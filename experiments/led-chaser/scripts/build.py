#!/usr/bin/env python3
"""Simulate and build this experiment inside WSL; never accesses USB."""
import hashlib
import json
from pathlib import Path
import shlex
import subprocess

from prepare_gowin_fs import prepare

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
PATTERNS = [0b111110, 0b111101, 0b111011, 0b110111, 0b101111, 0b011111]


def check_vcd(path, step_cycles, cycle_count):
    symbols = {}
    values = {}
    samples = []
    last_clock = None
    timestamp = None
    initial = None

    def consume():
        nonlocal last_clock, initial
        if timestamp is None or 'clk' not in symbols or 'led' not in symbols:
            return
        clock = values.get(symbols['clk'])
        bits = values.get(symbols['led'])
        if initial is None and bits is not None:
            assert set(bits) <= {'0', '1'}, 'Unknown LED value at startup'
            initial = int(bits, 2)
        if last_clock == '0' and clock == '1':
            assert bits is not None and set(bits) <= {'0', '1'}, 'Unknown LED output'
            port_value = int(bits, 2)
            cycle = len(samples) + 1
            assert port_value == PATTERNS[(cycle // step_cycles) % 6], f'Incorrect LED sequence at cycle {cycle}'
            active = (~port_value) & 0x3F
            assert active.bit_count() == 1, f'Expected exactly one lit LED at cycle {cycle}'
            samples.append({'cycle': cycle, 'vcd_tick': timestamp,
                            'active_led': active.bit_length() - 1, 'port_bits': f'{port_value:06b}'})
        last_clock = clock

    for raw in path.read_text(encoding='ascii').splitlines():
        line = raw.strip()
        if line.startswith('$var '):
            fields = line.split()
            if fields[4] in ('clk', 'led'):
                symbols[fields[4]] = fields[3]
        elif line.startswith('#'):
            consume()
            timestamp = int(line[1:])
        elif line.startswith('b'):
            bits, symbol = line[1:].split()
            values[symbol] = bits
        elif line and line[0] in '01xz' and not line.startswith('$'):
            values[line[1:]] = line[0]
    consume()
    assert initial == PATTERNS[0], 'Initial LED must be LED0'
    assert len(samples) == cycle_count, f'Expected {cycle_count} rising-edge samples'
    laps = cycle_count // (6 * step_cycles)
    assert laps >= 2, 'Simulation must cover at least two complete laps'
    return {'result': 'PASS', 'simulated_step_cycles': step_cycles,
            'clock_cycles': cycle_count, 'complete_laps': laps,
            'one_lit_led_at_every_sample': True,
            'correct_order_and_exact_step_interval': True,
            'initial_active_led': 0, 'samples': samples}


def main():
    BUILD.mkdir(exist_ok=True)
    stages = []
    commands = []

    def run(name, args):
        commands.append(shlex.join(args))
        (BUILD / 'commands.txt').write_text('\n\n'.join(commands) + '\n', encoding='utf-8')
        print(f'Running {name}...', flush=True)
        with (BUILD / f'{name}.console.log').open('wb') as output:
            process = subprocess.run(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
        stages.append({'stage': name, 'exit_code': process.returncode})
        if process.returncode:
            tail = (BUILD / f'{name}.console.log').read_text(encoding='utf-8', errors='replace')[-2000:]
            raise RuntimeError(f'{name} failed with exit code {process.returncode}:\n{tail}')
        print(f'{name}: exit_code=0', flush=True)

    try:
        run('simulation', ['yosys', '-Q', '-T', '-l', 'build/simulation.log', '-p',
                          'read_verilog src/top.v; chparam -set STEP_CYCLES 3 top; hierarchy -top top; proc; opt; sim -clock clk -n 42 -vcd build/simulation.vcd -q'])
        simulation = check_vcd(BUILD / 'simulation.vcd', 3, 42)
        (BUILD / 'simulation-result.json').write_text(json.dumps(simulation, indent=2) + '\n', encoding='utf-8')
        print('Simulation checks: PASS (42 cycles, 2 full laps)', flush=True)

        run('synthesis', ['yosys', '-Q', '-T', '-l', 'build/yosys.log', '-p',
                         'read_verilog src/top.v; synth_gowin -top top -json build/top.json; check -assert'])
        netlist = json.loads((BUILD / 'top.json').read_text())
        hardware_cycles = int(netlist['modules']['top']['parameter_default_values']['STEP_CYCLES'], 2)
        assert hardware_cycles == 13_500_000, 'Hardware build must retain the real 0.5-second interval'

        run('place-and-route', ['nextpnr-gowin', '--json', 'build/top.json', '--write', 'build/top_pnr.json',
                                '--device', 'GW1NR-LV9QN88PC6/I5', '--family', 'GW1N-9C',
                                '--cst', 'constraints/tangnano9k.cst', '--freq', '27',
                                '--report', 'build/timing.json', '--log', 'build/nextpnr.log'])
        timing = json.loads((BUILD / 'timing.json').read_text())
        assert timing['fmax'] and all(clock['constraint'] == 27 and clock['achieved'] >= 27
                                      for clock in timing['fmax'].values()), '27 MHz timing target not met'
        assert timing['utilization']['IOB']['used'] == 7, 'Expected one clock input and six LED outputs'

        run('packing', ['gowin_pack', '-d', 'GW1N-9C', '-o', 'build/tangnano9k-led-chaser.fs', 'build/top_pnr.json'])
        from apycula import bslib
        bitmap, _, _ = bslib.read_bitstream(str(BUILD / 'tangnano9k-led-chaser.fs'))
        assert bitmap.shape[0] == 712, 'Unexpected bitstream frame count'
        compatible = prepare(BUILD / 'tangnano9k-led-chaser.fs', BUILD / 'tangnano9k-led-chaser-gowin.fs')
        result = {
            'overall_result': 'PASS', 'stages': stages,
            'simulation_passed': True, 'simulation_cycles': 42, 'simulated_complete_laps': 2,
            'hardware_step_cycles': hardware_cycles, 'clock_hz': 27_000_000,
            'step_seconds': hardware_cycles / 27_000_000, 'full_lap_seconds': 3.0,
            'timing_target_mhz': 27, 'timing_passed': True,
            'fmax_estimates': timing['fmax'], 'utilization': timing['utilization'],
            'all_712_frame_crcs_passed': True, 'bitstream': compatible,
            'source_sha256': hashlib.sha256((ROOT / 'src/top.v').read_bytes()).hexdigest(),
            'constraints_sha256': hashlib.sha256((ROOT / 'constraints/tangnano9k.cst').read_bytes()).hexdigest(),
            'hardware_programming_performed_by_build': False,
        }
    except Exception as error:
        result = {'overall_result': 'FAIL', 'stages': stages, 'error': str(error),
                  'hardware_programming_performed_by_build': False}
        (BUILD / 'build-result.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
        raise
    (BUILD / 'build-result.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'overall_result': result['overall_result'], 'step_seconds': result['step_seconds'],
                      'expected_user_code': compatible['expected_user_code'],
                      'slice_used': timing['utilization']['SLICE']['used']}), flush=True)


if __name__ == '__main__':
    main()

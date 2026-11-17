#!/usr/bin/env python3
"""Build and simulate a RAM-booted RV32IMC full-feature experiment; no USB access."""
from pathlib import Path
import hashlib
import json
import shlex
import struct
import subprocess
import time
import sys

from prepare_gowin_fs import prepare

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'


def main():
    BUILD.mkdir(exist_ok=True)
    stages, commands = [], []

    def run(name, args, timeout=600):
        print(f'Running {name}...', flush=True)
        commands.append(shlex.join(args))
        (BUILD / 'commands.txt').write_text('\n\n'.join(commands) + '\n', encoding='utf-8')
        started = time.monotonic()
        with (BUILD / f'{name}.console.log').open('wb') as log:
            process = subprocess.run(args, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
        stages.append({'stage': name, 'exit_code': process.returncode, 'elapsed_seconds': round(time.monotonic() - started, 3)})
        if process.returncode:
            tail = (BUILD / f'{name}.console.log').read_text(encoding='utf-8', errors='replace')[-3500:]
            raise RuntimeError(f'{name}: exit_code={process.returncode}\n{tail}')
        print(f'{name}: PASS', flush=True)

    try:
        run('firmware-compile', ['riscv64-unknown-elf-gcc', '-march=rv32imc', '-mabi=ilp32', '-mno-relax',
                               '-msmall-data-limit=0', '-Os', '-ffreestanding', '-fno-builtin',
                               '-ffunction-sections', '-fdata-sections', '-fstack-usage', '-Wall', '-Wextra', '-Werror',
                               '-nostdlib', '-nostartfiles', '-T', 'firmware/link.ld', '-Wl,--gc-sections',
                               '-Wl,-Map,build/firmware.map', 'firmware/start.S', 'firmware/main.c',
                               '-o', 'build/firmware.elf'])
        elf = (BUILD / 'firmware.elf').read_bytes()
        assert elf[:6] == b'\x7fELF\x01\x01' and int.from_bytes(elf[18:20], 'little') == 243, 'Expected 32-bit little-endian RISC-V ELF'
        run('firmware-binary', ['riscv64-unknown-elf-objcopy', '-O', 'binary', 'build/firmware.elf', 'build/firmware.bin'])
        binary = (BUILD / 'firmware.bin').read_bytes()
        assert len(binary) <= 4096, 'Firmware must fit program ROM'
        image = binary + bytes(4096 - len(binary))
        (BUILD / 'firmware.hex').write_text(''.join(f'{word[0]:08x}\n' for word in struct.iter_unpack('<I', image)), encoding='ascii')
        with (BUILD / 'firmware.disassembly.txt').open('wb') as output:
            subprocess.run(['riscv64-unknown-elf-objdump', '-d', 'build/firmware.elf'], cwd=ROOT, stdout=output, check=True)

        run('simulation-compile', ['iverilog', '-g2012', '-s', 'soc_tb', '-o', 'build/soc-sim.vvp',
                                    'src/vendor/picorv32.v', 'src/vendor/simpleuart.v', 'src/pico_uart_soc.v', 'sim/soc_tb.v'])
        run('simulation', ['vvp', 'build/soc-sim.vvp'])
        simulation = (BUILD / 'simulation.console.log').read_text(encoding='utf-8')
        assert 'TEST PASS:' in simulation and 'UART: PONG' in simulation and 'UART: GPIO=00000008' in simulation
        assert 'UART: RV32IMC selftest=000000FF' in simulation and 'UART: M=PASS' in simulation and 'UART: SOFTIRQ=00000002' in simulation
        assert simulation.count('UART: IRQ_TICK=') >= 3
        print(simulation[-2400:], flush=True)
        if '--simulate-only' in sys.argv:
            return

        run('synthesis', ['yosys', '-Q', '-T', '-l', 'build/yosys.log', '-p',
                         'read_verilog src/vendor/picorv32.v src/vendor/simpleuart.v src/pico_uart_soc.v src/top.v; synth_gowin -nobram -nowidelut -noalu -top top -json build/top.json; check -assert'])
        run('place-and-route', ['nextpnr-gowin', '--json', 'build/top.json', '--write', 'build/top_pnr.json',
                                '--device', 'GW1NR-LV9QN88PC6/I5', '--family', 'GW1N-9C',
                                '--cst', 'constraints/tangnano9k.cst', '--freq', '27',
                                '--pre-pack', 'scripts/clocks.py', '--router', 'router1', '--report', 'build/timing.json', '--log', 'build/nextpnr.log'])
        timing = json.loads((BUILD / 'timing.json').read_text())
        assert timing['fmax'] and all(clock['achieved'] >= clock['constraint'] for clock in timing['fmax'].values()), 'Clock target not met'
        assert any(clock['constraint'] == 13.5 for clock in timing['fmax'].values()), 'Expected the 13.5 MHz CPU clock constraint'
        assert timing['utilization']['IOB']['used'] == 9
        run('packing', ['gowin_pack', '-d', 'GW1N-9C', '-o', 'build/picorv32-max.fs', 'build/top_pnr.json'])
        from apycula import bslib
        bitmap, _, _ = bslib.read_bitstream(str(BUILD / 'picorv32-max.fs'))
        assert bitmap.shape[0] >= 712
        compatible = prepare(BUILD / 'picorv32-max.fs', BUILD / 'picorv32-max-gowin.fs')
        result = {
            'overall_result': 'PASS', 'stages': stages,
            'cpu': 'Unmodified Sipeed PicoRV32, RV32IMC + IRQ/PCPI/trace/counters64/barrel shifter', 'firmware_elf_class': 32,
            'firmware_binary_bytes': len(binary), 'program_rom_bytes': 4096, 'data_ram_bytes': 512, 'ram_implementation': 'distributed LUT RAM + LUT ROM',
            'firmware_sha256': hashlib.sha256(binary).hexdigest(),
            'simulation_features_passed': True, 'selftest_expected_mask': '0x000000ff', 'm_extension_vectors': 4, 'm_extension_operations_per_vector': 8,
            'simulation_irq_reload': 135000, 'hardware_irq_reload': 13500000,
            'source_clock_hz': 27000000, 'clock_hz': 13500000, 'uart_requested_baud': 115200, 'uart_bit_clock_cycles': 117,
            'fmax_estimates': timing['fmax'], 'timing_passed': True,
            'utilization': timing['utilization'], 'all_frame_crcs_passed': True,
            'total_frames_including_ram_init': int(bitmap.shape[0]),
            'bitstream': compatible, 'hardware_programming_performed_by_build': False,
        }
    except Exception as error:
        result = {'overall_result': 'FAIL', 'stages': stages, 'error': str(error),
                  'hardware_programming_performed_by_build': False}
        (BUILD / 'build-result.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
        raise
    (BUILD / 'build-result.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'result': result['overall_result'], 'firmware_bytes': len(binary),
                      'expected_user_code': compatible['expected_user_code'], 'utilization': timing['utilization']}), flush=True)


if __name__ == '__main__':
    main()

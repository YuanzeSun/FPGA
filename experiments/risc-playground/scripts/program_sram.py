import os
from pathlib import Path
import hashlib
import json
import re
import subprocess
import time

project = Path(__file__).resolve().parents[1]
build = project / 'build'
records = build / 'sram-test'
records.mkdir(exist_ok=True)
validation = json.loads((build / 'build-result.json').read_text(encoding='utf-8'))
assert validation['overall_result'] == 'PASS'
assert validation['simulation_features_passed'] and validation['timing_passed']
fs = build / 'risc-playground-gowin.fs'
assert hashlib.sha256(fs.read_bytes()).hexdigest() == validation['bitstream']['output_sha256']
expected_code = int(validation['bitstream']['expected_user_code'], 16)
for name, digest in validation['source_sha256'].items():
    assert hashlib.sha256((project / name).read_bytes()).hexdigest() == digest, 'Source differs from validated build: ' + name
exe = Path(os.environ.get('GOWIN_PROGRAMMER',r'C:\GowinProgrammer\bin\programmer_cli.exe'))
steps = []


def run(name, args):
    command = [str(exe)] + args
    with (records / 'commands.txt').open('a', encoding='utf-8') as out:
        out.write(subprocess.list2cmdline(command) + '\n')
    start = time.monotonic()
    process = subprocess.run(command, cwd=exe.parent, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, timeout=60)
    (records / f'{name}.raw.log').write_bytes(process.stdout)
    log = process.stdout.decode('utf-8', errors='replace').replace('\r\r\n', '\n').replace('\r\n', '\n')
    (records / f'{name}.log').write_text(log, encoding='utf-8')
    item = {'step': name, 'exit_code': process.returncode, 'elapsed_seconds': round(time.monotonic() - start, 3)}
    steps.append(item)
    print(json.dumps(item), flush=True)
    print(log[-1000:].replace('\r', '\n'), flush=True)
    return process.returncode, log


def read_codes(log):
    codes = {}
    for name in ('ID', 'User', 'Status'):
        match = re.search(rf'{name} Code is:\s*(0x[0-9A-Fa-f]+)', log)
        codes[name] = int(match.group(1), 16) if match else None
    return codes


common = ['--device', 'GW1NR-9C']
cable = ['--cable-index', '4', '--frequency', '2MHz']
result = {
    'date': time.strftime('%Y-%m-%d'), 'experiment': 'TangNano9K-RISC-Playground', 'operation_index': 2,
    'programmer_version': 'V1.9.11.02 build2518', 'cable_index': 4, 'frequency': '2MHz',
    'expected_user_code': f'0x{expected_code:08X}',
    'compatible_bitstream_sha256': validation['bitstream']['output_sha256'],
    'flash_write_or_erase_performed': False,
    'physical_led_observation_performed': False,
    'steps': steps,
}
try:
    code, enumeration = run('01-cables', ['--scan-cables', 'F'])
    adapters = re.findall(r'Cable found:\s+USB Debugger A/(\d+)/(\d+)/', enumeration)
    assert code == 0 and len(adapters) == 2 and all(int(location) > 0 for _, location in adapters), 'Expected the single working two-channel board'
    code, log = run('02-preflight', common + ['--run', '0'] + cable)
    before = read_codes(log)
    assert code == 0 and before['ID'] == 0x1100481B, 'Actual FPGA ID preflight failed'
    assert before['Status'] is not None and before['Status'] & 0x8000, 'FPGA is not ready'
    result['preflight_codes'] = {key: f'0x{value:08X}' if value is not None else None for key, value in before.items()}
    code, log = run('03-sram-program', common + ['--run', '2', '--fsFile', str(fs)] + cable)
    result['sram_program_exit_code'] = code
    assert code == 0 and 'Finished.' in log and 'Error:' not in log, 'SRAM programming did not report completion'
    code, log = run('04-read-after-sram', common + ['--run', '0'] + cable)
    after = read_codes(log)
    status = after['Status']
    assert code == 0 and after['ID'] == 0x1100481B and after['User'] == expected_code, 'User code or ID readback mismatch'
    assert status is not None and status & 0x2000 and status & 0x8000 and not status & 0xF, 'Unexpected FPGA status flags'
    result.update({'overall_result': 'SRAM_PROGRAM_AND_READBACK_PASS',
                   'readback_codes': {key: f'0x{value:08X}' for key, value in after.items()},
                   'done_final': True, 'ready': True, 'device_error_flags_3_0': 0,
                   'user_code_matches': True})
except (AssertionError, subprocess.TimeoutExpired) as error:
    result['overall_result'] = 'REVIEW_REQUIRED'
    result['error'] = str(error)
finally:
    (records / 'result.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, indent=2), flush=True)
raise SystemExit(0 if result['overall_result'] == 'SRAM_PROGRAM_AND_READBACK_PASS' else 1)

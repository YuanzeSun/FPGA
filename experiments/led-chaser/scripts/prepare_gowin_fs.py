#!/usr/bin/env python3
"""Add Gowin Programmer metadata without changing Tang Nano 9K configuration bits.

For the uncompressed GW1N-9C bitstreams produced by this experiment's Apicula
version. The original .fs remains untouched. Uses only the Python standard library.
"""

import argparse
import hashlib
import json
from pathlib import Path


def prepare(source: Path, destination: Path) -> dict:
    if source.resolve() == destination.resolve():
        raise ValueError('Input and output must be different files.')
    original = source.read_bytes()
    lines = [line.strip() for line in original.decode('ascii').splitlines()
             if line.strip() and not line.lstrip().startswith('//')]
    if any(set(line) - {'0', '1'} or len(line) % 8 for line in lines):
        raise ValueError('Expected ASCII binary configuration lines with whole bytes.')
    ids = [int(line, 2) & 0xFFFFFFFF for line in lines
           if len(line) == 64 and line.startswith('00000110000000000000000000000000')]
    if ids != [0x1100481B]:
        raise ValueError('This helper supports only the GW1N/GW1NR-9C device ID 0x1100481B.')
    frame_headers = [i for i, line in enumerate(lines)
                     if len(line) == 32 and int(line[:8], 2) == 0x3B]
    if len(frame_headers) != 1:
        raise ValueError('Expected exactly one uncompressed configuration frame header.')
    start = frame_headers[0]
    frame_word = int(lines[start], 2)
    if frame_word != 0x3B8002C8:
        raise ValueError('Expected 712 CRC-enabled uncompressed GW1N-9C frames.')
    frames = lines[start + 1:start + 1 + 712]
    if len(frames) != 712 or any(len(line) != 2904 for line in frames):
        raise ValueError('Unexpected configuration frame count or width.')
    payload = ''.join(line[4:-64] for line in frames)
    if len(payload) % 16:
        raise ValueError('Configuration payload does not contain whole 16-bit words.')
    checksum = sum(int(payload[i:i + 16], 2) for i in range(0, len(payload), 16)) & 0xFFFF
    footer_codes = [int(line, 2) & 0xFFFFFFFF for line in lines[start + 1 + 712:]
                    if len(line) == 64 and int(line[:8], 2) == 0x0A]
    if footer_codes != [checksum]:
        raise ValueError('Recomputed configuration checksum differs from the footer user code.')

    header = f'//CheckSum: 0x{checksum:04X}\r\n//UserCode: 0x{checksum:08X}\r\n'.encode('ascii')
    # Remove existing instances of only these two metadata fields. Preserve every
    # other input byte, including configuration data and its original line endings.
    retained = b''.join(line for line in original.splitlines(keepends=True)
                        if not line.lstrip().lower().startswith((b'//checksum:', b'//usercode:')))
    compatible = header + retained
    compatible_lines = [line.strip() for line in compatible.decode('ascii').splitlines()
                        if line.strip() and not line.lstrip().startswith('//')]
    if compatible_lines != lines:
        raise ValueError('Compatibility processing unexpectedly changed configuration data.')
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(compatible)
    return {
        'input': str(source), 'output': str(destination),
        'input_sha256': hashlib.sha256(original).hexdigest(),
        'output_sha256': hashlib.sha256(compatible).hexdigest(),
        'device_id': '0x1100481B', 'frames': 712,
        'expected_user_code': f'0x{checksum:08X}',
        'configuration_data_unchanged': True,
        'programming_performed': False,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    try:
        result = prepare(args.input, args.output)
    except (OSError, UnicodeError, ValueError) as exc:
        parser.exit(1, f'Error: {exc}\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()

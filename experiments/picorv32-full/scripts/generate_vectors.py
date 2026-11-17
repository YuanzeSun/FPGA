#!/usr/bin/env python3
"""Generate RV32 M and shift golden values using host arbitrary-precision integers."""
from pathlib import Path

MASK = 0xffffffff

def signed(value):
    return value if value < 0x80000000 else value - 0x100000000

def golden(a, b):
    sa, sb = signed(a), signed(b)
    quotient = (-1 if (sa < 0) != (sb < 0) else 1) * (abs(sa) // abs(sb)) if sb else -1
    remainder = sa - quotient * sb if sb else sa
    return [a, b, (a*b) & MASK, ((sa*sb) >> 32) & MASK,
            ((sa*b) >> 32) & MASK, ((a*b) >> 32) & MASK,
            quotient & MASK, a//b if b else MASK, remainder & MASK, a%b if b else a]

def main():
    rows = [golden(a,b) for a,b in [(0xffed2979,321), (0x80000000,0xffffffff),
                                    (0x89abcdef,0), (0xfedcba98,0x89abcdef)]]
    text = '// Golden results generated independently with host Python integer arithmetic.\nstatic const u32 m_vectors[][10] = {\n'
    text += ''.join('    {' + ', '.join(f'0x{v:08x}u' for v in row) + '},\n' for row in rows) + '};\n'
    text += 'static const u32 shift_vectors[][5] = {\n'
    for a,n in [(0x81234567,0), (0x81234567,1), (0x81234567,17), (0x81234567,31)]:
        row = [a,n,(a<<n) & MASK,a>>n,(signed(a)>>n) & MASK]
        text += '    {' + ', '.join(f'0x{v:08x}u' for v in row) + '},\n'
    text += '};\n'
    (Path(__file__).resolve().parents[1] / 'firmware/golden_vectors.h').write_text(text, encoding='utf-8')

if __name__ == '__main__':
    main()

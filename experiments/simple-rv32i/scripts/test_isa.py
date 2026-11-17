"""Independent instruction interpreter vs RTL retirement and final RAM; deterministic seeds."""
from pathlib import Path
import json, random, re, subprocess

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/isa-test'
MASK=0xffffffff
def signed(x): return (x&MASK)-0x100000000 if x&0x80000000 else x&MASK
def sext(x,b): return x-(1<<b) if x&(1<<(b-1)) else x
def I(op,rd,f,rs,imm): return ((imm&4095)<<20)|(rs<<15)|(f<<12)|(rd<<7)|op
def R(rd,f,a,b,f7=0): return (f7<<25)|(b<<20)|(a<<15)|(f<<12)|(rd<<7)|0x33
def U(op,rd,value): return (value&0xfffff000)|(rd<<7)|op
def S(f,a,b,off): return ((off>>5&127)<<25)|(b<<20)|(a<<15)|(f<<12)|((off&31)<<7)|0x23
def B(f,a,b,off): return ((off>>12&1)<<31)|((off>>5&63)<<25)|(b<<20)|(a<<15)|(f<<12)|((off>>1&15)<<8)|((off>>11&1)<<7)|0x63
def J(rd,off): return ((off>>20&1)<<31)|((off>>1&1023)<<21)|((off>>11&1)<<20)|((off>>12&255)<<12)|(rd<<7)|0x6f

def reference(program):
    regs=[0]*32; pc=0; trace=[]; seen=set(); branch_outcomes=set()
    ram=bytearray().join(((0x80ff7f01^(i*0x01020304))&MASK).to_bytes(4,'little') for i in range(256))
    def done(cause,value): return trace,ram,(cause,value&MASK,pc),seen,branch_outcomes
    for _ in range(10000):
        if pc&3: return done(0,pc)
        if pc>=8192: return done(1,pc)
        ins=program[pc//4] if pc//4<len(program) else 0
        op=ins&127; rd=ins>>7&31; f=ins>>12&7; r1=ins>>15&31; r2=ins>>20&31; f7=ins>>25
        a,b=regs[r1],regs[r2]; imm=sext(ins>>20,12); nextpc=(pc+4)&MASK; value=0; write=False; name=None
        if op in (0x37,0x17):
            value=((ins&0xfffff000)+(pc if op==0x17 else 0))&MASK
            name='AUIPC' if op==0x17 else 'LUI'; write=True
        elif op in (0x33,0x13):
            write=True; operand=b if op==0x33 else imm&MASK
            if op==0x33 and not(f7==0 or (f7==32 and f in (0,5))): return done(2,ins)
            if op==0x13 and f in (1,5) and not(f7==0 or (f==5 and f7==32)): return done(2,ins)
            shift=operand&31
            if f==0:
                sub=op==0x33 and f7==32
                value=a-operand if sub else a+operand; name='SUB' if sub else 'ADD'
            elif f==1: value=a<<shift; name='SLL'
            elif f==2: value=int(signed(a)<signed(operand)); name='SLT'
            elif f==3: value=int(a<operand); name='SLTU'
            elif f==4: value=a^operand; name='XOR'
            elif f==5:
                value=signed(a)>>shift if f7==32 else a>>shift; name='SRA' if f7==32 else 'SRL'
            elif f==6: value=a|operand; name='OR'
            elif f==7: value=a&operand; name='AND'
            if op==0x13: name='SLTIU' if name=='SLTU' else name+'I'
        elif op==0x63:
            if f in (2,3): return done(2,ins)
            offset=sext(((ins>>31)<<12)|((ins>>7&1)<<11)|((ins>>25&63)<<5)|((ins>>8&15)<<1),13)
            taken={0:a==b,1:a!=b,4:signed(a)<signed(b),5:signed(a)>=signed(b),6:a<b,7:a>=b}[f]
            name={0:'BEQ',1:'BNE',4:'BLT',5:'BGE',6:'BLTU',7:'BGEU'}[f]
            branch_outcomes.add((name,taken))
            if taken: nextpc=(pc+offset)&MASK
        elif op==0x6f:
            offset=sext(((ins>>31)<<20)|((ins>>12&255)<<12)|((ins>>20&1)<<11)|((ins>>21&1023)<<1),21)
            name='JAL'; value=pc+4; write=True; nextpc=(pc+offset)&MASK
        elif op==0x67:
            if f: return done(2,ins)
            name='JALR'; value=pc+4; write=True; nextpc=((a+imm)&MASK)&~1
        elif op in (3,0x23):
            if op==3 and f not in (0,1,2,4,5): return done(2,ins)
            if op==0x23 and f not in (0,1,2): return done(2,ins)
            offset=imm if op==3 else sext(((ins>>25)<<5)|(ins>>7&31),12)
            addr=(a+offset)&MASK; width=1<<(f&3)
            if addr&(width-1): return done(4 if op==3 else 6,addr)
            if not(0x10000<=addr and addr+width<=0x10400): return done(5 if op==3 else 7,addr)
            at=addr-0x10000
            if op==3:
                value=int.from_bytes(ram[at:at+width],'little')
                if f in (0,1): value=sext(value,width*8)
                write=True; name={0:'LB',1:'LH',2:'LW',4:'LBU',5:'LHU'}[f]
            else:
                ram[at:at+width]=(b&((1<<(8*width))-1)).to_bytes(width,'little')
                name={0:'SB',1:'SH',2:'SW'}[f]
        elif op==0x0f and f==0: name='FENCE'
        elif ins in (0x73,0x100073):
            seen.add('ECALL' if ins==0x73 else 'EBREAK')
            return done(11 if ins==0x73 else 3,0 if ins==0x73 else pc)
        else: return done(2,ins)
        if nextpc&3: return done(0,nextpc)
        if write and rd: regs[rd]=value&MASK
        trace.append((pc,ins,rd if write else 0,(value&MASK) if write and rd else 0))
        seen.add(name); pc=nextpc
    raise AssertionError('Reference timeout')

def vectors(seed):
    rng=random.Random(seed); p=[U(0x37,31,0x10000)]
    for r in range(1,31):
        v=rng.getrandbits(32); low=sext(v&4095,12)
        p += [U(0x37,r,(v-low)&MASK),I(0x13,r,0,r,low)]
    p += [I(0x13,1,0,0,-1),I(0x13,2,0,0,1),I(0x13,0,0,0,123)]
    for f,f7 in [(f,0) for f in range(8)]+[(0,32),(5,32)]: p.append(R(3,f,1,2,f7))
    for f in range(8): p.append(I(0x13,3,f,1,5))
    p.append(I(0x13,3,5,1,(32<<5)|7))
    for f in (0,1,4,5,6,7):
        for a,b in ((1,1),(1,2),(2,1)):
            p += [B(f,a,b,8), I(0x13,0,0,0,0)]
    for f in (0,1,2):
        for offset in range(0,16,1<<f): p.append(S(f,31,1,offset))
    for f in (0,1,2,4,5):
        for offset in range(0,16,1<<(f&3)): p.append(I(3,4,f,31,offset))
    p += [U(0x17,5,0xfffff000), J(6,8), I(0x13,0,0,0,0)]
    at=len(p); p += [I(0x13,7,0,0,((at+3)*4)|1),I(0x67,8,0,7,0),I(0x13,0,0,0,0)]
    # Backwards branch and a loop-carried dependency.
    p += [I(0x13,9,0,0,4),I(0x13,9,0,9,-1),B(1,9,0,-4)]
    for _ in range(700):
        rd=rng.randrange(31); a=rng.randrange(31); b=rng.randrange(31); kind=rng.randrange(7)
        if kind==0:
            f,f7=rng.choice([(f,0) for f in range(8)]+[(0,32),(5,32)]); p.append(R(rd,f,a,b,f7))
        elif kind==1:
            f=rng.randrange(8); val=rng.randrange(-2048,2048)
            if f in (1,5): val=rng.randrange(32)|(1024 if f==5 and rng.randrange(2) else 0)
            p.append(I(0x13,rd,f,a,val))
        elif kind==2:
            f=rng.choice((0,1,2,4,5)); off=rng.randrange(128)&~((1<<(f&3))-1); p.append(I(3,rd,f,31,off))
        elif kind==3:
            f=rng.randrange(3); off=rng.randrange(128)&~((1<<f)-1); p.append(S(f,31,b,off))
        elif kind==4: p += [B(rng.choice((0,1,4,5,6,7)),a,b,8),I(0x13,0,0,0,0)]
        elif kind==5: p.append(U(rng.choice((0x37,0x17)),rd,rng.getrandbits(32)))
        else: p.append(0x0ff0000f)
    return p+[0x73]

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    src=['src/rv32_alu.v','src/rv32_regfile.v','src/rv32_decode.v','src/rv32_core.v','sim/core_tb.v']
    subprocess.run(['iverilog','-g2012','-s','core_tb','-o',str(OUT/'core.vvp'),*src],cwd=ROOT,check=True)
    cases={f'random-{s}':vectors(s) for s in (1,17,2026)}
    cases.update({'ebreak':[0x100073],'illegal':[0xffffffff],'mul-unsupported':[R(3,0,1,2,1)],
                  'csr-unsupported':[0xc0002073],'compressed-unsupported':[1],
                  'bad-shift':[I(0x13,1,1,0,0x400)],'bad-branch':[B(2,0,0,4)],
                  'bad-load':[I(3,1,3,0,0)],'bad-store':[S(3,0,0,0)],
                  'bad-jalr':[I(0x67,1,1,0,0)],'fence-i-unsupported':[0x100f],
                  'misaligned-jal':[J(1,2)],'misaligned-jalr':[I(0x67,1,0,0,3)],
                  'misaligned-branch':[B(0,0,0,2)],'untaken-misaligned-branch':[B(1,0,0,2),0x100073],
                  'instruction-access':[U(0x37,1,0x8000),I(0x67,0,0,1,0)],
                  'jalr-source-equals-destination':[I(0x13,1,0,0,13),I(0x67,1,0,1,0),I(0x13,0,0,0,0),0x100073],
                 })
    # Reference model uses RAM-only data accesses; choose genuinely unmapped address.
    cases['load-access']=[U(0x37,1,0x8000),I(3,2,2,1,0)]
    cases['store-access']=[U(0x37,1,0x8000),S(2,1,0,0)]
    for f in (1,2):
        cases[f'misaligned-load-{f}']=[U(0x37,31,0x10000),I(3,1,f,31,1)]
        cases[f'misaligned-store-{f}']=[U(0x37,31,0x10000),S(f,31,0,1)]
    seen=set(); outcomes=set(); counts=[]
    for name,p in cases.items():
        trace,ram,trap,cov,branches=reference(p)
        image=OUT/(name+'.hex'); image.write_text(''.join(f'{x:08x}\n' for x in p+[0]*(2048-len(p))))
        prefix=OUT/name
        run=subprocess.run(['vvp',str(OUT/'core.vvp'),f'+image={image}',f'+prefix={prefix}'],cwd=ROOT,capture_output=True,text=True,timeout=30)
        (OUT/(name+'.log')).write_text(run.stdout+run.stderr)
        assert run.returncode==0,(name,run.stdout,run.stderr)
        actual=[tuple(int(x,16) for x in line.split()) for line in prefix.with_suffix('.trace').read_text().splitlines()]
        assert actual==trace,(name,'retirement mismatch',next(((i,a,b) for i,(a,b) in enumerate(zip(actual,trace)) if a!=b), (len(actual),len(trace))))
        actual_ram=b''.join(int(line,16).to_bytes(4,'little') for line in prefix.with_suffix('.memory').read_text().splitlines())
        assert actual_ram==ram,(name,'RAM mismatch')
        m=re.search(r'TRAP ([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+) RETIRED (\d+)',run.stdout)
        assert m and tuple(int(x,16) for x in m.groups()[:3])==trap,(name,'trap mismatch',run.stdout,trap)
        assert int(m[4])==len(trace)
        seen|=cov; outcomes|=branches; counts.append({'case':name,'retired':len(trace),'trap':trap})
    expected=set('LUI AUIPC JAL JALR BEQ BNE BLT BGE BLTU BGEU LB LH LW LBU LHU SB SH SW ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI ADD SUB SLL SLT SLTU XOR SRL SRA OR AND FENCE ECALL EBREAK'.split())
    assert seen==expected, (sorted(seen-expected),sorted(expected-seen))
    assert len(outcomes)==12, sorted(outcomes)
    report={'result':'PASS','cases':counts,'instructions_covered':sorted(seen),
            'retirements_compared':sum(c['retired'] for c in counts),'branch_outcomes':12,
            'final_ram_compared':True,'variable_memory_wait_states':True,'official_compliance_certification':False}
    (OUT/'result.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f"ISA PASS: {len(cases)} cases, {len(seen)} instructions, {report['retirements_compared']} retirement records")
if __name__=='__main__': main()

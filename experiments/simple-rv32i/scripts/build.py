"""Build original SimpleRV32I. This script never accesses USB."""
from pathlib import Path
import hashlib, json, os, shlex, struct, subprocess, sys, time
from prepare_gowin_fs import prepare
ROOT=Path(__file__).resolve().parents[1]
BUILD=ROOT/'build'
TOOLS=Path(os.environ.get('FPGA_TOOLS_DIR','/opt/fpga-tools/hdmi/venv/bin'))
os.environ['XDG_CACHE_HOME']='/opt/fpga-tools/hdmi/cache'
CORE=['src/rv32_alu.v','src/rv32_regfile.v','src/rv32_decode.v','src/rv32_core.v']
SOC=CORE+['src/uart.v','src/simple_soc.v']

def main():
    BUILD.mkdir(exist_ok=True)
    commands=[]; stages=[]
    def run(name,args,timeout=600):
        commands.append(shlex.join(args))
        (BUILD/'commands.txt').write_text('\n\n'.join(commands)+'\n')
        start=time.monotonic()
        print('Running '+name,flush=True)
        with (BUILD/(name+'.log')).open('wb') as f:
            r=subprocess.run(args,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,timeout=timeout)
        stages.append({'name':name,'exit_code':r.returncode,'seconds':round(time.monotonic()-start,3)})
        if r.returncode:
            raise RuntimeError(name+' failed:\n'+(BUILD/(name+'.log')).read_text(errors='replace')[-4000:])
        print(name+': PASS',flush=True)
    result={'result':'FAIL','stages':stages,'hardware_accessed':False}
    try:
        run('firmware-compile',['riscv64-unknown-elf-gcc','-march=rv32i','-mabi=ilp32','-mno-relax',
            '-msmall-data-limit=0','-Os','-ffreestanding','-fno-builtin','-nostdlib','-nostartfiles',
            '-ffunction-sections','-fdata-sections','-fstack-usage','-Wall','-Wextra','-Werror',
            '-T','firmware/link.ld','-Wl,--gc-sections','-Wl,-Map,build/firmware.map',
            'firmware/start.S','firmware/main.c','-o','build/firmware.elf'])
        run('firmware-binary',['riscv64-unknown-elf-objcopy','-O','binary','build/firmware.elf','build/firmware.bin'])
        run('firmware-disassembly',['riscv64-unknown-elf-objdump','-d','build/firmware.elf'])
        binary=(BUILD/'firmware.bin').read_bytes()
        assert len(binary)<=4096
        image=binary+bytes(4096-len(binary))
        (BUILD/'firmware.hex').write_text(''.join(f'{v[0]:08x}\n' for v in struct.iter_unpack('<I',image)))
        run('isa-tests',['python3','scripts/test_isa.py'])
        run('soc-sim-compile',['iverilog','-g2012','-s','soc_tb','-o','build/soc.vvp',*SOC,'sim/soc_tb.v'])
        run('soc-sim',['vvp','build/soc.vvp'],timeout=180)
        assert 'SOC_TEST_PASS' in (BUILD/'soc-sim.log').read_text()
        if '--simulate-only' in sys.argv:
            result.update(result='SIMULATION_PASS', firmware_bytes=len(binary),
                          isa_test=json.loads((BUILD/'isa-test/result.json').read_text()))
            print('All simulations passed; FPGA stages skipped.')
            return
        run('yosys',[str(TOOLS/'yowasp-yosys'),'-Q','-T','-l','build/yosys-detail.log','-p',
            'read_verilog '+' '.join(SOC+['src/top.v'])+'; synth_gowin -nowidelut -top top -json build/top.json; check -assert'])
        run('nextpnr',[str(TOOLS/'yowasp-nextpnr-himbaechel-gowin'),'--json','build/top.json','--write','build/top_pnr.json',
            '--device','GW1NR-LV9QN88PC6/I5','--vopt','family=GW1N-9C','--vopt','cst=constraints/tangnano9k.cst',
            '--freq','27','--sdc','constraints/clocks.sdc','--report','build/timing.json'])
        timing=json.loads((BUILD/'timing.json').read_text())
        assert timing['fmax'] and all(v['achieved']>=v['constraint'] for v in timing['fmax'].values())
        assert timing['utilization']['BSRAM']['used']>0, 'Expected block RAM inference'
        run('packing',[str(TOOLS/'gowin_pack'),'-d','GW1N-9C','-o','build/simple-rv32i.fs','build/top_pnr.json'])
        from apycula import bslib
        bitmap,*_=bslib.read_bitstream(str(BUILD/'simple-rv32i.fs'))
        meta=prepare(BUILD/'simple-rv32i.fs',BUILD/'simple-rv32i-gowin.fs')
        hashes={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
                for folder in ['src','firmware','constraints'] for p in sorted((ROOT/folder).rglob('*')) if p.is_file()}
        result.update(result='PASS',isa='RV32I',clock_hz=13500000,rom_bytes=4096,ram_bytes=1024,
            firmware_bytes=len(binary),timing=timing['fmax'],utilization=timing['utilization'],
            bitstream=meta,all_frame_crcs_passed=True,frames=int(bitmap.shape[0]),source_hashes=hashes,
            isa_test=json.loads((BUILD/'isa-test/result.json').read_text()),
            tool_environment=str(TOOLS.parent))
    except Exception as exc:
        result['error']=str(exc)
        raise
    finally:
        (BUILD/'build-result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ['result','firmware_bytes','timing','utilization']}),flush=True)
if __name__=='__main__': main()

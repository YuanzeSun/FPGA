import os
"""Validate build, sources and target, then load SRAM and check readback. Never writes Flash."""
from pathlib import Path
import argparse, hashlib, json, re, subprocess, time
ROOT=Path(__file__).resolve().parents[1]

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--programmer',default=r'C:\GowinProgrammer\bin\programmer_cli.exe')
    ap.add_argument('--dry-run',action='store_true')
    args=ap.parse_args()
    build=json.loads((ROOT/'build/build-result.json').read_text())
    assert build['result']=='PASS' and build['all_frame_crcs_passed']
    for relative,digest in build['source_hashes'].items():
        assert hashlib.sha256((ROOT/relative).read_bytes()).hexdigest()==digest, 'Rebuild after editing '+relative
    fs=ROOT/'build/simple-rv32i-gowin.fs'
    assert hashlib.sha256(fs.read_bytes()).hexdigest()==build['bitstream']['output_sha256']
    expected=int(build['bitstream']['expected_user_code'],16)
    exe=Path(args.programmer)
    common=['--device','GW1NR-9C','--cable-index','4','--frequency','2MHz']
    if args.dry_run:
        print('Source/build/hash validation passed. No USB access.')
        print(subprocess.list2cmdline([str(exe),*common,'--run','2','--fsFile',str(fs)]))
        return
    out=ROOT/'build/sram-test'; out.mkdir(exist_ok=True)
    steps=[]; commands=[]
    result={'result':'FAIL','steps':steps,'flash_write_or_erase_performed':False,
            'expected_user_code':f'0x{expected:08X}','bitstream_sha256':build['bitstream']['output_sha256']}
    def run(name,flags):
        cmd=[str(exe),*flags]; commands.append(subprocess.list2cmdline(cmd))
        (out/'commands.txt').write_text('\n'.join(commands)+'\n')
        start=time.monotonic()
        p=subprocess.run(cmd,cwd=exe.parent,capture_output=True,timeout=60)
        log=(p.stdout+p.stderr).decode('utf-8',errors='replace').replace('\r','')
        (out/(name+'.log')).write_text(log)
        steps.append({'step':name,'exit_code':p.returncode,'seconds':round(time.monotonic()-start,3)})
        print(json.dumps(steps[-1]),flush=True)
        assert p.returncode==0 and 'Error:' not in log,(name,log[-1500:])
        return log
    def codes(log):
        return {n:int(re.search(n+r' Code is:\s*(0x[0-9a-fA-F]+)',log)[1],16) for n in ('ID','User','Status')}
    try:
        cables=run('01-cables',['--scan-cables','F'])
        adapters=re.findall(r'USB Debugger A/(\d+)/(\d+)/',cables)
        assert len(adapters)==2 and all(int(location)>0 for _,location in adapters),'Expected one working board'
        before=codes(run('02-preflight',common+['--run','0']))
        assert before['ID']==0x1100481b and before['Status']&0x8000
        assert 'Finished.' in run('03-program',common+['--run','2','--fsFile',str(fs)])
        after=codes(run('04-readback',common+['--run','0']))
        assert after['ID']==0x1100481b and after['User']==expected
        assert after['Status']&0xa000==0xa000 and after['Status']&15==0
        result.update(result='SRAM_AND_READBACK_PASS',readback={n:f'0x{v:08X}' for n,v in after.items()})
    except Exception as e:
        result['error']=str(e); raise
    finally:
        (out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
if __name__=='__main__': main()

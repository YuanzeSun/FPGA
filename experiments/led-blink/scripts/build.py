"""Build the verified 27 MHz LED design inside WSL; no board access."""
from pathlib import Path
import hashlib
import json
import subprocess
from prepare_gowin_fs import prepare

ROOT=Path(__file__).resolve().parents[1]
BUILD=ROOT/'build'

def main():
    BUILD.mkdir(exist_ok=True)
    commands=[
        ['yosys','-l','build/yosys.log','-p','read_verilog src/top.v; synth_gowin -top top -json build/top.json; check -assert'],
        ['nextpnr-gowin','--json','build/top.json','--write','build/top_pnr.json','--device','GW1NR-LV9QN88PC6/I5','--family','GW1N-9C','--cst','constraints/tangnano9k.cst','--freq','27','--report','build/timing.json','--log','build/nextpnr.log'],
        ['gowin_pack','-d','GW1N-9C','-o','build/tangnano9k-led.fs','build/top_pnr.json'],
    ]
    for index,command in enumerate(commands):
        print('Running '+command[0],flush=True)
        with (BUILD/f'stage-{index}.log').open('wb') as log:
            subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
    timing=json.loads((BUILD/'timing.json').read_text())
    assert timing['fmax'] and all(v['achieved']>=v['constraint'] for v in timing['fmax'].values())
    bitstream=prepare(BUILD/'tangnano9k-led.fs',BUILD/'tangnano9k-led-gowin.fs')
    result={'overall_result':'PASS','timing_passed':True,'fmax_estimates':timing['fmax'],
        'bitstream':bitstream,'hardware_accessed':False,
        'source_sha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for directory in ['src','constraints'] for p in sorted((ROOT/directory).rglob('*')) if p.is_file()}}
    (BUILD/'build-result.json').write_text(json.dumps(result,indent=2)+'\n')
    print('LED build and timing: PASS')

if __name__=='__main__':main()

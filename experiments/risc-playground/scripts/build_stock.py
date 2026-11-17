import hashlib,html,json,os,re,shutil,stat,struct,subprocess,time,zlib
from pathlib import Path
from prepare_gowin_fs import prepare

root=Path(__file__).resolve().parents[1];out=root/'build'
ROOT=root;BUILD=out
config=Path(__file__).with_name('toolchain.local.json')
default_tool=Path('gw_sh.exe')
if config.exists():default_tool=Path(json.loads(config.read_text())['gowin_sh'])
tool=Path(os.environ.get('GOWIN_SH',str(default_tool)))
assert tool.is_file(),'Set GOWIN_SH to the full path of Gowin Education gw_sh.exe'
linux_root='/mnt/'+root.drive[0].lower()+root.as_posix()[2:]
out.mkdir(exist_ok=True)
stages=[]
def wsl(args):return ['wsl.exe','-d','Ubuntu-24.04','--cd',linux_root,'--exec']+args
def run(name,args):
    print('Running '+name,flush=True);started=time.monotonic()
    with (out/f'{name}.log').open('wb') as log:
        p=subprocess.run([str(x) for x in args],cwd=root,stdout=log,stderr=subprocess.STDOUT,timeout=900)
    stages.append({'stage':name,'exit_code':p.returncode,'elapsed_seconds':round(time.monotonic()-started,3)})
    assert p.returncode==0,(out/f'{name}.log').read_text(errors='replace')[-3500:]
def cells(row):
    return [' '.join(html.unescape(re.sub('<[^>]+>',' ',c)).split()) for c in re.findall(r'<t[dh]\b[^>]*>(.*?)</t[dh]>',row,re.S|re.I)]
def cpu_inputs():
    paths=list((ROOT/'firmware').glob('*'))+[ROOT/p for p in ['src/vendor/picorv32.v','src/vendor/simpleuart.v','src/risc_soc.v','sim/soc_tb.v','assets/letter_length.vh','build/firmware.hex']]
    return {p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths if p.is_file()}

def image_checks():
    font=[int(s,16) for s in (ROOT/'assets/font.hex').read_text().split()]
    palette=['080f1d','f8eddf','22d3ee','fb7185','a78bfa','4ade80','fbbf24','f8fafc','334155','1e293b','e11d48','94a3b8','2563eb','0f766e','171024','513244']
    palette=[bytes.fromhex(c) for c in palette]
    for g in range(1,7):
        cells_path=BUILD/f'cpu-game{g}.cells' if g<=4 else BUILD/('native-letter-envelope.cells' if g==5 else 'native-letter-full.cells')
        cells=[int(s,16) for s in cells_path.read_text().split()]
        assert len(cells)==1200
        if g==3:assert sum((cells[y*40+x]&255)==4 for y in range(5,25) for x in range(12,22))>=8,'C hard drop did not create locked blocks'
        if g==4:assert sum((cell&255)>=128 for cell in cells)>20,'Chinese text was not written by CPU'
        actual=bytes.fromhex(''.join((BUILD/f'preview{g}.hex').read_text().split()))
        assert len(actual)==640*480*3
        golden=bytearray()
        for y in range(480):
            for x in range(640):
                cell=cells[(y>>4)*40+(x>>4)]
                bit=(font[(cell&255)*16+(y&15)]>>(15-(x&15)))&1
                golden.extend(palette[(cell>>8)&15 if bit else (cell>>12)&15])
        assert actual==golden,f'Pixel/color/latency mismatch in game {g}'
        def chunk(name,data):return struct.pack('>I',len(data))+name+data+struct.pack('>I',zlib.crc32(name+data)&0xffffffff)
        raw=b''.join(b'\0'+actual[y*1920:(y+1)*1920] for y in range(480))
        png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',640,480,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b'')
        (BUILD/f'preview{g}.png').write_bytes(png)
    return 6*640*480

try:
    # Rebuild the same C firmware, then reuse CPU evidence only if every byte matches.
    c=['firmware/ui.c','firmware/snake.c','firmware/maze.c','firmware/blocks.c','firmware/letter.c']
    run('native-compile',wsl(['gcc','-std=c11','-O1','-g','-Wall','-Wextra','-Werror','-fsanitize=address,undefined','-fno-omit-frame-pointer','-DHOST_TEST','-I','firmware']+c+['sim/native_tests.c','-o','build/native-tests']))
    run('native-tests',wsl(['./build/native-tests']))
    run('firmware-compile',wsl(['riscv64-unknown-elf-gcc','-march=rv32imc','-mabi=ilp32','-mno-relax','-msmall-data-limit=0','-Os','-ffreestanding','-fno-builtin','-ffunction-sections','-fdata-sections','-fstack-usage','-Wall','-Wextra','-Werror','-nostdlib','-nostartfiles','-T','firmware/link.ld','-Wl,--gc-sections','-Wl,-Map,build/firmware.map','firmware/start.S','firmware/main.c']+c+['-o','build/firmware.elf']))
    run('firmware-binary',wsl(['riscv64-unknown-elf-objcopy','-O','binary','build/firmware.elf','build/firmware.bin']))
    binary=(out/'firmware.bin').read_bytes();assert len(binary)<=16384
    image=binary+bytes(16384-len(binary))
    (out/'firmware.hex').write_text(''.join(f'{v[0]:08x}\n' for v in struct.iter_unpack('<I',image)))
    proof_file=out/'cpu-proof.json'
    proof=json.loads(proof_file.read_text()) if proof_file.exists() else {}
    reusable=proof.get('inputs')==cpu_inputs() and all(hashlib.sha256((root/p).read_bytes()).hexdigest()==h for p,h in proof.get('outputs',{}).items())
    if reusable:
        stages.extend([{**s,'reused_with_matching_sha256':True} for s in proof['stages']])
        print('CPU RTL simulation reused: all firmware, RTL, testbench and output hashes match',flush=True)
    else:
        rtl=['src/vendor/picorv32.v','src/vendor/simpleuart.v','src/risc_soc.v']
        run('soc-compile',wsl(['iverilog','-g2012','-I','src/vendor','-s','soc_tb','-o','build/soc.vvp']+rtl+['sim/soc_tb.v']))
        run('soc-sim',wsl(['vvp','build/soc.vvp']))
        assert 'TEST PASS:' in (out/'soc-sim.log').read_text()
        outputs=[out/f'cpu-game{g}.cells' for g in range(1,5)]+[out/'soc-sim.log']
        proof_file.write_text(json.dumps({'inputs':cpu_inputs(),'outputs':{p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in outputs},'stages':stages[-2:]},indent=2)+'\n')
    run('stock-compile',wsl(['iverilog','-g2012','-I','src','-I','src/hdmi','-s','stock_tb','-o','build/stock.vvp','src/video_timing.v','src/tile_video.v','src/tile_stream.v','src/hdmi/svo_enc.v','sim/stock_tb.v']))
    run('stock-sim',wsl(['vvp','build/stock.vvp']))
    assert 'TEST PASS:' in (out/'stock-sim.log').read_text()
    checked_pixels=image_checks()
    run('vendor-build',[tool,'stock_build.tcl'])
    report=(root/'impl/pnr/risc-playground_tr_content.html').read_text(errors='replace')
    rows=[cells(r) for r in re.findall(r'<tr\b[^>]*>(.*?)</tr>',report,re.S|re.I)]
    summary={r[0]:r[1] for r in rows if len(r)==2}
    setup=int(summary['Numbers of Setup Violated Endpoints']);hold=int(summary['Numbers of Hold Violated Endpoints'])
    assert setup==0 and hold==0,f'STA violations: setup={setup}, hold={hold}'
    fmax=[r for r in rows if len(r)==6 and '(MHz)' in r[2]]
    assert fmax and all(float(r[3].split('(')[0])>=float(r[2].split('(')[0]) for r in fmax)
    if (out/'risc-playground.fs').exists():(out/'risc-playground.fs').chmod(stat.S_IREAD|stat.S_IWRITE)
    shutil.copyfile(root/'impl/pnr/risc-playground.fs',out/'risc-playground.fs')
    run('frame-crcs',wsl([os.environ.get('FPGA_PYTHON','/opt/fpga-tools/hdmi/venv/bin/python'),'-c','from apycula import bslib; bslib.read_bitstream("build/risc-playground.fs"); print("ALL_FRAME_CRCS_PASS")']))
    bitstream=prepare(out/'risc-playground.fs',out/'risc-playground-gowin.fs')
    result={'overall_result':'PASS','stages':stages,'simulation_features_passed':True,'timing_passed':True,
            'simulated_features':'CPU VRAM controls, stream backpressure, pixel byte order, full raster geometry and frame tick',
            'setup_violated_endpoints':setup,'hold_violated_endpoints':hold,
            'fmax_estimates':fmax,'bitstream':bitstream,'all_frame_crcs_passed':True,
            'source_note':'Stock Sipeed clock/reset/video output; CPU VRAM supplies the visible pixel stream',
            'compiler':'Gowin V1.9.11.03 Education','compiler_path':str(tool),
            'hardware_programming_performed_by_build':False,
            'video':{'width':640,'height':480,'total_width':800,'total_height':525,'pixel_clock_mhz':25.2,'serializer_clock_mhz':126,'refresh_hz':60,'audio':False},
            'source_sha256':{p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in list((root/'src').rglob('*'))+list((root/'firmware').glob('*'))+list((root/'assets').glob('*'))+[out/'firmware.hex',root/'hdmi.gprj'] if p.is_file()},
            'cpu_present':True,'game_present':True,'firmware_bytes':len(binary),'checked_pixels':checked_pixels,'physical_display_observation_performed':False}
except Exception as error:
    result={'overall_result':'FAIL','stages':stages,'error':str(error)}
    (out/'build-result.json').write_text(json.dumps(result,indent=2)+'\n');raise
(out/'build-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'result':'PASS','user_code':bitstream['expected_user_code'],'fmax':fmax}),flush=True)

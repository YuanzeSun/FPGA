import hashlib,html,json,os,re,shutil,stat,subprocess,time
from pathlib import Path
from prepare_gowin_fs import prepare

root=Path(__file__).resolve().parents[1];out=root/'build'
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
        p=subprocess.run([str(x) for x in args],cwd=root,stdout=log,stderr=subprocess.STDOUT,timeout=240)
    stages.append({'stage':name,'exit_code':p.returncode,'elapsed_seconds':round(time.monotonic()-started,3)})
    assert p.returncode==0,(out/f'{name}.log').read_text(errors='replace')[-3500:]
def cells(row):
    return [' '.join(html.unescape(re.sub('<[^>]+>',' ',c)).split()) for c in re.findall(r'<t[dh]\b[^>]*>(.*?)</t[dh]>',row,re.S|re.I)]
try:
    game=['src/game/svo_pong.v','src/game/simpleuart.v','src/game/pong_system.v','src/game/pong_render.v','src/game/video_timing.v']
    run('stock-compile',wsl(['iverilog','-g2012','-I','src','-I','src/hdmi','-s','stock_tb','-o','build/stock.vvp']+game+['src/pong_stream.v','src/hdmi/svo_enc.v','sim/stock_tb.v']))
    run('system-compile',wsl(['iverilog','-g2012','-I','src','-I','src/hdmi','-s','system_tb','-o','build/system.vvp']+game+['sim/system_tb.v']))
    run('system-sim',wsl(['vvp','build/system.vvp']))
    assert 'TEST PASS:' in (out/'system-sim.log').read_text()
    run('stock-sim',wsl(['vvp','build/stock.vvp']))
    assert 'TEST PASS:' in (out/'stock-sim.log').read_text()
    run('vendor-build',[tool,'stock_build.tcl'])
    report=(root/'impl/pnr/hdmi-pong_tr_content.html').read_text(errors='replace')
    rows=[cells(r) for r in re.findall(r'<tr\b[^>]*>(.*?)</tr>',report,re.S|re.I)]
    summary={r[0]:r[1] for r in rows if len(r)==2}
    setup=int(summary['Numbers of Setup Violated Endpoints']);hold=int(summary['Numbers of Hold Violated Endpoints'])
    assert setup==0 and hold==0,f'STA violations: setup={setup}, hold={hold}'
    fmax=[r for r in rows if len(r)==6 and '(MHz)' in r[2]]
    assert fmax and all(float(r[3].split('(')[0])>=float(r[2].split('(')[0]) for r in fmax)
    if (out/'hdmi-pong.fs').exists():(out/'hdmi-pong.fs').chmod(stat.S_IREAD|stat.S_IWRITE)
    shutil.copyfile(root/'impl/pnr/hdmi-pong.fs',out/'hdmi-pong.fs')
    run('frame-crcs',wsl([os.environ.get('FPGA_PYTHON','/opt/fpga-tools/hdmi/venv/bin/python'),'-c','from apycula import bslib; bslib.read_bitstream("build/hdmi-pong.fs"); print("ALL_FRAME_CRCS_PASS")']))
    bitstream=prepare(out/'hdmi-pong.fs',out/'hdmi-pong-gowin.fs')
    result={'overall_result':'PASS','stages':stages,'simulation_features_passed':True,'timing_passed':True,
            'simulated_features':'Pong controls, stream backpressure, pixel byte order, full raster geometry and frame tick',
            'setup_violated_endpoints':setup,'hold_violated_endpoints':hold,
            'fmax_estimates':fmax,'bitstream':bitstream,'all_frame_crcs_passed':True,
            'source_note':'Stock Sipeed clock/reset/video output; Pong supplies the visible pixel stream',
            'compiler':'Gowin V1.9.11.03 Education','compiler_path':str(tool),
            'video':{'width':640,'height':480,'total_width':800,'total_height':525,'pixel_clock_mhz':25.2,'serializer_clock_mhz':126,'refresh_hz':60,'audio':False},
            'sources_sha256':{p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'src').rglob('*') if p.is_file()},
            'cpu_present':False,'game_present':True,'physical_display_observation_performed':False}
except Exception as error:
    result={'overall_result':'FAIL','stages':stages,'error':str(error)}
    (out/'build-result.json').write_text(json.dumps(result,indent=2)+'\n');raise
(out/'build-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'result':'PASS','user_code':bitstream['expected_user_code'],'fmax':fmax}),flush=True)

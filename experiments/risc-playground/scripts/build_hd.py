"""Build validated 720p60/1080p30/custom 1080p45 CPU demos. No USB access."""
import argparse
import hashlib
import html
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

from prepare_gowin_fs import prepare

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/hd"
MODES = {"720p60": (1280, 720, 1650, 750, 60),
         "1080p30": (1920, 1080, 2200, 1125, 30),
         "1080p45": (1920, 1080, 2080, 1125, 45)}
LINUX_ROOT = "/mnt/" + ROOT.drive[0].lower() + ROOT.as_posix()[2:]


def hashes(paths):
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


def inputs(mode):
    paths = sorted(p for p in (ROOT / "src/hd").glob("*") if p.is_file())
    paths += [ROOT / p for p in ["src/vendor/picorv32.v", "src/vendor/simpleuart.v", "src/risc_soc.v",
        "src/gowin_rpll/gowin_rpll.v", "src/gowin_clkdiv/gowin_clkdiv.v", "src/hdmi.cst",
        "assets/font.hex", "build/firmware.hex",
        "hd_1080p45.gprj" if mode == "1080p45" else "hd.gprj", f"hd_{mode}.tcl"]]
    paths += [p for p in (ROOT / "firmware").glob("*") if p.is_file()]
    return hashes(paths)


def test_inputs(name):
    if name == "tmds":
        files = ["src/hd/hd_tmds.v", "src/hdmi/svo_tmds.v", "sim/hd_tmds_tb.v"]
    elif name == "swap":
        files = ["src/hd/hd_tile_stream.v", "sim/hd_swap_tb.v", "assets/font.hex"]
    else:
        files = ["src/hd/hd_tile_stream.v", "src/hd/hd_svo_enc.v", "sim/hd_video_tb.v",
                 "assets/font.hex", "build/cpu-game3.cells", "build/cpu-game4.cells"]
    return hashes([ROOT / f for f in files])


def wsl(args):
    return ["wsl.exe", "-d", "Ubuntu-24.04", "--cd", LINUX_ROOT, "--exec"] + args


def run(log, args):
    print("Running " + log.name, flush=True)
    with log.open("wb") as output:
        result = subprocess.run([str(a) for a in args], cwd=ROOT, stdout=output,
                                stderr=subprocess.STDOUT, timeout=900)
    assert result.returncode == 0, log.read_text(errors="replace")[-3500:]


def timing(mode):
    report = (ROOT / f"impl/pnr/hd-{mode}_tr_content.html").read_text(errors="replace")
    rows = [[" ".join(html.unescape(re.sub("<[^>]+>", " ", cell)).split())
             for cell in re.findall(r"<t[dh]\b[^>]*>(.*?)</t[dh]>", row, re.S | re.I)]
            for row in re.findall(r"<tr\b[^>]*>(.*?)</tr>", report, re.S | re.I)]
    summary = {r[0]: r[1] for r in rows if len(r) == 2}
    assert int(summary["Numbers of Setup Violated Endpoints"]) == 0
    assert int(summary["Numbers of Hold Violated Endpoints"]) == 0
    fmax = [r for r in rows if len(r) == 6 and "(MHz)" in r[2]]
    assert len(fmax) >= 2 and all(float(r[3].split("(")[0]) >= float(r[2].split("(")[0]) for r in fmax)
    return fmax


def test(name, force):
    proof_path = OUT / (name + "-proof.json")
    log = OUT / (name + ".log")
    expected = test_inputs(name)
    proof = json.loads(proof_path.read_text()) if proof_path.exists() else {}
    if not force and proof.get("inputs") == expected and log.exists() and proof.get("log_sha256") == hashlib.sha256(log.read_bytes()).hexdigest():
        assert "TEST PASS:" in log.read_text()
        print("Reusing checked simulation: " + name, flush=True)
        return
    if name == "tmds":
        top = "hd_tmds_tb"
        files = ["src/hd/hd_tmds.v", "src/hdmi/svo_tmds.v", "sim/hd_tmds_tb.v"]
        params = ["-I", "src/hdmi"]
    elif name == "swap":
        top = "hd_swap_tb"
        files = ["src/hd/hd_tile_stream.v", "sim/hd_swap_tb.v"]
        params = []
    else:
        top = "hd_video_tb"
        files = ["src/hd/hd_tile_stream.v", "src/hd/hd_svo_enc.v", "sim/hd_video_tb.v"]
        params = ["-P", "hd_video_tb.HD1080=" + ("1" if "1080p" in name else "0"),
                  "-P", "hd_video_tb.HD45=" + ("1" if name.endswith("1080p45") else "0")]
    executable = "build/hd/" + name + ".vvp"
    run(OUT / (name + "-compile.log"), wsl(["iverilog", "-g2012", "-s", top] + params + ["-o", executable] + files))
    run(log, wsl(["vvp", executable]))
    assert "TEST PASS:" in log.read_text()
    proof_path.write_text(json.dumps({"inputs": expected, "log_sha256": hashlib.sha256(log.read_bytes()).hexdigest()}, indent=2) + "\n")


def build(mode, force):
    out = OUT / mode
    out.mkdir(exist_ok=True)
    metadata = out / "build-result.json"
    previous = json.loads(metadata.read_text()) if metadata.exists() else {}
    fs = out / ("hd-" + mode + "-gowin.fs")
    if not force and previous.get("overall_result") == "PASS" and previous.get("source_sha256") == inputs(mode) and fs.exists():
        assert hashlib.sha256(fs.read_bytes()).hexdigest() == previous["bitstream"]["output_sha256"]
        timing(mode)
        print("Reusing validated bitstream: " + mode, flush=True)
        return
    metadata.write_text(json.dumps({"overall_result": "BUILDING", "mode": mode}) + "\n")
    try:
        config_path = ROOT / "scripts/toolchain.local.json"
        config = json.loads(config_path.read_text()) if config_path.exists() else {}
        compiler = os.environ.get("GOWIN_SH") or config.get("gowin_sh")
        assert compiler and Path(compiler).is_file(), "Set GOWIN_SH to the Gowin gw_sh.exe path"
        run(OUT / ("vendor-" + mode + ".log"), [compiler, "hd_" + mode + ".tcl"])
        fmax = timing(mode)
        raw = out / ("hd-" + mode + ".fs")
        shutil.copyfile(ROOT / f"impl/pnr/hd-{mode}.fs", raw)
        check = f'from apycula import bslib; bslib.read_bitstream("build/hd/{mode}/hd-{mode}.fs"); print("ALL_FRAME_CRCS_PASS")'
        run(out / "frame-crcs.log", wsl([os.environ.get("FPGA_PYTHON","/opt/fpga-tools/hdmi/venv/bin/python"), "-c", check]))
        assert "ALL_FRAME_CRCS_PASS" in (out / "frame-crcs.log").read_text()
        width, height, totalx, totaly, hz = MODES[mode]
        result = {"overall_result": "PASS", "simulation_features_passed": True, "timing_passed": True,
            "setup_violated_endpoints": 0, "hold_violated_endpoints": 0, "fmax_estimates": fmax,
            "bitstream": prepare(raw, fs), "source_sha256": inputs(mode), "mode": mode,
            "all_frame_crcs_passed": True, "cpu_present": True, "cpu_clock_mhz": 25.2, "game_timer_hz": 60,
            "video": {"width": width, "height": height, "total_width": totalx, "total_height": totaly,
                      "refresh_hz": hz, "pixel_clock_mhz": 105.3 if mode == "1080p45" else 74.25,
                      "serializer_clock_mhz": 526.5 if mode == "1080p45" else 371.25,
                      "custom_reduced_blanking": mode == "1080p45"},
            "physical_display_observation_performed": False, "sram_programming_performed": False}
        metadata.write_text(json.dumps(result, indent=2) + "\n")
        print("Built " + mode + ": " + result["bitstream"]["expected_user_code"], flush=True)
    except Exception as error:
        metadata.write_text(json.dumps({"overall_result": "FAIL", "mode": mode, "error": str(error)}, indent=2) + "\n")
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=["all", "both"] + list(MODES), default="all")
    parser.add_argument("--force", action="store_true", help="Re-run checked simulations and rebuild")
    args = parser.parse_args()
    OUT.mkdir(exist_ok=True)
    proof = json.loads((ROOT / "build/cpu-proof.json").read_text())
    for group in ("inputs", "outputs"):
        for rel, digest in proof[group].items():
            assert hashlib.sha256((ROOT / rel).read_bytes()).hexdigest() == digest, "CPU evidence changed: " + rel
    modes = list(MODES) if args.mode == "all" else list(MODES)[:2] if args.mode == "both" else [args.mode]
    for name in ["tmds", "swap"] + ["video-" + mode for mode in modes]:
        test(name, args.force)
    for mode in modes:
        build(mode, args.force)


if __name__ == "__main__":
    main()

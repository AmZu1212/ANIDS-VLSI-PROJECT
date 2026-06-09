#!/usr/bin/env python3

import shutil
import subprocess
import sys
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC_DIR = ROOT / "ANIDS" / "src"
TB_DIR = ROOT / "ANIDS" / "tb"
OUT_BASENAME = "sim"
OUT_DIR = ROOT / "Outputs"
SIM_OUT_DIR = OUT_DIR / "out"
VCD_DIR = OUT_DIR / "vcd"


def usage() -> None:
    print("Usage: python run.py <tb_filename.sv>")
    print("Example: python run.py my_tb.sv")


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        usage()
        return 1

    # Resolve testbench path (absolute or relative). If only a name is given, search under TB_DIR.
    tb_arg = Path(argv[1])
    if tb_arg.is_file():
        tb_path = tb_arg.resolve()
    else:
        matches = sorted(TB_DIR.rglob(tb_arg.name))
        if len(matches) == 1:
            tb_path = matches[0].resolve()
        elif len(matches) > 1:
            print(f"Testbench name is ambiguous: {tb_arg.name}")
            for match in matches:
                print(f"  - {match}")
            return 1
        else:
            tb_path = (TB_DIR / tb_arg.name).resolve()
    if not tb_path.is_file():
        print(f"Testbench file not found: {tb_arg}")
        return 1

    top_module = tb_path.stem
    SIM_OUT_DIR.mkdir(parents=True, exist_ok=True)
    VCD_DIR.mkdir(parents=True, exist_ok=True)
    sim_out_path = SIM_OUT_DIR / f"{OUT_BASENAME}_{top_module}.out"
    src_files = sorted(SRC_DIR.rglob("*.sv"))
    sources = [tb_path] + src_files

    # Build include path list, deduplicated
    include_paths = [
        ROOT / "ANIDS",
        TB_DIR,
        tb_path.parent,
    ]
    include_paths.extend(path for path in SRC_DIR.rglob("*") if path.is_dir())
    include_paths.extend(path for path in TB_DIR.rglob("*") if path.is_dir())
    seen = set()
    include_args = []
    for inc in include_paths:
        inc_str = str(inc.resolve())
        if inc_str in seen:
            continue
        seen.add(inc_str)
        include_args.extend(["-I", inc_str])
    source_args = [str(p) for p in sources]

    # Resolve tools
    iverilog = shutil.which("iverilog")
    vvp = shutil.which("vvp")
    gtkwave = shutil.which("gtkwave")

    if iverilog is None:
        print("Error: 'iverilog' not found on PATH. Install Icarus Verilog and retry.")
        return 1
    if vvp is None:
        print("Error: 'vvp' not found on PATH. Install Icarus Verilog and retry.")
        return 1

    cmd = [iverilog, "-g2012", *include_args, "-s", top_module, "-o", str(sim_out_path), *source_args]

    print("Compiling:")
    print(" ".join(cmd))
    subprocess.run(cmd, check=True)

    print("Running simulation:")
    subprocess.run([vvp, str(sim_out_path)], check=True)

    # Move the generated waveform into a stable per-testbench path.
    vcd_candidates = [
        f"{top_module}.vcd",
        f"{top_module}_tb.vcd",
        "wave.vcd",
    ]
    vcd_to_open = None
    for cand in vcd_candidates:
        for candidate in (ROOT / cand, OUT_DIR / cand, VCD_DIR / cand):
            if not candidate.exists():
                continue
            vcd_dest = VCD_DIR / f"{top_module}.vcd"
            if candidate.resolve() != vcd_dest.resolve():
                if vcd_dest.exists():
                    vcd_dest.unlink()
                moved = shutil.move(str(candidate), str(vcd_dest))
                vcd_to_open = Path(moved)
            else:
                vcd_to_open = candidate
            break
        if vcd_to_open:
            break
    if vcd_to_open:
        try:
            vcd_rel = vcd_to_open.relative_to(ROOT)
        except ValueError:
            vcd_rel = vcd_to_open.name
        vcd_posix = Path(vcd_rel).as_posix()
        vcd_win = str(vcd_to_open)
        print(f"\nVCD generated: {vcd_win}")
        print(f"To view (bash/mingw): gtkwave ./{vcd_posix}")
        print(f"To view (cmd/PowerShell): gtkwave \"{vcd_win}\"")

        # Auto-launch GTKWave if available
        if gtkwave and not os.environ.get("ANIDS_NO_GTKWAVE"):
            try:
                subprocess.Popen([gtkwave, vcd_win], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except Exception as e:
                print(f"Note: failed to launch gtkwave automatically ({e}).")
        else:
            print("Note: 'gtkwave' not found on PATH; not auto-launching.")
    else:
        print("\nNote: no VCD file found to open.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

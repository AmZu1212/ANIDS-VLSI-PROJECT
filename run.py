#!/usr/bin/env python3

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC_DIR = ROOT / "ANIDS" / "src"
TB_DIR = ROOT / "ANIDS" / "tb"
OUT_BASENAME = "sim"
OUT_DIR = ROOT / "outputs"


def usage() -> None:
    print("Usage: python run.py <tb_filename.v>")
    print("Example: python run.py my_tb.v")


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        usage()
        return 1

    # Resolve testbench path (absolute or relative). If only a name is given, fall back to TB_DIR.
    tb_arg = Path(argv[1])
    tb_path = tb_arg if tb_arg.is_file() else (TB_DIR / tb_arg.name)
    tb_path = tb_path.resolve()
    if not tb_path.is_file():
        print(f"Testbench file not found: {tb_arg}")
        return 1

    top_module = tb_path.stem
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out_path = OUT_DIR / f"{OUT_BASENAME}_{top_module}.out"
    src_files = sorted(SRC_DIR.glob("*.v"))
    sources = [tb_path] + src_files

    # Build include path list, deduplicated
    include_paths = [
        ROOT / "ANIDS",
        SRC_DIR,
        TB_DIR,
        tb_path.parent,
    ]
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

    cmd = [iverilog, "-g2012", *include_args, "-s", top_module, "-o", str(out_path), *source_args]

    print("Compiling:")
    print(" ".join(cmd))
    subprocess.run(cmd, check=True)

    print("Running simulation:")
    subprocess.run([vvp, str(out_path)], check=True)

    # Report VCD file to open manually
    vcd_candidates = [
        f"{top_module}.vcd",
        f"{top_module}_tb.vcd",
        "wave.vcd",
    ]
    vcd_to_open = None
    for cand in vcd_candidates:
        root_path = ROOT / cand
        out_path_candidate = OUT_DIR / cand
        if root_path.exists():
            OUT_DIR.mkdir(parents=True, exist_ok=True)
            if out_path_candidate.exists():
                out_path_candidate.unlink()
            moved = shutil.move(str(root_path), str(out_path_candidate))
            vcd_to_open = Path(moved)
            break
        if out_path_candidate.exists():
            vcd_to_open = out_path_candidate
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
        if gtkwave:
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

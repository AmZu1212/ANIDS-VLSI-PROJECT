#!/usr/bin/env python3

import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC_DIR = ROOT / "ANIDS" / "src"
TB_DIR = ROOT / "ANIDS" / "tb"
OUT = ROOT / "sim.out"

tb_top = TB_DIR / "rw_tb.v"
src_files = sorted(SRC_DIR.glob("*.v"))
sources = [tb_top] + src_files

include_args = f"-I {ROOT/'ANIDS'} -I {SRC_DIR} -I {TB_DIR}"
source_args = " ".join(str(p) for p in sources)
cmd = f"iverilog -g2012 {include_args} -s rw_tb -o {OUT} {source_args}"

os.system(cmd)
os.system(f"vvp {OUT}")
subprocess.Popen(["gtkwave", "wave.vcd"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

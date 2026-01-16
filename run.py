import os

os.system(
    "iverilog -g2012 -I ANIDS -I ANIDS/src -I ANIDS/tb "
    "-s rw_tb -o sim.out ANIDS/tb/rw_tb.v ANIDS/src/anids_top.v"
)

os.system("vvp sim.out")

os.system("gtkwave wave.vcd")

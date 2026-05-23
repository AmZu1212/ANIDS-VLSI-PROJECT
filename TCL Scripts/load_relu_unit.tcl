# Set core count
set_host_options -max_cores 8

# Load custom SRAM library
read_db spram8x256_cb_typ.db

# Set libraries
set_app_var target_library [list tsl18fs120_typ.db spram8x256_cb_typ.db]
set_app_var link_library   [list * tsl18fs120_typ.db spram8x256_cb_typ.db dw_foundation.sldb]


# Set max loop iteration limit (needed for regfile analysis)
set_app_var hdlin_while_loop_iterations 20000


# load RTLs manually
set_app_var search_path [concat $search_path [list ANIDS-VLSI-PROJECT/ANIDS ANIDS-VLSI-PROJECT/ANIDS/src ANIDS-VLSI-PROJECT/ANIDS/src/core]]

set analyze_t0 [clock seconds]
analyze -format sverilog {
	ANIDS-VLSI-PROJECT/ANIDS/src/core/relu_unit.sv
}
puts "Analyze time: [expr {[clock seconds] - $analyze_t0}] seconds"

set elaborate_t0 [clock seconds]
elaborate relu_unit
puts "Elaborate time: [expr {[clock seconds] - $elaborate_t0}] seconds"

# Set top
current_design relu_unit

# Link and check
set link_t0 [clock seconds]
link
puts "Link time: [expr {[clock seconds] - $link_t0}] seconds"

set check_design_t0 [clock seconds]
check_design
puts "Check design time: [expr {[clock seconds] - $check_design_t0}] seconds"

# relu_unit is combinational and has no clk port, so no clock is created.

# Protect SRAM macro instances
set_dont_touch [get_cells -hier *function_lut*]
puts "SRAM macro instances protected: [sizeof_collection [get_cells -hier *function_lut*]]"

set write_ddc_t0 [clock seconds]
write -format ddc -hierarchy -output relu_unit_precompile.ddc
puts "Write DDC time: [expr {[clock seconds] - $write_ddc_t0}] seconds"

# Run Compile
set compile_t0 [clock seconds]
compile
puts "Compile time: [expr {[clock seconds] - $compile_t0}] seconds"

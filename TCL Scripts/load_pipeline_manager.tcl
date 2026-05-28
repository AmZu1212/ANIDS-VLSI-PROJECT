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
	ANIDS-VLSI-PROJECT/ANIDS/src/core/pipeline_manager.sv
}
puts "Analyze time: [expr {[clock seconds] - $analyze_t0}] seconds"

set elaborate_t0 [clock seconds]
elaborate pipeline_manager
puts "Elaborate time: [expr {[clock seconds] - $elaborate_t0}] seconds"

# Set top
current_design pipeline_manager

# Link and check
set link_t0 [clock seconds]
link
puts "Link time: [expr {[clock seconds] - $link_t0}] seconds"

set check_design_t0 [clock seconds]
check_design
puts "Check design time: [expr {[clock seconds] - $check_design_t0}] seconds"

# Create clk signal
create_clock -name clk -period 5 [get_ports clk]
# report_clocks

# Protect SRAM macro instances if present
set function_lut_cells [get_cells -hier *function_lut*]
if {[sizeof_collection $function_lut_cells] > 0} {
	set_dont_touch $function_lut_cells
}
puts "SRAM macro instances protected: [sizeof_collection $function_lut_cells]"

set write_ddc_t0 [clock seconds]
write -format ddc -hierarchy -output pipeline_manager_precompile.ddc
puts "Write DDC time: [expr {[clock seconds] - $write_ddc_t0}] seconds"

# Run Compile
set compile_t0 [clock seconds]
compile
puts "Compile time: [expr {[clock seconds] - $compile_t0}] seconds"

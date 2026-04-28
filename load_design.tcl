# set core count
set_host_options -max_cores 8

# Load custom SRAM library
read_db spram8x256_cb_typ.db

# Set libraries
set_app_var target_library [list tsl18fs120_typ.db spram8x256_cb_typ.db]
set_app_var link_library   [list * tsl18fs120_typ.db spram8x256_cb_typ.db dw_foundation.sldb]


# load RTLS manually

set_app_var search_path [concat $search_path [list ANIDS-VLSI-PROJECT/ANIDS ANIDS-VLSI-PROJECT/ANIDS/src ANIDS-VLSI-PROJECT/ANIDS/src/core]]

set analyze_t0 [clock seconds]
analyze -format sverilog {
	ANIDS-VLSI-PROJECT/ANIDS/src/anids_core.sv
	ANIDS-VLSI-PROJECT/ANIDS/src/anids_top.sv
	ANIDS-VLSI-PROJECT/ANIDS/src/mem_fetch_unit.sv
	ANIDS-VLSI-PROJECT/ANIDS/src/regfile.sv
	ANIDS-VLSI-PROJECT/ANIDS/src/result_status_encoder.sv
	ANIDS-VLSI-PROJECT/ANIDS/src/core/hidden_layer.sv
	ANIDS-VLSI-PROJECT/ANIDS/src/core/hidden_layer_unit.sv
	ANIDS-VLSI-PROJECT/ANIDS/src/core/input_layer.sv
	ANIDS-VLSI-PROJECT/ANIDS/src/core/lookup_layer.sv
	ANIDS-VLSI-PROJECT/ANIDS/src/core/loss_function.sv
	ANIDS-VLSI-PROJECT/ANIDS/src/core/memory_mapper.sv
	ANIDS-VLSI-PROJECT/ANIDS/src/core/outlier_detector.sv
	ANIDS-VLSI-PROJECT/ANIDS/src/core/output_layer.sv
	ANIDS-VLSI-PROJECT/ANIDS/src/core/output_layer_processing_unit.sv
	ANIDS-VLSI-PROJECT/ANIDS/src/core/pipeline_manager.sv
	ANIDS-VLSI-PROJECT/ANIDS/src/core/relu_unit.sv
}
puts "Analyze time: [expr {[clock seconds] - $analyze_t0}] seconds"

set elaborate_t0 [clock seconds]
elaborate anids_top
puts "Elaborate time: [expr {[clock seconds] - $elaborate_t0}] seconds"




# Load saved design - optional for later...
#read_ddc anids_top.ddc

# Set top
current_design anids_top

# Link and check
link
check_design

# Create clk signal
create_clock -name sys_clk -period 5 [get_ports sys_clk]
#report_clocks

# Run Compile (takes logn so commented)
#compile

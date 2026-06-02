# Load the compiled pipeline_manager design into Design Vision.
# Run from the Design Vision Tcl console with:
#   source {ANIDS-VLSI-PROJECT/TCL Scripts/load_ddc.tcl}

set_host_options -max_cores 8

# Match the library configuration used during synthesis.
read_db spram8x256_cb_typ.db
set_app_var target_library [list tsl18fs120_typ.db spram8x256_cb_typ.db]
set_app_var link_library   [list * tsl18fs120_typ.db spram8x256_cb_typ.db dw_foundation.sldb]

# Resolve the DDC path relative to this script so the loader is independent
# of the directory from which Design Vision was started.
set script_dir [file dirname [file normalize [info script]]]
set project_dir [file dirname $script_dir]
set ddc_file [file join $project_dir {Saved ddc} pipeline_manager_compiled.ddc]

if {![file exists $ddc_file]} {
	error "Compiled DDC file not found: $ddc_file"
}

read_ddc $ddc_file
current_design pipeline_manager
link
check_design

puts "Loaded compiled design: [current_design]"
puts "DDC file: $ddc_file"
puts "Use report_qor, report_area -hierarchy, or report_timing -max_paths 10 to view reports."

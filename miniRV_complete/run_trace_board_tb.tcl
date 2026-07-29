set script_dir [file dirname [file normalize [info script]]]
set trace_image [file join $script_dir software trace start.hex]
set trace_banks [list]

if {![file exists $trace_image]} {
    error "Missing software/trace/start.hex. Run tools/bin2coe.py first."
}
for {set bank 0} {$bank < 5} {incr bank} {
    set bank_file [file join $script_dir software trace \
        "start_bank${bank}.hex"]
    if {![file exists $bank_file]} {
        error "Missing $bank_file."
    }
    lappend trace_banks $bank_file
}

add_files -norecurse -fileset sim_1 \
    [file join $script_dir src sim trace_board_tb.v]
add_files -norecurse -fileset sim_1 $trace_banks
set_property file_type {Memory Initialization Files} \
    [get_files $trace_banks]
set_property top trace_board_tb [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
run all

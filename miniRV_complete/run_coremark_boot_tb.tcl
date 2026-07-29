set script_dir [file dirname [file normalize [info script]]]
set coremark_image [file join $script_dir software coremark coremark.hex]
set coremark_banks [list]

if {![file exists $coremark_image]} {
    error "Missing software/coremark/coremark.hex."
}
for {set bank 0} {$bank < 5} {incr bank} {
    set bank_file [file join $script_dir software coremark \
        "coremark_bank${bank}.hex"]
    if {![file exists $bank_file]} {
        error "Missing $bank_file."
    }
    lappend coremark_banks $bank_file
}

add_files -norecurse -fileset sim_1 \
    [file join $script_dir src sim coremark_boot_tb.v]
add_files -norecurse -fileset sim_1 $coremark_banks
set_property file_type {Memory Initialization Files} \
    [get_files $coremark_banks]
set_property verilog_define {SOC_SIM} [get_filesets sim_1]
set_property top coremark_boot_tb [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
run all

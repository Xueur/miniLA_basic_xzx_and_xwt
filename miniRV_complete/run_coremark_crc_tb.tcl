set script_dir [file dirname [file normalize [info script]]]
set project_file [file join $script_dir vivado_coremark_board_50MHz \
    miniRV_coremark_board_50MHz.xpr]
if {[llength [get_projects -quiet]] == 0} {
    if {![file exists $project_file]} {
        error "Create the CoreMark project first."
    }
    open_project $project_file
}

set coremark_banks [list]
for {set bank 0} {$bank < 5} {incr bank} {
    set bank_file [file join $script_dir software coremark \
        "coremark_bank${bank}.hex"]
    if {![file exists $bank_file]} {
        error "Missing $bank_file."
    }
    lappend coremark_banks $bank_file
}

set tb_file [file join $script_dir src sim coremark_crc_tb.v]
if {[llength [get_files -quiet $tb_file]] == 0} {
    add_files -norecurse -fileset sim_1 $tb_file
}
foreach bank_file $coremark_banks {
    if {[llength [get_files -quiet $bank_file]] == 0} {
        add_files -norecurse -fileset sim_1 $bank_file
    }
}
set_property file_type {Memory Initialization Files} \
    [get_files $coremark_banks]
set_property verilog_define {SOC_SIM} [get_filesets sim_1]
set_property top coremark_crc_tb [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
run all

set script_dir [file dirname [file normalize [info script]]]
set project_file [file join $script_dir vivado_coremark_board_50MHz \
    miniRV_coremark_board_50MHz.xpr]
if {[llength [get_projects -quiet]] == 0} {
    if {![file exists $project_file]} {
        error "Create the CoreMark project first."
    }
    open_project $project_file
}

set tb_file [file join $script_dir src sim mem_response_hazard_tb.v]
if {[llength [get_files -quiet $tb_file]] == 0} {
    add_files -norecurse -fileset sim_1 $tb_file
}
set_property verilog_define {} [get_filesets sim_1]
set_property top mem_response_hazard_tb [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
run all

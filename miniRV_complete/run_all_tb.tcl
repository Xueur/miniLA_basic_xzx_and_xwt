set script_dir [file dirname [file normalize [info script]]]
set opened_here 0
if {[llength [get_projects -quiet]] == 0} {
    open_project [file join $script_dir vivado_lab2 miniRV_lab2.xpr]
    set opened_here 1
}

set tb_file [file join $script_dir src sim cpu_core_all_tb.v]
if {[llength [get_files -quiet $tb_file]] == 0} {
    add_files -fileset sim_1 $tb_file
}
set_property top cpu_core_all_tb [get_filesets sim_1]
set_property verilog_define {} [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
run all
close_sim
if {$opened_here} {
    close_project
}

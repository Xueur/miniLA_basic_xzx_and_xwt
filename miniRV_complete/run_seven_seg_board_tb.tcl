set script_dir [file dirname [file normalize [info script]]]
set rtl_dir [file join $script_dir src rtl]
set sim_dir [file join $script_dir src sim]

set old_top [get_property top [get_filesets sim_1]]
add_files -norecurse -fileset sim_1 \
    [file join $sim_dir seven_seg_board_tb.v]
set_property top seven_seg_board_tb [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
run all
set_property top $old_top [get_filesets sim_1]

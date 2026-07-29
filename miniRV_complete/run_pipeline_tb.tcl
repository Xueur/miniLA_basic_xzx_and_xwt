set script_dir [file dirname [file normalize [info script]]]

set_property top cpu_core_all_tb [get_filesets sim_1]
set_property verilog_define {} [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
run all

puts "Expected result:"
puts "PIPELINE CPU: ALL 44 miniRV INSTRUCTIONS PASSED"

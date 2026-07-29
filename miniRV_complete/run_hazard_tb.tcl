set_property top pipeline_hazard_tb [get_filesets sim_1]
set_property verilog_define {} [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
run all

puts "Expected result:"
puts "HAZARD TEST PASSED: load-use + forwarding + flush"

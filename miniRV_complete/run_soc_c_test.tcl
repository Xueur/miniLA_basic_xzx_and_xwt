set script_dir [file dirname [file normalize [info script]]]
set c_test_banks [list]
for {set bank 0} {$bank < 5} {incr bank} {
    set bank_file [file join $script_dir software c_test \
        "c_test_bank${bank}.hex"]
    if {![file exists $bank_file]} {
        error "Missing $bank_file."
    }
    lappend c_test_banks $bank_file
}
add_files -norecurse -fileset sim_1 $c_test_banks
set_property file_type {Memory Initialization Files} \
    [get_files $c_test_banks]

set_property top soc_c_test_tb [get_filesets sim_1]
set_property verilog_define {SOC_SIM} [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
run all

puts "Expected result:"
puts "C_TEST: SWITCH + LED + DIG + UART TX/RX + TIMER PASSED"

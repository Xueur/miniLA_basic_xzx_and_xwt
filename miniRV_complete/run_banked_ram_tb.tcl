set script_dir [file dirname [file normalize [info script]]]
set bank_files [list]
for {set bank 0} {$bank < 5} {incr bank} {
    lappend bank_files [file join $script_dir software coremark \
        "coremark_bank${bank}.hex"]
}
add_files -norecurse -fileset sim_1 \
    [file join $script_dir src sim axi_bram_banked_tb.v]
add_files -norecurse -fileset sim_1 $bank_files
set_property file_type {Memory Initialization Files} \
    [get_files $bank_files]
set_property top axi_bram_banked_tb [get_filesets sim_1]
set_property verilog_define {SOC_SIM} [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
run all

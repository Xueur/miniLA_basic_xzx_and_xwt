set script_dir [file dirname [file normalize [info script]]]
set project_dir [file join $script_dir vivado_lab2]

create_project -force miniRV_lab2 $project_dir -part xc7a35tcsg324-1

set rtl_dir [file join $script_dir src rtl]
set rtl_files [list \
    [file join $rtl_dir defines.vh] \
    [file join $rtl_dir Controller.v] \
    [file join $rtl_dir SEXT.v] \
    [file join $rtl_dir RF.v] \
    [file join $rtl_dir MREQ.v] \
    [file join $rtl_dir MEXT.v] \
    [file join $rtl_dir multiplier.v] \
    [file join $rtl_dir divider.v] \
    [file join $rtl_dir ALU.v] \
    [file join $rtl_dir cpu_core.v] \
    [file join $rtl_dir icache.v] \
    [file join $rtl_dir dcache.v] \
    [file join $rtl_dir axi_master.v] \
    [file join $rtl_dir axi_bram_slave.v] \
    [file join $rtl_dir uart_simple.v] \
    [file join $rtl_dir io_peripherals.v] \
    [file join $rtl_dir seven_seg.v] \
    [file join $rtl_dir cpu_top.v] \
    [file join $rtl_dir miniRV_SoC.v] \
]
add_files -norecurse -fileset sources_1 $rtl_files
set_property file_type {Verilog Header} \
    [get_files [file join $rtl_dir defines.vh]]
set_property include_dirs [list $rtl_dir] [get_filesets sources_1]

set init_file [file join $script_dir software c_test c_test.hex]
add_files -norecurse -fileset sources_1 $init_file
set_property file_type {Memory Initialization Files} \
    [get_files $init_file]
set c_test_banks [list]
set trace_banks [list]
set coremark_banks [list]
for {set bank 0} {$bank < 5} {incr bank} {
    lappend c_test_banks [file join $script_dir software c_test \
        "c_test_bank${bank}.hex"]
    lappend trace_banks [file join $script_dir software trace \
        "start_bank${bank}.hex"]
    lappend coremark_banks [file join $script_dir software coremark \
        "coremark_bank${bank}.hex"]
}
foreach bank_file [concat $c_test_banks $trace_banks $coremark_banks] {
    if {![file exists $bank_file]} {
        error "Missing banked memory image: $bank_file"
    }
}
add_files -norecurse -fileset sources_1 $c_test_banks
add_files -norecurse -fileset sim_1 \
    [concat $c_test_banks $trace_banks $coremark_banks]
set_property file_type {Memory Initialization Files} \
    [get_files [concat $c_test_banks $trace_banks $coremark_banks]]

set clk_ip [file join $rtl_dir ip clk_wiz_0 clk_wiz_0.xci]
add_files -norecurse -fileset sources_1 $clk_ip
generate_target all [get_files $clk_ip]

add_files -norecurse -fileset constrs_1 \
    [file join $script_dir src xdc miniRV_SoC.xdc]
add_files -norecurse -fileset constrs_1 \
    [file join $script_dir src xdc clock.xdc]

add_files -norecurse -fileset sim_1 \
    [file join $script_dir src sim cpu_core_all_tb.v]
add_files -norecurse -fileset sim_1 \
    [file join $script_dir src sim pipeline_hazard_tb.v]
add_files -norecurse -fileset sim_1 \
    [file join $script_dir src sim soc_c_test_tb.v]
add_files -norecurse -fileset sim_1 \
    [file join $script_dir src sim trace_board_tb.v]
set_property include_dirs [list $rtl_dir] [get_filesets sim_1]

set_property top miniRV_SoC [get_filesets sources_1]
set_property generic {
    MEM_BANK0_FILE="c_test_bank0.hex"
    MEM_BANK1_FILE="c_test_bank1.hex"
    MEM_BANK2_FILE="c_test_bank2.hex"
    MEM_BANK3_FILE="c_test_bank3.hex"
    MEM_BANK4_FILE="c_test_bank4.hex"
} [get_filesets sources_1]
set_property top cpu_core_all_tb [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

set_property strategy Flow_PerfOptimized_high [get_runs synth_1]
set_property strategy Performance_Explore [get_runs impl_1]

puts "Created [file join $project_dir miniRV_lab2.xpr]"
puts "Part: xc7a35tcsg324-1; SoC clock: 50 MHz"

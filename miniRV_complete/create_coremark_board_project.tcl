set script_dir [file dirname [file normalize [info script]]]
set project_dir [file join $script_dir vivado_coremark_board_50MHz]

create_project -force miniRV_coremark_board_50MHz $project_dir \
    -part xc7a35tcsg324-1

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

set coremark_image [file join $script_dir software coremark coremark.hex]
if {![file exists $coremark_image]} {
    error "Missing software/coremark/coremark.hex. Run tools/convert_coremark_coe.py first."
}
set image_fp [open $coremark_image r]
set image_text [read $image_fp]
close $image_fp
set image_word_list [regexp -all -inline -line \
    {^[0-9A-Fa-f]{8}$} $image_text]
set image_words [llength $image_word_list]
if {$image_words != 40960} {
    error "CoreMark image must contain 40960 words; found $image_words."
}
add_files -norecurse -fileset sources_1 $coremark_image
set_property file_type {Memory Initialization Files} \
    [get_files $coremark_image]

set coremark_banks [list]
set bank_word_list [list]
for {set bank 0} {$bank < 5} {incr bank} {
    set bank_file [file join $script_dir software coremark \
        "coremark_bank${bank}.hex"]
    if {![file exists $bank_file]} {
        error "Missing $bank_file. Run tools/convert_coremark_coe.py first."
    }
    set bank_fp [open $bank_file r]
    set bank_text [read $bank_fp]
    close $bank_fp
    set words [regexp -all -inline -line {^[0-9A-Fa-f]{8}$} $bank_text]
    if {[llength $words] != 8192} {
        error "CoreMark BRAM bank $bank must contain 8192 words."
    }
    set bank_word_list [concat $bank_word_list $words]
    lappend coremark_banks $bank_file
}
if {[join $bank_word_list "\n"] ne [join $image_word_list "\n"]} {
    error "CoreMark BRAM banks do not reconstruct coremark.hex."
}
add_files -norecurse -fileset sources_1 $coremark_banks
set_property file_type {Memory Initialization Files} \
    [get_files $coremark_banks]

set clk_ip [file join $rtl_dir ip clk_wiz_0 clk_wiz_0.xci]
add_files -norecurse -fileset sources_1 $clk_ip
set clk_ip_obj [get_ips clk_wiz_0]
if {[llength $clk_ip_obj] != 1} {
    error "Cannot resolve clk_wiz_0 after adding $clk_ip."
}
set_property CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {50.000} $clk_ip_obj
generate_target all $clk_ip_obj

add_files -norecurse -fileset constrs_1 \
    [file join $script_dir src xdc miniRV_SoC.xdc]
add_files -norecurse -fileset constrs_1 \
    [file join $script_dir src xdc clock.xdc]

add_files -norecurse -fileset sim_1 \
    [file join $script_dir src sim coremark_boot_tb.v]
add_files -norecurse -fileset sim_1 $coremark_banks
set_property include_dirs [list $rtl_dir] [get_filesets sim_1]
set_property verilog_define {SOC_SIM} [get_filesets sim_1]

set_property top miniRV_SoC [get_filesets sources_1]
set_property generic {
    MEM_BANK0_FILE="coremark_bank0.hex"
    MEM_BANK1_FILE="coremark_bank1.hex"
    MEM_BANK2_FILE="coremark_bank2.hex"
    MEM_BANK3_FILE="coremark_bank3.hex"
    MEM_BANK4_FILE="coremark_bank4.hex"
} \
    [get_filesets sources_1]
set_property top coremark_boot_tb [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

set_property strategy Flow_PerfOptimized_high [get_runs synth_1]
catch {
    set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs synth_1]
}
if {[catch {
    set_property strategy Performance_ExplorePostRoutePhysOpt \
        [get_runs impl_1]
}]} {
    set_property strategy Performance_Explore [get_runs impl_1]
    catch {
        set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true \
            [get_runs impl_1]
        set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE \
            AggressiveExplore [get_runs impl_1]
    }
}

puts "Created [file join $project_dir miniRV_coremark_board_50MHz.xpr]"
puts "SoC clock: 50 MHz (pipelined SoC requirement satisfied)"
puts "Program image: $coremark_image (5 x 8192-word BRAM banks / 160 KiB)"
puts "CoreMark output: UART 115200-8-N-1"

set script_dir [file dirname [file normalize [info script]]]
set project_file [file join $script_dir vivado_coremark_board_50MHz \
    miniRV_coremark_board_50MHz.xpr]
if {[llength [get_projects -quiet]] == 0} {
    if {![file exists $project_file]} {
        error "Project is missing. Double-click create_and_open_CoreMark_50MHz_project.bat first."
    }
    open_project $project_file
}

set report_dir [file join $script_dir reports coremark_board_50MHz]
set output_dir [file join $script_dir output]
file mkdir $report_dir
file mkdir $output_dir

if {[get_property TOP [get_filesets sources_1]] ne "miniRV_SoC"} {
    error "Open the project created by create_coremark_board_project.tcl first."
}

set freq [get_property CONFIG.CLKOUT1_REQUESTED_OUT_FREQ \
    [get_ips clk_wiz_0]]
if {[expr {abs(double($freq) - 50.0)}] > 0.001} {
    error "Clocking Wizard is $freq MHz, but the pipelined SoC must use 50 MHz."
}
puts "Confirmed pipelined SoC clock = 50.000 MHz"

set cpu_top_file [file join $script_dir src rtl cpu_top.v]
set fp [open $cpu_top_file r]
set cpu_top_text [read $fp]
close $fp
if {![regexp {\.CLK_FREQ[ \t\r\n]*\([ \t\r\n]*50000000[ \t\r\n]*\)} \
    $cpu_top_text]} {
    error "UART/peripheral CLK_FREQ is not 50000000 in src/rtl/cpu_top.v."
}
puts "Confirmed UART/peripheral input clock = 50000000 Hz"

set coremark_file [file join $script_dir software coremark course_source \
    src coremark core_portme.c]
if {![file exists $coremark_file]} {
    error "Missing course CoreMark source: $coremark_file"
}
set fp [open $coremark_file r]
set coremark_text [read $fp]
close $fp
if {![regexp {#define[ \t]+MHZ[ \t]+50([^0-9]|$)} $coremark_text]} {
    error "CoreMark MHZ is not 50 in $coremark_file."
}
puts "Confirmed CoreMark MHZ = 50"

set coremark_image [file join $script_dir software coremark coremark.hex]
if {![file exists $coremark_image]} {
    error "Missing CoreMark image: $coremark_image"
}
set fp [open $coremark_image r]
set image_text [read $fp]
close $fp
set image_word_list [regexp -all -inline -line \
    {^[0-9A-Fa-f]{8}$} $image_text]
set image_words [llength $image_word_list]
if {$image_words != 40960} {
    error "CoreMark image must contain 40960 words; found $image_words."
}

set bank_word_list [list]
for {set bank 0} {$bank < 5} {incr bank} {
    set bank_file [file join $script_dir software coremark \
        "coremark_bank${bank}.hex"]
    if {![file exists $bank_file]} {
        error "Missing CoreMark BRAM bank $bank: $bank_file"
    }
    set bank_fp [open $bank_file r]
    set bank_text [read $bank_fp]
    close $bank_fp
    set words [regexp -all -inline -line {^[0-9A-Fa-f]{8}$} $bank_text]
    if {[llength $words] != 8192} {
        error "CoreMark BRAM bank $bank must contain 8192 words."
    }
    set bank_word_list [concat $bank_word_list $words]
}
if {[join $bank_word_list "\n"] ne [join $image_word_list "\n"]} {
    error "CoreMark BRAM banks do not reconstruct coremark.hex."
}
puts "Confirmed CoreMark image = 5 x 8192-word BRAM banks / 160 KiB"

set soc_file [file join $script_dir src rtl miniRV_SoC.v]
set fp [open $soc_file r]
set soc_text [read $fp]
close $fp
if {![regexp {\.RAM_WORDS[ \t\r\n]*\([ \t\r\n]*40960[ \t\r\n]*\)} \
    $soc_text]} {
    error "Main memory is not configured for 40960 words (160 KiB)."
}
set ram_file [file join $script_dir src rtl axi_bram_slave.v]
set fp [open $ram_file r]
set ram_text [read $fp]
close $fp
if {![regexp {localparam[ \t]+BANK_WORDS[ \t]*=[ \t]*8192} $ram_text]} {
    error "Main memory is not split into 8192-word BRAM banks."
}
foreach bank {0 1 2 3 4} {
    set bank_pattern [format {mem%d[ \t]+\[0:BANK_WORDS-1\]} $bank]
    if {![regexp $bank_pattern $ram_text]} {
        error "Main memory BRAM bank $bank is missing."
    }
}
puts "Confirmed main memory = 5 x 8192-word banks / 160 KiB"

set cpu_core_file [file join $script_dir src rtl cpu_core.v]
set fp [open $cpu_core_file r]
set cpu_core_text [read $fp]
close $fp
if {![regexp {mem_is_load[ \t]*\?[ \t\r\n]*\(mem_req_sent[ \t]*&&[ \t]*daccess_rvalid\)} \
    $cpu_core_text]} {
    error "Load response is not qualified by mem_req_sent."
}
if {![regexp {mem_is_store[ \t]*\?[ \t\r\n]*\(mem_req_sent[ \t]*&&[ \t]*daccess_wresp\)} \
    $cpu_core_text]} {
    error "Store response is not qualified by mem_req_sent."
}
if {![regexp {mem_resp_active[ \t]*=[ \t]*daccess_rvalid[ \t]*\|\|[ \t]*daccess_wresp} \
    $cpu_core_text]} {
    error "Residual memory response guard is missing."
}
puts "Confirmed v8 request-qualified memory response guard"

set io_file [file join $script_dir src rtl io_peripherals.v]
set fp [open $io_file r]
set io_text [read $fp]
close $fp
if {![regexp {\{28'h0,[ \t\r\n]*tx_busy,[ \t\r\n]*!tx_busy,[ \t\r\n]*rx_valid,[ \t\r\n]*rx_valid\}} \
    $io_text]} {
    error "UART status register is not compatible with the course CoreMark."
}
puts "Confirmed UART status bits: bit3=TX busy, bit2=TX idle"

set project_generic [get_property generic [get_filesets sources_1]]
foreach bank {0 1 2 3 4} {
    if {![string match \
        "*MEM_BANK${bank}_FILE=*coremark_bank${bank}.hex*" \
        $project_generic]} {
        error "Project BRAM bank $bank generic is incorrect: $project_generic"
    }
}
puts "Confirmed synthesis image = coremark_bank0.hex through bank4.hex"

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property STATUS [get_runs synth_1]] ni \
    {"synth_design Complete!" "Complete!"}} {
    error "Synthesis failed. Inspect the synth_1 runme.log."
}

open_run synth_1
report_utilization -hierarchical -file \
    [file join $report_dir post_synthesis_utilization.rpt]
set ram36_cells [get_cells -hier -quiet -filter {REF_NAME == RAMB36E1}]
set ram18_cells [get_cells -hier -quiet -filter {REF_NAME == RAMB18E1}]
set ram36_count [llength $ram36_cells]
set ram18_count [llength $ram18_cells]
set bram18_equiv [expr {2 * $ram36_count + $ram18_count}]
puts "Post-synthesis BRAM usage: RAMB36E1=$ram36_count, RAMB18E1=$ram18_count, BRAM18-equivalent=$bram18_equiv/100"
if {$ram36_count > 50 || $bram18_equiv > 100} {
    error "BRAM is still over-utilized; expected the 160 KiB main memory to fit in 40 RAMB36E1."
}
if {$bram18_equiv < 80} {
    error "Banked main memory did not infer the expected minimum 160 KiB of block RAM."
}
close_design

set strategies [list \
    Performance_ExplorePostRoutePhysOpt \
    Performance_NetDelay_high \
    Performance_Explore \
]
set timing_passed 0
set best_setup_slack -9999.0
set best_strategy ""

foreach strategy $strategies {
    if {[catch {
        set_property strategy $strategy [get_runs impl_1]
    } strategy_error]} {
        puts "Skipping unsupported strategy $strategy: $strategy_error"
        continue
    }

    puts "Running implementation strategy: $strategy"
    reset_run impl_1
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1

    if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
        puts "Strategy $strategy did not finish; trying the next one."
        continue
    }

    open_run impl_1
    set setup_path [get_timing_paths -delay_type max -max_paths 1 -quiet]
    set hold_path [get_timing_paths -delay_type min -max_paths 1 -quiet]
    if {[llength $setup_path] == 0 || [llength $hold_path] == 0} {
        close_design
        puts "Strategy $strategy produced no valid timing path."
        continue
    }
    set setup_slack [get_property SLACK [lindex $setup_path 0]]
    set hold_slack [get_property SLACK [lindex $hold_path 0]]

    report_timing_summary -delay_type min_max -report_unconstrained \
        -check_timing_verbose -max_paths 20 -input_pins \
        -file [file join $report_dir "timing_${strategy}.rpt"]
    puts "$strategy post-route setup WNS = $setup_slack ns"
    puts "$strategy post-route hold WHS = $hold_slack ns"

    if {$setup_slack > $best_setup_slack} {
        set best_setup_slack $setup_slack
        set best_strategy $strategy
    }

    if {$setup_slack >= 0.0 && $hold_slack >= 0.0} {
        set timing_passed 1
        break
    }
    close_design
}

if {!$timing_passed} {
    error "All implementation strategies failed timing. Best: $best_strategy, WNS=$best_setup_slack ns. Send reports/coremark_board_50MHz to me."
}

report_timing_summary -delay_type min_max -report_unconstrained \
    -check_timing_verbose -max_paths 20 -input_pins \
    -file [file join $report_dir timing_summary_PASS.rpt]
report_utilization -hierarchical -file \
    [file join $report_dir utilization_PASS.rpt]
report_power -file [file join $report_dir power_PASS.rpt]
report_drc -file [file join $report_dir drc_PASS.rpt]

set output_bit [file join $output_dir miniRV_coremark_board_50MHz.bit]
write_bitstream -force $output_bit

puts "COREMARK BOARD 50 MHz BITSTREAM AND TIMING PASSED"
puts "Implementation strategy: $strategy"
puts "Post-route setup WNS = $setup_slack ns"
puts "Post-route hold WHS = $hold_slack ns"
puts "Bitstream: $output_bit"
puts "Open UART at 115200-8-N-1, then program and release S6."

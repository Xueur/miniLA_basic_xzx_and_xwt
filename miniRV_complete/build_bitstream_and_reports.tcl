set script_dir [file dirname [file normalize [info script]]]
set report_dir [file join $script_dir reports]
file mkdir $report_dir

reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "Implementation did not finish."
}

open_run impl_1
report_timing_summary -delay_type min_max -report_unconstrained \
    -check_timing_verbose -max_paths 20 -input_pins \
    -file [file join $report_dir timing_summary.rpt]
report_utilization -hierarchical -file \
    [file join $report_dir utilization.rpt]
report_power -file [file join $report_dir power.rpt]
report_drc -file [file join $report_dir drc.rpt]

set setup_path [get_timing_paths -delay_type max -max_paths 1]
set hold_path [get_timing_paths -delay_type min -max_paths 1]
set setup_slack [get_property SLACK $setup_path]
set hold_slack [get_property SLACK $hold_path]

puts "Post-route setup WNS = $setup_slack ns"
puts "Post-route hold WHS = $hold_slack ns"
if {$setup_slack < 0.0 || $hold_slack < 0.0} {
    error "Timing violation: inspect reports/timing_summary.rpt."
}

puts "BITSTREAM AND REPORTS PASSED: no setup/hold violation."


# Create the Vivado project, synthesize the FIFO, and save reports.
# Run from the project root with:
# vivado -mode batch -source scripts/create_project.tcl -tclargs zybo_z7_10 1
# First argument: zybo_z7_10 or zybo_z7_20
# Second argument: READ_LATENCY from 1 through 8

set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir ..]]
set project_name "sc_fifo_lab3"
set project_dir [file join $repo_root build "vivado_fifo"]
set report_dir [file join $repo_root reports]
set input_file [file normalize [file join $repo_root sim "input_data.txt"]]

set board_choice "zybo_z7_10"
set read_latency 1

if {$argc >= 1} {
    set board_choice [string tolower [lindex $argv 0]]
}
if {$argc >= 2} {
    set read_latency [lindex $argv 1]
}

switch -- $board_choice {
    "zybo_z7_10" {
        set part_name "xc7z010clg400-1"
    }
    "zybo_z7_20" {
        set part_name "xc7z020clg400-1"
    }
    default {
        error "Unknown board '$board_choice'. Use zybo_z7_10 or zybo_z7_20."
    }
}

if {![string is integer -strict $read_latency] ||
    $read_latency < 1 || $read_latency > 8} {
    error "READ_LATENCY must be an integer from 1 through 8."
}

if {![file exists $input_file]} {
    error "Missing $input_file. First run the Python input-data script."
}

file mkdir [file dirname $project_dir]
file mkdir $report_dir

create_project -force $project_name $project_dir -part $part_name

set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]
set_property target_simulator XSim [current_project]

set rtl_file [file join $repo_root src "sc_fifo.vhd"]
set tb_file  [file join $repo_root sim "tb_sc_fifo.vhd"]

add_files -norecurse $rtl_file
add_files -fileset sim_1 -norecurse $tb_file

set_property file_type {VHDL 2008} [get_files $rtl_file]
set_property file_type {VHDL 2008} [get_files $tb_file]

set_property top sc_fifo [current_fileset]
set_property top tb_sc_fifo [get_filesets sim_1]

# Give XSim the absolute data-file path, so it can find the file
# regardless of the simulator's working directory.
set_property generic \
    "G_READ_LATENCY=$read_latency G_INPUT_FILE=\"$input_file\"" \
    [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Creating $project_name for $board_choice ($part_name)"
puts "READ_LATENCY=$read_latency"
puts "Project directory: $project_dir"
puts "Input data file: $input_file"

# Synthesize for the selected Zybo Z7 FPGA part.
launch_runs synth_1 -jobs 4
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
puts "Synthesis status: $synth_status"

if {![string match "*Complete*" $synth_status]} {
    error "Synthesis did not complete successfully. Check the Vivado run log."
}

open_run synth_1

report_utilization \
    -file [file join $report_dir "resource_utilization_synth.rpt"]

report_timing_summary \
    -file [file join $report_dir "timing_summary_synth.rpt"]

# Copy Vivado's synthesis run log into the repository's reports folder.
set synth_log [file join $project_dir \
    "${project_name}.runs" "synth_1" "runme.log"]

if {[file exists $synth_log]} {
    file copy -force $synth_log \
        [file join $report_dir "synthesis.log"]
} else {
    puts "WARNING: Synthesis completed, but runme.log was not found at $synth_log"
}

puts "Reports were written to: $report_dir"
puts "Vivado project: [file join $project_dir "${project_name}.xpr"]"
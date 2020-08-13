#set_msg_config -severity STATUS -suppress
#reset_msg_config -severity STATUS -suppress
#
# In case the Custom DRC cannot recognize the OS you're running on:
# Run below command in Tcl Console and send to author at (tuan.la@postgrad.manchester.ac.uk)
#   puts "Printing out environment variables:"
#   foreach index [array names env] {
#       puts "$index: $env($index)"
#   }
#
# To delete this custom DRC, run:
#delete_drc_check COMBLOOPS-1


proc CombinatorialLoopsCheck {} {
  # Setting limitation of Errors for this DRC
  set ERR_LIMIT 10000
  
  set fileDat  "[current_project].rpt_distiming"
  set fileLoop "[current_project].rpt_loop"
  report_disable_timing -return_string -file $fileDat
  
  #exec wsl egrep -i '\Sloop\S' $fileDat > $fileLoop
  #exec wsl awk '{for (i=4; i<=NF; i++) { if ($i ~ "loop") {print $0; break;}}}' $fileDat > $fileLoop
  #exec awk '{for (i=4; i<=NF; i++) { if ($i ~ "loop") {print $0; break;}}}' $fileDat > $fileLoop
  set rm_cmd "pwd"
  if {[info exists ::env(OS)]} {
    if [string match "Windows_NT" $::env(OS)] {
      # WSL Linux Subsystem Environment
      set cmd [list wsl --exec awk {{for (i=4; i<=NF; i++) { if ($i ~ /loop/) {print $0; break;}}}} $fileDat > $fileLoop]
      set rm_cmd [list wsl rm -rf $fileDat $fileLoop]
    } else {
      return -code error [create_drc_violation -name {COMBLOOPS-1} -msg "Cannot recognize environment OS!"]
    }
  } elseif {[info exists ::env(OSTYPE)]} {
    if [string match "linux" $::env(OSTYPE)] {
    # Linux Environment
      set cmd [list awk {{for (i=4; i<=NF; i++) { if ($i ~ /loop/) {print $0; break;}}}} $fileDat > $fileLoop]
      set rm_cmd [list rm -rf $fileDat $fileLoop]
    } else {
      return -code error [create_drc_violation -name {COMBLOOPS-1} -msg "Cannot recognize environment OSTYPE!"]
    }
  } else {
    return -code error [create_drc_violation -name {COMBLOOPS-1} -msg "Cannot recognize any OS!"]
  }
  eval exec $cmd
  
  set fp [open $fileLoop r]
  set file_data [read $fp]

  #puts "----------------------------------------------------------------------------------------------------------------"
  set err_cnt 0
  # List of violations
  set vios {}
  
  foreach line [split $file_data "\n"] {
    if [string match "*loop*" $line] {
      incr err_cnt      
      set CELL [lindex [split $line " "] 0]
      set line_splitted [regexp -all -inline {\S+} $line]
      set field_0 [lindex $line_splitted 0]
      set field_1 [lindex $line_splitted 1]
      set field_2 [lindex $line_splitted 2]
      
      if {$CELL == ""} {
        set PINS [get_pins "$field_0 $field_1"]
        set NETS [get_nets -of $PINS]
      } else {
        set PINS [get_pins "$field_0/$field_1 $field_0/$field_2"]
        set NETS [get_nets -of $PINS]
      }
      
      set objects "$CELL $PINS $NETS"
      
      #puts "$CELL"
      #puts "PINS: $PINS"
      #puts "NETS: $NETS"
      
      set msg "Combinatorial loop is found! Related CELL: $CELL; PINS: $PINS; NETS: $NETS"  
      #set vio [ create_drc_violation -name {COMBLOOPS-1} -msg $msg $objects ]  
      set vio [ create_drc_violation -name {COMBLOOPS-1} -msg $msg $PINS $NETS]  
      lappend vios $vio
    }
    
    # Limiting Error message
    if {$err_cnt >= $ERR_LIMIT} {
      break
    }
  }
  
  close $fp
  #exec wsl rm -rf $fileDat $fileLoop
  eval exec $rm_cmd
  
  if {$err_cnt > 0} {
    return -code error $vios
  } else {
    return {}
  }
}

create_drc_check -name {COMBLOOPS-1} -hiername {Netlist.Design Level.Combinatorial Loop} -desc {Combinatorial Loops Check} -rule_body CombinatorialLoopsCheck -severity ERROR
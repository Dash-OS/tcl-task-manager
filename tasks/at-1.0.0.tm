package require task

# A convenience command to replace [every] if needed
proc ::at { time command args} {
  if { [string equal $time cancel] } {
    return [::task -cancel $command {*}$args]
  } else {
    return [::task -at $time -command $command {*}$args]
  }
}

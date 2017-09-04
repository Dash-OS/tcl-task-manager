package require task

# A convenience command to replace [every] if needed
proc ::every { interval command args} {
  if { [string equal $interval cancel] } {
    return [::task -cancel $command {*}$args]
  } else {
    return [::task -every $interval -command $command {*}$args]
  }
}

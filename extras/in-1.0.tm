package provide in 1.0
package require task

# A convenience command to replace [every] if needed
proc ::in { ms command args} {
  if { [string equal $ms cancel] } {
    return [::task -cancel $command {*}$args] 
  } else {
    return [::task -in $ms -command $command {*}$args]
  }
}
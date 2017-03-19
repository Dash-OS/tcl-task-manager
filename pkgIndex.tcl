package ifneeded task 1.0 [list apply {{dir} {
	uplevel #0 [ list source [file join $dir task.tcl] ]
	package provide task 1.0
}} $dir]

package ifneeded every 1.0 [list apply {{dir} {
	uplevel #0 [ list source [file join $dir every.tcl] ]
	package provide every 1.0
}} $dir]
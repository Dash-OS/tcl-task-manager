package ifneeded task 1.0 [list apply {{dir} {
	uplevel #0 [ list source [file join $dir task-1.0.tm] ]
	package provide task 1.0
}} $dir]

package ifneeded every 1.0 [list apply {{dir} {
	uplevel #0 [ list source [file join $dir tasks every-1.0.tm] ]
	package provide every 1.0
}} $dir]

package ifneeded at 1.0 [list apply {{dir} {
	uplevel #0 [ list source [file join $dir tasks at-1.0.tm] ]
	package provide at 1.0
}} $dir]

package ifneeded in 1.0 [list apply {{dir} {
	uplevel #0 [ list source [file join $dir tasks in-1.0.tm] ]
	package provide in 1.0
}} $dir]
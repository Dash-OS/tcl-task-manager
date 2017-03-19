# Tcl Task Manager

Tcl Task Manager is a powerful and lightweight task manager / scheduler which utilizes
the awesome capabilities of Tcl's [coroutines](https://www.tcl.tk/man/tcl/TclCmd/coroutine.htm) to 
allow us to schedule and maintain tasks which execute based on the given arguments. 

It utilizes the less-known [coroutine inject](http://www.tcl.tk/cgi-bin/tct/tip/383.html) 
command to faciliate the given commands based on your arguments.

One of it's important features is that it will only schedule a single `[after]` for its 
tasks so that we do not continually add more after's to our script needlessly. It will 
determine the next time it should wakeup based on the currently scheduled tasks then 
sleep until the next task needs to be executed.  

`[task]` provides options to cancel, introspect, and execute your tasks in a variety of 
ways such as at intervals, in a given period of time, at a specific time, and more.

## Installation 

You can use this package by simply adding the files to your system either within one of 
the tcl module directories (`[::tcl::tm::path list]`) or to one of your `$auto_path` 
directories.  Once you have done this you should be able to `package require` them.

> **Tip:** You can add to the tcl module directories list by calling `[::tcl::tm::path add $dir]`

## Optional Extras

There are a few optional "extras" commands which act as simple shortcut wrappers for 
convenience.  They essentially just provide an alias to calling the `[task]` command 
for specific use cases.  In all cases you can add them by calling `[package require extras::$package]`.

These extras are `[at]`, `[every]`, `[in]` and are called like `[every 5000 MyProc]`.

## Command Summary

#### **`task`** *?...-opt ?value?...?*
 
| Argument Name |  Type   |  Description   |
| ------------- | ------  | -------------- |
| -id           | String  | The id to use.  If not provided, one will be generated during creation. |
| -in           | MS      | Schedules the task to execute after the given milliseconds. |
| -at           | Unix MS | Provide the exact time to execute the task. |
| -every        | MS      | Execute the task every MS. |
| -times        | Integer | Modifies every so it only executes the given # of times. |
| -until        | Unix MS | Modifies every so it only executes until the given time. |
| -for          | MS      | Modifies every so it only executes for the given # of MS. |
| -while        | Command | Only execute the task if command is true.  Cancel every if false. |
| -command      | Command | The command (task) to execute. |
| -subst        | Boolean | Should we run `[subst -nocommands]` before calling the -command and -while? (Default 0) |
| -cancel       | Task ID | Cancels one or more tasks by their ID. |
| -info         | String  | Request information about a task or tasks. |

## Command Examples

```tcl
package require task

proc MyProc args {
  puts "[clock milliseconds] | MyProc Executes | $args"
}

# Execute the task once, in 5 seconds with no arguments and an auto assigned id
set task_id [ task -in 5000 -command MyProc ]

# Trigger MyProc every 5 seconds.  The tasks id is my_task
task -id my_task -every 5000 -command [list MyProc my_task]

# Scheduling a new task with the same id will replace the previous
task -id my_task -every 5000 -command [list MyProc my_task]

# Trigger MyProc every 5 seconds for 5 cycles
task -every 5000 -times 5 -command [list MyProc five_times]

# Trigger MyProc every 5 seconds for 60 seconds
task -every 5000 -for 60000 -command [list MyProc sixty_seconds]

# Trigger MyProc every 5 seconds until the given unix timestamp in ms.
task -every 5000 -until [expr { [clock milliseconds] + 60000 }] -command [list MyProc every_until_unix_ms]

# Trigger MyProc at the given unix timestamp in ms.
task -at [expr { [clock milliseconds] + 5000 }] -command [list MyProc at_unix_ms]

# Now lets add a command that we can use to test if we should continue execution

set i 0
proc RunWhile args {
  variable i ; incr i
  if { $args ne {} } {
    lassign $args task_id
    if { $task_id ne {} && $i > 30 } { return 0 }
  } elseif { $i > 5 } { return 0 }
  return 1
}

# Run the every command every 5 seconds for 5 overall calls of RunWhile
task -every 5000 -while RunWhile -command [list MyProc run_while_true]

# Run the every command every 5 seconds for 30 calls of RunWhile - feed our $task_id to -while and -command.
task -subst 1 -every 5000 -while {RunWhile $task_id} -command {MyProc $task_id}  

```

## Extras Examples

All of the commands below can also take the normal `[task]` arguments optionally. 
All of these commands will operate together - you will still always have a single 
set of tasks that are managed by `[task]`.

#### **`every`** $interval_ms $cmd

```tcl
package require extras::every

set every_id [every 5000 {puts hi}]

# sometime later

every cancel $every_id

```

#### **`in`** $ms $cmd

```tcl
package require extras::in

set in_id [in 5000 {puts hi}]

# can be cancelled with [in cancel $in_id]

```

> Note this is almost identical to [after] except that scheduling many will only 
> actually schedule [after] one total time.  You may also call it with the other 
> `[task]` arguments to enhance its capabilities.

#### **`at`** $time $cmd

```tcl
package require extras::at

set at_id [at [expr { [clock milliseconds] + 5000 }] {puts hi}]

# can be cancelled with [at cancel $at_id]

```

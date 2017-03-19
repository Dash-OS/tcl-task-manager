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
for specific use cases.  In all cases you can add them by calling `[package require tasks::$package]`.

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
| -info         | String  | Requests specific information as a response to the command. |

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

### Task Cancellation

You can cancel scheduled tasks easily by providing the `-cancel` argument.  It accepts a 
string or list of task_id(s) that should be cancelled.  When creating a new task, the 
response value will be the task_id.  

```tcl
package require task

proc myproc args {
  # ... do something
}

task -every 5000 -id my_task -command myproc
set task_id [ task -in 5000 -command myproc ]
set task2_id [ task -in 5000 -command myproc ]

task -cancel [list my_task $task_id]
task -cancel $task2_id

# Technically this also works, although the above is less verbose.
# task -cancel -ids [list my_task $task_id]
# task -cancel -id $task2_id

# Using introspection you can do something like below to cancel all scheduled tasks.
# task -cancel [task -info ids]
```

### -subst argument

By providing the `-subst 1` argument, you are instructing the task manager to subst the given 
command before execution.  This allows you to add arguments from our execution environment 
before running the command.  

This is useful, for example, to capture the executed task_id or to get the currently scheduled 
tasks.  Below is a list of variables that you can capture for any `-while` or `-command` executions 
if the `-subst` argument is set to true.  

> **Note:** By default this is 0 and no substitution will be attempted.

| Variable Name   |  Description   |
| -------------   | -------------- |
| $task_id        | This will always resolve to the task_id of the task that is being evaluated. |
| $tasks          | The dict that holds all currently scheduled tasks (not including the current task).  |
| $task           | The current tasks descriptor that defines its arguments. |
| $scheduled      | The key/value list of task_id's to time_scheduled values (not including the current task). |

```tcl
package require task

proc myproc {id remaining_tasks} {
  # ... do stuff
}

task -subst 1 -every 5000 -command {myproc $task_id $tasks}
```

### Task Introspection

#### **`task`** -info $value

The package introduces a fairly simple introspection capability that can allow you 
to get some information about the currently scheduled tasks.  

| Argument Name |  Description   |
| ------------- | -------------- |
| task / tasks  | Get a dict of the currently scheduled tasks.  If -id is provided, returns that task only. |
| scheduled     | Returns a dict of $task_id / $time_scheduled pairs. |
| ids           | Returns a list of the currently scheduled task ids. |
| next_id       | Returns the id of the next task that will be executed. |
| next_time     | Returns the time that the next task will be executed. |
| next_task     | Returns the descriptor dict of the next task that will be executed. |
| next          | Returns a three element list: [list $next_id $next_time $next_task] |

```tcl
package require task

proc myproc args { 
  # ... do stuff
}

task -every 5000 -command myproc
task -in 10000 -command myproc
task -in 15000 -command myproc
task -id my_task -every 2000 -times 5 -command myproc

# Now we can run introspection commands

set next [task -info next] 
# my_task 1489896518265 {every 2000 times 5 cmd myproc}

set ids  [task -info ids] 
# task#1 task#2 task#3 my_task

set task [task -info task -id my_task]
# every 5000 times 5 cmd myproc

set tasks [task -info tasks]
# task#1 {every 5000 cmd myproc} task#2 {cmd myproc} task#3 {cmd myproc} 
# my_task {every 2000 times 5 cmd myproc}

set scheduled [task -info scheduled]
# my_task 1489896708158 task#1 1489896711158 
# task#2 1489896716158 task#3 1489896721158

```

> **Note:** The "times" key within the descriptor will be updated with how many 
> executions are remaining so it might be difference depending on when it is 
> called.

## Extras Examples

All of the commands below can also take the normal `[task]` arguments optionally. 
All of these commands will operate together - you will still always have a single 
set of tasks that are managed by `[task]`. 

> As these are found in the "tasks" folder, we require it by providing the 
> directory followed by "::" then the package name.  This is defined by the 
> Tcl [tm](https://www.tcl.tk/man/tcl/TclCmd/tm.htm) packages instructions.

#### **`every`** $interval_ms $cmd

```tcl
package require tasks::every

set every_id [every 5000 {puts hi}]

# sometime later

every cancel $every_id

```

#### **`in`** $ms $cmd

```tcl
package require tasks::in

set in_id [in 5000 {puts hi}]

# can be cancelled with [in cancel $in_id]

```

> Note this is almost identical to [after] except that scheduling many will only 
> actually schedule [after] one total time.  You may also call it with the other 
> `[task]` arguments to enhance its capabilities.

#### **`at`** $time $cmd

```tcl
package require tasks::at

set at_id [at [expr { [clock milliseconds] + 5000 }] {puts hi}]

# can be cancelled with [at cancel $at_id]

```

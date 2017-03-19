package provide task 1.0
namespace eval ::task { variable id 0 }

proc ::task::init {} { coroutine ::task::task ::task::taskman }

proc ::task::evaluate script {
  ::tcl::unsupported::inject ::task::task try [subst -nocommands {yield [try {$script} on error {r} {}]}]
  return [::task::task]
}

proc ::task::cmdlist args { 
  if { [llength $args] == 1 } { set args [lindex $args 0] }
  return [ join $args \; ] 
}

proc ::task args {
  if { [info commands ::task::task] eq {} } { ::task::init }
  set execution_time {}
  set task    {}
  set current {}
  set action  create
  foreach arg $args {
    if { [string equal [string index $arg 0] "-"] } {
      set current [string range $arg 1 end]
      switch -glob -- $current {
        ca* - k* { set action cancel }
      }
      continue
    }
    switch -glob -- $current {
      id* { set task_id $arg }
      in  { set execution_time [expr { [clock milliseconds] + $arg }] }
      at  { set execution_time $arg }
      e*  { 
        dict set task every $arg
        set execution_time [expr { [clock milliseconds] + $arg }]
      }
      w*  { dict set task while $arg }
      in* { 
        set action info
        set info $arg 
      }
      co* { dict set task cmd $arg }
      ti* { dict set task times $arg }
      un* { dict set task until $arg }
      su* {
        if { [string is bool -strict $arg] && $arg } { dict set task subst 1 }
      }
      fo* { dict set task until [expr { [clock milliseconds] + $arg }] }
      ca* - k* { set task_id $arg }
      default {
        throw error "$current is an unknown task argument.  Must be one of \"-id, -in, -at, -every, -while, -times, -until, -command, -info, -subst, -cancel\""  
      }
    }
  }
  switch -- $action {
    create {
      if { ! [info exists task_id] } { 
        # If a task id was not provided, we will create one.
        set task_id task#[incr ::task::id] 
      }
      lappend script [list ::task::add_task $task_id $task $execution_time]
    }
    cancel {
      if { ! [info exists task_id] } {
        throw error "-id argument required when cancelling a task" 
      }
      lappend script [list ::task::remove_tasks $task_id]
    }
    info {
      switch -glob -- $info {
        s* { lappend script [list set scheduled] }
        t* { 
          if { [info exists task_id] } {
            lappend script [format {dict get $tasks {%s}} $task_id]
          } else {
            lappend script [list set tasks]
          }
        }
        i* {
          lappend script {dict keys $tasks}
        }
        n*time {
          lappend script {lindex $scheduled 1}
        }
        n*id {
          lappend script {lindex $scheduled 0}
        }
        n* { lappend script {lrange $scheduled 0 1} }
        default { throw error "$info is an unknown info response, you may request one of \"scheduled, tasks\"" }
      }
    }
  }
  set response [ ::task::evaluate [::task::cmdlist $script] ]
  if { $action eq "info" } { return $response } else { return $task_id }
}

proc ::task::taskman {} {
  # Run the coroutine asynchronously from the caller
  after 0 [info coroutine]
  # tasks is a dict which holds our tasks.  Its keys are the times that they 
  # should execute and their values contain data including the command to 
  # execute and any other required context about the task.
  set tasks [dict create]
  # $scheduled is actually a "dict style" list which is sorted so that we
  # can always assume that the next two elements represent the task_id and
  # next_event pair.
  set scheduled [list]
  # $after_id will store the after_id of the coroutine which is set to the
  # next scheduled event. This allows us to cancel it should the tasks
  # change.
  set after_id  {}
  set task_time {} ; set task_scheduled {} ; set task_id {} ; set task {}
  # Our core loop will continually iterate and execute any scheduled tasks
  # that are provided to it.  When it has finished executing the events it will 
  # sleep until the next event or until a new task is provided to it.
  while 1 {
    # task will tell us if we need to execute the next task
    while { [next_task] ne {} } {
      # We run in an after so that the execution will not be in our coroutines
      # context anymore.  If we don't do this then we won't be able to schedule
      # tasks within the execution of a task.
      if { [dict exists $task while] } {
        # while is a command to run to test if we should execute the task.  When
        # combined with -every, the command will run until the -while clause is no
        # longer true.  In the case of -in or -at, -while will be a test to check
        # if we still want to execute the event in the case we did not cancel the
        # task for whatever reason.
        try {
          if { [dict exists $task subst] } {
            set should_execute [ uplevel #0 [subst -nocommands [dict get $task while]]]
          } else {
            set should_execute [ uplevel #0 [dict get $task while] ]
          }
          if { ! [string is bool -strict $should_execute] } { set should_execute 0 }
        } on error {r} { set should_execute 0 }
        set cancel_every [expr { ! $should_execute }]
      } else { set should_execute 1 ; set cancel_every 0 }
      
      if { $should_execute } { 
        if { [dict exists $task subst] } {
          catch { after 0 [subst -nocommands [dict get $task cmd]] }
        } else { after 0 [dict get $task cmd] }
      }
      
      if { [dict exists $task every] && ! $cancel_every } {
        # every - we need to schedule the task to occur again
        if { [dict exists $task times] } {
          dict incr task times -1
          if { [dict get $task times] < 1 } {
            continue
          }
        }
        if { [dict exists $task until] } {
          if { [clock milliseconds] >= [dict get $task until] } {
            continue
          }
        }
        ::task::add_task \
          $task_id \
          $task \
          [expr { [clock milliseconds] + [dict get $task every] }]
      }
    }
    unset task_id ; unset task ; unset task_time
    # We reach here when there are either no more tasks to execute or we need
    # to schedule the next execution evaluation.  $scheduled will tell us this
    # as it will either be {} or the ms until the next event.
    schedule_next
    # We yield and await either the next scheduled task or to be woken up
    # by injection to modify our values.
    yield [info coroutine]
  }
}

# removes a task from the scheduled execution context
proc ::task::remove_tasks { task_ids } {
  upvar 1 tasks tasks
  upvar 1 scheduled scheduled
  upvar 1 task_scheduled task_scheduled
  foreach task_id $task_ids {
    if { [dict exists $tasks $task_id] } {
      dict unset tasks $task_id
      set index [lsearch $scheduled $task_id]
      if { $index != -1 } {
        set scheduled [lreplace $scheduled $index [expr {$index + 1}]]
      }
    }
  }
  set task_scheduled [expr { [lindex $scheduled 1] - [clock milliseconds] }]
  return
}

# when we add a new task to our tasks list, we will add the context to a hash (dict)
# and our scheduled items to the scheduled list in the order of execution.
proc ::task::add_task { task_id context execution_time } {
  upvar 1 tasks     tasks
  upvar 1 scheduled scheduled
  upvar 1 task_scheduled task_scheduled
  if { [dict exists $tasks $task_id] } {
    # If we are scheduling a task with the same id of a previous task
    # then we will remove and cancel the previous task.
    remove_tasks $task_id
  }
  # Add to our event to the list in the appropriate position based on the scheduled time.
  set scheduled [ lsort -stride 2 -index 1 -real [lappend scheduled $task_id $execution_time] ]
  dict set tasks $task_id $context
  set task_scheduled [expr { [lindex $scheduled 1] - [clock milliseconds] }]
  return
}

# next_event reads the tasks and determines the next time that we should
# wake up.
proc ::task::next_task {} { 
  uplevel 1 {
    if { $scheduled eq [list] } {
      set task_id {} ; set task_scheduled {}
    } else {
      set task_scheduled [expr { [lindex $scheduled 1] - [clock milliseconds] }]
      if { $task_scheduled <= 0 } {
        # If the event will be executed we will remove them from the scheduled list
        set scheduled [lassign $scheduled task_id task_time]
        set task [dict get $tasks $task_id]
        dict unset tasks $task_id
      } else { 
        set task_id {} ; set task_scheduled {}
      }
    }
    set task_id
  }
}

proc ::task::schedule_next {} {
  upvar 1 task_scheduled task_scheduled
  upvar 1 after_id after_id
  after cancel $after_id
  if { [string is entier -strict $task_scheduled] } {
    # We have an event to execute in the future, we will sleep for the given
    # period of time.
    if { $task_scheduled > 600000 } {
      # If the next task if more than 10 minutes in the future, we will
      # schedule our wakeup in 10 minutes to keep our task manager fresh.
      set task_scheduled 600000
    }
    set after_id [ after $task_scheduled [list catch [list [info coroutine]]] ]
  }
}
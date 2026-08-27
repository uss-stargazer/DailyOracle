# Daily Oracle

Your own authoritative oracle to tell you what's going to happen and what you're going to do.

In more coherrent words, a cli that loads a list of tasks and distributes them as evenly as possible
between today and their due dates. Then, you just call upon `Oracle` and it tells you what you need
to do today. This way you can literally be as lazy as possible while completing your tasks on time.

## installation

1. make sure your system has PowerShell >=5 (`powershell` or `pwsh`)
2. just clone/download this repo somewhere and add the directory to your PATH

## usage

```powershell
# showcase/TLDR (clone repo then run)
> ./Oracle -All -Dotplot -ConfigFile ./DailyOracle.example.json

# Get a list of tasks to complete (your prophecy)
> Get-Help Oracle
> Oracle                    # today
> Oracle -InDays 1          # tommorow
> Oracle 20                 # 20 days from now
> Oracle -Dates "08/21/77"  # specific date
> Oracle 0, 20              # prophecy for today and for 20 days for now
> Oracle (0..20)            # all prophecy for the next 20 days
> Oracle (0..20) -Dotplot   # dotplot visualization of the next 20 days

# List all tasks
> Get-Help Oracle-Tasks
> Oracle-Tasks

# Add tasks
> Oracle-Tasks -Add "Assignment #0", "Assignment #1" -Date 08/21/2077
> Oracle-Tasks -Add "Assignment #2" -InDays 3   # 3 days from now
> Oracle-Tasks -a "Assignment #3" 3             # 3 days from now
> Oracle-Tasks -a "Assignment #5" -Date 6/18    # specific date
> Oracle-Tasks -Add "Assignment #0"             # won't do anything if task already exists
> Oracle-Tasks -Add "Assignment #4" -ListAll    # will return the final tasks state

# Complete tasks
> Oracle-Tasks -Complete "Assignment #0"
> Oracle-Tasks -c "Assignment #1", "Assignment 2"
> Oracle-Tasks -Add "tmp" -Complete "tmp"           # does nothing basically
> Oracle-Tasks -NoEffects -Complete "Assignment 2"  # disable fireworks
> Oracle-Tasks -CompleteSelect                      # open search and select gui

# Manual spreading (`Oracle` does automated spreading but you should run this regularly)
> Get-Help Oracle-Spread
> Oracle-Spread             # distributes tasks evenly
> Oracle-Spread -Delay      # distributes tasks evenly, but doesn't include today
> Oracle-Spread -KeepToday  # locks tasks set for today, then spreads the rest
```

Note: for tasks names, you should probably choose short names, so you don't have to type as much...

For task management, you can also edit the json directly. By default, it uses the first instance of
`DailyOracle.json` in the following paths:

- `$HOME/OneDrive/Documents`
- `$HOME/Documents`
- `$HOME`
- this directory (the downloaded source)

You can also use symlinks. You can specify the file with `-ConfigFile` See the [schema](#config-schema). for details.

## how it works

NOTE: hasn't been tested for linux (probably doesn't work)

CREDIT: [fireworks animation](https://github.com/p01nd3xt3r/PowershellAnimations)

### algorithm

NOTE: idk how to really format psuedocode, so sorry...

for task distribution, we find the number of tasks to complete during continuous ranges. I think of
it like a staircase of water resovoirs. the tasks are ordered by due date, ascending (very
important), then iteratively added to the last resovoir. if a resovoir exceeds the water level of
the previous resovoir, they are combined into one larger resovoir (the water level is symbolic for
task frequency). here's the psuedocode:

```
# map for distribution of tasks by range (key: date range; value: number of tasks)
# this is the target value of the algorithm
#
# NOTE: in implementation tasksByDayRange uses the day range end as map key (since the start is
# implied to be the end of previous, defaulting to today).
tasksDistribution = EMPTY ORDERED MAP 

FUNCTION addRangeToDistribution(range, n_tasks):
    prev_range, prev_n_tasks = ...
    range = days between due day and last due day
    n_tasks = tasksByDueDay[range]
    freq = n_task / range
    prev_freq = prev_n_tasks / prev_range
    if freq > prev_freq:
        remove taskDistribution[previous_range]
        range = prev_range + range
        n_tasks = prev_n_tasks + n_tasks
        addRangeToDistribution(range, n_tasks)
    else:
        taskDistribution[range] = n_tasks

order tasks by due date ascending
tasksByDueDay = map between due day and number of tasks (by itering over ordered tasks)
foreach due_day:
    addRangeToDistribution(due_day, taskByDueDay[due_day])
```

so once we have the distribution, we use it to resolving dates for each task. we can do this by
walking along the distribution and evenly distributing tasks _in oreder_. since all the tasks are
ordered by due date, tasks will be assigned a date that is before their due date even if the range
in the distribution exceeds that due date. here is the psuedocode:

```
order tasks by due date ascending (should already be done)
task_idx = 0
foreach range in tasksDistribution:
    n_tasks_per_day = int(taskDistribution[range] / range)
    remainder = taskDistribution[range] % range
    gap_size = range / remainder
    for i in range: 
        day = range_start + i
        n_tasks = n_tasks_per_day
        if i % gap_size == 0:
            n_tasks++
        for t in n_task:
            tasks[task_idx].targetday = day
            task_idx++
```

### config schema

note that Task properties starting in `_` are internal state variables (although they technically
can be edited, they'll likely be overwritten).

```json
{
    "type": "array",
    "items": {
        "type": "object",
        "properties": {
            "Name": { "type": "string" },
            "Due": {
                "type": "string",
                "format": "date"
            },
            "Description": { "type": "string" },
            "_TargetDate": {
                "type": "string",
                "format": "date"
            }
        },
        "required": ["Name", "Due"]
    }
}
```

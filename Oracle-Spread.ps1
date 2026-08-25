<#
.SYNOPSIS
    Spread DailyOracle tasks between today and due dates.

.DESCRIPTION
    Loads task file from default location or from -ConfigFile, runs spread algorithm to compute target
    dates, then writes them to task file.

.PARAMETER Delay
    There are two anchor points when spreading: today and the due date. Normally, it equally
    distributes the tasks between the anchors and including the former. If this is set, it only
    distributes between the anchors. (in implementation, its a bit more complicated, but this is the
    gist)

.PARAMETER KeepToday
    Anchor tasks that have _TargetDate as today and apply spread algorithm on the rest. Implicitly
    sets -Delay.
#>

param (
  [switch]$Delay,
  [switch]$KeepToday,
  [string]$ConfigFile,
  [switch]$Silent
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Oracle-Core.ps1"

$script:Tasks = Get-Tasks

if (-not $script:Tasks) {
  Write-Warning 'no tasks to spread'
  return
}

if (-not ($script:Tasks -is [array])) {
  Write-Error 'excpected Tasks from Oracle-Tasks with correct type'
}

# ignore overdue tasks in spread
$script:OverdueTasks = $script:Tasks | Where-Object { $_.Due.Date -lt $today } 
$script:Tasks = $script:Tasks | Where-Object { $_.Due.Date -ge $today } 
if ($script:IgnoredTasks.Count -gt 0) {
  Write-Warning "excluding $($script:OverdueTasks.Count) overdue tasks from spread"
}

# if KeepToday, ignore today tasks and set delay
if ($KeepToday) {
  $script:TodayTasks = $script:Tasks | Where-Object {
    $_._TargetDate -and ($_._TargetDate.Date -le $today)
  } 
  $script:Tasks = $script:Tasks | Where-Object {
    (-not $_._TargetDate) -or ($_._TargetDate.Date -gt $today)
  } 
  if ($script:TodayTasks.Count -gt 0) {
    Write-Warning "excluding $($script:TodayTasks.Count) today tasks from spread"
  }
  $Delay = $true
}

$script:IgnoredTasks = $script:OverdueTasks + $script:TodayTasks
if ($script:Tasks.Count -eq 0) {
  Write-Warning 'no tasks to spread'
  return
}

# order by due date ascending (important!)
$script:Tasks = $script:Tasks | Sort-Object -Property Due

# get task distribution ---------------------------------------------------------------------------

# number of tasks assigned to date range (end date is used as key since start date is implied to be
# the previous range's end date)
$script:TaskDistribution = [ordered]@{}

function Get-TaskDistRange([int]$Idx) {
  $endDays = [array]$script:TaskDistribution.Keys
  $endDay = [int]$endDays[$Idx]
  $startDay = 0
  if ($Idx -ne 0) {
    $startDay = [int]$endDays[$Idx - 1]
  }
  return @{
    StartDay = $startDay
    EndDay = $endDay
    NumTasks = [int]($script:TaskDistribution[$Idx])
    Length = $endDay - $startDay
  } 
}

function Add-RangeToDistribution([int]$endDay, [int]$numTasks) {
  Write-Debug "requested add range: $endDay with $numTasks tasks"

  $prevRange = Get-TaskDistRange -1
  Write-Debug "previous range:"
  $prevRange | Out-String | Write-Debug

  $rangeLength = $endDay - $prevRange.EndDay

  $prevFreq = [double]$prevRange.NumTasks / [double]$prevRange.Length
  $freq = [double]$numTasks / [double]$rangeLength
  if ([double]::IsNaN($prevFreq)) {
    $prevFreq = [double]::PositiveInfinity
  }
  if ([double]::IsNaN($freq)) {
    $freq = [double]::PositiveInfinity
  }
  Write-Debug "prev freq: $prevFreq"
  Write-Debug "freq: $freq"

  if (($freq -ge $prevFreq) -and ($script:TaskDistribution.Count -gt 0)) {
    Write-Debug 'combining current and previous'
    $script:TaskDistribution.Remove($prevRange.EndDay)
    $newEndDay = $endDay
    $newNumTasks = $prevRange.NumTasks + $numTasks
    Add-RangeToDistribution $newEndDay $newNumTasks
  } else {
    Write-Debug "actually added to TaskDist"
    $script:TaskDistribution.Add([object]$endDay, $numTasks)
  }
}

$tasksByDueDay = [ordered]@{}
foreach ($task in $script:Tasks) {
  $dueDay = (New-TimeSpan -Start (Get-Date).Date -End $task.Due).Days
  $tasksByDueDay[[object]$dueDay]++
}
Write-Debug "tasksByDueDay:"
$tasksByDueDay | Out-String | Write-Debug

foreach ($pair in $tasksByDueDay.GetEnumerator()) {
  $dueDay = $pair.Key
  $numTasks = $pair.Value
  Add-RangeToDistribution $dueDay $numTasks
}

Write-Debug 'TaskDistribution computed'

# some sanity checks
$totalDistTasks = $script:TaskDistribution.GetEnumerator() |
  Select-Object -ExpandProperty Value | Measure-Object -Sum
if ($script:Tasks.Count -ne $totalDistTasks.Sum) {
  Write-Error 'invalid number of tasks in computed distribution (dev error)'
}
$maxDistDate = (Get-Date).AddDays(([array]$script:TaskDistribution.Keys)[-1])
if ($script:Tasks[-1].Due.Date -ne $maxDistDate.Date) {
  Write-Error "distribution doesn't contain all tasks (dev error)"
}

# resolve target dates ----------------------------------------------------------------------------

$taskIdx = 0
for ($rangeIdx = 0; $rangeIdx -lt $script:TaskDistribution.Count; $rangeIdx++) {
  $range = Get-TaskDistRange $rangeIdx

  # in general there is (tasks / range) tasks per day, but every (range / remainder) days, there's
  # an extra one
  $range.NumTasks = [double]$range.NumTasks
  $range.Length = [double]($range.Length + 1) # +1 for current day inclusive
  $tasksPerDay = [int][Math]::Floor($range.NumTasks / $range.Length)
  $remainderTasks = [int]($range.NumTasks % $range.Length)
  if ($Delay) {
    $gapSize = $range.Length / [double]($remainderTasks + 1)
    $gapStartIdx = 1
  } else {
    $gapSize = $range.Length / [double]$remainderTasks
    $gapStartIdx = 0
  }

  # since the gap might be a fraction we have to precalculate gap days (rounding down)
  [int[]]$extraTaskDays = @()
  for ($i = 0; $i -lt $remainderTasks; $i++) {
    $gapDay = [int][Math]::Floor(($gapStartIdx + $i) * [double]$gapSize)
    $extraTaskDays += $gapDay
  }

  for ($dayIdx = 0; $dayIdx -lt $range.Length; $dayIdx++) {
    $date = $today.AddDays($range.StartDay + $dayIdx)
    $nTasks = $tasksPerDay
    if ($dayIdx -in $extraTaskDays) {
      $nTasks++
    }
    
    # add next n tasks
    for ($i = 0; $i -lt $nTasks; $i++) {
      $script:Tasks[$taskIdx]._TargetDate = $date
      $taskIdx++
    }
  }
}

# sanity checks
if ($taskIdx -lt ($script:Tasks.Count - 1)) {
  Write-Error "didn't compute target date for all tasks (dev error)"
}

# apply
if ($script:IgnoredTasks) {
  $script:Tasks = @($script:IgnoredTasks) + @($script:Tasks)
}
Write-CliMessage 'spread computed and writing _TargetDate values'
Write-Tasks $script:Tasks

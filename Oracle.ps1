param (
  [Parameter(Position = 0, Mandatory = $false)]
  [int]$InDays,
  [DateTime]$Date,
  [string]$TaskFile,
  [switch]$Silent
)

$InformationPreference = 'Continue'
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if ($Silent) {
  $InformationPreference = 'SilentlyContinue'
}

# takes care of loading $script:TaskFile, $script:Tasks, $script:TargetDay, plus it loads functions
# like Write-Tasks, etc.
. "$PSScriptRoot/Oracle-Tasks.ps1" @PSBoundParameters

if (-not ($script:Tasks)) {
  Write-Error 'excpected Tasks from Oracle-Tasks'
}

# order by due date ascending (important!)
Sort-Object $script:Tasks -proeprty Due

# get task distribution ---------------------------------------------------------------------------

# number of tasks assigned to date range (end date is used as key since start date is implied to be
# the previous range's end date)
$script:TaskDistribution = [ordered]@{}

function Add-RangeToDistribution([int]$endDay, [int]$numTasks) {
  # get $prevNumTasks, $prevEndDay, and $prevPrevEndDay (needed for range, then frequency calc)
  $endDays = [array]$script:TaskDistribution.Keys
  switch ($endDays.Count) {
    0 {
      $prevEndDay = 0
      $prevPrevEndDay = 0
      $prevNumTasks = 0
    }
    1 {
      $prevEndDay = $endDays[-1]
      $prevPrevEndDay = 0
      $prevNumTasks = $script:TaskDistribution[[object]$prevEndDay]
    }
    default {
      $prevEndDay = $endDays[-1]
      $prevPrevEndDay = $endDays[-2]
      $prevNumTasks = $script:TaskDistribution[[object]$prevEndDay]
    }
  }

  $range = $endDay - $prevEndDay
  $prevRange = $prevEndDay - $prevPrevEndDay
  $prevFreq = [double]$prevNumTasks / [double]$prevRange
  if ([double]::IsInfinity($prevFreq)) {
    $prevFreq = 0
  }
  $freq = [double]$numTasks / [double]$range

  if ($freq -gt $prevFreq) {
    $script:TaskDistribution.Remove($prevEndDay)
    $newEndDay = $endDay
    $newNumTasks = $prevNumTasks + $numTasks
    Add-RangeToDistribution $newEndDay $newNumTasks
  } else {
    $script:TaskDistribution.Add([object]$endDay, $numTasks)
  }
}

$tasksByDueDay = [ordered]@{}
foreach ($task in $script:Tasks) {
  $dueDay = (New-TimeSpan -Start (Get-Date).Date -End $task.Due).Days
  $tasksByDueDay[[object]$dueDay]++
}
foreach ($pair in $tasksByDueDay.GetEnumerator()) {
  $dueDay = $pair.Key
  $numTasks = $pair.Value
  Add-RangeToDistribution $dueDay $numTasks
}

$script:TaskDistribution

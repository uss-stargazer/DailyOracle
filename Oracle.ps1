<#
.SYNOPSIS
    CLI entrypoint to DailOracle, used to view get your to-do prophecy.

.DESCRIPTION
    Loads task file from default location or from -TaskFile, applied spreading algorithm for any
    change in tasks (user can change using Oracle-Tasks), and finally returns the prophecy (the list
    of tasks to do) for the supplied dates.

.PARAMETER InDays
    Which days to show prophecy for. List of integers (days from today).

.PARAMETER Dates
    Which days to show prophecy for. List of explicit dates.
#>

param (
  [Parameter(Position = 0)]
  [int[]]$InDays = @(),
  [DateTime[]]$Dates = @(),
  [string]$TaskFile,
  [switch]$Silent
)

$InformationPreference = 'Continue'
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if ($Silent) {
  $InformationPreference = 'SilentlyContinue'
}

$today = (Get-Date).Date
[DateTime[]]$script:TargetDates = (
  $Dates + (
    $InDays | ForEach-Object { $today.AddDays($_) }
  )
) | Sort-Object # order ascending

$null = $PSBoundParameters.Remove('InDays')
$null = $PSBoundParameters.Remove('Dates')
if ($script:TargetDates.Count -eq 0) {
  $script:TargetDates = @($today)
}
$OracleParams = $PSBoundParameters

# loads $script:TaskFile, Get-Tasks, Write-Tasks
. "$PSScriptRoot/Oracle-Core.ps1"

function Load-Tasks() {
  $script:Tasks = Get-Tasks $script:TaskFile
  if (-not $script:Tasks) {
    $script:Tasks = @()
  }
  if (-not ($script:Tasks -is [array])) {
    Write-Error 'excpected Tasks from Oracle-Tasks with correct type'
  }
  $script:OverdueTasks = $script:Tasks | Where-Object { $_.Due -lt $today } 
  $script:Tasks = $script:Tasks | Where-Object { $_.Due -ge $today } 
}

Write-Information "loading tasks from $script:TaskFile"
Load-Tasks

# target value of this script: tasks with targets in at the specified dates
[Task[]]$script:TaskProphecy = @()

# overdue tasks are first priority for any date
if ($script:OverdueTasks.Count -gt 0) {
  Write-Warning "prophecy has $($script:OverdueTasks.Count) overdue tasks!"
  $script:TaskProphecy += $script:OverdueTasks
}

# if there are any values that don't have a target date, spread tasks
if (($script:Tasks | Where-Object { -not $_._TargetDate }).Count -ne 0) {
  Write-Warning "some tasks don't have target dates, so running spread algorithm"
  & "$PSScriptRoot/Oracle-Spread.ps1" @OracleParams
  Load-Tasks
}
if (($script:Tasks | Where-Object { -not $_._TargetDate }).Count -ne 0) {
  Write-Error "spread algorithm run but some tasks still aren't"
}

function Get-Prophecy([datetime]$Date) {
  $d = $Date.Date
  return $script:Tasks | Where-Object { ($_._TargetDate).Date -eq $d }
}

foreach ($targetDate in $script:TargetDates) {
  $script:Prophecy += Get-Prophecy $targetDate
}

if ($script:Prophecy.Count -eq 0) {
  Write-Information 'your future is yours... (nothing to do)'
} else {
  Write-Information 'here is your prophecy:'
}

return $script:Prophecy

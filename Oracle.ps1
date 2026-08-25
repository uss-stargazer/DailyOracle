<#
.SYNOPSIS
    CLI entrypoint to DailOracle, used to view get your to-do prophecy.

.DESCRIPTION
    Loads task file from default location or from -ConfigFile, applied spreading algorithm for any
    change in tasks (user can change using Oracle-Tasks), and finally returns the prophecy (the list
    of tasks to do) for the supplied dates.

.PARAMETER InDays
    Which days to show prophecy for. List of integers (days from today).

.PARAMETER Dates
    Which days to show prophecy for. List of explicit dates.

.PARAMETER Dotplot
    Show fancy dotplot to visual task distribution. Shows in from min(Dates) to max(Dates);
    everything in between.
#>

param (
  [Parameter(Position = 0)]
  [int[]]$InDays = @(),
  [DateTime[]]$Dates = @(),
  [switch]$Dotplot,
  [string]$ConfigFile,
  [switch]$Silent
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Oracle-Core.ps1"

[DateTime[]]$script:TargetDates = (
  @($Dates) + @($InDays | ForEach-Object { $today.AddDays($_) })
) | Sort-Object # order ascending
if ($script:TargetDates.Count -eq 0) {
  $script:TargetDates = @($today)
}

$null = $PSBoundParameters.Remove('InDays')
$null = $PSBoundParameters.Remove('Dates')
$null = $PSBoundParameters.Remove('Dotplot')
$OracleParams = $PSBoundParameters

function Load-Tasks() {
  $script:Tasks = Get-Tasks
  if (-not $script:Tasks) {
    $script:Tasks = @()
  }
  if (-not ($script:Tasks -is [array])) {
    Write-Error 'excpected Tasks from Oracle-Tasks with correct type'
  }
  $script:OverdueTasks = $script:Tasks | Where-Object { $_.Due -lt $today } 
  $script:Tasks = $script:Tasks | Where-Object { $_.Due -ge $today } 
}

Load-Tasks

# target value of this script: tasks with targets in at the specified dates
[Task[]]$script:TaskProphecy = @()

# overdue tasks are first priority for any date
if ($script:OverdueTasks.Count -gt 0) {
  Write-Warning "prophecy has $($script:OverdueTasks.Count) overdue tasks!"
  $script:TaskProphecy += @($script:OverdueTasks)
}

# if there are any values that don't have a target date, spread tasks
if (($script:Tasks | Where-Object { -not $_._TargetDate }).Count -ne 0) {
  Write-Warning "some tasks don't have target dates, so running spread algorithm"
  if (($script:Tasks | Where-Object { $_._TargetDate }).Count -ne 0) {
    $OracleParams['-KeepToday'] = $true
  }
  & "$PSScriptRoot/Oracle-Spread.ps1" @OracleParams
  Load-Tasks
}
if (($script:Tasks | Where-Object { -not $_._TargetDate }).Count -ne 0) {
  Write-Error "spread algorithm run but some tasks still aren't"
}

foreach ($targetDate in $script:TargetDates) {
  $date = $targetDate.Date
  $script:Prophecy += @($script:Tasks | Where-Object { ($_._TargetDate).Date -eq $date })
}

function Write-ProphecyDotplot() {
  if ($script:Prophecy.Count -gt 0) {
    $min = $script:Prophecy[0]._TargetDate.Date
    $max = $script:Prophecy[-1]._TargetDate.Date
  } else {
    Write-Host 'no prophecy to plot for dates'
    return
  }
  for ($d = $min; $d -le $max; $d = $d.AddDays(1)) {
    $nTasks = ($script:Prophecy | Where-Object { $_._TargetDate.Date -eq $d }).Count
    Write-Host "$($d.ToString("MM/dd/yyyy")) | " -NoNewLine
    "x" * $nTasks | Format-Rainbow
  }
}

if ($Dotplot) {
  Write-ProphecyDotplot
} else {
  if ($script:Prophecy.Count -eq 0) {
    Write-Host 'your future is yours... (nothing to do)'
  } else {
    Write-Host 'Behold your ' -NoNewLine
    'PrOpHeCy' | Format-Rainbow | Write-Host
  }

  return $script:Prophecy
}

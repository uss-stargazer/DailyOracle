<#
.SYNOPSIS
    Manage DailyOracle tasks.

.DESCRIPTION
    Loads task file from default location or from -ConfigFile, applies operations (Add or Complete),
    updates task file, and optionally returns tasks (if -ListAll).
#>

param(
  [Parameter(Position = 0)]
  [datetime]$Date = (Get-Date).Date, 
  [nullable[int]]$InDays,
  [string[]]$Add = @(),
  [string[]]$Complete = @(),
  [switch]$SelectComplete,
  [switch]$ListAll,
  [switch]$NoEffects,
  [string]$ConfigFile,
  [switch]$Silent
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Oracle-Core.ps1"

$script:TargetDate = $Date
if ($InDays -ne $null) {
  $script:TargetDate = (Get-Date).AddDays($InDays).Date
}

$script:Tasks = Get-Tasks

if ($SelectComplete) {
  $selected = $script:Tasks | Out-GridView -Title "Select task(s) to complete" -OutputMode Multiple
  if ($selected) {
    $Complete += $selected.Name
  }
}

$Add = $Add | Where-Object {
  if ($_ -in $script:Tasks.Name) {
    Write-Warning "task already exists: $_"
    $false
  } else {
    Write-CliMessage -Label 'NEW' -Color Magenta "$_ (due $($script:TargetDate.ToShortDateString()))"
    $true
  }
}

$Complete = $Complete | Where-Object {
  if ($_ -in $script:Tasks.Name) {
    Write-CliMessage -Label 'DONE' -Color Green "$_"
    $true
  } else {
    Write-Warning "task doesn't exist: $_"
    $false
  }
}

# ListAll implied if no operations specified
$ListAll = $ListAll -or -not ($Add -or $Complete)

if ($Add -or $Complete) {
  if ($Add.Count -gt 0) {
    $script:Tasks += foreach ($name in $Add) {
      [Task]@{ Name = $name; Due = $script:TargetDate }
    }
  }

  if ($Complete.Count -gt 0) {
    $script:Tasks = $script:Tasks | Where-Object { -not ($_.Name -in $Complete) }
    if (-not $NoEffects) {
      Write-Fireworks
    }
  }

  Write-CliMessage 'writing tasks'
  Write-Tasks $script:Tasks
}

if ($ListAll) {
  if ($script:Tasks.Count -eq 0) {
    Write-CliMessage 'no tasks'
  }
  return $script:Tasks
}

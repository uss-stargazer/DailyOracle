<#
.SYNOPSIS
    Manage DailyOracle tasks.

.DESCRIPTION
    Loads task file from default location or from -TaskFile, applies operations (Add or Complete),
    updates task file, and optionally returns tasks (if -ListAll).
#>

param(
  [Parameter(Position = 0)]
  [datetime]$Date = (Get-Date).Date, 
  [nullable[int]]$InDays,
  [string[]]$Add = @(),
  [string[]]$Complete = @(),
  [string]$TaskFile,
  [switch]$ListAll,
  [switch]$Silent
)

$InformationPreference = 'Continue'
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if ($Silent) {
  $InformationPreference = 'SilentlyContinue'
}

# ListAll implied if no operations specified
$ListAll = $ListAll -or -not ($Add -or $Complete)

$script:TargetDate = $Date
if ($InDays -ne $null) {
  $script:TargetDate = (Get-Date).AddDays($InDays).Date
}

# loads $script:TaskFile, Get-Tasks, Write-Tasks
. "$PSScriptRoot/Oracle-Core.ps1"

Write-Information "loading tasks from $script:TaskFile"
$script:Tasks = Get-Tasks $script:TaskFile

function Start-CompletionCelebration() {
  Write-Host 'hooray' -ForegroundColor Green
}

if ($Add -or $Complete) {
  $Add = $Add | Where-Object {
    if ($_ -in $script:Tasks.Name) {
      Write-Warning "task already exists: $_"
      $false
    } else {
      Write-Information "new task: $_ (due on $script:TargetDate)"
      $true
    }
  }
  if ($Add.Count -gt 0) {
    $NewTasks = $Add | ForEach-Object { [Task]@{ Name = $_; Due = $script:TargetDate } }
    $script:Tasks = [Task[]]$script:Tasks + [Task[]]$NewTasks
  }

  $Complete = $Complete | Where-Object {
    if ($_ -in $script:Tasks.Name) {
      Write-Information "remove task: $_"
      $true
    } else {
      Write-Warning "no task to complete: $_"
      $false
    }
  }
  if ($Complete.Count -gt 0) {
    $script:Tasks = $script:Tasks | Where-Object { -not ($_.Name -in $Complete) }
    Start-CompletionCelebration
  }

  Write-Information 'writing tasks'
  Write-Tasks $script:Tasks $script:TaskFile
}

if ($ListAll) {
  if ($script:Tasks.Count -eq 0) {
    Write-Information 'no tasks'
  }
  return $script:Tasks
}

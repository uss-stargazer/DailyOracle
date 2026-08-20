param(
  [Parameter(Position = 0, Mandatory = $false)]
  [int]$InDays,
  [datetime]$Date, 
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

$script:TargetDay = 0 # script uses dates relative to current, default today
if ($InDays -ne $null) {
  $script:TargetDay = $InDays
} elseif ($Date -ne $null) {
  $script:TargetDay = (New-TimeSpan -Start (Get-Date).Date -End $Date).Days
}
$script:TargetDate = (Get-Date).AddDays($script:TargetDay)

if ($TaskFile) {
  $script:TaskFile = $TaskFile
} else {
  $script:TaskFile = Join-Path $PSScriptRoot 'oracle-tasks.json'
}

class Task {
  [ValidateNotNullOrEmpty()]
  [string]$Name
  [datetime]$Due

  [object] ToRaw() {
    return @{
      Name  = $this.Name
      Due   = $this.Due.ToString("yyyy-MM-dd")
    }
  }
}

function Get-Tasks([string]$TaskFile) {
  if (-not (Test-Path $TaskFile)) {
    return @()
  }
  try {
    $json = Get-Content $TaskFile -Raw | ConvertFrom-Json
    return [Task[]]$json
  } catch {
    Write-Error "invalid task json... refer to README!"
  }
}

function Write-Tasks([Task[]]$Tasks, [string]$TaskFile) {
  if (-not $Tasks -or ($Tasks.Count -eq 0)) {
    Set-Content -Path $TaskFile -Value '[]'
  } else {
    $Tasks.ToRaw() | ConvertTo-Json -Depth 100 | Set-Content -Path $TaskFile
  }
}

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

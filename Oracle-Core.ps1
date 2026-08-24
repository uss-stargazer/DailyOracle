class Task {
  [ValidateNotNullOrEmpty()]
  [string]$Name
  [ValidateNotNullOrEmpty()]
  [datetime]$Due
  [string]$Description
  [nullable[datetime]]$_TargetDate
}

# should be a Task method but powershell doesn't like that when converting from json...
function ConvertTo-SerializedTask([Task]$task) {
  $serialized = @{
    Name = $task.Name
    Due  = $task.Due.ToString("yyyy-MM-dd")
  }
  if ($task.Description) {
    $serialized.Description = $task.Description
  }
  if ($task._TargetDate) {
    $serialized._TargetDate = $task._TargetDate.ToString("yyyy-MM-dd")
  }
  return $serialized
}

function Get-Tasks([string]$TaskFile) {
  if (-not (Test-Path $TaskFile)) {
    return @()
  }
  try {
    $json = Get-Content $TaskFile -Raw | ConvertFrom-Json
    return [Task[]]($json | ForEach-Object { [Task]$_ })
  } catch {
    Write-Error "invalid task json; refer to README!"
  }
}

function Write-Tasks([Task[]]$Tasks, [string]$TaskFile) {
  if (-not $Tasks -or ($Tasks.Count -eq 0)) {
    Set-Content -Path $TaskFile -Value '[]'
  } else {
    $Tasks |
      ForEach-Object { ConvertTo-SerializedTask $_ } |
      ConvertTo-Json -Depth 100 |
      Set-Content -Path $TaskFile
  }
}

if (-not $script:TaskFile) {
  $script:TaskFile = Join-Path $PSScriptRoot 'oracle-tasks.json'
}

function Write-CliInfo([string]$Message) {
  if ($InformationPreference -ne 'SilentlyContinue') {
    Write-Host -ForegroundColor blue 'INFO' -NoNewLine
    Write-Host "> $Message"
  }
}

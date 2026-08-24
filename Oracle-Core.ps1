class Task {
  [ValidateNotNullOrEmpty()]
  [string]$Name
  [ValidateNotNullOrEmpty()]
  [datetime]$Due

  [string]$Description
  [nullable[datetime]]$_TargetDate

  [object] Serialize() {
    $serialized = @{
      Name = $this.Name
      Due  = $this.Due.ToString("yyyy-MM-dd")
    }
    if ($this.Description) {
      $serialized.Description = $this.Description
    }
    if ($this._TargetDate) {
      $serialized._TargetDate = $this._TargetDate.ToString("yyyy-MM-dd")
    }
    return $serialized
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
    Write-Error "invalid task json; refer to README!"
  }
}

function Write-Tasks([Task[]]$Tasks, [string]$TaskFile) {
  if (-not $Tasks -or ($Tasks.Count -eq 0)) {
    Set-Content -Path $TaskFile -Value '[]'
  } else {
    $Tasks |
      ForEach-Object { $_.Serialize() } |
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

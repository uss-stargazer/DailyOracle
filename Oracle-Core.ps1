$today = (Get-Date).Date

# task management ---------------------------------------------------------------------------------

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

function Get-Tasks() {
  if (-not (Test-Path $script:ConfigFile)) {
    return @()
  }
  try {
    $json = Get-Content $script:ConfigFile -Raw | ConvertFrom-Json
    return [Task[]]($json | ForEach-Object { [Task]$_ })
  } catch {
    Write-Error "invalid task json; refer to README!"
  }
}

function Write-Tasks($Tasks) { # NOTE: don't try to put [Task[]] because powershell complains can't convert [Task] to [Task] (??!?!)
  if ((-not $Tasks) -or ($Tasks.Count -eq 0)) {
    Set-Content -Path $script:ConfigFile -Value '[]'
  } else {
    $Tasks |
      ForEach-Object { ConvertTo-SerializedTask $_ } |
      ConvertTo-Json -Depth 100 |
      Set-Content -Path $script:ConfigFile
  }
}

# misc utils --------------------------------------------------------------------------------------

function Write-CliMessage([string]$Message, [string]$Label = 'INFO', [string]$Color = 'Blue') {
  if ($InformationPreference -ne 'SilentlyContinue') {
    Write-Host -ForegroundColor $Color $Label -NoNewLine
    Write-Host "> $Message"
  }
}

$global:COLORS = 2, 3, 4, 6, 8, 10, 11, 12, 13, 14, 15
$esc = [char]27

# https://www.bgreco.net/powershell/format-rainbow/
function Format-Rainbow() {
	$input | Out-String -Stream | % {
		$chars = $_.TrimEnd() -split ''
		foreach($char in $chars) {
			Write-Host -ForegroundColor (Get-Random $global:COLORS) $char -NoNewline
		}
		Write-Host
	}
}

# firworks paths
$FireworksRoot = "$PSScriptRoot/fireworks"
$FireworksPath = Join-Path $FireworksRoot 'ascii.txt'
$FireworksSoundPath = Join-Path $FireworksRoot 'sfx.wav'
$NoFireworks = $false
If ((!(Test-Path -pathtype leaf -literalpath $FireworksPath)) -or (!(Test-Path -pathtype leaf -literalpath $FireworksSoundPath))) {
  Write-Warning 'no fireworks media files!'
  $NoFireworks = $true
}

# CREDIT: https://github.com/p01nd3xt3r/PowershellAnimations/blob/main/Functions/Get-Fireworks.ps1
function Write-Fireworks([int]$Speed = 15) {
  if ($NoFireworks) {
    return
  }
  Write-Host -NoNewLine ([char]27 + "[?1049h") # alt screen
  Clear-Host
  [console]::CursorVisible = $False

  # sound
  $Frames = (Get-Content $FireworksPath -Raw) -split '<del>'
  $PlaySound = New-Object System.Media.SoundPlayer
  $PlaySound.SoundLocation = $FireworksSoundPath
  $PlaySound.play()

  # Making it so that if you hit ctrl+c, the script does a couple things before stopping. I'm
  # basically disabling the standard ctrl+c functionality and then just capturing those keys and
  # responding with the things I want to and a Break. Notice that the animation is nested within
  # this, and While ($True) runs infinitely.
  [console]::TreatControlCAsInput = $True
  foreach ($frame in $Frames) { 
    If ([console]::KeyAvailable) {
      Break
    }
    $c = 30 + [int]((Get-Random $global:COLORS) / 2)
    Write-Host "${esc}[${c}m${frame}${esc}[0m" -NoNewline # -ForegroundColor isn't reliable in alt screen
    Start-Sleep -Milliseconds $Speed
    Clear-Host
  }

  [console]::TreatControlCAsInput = $False
  [console]::CursorVisible = $True
  Write-Host -NoNewLine ([char]27 + "[?1049l") # exit alt screen
}

# shared script initialization --------------------------------------------------------------------

$InformationPreference = 'Continue'
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if ($script:Silent) {
  $InformationPreference = 'SilentlyContinue'
}

function Get-DefaultConfigFile() {
  $dirs = Get-Item "$HOME/Documents", "$HOME", "$PSScriptRoot" -ErrorAction SilentlyContinue
  $file = Get-ChildItem -Path $dirs -Filter "DailyOracle.json" -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if (-not $file) {
    $file = Join-Path $dirs[0] 'DailyOracle.json'
  }
  return $file
}

if (-not $script:ConfigFile) {
  $script:ConfigFile = Get-DefaultConfigFile
  Write-CliMessage "using config at $script:ConfigFile"
}

param (
  [string]$InstallDirectory = $PSScriptRoot,
  [string]$Repo = 'uss-stargazer/DailyOracle',
  [string]$Branch = 'main',
  [switch]$Silent
)

$InformationPreference = 'Continue'
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
if ($Silent) {
  $InformationPreference = 'SilentlyContinue'
}

$GithubRepo = "https://github.com/$Repo"
$GithubRepoZip = "$GithubRepo/archive/refs/heads/$Branch.zip"

function Test-GitRepo([string]$Dir) {
  git -C "$Dir" rev-parse --is-inside-work-tree > $null
  return $LASTEXITCODE -eq 0
}

if (
  (Test-Path $InstallDirectory) -and `
    (Get-Command 'git' -ErrorAction SilentlyContinue) -and `
    (Test-GitRepo $InstallDirectory)
) {
  Write-Information 'git available and git repo detected, so pulling'
  git -C "$InstallDirectory" pull origin "$Branch"
  git -C "$InstallDirectory" checkout "$Branch"
} else {
  #if (Test-Path $InstallDirectory) {
    #Write-Warning "$InstallDirectory already exists"
    #if (-not $Silent -and -not ((Read-Host "Overwrite InstallDirectory? (Y/N)").Trim().ToLower() -in @('y', 'yes'))) {
      #exit 1
    #}
    #Remove-Item $InstallDirectory -Force -Recurse
  #}

  $tmpZip = New-TemporaryFile
  Move-Item $tmpZip "$tmpZip.zip"
  $tmpZip = Get-Item "$tmpZip.zip"
  $tmpExtracted = Join-Path $tmpZip.Directory 'DailyOracle_update'
  New-Item $InstallDirectory -ItemType Directory -Force | Out-Null

  Write-Information "downloading source from $GithubRepoZip"
  Invoke-WebRequest -Uri "$GithubRepoZip" -OutFile $tmpZip

  Write-Information "expanding to $InstallDirectory"
  Expand-Archive -Path $tmpZip -DestinationPath $tmpExtracted -Force
  Remove-Item $tmpZip -Force

  $extracted = $tmpExtracted
  $childDirs = Get-ChildItem $extracted -Directory
  if ($childDirs.Count -eq 1) {
    $extracted = ($childDirs | Select-Object -First 1).FullName
  }
  Copy-Item -Path "$extracted/*" -Destination $InstallDirectory -Recurse -Force
  Remove-Item $tmpExtracted -Force -Recurse
}

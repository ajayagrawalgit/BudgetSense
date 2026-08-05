#!/usr/bin/env pwsh
<#
.SYNOPSIS
  defluff - shake the fluff out of a Flutter/Dart repo.
.DESCRIPTION
  Removes generated caches, build output, tool caches, coverage, platform glue
  and OS junk so you can start fresh before a new feature, a test run, or a git
  push. It only ever touches known-regenerable "fluff". Your source code,
  pubspec.lock, signing keystores (*.jks), key.properties and .git are never
  touched, even though some of them are gitignored.
.PARAMETER DryRun
  Show what would be removed without deleting anything.
.PARAMETER Deep
  Also remove generated *.g.dart / *.freezed.dart / *.mocks.dart.
.PARAMETER Regen
  After cleaning, run flutter pub get + build_runner to restore a buildable state.
.EXAMPLE
  ./scripts/defluff.ps1
.EXAMPLE
  ./scripts/defluff.ps1 -DryRun
.EXAMPLE
  ./scripts/defluff.ps1 -Deep -Regen
#>
[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$Deep,
  [switch]$Regen
)

$ErrorActionPreference = 'Stop'

# Repo root is the parent of this script's folder. Confirm it is a Flutter
# project before we delete a single thing.
$Root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $Root 'pubspec.yaml'))) {
  Write-Host "This does not look like a Flutter repo (no pubspec.yaml at $Root). Aborting." -ForegroundColor Red
  exit 1
}
Set-Location $Root

$script:TotalBytes = 0

function Get-SizeBytes([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return 0 }
  try {
    $sum = (Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sum) { return 0 } else { return $sum }
  } catch { return 0 }
}

function Format-Size([double]$Bytes) {
  $u = 'B','KB','MB','GB','TB'; $i = 0; $s = [double]$Bytes
  while ($s -ge 1024 -and $i -lt 4) { $s /= 1024; $i++ }
  return ('{0:N1} {1}' -f $s, $u[$i])
}

function Invoke-Zap([string]$Path, [string]$Label) {
  if (-not $Label) { $Label = $Path }
  if (Test-Path -LiteralPath $Path) {
    $bytes = Get-SizeBytes $Path
    $script:TotalBytes += $bytes
    if ($DryRun) {
      Write-Host ("  would remove  {0,-46} ({1})" -f $Label, (Format-Size $bytes)) -ForegroundColor Yellow
    } else {
      Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
      Write-Host ("  removed       {0,-46} ({1})" -f $Label, (Format-Size $bytes)) -ForegroundColor Green
    }
  }
}

Write-Host ("defluff (shaking the fluff out of {0})" -f (Split-Path -Leaf $Root)) -ForegroundColor Cyan
if ($DryRun) { Write-Host "dry run: nothing will actually be deleted" -ForegroundColor Yellow }
Write-Host ""

Write-Host "Caches and build output"
Invoke-Zap ".dart_tool"                    ".dart_tool/ (pub + build cache)"
Invoke-Zap "build"                         "build/ (compiled output)"
Invoke-Zap "coverage"                      "coverage/ (test coverage)"
Invoke-Zap "dist"                          "dist/ (staged distributables)"
Invoke-Zap ".flutter-plugins"              ".flutter-plugins"
Invoke-Zap ".flutter-plugins-dependencies" ".flutter-plugins-dependencies"

Write-Host ""
Write-Host "Android"
Invoke-Zap "android/.gradle"    "android/.gradle/ (Gradle cache)"
Invoke-Zap "android/build"      "android/build/"
Invoke-Zap "android/app/build"  "android/app/build/"

Write-Host ""
Write-Host "iOS platform glue"
Invoke-Zap "ios/Pods"                                  "ios/Pods/"
Invoke-Zap "ios/.symlinks"                             "ios/.symlinks/"
Invoke-Zap "ios/Flutter/ephemeral"                     "ios/Flutter/ephemeral/"
Invoke-Zap "ios/Flutter/Generated.xcconfig"            "ios/Flutter/Generated.xcconfig"
Invoke-Zap "ios/Flutter/flutter_export_environment.sh" "ios/Flutter/flutter_export_environment.sh"

Write-Host ""
Write-Host "OS junk"
Get-ChildItem -Path . -Recurse -Force -Include '.DS_Store','Thumbs.db' -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } |
  ForEach-Object { Invoke-Zap $_.FullName ($_.FullName.Substring($Root.Length + 1)) }

if ($Deep) {
  Write-Host ""
  Write-Host "Generated Dart code (-Deep)"
  Get-ChildItem -Path lib,test -Recurse -Force -Include '*.g.dart','*.freezed.dart','*.mocks.dart' -ErrorAction SilentlyContinue |
    ForEach-Object { Invoke-Zap $_.FullName ($_.FullName.Substring($Root.Length + 1)) }
}

Write-Host ""
if ($DryRun) {
  Write-Host ("Would reclaim about {0}." -f (Format-Size $script:TotalBytes)) -ForegroundColor Yellow
} else {
  Write-Host ("All fluffed out. Reclaimed about {0}." -f (Format-Size $script:TotalBytes)) -ForegroundColor Green
}

if ($Regen -and -not $DryRun) {
  Write-Host ""
  Write-Host "Restoring a buildable state..." -ForegroundColor Cyan
  if (Get-Command flutter -ErrorAction SilentlyContinue) {
    flutter pub get
    dart run build_runner build --delete-conflicting-outputs
    Write-Host "Ready. Fresh as a daisy." -ForegroundColor Green
  } else {
    Write-Host "flutter not found on PATH; skipped pub get / build_runner." -ForegroundColor Yellow
  }
} elseif (-not $DryRun) {
  Write-Host "Tip: run 'flutter pub get' (and build_runner) before building, or use -Regen." -ForegroundColor DarkGray
}

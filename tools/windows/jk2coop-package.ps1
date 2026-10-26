<#
.SYNOPSIS
    Packs the current co-op build into one zip for testing on another PC.

.DESCRIPTION
    Run this on the PC where you build the game. It collects
      openjo_sp.x86_64.exe, rdjosp-vanilla_x86_64.dll, SDL2.dll,
      base\jospgamex86_64.dll, base\zz-coop-ui.pk3,
      Install-JK2Coop.ps1, Install.cmd, README.txt, version.txt
    into dist\JK2Coop-test-<date>.zip in this repository (-Name changes the
    file name, e.g. -Name JK2Coop-v0.1 for a release).

    The zip holds only the co-op build. No Jedi Outcast game files go in it:
    the other PC needs its own copy of the game (Steam, GOG or disc).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\tools\windows\jk2coop-package.ps1
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\tools\windows\jk2coop-package.ps1 -BuildDir openjk\build-release -Name JK2Coop-v0.1
#>
[CmdletBinding()]
param(
    # folder holding openjo_sp.x86_64.exe (default: openjk\build in this repository)
    [string]$BuildDir = '',
    # where the zip goes (default: dist\ in this repository)
    [string]$OutDir = '',
    # zip file name without .zip (default: JK2Coop-test-<date>)
    [string]$Name = '',
    # also include the .pdb debug symbols (bigger zip, better crash reports)
    [switch]$Symbols
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$repo = (Resolve-Path -LiteralPath (Join-Path $here '..\..')).Path
if (-not $BuildDir) { $BuildDir = Join-Path $repo 'openjk\build' }
if (-not [IO.Path]::IsPathRooted($BuildDir)) { $BuildDir = Join-Path $repo $BuildDir }
# a fresh build folder has no SDL2.dll yet: take the one OpenJK ships
$sdl = Join-Path $BuildDir 'SDL2.dll'
if (-not (Test-Path -LiteralPath $sdl)) { $sdl = Join-Path $repo 'openjk\lib\SDL2\bin\x64\SDL2.dll' }
if (-not $OutDir) { $OutDir = Join-Path $repo 'dist' }

# what goes in, and where from
$items = @(
    @{ From = (Join-Path $BuildDir 'openjo_sp.x86_64.exe');            To = 'openjo_sp.x86_64.exe' },
    @{ From = (Join-Path $BuildDir 'rdjosp-vanilla_x86_64.dll');       To = 'rdjosp-vanilla_x86_64.dll' },
    @{ From = $sdl;                                                    To = 'SDL2.dll' },
    @{ From = (Join-Path $BuildDir 'jospgamex86_64.dll');              To = 'base\jospgamex86_64.dll' },
    @{ From = (Join-Path $repo 'assets\coop-ui\zz-coop-ui.pk3');       To = 'base\zz-coop-ui.pk3' },
    @{ From = (Join-Path $here 'Install-JK2Coop.ps1');                 To = 'Install-JK2Coop.ps1' },
    @{ From = (Join-Path $here 'Install-JK2Coop.cmd');                 To = 'Install.cmd' },
    @{ From = (Join-Path $here 'package-README.txt');                  To = 'README.txt' },
    @{ From = (Join-Path $repo 'LICENSE');                             To = 'LICENSE.txt' }
)
if ($Symbols) {
    $items += @{ From = (Join-Path $BuildDir 'openjo_sp.x86_64.pdb'); To = 'openjo_sp.x86_64.pdb' }
    $items += @{ From = (Join-Path $BuildDir 'jospgamex86_64.pdb');   To = 'base\jospgamex86_64.pdb' }
}

$missing = $items | Where-Object { -not (Test-Path -LiteralPath $_.From) }
if ($missing) {
    foreach ($m in $missing) { Write-Host "Missing: $($m.From)" -ForegroundColor Red }
    throw 'Build the game first (ninja in openjk\build) and run tools\build-coop-ui-pk3.sh if the pk3 is missing.'
}

$exeTime = (Get-Item -LiteralPath $items[0].From).LastWriteTime
$dllTime = (Get-Item -LiteralPath $items[3].From).LastWriteTime

$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$stage = Join-Path ([IO.Path]::GetTempPath()) "jk2coop-package-$stamp"
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path (Join-Path $stage 'base') | Out-Null

foreach ($i in $items) {
    Copy-Item -LiteralPath $i.From -Destination (Join-Path $stage $i.To) -Force
}

# version.txt: when and from which commit, so bug reports can name the build
$commit = 'unknown'
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    $c = & git -C $repo rev-parse --short HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $c) { $commit = $c.Trim() }
    $dirty = & git -C $repo status --porcelain 2>$null
    if ($dirty) { $commit += ' (plus uncommitted changes)' }
}
Set-Content -LiteralPath (Join-Path $stage 'version.txt') -Encoding ASCII -Value @(
    "JK2 co-op test build",
    "packed:  $(Get-Date -Format 'yyyy-MM-dd HH:mm')",
    "commit:  $commit",
    "exe:     $exeTime",
    "game:    $dllTime")

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
if (-not $Name) { $Name = "JK2Coop-test-$stamp" }
$zip = Join-Path $OutDir "$Name.zip"
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -Force
Remove-Item -LiteralPath $stage -Recurse -Force

$sizeMB = [math]::Round((Get-Item -LiteralPath $zip).Length / 1MB, 1)
Write-Host ''
Write-Host "Package ready: $zip ($sizeMB MB)" -ForegroundColor Green
Write-Host 'Copy it to the other PC, unzip it, and double-click Install.cmd.'

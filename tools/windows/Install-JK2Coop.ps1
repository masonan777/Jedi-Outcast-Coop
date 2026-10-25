<#
.SYNOPSIS
    Installs the Jedi Outcast co-op test build on this PC.

.DESCRIPTION
    Run this from the unzipped test package. It:
      1. finds your own Jedi Outcast install (Steam, GOG or disc) -- you must
         own the game; nothing from it is copied or changed, the co-op build
         reads its data files in place,
      2. copies the co-op build to %LOCALAPPDATA%\JK2Coop (or -InstallDir),
      3. checks for the Microsoft Visual C++ runtime the game needs,
      4. puts a "JK2 Co-op" shortcut on the desktop.

    Run it again with a newer package to update.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Install-JK2Coop.ps1
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Install-JK2Coop.ps1 -GameDir "D:\Games\Jedi Outcast"
#>
[CmdletBinding()]
param(
    # your Jedi Outcast folder (the one containing GameData, or GameData itself)
    [string]$GameDir = '',
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'JK2Coop'),
    [switch]$NoShortcut
)

$ErrorActionPreference = 'Stop'
$src = $PSScriptRoot

function Test-JK2([string]$dir) {
    # returns the folder that holds base\assets0.pk3, or $null
    if (-not $dir) { return $null }
    foreach ($c in @($dir, (Join-Path $dir 'GameData'))) {
        if (Test-Path -LiteralPath (Join-Path $c 'base\assets0.pk3')) { return (Resolve-Path -LiteralPath $c).Path }
    }
    return $null
}

function Find-JK2 {
    $libs = @()
    $steam = $null
    try { $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction Stop).SteamPath } catch { }
    if ($steam) {
        $steam = $steam -replace '/', '\'
        $libs += $steam
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            foreach ($m in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"path"\s+"([^"]+)"')) {
                $libs += ($m.Groups[1].Value -replace '\\\\', '\')
            }
        }
    }
    foreach ($l in $libs) {
        $r = Test-JK2 (Join-Path $l 'steamapps\common\Jedi Outcast')
        if ($r) { return $r }
    }
    $guesses = @(
        "${env:ProgramFiles(x86)}\GOG Galaxy\Games\Star Wars Jedi Knight II",
        'C:\GOG Games\Star Wars Jedi Knight II',
        'C:\GOG Games\Star Wars - Jedi Knight II',
        "${env:ProgramFiles(x86)}\LucasArts\Star Wars JK II Jedi Outcast",
        "${env:ProgramFiles}\LucasArts\Star Wars JK II Jedi Outcast")
    foreach ($g in $guesses) {
        $r = Test-JK2 $g
        if ($r) { return $r }
    }
    return $null
}

Write-Host 'Jedi Outcast co-op - test install' -ForegroundColor Cyan

# 1. the player's own game
$data = Test-JK2 $GameDir
if (-not $data) { $data = Find-JK2 }
while (-not $data) {
    Write-Host "Couldn't find Jedi Outcast automatically."
    $answer = Read-Host 'Paste the folder where Jedi Outcast is installed (or press Enter to cancel)'
    if (-not $answer) { throw 'Cancelled: Jedi Outcast not found.' }
    $data = Test-JK2 ($answer.Trim('"'))
    if (-not $data) { Write-Host "No base\assets0.pk3 under that folder or its GameData folder." -ForegroundColor Yellow }
}
Write-Host "Jedi Outcast found: $data"

# 2. copy the co-op build
$files = @('openjo_sp.x86_64.exe', 'rdjosp-vanilla_x86_64.dll', 'SDL2.dll')
foreach ($f in $files + @('base\jospgamex86_64.dll', 'base\zz-coop-ui.pk3')) {
    if (-not (Test-Path -LiteralPath (Join-Path $src $f))) { throw "The package is missing $f - unzip all of it and run this from inside." }
}
New-Item -ItemType Directory -Force -Path (Join-Path $InstallDir 'base') | Out-Null
foreach ($f in $files) { Copy-Item -LiteralPath (Join-Path $src $f) -Destination (Join-Path $InstallDir $f) -Force }
Get-ChildItem -LiteralPath (Join-Path $src 'base') -File | ForEach-Object {
    $dest = Join-Path (Join-Path $InstallDir 'base') $_.Name
    # keep the player's own settings file once it exists
    if ($_.Name -eq 'autoexec_sp.cfg' -and (Test-Path -LiteralPath $dest)) { return }
    Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
}
foreach ($extra in @('README.txt', 'version.txt')) {
    if (Test-Path -LiteralPath (Join-Path $src $extra)) { Copy-Item -LiteralPath (Join-Path $src $extra) -Destination $InstallDir -Force }
}
# files unzipped from a download carry a "came from the internet" mark that
# makes Windows warn on every start; this build was copied on purpose
Get-ChildItem -LiteralPath $InstallDir -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
Write-Host "Installed to: $InstallDir"

# 3. Visual C++ runtime (2015-2022, x64)
$sys = Join-Path $env:WINDIR 'System32'
$missing = @('vcruntime140.dll', 'vcruntime140_1.dll', 'msvcp140.dll') | Where-Object { -not (Test-Path -LiteralPath (Join-Path $sys $_)) }
if ($missing) {
    Write-Host ''
    Write-Host "The Microsoft Visual C++ runtime is missing ($($missing -join ', '))." -ForegroundColor Yellow
    Write-Host 'Install it from Microsoft, then start the game:' -ForegroundColor Yellow
    Write-Host '  https://aka.ms/vs/17/release/vc_redist.x64.exe' -ForegroundColor Yellow
}

# 4. launcher + desktop shortcut
$exe = Join-Path $InstallDir 'openjo_sp.x86_64.exe'
$launchArgs = "+set fs_basepath `"$InstallDir`" +set fs_cdpath `"$data`""
Set-Content -LiteralPath (Join-Path $InstallDir 'Play JK2 Co-op.cmd') -Encoding ASCII -Value @(
    '@echo off',
    "start `"`" `"$exe`" $launchArgs")
if (-not $NoShortcut) {
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'JK2 Co-op.lnk'))
    $lnk.TargetPath = $exe
    $lnk.Arguments = $launchArgs
    $lnk.WorkingDirectory = $InstallDir
    $lnk.IconLocation = "$exe,0"
    $lnk.Description = 'Star Wars Jedi Knight II: Jedi Outcast - co-op'
    $lnk.Save()
    Write-Host 'Desktop shortcut created: JK2 Co-op'
}

Write-Host ''
Write-Host 'Done. Start "JK2 Co-op" from the desktop, then main menu > CO-OP.' -ForegroundColor Green
Write-Host 'The first time you host, Windows asks to allow the game through the firewall - allow it.'

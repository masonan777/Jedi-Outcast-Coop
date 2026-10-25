<#
.SYNOPSIS
    Level crawl bot: loads every campaign level with a real host AND a real joiner,
    tours each level, and reports which levels load and play for both players.

.DESCRIPTION
    Starts a host and a player-2 joiner on this PC (side by side, like split
    screen, no controllers needed). The host's game runs the crawl bot built into
    the gamecode (coop_crawl 1, G_CoopCrawlFrame): for every map it waits for the
    joiner to spawn, moves both players around the level for -Dwell seconds and
    then loads the next map the way a real level exit does. The joiner's game
    logs what it actually got (CG_CoopCrawlFrame).

    Story videos (the opening crawl etc.) are skipped and scripted cutscenes
    fast-forward, only in these test games (their settings live in the crawl
    folder, not in your normal game).

    This script watches both games, restarts a joiner that crashed or dropped
    (and a host that crashed), collects logs and crash dumps, and prints one line
    per map plus a final "RESULT: PASS" or "RESULT: FAIL".

    A map PASSES only when the host logged a PASS for it AND the joiner's own log
    says it was in that map, and the joiner process did not die during it. A map
    that never produced a result is TIMEOUT, not a pass.

    It never touches your game install or saves: each game gets its own fresh
    home folder under <Base>\crawl\<date-time>\, and only processes this script
    started are ever stopped.

.EXAMPLE
    .\jk2coop-levelcrawl.ps1                                   # every campaign map (about 30-40 minutes)
.EXAMPLE
    .\jk2coop-levelcrawl.ps1 -Maps kejim_post,bespin_undercity -Dwell 20
.EXAMPLE
    .\jk2coop-levelcrawl.ps1 -SelfTest                         # check the scorer can fail (no game started)
.EXAMPLE
    .\jk2coop-levelcrawl.ps1 -Maps kejim_post -TwinKillJoiner  # check the whole harness can fail
#>
[CmdletBinding()]
param(
    # campaign maps to crawl, in order (default: the whole campaign)
    [string[]]$Maps = @(
        'kejim_post','kejim_base','artus_mine','artus_detention','artus_topside','valley',
        'yavin_temple','yavin_trial','ns_streets','ns_hideout','ns_starpad','bespin_undercity',
        'bespin_streets','bespin_platform','cairn_bay','cairn_assembly','cairn_reactor',
        'cairn_dock1','doom_comm','doom_detention','doom_shields','yavin_swamp','yavin_canyon',
        'yavin_courtyard','yavin_final','pit'),
    # seconds both players stay in each map after the joiner is in
    [int]$Dwell = 30,
    # seconds to wait for the joiner to load a map and spawn
    [int]$JoinTimeout = 120,
    # folder with openjo_sp.x86_64.exe and jospgamex86_64.dll
    [string]$Build = '',
    # the game folder used as fs_basepath (the jk2coop install)
    [string]$Base = '',
    # UDP port for the test host (kept away from the normal 29070)
    [int]$Port = 29170,
    # turn the game sound down to 0 in both windows
    [switch]$Mute,
    # only test the scorer with made-up logs, start no game
    [switch]$SelfTest,
    # deliberately kill the joiner on the first map: that map MUST come out FAIL
    [switch]$TwinKillJoiner
)

$ErrorActionPreference = 'Stop'

# must match s_coopCrawlDefaultMaps in the gamecode (g_utils.cpp); only a
# different list is passed on the command line (the engine's command line is
# limited to 1024 characters)
$DefaultMapList = 'kejim_post kejim_base artus_mine artus_detention artus_topside valley ' +
    'yavin_temple yavin_trial ns_streets ns_hideout ns_starpad bespin_undercity ' +
    'bespin_streets bespin_platform cairn_bay cairn_assembly cairn_reactor ' +
    'cairn_dock1 doom_comm doom_detention doom_shields yavin_swamp yavin_canyon ' +
    'yavin_courtyard yavin_final pit'

# ---------------------------------------------------------------- scoring ----

function Get-CrawlVerdicts {
    param([string[]]$MapList, [string[]]$HostLines, [string[]]$P2Lines, [object[]]$Events)

    $verdicts = @()
    for ($i = 0; $i -lt $MapList.Count; $i++) {
        $map = $MapList[$i]
        $start = $HostLines | Where-Object { $_ -match "^MAP_START idx=$i map=(\S+)" } | Select-Object -Last 1
        $result = $HostLines | Where-Object { $_ -match "^RESULT map=$([regex]::Escape($map)) " } | Select-Object -Last 1
        $p2In = @($P2Lines | Where-Object { $_ -match "^P2 INGAME map=$([regex]::Escape($map))( |$)" })
        $mapEvents = @($Events | Where-Object { $_.Index -eq $i })
        $verdict = 'TIMEOUT'
        $why = 'no result (not reached or hung)'

        if ($start -and $start -match 'map=(\S+) expected=(\S+)' -and $Matches[1] -ne $Matches[2]) {
            $verdict = 'FAIL'; $why = "wrong map loaded ($($Matches[1]))"
        }
        elseif ($result -and $result -match ' PASS ') {
            if ($p2In.Count -eq 0) {
                $verdict = 'FAIL'; $why = 'host saw a joiner but the joiner never logged being in this map'
            }
            elseif ($mapEvents | Where-Object { $_.Kind -eq 'P2_EXIT' }) {
                $verdict = 'FAIL'; $why = 'joiner process died during this map'
            }
            else {
                $verdict = 'PASS'; $why = ($result -replace '^RESULT map=\S+ PASS ', '')
            }
        }
        elseif ($result) {
            $verdict = 'FAIL'
            $why = ($result -replace '^RESULT map=\S+ FAIL ', '')
            $exit = $mapEvents | Where-Object { $_.Kind -eq 'P2_EXIT' } | Select-Object -First 1
            if ($exit) { $why = "$why; joiner process exited (code $($exit.Detail))" }
        }
        elseif ($mapEvents | Where-Object { $_.Kind -eq 'HOST_EXIT' }) {
            $verdict = 'FAIL'; $why = 'host game crashed or quit on this map'
        }
        elseif ($mapEvents | Where-Object { $_.Kind -eq 'HOST_ERROR' }) {
            $verdict = 'FAIL'; $why = 'host could not load or play this map'
        }
        elseif ($mapEvents | Where-Object { $_.Kind -eq 'HANG' }) {
            $verdict = 'TIMEOUT'; $why = 'no progress before the watchdog fired'
        }
        $errors = @($mapEvents | Where-Object { $_.Kind -eq 'P2_ERROR' } | ForEach-Object { $_.Detail })
        if ($errors.Count) { $why = "$why; joiner console: $($errors -join ' | ')" }
        $herrors = @($mapEvents | Where-Object { $_.Kind -eq 'HOST_ERROR' } | ForEach-Object { $_.Detail })
        if ($herrors.Count) { $why = "$why; host console: $($herrors -join ' | ')" }
        $verdicts += [pscustomobject]@{ Index = $i; Map = $map; Verdict = $verdict; Detail = $why }
    }
    return $verdicts
}

function Invoke-ScorerSelfTest {
    # Feed the real scorer known-good and known-bad logs; every case must come out as expected.
    $maps = @('m_good', 'm_hollow', 'm_p2crash', 'm_missing', 'm_hostcrash', 'm_wrongmap', 'm_noload')
    $hostLines = @(
        'MAP_START idx=0 map=m_good expected=m_good', 'JOINED map=m_good after=900 players=2',
        'RESULT map=m_good PASS reason=ok joined_after=900 tour=6',
        'MAP_START idx=1 map=m_hollow expected=m_hollow', 'JOINED map=m_hollow after=800 players=2',
        'RESULT map=m_hollow PASS reason=ok joined_after=800 tour=6',
        'MAP_START idx=2 map=m_p2crash expected=m_p2crash', 'JOINED map=m_p2crash after=700 players=2',
        'RESULT map=m_p2crash FAIL reason=joiner_lost_at_4000 joined_after=700 tour=1',
        'MAP_START idx=3 map=m_missing expected=m_missing',
        'MAP_START idx=4 map=m_hostcrash expected=m_hostcrash',
        'MAP_START idx=5 map=m_other expected=m_wrongmap', 'RESULT map=m_wrongmap PASS reason=ok joined_after=1 tour=1')
    $p2Lines = @('P2 MAP map=m_good', 'P2 INGAME map=m_good frames=60', 'P2 MAP map=m_hollow',
        'P2 INGAME map=m_p2crash frames=60', 'P2 INGAME map=m_wrongmap frames=60')
    $events = @(
        [pscustomobject]@{ Index = 2; Kind = 'P2_EXIT'; Detail = '-1073741819' },
        [pscustomobject]@{ Index = 4; Kind = 'HOST_EXIT'; Detail = '-1073741819' },
        [pscustomobject]@{ Index = 6; Kind = 'HOST_ERROR'; Detail = "Can't find map maps/m_noload.bsp" })
    $expect = @{ m_good = 'PASS'; m_hollow = 'FAIL'; m_p2crash = 'FAIL'; m_missing = 'TIMEOUT'; m_hostcrash = 'FAIL'; m_wrongmap = 'FAIL'; m_noload = 'FAIL' }

    $ok = $true
    foreach ($v in (Get-CrawlVerdicts -MapList $maps -HostLines $hostLines -P2Lines $p2Lines -Events $events)) {
        $want = $expect[$v.Map]
        $mark = if ($v.Verdict -eq $want) { 'ok  ' } else { $ok = $false; 'BAD ' }
        Write-Host ("{0} {1,-12} expected {2,-7} got {3,-7} {4}" -f $mark, $v.Map, $want, $v.Verdict, $v.Detail)
    }
    if ($ok) { Write-Host 'SELFTEST OK' } else { Write-Host 'SELFTEST FAILED' }
    return $ok
}

if ($SelfTest) {
    if (Invoke-ScorerSelfTest) { exit 0 } else { exit 1 }
}

# "-Maps a,b" run through "powershell -File" arrives as ONE string "a,b"
$Maps = @($Maps | ForEach-Object { $_ -split '[,;\s]+' } | Where-Object { $_ })
if ($Maps.Count -eq 0) { throw 'No maps given.' }

# ------------------------------------------------------------------ setup ----

if (-not $Build) { $Build = Join-Path $PSScriptRoot '..\..\openjk\build' }
if (-not $Base) { $Base = Join-Path $env:LOCALAPPDATA 'OpenJO' }
$Build = (Resolve-Path $Build).Path
$Base = (Resolve-Path $Base).Path
$exe = Join-Path $Build 'openjo_sp.x86_64.exe'
$dll = Join-Path $Build 'jospgamex86_64.dll'
foreach ($f in @($exe, $dll)) { if (-not (Test-Path $f)) { throw "Missing $f (set -Build)" } }

# the scorer must be able to fail before we trust it
if (-not (Invoke-ScorerSelfTest)) { throw 'Scorer self-test failed; not running the crawl.' }

$run = Join-Path $Base ("crawl\" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $run | Out-Null
$hostLog = Join-Path $run 'host_crawl.log'
$p2Log = Join-Path $run 'p2_crawl.log'
$dumpDir = Join-Path $Base 'crashdumps'
$dumpsBefore = @()
if (Test-Path $dumpDir) { $dumpsBefore = @(Get-ChildItem $dumpDir -File | ForEach-Object { $_.FullName }) }

$common = "+set fs_basepath `"$Base`" +set net_enabled 1 +set r_ignorehwgamma 1 +set in_joystick 0 +set logfile 2"
if ($Mute) { $common += ' +set s_volume 0' }

$events = New-Object System.Collections.ArrayList
$script:hostLaunches = 0
$script:p2Launches = 0

function New-Home([string]$name) {
    $h = Join-Path $run $name
    New-Item -ItemType Directory -Force -Path (Join-Path $h 'base') | Out-Null
    Copy-Item $dll (Join-Path $h 'base\jospgamex86_64.dll') -Force
    return $h
}

function Read-Lines([string]$path) {
    if (-not (Test-Path $path)) { return @() }
    $fs = [System.IO.File]::Open($path, 'Open', 'Read', 'ReadWrite')
    try { $text = (New-Object System.IO.StreamReader($fs)).ReadToEnd() } finally { $fs.Close() }
    return @($text -split "`r?`n" | Where-Object { $_ })
}

function Start-CrawlHost([int]$idx) {
    $script:hostLaunches++
    $script:hostHome = New-Home ("host-" + $script:hostLaunches)
    $argLine = "$common +set fs_homepath `"$($script:hostHome)`" +set net_port $Port +set r_splitscreen 1" +
        " +set coop_crawl 1 +set coop_crawl_index $idx" +
        " +set g_skipIntroCinematics 1 +set g_skipVideos 1" +
        " +set coop_crawl_dwell $Dwell +set coop_crawl_jointimeout $JoinTimeout +set coop_crawl_log `"$hostLog`""
    if (($Maps -join ' ') -ne $DefaultMapList) { $argLine += " +set coop_crawl_maps `"$($Maps -join ' ')`"" }
    $argLine += " +map $($Maps[$idx])"
    Write-Host "[crawl] starting host at map $idx ($($Maps[$idx]))"
    return Start-Process -FilePath $exe -ArgumentList $argLine -WorkingDirectory $Build -PassThru
}

function Start-CrawlJoiner {
    $script:p2Launches++
    $script:p2Home = New-Home ("p2-" + $script:p2Launches)
    $argLine = "$common +set fs_homepath `"$($script:p2Home)`" +set r_splitscreen 2 +set coop_crawl_log `"$p2Log`"" +
        " +connect localhost:$Port"
    Write-Host "[crawl] starting player 2 (launch $($script:p2Launches))"
    return Start-Process -FilePath $exe -ArgumentList $argLine -WorkingDirectory $Build -PassThru
}

function Stop-Mine($proc) {
    # only ever a process this script started
    if ($proc -and -not $proc.HasExited) { try { $proc.Kill(); $proc.WaitForExit(5000) | Out-Null } catch { } }
}

function Add-Event([int]$idx, [string]$kind, [string]$detail) {
    [void]$events.Add([pscustomobject]@{ Index = $idx; Kind = $kind; Detail = $detail })
    Write-Host "[crawl] map $idx : $kind $detail"
}

# Real errors (an error drop back to the menu) are printed as a plain line
# "ERROR: ..."; map warnings like "^1ERROR: ref_tag ... invalid target" carry a
# colour code and are harmless. Matching is case-sensitive: the GL extension
# list contains words like "no_error".
$HostErrorPattern = "^(ERROR:|Can't find map)"
$JoinerErrorPattern = "^(ERROR:|Can't find map)|Server disconnected|was kicked|Connection timed out"

function Get-ConsoleErrors([string]$gameHome, [string]$pattern) {
    # error lines from a game's own console log, without the timestamp
    if (-not $gameHome) { return @() }
    $q = Join-Path $gameHome 'base\qconsole.log'
    return @(Read-Lines $q | ForEach-Object { ($_ -replace '^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d ', '').Trim() } |
        Where-Object { $_ -cmatch $pattern } | ForEach-Object {
            if ($_.Length -gt 160) { $_.Substring(0, 160) } else { $_ } })
}

function Add-JoinerConsoleErrors([int]$idx) {
    # what the joiner's own console said went wrong (ERR_DROP texts etc.)
    foreach ($l in (Get-ConsoleErrors $script:p2Home $JoinerErrorPattern | Select-Object -Last 3)) { Add-Event $idx 'P2_ERROR' $l }
}

# ------------------------------------------------------------------- run ----

$cur = 0                       # index of the map the host is on (or loading)
$hostProc = Start-CrawlHost 0
$p2Proc = $null
$lastHostCount = 0
$lastResultCount = 0
$progressAt = Get-Date
$loadStartedAt = Get-Date      # host started or last map finished; MAP_START expected soon
$lastMapStarts = 0
$mapStarts = 0
$p2Gate = 0                    # player 2 (re)starts only when MAP_START count is above this
$hostErrorsSeen = 0
$twinDone = $false
$finished = $false

try {
    while (-not $finished) {
        Start-Sleep -Seconds 1
        $hostLines = Read-Lines $hostLog
        $p2Lines = Read-Lines $p2Log

        if ($hostLines.Count -ne $lastHostCount) {
            $lastHostCount = $hostLines.Count
            $progressAt = Get-Date
        }
        if ($hostLines -match '^DONE ') { $finished = $true; break }
        $mapStarts = @($hostLines | Where-Object { $_ -match '^MAP_START ' }).Count
        if ($mapStarts -ne $lastMapStarts) { $lastMapStarts = $mapStarts; $loadStartedAt = $null }

        # the host's own console: a map that can't be found or an error drop
        # leaves it sitting in the main menu -- note it and move on at once
        $hostErrors = @(Get-ConsoleErrors $script:hostHome $HostErrorPattern)
        if ($hostErrors.Count -gt $hostErrorsSeen) {
            $newErrors = $hostErrors[$hostErrorsSeen..($hostErrors.Count - 1)]
            $hostErrorsSeen = $hostErrors.Count
            foreach ($e in $newErrors) { Add-Event $cur 'HOST_ERROR' $e }
            if ($newErrors) {
                Stop-Mine $p2Proc; $p2Proc = $null; $p2Gate = $mapStarts
                Stop-Mine $hostProc
                if ($cur + 1 -ge $Maps.Count) { break }
                $cur++
                $hostProc = Start-CrawlHost $cur
                $hostErrorsSeen = 0
                $progressAt = Get-Date; $loadStartedAt = Get-Date
                continue
            }
        }

        # a result ends map $cur; from now on the host is loading the next one, so a
        # crash from here on belongs to that map. A FAIL means the joiner dropped
        # or never got in: give it a fresh start.
        $results = @($hostLines | Where-Object { $_ -match '^RESULT ' })
        if ($results.Count -ne $lastResultCount) {
            $new = $results[$lastResultCount..($results.Count - 1)]
            $lastResultCount = $results.Count
            if ($new | Where-Object { $_ -match ' FAIL ' }) {
                Add-JoinerConsoleErrors $cur
                Stop-Mine $p2Proc; $p2Proc = $null
                $p2Gate = $mapStarts    # restart player 2 only once the next map is up
            }
            $cur += @($new).Count
            $loadStartedAt = Get-Date
        }

        # host crashed or quit early: note it, carry on from the next map
        if ($hostProc.HasExited) {
            Add-Event $cur 'HOST_EXIT' $hostProc.ExitCode
            Stop-Mine $p2Proc; $p2Proc = $null; $p2Gate = $mapStarts
            if ($cur + 1 -ge $Maps.Count) { break }
            $cur++
            $hostProc = Start-CrawlHost $cur
            $hostErrorsSeen = 0
            $progressAt = Get-Date; $loadStartedAt = Get-Date
            continue
        }

        # joiner: start it once the host is on a map; restart it after a crash or drop
        if ($p2Proc -and $p2Proc.HasExited) {
            Add-Event $cur 'P2_EXIT' $p2Proc.ExitCode
            Add-JoinerConsoleErrors $cur
            $p2Proc = $null
            Start-Sleep -Seconds 2
        }
        # (only while the host is actually on a map: a joiner started while the
        # host is loading the next one fails to connect and sits in the menu)
        $lastMarker = $hostLines | Where-Object { $_ -match '^(MAP_START|RESULT) ' } | Select-Object -Last 1
        if (-not $p2Proc -and $mapStarts -gt $p2Gate -and $lastMarker -match '^MAP_START ') {
            $p2Proc = Start-CrawlJoiner
        }

        # harness twin: kill the joiner on the first map; the scorer must call it FAIL
        if ($TwinKillJoiner -and -not $twinDone -and ($p2Lines -match "^P2 INGAME map=$([regex]::Escape($Maps[0]))")) {
            Start-Sleep -Seconds 5
            Write-Host '[crawl] TWIN: killing player 2 on purpose'
            Stop-Mine $p2Proc
            $twinDone = $true
        }

        # watchdogs: a map that never starts loading-to-playing, or no news at all
        $loadHung = ($loadStartedAt -and ((Get-Date) - $loadStartedAt).TotalSeconds -gt 180)
        if ($loadHung -or ((Get-Date) - $progressAt).TotalSeconds -gt ($JoinTimeout + $Dwell + 120)) {
            Add-Event $cur 'HANG' $(if ($loadHung) { 'map never finished loading on the host' } else { 'no host progress' })
            Stop-Mine $p2Proc; $p2Proc = $null; $p2Gate = $mapStarts
            Stop-Mine $hostProc
            if ($cur + 1 -ge $Maps.Count) { break }
            $cur++
            $hostProc = Start-CrawlHost $cur
            $hostErrorsSeen = 0
            $progressAt = Get-Date; $loadStartedAt = Get-Date
        }
    }
}
finally {
    Start-Sleep -Seconds 3
    Stop-Mine $p2Proc
    Stop-Mine $hostProc
}

# ----------------------------------------------------------------- report ----

$verdicts = Get-CrawlVerdicts -MapList $Maps -HostLines (Read-Lines $hostLog) -P2Lines (Read-Lines $p2Log) -Events $events.ToArray()
$lines = @()
foreach ($v in $verdicts) { $lines += ("{0,-8} {1,-18} {2}" -f $v.Verdict, $v.Map, $v.Detail) }
$newDumps = @()
if (Test-Path $dumpDir) { $newDumps = @(Get-ChildItem $dumpDir -File | Where-Object { $dumpsBefore -notcontains $_.FullName }) }
if ($newDumps.Count) { $lines += ''; $lines += 'New crash dumps:'; $lines += ($newDumps | ForEach-Object { '  ' + $_.FullName }) }

$passed = @($verdicts | Where-Object { $_.Verdict -eq 'PASS' }).Count
$total = $verdicts.Count
if ($TwinKillJoiner) {
    $twin = $verdicts[0]
    $caught = ($twin.Verdict -ne 'PASS')
    $lines += ''
    $lines += ("TWIN: joiner killed on {0} -> {1} ({2})" -f $twin.Map, $twin.Verdict, $(if ($caught) { 'caught, harness can fail' } else { 'NOT caught, harness is broken' }))
    $final = $(if ($caught) { 'RESULT: PASS (twin caught)' } else { 'RESULT: FAIL (twin not caught)' })
}
elseif ($passed -eq $total -and $newDumps.Count -eq 0) { $final = "RESULT: PASS ($passed/$total maps)" }
else { $final = "RESULT: FAIL ($passed/$total maps passed)" }
$lines += ''
$lines += $final

$lines | Set-Content -Path (Join-Path $run 'summary.txt')
$lines | ForEach-Object { Write-Host $_ }
Write-Host "Logs: $run"
if ($final -like 'RESULT: PASS*') { exit 0 } else { exit 1 }

@echo off
rem jk2coop-splitscreen [map] [swap] - two players on ONE Windows PC, side by
rem side, one Xbox (or any SDL-recognised) controller each.
rem   Host     = left half of the screen,  controller 1
rem   Player 2 = right half of the screen, controller 2   ("swap" flips them)
rem Both windows play sound; set each one's volume in its in-game menu.
rem
rem Paths (override by setting these environment variables first):
rem   JK2COOP_BUILD  folder holding openjo_sp.x86_64.exe + jospgamex86_64.dll
rem                  (default: openjk\build in this repository)
rem   JK2COOP_BASE   the game folder the launchers use as fs_basepath
rem                  (default: %LOCALAPPDATA%\OpenJO)
rem Copy tools\windows\jk2coop_gamepad.cfg into %JK2COOP_BASE%\base first.
setlocal enabledelayedexpansion

set MAP=%1
if "%MAP%"=="" set MAP=kejim_post
set PAD_HOST=0
set PAD_P2=1
if /i "%2"=="swap" ( set PAD_HOST=1& set PAD_P2=0 )
if /i "%1"=="swap" ( set MAP=kejim_post& set PAD_HOST=1& set PAD_P2=0 )

if "%JK2COOP_BUILD%"=="" set JK2COOP_BUILD=%~dp0..\..\openjk\build
if "%JK2COOP_BASE%"=="" set JK2COOP_BASE=%LOCALAPPDATA%\OpenJO
set EXE=%JK2COOP_BUILD%\openjo_sp.x86_64.exe
set BASE=%JK2COOP_BASE%
if not exist "%EXE%" (
	echo Cannot find %EXE%
	echo Set JK2COOP_BUILD to the folder that holds openjo_sp.x86_64.exe.
	exit /b 1
)

set PADARGS=+set in_joystick 1 +set in_gamepad 1 +set in_joystickBackground 1 +exec jk2coop_gamepad.cfg
rem keep the game from brightening the whole monitor (hardware gamma ramp)
set PADARGS=%PADARGS% +set r_ignorehwgamma 1

rem make sure the host runs the freshly built gamecode (the installed
rem base\jospgamex86_64.dll may point at this intermediate copy)
if exist "%JK2COOP_BUILD%\codeJK2\game\" copy /y "%JK2COOP_BUILD%\jospgamex86_64.dll" "%JK2COOP_BUILD%\codeJK2\game\jospgamex86_64.dll" >nul

echo Starting host (left half, controller %PAD_HOST%) on map %MAP% ...
start "JK2 co-op host" "%EXE%" +set fs_basepath "%BASE%" +set net_enabled 1 +set net_port 29070 +set r_splitscreen 1 +set in_joystickNo %PAD_HOST% %PADARGS% +map "%MAP%"

echo.
echo Waiting for the host to finish loading the level.
echo Press any key to start player 2 right away once the host is in the game.
timeout /t 15

rem player 2 runs from its own fresh home folder so the two games don't share
rem config / save files
set CLIENT2DIR=%TEMP%\jk2-client2-%RANDOM%%RANDOM%
mkdir "!CLIENT2DIR!\base" 2>nul
copy /y "%JK2COOP_BUILD%\jospgamex86_64.dll" "!CLIENT2DIR!\base\jospgamex86_64.dll" >nul
rem keep player 2's settings (volume, sensitivity, ...) between runs
set P2PROFILE=%BASE%\p2profile
if exist "%P2PROFILE%\*.cfg" copy /y "%P2PROFILE%\*.cfg" "!CLIENT2DIR!\base\" >nul

echo Starting player 2 (right half, controller %PAD_P2%) ...
start "JK2 co-op player 2" /wait "%EXE%" +set fs_basepath "%BASE%" +set net_enabled 1 +set fs_homepath "!CLIENT2DIR!" +set r_splitscreen 2 +set in_joystickNo %PAD_P2% %PADARGS% +set logfile 2 +connect "localhost:29070"

mkdir "%P2PROFILE%" 2>nul
copy /y "!CLIENT2DIR!\base\*.cfg" "%P2PROFILE%\" >nul 2>nul
rem diagnostics from player 2's game, kept for bug reports
if exist "!CLIENT2DIR!\base\coopanim.log" copy /y "!CLIENT2DIR!\base\coopanim.log" "%P2PROFILE%\coopanim.log" >nul
if exist "!CLIENT2DIR!\base\qconsole.log" copy /y "!CLIENT2DIR!\base\qconsole.log" "%P2PROFILE%\p2_console.log" >nul
rmdir /s /q "!CLIENT2DIR!" 2>nul

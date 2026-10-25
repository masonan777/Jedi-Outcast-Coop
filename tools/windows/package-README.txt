Star Wars Jedi Knight II: Jedi Outcast - co-op campaign (TEST BUILD)
=====================================================================

Based on Benehiko's jedi-outcast-coop (https://github.com/Benehiko/jedi-outcast-coop)
and OpenJK. This fork: https://github.com/masonan777/Jedi-Outcast-Coop

You need your own copy of Jedi Outcast (Steam, GOG or disc). This package
contains only the co-op build; it reads the game's data from your install
and never changes it.


INSTALL
-------
1. Unzip this whole folder anywhere (Desktop is fine).
2. Double-click Install.cmd.
   - It finds Jedi Outcast by itself. If it can't, it asks you to paste the
     game folder (the one that contains GameData).
   - It installs to %LOCALAPPDATA%\JK2Coop and puts "JK2 Co-op" on the desktop.
   - If it says the Visual C++ runtime is missing, install it from
     https://aka.ms/vs/17/release/vc_redist.x64.exe and you're set.
3. Start "JK2 Co-op" from the desktop.

To update, unzip a newer package and run Install.cmd again (your settings
are kept).


PLAYING TOGETHER OVER A NETWORK
-------------------------------
Both PCs must run the SAME package (compare version.txt).

On the host PC:
  Main menu > CO-OP > pick Players and Difficulty > HOST NEW GAME.
  The first time, Windows asks whether to let the game through the
  firewall. Tick "Private networks" and allow it.

On the other PC (same home network):
  Main menu > CO-OP > REFRESH, pick the game in the list > JOIN.
  If the list stays empty, type the host's address in the IP box and press
  JOIN IP. The host finds its address by opening Command Prompt, typing
  ipconfig and reading "IPv4 Address" (it looks like 192.168.1.23).

Over the internet (different houses):
  The host forwards UDP port 29070 on the router to the host PC, and the
  joiner types the host's public IP address in the IP box. A virtual LAN
  tool such as Tailscale or ZeroTier also works, without touching the
  router: use the address it shows for the host PC.

Each player uses their own keyboard and mouse or controller.

Split screen on one PC still works: main menu > CO-OP > START SPLIT SCREEN
(with two controllers plugged in), or in a running game: ESC > CO-OP >
ADD PLAYER 2.


IF SOMETHING GOES WRONG
-----------------------
Note the map, what happened, and send version.txt with a screenshot.
The game's console opens with the ~ key (left of 1); its last lines usually
say what went wrong.


UNINSTALL
---------
Delete %LOCALAPPDATA%\JK2Coop and the "JK2 Co-op" desktop shortcut.
Your Jedi Outcast install was never changed.

# Jedi Outcast Rebuild

A build of Jedi Outcast singleplayer with **cooperative campaign play**
— up to four players in one campaign game — for **Linux and Windows**.

> **About this fork.** This repository is a fork of
> [**Benehiko/jedi-outcast-coop**](https://github.com/Benehiko/jedi-outcast-coop),
> created by **Alano Terblanche ([@Benehiko](https://github.com/Benehiko))**.
> The co-op engine, the dual-load remote-client design, patches
> `0001`–`0031`, the `jk2coop` tool, the installers and the documentation
> below are his work; the full original commit history is preserved here.
> This fork adds patch `0032` (campaign gameplay fixes for joiners, Force
> powers and lightsaber for player 2, a revive system, in-game CO-OP menus
> with one-click split screen, controller support, and an automated level
> crawl test) plus a Windows test package/installer under `tools/windows/`
> — see [docs/fork-changes.md](docs/fork-changes.md) for what changed and
> the [credits](#credits).



## Approach

The engine is not reverse engineered. Raven Software released the Jedi
Outcast source under the GPLv2 in 2013;
[OpenJK](https://github.com/JACoders/OpenJK) maintains it. Only the
retail assets are proprietary, and they are used in place, unmodified.
Changes to OpenJK live in `patches/` and are applied to a pinned
submodule by `tools/apply-patches.sh`, rather than carrying a fork.

## License

The engine is [OpenJK](https://github.com/JACoders/OpenJK), GPLv2. This
project's changes to it (`patches/`) are derivative works and are
therefore also **GPLv2**, as are the built binaries; the full license
text is in [LICENSE](LICENSE). The original authorship in this
repository — patches, tools, docs, and the Co-op UI overlay — is offered
under the same terms.

This project ships **no game data**. The retail `assets*.pk3` files are
proprietary and are used in place from your own legal copy of the game;
see [Installing](#installing).

### Trademarks

*Star Wars*, *Jedi Knight*, *Jedi Outcast*, and related names and marks
are trademarks of their respective owners (Lucasfilm / Disney, and the
game's publishers). This is an unofficial, non-commercial, fan-made
project, not affiliated with, endorsed by, or sponsored by any of those
rights holders. The GPL covers the source code only — it grants no
rights in these trademarks or in the proprietary game assets.

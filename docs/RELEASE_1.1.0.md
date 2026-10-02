# Extinction 1.1.0 — Natural Extinction & Animal Hunting

## Two ways for the dead to disappear

- **Fixed timeline:** the original configurable death schedule, enabled by default.
- **Natural extinction:** opt in when creating a new world. Zombies lose a single
  biological reserve, can replenish it through rain and existing corpses, and
  eventually die when resources and resilience run out. There is no fixed final day.
- **Animal hunting:** a separate new-world checkbox, available in either mode.
  Zombies pursue and bite living animals; native animal death creates the corpse.
- Zombies never hunt or attack living zombies for food.

## Bodies, skeletons, and diagnostics

- Human, zombie, and animal corpses can provide finite resources in natural mode.
- Assigned feeding resumes after temporary interruptions while food remains.
- Exhausted bodies become the appropriate native skeletons rather than disappearing.
- Age-based skeletonization retains its configurable delay, defaulting to 180 days.
- New-world skeletonization preserves hard items and contents of discarded soft bags.
- Separate optional overlays show zombie reserve and corpse nutrition, including
  the estimated time until age-based skeletonization.
- Biological reserve is capped at 21 baseline days, including after feeding or rain.

## Existing saves

- **No new game is needed to continue an existing fixed-timeline Extinction save.**
- Such worlds keep original death dates, mode, configured timing, and original loot
  handling. New default checkboxes do not turn on natural extinction or hunting.
- **A new world is required to select natural extinction or the new hunting option.**
- World choices persist across reloads and are not replaced by new sandbox defaults.
- Existing natural-mode development saves are recognized through non-empty natural
  sector records and retain their already-selected mode; empty records do not qualify.
- Vanilla population, respawn, apocalypse age, and corpse-sickness choices stay untouched.
- Retain the same mod ID: `Extinction`. Do not activate local and Workshop copies together.
- Back up important saves before updating.

## Compatibility and validation

Target: Project Zomboid Build 42.20+, locally checked against Build 42.21.0.
Project A-Life marker protections remain in place; other NPC mods are not certified.

The author confirmed the latest animal pursuit and attack behaviour in a real
single-player game. The update additionally has actual-code regression tests
in the game's Kahlua interpreter using simulated world data and game objects:

- old fixed-timeline dates and modes;
- persisted new-world choices and reload behaviour;
- hunting without natural extinction and natural extinction without hunting;
- late-start historical deaths and untouched vanilla sandbox options;
- Project A-Life exclusions;
- damage only at animation contact, no timer-only phantom bite;
- pursuit routing, obstacle blocking, and cleanup on interruption.

Native animation-graph checks cover the bite node in seven animation states.
These checks are not rendered gameplay tests. Exhaustive species testing,
multiplayer, long-term migration of real saves, and dense-city profiling remain
unperformed. Release status does not imply those tests passed.

## Links

- [Mechanics and research](UPDATE_1.1_NATURAL_STARVATION.md)
- [Steam description](STEAM_DESCRIPTION.txt)
- [Source code](https://github.com/Wrathtide/ProjectZomboid-Extinction)
- [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3809176497)

MIT license. Human concept, design, direction, and testing; code built with AI
under human direction. Extinction is an independent, unofficial fan project.

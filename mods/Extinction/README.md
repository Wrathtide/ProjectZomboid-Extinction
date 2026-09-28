# Extinction

**Extinction** is a mod for **Project Zomboid Build 42.20+** that simulates the gradual and permanent extinction of the ordinary zombie population. Every ordinary zombie receives an individual death time, and the world progressively changes from an active outbreak into a mostly empty landscape of corpses and skeletons.

The mod is intended for a **new world** and is compatible with **Project A-Life [ALIFE NPCS]**.

## Update 1.1 beta — Natural Extinction

The local 1.1 beta adds an optional natural survival model alongside the stable
fixed deadline. Each active zombie stores one biological reserve, and each
corpse used as food stores one shared resource value. Rain, temperature,
activity, corpse feeding, and systemic failure affect survival. Human, zombie,
and animal corpses are eligible; living animal hunting is separately
configurable. Zombies never attack living zombies for food.

Two disabled-by-default testing checkboxes allow an eligible tester to make
zombies ignore the player and to display a compact biological-state label over
nearby zombies.

## Inspiration

The atmosphere and premise were inspired by two post-apocalyptic novels:

- Stephen King's **The Stand** (published in Polish as **Bastion**),
- Robert J. Szmidt's **Samotność Anioła Zagłady** (later republished as **Samotność Anioła Zagłady. Adam**).

Extinction is an independent fan-made project. It is not an adaptation, contains no text, characters, artwork, or other assets from either novel, and is not affiliated with or endorsed by the authors, their publishers, The Indie Stone, or Valve.

## Main features

- Gradual extinction of all ordinary zombies.
- Configurable extinction deadline, defaulting to **21 days after the apocalypse**.
- One immutable random death time per zombie.
- Correct handling of worlds that begin months after the apocalypse.
- Historically dated corpses in areas first explored long after the outbreak.
- Silent conversion into corpses without combat, kill credit, or experience.
- Configurable skeletonization, defaulting to **180 days after each individual death**.
- Native lightweight Project Zomboid skeletons replace old detailed bodies.
- Project A-Life characters are explicitly protected.
- Ordinary zombies created by vanilla or other mods remain subject to extinction.
- Full compatibility with standard Project Zomboid sandbox population and corpse settings.
- English and Polish in-game sandbox-option text.

## Extinction schedule

Every ordinary zombie receives one random death age measured from the beginning of the apocalypse. The value is uniformly distributed between apocalypse day 0 and the configured extinction deadline.

With the default value of **21 days**:

- some zombies die during the first days,
- some survive for one or two weeks,
- the final ordinary zombies die no later than the end of day 21,
- no ordinary zombie can remain alive after the deadline.

The assigned time is stored in the zombie's mod data and never changes because of the player's position or visibility. If the deadline happens to occur while the zombie is visible, the player may see the instantaneous conversion into a corpse. Visibility never causes, delays, or rerolls the death.

## Starting months after the apocalypse

Extinction uses the standard `TimeSinceApo` sandbox option. Build 42 represents elapsed apocalypse time in months, with each month contributing 30 days. Internally, the mod uses:

```text
apocalypse age = current world age + (TimeSinceApo - 1) × 30 days
```

This means the extinction deadline is always relative to the apocalypse, not to the moment the player enters the world.

Example:

- the player selects **Six Months Later**,
- the extinction deadline is set to **30 days**,
- the world begins approximately 180 days after the apocalypse,
- every ordinary zombie is already past its assigned deadline,
- all ordinary zombies loaded at world start or generated later are immediately converted into historically dated remains.

The corpse's engine-level death time is shifted into the past so decomposition and the custom skeletonization delay reflect the historical death date rather than the discovery date.

## Newly explored areas

Project Zomboid creates part of its population only when new areas are loaded. Extinction handles this without producing implausibly fresh bodies late in the game:

1. The vanilla game creates a zombie according to its normal population rules.
2. Extinction assigns that zombie a death age from the original outbreak period.
3. If the assigned time is still in the future, the zombie remains alive until that time.
4. If the assigned time has already passed, the zombie immediately becomes a corpse.
5. The corpse receives the historical death date, not the time at which the player discovered the area.
6. If the skeletonization delay has also elapsed, the corpse can become a skeleton during the next corpse-processing pass.

## Silent death

Extinction does not kill zombies through an attack or the normal combat-damage path. It calls the engine's native corpse-creation method directly. As a result:

- no combat sound is produced,
- no player attack or damage is involved,
- the player receives no kill credit or experience,
- no killer is assigned,
- no dramatic falling animation is required,
- the corpse occupies the zombie's location.

## Skeletonization

Ordinary zombie corpses are tracked until they reach the configured age. The default delay is **180 days after the individual death date**.

When the delay has elapsed:

- the detailed corpse is replaced by a native Project Zomboid skeleton,
- clothing, inventory, and identifying visual details are discarded,
- the position and historical death age are retained,
- the resulting skeleton is no longer actively processed by the mod.

This is a deliberate performance compromise. Hundreds of detailed bodies can be expensive, while native skeletons preserve the visual history of the disaster at a lower runtime cost.

Setting the skeletonization delay to **0** disables automatic skeletonization.

## Full standard-sandbox compatibility

Extinction does **not** overwrite or replace any standard Project Zomboid sandbox setting. It does not write to population, peak population, distribution, respawn, corpse removal, corpse sickness, start date, or months-since-apocalypse options.

In particular:

- Zombie count and distribution are controlled exclusively by vanilla population settings.
- Extinction never spawns additional ordinary zombies to reach its own target.
- Population peak and population evolution remain controlled by the game.
- If vanilla respawn is enabled, the game may continue to create replacement zombies; after the extinction deadline, each such zombie is immediately converted into historically dated remains.
- If corpse removal is enabled, the game may remove bodies and skeletons according to the selected standard setting.
- If corpse removal is disabled by the player, remains persist.
- Corpse sickness uses exactly the standard value selected by the player.
- Start month, start day, start year, and `TimeSinceApo` remain untouched.

The mod adds only two independent settings of its own: the extinction deadline and the skeletonization delay. Neither setting substitutes for a vanilla population option.

## Project A-Life compatibility

Project A-Life uses zombie-class objects as technical shells for human NPCs. Extinction detects those shells using the official markers:

- `ProjectALifeOwned`,
- `ProjectALifeActor`,
- `ALifeActor`,
- `ALifeUID`.

Any object carrying one of these markers is excluded completely:

- it receives no extinction time,
- it is never converted into an ambient corpse,
- its corpse is not skeletonized by Extinction,
- the NPC remains under Project A-Life's control.

Unmarked ordinary zombies—whether created by vanilla, Project A-Life, or another mod—follow the normal extinction schedule. Project A-Life is optional; Extinction also works by itself.

## Recommended NPC companions

Extinction deliberately turns the late game into a quiet, sparsely populated world. It works best alongside an NPC mod so that human stories, encounters, and danger remain after the zombie population has died out.

Compatibility has been specifically implemented and checked for **Project A-Life [ALIFE NPCS]**. Other NPC mods may also work, but they have not been verified and must not expose their human characters as unmarked ordinary zombies.

## Custom sandbox options

Enabling the mod adds an **Extinction** page to the sandbox settings.

### Days until complete zombie extinction

- Default: `21`
- Minimum: `0`
- Maximum: `3650`
- `0` means immediate extinction.

The entire probability distribution scales automatically to the selected value.

### Days from death to skeletonization

- Default: `180`
- Minimum: `0`
- Maximum: `3650`
- `0` disables automatic skeletonization.

This delay is calculated separately from each corpse's real or historical death date.

## Installation

Place the `Extinction` folder in:

```text
C:\Users\<username>\Zomboid\mods\Extinction
```

Enable **Extinction** when creating a new world. When using Project A-Life, enable both mods for the same save.

## Version and validation

- Target game version: **Project Zomboid Build 42.20+**.
- Mod version: **1.1.0-beta.2**.
- Lua syntax is checked with the Kahlua parser shipped with the local game installation.
- Events and Java methods are verified directly against the local `projectzomboid.jar`.
- Sandbox-option and translation files are validated statically.
- Project A-Life marker compatibility was checked against Project A-Life 1.3.0 for Build 42.20.

Runtime testing in a real world remains a separate validation stage. A new save is recommended because an existing world may already contain population and corpses generated under different rules.

## Project structure

```text
mods/Extinction/42.20/
├── mod.info
└── media/
    ├── sandbox-options.txt
    └── lua/
        ├── client/Extinction/ExtinctionSandboxUI.lua
        ├── client/Extinction/ExtinctionTestTools.lua
        ├── server/Extinction/ExtinctionServer.lua
        ├── server/Extinction/ExtinctionNaturalStarvation.lua
        └── shared/Translate/
            ├── EN/Sandbox.json
            └── PL/Sandbox.json
```

## Authorship and AI disclosure

The project's original idea, gameplay design, requirements, direction, and final creative decisions were provided by a human who is not a programmer. The code was built with AI under human direction, specification, testing requirements, and final approval.

## Repository

[GitHub — Wrathtide/ProjectZomboid-Extinction](https://github.com/Wrathtide/ProjectZomboid-Extinction)

The repository contains no credentials, Steam session data, save files, or personal data.

## License

The Extinction source code and its accompanying project documentation are released under the [MIT License](LICENSE).

The MIT License applies only to original material contained in this repository. It does not grant rights to Project Zomboid, Steam, Project A-Life, the referenced novels, their titles or characters, third-party mods, trademarks, or any other third-party intellectual property. Extinction is an unofficial, independent, non-commercial fan project and is not endorsed by The Indie Stone, Valve, the referenced authors, or their publishers.

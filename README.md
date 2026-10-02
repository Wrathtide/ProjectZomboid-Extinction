# Extinction

> **Update 1.1 — Natural Extinction & Animal Hunting**
>
> Choose a fixed extinction deadline or optional natural extinction when creating a new world. Animal hunting is a separate option in either mode. Existing fixed-timeline saves retain their original rules and death dates.
>
> **[Update 1.1 mechanics and research →](docs/UPDATE_1.1_NATURAL_STARVATION.md)** · **[Release notes →](docs/RELEASE_1.1.0.md)**

**Extinction** is a mod for **Project Zomboid Build 42.20+** that simulates the gradual decline of the ordinary zombie population. In fixed mode, each receives an individual death time; in natural mode, survival depends on a finite biological reserve and available resources. The world progressively changes from an active outbreak into a mostly empty landscape of corpses and skeletons.

The mod is compatible with **Project A-Life [ALIFE NPCS]**. A **new world is required to start natural extinction**, not to continue an existing fixed-timeline Extinction save after updating.

## Updating an existing save

- Keep the same mod ID, `Extinction`. Do not install a second copy alongside it.
- Existing fixed-timeline worlds stay in fixed mode. Their stored death dates, configured deadline, skeletonization delay, and original skeleton-loot behaviour are preserved.
- New default options do not silently activate starvation or animal hunting in those worlds.
- Choose natural extinction and animal hunting when creating a new world. The two choices are saved with the world and cannot switch its simulation merely because sandbox defaults change later.
- Development saves that already used natural extinction keep it when persistent sector records prove the mode was used. An empty sector table does not trigger this migration.
- Back up important saves before any mod update. Compatibility tests exercise the actual Lua code with simulated game objects; they are not a guarantee against unrelated game or mod problems.

## Inspiration

The atmosphere and premise were inspired by two post-apocalyptic novels:

- Stephen King's **The Stand** (published in Polish as **Bastion**),
- Robert J. Szmidt's **Samotność Anioła Zagłady** (later republished as **Samotność Anioła Zagłady. Adam**).

Extinction is an independent fan-made project. It is not an adaptation, contains no text, characters, artwork, or other assets from either novel, and is not affiliated with or endorsed by the authors, their publishers, The Indie Stone, or Valve.

## Main features

- Gradual extinction of ordinary zombies, with a guaranteed deadline in fixed mode and resource-dependent survival in natural mode.
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
- Optional natural-extinction mode with one persistent biological reserve per zombie.
- A 21-day hard cap on the composite biological reserve, including after feeding or rain; this is a simplified gameplay model, not a medical prediction.
- Rain and temperature affect survival without adding separate hydration fields.
- Persistent native corpse-eating behaviour for human, zombie, and animal remains: an assigned corpse is resumed after the native eating timer or a temporary interruption until its resource is exhausted.
- Optional pursuit and attack of living animals through the game's native detection and targeting path.
- Consumed bodies preserve hard loot while selected clothing and soft bags are removed.
- Separate opt-in overlays for zombie biological state and corpse nutrition.

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
- selected clothing and soft containers are discarded,
- nested and hard items are transferred to the skeleton or dropped on the same square,
- the position and historical death age are retained,
- the resulting human skeleton leaves the active body-processing list.

This is a deliberate performance compromise. Hundreds of detailed bodies can be expensive, while native skeletons preserve the visual history of the disaster at a lower runtime cost.

Setting the skeletonization delay to **0** disables age-based skeletonization. In natural mode, exhausting a corpse's nutritional resource still turns it into remains. Animal bodies use the engine's animal-skeleton path; human and zombie bodies use its human-skeleton path.

The new loot-preservation rules apply to new 1.1 worlds and existing natural-mode development worlds. Older fixed-timeline saves retain the original skeletonization behaviour, including its original loot handling. Human skeletons leave the ordinary processing list; animal skeletons receive a lightweight preservation pass to prevent later animal rot stages from deleting them. Standard corpse-removal settings otherwise remain the player's choice.

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

The mod adds its own natural-mode, fixed-deadline, skeletonization, animal-hunting, and testing controls. None substitutes for a vanilla population option. Enabling Natural Extinction disables the fixed deadline without changing any standard population setting.

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

### Natural extinction

- Default: `Off`
- Selected for a **new world**, then persisted as that world's mode.
- When disabled, Extinction uses the stable fixed extinction deadline.
- When enabled, the fixed deadline field is locked and ignored.
- Every zombie stores one composite biological reserve.
- The initial reserve follows a survival curve dominated by 3–7 days, with only a 0.5% tail reaching 18–21 days.
- The reserve can never exceed 21 days, including after corpse feeding or rain.
- Rain, temperature, activity, corpse feeding, and reserve-dependent systemic failure affect survival.
- Hungry zombies may use existing, non-skeletal human, zombie, or animal corpses.
- Once feeding begins, the assigned corpse is remembered and feeding resumes after the native eating timer or a temporary interruption until no resource remains.
- A fully consumed human, zombie, or animal corpse is converted through the matching native skeleton path. Extinction also prevents Build 42's later animal-rot stage from deleting native animal skeletons.
- Zombies never attack living zombies to obtain food.
- Resources removed from a corpse are shared and cannot be consumed twice.
- Digestion, metabolism, and decomposition permanently remove resources from the system.
- Late-created zombies are aged from the beginning of the apocalypse.
- Exact off-screen routes are approximated through persistent 50×50-tile sector timing.

### Zombies hunt living animals

- Default: `On`
- Independent of Natural Extinction: available in both modes for new worlds.
- Any ordinary zombie may proactively target a nearby living animal, just as it targets a living human. Biological reserve controls whether the zombie feeds from the resulting corpse; it no longer prevents the attack itself. If Build 42 has already made a zombie pursue an animal, Extinction adopts that native target and completes the otherwise missing attack.
- The zombie enters the game's native `spotted(...)` detection path for targeting and pursuit. A dedicated animation node plays the game's `Zombie_Bite_Success` clip, with damage applied once when that clip reports its contact event. This bypasses the player-only collision event that rejects `IsoAnimal`, without accessing Lua-inaccessible Java fields or writing the read-only `bAttack` callback. A missing animation event does not silently inflict damage. A lethal bite sets health to exactly zero and leaves native animal death and corpse creation to the engine. Bite reach scales with the animal's native corpse-size value.
- The bite node is available in the native idle, alerted-turn, walk, pathfinding, lunge, thump, and attack animation states. It does not require action-group XML overrides, which the Build 42.21 Windows loader bypasses through absolute installation paths. The animation has no root movement, and normal nodes are selected again when the bite flag is cleared.
- Pursuit preserves an existing route to the animal rather than cancelling and restarting it every tick. Retry checks are limited to once per second and do not interrupt native door-thumping or climbing actions. The latest indoor pursuit and attack behaviour was accepted by the author after testing in the game.
- The mod writes a bounded set of `[Extinction] Animal attack ...` diagnostic trace lines to `console.txt`.
- Every animal species and multiplayer have not received exhaustive runtime validation.

### Testing overlays

- **Show zombie biological state** displays reserve, approximate baseline survival time, and current state over nearby zombies.
- **Show corpse nutrition** displays the remaining raw and usable nutritional value plus the time left until skeletonization over nearby human, zombie, and animal corpses.
- Both options default to `Off`.

### Days until complete zombie extinction

- Default: `21`
- Minimum: `0`
- Maximum: `3650`
- `0` means immediate extinction.
- Ignored and locked when natural calorie distribution is enabled.

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
- Mod version: **1.1.0**.
- Lua syntax is checked with the Kahlua parser shipped with the local game installation.
- Events and Java methods are verified directly against the local `projectzomboid.jar`.
- Sandbox-option and translation files are validated statically.
- Project A-Life marker compatibility was checked against Project A-Life 1.3.0 for Build 42.20.

The author confirmed the latest animal-hunting behaviour in a real single-player game. Regression tests also run the actual Lua modules in the game's Kahlua interpreter with simulated world data and game objects. They cover saved mode selection, old death dates, late-start worlds, A-Life protection, independent hunting, animation-contact damage, and interrupted pursuit. Native animation-graph checks remain distinct from visual tests. Full multiplayer, every animal species, long-running real-save migration, and dense-city performance are not certified.

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

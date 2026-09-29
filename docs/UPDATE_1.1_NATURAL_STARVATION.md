# Extinction 1.1 Project — Natural Extinction

> Status: design approved; implementation beta is in progress on
> `feature/natural-starvation-1.1`. Static API and Lua syntax checks pass.
> Runtime validation in Project Zomboid is still required before release.
>
> This document supersedes the earlier multi-parameter Natural Starvation
> proposal. The released fixed-timeline mode remains unchanged until every
> mandatory validation gate has passed.

## Vision

Natural Extinction is an optional alternative to the fixed extinction deadline.
It treats the zombie population as a decaying biological system.

Every active zombie stores one composite biological reserve. The reserve falls
with time, activity, temperature stress, dehydration, and systemic failure. It
may be replenished by liquid rain and by feeding on corpses that already exist.

The mode deliberately permits rare, unusually resilient zombies. It does not
promise that the world becomes mathematically empty on a predetermined day.
The late game should become mostly silent while preserving uncertainty.

Non-negotiable rules:

- zombies never attack, injure, or hunt living zombies for food;
- zombies may feed only from an existing `IsoDeadBody`;
- human, zombie, and animal corpses may provide resources;
- living animals may be hunted only when the separate option is enabled;
- rotten flesh loses resources but is not toxic to zombies;
- living NPCs, including Project A-Life characters, are never processed as
  zombies or prey by Extinction.

## Sandbox settings

| Setting | Type | Default | Behaviour |
|---|---:|---:|---|
| Natural Extinction | Checkbox | Off | Enables the biological-reserve simulation. |
| Days Until Complete Zombie Extinction | Integer | 21 | Used only in fixed mode. Locked and ignored in natural mode. |
| Days From Death to Skeletonization | Integer | 180 | Remains available in both modes. |
| Zombies Hunt Living Animals | Checkbox | On | Allows hungry zombies to select living animals as prey in natural mode. |
| Testing: Show Zombie Biological State | Checkbox | Off | Draws a compact state label over nearby active zombies. |
| Testing: Show Corpse Nutrition | Checkbox | Off | Draws the remaining raw and usable nutritional value over nearby corpses. |

Natural Extinction remains disabled by default. The fixed extinction schedule
continues to be the predictable standard mode.

## One persistent parameter per active zombie

An active zombie stores only:

- `ExtinctionBiologicalReserve`

The value combines the effects of:

- stored energy;
- hydration;
- individual metabolic demand;
- age and pre-infection health;
- organ resilience;
- current environmental stress;
- reserve-dependent systemic failure.

It is a gameplay abstraction measured in baseline survival-day equivalents,
not a literal calorie or water counter.

Search cooldowns, synchronization thresholds, and current batch state exist
only in transient weak-reference tables. They are not written into every
zombie's persistent mod data.

### Initial population curve

When a zombie first enters the simulation, Extinction draws a continuous
reserve from a precomputed population curve and stores only the result.

The curve is informed by:

- the United States age structure around 1990;
- NHANES population health and body-mass data;
- variation in resting metabolic demand;
- the short-term importance of hydration;
- a small long tail of unusually resilient individuals.

The implemented beta curve is continuous inside these population bands:

| Population share | Baseline reserve before environmental support |
|---:|---:|
| 10% | 1–3 days |
| 55% | 3–7 days |
| 30% | 7–12 days |
| 4.5% | 12–18 days |
| 0.5% | 18–21 days |

The 21-day ceiling follows a forensic review that places exceptional survival
without both food and fluid at approximately 8–21 days. Other reviews describe
death without water as generally occurring within about a week, while food-only
deprivation can last for weeks. The ceiling is therefore deliberately an
extreme outlier rather than a typical outcome:

- https://pubmed.ncbi.nlm.nih.gov/20069776/
- https://pmc.ncbi.nlm.nih.gov/articles/PMC2849909/

Feeding, food moisture, and liquid rain may replenish the reserve but can never
raise it above 21 days. Once full, further intake provides no additional
reserve. Existing saved values above the ceiling are clamped when processed.

### Active update

The server processes active zombies in sector batches instead of running a
biological function every frame.

Each update:

1. subtracts baseline reserve expenditure for elapsed game time;
2. applies activity and temperature multipliers;
3. adds liquid-rain support when the zombie is outdoors;
4. adds assimilated corpse resources while it is eating;
5. applies a small reserve-dependent systemic-failure risk;
6. clamps the reserve to its supported range;
7. converts a failed zombie directly to a corpse through Extinction's silent
   death pipeline.

The combined system represents starvation, dehydration, high metabolism,
pre-existing disease, organ damage, infection-related failure, temperature
exposure, exhaustion, and collapse in critically weakened individuals.

## Rain and hydration

The regional reference is Louisville and north-central Kentucky.
NOAA 1991–2020 normals report approximately:

- 48.34 inches / 1,228 mm of precipitation per year;
- 124.5 days per year with at least 0.01 inch;
- 3.36 mm per calendar day averaged across the year;
- 9.86 mm on a qualifying precipitation day.

The active simulation uses the game's real current weather. It reads rain
intensity, snow state, local temperature, and whether the square is outdoors.

The simplification assumes an effective water-access area of 0.20 square
metres:

- annual-average incident water: about 0.67 litres per day;
- typical wet day: about 1.97 litres;
- maximum usable water: 3.0 litres per day.

The model represents drinking from wet skin, clothing, puddles, surfaces, and
remains. Snow grants no immediate hydration because version 1.1 does not
simulate melting.

Historical unloaded time uses a conservative regional average support of 0.20
reserve-day per apocalypse day. Active areas use actual game rain.

### Water retained by corpses

A human corpse may be treated as approximately 0.60 square metres of exposed
collection area. A typical wet day provides about 5.9 litres of incident water.
The model retains only a small accessible part:

- approximately 10% of incident water;
- a maximum of 1.0 litre-equivalent for a human corpse;
- a size-scaled capacity for animals.

This is an explicit gameplay assumption, not a forensic measurement. Rain
changes the corpse's single resource value and does not create a second water
field.

## One persistent parameter per used corpse

A corpse is indexed when it enters an active chunk, but it receives no
biological field until a zombie inspects or uses it.

The only persistent natural-mode field on a used corpse is:

- `ExtinctionCorpseResource`

It combines accessible tissue, recoverable fluids, decomposition loss, and the
small rain contribution. The native corpse death time supplies age, so no
duplicate custom timestamp is stored.

A skeleton always has zero resource.

### Human and zombie corpses

The published estimate of approximately 32,000 kcal of potentially edible
human skeletal muscle is used as an upper reference. One average fresh human
corpse begins near 12.8 raw reserve-day equivalents before assimilation.

The value varies with body size and falls with corpse age and temperature.
Assimilation is intentionally lossy. A zombie dying after biological depletion
produces only a fraction of a fresh corpse's resource, preventing infinite
recycling.

### Animal corpses

Animal corpses are eligible. The game exposes animal type, breed, body size,
animal-corpse state, and animal-skeleton state.

Version 1.1 uses conservative species and size mappings:

- mice and rats provide a negligible resource;
- poultry provides less than two baseline days;
- sheep, pigs, and deer provide intermediate resources;
- cattle provide the largest resource pool;
- unknown modded animals receive a bounded size-based fallback.

The values remain balance parameters and must be checked against every vanilla
animal species.

## Corpse feeding

Extinction reuses the game's native zombie corpse-eating behaviour for:

- walking and pathfinding;
- kneeling and eating animation;
- sounds and visual effects;
- interruption by a higher-priority target;
- the native simultaneous-eater limit.

Extinction extends selection and performs server-authoritative resource
accounting. Because the native eating state has a randomized internal timer and
may end before a corpse is exhausted, Extinction remembers the corpse assigned
to each feeding zombie. When the timer expires or feeding is temporarily
interrupted, the zombie returns to that corpse and resumes eating if no
higher-priority target is present. This continues until the corpse resource
reaches zero.

A hungry zombie may select a corpse only if:

- it has no higher-priority target;
- the object is an existing `IsoDeadBody`;
- it is not a skeleton;
- resource remains;
- it is on the same level and inside the search radius;
- the native eating state can accept it.

Shared corpse resources are debited exactly once. Only 70% of consumed resource
is added to zombie reserves. Digestion, feeding loss, decomposition, and
metabolic expenditure permanently remove matter from the closed system.
Feeding continues even when the zombie has reached the 21-day reserve cap; the
corpse is still depleted, but surplus energy is discarded and cannot extend the
reserve beyond that cap.

## Living animal hunting

The setting `Zombies Hunt Living Animals` is separate and only affects living
animals.

The current Build 42 API supports the required path:

- `IsoAnimal` derives from the player-character hierarchy used by zombie
  targeting;
- zombies expose target and path-to-character methods;
- animals expose health, hit consequences, death, and native flee behaviour;
- the active cell exposes its animal list;
- a dead animal becomes an `IsoDeadBody`.

The beta implementation:

1. searches the game's active animal list only when a hungry zombie found no
   usable corpse;
2. keeps the animal search bounded;
3. passes the animal through the same native `spotted(...)` detection path used
   for living character targets, establishing the target, pursuit, and ordinary
   close-range attack behaviour;
4. triggers the animal's native flee response;
5. relies on the inherited native attack path because `IsoAnimal` is an
   `IsoPlayer` subclass;
6. leaves the normal animal corpse for the corpse-resource model.

Runtime testing must still confirm attack damage, animation alignment, fleeing,
multiplayer authority, and corpse creation for every supported animal size.
The mod does not synthesize unverified damage while these tests are pending.

## Consumed remains and loot

When a human or zombie corpse reaches zero resource, it may be converted to a
native lightweight skeleton before the ordinary age deadline.

During conversion:

- clothing and soft containers are treated as consumed or destroyed;
- nested contents are removed from a soft container before that container is
  destroyed;
- weapons, tools, keys, ammunition, jewellery, and unknown modded items are
  preserved;
- preserved items are transferred to the skeleton container;
- an item that cannot be transferred is dropped on the same square.

Unknown item categories are preserved by default.

Animal corpses use a native animal skeleton only where the game supports it.
Otherwise the zero-resource animal corpse remains available to the game's
ordinary rot/removal systems rather than being replaced by an incorrect human
skeleton.

## Loaded and unloaded simulation

Project Zomboid virtualizes distant zombies through
`ZombiePopulationManager`. Pure Lua cannot maintain a full object-level route
and feeding history for every absent zombie.

The implementation therefore uses two layers:

| World state | Simulation |
|---|---|
| Loaded near players | Individual zombie reserve and lazy corpse resource |
| Unloaded or virtualized | Persistent aggregate sector timing and reserve statistics |

Each 50×50-tile sector stores:

- the last simulated apocalypse hour;
- the last observed active population;
- the last observed mean biological reserve;
- the model version.

When a sector becomes active again, every persistent zombie in that sector is
advanced by the same missing time. Newly materialized zombies are instead
initialized from the full apocalypse age, so elapsed time is never charged
twice.

This is a deterministic population approximation. It does not pretend that an
absent zombie followed an exact route or ate one particular corpse while the
engine had no corresponding object.

## Vanilla sandbox compatibility

Extinction does not replace or rewrite:

- population multiplier and presets;
- starting and peak population;
- peak day;
- migration;
- respawn;
- rally groups and distribution;
- time since apocalypse;
- start date and world time;
- standard corpse-removal or corpse-sickness settings.

Examples:

- a six-month-later start initializes new zombies from six months of biological
  history instead of giving them fresh reserves;
- fixed mode still kills every eligible zombie already beyond its configured
  deadline;
- enabling natural mode locks and ignores the fixed deadline;
- respawned objects in an old world inherit old-world history and cannot inject
  a fresh reserve;
- the number and distribution of zombies always originate from the selected
  vanilla settings.

## Project A-Life compatibility

- Living NPCs never receive a zombie reserve.
- Extinction never kills a Project A-Life character.
- Known ownership markers are checked before biological processing.
- A dead NPC may become food only after it genuinely exists as an
  `IsoDeadBody`.
- A mod-created hostile participates only if it is an actual `IsoZombie` and
  is not marked as an owned NPC actor or shell.
- Real zombies created by another mod follow the same extinction rules.
A dedicated Project A-Life runtime test remains mandatory.

## Testing overlays

Both overlays are simple sandbox checkboxes and default to Off.

### Testing: Show Zombie Biological State

The client draws one compact line over nearby active zombies:

```text
Reserve 0.62 | ~1 days | Critical
```

Possible states:

- `Stable`
- `Rain-supported`
- `Hungry`
- `Critical`
- `Failing`
- `Feeding`

The reserve value is authoritative. Approximate days are a baseline diagnostic,
not a promised death date.

### Testing: Show Corpse Nutrition

The client draws a compact label over nearby human, zombie, and animal corpses:

```text
Human corpse | raw 12.80d | usable 8.96d
```

`raw` is the remaining gross corpse resource. `usable` is the part that can
still become zombie reserve after the 70% digestion efficiency is applied.
Pending and depleted corpses are visually distinguished. A second line shows
the time remaining until age-based skeletonization, reports when
skeletonization is disabled, or marks a depleted body for immediate conversion.

The overlay:

- is limited to approximately 20 tiles;
- skips zombies on another floor or outside the screen;
- reads synchronized zombie mod data;
- creates no additional persistent biological fields;
- performs no drawing work while disabled;
- is client-side and intended only as a temporary diagnostic display.

## Performance rules

- One persistent reserve value per active zombie.
- One persistent resource value only on touched corpses.
- Server-authoritative biological calculation.
- No per-frame biological update.
- No full-map zombie, corpse, or animal scan.
- Corpse lookup uses active chunk indexes.
- Animal lookup uses the game's active animal list and a bounded radius.
- Zombie updates use sector batches.
- Shared corpse resource is debited atomically.
- Debug rendering is nearby-only and disabled by default.
- Temporary object tables use weak references.
- Save/reload cannot reroll an initialized reserve.

Dense-city profiling remains required before release.

## Feasibility audit

| Feature | Assessment | Evidence or limitation |
|---|---|---|
| Custom checkboxes | Verified | The mod already uses Build 42 custom sandbox options and UI hooks. |
| Lock fixed deadline | Verified | Existing UI hook already supports it. |
| One zombie reserve | Implemented; runtime test required | Uses synchronized zombie mod data and sector batches. |
| One lazy corpse resource | Implemented; runtime test required | Uses native death age and absolute-age decay caps. |
| Native corpse eating | Verified API path | Uses `setBodyToEat`, remembers the assigned corpse, and resumes the game's eating state until depletion. |
| Human/zombie corpse feeding | Implemented; runtime test required | Eligible `IsoDeadBody` objects are indexed by chunk. |
| Animal corpse feeding | Implemented; runtime test required | Animal type and size APIs are present. |
| Current rain support | Implemented; runtime test required | Climate, snow, temperature, and outdoor APIs are present. |
| Living animal pursuit | Implemented target path; runtime gate | Full native attack sequence must be observed in game. |
| Human skeleton conversion | Verified and implemented | Uses native `createCorpse(true)`. |
| Animal skeletons | Species-dependent | Incorrect human skeleton fallback is prohibited. |
| Preserve hard loot | Implemented; multiplayer test required | Uses native item containers and ground-item fallback. |
| Historical start age | Implemented as an approximation | New objects use full apocalypse age. |
| Exact individual off-screen routes | Not feasible in pure Lua | Engine virtualization requires aggregate sectors. |
| Project A-Life exclusion | Implemented; integration test required | Checks known A-Life ownership markers. |
| Biological overlay | Implemented; runtime test required | Uses active-zombie lists, world projection, and UI drawing. |

## Mandatory runtime validation gates

### Core simulation

- [ ] One reserve persists through save and reload.
- [ ] Chunk unload/reload cannot reroll reserve.
- [ ] Early, average, and long-tail outcomes match the intended curve.
- [ ] Rain helps only outdoors during liquid precipitation.
- [ ] Snow gives no immediate hydration.
- [ ] Rotten corpses lose resource without poisoning zombies.
- [ ] Feeding cannot create resource through load/unload cycles.
- [ ] A depleted zombie produces less resource than a fresh body.
- [ ] Multiple eaters cannot debit a corpse twice.
- [ ] Zombies never target living zombies as food.

### Animals

- [ ] Every vanilla animal corpse receives a sane resource amount.
- [ ] Pathing and attack animation work for each animal size.
- [ ] Native attack damage reaches animals correctly.
- [ ] Animals flee and die through normal systems.
- [ ] Multiplayer creates exactly one authoritative corpse.
- [ ] Unsupported animal skeletons fall back safely.

### Remains and loot

- [ ] Human remains convert without deleting hard loot.
- [ ] Only explicit clothing and soft containers are destroyed.
- [ ] Nested bags are emptied first.
- [ ] Unknown and modded items are preserved.
- [ ] Container and ground transfer synchronize in multiplayer.

### World history and compatibility

- [ ] A six-month-later start reconstructs an aged population.
- [ ] Vanilla population multipliers preserve the expected scale.
- [ ] Peak day, migration, and respawn do not inject fresh reserves.
- [ ] Sector timing advances persistent zombies exactly once.
- [ ] Newly discovered regions do not contain biologically fresh zombies.
- [ ] Living Project A-Life NPCs remain untouched.
- [ ] Unmarked real `IsoZombie` objects from other mods participate.

### Testing overlays

- [ ] Biological labels show nearby active zombies only.
- [ ] Multiplayer labels contain server-authoritative values.
- [ ] Corpse labels decrease during feeding and remain synchronized with the server-authoritative resource.
- [ ] Dense-city overlay remains readable and performant.

### Performance

- [ ] No biological function executes per zombie per frame.
- [ ] Dense-city server time remains acceptable.
- [ ] Corpse fields do not cause a square scan per hungry zombie.
- [ ] Overlay cost is negligible while disabled.
- [ ] Long saves do not accumulate unbounded stale records.

## Release policy

Natural Extinction will ship only after mandatory runtime gates pass.

The final option does not use the word “experimental”, but removing that label
does not lower the validation standard.

Until runtime validation is complete:

- fixed-timeline Extinction remains the stable released mode;
- Natural Extinction remains disabled by default;
- version 1.1 remains a local/feature-branch beta;
- Steam Workshop is not updated;
- `main` is not replaced.

## References

Biology, population, and climate:

- FAO, Human Energy Requirements:
  https://www.fao.org/4/y5686e/y5686e07.htm
- James Cole, calorific significance of human cannibalism:
  https://www.nature.com/articles/srep44707
- CDC/NCHS, NHANES III:
  https://wwwn.cdc.gov/nchs/nhanes/nhanes3/
- U.S. Census Bureau, 1990 Census:
  https://www.census.gov/programs-surveys/decennial-census/decade.1990.html
- NOAA, U.S. Climate Normals:
  https://www.ncei.noaa.gov/products/land-based-station/us-climate-normals
- Decomposition and accumulated degree days:
  https://pmc.ncbi.nlm.nih.gov/articles/PMC5920129/

Project Zomboid Build 42 API:

- `IsoZombie`:
  https://demiurgequantified.github.io/ProjectZomboidJavaDocs/zombie/characters/IsoZombie.html
- `IsoPlayer`:
  https://demiurgequantified.github.io/ProjectZomboidJavaDocs/zombie/characters/IsoPlayer.html
- `IsoAnimal`:
  https://demiurgequantified.github.io/ProjectZomboidJavaDocs/zombie/characters/animals/IsoAnimal.html
- `IsoDeadBody`:
  https://demiurgequantified.github.io/ProjectZomboidJavaDocs/zombie/iso/objects/IsoDeadBody.html
- `ClimateManager`:
  https://demiurgequantified.github.io/ProjectZomboidJavaDocs/zombie/iso/weather/ClimateManager.html
- `ZombiePopulationManager`:
  https://demiurgequantified.github.io/ProjectZomboidJavaDocs/zombie/popman/ZombiePopulationManager.html
- Build 42 Lua events:
  https://demiurgequantified.github.io/ProjectZomboidLuaDocs/md_Events.html

## Approval boundary

The design is approved for implementation on the feature branch.

This approval does not authorize:

- merging version 1.1 into `main`;
- creating a public GitHub release;
- replacing the Steam Workshop build;
- presenting unperformed in-game tests as completed.

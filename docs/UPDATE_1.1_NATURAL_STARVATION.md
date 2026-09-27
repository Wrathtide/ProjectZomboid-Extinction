# Extinction 1.1 Project — Natural Starvation

> Status: researched and technically feasible, pending prototype validation.
>
> This document is a design target, not a promise that every item below is already implemented.

## Vision

Version 1.1 is planned to add an optional natural-extinction simulation alongside Extinction's stable fixed-timeline mode.

Zombies will consume energy every day. They may survive longer by feeding on corpses that already exist, but they will never attack or damage other zombies to obtain food. Corpse decomposition, metabolic losses, and imperfect digestion will continuously remove energy from the closed system. As edible remains disappear, the zombie population will gradually starve.

```text
Living zombie
     │ consumes energy
     ▼
Hunger threshold ──► searches for an existing corpse
     │                         │
     │ none found              │ corpse found
     ▼                         ▼
Starvation death        native eating behaviour
     │                         │
     └──── becomes a corpse ◄──┘
                               │
                     calories and decomposition
                               │
                               ▼
                  exhausted corpse / skeleton
```

## Non-negotiable rules

- Zombies never attack, injure, or target living zombies as food.
- Feeding is allowed only from an existing `IsoDeadBody`.
- Eligible food consists of non-skeletal human and zombie corpses.
- Animal corpses are excluded from the initial design.
- Living NPCs, including Project A-Life characters, are never affected by Extinction's death system.
- Zombies created by another mod are eligible only when they are actual `IsoZombie` objects.
- Vanilla sandbox population, peak, migration, respawn, and apocalypse-age settings remain authoritative.
- The existing fixed extinction timeline remains the stable default until the natural mode passes all validation gates.

## Verified Project Zomboid support

Build 42.20 contains a native `ZombieEatBodyState` and public zombie methods including `setBodyToEat(IsoDeadBody)`, `setEatBodyTarget(IsoMovingObject, boolean)`, and `getEatBodyTarget()`.

The native implementation already provides movement and pathing towards a corpse, kneeling and eating animation, feeding sounds and blood effects, multiplayer synchronization, interruption when a higher-priority target appears, and a three-eaters-per-body limit.

Vanilla corpse selection accepts human corpses but deliberately rejects zombie corpses. Extinction 1.1 will replace only this selection step. After selecting an eligible corpse, it will hand control back to the game's native eating state. It will not replace combat AI, create zombie-on-zombie attacks, or use a living zombie as an eating target.

## Active-area simulation

Loaded zombies will be simulated individually on the server. Each tracked zombie will have a current energy reserve, daily metabolic requirement, a small deterministic metabolism variation, last accounting time, and hunger and starvation thresholds.

Energy accounting will run at a low fixed frequency, such as every ten in-game minutes, rather than every frame:

```text
energy spent = daily requirement × elapsed game hours / 24
```

The initial reference value will be approximately 2,500 kcal per day. This is a gameplay model based on ordinary adult human energy requirements, not a claim about fictional zombie biology.

### Corpse selection

A hungry zombie may select a corpse only when:

- it has no living target and is not performing a higher-priority action;
- the object is an existing `IsoDeadBody`;
- it is a human or zombie corpse, not an animal;
- it is not a skeleton;
- it has edible calories remaining;
- it is still present in the world and reachable;
- fewer than three zombies are already feeding from it.

Corpse lookup will use a per-chunk index maintained from corpse-spawn and chunk-load events. It will not scan every nearby square for every zombie on every frame.

### Feeding and calorie transfer

The native animation does not contain a nutritional system. Extinction must perform server-authoritative accounting while `getEatBodyTarget()` still points to the corpse.

For each accounting interval:

1. Determine how much tissue each active eater could consume.
2. Cap the total by the corpse's remaining calories.
3. Remove the consumed amount from the corpse exactly once.
4. Add only the assimilated portion to the eating zombies.
5. Permanently discard the remainder as metabolic and feeding loss.
6. Detach all eaters when no edible energy remains.

The initial prototype will use roughly 70% assimilation efficiency. This is an explicit balancing assumption and will be validated before becoming a release default.

## Corpse energy model

The research baseline is approximately 32,000 kcal of potentially edible skeletal muscle for an average fresh human body, with a deterministic body-size variation of approximately 0.70–1.30.

```text
initial edible calories = 32,000 × body-size factor
approximate range       = 22,400–41,600 kcal
```

At 70% assimilation and a 2,500 kcal daily requirement, an average fresh corpse could extend one zombie's survival by about nine days. Multiple eaters divide the benefit.

A zombie that dies from starvation still becomes food, but its corpse must not reset to a full healthy-body value. Its remaining calories will depend on its original body size, starvation damage, previous feeding history, and decomposition state. The proposed starvation-corpse range is approximately 40–70% of the corresponding fresh-body value, subject to prototype balancing.

This keeps the system lossy: corpse energy is reduced by decomposition, feeding loss, and metabolic expenditure. The final survivor cannot consume its own future corpse, so extinction remains the eventual outcome in a closed population with no external supply of fresh bodies.

## Decomposition and skeletonization

Edible decay and visual skeletonization are separate processes.

- A body may become nutritionally exhausted long before it turns into a skeleton.
- A skeleton always contains zero edible calories.
- Warm conditions accelerate decay.
- Cold conditions slow decay.
- Freezing conditions almost suspend decay.
- Feeding damage may accelerate the loss of remaining tissue.
- The existing configurable skeletonization period remains independent, with 180 days as its default.

Project Zomboid exposes climate and square-temperature data, but it does not expose a scientifically exact remaining-calorie value. Extinction will use a documented temperature-dependent gameplay model. Exact decay constants must be calibrated in the prototype and must not be presented as forensic facts.

## Unloaded-world simulation

Project Zomboid virtualizes distant zombies through `ZombiePopulationManager`. A Lua mod cannot safely maintain a complete, continuously running object-level simulation for every virtual zombie on the entire map.

Version 1.1 will therefore use two layers:

| World state | Simulation |
|---|---|
| Loaded near players | Individual zombie and corpse accounting |
| Unloaded / virtualized | Persistent aggregate sector accounting |

Each aggregate sector record will contain the last simulated apocalypse hour, estimated living population, total living-zombie energy, total edible corpse energy, energy lost to metabolism and decomposition, and a data-model version.

When a sector loads, Extinction will advance this aggregate model over elapsed game time, reconcile it with the zombies and corpses supplied by the engine, and distribute the result deterministically. Zombies that could not have survived will become corpses outside player sight whenever possible.

This is an energy-conserving approximation, not a claim that every distant zombie followed an individually simulated route while unloaded.

## Sandbox compatibility

Extinction will not replace or rewrite vanilla population options. The natural model must consume the world produced by the selected population multipliers, peak day, migration, respawn, start date, and `Time Since Apocalypse`.

A zombie object spawned six months after the apocalypse will not receive six months of fresh energy merely because the engine instantiated it then. Its state must be derived from apocalypse age and the persistent sector balance. With respawn enabled, new objects represent members of the historical population and must not inject fresh energy into the world.

## NPC and Project A-Life boundary

- Extinction never applies zombie starvation logic to a living NPC.
- Extinction never kills an A-Life character.
- A dead human NPC may become food only after it genuinely exists as an `IsoDeadBody`.
- A mod-created hostile entity participates only if it is an actual `IsoZombie`.
- Project A-Life compatibility must pass a dedicated integration test before release.

## Performance rules

- Server-authoritative calculation only.
- No full-map zombie iteration.
- No per-frame calorie accounting.
- No per-zombie full-square scan.
- Corpses indexed by loaded chunk.
- Hungry zombies searched in batches.
- Shared corpse calories debited atomically.
- Empty sector records compacted.

## Prototype gates

- [ ] Direct a zombie to an existing zombie corpse without attacking a living zombie.
- [ ] Preserve native walking, kneeling, eating, sounds, interruption, and multiplayer synchronization.
- [ ] Prevent duplicate calorie consumption by multiple eaters.
- [ ] Preserve corpse calories and sector balances through save/reload.
- [ ] Prevent chunk unload/reload from resetting reserves or creating fresh food.
- [ ] Reconstruct an aged population when starting six months after the apocalypse.
- [ ] Prevent vanilla respawn from injecting fresh energy into an old world.
- [ ] Verify predictable decay in warm, cold, and freezing conditions.
- [ ] Convert exhausted corpses to zero-calorie skeletons without stale eat targets.
- [ ] Keep living Project A-Life NPCs untouched.
- [ ] Include A-Life-created `IsoZombie` instances.
- [ ] Verify server-authoritative single-player and multiplayer results.
- [ ] Keep dense urban corpse fields within an acceptable performance budget.

## Release policy

Natural Starvation will be optional in 1.1. The fixed extinction schedule remains available and remains the recommended stable mode until the new simulation completes every gate above.

If reliable off-screen reconciliation cannot be achieved without replacing Project Zomboid Java classes, the feature will remain experimental and will not replace the stable Lua implementation.

## Research references

- FAO, *Human Energy Requirements*: https://www.fao.org/4/y5686e/y5686e07.htm
- James Cole, *Assessing the calorific significance of episodes of human cannibalism in the Palaeolithic*: https://cris.brighton.ac.uk/ws/portalfiles/portal/445829/srep44707%20%281%29%20%281%29.pdf
- Temperature and accumulated degree days in decomposition research: https://pmc.ncbi.nlm.nih.gov/articles/PMC5920129/
- Project Zomboid Build 42.20 `IsoZombie` API: https://demiurgequantified.github.io/ProjectZomboidJavaDocs/zombie/characters/IsoZombie.html
- Project Zomboid Build 42.20 `ZombiePopulationManager` API: https://demiurgequantified.github.io/ProjectZomboidJavaDocs/zombie/popman/ZombiePopulationManager.html
- Project Zomboid Build 42 Lua events: https://demiurgequantified.github.io/ProjectZomboidLuaDocs/md_Events.html


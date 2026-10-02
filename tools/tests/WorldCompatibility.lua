-- Execute with actual WorldSettings, NaturalStarvation and Server modules.
local T = CompatibilityTest
local S = Extinction.WorldSettings
local NS = Extinction.NaturalStarvation

T.world(false, true, true)
assert(S.isLegacyFixedWorld() and not NS.isEnabled() and not S.isHuntingEnabled(),
    "An old fixed world was migrated into new gameplay")
assert(T.storage.ExtinctionNaturalSectors == nil, "Old world initialized natural sectors")
local originalDate = 480
local zombie = T.zombie({ ExtinctionDeathAgeHours = originalDate, ExtinctionVersion = 2 })
T.zombies = { zombie }
local draws = T.randomCalls
T.fire("EveryOneMinute")
assert(zombie.data.ExtinctionDeathAgeHours == originalDate and T.randomCalls == draws,
    "Existing death date was re-rolled")
assert(zombie.data.ExtinctionBiologicalReserve == nil, "Fixed world initialized reserve")
T.hours = 481
T.fire("EveryOneMinute")
assert(zombie.converted and zombie.corpse.data.ExtinctionDeathAgeHours == originalDate,
    "Original fixed death did not retain its historical date")
assert(zombie.corpse.deathTime == originalDate, "Original corpse date changed")

local inventoryReads = 0
local skeleton = { data = {} }
function skeleton:getModData() return self.data end
function skeleton:getContainer() inventoryReads = inventoryReads + 1; return nil end
local square = { removed = false }
function square:createCorpse(nativeSkeleton)
    assert(nativeSkeleton == true, "Skeleton did not use the original native path")
    return skeleton
end
function square:removeCorpse(body, ignored) self.removed = true end
local oldBody = { class = "IsoDeadBody", data = { ExtinctionDeathAgeHours = 0 } }
function oldBody:getSquare() return square end
function oldBody:getModData() return self.data end
function oldBody:isZombie() return true end
function oldBody:isAnimal() return false end
function oldBody:isSkeleton() return false end
function oldBody:getX() return 0 end
function oldBody:getY() return 0 end
function oldBody:getZ() return 0 end
function oldBody:getContainer() inventoryReads = inventoryReads + 1; return nil end
SandboxVars.Extinction.SkeletonizationDays = 1
T.fire("OnObjectAdded", oldBody)
T.hours = 25
T.fire("EveryHours")
assert(square.removed and skeleton.data.ExtinctionSkeletonized == true,
    "Legacy corpse did not become a skeleton")
assert(inventoryReads == 0, "Legacy world received new skeleton loot handling")
SandboxVars.Extinction.SkeletonizationDays = 180

T.world(false, false, true, { ExtinctionNaturalSectors = { version = 1, sectors = {} } })
assert(S.isLegacyFixedWorld() and not S.isHuntingEnabled(),
    "Empty development sector table was mistaken for a natural world")

T.world(true, false, true)
assert(not S.isLegacyFixedWorld() and not NS.isEnabled() and S.isHuntingEnabled(),
    "New fixed world cannot select independent hunting")
zombie = T.zombie({ ExtinctionDeathAgeHours = 480 })
local animal = { class = "IsoAnimal" }
function animal:getX() return 1 end
function animal:getY() return 0 end
function animal:getZ() return 0 end
zombie.target = animal
T.zombies = { zombie }
T.fire("EveryOneMinute")
assert(NS.animalTargets[zombie] == animal, "Fixed-world scan did not adopt animal target")
assert(zombie.data.ExtinctionBiologicalReserve == nil and T.storage.ExtinctionNaturalSectors == nil,
    "Independent hunting initialized starvation")

local fixedSettings = T.storage
T.world(false, true, false, fixedSettings)
assert(not NS.isEnabled() and S.isHuntingEnabled(), "Reload changed saved world modes")

T.world(true, true, false)
assert(NS.isEnabled() and not S.isHuntingEnabled(), "Natural mode requires hunting")
zombie = T.zombie()
T.zombies = { zombie }
T.fire("EveryOneMinute")
assert(tonumber(zombie.data.ExtinctionBiologicalReserve) ~= nil,
    "New natural world did not initialize reserve")
assert(zombie.data.ExtinctionDeathAgeHours == nil, "Natural zombie got a fixed deadline")
assert(zombie.data.ExtinctionBiologicalReserve <= 21, "Reserve exceeded its cap")
local naturalSettings = T.storage
T.world(false, false, true, naturalSettings)
assert(NS.isEnabled() and not S.isHuntingEnabled(), "Reload changed natural world modes")

T.world(false, true, true, { ExtinctionNaturalSectors = {
    version = 1, sectors = { ["0:0"] = { lastHour = 0 } } } })
assert(NS.isEnabled() and not S.isLegacyFixedWorld(), "Existing natural test save was not preserved")

T.world(true, false, false)
SandboxVars.TimeSinceApo = 7
SandboxVars.Extinction.ExtinctionDays = 30
zombie = T.zombie()
T.zombies = { zombie }
T.fire("EveryOneMinute")
assert(zombie.converted, "Late-start world contains a living scheduled zombie")
assert(zombie.corpse.data.ExtinctionDeathAgeHours <= 30 * 24,
    "Late-created corpse has a fresh death date")
assert(zombie.corpse.deathTime < 0, "Apocalypse offset was not applied to historical corpse")
assert(SandboxVars.TimeSinceApo == 7 and SandboxVars.ZombieConfig.PopulationMultiplier == 2.5,
    "The mod changed vanilla sandbox settings")

T.world(false, true, true)
zombie = T.zombie({ ProjectALifeOwned = true })
T.zombies = { zombie }
T.hours = 100000
T.fire("EveryOneMinute")
assert(not zombie.converted and zombie.data.ExtinctionDeathAgeHours == nil
    and zombie.data.ExtinctionBiologicalReserve == nil, "A-Life actor was modified")
print("OK zgodnosc swiata: stare daty, nowy wybor trybu, przeladowanie, polowanie, pozny start i A-Life")

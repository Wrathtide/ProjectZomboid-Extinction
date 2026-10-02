-- Exercises the actual NS.processAnimalAttacks implementation with simulated
-- animation event flags. This is not a rendered in-game animation test.
local NS = Extinction.NaturalStarvation
SandboxVars = { Extinction = { NaturalStarvation = true, HuntAnimals = true } }
local now = 1000
function getTimestampMs() return now end
local square = { isSomethingTo = function() return false end }
local animal = { health = 10, hits = 0 }
function animal:getSquare() return square end
function animal:isDead() return self.health <= 0 end
function animal:getHealth() return self.health end
function animal:setHealth(value) self.health = value end
function animal:getCorpseSize() return 3 end
function animal:getX() return 1 end
function animal:getY() return 0 end
function animal:getZ() return 0 end
function animal:hitConsequences(weapon, attacker, ignored, damage, final)
    self.hits = self.hits + 1
    self.health = self.health - damage
end
local zombie = { variables = {}, target = animal }
function zombie:getSquare() return square end
function zombie:isDead() return false end
function zombie:getTarget() return self.target end
function zombie:setTarget(value) self.target = value end
function zombie:getX() return 0 end
function zombie:getY() return 0 end
function zombie:getZ() return 0 end
function zombie:faceThisObject(value) end
function zombie:setTargetSeenTime(value) end
function zombie:clearVariable(name) self.variables[name] = nil end
function zombie:setVariable(name, value) self.variables[name] = value end
function zombie:GetVariable(name) return tostring(self.variables[name] or "") end
function zombie:getActionStateName() return "attack" end
function zombie:getAnimationStateName() return "attack" end
local function step() NS.processAnimalAttacks() end
local function event(suffix) zombie:setVariable("ExtinctionAnimalBite" .. suffix, true) end
NS.animalTargets[zombie] = animal
step()
assert(NS.pendingAnimalBites[zombie] ~= nil, "Bite not requested")
assert(animal.hits == 0, "Damage applied before animation")
now = now + 500
step()
assert(animal.hits == 0, "Timer caused phantom damage")
event("Started")
step()
assert(animal.hits == 0, "Start event caused damage")
event("Contact")
step()
assert(animal.hits == 1 and animal.health == 7.5, "Contact did not cause one bite")
step()
assert(animal.hits == 1, "Contact damage repeated")
event("Done")
step()
assert(NS.pendingAnimalBites[zombie] == nil, "End did not release bite")
assert(zombie.variables.ExtinctionAnimalBiteActive == nil, "Active flag not cleared")
now = now + 2000
step()
now = now + 4100
step()
assert(NS.pendingAnimalBites[zombie] == nil and animal.hits == 1, "Timeout caused invisible bite")
now = now + 2000
step()
animal.health = 1
event("Started")
event("Contact")
step()
assert(animal.health == 0 and animal.hits == 2, "Lethal bite did not set native death trigger")
assert(NS.pendingAnimalBites[zombie] ~= nil, "Lethal bite ended animation early")
step()
assert(NS.pendingAnimalBites[zombie] ~= nil, "Death interrupted animation before end")
event("Done")
step()
assert(NS.animalTargets[zombie] == nil and NS.pendingAnimalBites[zombie] == nil, "Dead target not released")
animal.health = 10
NS.animalTargets[zombie] = animal
now = now + 2000
step()
SandboxVars.Extinction.HuntAnimals = false
step()
assert(NS.pendingAnimalBites[zombie] == nil and zombie.variables.ExtinctionAnimalBiteActive == nil,
    "Disabling hunting left animation active")
print("OK cykl ugryzienia: brak obrazen przed kontaktem, jeden hit, timeout, zgon i wylaczenie opcji")

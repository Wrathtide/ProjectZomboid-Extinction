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
local zombie = { variables = {}, target = animal, action = "idle", pathRequests = 0 }
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
function zombie:getActionStateName() return self.action end
function zombie:getAnimationStateName() return self.action end
local route = { cancelled = false }
function route:getTargetChar() return animal end
function route:getIsCancelled() return self.cancelled end
function zombie:getPathFindBehavior2() return route end
function zombie:pathToCharacter(value)
    self.pathRequests = self.pathRequests + 1
    self.action = "pathfind"
    route.cancelled = false
end
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

SandboxVars.Extinction.HuntAnimals = true
function animal:getX() return 10 end
NS.animalTargets[zombie] = animal
zombie.action = "idle"
now = now + 2000
step()
assert(zombie.pathRequests == 1, "Initial pursuit did not request a path")
for index = 1, 100 do
    now = now + 100
    step()
end
assert(zombie.pathRequests == 1, "Repeated ticks cancelled existing character route")
route.cancelled = true
now = now + 1100
step()
assert(zombie.pathRequests == 2, "Cancelled route was not retried")
zombie.action = "thump"
for index = 1, 20 do
    now = now + 100
    step()
end
assert(zombie.pathRequests == 2, "Pursuit interrupted obstacle action")
zombie.action = "climbthroughwindow"
now = now + 1100
step()
assert(zombie.pathRequests == 2, "Pursuit interrupted climbing")
zombie.action = "idle"
now = now + 1100
step()
assert(zombie.pathRequests == 3, "Idle zombie did not restart pursuit")
function animal:getX() return 1 end
function square:isSomethingTo(value) return true end
now = now + 1100
step()
assert(NS.pendingAnimalBites[zombie] == nil, "Attack started through obstacle")
local healthBeforeObstacle = animal.health
step()
assert(animal.health == healthBeforeObstacle, "Obstacle test caused damage")
print("OK poscig: zachowanie trasy, ograniczone ponowienia, przeszkody, wspinanie i brak ataku przez sciane")

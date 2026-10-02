-- Minimal engine fixtures. Actual mod code is loaded after this file.
CompatibilityTest = { storage = {}, zombies = {}, hours = 0, randomCalls = 0 }
local T = CompatibilityTest
SandboxVars = { TimeSinceApo = 1, ZombieConfig = { PopulationMultiplier = 2.5 },
    Extinction = { NaturalStarvation = false, HuntAnimals = true,
        ExtinctionDays = 21, SkeletonizationDays = 180 } }
ModData = {}
function ModData.get(key) return T.storage[key] end
function ModData.getOrCreate(key)
    T.storage[key] = T.storage[key] or {}
    return T.storage[key]
end
function ModData.transmit(key) end
Events = setmetatable({}, { __index = function(events, name)
    local event = { handlers = {} }
    function event.Add(handler) table.insert(event.handlers, handler) end
    events[name] = event
    return event
end })
function T.fire(name, argument)
    for _, handler in ipairs(Events[name].handlers) do handler(argument) end
end
function require(name)
    if name == "Extinction/ExtinctionWorldSettings" then return Extinction.WorldSettings end
    if name == "Extinction/ExtinctionNaturalStarvation" then return Extinction.NaturalStarvation end
    error("Unexpected module: " .. name)
end
function ZombRand(a, b)
    T.randomCalls = T.randomCalls + 1
    return 500000
end
function getGameTime() return { getWorldAgeHours = function() return T.hours end } end
function getCell()
    return { getZombieList = function()
        return { size = function() return #T.zombies end,
            get = function(_, index) return T.zombies[index + 1] end }
    end, getAnimals = function() return { size = function() return 0 end } end }
end
function instanceof(object, class) return object ~= nil and object.class == class end
function isServer() return false end

function T.zombie(data)
    local zombie = { class = "IsoZombie", data = data or {}, converted = false,
        target = nil, variables = {} }
    local square = {}
    function square:createCorpse(character, ignored)
        character.converted = true
        local body = { class = "IsoDeadBody", data = {}, deathTime = nil }
        function body:getModData() return self.data end
        function body:isZombie() return true end
        function body:isAnimal() return false end
        function body:isSkeleton() return false end
        function body:isPlayer() return false end
        function body:setDeathTime(value) self.deathTime = value end
        function body:getDeathTime() return self.deathTime end
        function body:getX() return 0 end
        function body:getY() return 0 end
        function body:getZ() return 0 end
        character.corpse = body
        return body
    end
    function zombie:getCurrentSquare() return square end
    function zombie:getSquare() return square end
    function zombie:getModData() return self.data end
    function zombie:isDead() return self.converted end
    function zombie:getTarget() return self.target end
    function zombie:setTarget(value) self.target = value end
    function zombie:isCrawling() return false end
    function zombie:getEatBodyTarget() return nil end
    function zombie:getX() return 0 end
    function zombie:getY() return 0 end
    function zombie:getZ() return 0 end
    function zombie:GetVariable(name) return tostring(self.variables[name] or "") end
    function zombie:setVariable(name, value) self.variables[name] = value end
    function zombie:setTargetSeenTime(value) end
    return zombie
end

function T.world(isNewGame, natural, hunting, storage)
    T.storage = storage or {}
    T.zombies = {}
    T.hours = 0
    SandboxVars.TimeSinceApo = 1
    SandboxVars.Extinction.NaturalStarvation = natural
    SandboxVars.Extinction.HuntAnimals = hunting
    Extinction.NaturalStarvation.sectorRoot = nil
    Extinction.NaturalStarvation.nextAnimalSearch = {}
    Extinction.trackedBodies = {}
    T.fire("OnInitGlobalModData", isNewGame)
end

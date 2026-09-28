Extinction = Extinction or {}

local NS = Extinction.NaturalStarvation or {}
Extinction.NaturalStarvation = NS

local HOURS_PER_DAY = 24
local BASELINE_DAILY_DRAIN = 1.0
-- Forensic reviews place exceptional survival without both food and fluid at
-- roughly 8-21 days. The reserve is therefore a short-term biological buffer,
-- not a store of every calorie contained in the body.
local MAX_RESERVE_DAYS = 21
local HUNGER_RESERVE_DAYS = 4
local ASSIMILATION_EFFICIENCY = 0.70
local CONSUMPTION_RESOURCE_PER_HOUR = 0.36
local HUMAN_CORPSE_RESOURCE = 12.8
local FOOD_SEARCH_RADIUS = 10
local ANIMAL_SEARCH_RADIUS = 16
local FOOD_SEARCH_INTERVAL_HOURS = 1
local HISTORICAL_RAIN_SUPPORT_PER_DAY = 0.20
local SECTOR_SIZE = 50
local SECTOR_DATA_KEY = "ExtinctionNaturalSectors"
local SECTOR_DATA_VERSION = 1

local LEGACY_ZOMBIE_KEYS = {
    "ExtinctionNaturalInitialized",
    "ExtinctionNaturalDailyNeedKcal",
    "ExtinctionNaturalBodyFactor",
    "ExtinctionNaturalInitialKcal",
    "ExtinctionNaturalEnergyKcal",
    "ExtinctionNaturalLastHour",
    "ExtinctionNaturalNoFoodDeathAgeHours",
    "ExtinctionNaturalHistoricalDeathAgeHours",
    "ExtinctionNaturalNextFoodSearchHour",
    "ExtinctionNaturalConsumedFood",
}

local LEGACY_BODY_KEYS = {
    "ExtinctionFoodInitialized",
    "ExtinctionBodyFactor",
    "ExtinctionFoodInitialKcal",
    "ExtinctionFoodKcal",
    "ExtinctionFoodLastHour",
    "ExtinctionStarvationCorpse",
}

local ANIMAL_RESOURCE_BY_NAME = {
    mousepups = 0.01,
    mousefemale = 0.02,
    mouse = 0.02,
    ratbaby = 0.02,
    ratfemale = 0.05,
    rat = 0.05,
    chick = 0.08,
    hen = 0.45,
    cockerel = 0.55,
    turkeypoult = 0.20,
    turkeyhen = 1.20,
    gobblers = 1.50,
    lamb = 3.00,
    ewe = 8.00,
    ram = 9.00,
    piglet = 4.00,
    sow = 18.00,
    boar = 20.00,
    fawn = 3.00,
    doe = 10.00,
    buck = 12.00,
    cowcalf = 10.00,
    cow = 45.00,
    bull = 50.00,
}

local ANIMAL_RESOURCE_FALLBACKS = {
    { "mouse", 0.02 },
    { "rat", 0.05 },
    { "chicken", 0.45 },
    { "chick", 0.08 },
    { "turkey", 1.20 },
    { "lamb", 3.00 },
    { "sheep", 8.00 },
    { "piglet", 4.00 },
    { "pig", 18.00 },
    { "fawn", 3.00 },
    { "deer", 10.00 },
    { "calf", 10.00 },
    { "cow", 45.00 },
    { "bull", 50.00 },
}

local function weakKeyTable()
    return setmetatable({}, { __mode = "k" })
end

NS.bodyChunks = NS.bodyChunks or {}
NS.bodyChunkKeys = NS.bodyChunkKeys or weakKeyTable()
NS.nextFoodSearch = NS.nextFoodSearch or weakKeyTable()
NS.lastReserveTransmit = NS.lastReserveTransmit or weakKeyTable()
NS.context = NS.context or nil
NS.sectorRoot = NS.sectorRoot or nil
NS.batchHour = nil
NS.batchSectorElapsed = {}
NS.batchSectorStats = {}
NS.lastBodyBatchHour = NS.lastBodyBatchHour or nil
NS.lastSectorTransmitHour = NS.lastSectorTransmitHour or 0

local function randomUnit()
    return ZombRand(0, 1000001) / 1000000
end

local function randomRange(minimum, maximum)
    return minimum + randomUnit() * (maximum - minimum)
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function optionBoolean(name, fallback)
    local group = SandboxVars and SandboxVars.Extinction
    local value = group and group[name] or nil
    if value == nil then return fallback end
    return value == true
end

local function naturalModeEnabled()
    return optionBoolean("NaturalStarvation", false)
end

local function animalHuntingEnabled()
    return naturalModeEnabled() and optionBoolean("HuntAnimals", true)
end

local function clearKeys(data, keys)
    for _, key in ipairs(keys) do
        data[key] = nil
    end
end

local function sampleInitialReserveDays()
    local roll = randomUnit()
    if roll < 0.10 then
        return randomRange(1, 3)
    elseif roll < 0.65 then
        return randomRange(3, 7)
    elseif roll < 0.95 then
        return randomRange(7, 12)
    elseif roll < 0.995 then
        return randomRange(12, 18)
    end
    return randomRange(18, MAX_RESERVE_DAYS)
end

local function chunkKeyFor(object)
    if object == nil then return nil end
    local ok, x, y, z = pcall(function()
        return object:getX(), object:getY(), object:getZ()
    end)
    if not ok or x == nil or y == nil or z == nil then return nil end
    return math.floor(x / 10) .. ":" .. math.floor(y / 10) .. ":" .. math.floor(z)
end

local function sectorKeyFor(object)
    if object == nil then return nil end
    local ok, x, y = pcall(function() return object:getX(), object:getY() end)
    if not ok or x == nil or y == nil then return nil end
    return math.floor(x / SECTOR_SIZE) .. ":" .. math.floor(y / SECTOR_SIZE)
end

local function ensureSectorRoot()
    if NS.sectorRoot ~= nil then return NS.sectorRoot end
    if ModData == nil or ModData.getOrCreate == nil then return nil end
    local root = ModData.getOrCreate(SECTOR_DATA_KEY)
    root.version = SECTOR_DATA_VERSION
    root.sectors = root.sectors or {}
    NS.sectorRoot = root
    return root
end

local function ensureSector(key, currentHour)
    if key == nil then return nil end
    local root = ensureSectorRoot()
    if root == nil then return nil end
    local record = root.sectors[key]
    if record == nil then
        record = {
            lastHour = currentHour,
            observedPopulation = 0,
            meanReserve = 0,
        }
        root.sectors[key] = record
    end
    return record
end

local function bodyIsPresent(body)
    if body == nil then return false end
    local ok, index = pcall(function() return body:getStaticMovingObjectIndex() end)
    return ok and tonumber(index) ~= nil and index ~= -1
end

local function bodyIsAnimal(body)
    local animal = false
    if body ~= nil and body.isAnimal ~= nil then
        pcall(function() animal = body:isAnimal() end)
    end
    return animal
end

local function bodyIsSkeleton(body)
    local skeleton = false
    if body ~= nil and body.isSkeleton ~= nil then
        pcall(function() skeleton = body:isSkeleton() end)
    end
    if not skeleton and body ~= nil and body.isAnimalSkeleton ~= nil then
        pcall(function() skeleton = body:isAnimalSkeleton() end)
    end
    return skeleton
end

local function isEdibleBodyType(body)
    if body == nil or type(instanceof) ~= "function" or not instanceof(body, "IsoDeadBody") then
        return false
    end
    return not bodyIsSkeleton(body)
end

local function removeFromIndex(body)
    local key = NS.bodyChunkKeys[body]
    if key == nil then return end
    local bucket = NS.bodyChunks[key]
    if bucket ~= nil then
        bucket[body] = nil
        if next(bucket) == nil then NS.bodyChunks[key] = nil end
    end
    NS.bodyChunkKeys[body] = nil
end

local function addToIndex(body)
    local key = chunkKeyFor(body)
    if key == nil then return end
    local oldKey = NS.bodyChunkKeys[body]
    if oldKey ~= nil and oldKey ~= key then removeFromIndex(body) end
    local bucket = NS.bodyChunks[key]
    if bucket == nil then
        bucket = weakKeyTable()
        NS.bodyChunks[key] = bucket
    end
    bucket[body] = true
    NS.bodyChunkKeys[body] = key
end

local function squareIsOutside(square)
    if square == nil or square.isOutside == nil then return false end
    local ok, outside = pcall(function() return square:isOutside() end)
    return ok and outside == true
end

local function climateManager()
    if type(getClimateManager) ~= "function" then return nil end
    local ok, manager = pcall(getClimateManager)
    if not ok then return nil end
    return manager
end

local function liquidRainIntensity(square)
    if not squareIsOutside(square) then return 0 end
    local manager = climateManager()
    if manager == nil then return 0 end
    local snow = false
    pcall(function() snow = manager:getPrecipitationIsSnow() end)
    if snow then return 0 end
    local raining = false
    pcall(function() raining = manager:isRaining() end)
    if not raining then return 0 end
    local intensity = 0
    pcall(function() intensity = tonumber(manager:getRainIntensity()) or 0 end)
    if intensity <= 0 and manager.getPrecipitationIntensity ~= nil then
        pcall(function() intensity = tonumber(manager:getPrecipitationIntensity()) or 0 end)
    end
    return clamp(intensity, 0, 1)
end

local function bodyTemperature(body)
    local square = body and body:getSquare() or nil
    local manager = climateManager()
    if square ~= nil and manager ~= nil and manager.getAirTemperatureForSquare ~= nil then
        local ok, value = pcall(function() return manager:getAirTemperatureForSquare(square) end)
        if ok and tonumber(value) ~= nil then return tonumber(value) end
    end
    return 15
end

local function dailyDecayFraction(temperature)
    if temperature <= 0 then return 0.001 end
    if temperature <= 5 then return 0.005 end
    if temperature <= 15 then return 0.020 end
    if temperature <= 25 then return 0.050 end
    return 0.090
end

local function zombieDrainMultiplier(zombie)
    local temperature = 15
    local manager = climateManager()
    local square = zombie and zombie:getSquare() or nil
    if manager ~= nil and square ~= nil and manager.getAirTemperatureForSquare ~= nil then
        pcall(function() temperature = tonumber(manager:getAirTemperatureForSquare(square)) or 15 end)
    end

    local temperatureMultiplier = 1.0
    if temperature <= 0 then
        temperatureMultiplier = 1.15
    elseif temperature <= 5 then
        temperatureMultiplier = 1.08
    elseif temperature >= 35 then
        temperatureMultiplier = 1.25
    elseif temperature >= 30 then
        temperatureMultiplier = 1.10
    end

    local activityMultiplier = 1.0
    if zombie ~= nil and zombie.getTarget ~= nil and zombie:getTarget() ~= nil then
        activityMultiplier = 1.25
    end
    return temperatureMultiplier * activityMultiplier
end

local function detachEaters(body)
    if body == nil or body.getEatingZombies == nil then return end
    local ok, eaters = pcall(function() return body:getEatingZombies() end)
    if not ok or eaters == nil then return end
    for index = eaters:size() - 1, 0, -1 do
        local zombie = eaters:get(index)
        if zombie ~= nil then
            pcall(function() zombie:setBodyToEat(nil) end)
            pcall(function() zombie:setEatBodyTarget(nil, false) end)
        end
    end
end

local function detachZombieFromBody(zombie)
    if zombie == nil then return end
    pcall(function() zombie:setBodyToEat(nil) end)
    pcall(function() zombie:setEatBodyTarget(nil, false) end)
end

local function animalResourceFromBody(body)
    local animalType = ""
    local animalSize = 0
    pcall(function() animalType = string.lower(tostring(body:getAnimalType() or "")) end)
    pcall(function() animalSize = tonumber(body:getAnimalSize()) or 0 end)

    local resource = ANIMAL_RESOURCE_BY_NAME[animalType]
    if resource == nil then
        for _, fallback in ipairs(ANIMAL_RESOURCE_FALLBACKS) do
            if string.find(animalType, fallback[1], 1, true) ~= nil then
                resource = fallback[2]
                break
            end
        end
    end
    if resource ~= nil then
        return resource * clamp(0.50 + animalSize, 0.50, 1.50)
    end
    return clamp(0.50 + animalSize * 10, 0.25, 12)
end

local function maximumFreshBodyResource(body)
    if bodyIsAnimal(body) then
        return animalResourceFromBody(body) * 1.25
    end
    return HUMAN_CORPSE_RESOURCE * 1.30
end

local function initialBodyResource(body)
    if bodyIsAnimal(body) then
        return animalResourceFromBody(body)
    end
    return HUMAN_CORPSE_RESOURCE * randomRange(0.70, 1.30)
end

local function bodyAgeDays(body, currentHour)
    if NS.context == nil then return 0 end
    local deathHour = NS.context.bodyDeathAgeHours(body)
    return math.max(0, currentHour - deathHour) / HOURS_PER_DAY
end

local function capBodyResourceForAge(body, remaining, currentHour)
    local maximum = maximumFreshBodyResource(body)
    local decayRate = dailyDecayFraction(bodyTemperature(body))
    local ageCap = maximum * math.exp(-decayRate * bodyAgeDays(body, currentHour))
    return clamp(remaining, 0, ageCap)
end

local function ensureBodyResource(body, currentHour)
    if not isEdibleBodyType(body) or NS.context == nil then return nil end
    local data = NS.context.safeModData(body)
    if data == nil then return nil end

    local remaining = tonumber(data.ExtinctionCorpseResource)
    if remaining == nil then
        local legacyCalories = tonumber(data.ExtinctionFoodKcal)
        if legacyCalories ~= nil then
            remaining = math.max(0, legacyCalories / 2500)
        else
            remaining = initialBodyResource(body)
            local decayRate = dailyDecayFraction(bodyTemperature(body))
            remaining = remaining * math.exp(-decayRate * bodyAgeDays(body, currentHour))
        end
        data.ExtinctionCorpseResource = remaining
        clearKeys(data, LEGACY_BODY_KEYS)
        NS.context.transmitModData(body)
    else
        local capped = capBodyResourceForAge(body, remaining, currentHour)
        if math.abs(capped - remaining) >= 0.01 then
            data.ExtinctionCorpseResource = capped
            NS.context.transmitModData(body)
        end
    end
    return data
end

local function bodyEaterCount(body)
    if body == nil or body.getEatingZombies == nil then return 0 end
    local ok, eaters = pcall(function() return body:getEatingZombies() end)
    if not ok or eaters == nil then return 0 end
    return eaters:size()
end

local function bodyCanFeedZombie(body, zombie, currentHour)
    if not bodyIsPresent(body) or not isEdibleBodyType(body) then return false end
    local data = ensureBodyResource(body, currentHour)
    if data == nil or (tonumber(data.ExtinctionCorpseResource) or 0) <= 0.01 then
        return false
    end
    if bodyEaterCount(body) >= 3 then
        local target = zombie:getEatBodyTarget()
        if target ~= body then return false end
    end
    return math.floor(body:getZ()) == math.floor(zombie:getZ())
end

local function nearestEdibleBody(zombie, currentHour)
    local x = zombie:getX()
    local y = zombie:getY()
    local z = math.floor(zombie:getZ())
    local chunkX = math.floor(x / 10)
    local chunkY = math.floor(y / 10)
    local chunkRadius = math.ceil(FOOD_SEARCH_RADIUS / 10)
    local bestBody = nil
    local bestDistance = FOOD_SEARCH_RADIUS * FOOD_SEARCH_RADIUS + 1

    for offsetX = -chunkRadius, chunkRadius do
        for offsetY = -chunkRadius, chunkRadius do
            local key = (chunkX + offsetX) .. ":" .. (chunkY + offsetY) .. ":" .. z
            local bucket = NS.bodyChunks[key]
            if bucket ~= nil then
                for body, _ in pairs(bucket) do
                    if bodyCanFeedZombie(body, zombie, currentHour) then
                        local dx = body:getX() - x
                        local dy = body:getY() - y
                        local distance = dx * dx + dy * dy
                        if distance <= FOOD_SEARCH_RADIUS * FOOD_SEARCH_RADIUS
                                and distance < bestDistance then
                            bestBody = body
                            bestDistance = distance
                        end
                    elseif not bodyIsPresent(body) then
                        removeFromIndex(body)
                    end
                end
            end
        end
    end
    return bestBody
end

local function takeResourceFromBody(body, requested, currentHour)
    if requested <= 0 then return 0 end
    local bodyData = ensureBodyResource(body, currentHour)
    if bodyData == nil then return 0 end
    local remaining = tonumber(bodyData.ExtinctionCorpseResource) or 0
    local consumed = math.min(remaining, requested)
    if consumed <= 0 then return 0 end

    bodyData.ExtinctionCorpseResource = math.max(0, remaining - consumed)
    NS.context.transmitModData(body)
    if bodyData.ExtinctionCorpseResource <= 0.01 then
        bodyData.ExtinctionCorpseResource = 0
        detachEaters(body)
    end
    return consumed
end

local function migrateZombieReserve(data)
    local reserve = tonumber(data.ExtinctionBiologicalReserve)
    if reserve ~= nil then
        reserve = clamp(reserve, 0, MAX_RESERVE_DAYS)
        data.ExtinctionBiologicalReserve = reserve
        clearKeys(data, LEGACY_ZOMBIE_KEYS)
        data.ExtinctionDeathAgeHours = nil
        data.ExtinctionVersion = nil
        return reserve
    end
    local legacyCalories = tonumber(data.ExtinctionNaturalEnergyKcal)
    if legacyCalories == nil then return nil end
    reserve = clamp(legacyCalories / 2500, 0, MAX_RESERVE_DAYS)
    data.ExtinctionBiologicalReserve = reserve
    clearKeys(data, LEGACY_ZOMBIE_KEYS)
    data.ExtinctionDeathAgeHours = nil
    data.ExtinctionVersion = nil
    return reserve
end

local function initializeZombieReserve(data, currentHour)
    local existing = migrateZombieReserve(data)
    if existing ~= nil then return false, nil end

    local initialReserve = sampleInitialReserveDays()
    local apocalypseDays = currentHour / HOURS_PER_DAY
    local historicalRain = apocalypseDays * HISTORICAL_RAIN_SUPPORT_PER_DAY
    local reserve = initialReserve - apocalypseDays * BASELINE_DAILY_DRAIN + historicalRain
    data.ExtinctionBiologicalReserve = reserve
    data.ExtinctionDeathAgeHours = nil
    data.ExtinctionVersion = nil
    clearKeys(data, LEGACY_ZOMBIE_KEYS)

    local netHistoricalDrain = BASELINE_DAILY_DRAIN - HISTORICAL_RAIN_SUPPORT_PER_DAY
    local historicalDeathHour = currentHour
    if netHistoricalDrain > 0 then
        historicalDeathHour = math.min(currentHour,
            initialReserve / netHistoricalDrain * HOURS_PER_DAY)
    end
    return true, historicalDeathHour
end

local function reconcileHistoricalFood(zombie, data, currentHour)
    local reserve = tonumber(data.ExtinctionBiologicalReserve) or 0
    if reserve > 0 then return end
    local reserveGoal = randomRange(0.25, HUNGER_RESERVE_DAYS)
    local requiredAssimilated = -reserve + reserveGoal
    local bodiesUsed = 0

    while requiredAssimilated > 0 and bodiesUsed < 8 do
        local body = nearestEdibleBody(zombie, currentHour)
        if body == nil then break end
        local rawNeeded = requiredAssimilated / ASSIMILATION_EFFICIENCY
        local consumed = takeResourceFromBody(body, rawNeeded, currentHour)
        if consumed <= 0 then break end
        local assimilated = consumed * ASSIMILATION_EFFICIENCY
        reserve = reserve + assimilated
        requiredAssimilated = math.max(0, requiredAssimilated - assimilated)
        bodiesUsed = bodiesUsed + 1
    end
    data.ExtinctionBiologicalReserve = reserve
end

local function consumeFromCurrentTarget(zombie, data, elapsedHours, currentHour)
    if elapsedHours <= 0 or zombie.getEatBodyTarget == nil then return end
    local ok, body = pcall(function() return zombie:getEatBodyTarget() end)
    if not ok or body == nil or not isEdibleBodyType(body) then return end
    if not bodyCanFeedZombie(body, zombie, currentHour) then
        detachZombieFromBody(zombie)
        detachEaters(body)
        return
    end

    local reserve = clamp(
        tonumber(data.ExtinctionBiologicalReserve) or 0,
        0,
        MAX_RESERVE_DAYS
    )
    local remainingCapacity = MAX_RESERVE_DAYS - reserve
    if remainingCapacity <= 0 then
        detachZombieFromBody(zombie)
        return
    end

    local requested = math.min(
        CONSUMPTION_RESOURCE_PER_HOUR * elapsedHours,
        remainingCapacity / ASSIMILATION_EFFICIENCY
    )
    local consumed = takeResourceFromBody(body, requested, currentHour)
    if consumed <= 0 then
        detachZombieFromBody(zombie)
        return
    end
    data.ExtinctionBiologicalReserve = math.min(
        MAX_RESERVE_DAYS,
        reserve + consumed * ASSIMILATION_EFFICIENCY
    )
    local bodyData = NS.context.safeModData(body)
    if bodyData ~= nil and (tonumber(bodyData.ExtinctionCorpseResource) or 0) <= 0.01 then
        detachZombieFromBody(zombie)
    end
end

local function addRainSupport(zombie, reserve, elapsedHours)
    local square = zombie and zombie:getSquare() or nil
    local intensity = liquidRainIntensity(square)
    if intensity <= 0 then return reserve end
    local maximumDailySupport = 1.20
    return reserve + intensity * maximumDailySupport * elapsedHours / HOURS_PER_DAY
end

local function systemicFailure(reserve, elapsedHours)
    if elapsedHours <= 0 then return false end
    local dailyRisk = 0.0002
    if reserve <= 0.25 then
        dailyRisk = 0.35
    elseif reserve <= 0.75 then
        dailyRisk = 0.08
    elseif reserve <= 1.50 then
        dailyRisk = 0.02
    elseif reserve <= 3.00 then
        dailyRisk = 0.003
    end
    local chance = 1 - math.exp(-dailyRisk * elapsedHours / HOURS_PER_DAY)
    return randomUnit() < chance
end

local function transmitReserveWhenNeeded(zombie, data)
    local reserve = tonumber(data.ExtinctionBiologicalReserve) or 0
    local last = tonumber(NS.lastReserveTransmit[zombie])
    if last == nil or math.abs(last - reserve) >= 0.05 or reserve <= 0 then
        NS.lastReserveTransmit[zombie] = reserve
        NS.context.transmitModData(zombie)
    end
end

local function updateZombieReserve(zombie, data, elapsedHours, currentHour)
    if elapsedHours <= 0 then return false end
    local reserve = tonumber(data.ExtinctionBiologicalReserve) or 0
    reserve = reserve - BASELINE_DAILY_DRAIN
        * zombieDrainMultiplier(zombie)
        * elapsedHours / HOURS_PER_DAY
    reserve = addRainSupport(zombie, reserve, elapsedHours)
    data.ExtinctionBiologicalReserve = reserve
    consumeFromCurrentTarget(zombie, data, elapsedHours, currentHour)
    reserve = clamp(tonumber(data.ExtinctionBiologicalReserve) or 0, 0, MAX_RESERVE_DAYS)
    data.ExtinctionBiologicalReserve = reserve
    return reserve <= 0 or systemicFailure(reserve, elapsedHours)
end

local function nearestLivingAnimal(zombie)
    if not animalHuntingEnabled() then return nil end
    local cell = getCell()
    if cell == nil or cell.getAnimals == nil then return nil end
    local animals = cell:getAnimals()
    if animals == nil then return nil end

    local x = zombie:getX()
    local y = zombie:getY()
    local z = math.floor(zombie:getZ())
    local best = nil
    local bestDistance = ANIMAL_SEARCH_RADIUS * ANIMAL_SEARCH_RADIUS + 1

    for index = 0, animals:size() - 1 do
        local animal = animals:get(index)
        if animal ~= nil and (animal.isDead == nil or not animal:isDead())
                and math.floor(animal:getZ()) == z then
            local dx = animal:getX() - x
            local dy = animal:getY() - y
            local distance = dx * dx + dy * dy
            if distance <= ANIMAL_SEARCH_RADIUS * ANIMAL_SEARCH_RADIUS
                    and distance < bestDistance then
                best = animal
                bestDistance = distance
            end
        end
    end
    return best
end

local function targetAnimal(zombie, animal)
    if zombie == nil or animal == nil then return end
    pcall(function() zombie:setTarget(animal) end)
    pcall(function() zombie:pathToCharacter(animal) end)
    if animal.getBehavior ~= nil then
        local ok, behavior = pcall(function() return animal:getBehavior() end)
        if ok and behavior ~= nil and behavior.forceFleeFromChr ~= nil then
            pcall(function() behavior:forceFleeFromChr(zombie) end)
        end
    end
end

local function chooseFoodIfHungry(zombie, data, currentHour)
    local reserve = tonumber(data.ExtinctionBiologicalReserve) or 0
    if reserve > HUNGER_RESERVE_DAYS then return end
    if zombie.getTarget ~= nil and zombie:getTarget() ~= nil then return end
    if zombie.isCrawling ~= nil and zombie:isCrawling() then return end
    if zombie.getEatBodyTarget ~= nil and zombie:getEatBodyTarget() ~= nil then return end

    local nextSearch = tonumber(NS.nextFoodSearch[zombie]) or 0
    if currentHour < nextSearch then return end
    NS.nextFoodSearch[zombie] = currentHour + FOOD_SEARCH_INTERVAL_HOURS

    local body = nearestEdibleBody(zombie, currentHour)
    if body ~= nil then
        pcall(function() zombie:setBodyToEat(body) end)
        return
    end

    local animal = nearestLivingAnimal(zombie)
    if animal ~= nil then targetAnimal(zombie, animal) end
end

local function sectorElapsedForZombie(zombie, currentHour, newlyInitialized)
    local key = sectorKeyFor(zombie)
    if key == nil then return 0, nil end
    local record = ensureSector(key, currentHour)
    if record == nil then return 0, key end
    if NS.batchHour == nil then return 0, key end

    local elapsed = NS.batchSectorElapsed[key]
    if elapsed == nil then
        elapsed = math.max(0, currentHour - (tonumber(record.lastHour) or currentHour))
        NS.batchSectorElapsed[key] = elapsed
    end
    if newlyInitialized then elapsed = 0 end
    return elapsed, key
end

local function recordSectorSample(key, reserve)
    if key == nil then return end
    local stats = NS.batchSectorStats[key]
    if stats == nil then
        stats = { count = 0, totalReserve = 0 }
        NS.batchSectorStats[key] = stats
    end
    stats.count = stats.count + 1
    stats.totalReserve = stats.totalReserve + math.max(0, reserve)
end

function NS.configure(context)
    NS.context = context
end

function NS.initGlobalData()
    ensureSectorRoot()
end

function NS.isEnabled()
    return naturalModeEnabled()
end

function NS.beginBatch()
    if NS.context == nil then return end
    NS.batchHour = NS.context.apocalypseAgeHours()
    NS.batchSectorElapsed = {}
    NS.batchSectorStats = {}
end

function NS.endBatch()
    if NS.batchHour == nil then return end
    local root = ensureSectorRoot()
    if root ~= nil then
        for key, _ in pairs(NS.batchSectorElapsed) do
            local record = ensureSector(key, NS.batchHour)
            if record ~= nil then
                local stats = NS.batchSectorStats[key]
                record.lastHour = NS.batchHour
                record.observedPopulation = stats and stats.count or 0
                if stats ~= nil and stats.count > 0 then
                    record.meanReserve = stats.totalReserve / stats.count
                else
                    record.meanReserve = 0
                end
            end
        end
        if NS.batchHour - NS.lastSectorTransmitHour >= 6 then
            NS.lastSectorTransmitHour = NS.batchHour
            if ModData ~= nil and ModData.transmit ~= nil
                    and type(isServer) == "function" and isServer() then
                pcall(function() ModData.transmit(SECTOR_DATA_KEY) end)
            end
        end
    end
    NS.batchHour = nil
    NS.batchSectorElapsed = {}
    NS.batchSectorStats = {}
end

function NS.trackBody(body)
    if not naturalModeEnabled() or NS.context == nil or not isEdibleBodyType(body) then
        return
    end
    addToIndex(body)
end

function NS.untrackBody(body)
    detachEaters(body)
    removeFromIndex(body)
end

function NS.markStarvationCorpse(body, sourceData, deathAgeHours)
    if body == nil or NS.context == nil then return end
    local data = NS.context.safeModData(body)
    if data == nil then return end
    local sourceReserve = tonumber(sourceData and sourceData.ExtinctionBiologicalReserve) or 0
    local residualFraction = 0.40
        + 0.10 * clamp(sourceReserve / MAX_RESERVE_DAYS, 0, 1)
    data.ExtinctionCorpseResource = HUMAN_CORPSE_RESOURCE
        * randomRange(0.70, 1.30)
        * residualFraction
    clearKeys(data, LEGACY_BODY_KEYS)
    NS.context.transmitModData(body)
    addToIndex(body)
end

function NS.processZombie(zombie)
    if zombie == nil or NS.context == nil or NS.context.belongsToProjectALife(zombie) then
        return
    end
    if zombie.isDead ~= nil and zombie:isDead() then return end
    local data = NS.context.safeModData(zombie)
    if data == nil then return end

    local currentHour = NS.batchHour or NS.context.apocalypseAgeHours()
    local newlyInitialized, historicalDeathHour = initializeZombieReserve(data, currentHour)
    if newlyInitialized then reconcileHistoricalFood(zombie, data, currentHour) end

    local elapsedHours, sectorKey = sectorElapsedForZombie(
        zombie,
        currentHour,
        newlyInitialized
    )
    local failed = updateZombieReserve(zombie, data, elapsedHours, currentHour)
    local reserve = tonumber(data.ExtinctionBiologicalReserve) or 0
    if reserve <= 0 then failed = true end

    if failed then
        local deathAgeHours = currentHour
        if newlyInitialized and reserve <= 0 then
            deathAgeHours = historicalDeathHour or currentHour
        end
        local body = NS.context.convertZombieToBody(zombie, deathAgeHours)
        if body ~= nil then NS.markStarvationCorpse(body, data, deathAgeHours) end
        return
    end

    transmitReserveWhenNeeded(zombie, data)
    recordSectorSample(sectorKey, reserve)
    chooseFoodIfHungry(zombie, data, currentHour)
end

function NS.processBodies()
    if not naturalModeEnabled() or NS.context == nil then return end
    local currentHour = NS.context.apocalypseAgeHours()
    local elapsedHours = 0
    if NS.lastBodyBatchHour ~= nil then
        elapsedHours = math.max(0, currentHour - NS.lastBodyBatchHour)
    end
    NS.lastBodyBatchHour = currentHour

    local bodies = {}
    for body, _ in pairs(NS.bodyChunkKeys) do bodies[#bodies + 1] = body end
    for _, body in ipairs(bodies) do
        if bodyIsPresent(body) and isEdibleBodyType(body) then
            local data = NS.context.safeModData(body)
            if data ~= nil and tonumber(data.ExtinctionCorpseResource) ~= nil then
                local remaining = capBodyResourceForAge(
                    body,
                    tonumber(data.ExtinctionCorpseResource) or 0,
                    currentHour
                )
                local rain = liquidRainIntensity(body:getSquare())
                if rain > 0 and elapsedHours > 0 then
                    local capacity = bodyIsAnimal(body)
                        and clamp(animalResourceFromBody(body) * 0.04, 0.02, 0.80)
                        or 0.40
                    remaining = remaining + rain * capacity
                        * math.min(elapsedHours / HOURS_PER_DAY, 1)
                end
                data.ExtinctionCorpseResource = math.max(0, remaining)
                NS.context.transmitModData(body)

                if data.ExtinctionCorpseResource <= 0.01 then
                    data.ExtinctionCorpseResource = 0
                    detachEaters(body)
                    if not bodyIsAnimal(body)
                            and NS.context.createSkeletonFromBody ~= nil then
                        NS.context.createSkeletonFromBody(body)
                    end
                end
            end
        else
            NS.untrackBody(body)
        end
    end
end

return NS

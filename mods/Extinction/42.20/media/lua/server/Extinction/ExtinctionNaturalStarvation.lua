Extinction = Extinction or {}

local NS = Extinction.NaturalStarvation or {}
Extinction.NaturalStarvation = NS

local HOURS_PER_DAY = 24
local BASE_CORPSE_CALORIES = 32000
local ASSIMILATION_EFFICIENCY = 0.70
local CONSUMPTION_PER_HOUR = 900
local HUNGER_RESERVE_DAYS = 3
local MAX_RESERVE_DAYS = 45
local FOOD_SEARCH_RADIUS = 10
local FOOD_SEARCH_INTERVAL_HOURS = 1

NS.bodyChunks = NS.bodyChunks or {}
NS.bodyChunkKeys = NS.bodyChunkKeys or {}
NS.context = NS.context or nil

local function randomUnit()
    return ZombRand(0, 1000001) / 1000000
end

local function randomRange(minimum, maximum)
    return minimum + randomUnit() * (maximum - minimum)
end

local function naturalModeEnabled()
    local group = SandboxVars and SandboxVars.Extinction
    return group ~= nil and group.NaturalStarvation == true
end

local function survivalDaysWithoutFood()
    local roll = ZombRand(0, 10000)
    if roll < 1500 then
        return randomRange(0.5, 3)
    elseif roll < 6500 then
        return randomRange(3, 14)
    elseif roll < 9300 then
        return randomRange(14, 30)
    end
    return randomRange(30, 55)
end

local function chunkKeyFor(object)
    if object == nil then return nil end
    local ok, x, y, z = pcall(function()
        return object:getX(), object:getY(), object:getZ()
    end)
    if not ok or x == nil or y == nil or z == nil then return nil end
    return math.floor(x / 10) .. ":" .. math.floor(y / 10) .. ":" .. math.floor(z)
end

local function bodyIsPresent(body)
    if body == nil then return false end
    local ok, index = pcall(function() return body:getStaticMovingObjectIndex() end)
    return ok and tonumber(index) ~= nil and index ~= -1
end

local function isEdibleBodyType(body)
    if body == nil or type(instanceof) ~= "function" or not instanceof(body, "IsoDeadBody") then
        return false
    end
    local animal = false
    local skeleton = false
    pcall(function() animal = body:isAnimal() end)
    pcall(function() skeleton = body:isSkeleton() end)
    return not animal and not skeleton
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
        bucket = {}
        NS.bodyChunks[key] = bucket
    end
    bucket[body] = true
    NS.bodyChunkKeys[body] = key
end

local function bodyTemperature(body)
    local square = body and body:getSquare() or nil
    if square ~= nil and type(getClimateManager) == "function" then
        local manager = getClimateManager()
        if manager ~= nil and manager.getAirTemperatureForSquare ~= nil then
            local ok, value = pcall(function() return manager:getAirTemperatureForSquare(square) end)
            if ok and tonumber(value) ~= nil then return tonumber(value) end
        end
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

local function ensureBodyFood(body, currentHour)
    if not isEdibleBodyType(body) then return nil end
    local context = NS.context
    if context == nil then return nil end
    local data = context.safeModData(body)
    if data == nil then return nil end

    if data.ExtinctionFoodInitialized ~= true then
        local bodyFactor = randomRange(0.70, 1.30)
        data.ExtinctionFoodInitialized = true
        data.ExtinctionBodyFactor = bodyFactor
        data.ExtinctionFoodInitialKcal = BASE_CORPSE_CALORIES * bodyFactor
        data.ExtinctionFoodKcal = data.ExtinctionFoodInitialKcal
        data.ExtinctionFoodLastHour = context.bodyDeathAgeHours(body)
        context.transmitModData(body)
    end

    local remaining = math.max(0, tonumber(data.ExtinctionFoodKcal) or 0)
    local lastHour = tonumber(data.ExtinctionFoodLastHour) or currentHour
    local elapsedHours = math.max(0, currentHour - lastHour)
    if elapsedHours > 0 and remaining > 0 then
        local decayRate = dailyDecayFraction(bodyTemperature(body))
        remaining = remaining * math.exp(-decayRate * elapsedHours / HOURS_PER_DAY)
        data.ExtinctionFoodKcal = remaining
        data.ExtinctionFoodLastHour = currentHour
        if remaining <= 0.5 then
            data.ExtinctionFoodKcal = 0
            detachEaters(body)
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
    local data = ensureBodyFood(body, currentHour)
    if data == nil or (tonumber(data.ExtinctionFoodKcal) or 0) <= 0 then return false end
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
                        if distance <= FOOD_SEARCH_RADIUS * FOOD_SEARCH_RADIUS and distance < bestDistance then
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

local function takeCaloriesFromBody(body, requestedCalories, currentHour)
    if requestedCalories <= 0 then return 0 end
    local bodyData = ensureBodyFood(body, currentHour)
    if bodyData == nil then return 0 end
    local remaining = tonumber(bodyData.ExtinctionFoodKcal) or 0
    local consumed = math.min(remaining, requestedCalories)
    if consumed <= 0 then return 0 end

    bodyData.ExtinctionFoodKcal = remaining - consumed
    NS.context.transmitModData(body)
    if bodyData.ExtinctionFoodKcal <= 0.5 then
        bodyData.ExtinctionFoodKcal = 0
        detachEaters(body)
    end
    return consumed
end

local function initializeZombieEnergy(zombie, data, currentHour)
    if data.ExtinctionNaturalInitialized == true then return false end
    local dailyNeed = randomRange(2000, 3200)
    local survivalDays = survivalDaysWithoutFood()
    local initialEnergy = dailyNeed * survivalDays
    local spentSinceApocalypse = dailyNeed * currentHour / HOURS_PER_DAY

    data.ExtinctionNaturalInitialized = true
    data.ExtinctionNaturalDailyNeedKcal = dailyNeed
    data.ExtinctionNaturalBodyFactor = randomRange(0.70, 1.30)
    data.ExtinctionNaturalInitialKcal = initialEnergy
    data.ExtinctionNaturalEnergyKcal = initialEnergy - spentSinceApocalypse
    data.ExtinctionNaturalLastHour = currentHour
    data.ExtinctionNaturalNoFoodDeathAgeHours = survivalDays * HOURS_PER_DAY
    data.ExtinctionNaturalHistoricalDeathAgeHours = survivalDays * HOURS_PER_DAY
    data.ExtinctionNaturalNextFoodSearchHour = currentHour
    data.ExtinctionNaturalConsumedFood = false
    data.ExtinctionVersion = 3
    NS.context.transmitModData(zombie)
    return true
end

local function reconcileHistoricalFood(zombie, data, currentHour)
    local energy = tonumber(data.ExtinctionNaturalEnergyKcal) or 0
    if energy > 0 then return end
    local dailyNeed = tonumber(data.ExtinctionNaturalDailyNeedKcal) or 2500
    local reserveGoal = dailyNeed * randomRange(0.25, HUNGER_RESERVE_DAYS)
    local requiredAssimilated = -energy + reserveGoal
    local bodiesUsed = 0

    while requiredAssimilated > 0 and bodiesUsed < 8 do
        local body = nearestEdibleBody(zombie, currentHour)
        if body == nil then break end
        local rawNeeded = requiredAssimilated / ASSIMILATION_EFFICIENCY
        local consumed = takeCaloriesFromBody(body, rawNeeded, currentHour)
        if consumed <= 0 then break end

        local assimilated = consumed * ASSIMILATION_EFFICIENCY
        energy = energy + assimilated
        requiredAssimilated = math.max(0, requiredAssimilated - assimilated)
        data.ExtinctionNaturalConsumedFood = true
        data.ExtinctionNaturalHistoricalDeathAgeHours =
            (tonumber(data.ExtinctionNaturalHistoricalDeathAgeHours) or 0)
            + assimilated / dailyNeed * HOURS_PER_DAY
        bodiesUsed = bodiesUsed + 1
    end
    data.ExtinctionNaturalEnergyKcal = energy
end

local function consumeFromCurrentTarget(zombie, data, elapsedHours, currentHour)
    if elapsedHours <= 0 or zombie.getEatBodyTarget == nil then return end
    local ok, body = pcall(function() return zombie:getEatBodyTarget() end)
    if not ok or body == nil or not isEdibleBodyType(body) then return end
    if not bodyCanFeedZombie(body, zombie, currentHour) then
        detachEaters(body)
        return
    end

    local consumed = takeCaloriesFromBody(body, CONSUMPTION_PER_HOUR * elapsedHours, currentHour)
    if consumed <= 0 then return end

    data.ExtinctionNaturalEnergyKcal = (tonumber(data.ExtinctionNaturalEnergyKcal) or 0)
        + consumed * ASSIMILATION_EFFICIENCY
    data.ExtinctionNaturalConsumedFood = true
end

local function updateZombieEnergy(zombie, data, currentHour)
    local lastHour = tonumber(data.ExtinctionNaturalLastHour) or currentHour
    local elapsedHours = math.max(0, currentHour - lastHour)
    if elapsedHours <= 0 then return end

    local dailyNeed = tonumber(data.ExtinctionNaturalDailyNeedKcal) or 2500
    local energy = tonumber(data.ExtinctionNaturalEnergyKcal) or 0
    data.ExtinctionNaturalEnergyKcal = math.max(0, energy - dailyNeed * elapsedHours / HOURS_PER_DAY)
    consumeFromCurrentTarget(zombie, data, elapsedHours, currentHour)
    data.ExtinctionNaturalEnergyKcal = math.min(
        tonumber(data.ExtinctionNaturalEnergyKcal) or 0,
        dailyNeed * MAX_RESERVE_DAYS
    )
    data.ExtinctionNaturalLastHour = currentHour
end

local function chooseFoodIfHungry(zombie, data, currentHour)
    local dailyNeed = tonumber(data.ExtinctionNaturalDailyNeedKcal) or 2500
    local energy = tonumber(data.ExtinctionNaturalEnergyKcal) or 0
    if energy > dailyNeed * HUNGER_RESERVE_DAYS then return end
    if zombie.getTarget ~= nil and zombie:getTarget() ~= nil then return end
    if zombie.isCrawling ~= nil and zombie:isCrawling() then return end
    if zombie.getEatBodyTarget ~= nil and zombie:getEatBodyTarget() ~= nil then return end

    local nextSearch = tonumber(data.ExtinctionNaturalNextFoodSearchHour) or 0
    if currentHour < nextSearch then return end
    data.ExtinctionNaturalNextFoodSearchHour = currentHour + FOOD_SEARCH_INTERVAL_HOURS

    local body = nearestEdibleBody(zombie, currentHour)
    if body ~= nil then
        pcall(function() zombie:setBodyToEat(body) end)
    end
end

function NS.configure(context)
    NS.context = context
end

function NS.isEnabled()
    return naturalModeEnabled()
end

function NS.trackBody(body)
    if not naturalModeEnabled() or NS.context == nil or not isEdibleBodyType(body) then return end
    addToIndex(body)
    ensureBodyFood(body, NS.context.apocalypseAgeHours())
end

function NS.untrackBody(body)
    detachEaters(body)
    removeFromIndex(body)
end

function NS.markStarvationCorpse(body, sourceData, deathAgeHours)
    if body == nil then return end
    local data = NS.context.safeModData(body)
    if data == nil then return end
    local bodyFactor = tonumber(sourceData.ExtinctionNaturalBodyFactor)
    if bodyFactor == nil then bodyFactor = randomRange(0.70, 1.30) end
    local starvationFraction = randomRange(0.40, 0.70)
    data.ExtinctionFoodInitialized = true
    data.ExtinctionBodyFactor = bodyFactor
    data.ExtinctionFoodInitialKcal = BASE_CORPSE_CALORIES * bodyFactor * starvationFraction
    data.ExtinctionFoodKcal = data.ExtinctionFoodInitialKcal
    data.ExtinctionFoodLastHour = deathAgeHours
    data.ExtinctionStarvationCorpse = true
    NS.context.transmitModData(body)
    NS.trackBody(body)
end

function NS.processZombie(zombie)
    if zombie == nil or NS.context == nil or NS.context.belongsToProjectALife(zombie) then return end
    if zombie.isDead ~= nil and zombie:isDead() then return end
    local data = NS.context.safeModData(zombie)
    if data == nil then return end

    local currentHour = NS.context.apocalypseAgeHours()
    local newlyInitialized = initializeZombieEnergy(zombie, data, currentHour)
    if newlyInitialized then reconcileHistoricalFood(zombie, data, currentHour) end
    updateZombieEnergy(zombie, data, currentHour)

    if (tonumber(data.ExtinctionNaturalEnergyKcal) or 0) <= 0 then
        local deathAgeHours = currentHour
        if newlyInitialized then
            deathAgeHours = math.min(currentHour, tonumber(
                data.ExtinctionNaturalHistoricalDeathAgeHours
            ) or currentHour)
        end
        local body = NS.context.convertZombieToBody(zombie, deathAgeHours)
        if body ~= nil then NS.markStarvationCorpse(body, data, deathAgeHours) end
        return
    end

    chooseFoodIfHungry(zombie, data, currentHour)
end

function NS.processBodies()
    if not naturalModeEnabled() or NS.context == nil then return end
    local currentHour = NS.context.apocalypseAgeHours()
    local bodies = {}
    for body, _ in pairs(NS.bodyChunkKeys) do bodies[#bodies + 1] = body end
    for _, body in ipairs(bodies) do
        if bodyIsPresent(body) and isEdibleBodyType(body) then
            ensureBodyFood(body, currentHour)
        else
            NS.untrackBody(body)
        end
    end
end

return NS

ExtinctionTestTools = ExtinctionTestTools or {}

local Tools = ExtinctionTestTools
local OVERLAY_RANGE = 20
local OVERLAY_RANGE_SQUARED = OVERLAY_RANGE * OVERLAY_RANGE
local CORPSE_SCAN_INTERVAL_TICKS = 60
local ASSIMILATION_EFFICIENCY = 0.70
local HOURS_PER_DAY = 24
local DAYS_PER_MONTH = 30
local DEFAULT_SKELETONIZATION_DAYS = 180

Tools.trackedBodies = Tools.trackedBodies
    or setmetatable({}, { __mode = "k" })
Tools.corpseScanTicks = Tools.corpseScanTicks or 0

local function optionEnabled(name)
    local group = SandboxVars and SandboxVars.Extinction
    return group ~= nil and group[name] == true
end

local function optionNumber(name, fallback)
    local group = SandboxVars and SandboxVars.Extinction
    local value = group and tonumber(group[name]) or nil
    if value == nil then return fallback end
    return math.max(0, value)
end

local function apocalypseOffsetHours()
    local timeSinceApo = SandboxVars and tonumber(SandboxVars.TimeSinceApo) or 1
    return math.max(0, (timeSinceApo or 1) - 1)
        * DAYS_PER_MONTH * HOURS_PER_DAY
end

local function apocalypseAgeHours()
    local gameTime = getGameTime()
    local worldAge = gameTime and tonumber(gameTime:getWorldAgeHours()) or 0
    return worldAge + apocalypseOffsetHours()
end

local function bodyDeathAgeHours(body)
    local data = body and body:getModData() or nil
    local marked = data and tonumber(data.ExtinctionDeathAgeHours) or nil
    if marked ~= nil then return marked end
    local deathTime = nil
    if body ~= nil and body.getDeathTime ~= nil then
        pcall(function() deathTime = tonumber(body:getDeathTime()) end)
    end
    if deathTime ~= nil and deathTime ~= -1 then
        return deathTime + apocalypseOffsetHours()
    end
    return apocalypseAgeHours()
end

local function skeletonizationStatus(body, resource)
    if resource ~= nil and resource <= 0.01 then return "skeleton now" end
    local delayDays = optionNumber(
        "SkeletonizationDays",
        DEFAULT_SKELETONIZATION_DAYS
    )
    if delayDays <= 0 then return "skeleton disabled" end
    local remaining = bodyDeathAgeHours(body)
        + delayDays * HOURS_PER_DAY
        - apocalypseAgeHours()
    if remaining <= 0 then return "skeleton now" end
    local totalHours = math.ceil(remaining)
    local days = math.floor(totalHours / HOURS_PER_DAY)
    local hours = totalHours % HOURS_PER_DAY
    if days > 0 then
        return string.format("skeleton in %dd %dh", days, hours)
    end
    return string.format("skeleton in %dh", hours)
end

local function bodyIsPresent(body)
    if body == nil then return false end
    local ok, index = pcall(function()
        return body:getStaticMovingObjectIndex()
    end)
    return ok and tonumber(index) ~= nil and index ~= -1
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

local function trackBody(body)
    if body == nil or type(instanceof) ~= "function"
            or not instanceof(body, "IsoDeadBody") or bodyIsSkeleton(body) then
        return
    end
    Tools.trackedBodies[body] = true
end

local function trackSquare(square)
    if square == nil then return end
    local objects = square:getStaticMovingObjects()
    if objects == nil then return end
    for index = 0, objects:size() - 1 do
        trackBody(objects:get(index))
    end
end

local function refreshNearbyBodies()
    if not optionEnabled("NaturalStarvation")
            or not optionEnabled("TestShowCorpseNutrition") then
        Tools.corpseScanTicks = 0
        return
    end

    Tools.corpseScanTicks = Tools.corpseScanTicks + 1
    if Tools.corpseScanTicks < CORPSE_SCAN_INTERVAL_TICKS then return end
    Tools.corpseScanTicks = 0

    local player = getSpecificPlayer(0)
    local cell = getCell()
    if player == nil or cell == nil then return end
    local centreX = math.floor(player:getX())
    local centreY = math.floor(player:getY())
    local z = math.floor(player:getZ())
    for x = centreX - OVERLAY_RANGE, centreX + OVERLAY_RANGE do
        for y = centreY - OVERLAY_RANGE, centreY + OVERLAY_RANGE do
            trackSquare(cell:getGridSquare(x, y, z))
        end
    end
end

local function rainSupports(zombie)
    local square = zombie and zombie:getSquare() or nil
    if square == nil or square.isOutside == nil or not square:isOutside() then return false end
    if type(getClimateManager) ~= "function" then return false end
    local manager = getClimateManager()
    if manager == nil or not manager:isRaining() then return false end
    return not manager:getPrecipitationIsSnow()
end

local function stateForZombie(zombie, reserve)
    if zombie.getEatBodyTarget ~= nil and zombie:getEatBodyTarget() ~= nil then
        return "Feeding"
    end
    if reserve <= 0.25 then return "Failing" end
    if reserve <= 1.50 then return "Critical" end
    if reserve <= 4.00 then return "Hungry" end
    if rainSupports(zombie) then return "Rain-supported" end
    return "Stable"
end

local function drawZombieLabel(playerIndex, player, zombie, reserve)
    local dx = zombie:getX() - player:getX()
    local dy = zombie:getY() - player:getY()
    if dx * dx + dy * dy > OVERLAY_RANGE_SQUARED then return end
    if math.floor(zombie:getZ()) ~= math.floor(player:getZ()) then return end

    local screenX = isoToScreenX(
        playerIndex,
        zombie:getX(),
        zombie:getY(),
        zombie:getZ()
    )
    local screenY = isoToScreenY(
        playerIndex,
        zombie:getX(),
        zombie:getY(),
        zombie:getZ() + 0.70
    )
    local width = getCore():getScreenWidth()
    local height = getCore():getScreenHeight()
    if screenX < 0 or screenY < 0 or screenX > width or screenY > height then return end

    local days = math.max(0, math.floor(reserve + 0.5))
    local state = stateForZombie(zombie, reserve)
    local text = string.format("Reserve %.2f | ~%d days | %s", reserve, days, state)
    local manager = getTextManager()
    manager:DrawStringCentre(UIFont.Small, screenX + 1, screenY + 1, text, 0, 0, 0, 0.90)
    manager:DrawStringCentre(UIFont.Small, screenX, screenY, text, 0.85, 1.0, 0.85, 1.0)
end

local function drawBiologicalOverlay()
    if not optionEnabled("NaturalStarvation")
            or not optionEnabled("TestShowBiologicalState") then
        return
    end

    local playerIndex = 0
    local player = getSpecificPlayer(playerIndex)
    if player == nil then return end
    local cell = getCell()
    if cell == nil then return end
    local zombies = cell:getZombieList()
    if zombies == nil then return end

    for index = 0, zombies:size() - 1 do
        local zombie = zombies:get(index)
        if zombie ~= nil and (zombie.isDead == nil or not zombie:isDead()) then
            local data = zombie:getModData()
            local reserve = data and tonumber(data.ExtinctionBiologicalReserve) or nil
            if reserve ~= nil then
                drawZombieLabel(playerIndex, player, zombie, reserve)
            end
        end
    end
end

local function drawCorpseLabel(playerIndex, player, body, resource)
    local dx = body:getX() - player:getX()
    local dy = body:getY() - player:getY()
    if dx * dx + dy * dy > OVERLAY_RANGE_SQUARED then return end
    if math.floor(body:getZ()) ~= math.floor(player:getZ()) then return end

    local screenX = isoToScreenX(
        playerIndex,
        body:getX(),
        body:getY(),
        body:getZ()
    )
    local screenY = isoToScreenY(
        playerIndex,
        body:getX(),
        body:getY(),
        body:getZ() + 0.25
    )
    local width = getCore():getScreenWidth()
    local height = getCore():getScreenHeight()
    if screenX < 0 or screenY < 0 or screenX > width or screenY > height then return end

    local kind = "Human"
    if body.isAnimal ~= nil and body:isAnimal() then kind = "Animal" end
    local text
    local r, g, b = 1.0, 0.82, 0.35
    if resource == nil then
        text = kind .. " corpse | nutrition pending"
        r, g, b = 0.75, 0.75, 0.75
    elseif resource <= 0.01 then
        text = kind .. " corpse | depleted"
        r, g, b = 1.0, 0.30, 0.20
    else
        text = string.format(
            "%s corpse | raw %.2fd | usable %.2fd",
            kind,
            resource,
            resource * ASSIMILATION_EFFICIENCY
        )
    end

    local skeletonText = skeletonizationStatus(body, resource)
    local manager = getTextManager()
    manager:DrawStringCentre(UIFont.Small, screenX + 1, screenY + 1, text, 0, 0, 0, 0.90)
    manager:DrawStringCentre(UIFont.Small, screenX, screenY, text, r, g, b, 1.0)
    manager:DrawStringCentre(UIFont.Small, screenX + 1, screenY + 13, skeletonText, 0, 0, 0, 0.90)
    manager:DrawStringCentre(UIFont.Small, screenX, screenY + 12, skeletonText, 0.65, 0.85, 1.0, 1.0)
end

local function drawCorpseNutritionOverlay()
    if not optionEnabled("NaturalStarvation")
            or not optionEnabled("TestShowCorpseNutrition") then
        return
    end

    local playerIndex = 0
    local player = getSpecificPlayer(playerIndex)
    if player == nil then return end
    for body, _ in pairs(Tools.trackedBodies) do
        if not bodyIsPresent(body) or bodyIsSkeleton(body) then
            Tools.trackedBodies[body] = nil
        else
            local data = body:getModData()
            local resource = data
                and tonumber(data.ExtinctionCorpseResource) or nil
            drawCorpseLabel(playerIndex, player, body, resource)
        end
    end
end

local function onGameExit()
    Tools.trackedBodies = setmetatable({}, { __mode = "k" })
    Tools.corpseScanTicks = 0
end

Events.OnObjectAdded.Add(trackBody)
Events.OnDeadBodySpawn.Add(trackBody)
Events.LoadGridsquare.Add(trackSquare)
Events.OnTick.Add(refreshNearbyBodies)
Events.OnPostUIDraw.Add(drawBiologicalOverlay)
Events.OnPostUIDraw.Add(drawCorpseNutritionOverlay)
if Events.OnGameExit ~= nil then Events.OnGameExit.Add(onGameExit) end

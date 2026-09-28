ExtinctionTestTools = ExtinctionTestTools or {}

local Tools = ExtinctionTestTools
local OVERLAY_RANGE = 20
local OVERLAY_RANGE_SQUARED = OVERLAY_RANGE * OVERLAY_RANGE

Tools.protectedPlayers = Tools.protectedPlayers or setmetatable({}, { __mode = "k" })
Tools.pendingZombies = Tools.pendingZombies or setmetatable({}, { __mode = "k" })
Tools.ignoreStatus = Tools.ignoreStatus or {
    active = false,
    logged = false,
    suppressed = 0,
}

local function optionEnabled(name)
    local group = SandboxVars and SandboxVars.Extinction
    return group ~= nil and group[name] == true
end

local function protectedPlayers()
    local protected = {}
    local hasProtectedPlayer = false
    if not optionEnabled("TestIgnorePlayer") then
        Tools.protectedPlayers = protected
        Tools.ignoreStatus.active = false
        Tools.ignoreStatus.logged = false
        return protected, false
    end

    local count = 1
    if type(getNumActivePlayers) == "function" then
        local ok, value = pcall(getNumActivePlayers)
        if ok and tonumber(value) ~= nil then count = math.max(1, tonumber(value)) end
    end
    for playerIndex = 0, count - 1 do
        local player = getSpecificPlayer(playerIndex)
        if player ~= nil then
            protected[player] = true
            hasProtectedPlayer = true
        end
    end

    Tools.protectedPlayers = protected
    Tools.ignoreStatus.active = hasProtectedPlayer
    if hasProtectedPlayer and not Tools.ignoreStatus.logged then
        print("[Extinction] TestIgnorePlayer ACTIVE: direct zombie target suppression")
        Tools.ignoreStatus.logged = true
    end
    return protected, hasProtectedPlayer
end

local function isProtectedPlayer(character)
    if character == nil or not optionEnabled("TestIgnorePlayer") then return false end
    local protected, _ = protectedPlayers()
    return protected[character] == true
end

local function zombieAggressor(zombie)
    local ok, attacker = pcall(function() return zombie:getAttackedBy() end)
    if ok then return attacker end
    return nil
end

local function clearZombieAggression(zombie)
    pcall(function() zombie:setTarget(nil) end)
    pcall(function() zombie:setAttackedBy(nil) end)
    pcall(function() zombie:clearAggroList() end)
    pcall(function() zombie:setTargetSeenTime(0) end)
    pcall(function() zombie:setPath2(nil) end)
    pcall(function() zombie:Wander() end)
    Tools.ignoreStatus.suppressed = Tools.ignoreStatus.suppressed + 1
end

local function clearIfThreateningTester(zombie, protected, force)
    if zombie == nil then return end
    local target = zombie:getTarget()
    local attacker = zombieAggressor(zombie)
    if force or protected[target] == true or protected[attacker] == true then
        clearZombieAggression(zombie)
    end
end

local function enforceZombieIgnore()
    local protected, hasProtectedPlayer = protectedPlayers()
    if not hasProtectedPlayer then return end
    local cell = getCell()
    local zombies = cell and cell:getZombieList() or nil
    if zombies == nil then return end

    for index = 0, zombies:size() - 1 do
        local zombie = zombies:get(index)
        if zombie ~= nil then
            local force = Tools.pendingZombies[zombie] == true
            clearIfThreateningTester(zombie, protected, force)
            Tools.pendingZombies[zombie] = nil
        end
    end
end

local function onZombieUpdate(zombie)
    if not Tools.ignoreStatus.active or zombie == nil then return end
    local force = Tools.pendingZombies[zombie] == true
    clearIfThreateningTester(zombie, Tools.protectedPlayers, force)
    Tools.pendingZombies[zombie] = nil
end

local function onHitZombie(zombie, wielder)
    if zombie == nil or not isProtectedPlayer(wielder) then return end
    Tools.pendingZombies[zombie] = true
end

local function onWeaponHitCharacter(attacker, target)
    if target == nil or not isProtectedPlayer(attacker) then return end
    if type(instanceof) == "function" and instanceof(target, "IsoZombie") then
        Tools.pendingZombies[target] = true
    end
end

local function drawIgnoreStatus()
    if not optionEnabled("TestIgnorePlayer") then return end
    local text
    local r, g, b
    if Tools.ignoreStatus.active then
        text = string.format(
            "EXTINCTION TEST SHIELD: ACTIVE | aggression cancelled: %d",
            Tools.ignoreStatus.suppressed
        )
        r, g, b = 0.25, 1.0, 0.25
    else
        text = "EXTINCTION TEST SHIELD: ERROR - no protected local player"
        r, g, b = 1.0, 0.2, 0.2
    end
    getTextManager():DrawStringCentre(
        UIFont.Small,
        getCore():getScreenWidth() / 2,
        24,
        text,
        r,
        g,
        b,
        1.0
    )
end

local function onGameExit()
    Tools.protectedPlayers = setmetatable({}, { __mode = "k" })
    Tools.pendingZombies = setmetatable({}, { __mode = "k" })
    Tools.ignoreStatus.active = false
    Tools.ignoreStatus.logged = false
    Tools.ignoreStatus.suppressed = 0
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

Events.OnGameStart.Add(enforceZombieIgnore)
Events.OnTick.Add(enforceZombieIgnore)
Events.OnPlayerUpdate.Add(enforceZombieIgnore)
Events.OnZombieUpdate.Add(onZombieUpdate)
Events.OnHitZombie.Add(onHitZombie)
Events.OnWeaponHitCharacter.Add(onWeaponHitCharacter)
Events.OnPostUIDraw.Add(drawIgnoreStatus)
Events.OnPostUIDraw.Add(drawBiologicalOverlay)
if Events.OnGameExit ~= nil then Events.OnGameExit.Add(onGameExit) end

ExtinctionTestTools = ExtinctionTestTools or {}

local Tools = ExtinctionTestTools
local OVERLAY_RANGE = 20
local OVERLAY_RANGE_SQUARED = OVERLAY_RANGE * OVERLAY_RANGE

Tools.playerState = Tools.playerState or setmetatable({}, { __mode = "k" })

local function optionEnabled(name)
    local group = SandboxVars and SandboxVars.Extinction
    return group ~= nil and group[name] == true
end

local function isMultiplayerClient()
    return type(isClient) == "function" and isClient()
end

local function isEligibleTester(player)
    if player == nil then return false end
    if not isMultiplayerClient() then return true end

    local accessLevel = ""
    if player.getAccessLevel ~= nil then
        pcall(function() accessLevel = string.lower(tostring(player:getAccessLevel() or "")) end)
    end
    return accessLevel ~= "" and accessLevel ~= "none"
end

local function isGhostMode(player)
    local ok, value = pcall(function() return player:isGhostMode() end)
    return ok and value == true
end

local function restoreIgnoreState(player)
    local state = Tools.playerState[player]
    if state == nil or state.applied ~= true then return end
    if state.changedByExtinction == true and isGhostMode(player) then
        pcall(function() player:setGhostMode(false) end)
    end
    Tools.playerState[player] = nil
end

local function updateIgnoreState(player)
    if player == nil then return end
    local enabled = optionEnabled("TestIgnorePlayer") and isEligibleTester(player)
    local state = Tools.playerState[player]

    if enabled then
        if state == nil or state.applied ~= true then
            local alreadyGhost = isGhostMode(player)
            Tools.playerState[player] = {
                applied = true,
                changedByExtinction = not alreadyGhost,
            }
        end
        pcall(function() player:setGhostMode(true) end)
    else
        restoreIgnoreState(player)
    end
end

local function protectedPlayers()
    local protected = {}
    local count = 1
    if type(getNumActivePlayers) == "function" then
        local ok, value = pcall(getNumActivePlayers)
        if ok and tonumber(value) ~= nil then count = math.max(1, tonumber(value)) end
    end
    for playerIndex = 0, count - 1 do
        local player = getSpecificPlayer(playerIndex)
        if player ~= nil then
            updateIgnoreState(player)
            if optionEnabled("TestIgnorePlayer") and isEligibleTester(player) then
                protected[player] = true
            end
        end
    end
    return protected
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
end

local function enforceZombieIgnore()
    local protected = protectedPlayers()
    if next(protected) == nil then return end

    local cell = getCell()
    local zombies = cell and cell:getZombieList() or nil
    if zombies == nil then return end

    for index = 0, zombies:size() - 1 do
        local zombie = zombies:get(index)
        if zombie ~= nil then
            local target = zombie:getTarget()
            local attacker = zombieAggressor(zombie)
            if protected[target] == true or protected[attacker] == true then
                clearZombieAggression(zombie)
            end
        end
    end
end

local function onCreatePlayer(_, player)
    updateIgnoreState(player)
end

local function onGameExit()
    for player, _ in pairs(Tools.playerState) do
        restoreIgnoreState(player)
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
    if player == nil or not isEligibleTester(player) then return end
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

Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnGameStart.Add(enforceZombieIgnore)
Events.OnTick.Add(enforceZombieIgnore)
Events.OnPostUIDraw.Add(drawBiologicalOverlay)
if Events.OnGameExit ~= nil then Events.OnGameExit.Add(onGameExit) end

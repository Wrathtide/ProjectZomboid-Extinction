ExtinctionTestTools = ExtinctionTestTools or {}

local OVERLAY_RANGE = 20
local OVERLAY_RANGE_SQUARED = OVERLAY_RANGE * OVERLAY_RANGE

local function optionEnabled(name)
    local group = SandboxVars and SandboxVars.Extinction
    return group ~= nil and group[name] == true
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

Events.OnPostUIDraw.Add(drawBiologicalOverlay)

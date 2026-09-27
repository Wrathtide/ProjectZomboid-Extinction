Extinction = Extinction or {}

local QE = Extinction
local HOURS_PER_DAY = 24
local DAYS_PER_MONTH = 30
local DEFAULT_EXTINCTION_DAYS = 21
local DEFAULT_SKELETONIZATION_DAYS = 180
local PENDING_DELAY_TICKS = 2
local FULL_SCAN_INTERVAL_TICKS = 300
local MAX_PENDING_PER_TICK = 128

QE.pendingZombies = QE.pendingZombies or {}
QE.trackedBodies = QE.trackedBodies or {}
QE.tickNumber = QE.tickNumber or 0
QE.lastFullScanTick = QE.lastFullScanTick or 0

local function worldAgeHours()
    local gameTime = getGameTime()
    if gameTime == nil then return 0 end
    return tonumber(gameTime:getWorldAgeHours()) or 0
end

local function apocalypseOffsetHours()
    local timeSinceApo = SandboxVars and tonumber(SandboxVars.TimeSinceApo) or nil
    if type(getSandboxOptions) == "function" then
        local options = getSandboxOptions()
        if options ~= nil and options.getTimeSinceApo ~= nil then
            local ok, value = pcall(function() return options:getTimeSinceApo() end)
            if ok and tonumber(value) ~= nil then timeSinceApo = tonumber(value) end
        end
    end
    local elapsedMonths = math.max(0, (timeSinceApo or 1) - 1)
    return elapsedMonths * DAYS_PER_MONTH * HOURS_PER_DAY
end

local function apocalypseAgeHours()
    return worldAgeHours() + apocalypseOffsetHours()
end

local function apocalypseAgeToWorldAge(deathAgeHours)
    return deathAgeHours - apocalypseOffsetHours()
end

local function optionNumber(name, fallback)
    local group = SandboxVars and SandboxVars.Extinction
    local value = group and tonumber(group[name]) or nil
    if value == nil then return fallback end
    return math.max(0, value)
end

local function extinctionHours()
    return optionNumber("ExtinctionDays", DEFAULT_EXTINCTION_DAYS) * HOURS_PER_DAY
end

local function skeletonizationHours()
    return optionNumber("SkeletonizationDays", DEFAULT_SKELETONIZATION_DAYS) * HOURS_PER_DAY
end

local function randomDeathAgeHours()
    local finalHour = extinctionHours()
    if finalHour <= 0 then return 0 end
    return (ZombRand(0, 1000001) / 1000000) * finalHour
end

local function safeModData(object)
    if object == nil or object.getModData == nil then return nil end
    local ok, data = pcall(function() return object:getModData() end)
    if not ok or type(data) ~= "table" then return nil end
    return data
end

local function variableText(character, name)
    if character == nil or character.GetVariable == nil then return nil end
    local ok, value = pcall(function() return character:GetVariable(name) end)
    if not ok or value == nil then return nil end
    return tostring(value)
end

local function belongsToProjectALife(character)
    local data = safeModData(character)
    if data ~= nil and (data.ProjectALifeOwned == true or data.ProjectALifeActor == true) then
        return true
    end

    local actor = variableText(character, "ALifeActor")
    if actor == "true" or actor == "1" then return true end
    local uid = variableText(character, "ALifeUID")
    return uid ~= nil and uid ~= ""
end

local function transmitModData(object)
    if object == nil or object.transmitModData == nil then return end
    pcall(function() object:transmitModData() end)
end

local function sendNewCorpse(body)
    if body == nil or type(isServer) ~= "function" or not isServer() then return end
    if type(sendCorpse) == "function" then
        pcall(function() sendCorpse(body) end)
    end
end

local function trackBody(body)
    if body == nil or type(instanceof) ~= "function" or not instanceof(body, "IsoDeadBody") then
        return
    end
    if body.isAnimal ~= nil and body:isAnimal() then return end
    if body.isPlayer ~= nil and body:isPlayer() then return end
    if belongsToProjectALife(body) then return end
    if body.isZombie ~= nil and not body:isZombie() then return end
    local skeleton = false
    pcall(function() skeleton = body:isSkeleton() end)
    if skeleton then return end
    QE.trackedBodies[body] = true
end

local function prepareAmbientBody(body, deathAgeHours)
    if body == nil then return nil end
    local data = safeModData(body)
    if data == nil then return body end

    data.ExtinctionManagedCorpse = true
    data.ExtinctionAmbientCorpse = true
    data.ExtinctionDeathAgeHours = deathAgeHours
    data.ExtinctionSkeletonized = nil
    pcall(function() body:setDeathTime(apocalypseAgeToWorldAge(deathAgeHours)) end)
    pcall(function() body:setFakeDead(false) end)
    pcall(function() body:setReanimateTime(-1) end)
    pcall(function() body:setKilledBy(nil) end)
    transmitModData(body)
    trackBody(body)
    return body
end

local function convertZombieToBody(zombie, deathAgeHours)
    if zombie == nil or belongsToProjectALife(zombie) then return nil end
    local square = zombie:getCurrentSquare()
    if square == nil and zombie.getSquare ~= nil then square = zombie:getSquare() end
    if square == nil then return nil end

    pcall(function() zombie:setFakeDead(false) end)
    pcall(function() zombie:setForceFakeDead(false) end)
    pcall(function() zombie:setReanimate(false) end)
    pcall(function() zombie:setTarget(nil) end)
    pcall(function() zombie:setAttackedBy(nil) end)

    local ok, body = pcall(function() return square:createCorpse(zombie, false) end)
    if not ok or body == nil then return nil end
    prepareAmbientBody(body, deathAgeHours)
    sendNewCorpse(body)
    return body
end

local function processZombie(zombie)
    if zombie == nil or belongsToProjectALife(zombie) then return end
    if zombie.isDead ~= nil and zombie:isDead() then return end
    local data = safeModData(zombie)
    if data == nil then return end

    local deathAgeHours = tonumber(data.ExtinctionDeathAgeHours)
    if deathAgeHours == nil then
        deathAgeHours = randomDeathAgeHours()
        data.ExtinctionDeathAgeHours = deathAgeHours
        data.ExtinctionVersion = 2
        transmitModData(zombie)
    end

    if apocalypseAgeHours() >= deathAgeHours then
        convertZombieToBody(zombie, deathAgeHours)
    end
end

local function queueZombie(zombie)
    if zombie == nil then return end
    QE.pendingZombies[zombie] = QE.tickNumber + PENDING_DELAY_TICKS
end

local function processPendingZombies()
    local processed = 0
    for zombie, readyTick in pairs(QE.pendingZombies) do
        if readyTick <= QE.tickNumber then
            QE.pendingZombies[zombie] = nil
            processZombie(zombie)
            processed = processed + 1
            if processed >= MAX_PENDING_PER_TICK then return end
        end
    end
end

local function scanAllActiveZombies()
    local cell = getCell()
    if cell == nil then return end
    local zombies = cell:getZombieList()
    if zombies == nil then return end
    for index = zombies:size() - 1, 0, -1 do
        processZombie(zombies:get(index))
    end
end

local function bodyDeathAgeHours(body)
    local data = safeModData(body)
    local marked = data and tonumber(data.ExtinctionDeathAgeHours) or nil
    if marked ~= nil then return marked end
    local ok, value = pcall(function() return body:getDeathTime() end)
    local deathWorldAge = ok and tonumber(value) or nil
    if deathWorldAge ~= nil and deathWorldAge ~= -1 then
        return deathWorldAge + apocalypseOffsetHours()
    end
    return apocalypseAgeHours()
end

local function createSkeletonFromBody(body)
    if body == nil or belongsToProjectALife(body) then return nil end
    local square = body:getSquare()
    if square == nil then return nil end

    local deathAgeHours = bodyDeathAgeHours(body)
    local x, y, z = body:getX(), body:getY(), body:getZ()
    local ok, skeleton = pcall(function() return square:createCorpse(true) end)
    if not ok or skeleton == nil then return nil end

    pcall(function() skeleton:setX(x) end)
    pcall(function() skeleton:setY(y) end)
    pcall(function() skeleton:setZ(z) end)
    pcall(function() skeleton:setDeathTime(apocalypseAgeToWorldAge(deathAgeHours)) end)
    pcall(function() skeleton:setFakeDead(false) end)
    pcall(function() skeleton:setReanimateTime(-1) end)
    pcall(function() skeleton:setKilledBy(nil) end)

    local data = safeModData(skeleton)
    if data ~= nil then
        data.ExtinctionManagedCorpse = true
        data.ExtinctionAmbientCorpse = true
        data.ExtinctionDeathAgeHours = deathAgeHours
        data.ExtinctionSkeletonized = true
    end

    QE.trackedBodies[body] = nil
    pcall(function() square:removeCorpse(body, false) end)
    transmitModData(skeleton)
    sendNewCorpse(skeleton)
    return skeleton
end

local function processTrackedBodies()
    local delay = skeletonizationHours()
    if delay <= 0 then return end
    local now = apocalypseAgeHours()

    for body, _ in pairs(QE.trackedBodies) do
        local remove = false
        local ok, square = pcall(function() return body:getSquare() end)
        if not ok or square == nil then
            remove = true
        elseif belongsToProjectALife(body) then
            remove = true
        else
            local skeleton = false
            pcall(function() skeleton = body:isSkeleton() end)
            if not skeleton and now >= bodyDeathAgeHours(body) + delay then
                createSkeletonFromBody(body)
            end
        end
        if remove then QE.trackedBodies[body] = nil end
    end
end

local function scanSquareForBodies(square)
    if square == nil then return end
    local objects = square:getStaticMovingObjects()
    if objects == nil then return end
    for index = 0, objects:size() - 1 do
        local object = objects:get(index)
        if instanceof(object, "IsoDeadBody") then trackBody(object) end
    end
end

local function scanChunkForBodies(chunk)
    if chunk == nil then return end
    local maxLevel = math.max(0, tonumber(chunk:getMaxLevel()) or 0)
    for z = 0, maxLevel do
        for x = 0, 9 do
            for y = 0, 9 do
                scanSquareForBodies(chunk:getGridSquare(x, y, z))
            end
        end
    end
end

local function onTick()
    QE.tickNumber = QE.tickNumber + 1
    processPendingZombies()
    if QE.tickNumber - QE.lastFullScanTick >= FULL_SCAN_INTERVAL_TICKS then
        QE.lastFullScanTick = QE.tickNumber
        scanAllActiveZombies()
    end
end

local function onGameStart()
    scanAllActiveZombies()
end

Events.OnZombieCreate.Add(queueZombie)
Events.OnTick.Add(onTick)
Events.EveryOneMinute.Add(scanAllActiveZombies)
Events.EveryHours.Add(processTrackedBodies)
Events.LoadGridsquare.Add(scanSquareForBodies)
Events.LoadChunk.Add(scanChunkForBodies)
Events.OnObjectAdded.Add(trackBody)
Events.OnDeadBodySpawn.Add(trackBody)
Events.OnGameStart.Add(onGameStart)
Events.OnServerStarted.Add(onGameStart)

return QE

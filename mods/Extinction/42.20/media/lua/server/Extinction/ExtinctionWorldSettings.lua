Extinction = Extinction or {}

local Settings = {}
local DATA_KEY = "ExtinctionWorldSettings"
local SECTOR_KEY = "ExtinctionNaturalSectors"
local settings = nil

local function selected(name, fallback)
    local options = SandboxVars and SandboxVars.Extinction
    if options == nil or options[name] == nil then return fallback end
    return options[name] == true
end

function Settings.initialize(isNewGame)
    -- Never infer a new world from its age: a new sandbox may start months
    -- after the apocalypse, and an existing save may still be on day zero.
    if ModData == nil or ModData.getOrCreate == nil then return end
    local root = ModData.getOrCreate(DATA_KEY)
    if root.version ~= 1 then
        local sectors = ModData.get ~= nil and ModData.get(SECTOR_KEY) or nil
        local usedNaturalMode = false
        if sectors ~= nil and type(sectors.sectors) == "table"
                and selected("NaturalStarvation", false) then
            for _ in pairs(sectors.sectors) do
                usedNaturalMode = true
                break
            end
        end
        -- Preserve worlds already using the development implementation. An
        -- empty sector root is not evidence: older builds created it in both
        -- modes. All other unmarked existing worlds keep the original mode.
        local newFeatures = isNewGame == true or usedNaturalMode
        root.natural = newFeatures and selected("NaturalStarvation", false)
        root.huntAnimals = newFeatures and selected("HuntAnimals", true)
        root.legacyFixed = not newFeatures
        root.version = 1
    end
    settings = root
    print("[Extinction] World settings: natural=" .. tostring(root.natural)
        .. ", hunting=" .. tostring(root.huntAnimals)
        .. ", legacyFixed=" .. tostring(root.legacyFixed))
end

function Settings.isNaturalEnabled()
    return settings ~= nil and settings.natural == true
end

function Settings.isHuntingEnabled()
    return settings ~= nil and settings.huntAnimals == true
end

function Settings.isLegacyFixedWorld()
    -- Until persistent settings are loaded, fail closed into original mode.
    return settings == nil or settings.legacyFixed == true
end

Extinction.WorldSettings = Settings
return Settings

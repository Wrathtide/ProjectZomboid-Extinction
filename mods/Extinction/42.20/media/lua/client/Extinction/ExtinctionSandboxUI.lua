require "OptionScreens/SandboxOptions"

local NATURAL_OPTION = "Extinction.NaturalStarvation"
local DEADLINE_OPTION = "Extinction.ExtinctionDays"
local HUNT_ANIMALS_OPTION = "Extinction.HuntAnimals"
local BIOLOGICAL_STATE_OPTION = "Extinction.TestShowBiologicalState"
local CORPSE_NUTRITION_OPTION = "Extinction.TestShowCorpseNutrition"

local function setTickBoxEnabled(control, enabled)
    if control == nil then return end
    control.enable = enabled
    if control.setEnabled ~= nil then control:setEnabled(enabled) end
end

local function updateExtinctionControls(screen)
    if screen == nil or screen.controls == nil then return end

    local naturalControl = screen.controls[NATURAL_OPTION]
    local deadlineControl = screen.controls[DEADLINE_OPTION]
    if naturalControl == nil or deadlineControl == nil then return end

    local naturalEnabled = naturalControl.selected ~= nil and naturalControl.selected[1] == true
    deadlineControl:setEditable(not naturalEnabled)
    deadlineControl:setSelectable(not naturalEnabled)
    if naturalEnabled then
        deadlineControl:setTextRGBA(0.55, 0.55, 0.55, 1.0)
    else
        deadlineControl:setTextRGBA(1.0, 1.0, 1.0, 1.0)
    end

    setTickBoxEnabled(screen.controls[HUNT_ANIMALS_OPTION], true)
    setTickBoxEnabled(screen.controls[BIOLOGICAL_STATE_OPTION], naturalEnabled)
    setTickBoxEnabled(screen.controls[CORPSE_NUTRITION_OPTION], naturalEnabled)
end

local originalOnTickBoxSelected = SandboxOptionsScreen.onTickBoxSelected
function SandboxOptionsScreen:onTickBoxSelected(_, value, optionName)
    originalOnTickBoxSelected(self, _, value, optionName)
    if optionName == NATURAL_OPTION then
        updateExtinctionControls(self)
    end
end

local originalSettingsToUI = SandboxOptionsScreen.settingsToUI
function SandboxOptionsScreen:settingsToUI(options)
    originalSettingsToUI(self, options)
    updateExtinctionControls(self)
end

local originalSetVisible = SandboxOptionsScreen.setVisible
function SandboxOptionsScreen:setVisible(visible, joypadData)
    originalSetVisible(self, visible, joypadData)
    if visible then
        updateExtinctionControls(self)
    end
end

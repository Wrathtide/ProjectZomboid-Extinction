require "OptionScreens/SandboxOptions"

local NATURAL_OPTION = "Extinction.NaturalStarvation"
local DEADLINE_OPTION = "Extinction.ExtinctionDays"

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

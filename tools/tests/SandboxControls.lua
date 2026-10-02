local deadline = {}
function deadline:setEditable(value) self.editable = value end
function deadline:setSelectable(value) self.selectable = value end
function deadline:setTextRGBA(r, g, b, a) self.red = r end
local natural = { selected = { false } }
local hunting = {}
local biological = {}
local nutrition = {}
local screen = { controls = {
    ["Extinction.NaturalStarvation"] = natural,
    ["Extinction.ExtinctionDays"] = deadline,
    ["Extinction.HuntAnimals"] = hunting,
    ["Extinction.TestShowBiologicalState"] = biological,
    ["Extinction.TestShowCorpseNutrition"] = nutrition,
} }
SandboxOptionsScreen.settingsToUI(screen, {})
assert(deadline.editable and deadline.selectable and hunting.enable,
    "Fixed-mode controls incorrectly lock deadline or hunting")
assert(not biological.enable and not nutrition.enable, "Natural-only overlays available in fixed mode")
natural.selected[1] = true
SandboxOptionsScreen.onTickBoxSelected(screen, nil, true, "Extinction.NaturalStarvation")
assert(not deadline.editable and not deadline.selectable and deadline.red == 0.55,
    "Natural mode did not lock and grey deadline")
assert(hunting.enable and biological.enable and nutrition.enable,
    "Natural-mode checkbox controls incorrectly disabled")
natural.selected[1] = false
SandboxOptionsScreen.setVisible(screen, true)
assert(deadline.editable and hunting.enable, "Returning to fixed mode disabled independent hunting")
print("OK ustawienia: blokada terminu, niezalezne polowanie, warunkowe ramki diagnostyczne")

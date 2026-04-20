local addon = cfSwingTimer
local K = addon.KEYS
local factory = addon.GUI

local panel = CreateFrame("Frame", "cfSwingTimerSettingsPanel")
panel.name = "cfSwingTimer"
panel:Hide()

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("cfSwingTimer")

local mainhand = factory.CreateCheckbox(panel, title, "Main Hand", K.MAINHAND, addon.EnableMainhand, addon.DisableMainhand)
local offhand = factory.CreateCheckbox(panel, mainhand, "Off Hand", K.OFFHAND, addon.EnableOffhand, addon.DisableOffhand)
local ranged = factory.CreateCheckbox(panel, offhand, "Ranged", K.RANGED, addon.EnableRanged, addon.DisableRanged)
local rangedCast = factory.CreateCheckbox(panel, ranged, "Ranged Cast", K.RANGED_CAST, addon.EnableRangedCast, addon.DisableRangedCast, ranged)
local paladinTwist = factory.CreateReloadCheckbox(panel, mainhand, "Paladin Twist", K.PALADIN_TWIST, mainhand, 260)
local warriorQueue = factory.CreateReloadCheckbox(panel, paladinTwist, "Warrior Queue", K.WARRIOR_QUEUE, mainhand)
local shamanHalf = factory.CreateReloadCheckbox(panel, warriorQueue, "Shaman Half", K.SHAMAN_HALF, mainhand)

local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Settings.RegisterAddOnCategory(category)

panel:SetScript("OnShow", factory.MakeSettingsPanelDraggable)

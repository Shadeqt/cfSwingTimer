local BAR_W = cfSwingTimer.BAR_W
local BAR_H = cfSwingTimer.BAR_H

-- Anchor
local frame = CreateFrame("Frame", "cfSwingTimerRangedFrame", UIParent)
frame:SetPoint("CENTER", 0, -200)
frame:SetSize(BAR_W, BAR_H)

local rangedBar = cfSwingTimer.CreateSwingBar(frame)
rangedBar:SetPoint("TOP")

-- OnUpdate
frame:SetScript("OnUpdate", function(self, elapsed)
    if rangedBar.speed > 0 then
        cfSwingTimer.UpdateBar(rangedBar, elapsed)
    end
end)

-- Events
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:SetScript("OnEvent", function(self, event)
    local _, sub, _, srcGUID = CombatLogGetCurrentEventInfo()
    if srcGUID ~= UnitGUID("player") then return end

    if sub == "SPELL_CAST_SUCCESS" then
        local spellId = select(12, CombatLogGetCurrentEventInfo())
        if spellId == 75 or spellId == 5019 or spellId == 3018 then
            local speed = UnitRangedDamage("player")
            rangedBar.speed = speed
            rangedBar.timer = speed
        end
    end
end)

local BAR_WIDTH, BAR_HEIGHT = 195, 13

cfSwingTimer = {
    BAR_WIDTH = BAR_WIDTH,
    BAR_HEIGHT = BAR_HEIGHT,
    playerGUID = UnitGUID("player"),
    debug = false,
    frames = {},
    bars = {},
}

function cfSwingTimer.dbg(...)
    if cfSwingTimer.debug then print(...) end
end

SLASH_CFST1 = "/cfst"
SlashCmdList["CFST"] = function(msg)
    local command = (msg or ""):trim():lower()
    if command == "debug" then
        cfSwingTimer.debug = not cfSwingTimer.debug
        print("cfSwingTimer debug: " .. (cfSwingTimer.debug and "ON" or "OFF"))
    else
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(cfSwingTimer.settingsCategory:GetID())
        end
    end
end

-- Tooltip scanner: only way to get base (unhasted) weapon speed in Classic
local tooltipScanner = CreateFrame("GameTooltip", "cfScanTip", nil, "GameTooltipTemplate")
tooltipScanner:SetOwner(WorldFrame, "ANCHOR_NONE")
local baseSpeedCache = {}

function cfSwingTimer.GetBaseWeaponSpeed(inventorySlot)
    local itemId = GetInventoryItemID("player", inventorySlot)
    if not itemId then return nil end
    if baseSpeedCache[itemId] then return baseSpeedCache[itemId] end
    tooltipScanner:ClearLines()
    tooltipScanner:SetInventoryItem("player", inventorySlot)
    for i = 2, tooltipScanner:NumLines() do
        local text = _G["cfScanTipTextRight" .. i]:GetText()
        if text then
            local speed = text:match("Speed (%d+%.%d+)")
            if speed then
                baseSpeedCache[itemId] = tonumber(speed)
                return baseSpeedCache[itemId]
            end
        end
    end
end

function cfSwingTimer.MakeMovable(frame, moduleName)
    frame:SetMovable(true)
    frame:EnableMouse(not cfSwingTimerDB.locked)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not cfSwingTimerDB.locked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local cx, cy = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        local x = math.floor(cx - ux + 0.5)
        local y = math.floor(cy - uy + 0.5)
        self:ClearAllPoints()
        self:SetPoint("CENTER", x, y)
        cfSwingTimerDB[moduleName].x = x
        cfSwingTimerDB[moduleName].y = y
    end)
    cfSwingTimer.frames[moduleName] = frame
end

function cfSwingTimer.CreateSwingBar(parent, speed)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
    bar:SetStatusBarTexture(cfSwingTimer.GetBarTexture())
    bar:SetStatusBarColor(1, 0.7, 0)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar.timer = 0
    bar.speed = speed or 0

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0, 0, 0, 0.5)

    bar.spark = bar:CreateTexture(nil, "OVERLAY")
    bar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    bar.spark:SetSize(32, 32)
    bar.spark:SetBlendMode("ADD")
    bar.spark:SetPoint("CENTER", bar, "LEFT", 0, 0)
    bar.spark:Hide()

    bar.border = bar:CreateTexture(nil, "OVERLAY")
    bar.border:SetTexture("Interface\\CastingBar\\UI-CastingBar-Border")
    bar.border:SetSize(256, 64)
    bar.border:SetPoint("TOP", bar, "TOP", 0, 26)

    bar.text = bar:CreateFontString(nil, "OVERLAY")
    bar.text:SetFont("Fonts\\FRIZQT__.ttf", 11)
    bar.text:SetPoint("RIGHT", bar, "RIGHT", -3, 0)

    bar.label = bar:CreateFontString(nil, "OVERLAY")
    bar.label:SetFont("Fonts\\FRIZQT__.ttf", 11)
    bar.label:SetPoint("LEFT", bar, "LEFT", 3, 0)

    return bar
end

function cfSwingTimer.UpdateSwingBar(bar, progress, remaining)
    bar:SetValue(progress)
    if remaining > 0 then
        bar.spark:Show()
        bar.spark:ClearAllPoints()
        bar.spark:SetPoint("CENTER", bar, "LEFT", progress * bar:GetWidth(), 0)
        bar.text:SetText(string.format("%.1f", remaining))
    else
        bar.spark:Hide()
        bar.text:SetText("")
    end
end

function cfSwingTimer.UpdateBar(bar, elapsed)
    if bar.speed == 0 then return end
    bar.timer = math.max(0, bar.timer - elapsed)
    local progress = bar.timer > 0 and (1 - bar.timer / bar.speed) or 0
    cfSwingTimer.UpdateSwingBar(bar, progress, bar.timer)
end

-- Apply all bar settings from DB (size, border scale, font, text color, text visibility, label)
function cfSwingTimer.ApplyBarSettings(bar, moduleName)
    local db = cfSwingTimerDB[moduleName]
    local w, h = db.width, db.height

    bar:SetSize(w, h)
    bar:GetParent():SetSize(w, h)

    -- Scale border proportionally from the default 195x13 → 256x64 ratio
    bar.border:SetSize(256 * w / 195, 64 * h / 13)
    bar.border:ClearAllPoints()
    bar.border:SetPoint("TOP", bar, "TOP", 0, 26 * h / 13)

    -- Font + text color
    bar.label:SetFont("Fonts\\FRIZQT__.ttf", db.fontSize)
    bar.text:SetFont("Fonts\\FRIZQT__.ttf", db.fontSize)
    bar.label:SetTextColor(db.textColor.r, db.textColor.g, db.textColor.b)
    bar.text:SetTextColor(db.textColor.r, db.textColor.g, db.textColor.b)

    -- Text visibility + label text
    if db.showLeftText then bar.label:Show() else bar.label:Hide() end
    if db.showRightText then bar.text:Show() else bar.text:Hide() end
    bar.label:SetText(db.leftText)

    -- Refresh class markers if they exist
    if cfSwingTimer.UpdateTwistMarkers then cfSwingTimer.UpdateTwistMarkers() end
    if cfSwingTimer.UpdateShamanMarkers then cfSwingTimer.UpdateShamanMarkers() end
end

-- Combat alpha: update all frame alphas based on combat state
function cfSwingTimer.ApplyAlpha()
    local inCombat = InCombatLockdown()
    local db = cfSwingTimerDB
    for moduleName, f in pairs(cfSwingTimer.frames) do
        local mod = db[moduleName]
        if mod then
            f:SetAlpha(inCombat and mod.alphaIC or mod.alphaOOC)
        end
    end
end

local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
combatFrame:SetScript("OnEvent", function()
    cfSwingTimer.ApplyAlpha()
end)

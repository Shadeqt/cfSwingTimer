-- Blizzard CastingBarFrame dimensions
-- Source: Interface/AddOns/Blizzard_CastingBar/Vanilla/CastingBarFrame.xml (Gethe/wow-ui-source, classic_era)
local BAR_WIDTH = 195
local BAR_HEIGHT = 13
local BORDER_WIDTH = 256
local BORDER_HEIGHT = 64
local SPARK_SIZE = 32
local SHOW_BORDER = false
local BAR_SPACING = SHOW_BORDER and 12 or 2

-- Blizzard class colors (RAID_CLASS_COLORS)
-- Source: warcraft.wiki.gg/wiki/RAID_CLASS_COLORS
local CLASS_COLORS = {
    WARRIOR     = { 0.78, 0.61, 0.43 },
    PALADIN     = { 0.96, 0.55, 0.73 },
    HUNTER      = { 0.67, 0.83, 0.45 },
    ROGUE       = { 1.00, 0.96, 0.41 },
    PRIEST      = { 1.00, 1.00, 1.00 },
    SHAMAN      = { 0.00, 0.44, 0.87 },
    MAGE        = { 0.25, 0.78, 0.92 },
    WARLOCK     = { 0.53, 0.53, 0.93 },
    DRUID       = { 1.00, 0.49, 0.04 },
    DEATHKNIGHT = { 0.77, 0.12, 0.23 },
    MONK        = { 0.00, 1.00, 0.60 },
    DEMONHUNTER = { 0.64, 0.19, 0.79 },
    EVOKER      = { 0.20, 0.58, 0.50 },
}

-- Blizzard casting bar colors
-- Source: Interface/AddOns/Blizzard_CastingBar/Vanilla/CastingBarFrame.lua (Gethe/wow-ui-source, classic_era)
local CASTBAR_COLORS = {
    CASTING          = { 1.00, 0.70, 0.00 },
    CHANNELING       = { 0.00, 1.00, 0.00 },
    FINISHED         = { 0.00, 1.00, 0.00 },
    FAILED           = { 1.00, 0.00, 0.00 },
    NONINTERRUPTIBLE = { 0.70, 0.70, 0.70 },
}

cfSwingTimer = {
    BAR_WIDTH = BAR_WIDTH,
    BAR_HEIGHT = BAR_HEIGHT,
    playerGUID = UnitGUID("player"),
    bars = {},
    CLASS_COLORS = CLASS_COLORS,
    CASTBAR_COLORS = CASTBAR_COLORS,
    BAR_SPACING = BAR_SPACING,
}

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


local function AddBackground(frame)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0.5)
end

local function AddThinBorder(frame)
    local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetBackdrop({ edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1 })
    border:SetBackdropBorderColor(0, 0, 0, 1)
end

local function AddBorder(frame, overlayParent)
    overlayParent = overlayParent or frame
    frame.border = overlayParent:CreateTexture(nil, "OVERLAY")
    frame.border:SetTexture("Interface\\CastingBar\\UI-CastingBar-Border")
    frame.border:SetSize(BORDER_WIDTH, BORDER_HEIGHT)
    frame.border:SetPoint("TOP", frame, "TOP", 0, 26)
end

local function AddText(frame, overlayParent, flags)
    overlayParent = overlayParent or frame
    frame.text = overlayParent:CreateFontString(nil, "OVERLAY")
    frame.text:SetFont("Fonts\\FRIZQT__.ttf", 11, flags)
    frame.text:SetPoint("RIGHT", frame, "RIGHT", -3, 0)
end

local function CreateStatusBar(parent, texture, color)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(texture)
    bar:SetStatusBarColor(unpack(color))
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    return bar
end

local DEFAULT_COLOR = CASTBAR_COLORS.CASTING

local function AddClipZone(bar)
    local clip = bar:CreateTexture(nil, "OVERLAY")
    clip:SetColorTexture(1, 0, 0, 0.3)
    clip:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    clip:Hide()
    bar.clipZones = { clip }
end

local function AddCenterClipZone(frame)
    local clip = frame:CreateTexture(nil, "OVERLAY")
    clip:SetColorTexture(1, 0, 0, 0.3)
    clip:SetPoint("BOTTOM", 0, 0)
    clip:SetHeight(BAR_HEIGHT)
    clip:Hide()
    frame.clipZones = { clip }
end

function cfSwingTimer.SetClipFraction(bar, fraction)
    local width = math.min(fraction * BAR_WIDTH, BAR_WIDTH)
    for _, tex in ipairs(bar.clipZones) do
        tex:SetWidth(width)
        tex:Show()
    end
end

function cfSwingTimer.HideClipZone(bar)
    for _, tex in ipairs(bar.clipZones) do tex:Hide() end
end

function cfSwingTimer.CreateSwingBar(parent, speed, clipZone)
    local texture = cfSwingTimer.GetBarTexture()
    local bar = CreateStatusBar(parent, texture, DEFAULT_COLOR)
    bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
    bar.timer = 0
    bar.speed = speed or 0

    AddBackground(bar)

    bar.spark = bar:CreateTexture(nil, "OVERLAY")
    bar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    bar.spark:SetSize(SPARK_SIZE, SPARK_SIZE)
    bar.spark:SetBlendMode("ADD")
    bar.spark:SetPoint("CENTER", bar, "LEFT", 0, 0)
    bar.spark:Hide()

    if clipZone then AddClipZone(bar) end
    if SHOW_BORDER then AddBorder(bar) else AddThinBorder(bar) end
    AddText(bar)

    return bar
end

function cfSwingTimer.CreateCenterSwingBar(parent, speed, clipZone)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(BAR_WIDTH, BAR_HEIGHT)
    frame.timer = 0
    frame.speed = speed or 0

    AddBackground(frame)

    local texture = cfSwingTimer.GetBarTexture()
    frame.bar = frame:CreateTexture(nil, "ARTWORK")
    frame.bar:SetTexture(texture)
    frame.bar:SetHeight(BAR_HEIGHT)
    frame.bar:SetWidth(0.001)
    frame.bar:SetPoint("BOTTOM", 0, 0)
    frame.bar:SetVertexColor(unpack(DEFAULT_COLOR))

    if clipZone then AddCenterClipZone(frame) end

    -- Raised frame so border/text draw above everything
    local overlayFrame = CreateFrame("Frame", nil, frame)
    overlayFrame:SetAllPoints()
    overlayFrame:SetFrameLevel(frame:GetFrameLevel() + 10)

    if SHOW_BORDER then AddBorder(frame, overlayFrame) else AddThinBorder(frame) end
    AddText(frame, overlayFrame, "OUTLINE")

    frame.SetStatusBarColor = function(self, r, g, b, a)
        self.bar:SetVertexColor(r, g, b, a)
    end

    frame.isCenter = true
    return frame
end

function cfSwingTimer.CreateBarFrame(moduleKey, y)
    local frame = CreateFrame("Frame", "cfSwingTimer_" .. moduleKey, UIParent)
    if y then frame:SetPoint("CENTER", 0, y) end
    frame:SetSize(cfSwingTimer.BAR_WIDTH, cfSwingTimer.BAR_HEIGHT)
    local bar = cfSwingTimer.CreateSwingBar(frame)
    bar:SetPoint("TOP")
    cfSwingTimer.bars[moduleKey] = bar
    return frame, bar
end

function cfSwingTimer.CreateCenterBarFrame(moduleKey, y, clipZone)
    local frame = CreateFrame("Frame", "cfSwingTimer_" .. moduleKey, UIParent)
    if y then frame:SetPoint("CENTER", 0, y) end
    frame:SetSize(cfSwingTimer.BAR_WIDTH, cfSwingTimer.BAR_HEIGHT)
    local bar = cfSwingTimer.CreateCenterSwingBar(frame, nil, clipZone)
    bar:SetPoint("TOP")
    cfSwingTimer.bars[moduleKey] = bar
    return frame, bar
end

function cfSwingTimer.CreateMarker(bar, color)
    local marker = bar:CreateTexture(nil, "OVERLAY")
    marker:SetColorTexture(unpack(color))
    marker:SetSize(1, bar:GetHeight())
    return marker
end

function cfSwingTimer.UpdateSwingBar(bar, progress, remaining)
    if bar.isCenter then
        local width = math.max(progress * BAR_WIDTH, 0.001)
        bar.bar:SetWidth(width)
    else
        bar:SetValue(progress)
        if remaining > 0 then
            bar.spark:Show()
            bar.spark:ClearAllPoints()
            bar.spark:SetPoint("CENTER", bar, "LEFT", progress * bar:GetWidth(), 0)
        else
            bar.spark:Hide()
        end
    end

    bar.text:SetText(remaining > 0 and string.format("%.1f", remaining) or "")
end



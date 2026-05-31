local _, addon = ...

-- The one bar type. Only the "thin" border style was ever used, so it is the
-- single inlined border here. Dimensions are read live from the Blizzard player
-- casting bar so our bars always match it (its size is set in XML and available
-- at load).
local BAR_WIDTH = CastingBarFrame:GetWidth()
local BAR_HEIGHT = CastingBarFrame:GetHeight()
local SPARK_SIZE = CastingBarFrame.Spark:GetWidth()

addon.BAR_WIDTH = BAR_WIDTH
addon.BAR_HEIGHT = BAR_HEIGHT
addon.playerGUID = UnitGUID("player")

-- The single StatusBar builder, shared by melee (MH/OH) and ranged (base + cast).
-- Bars are transient (hidden out of combat, shown on first swing/shot), so texture
-- and border color are read off the player frame in OnShow rather than via a
-- persistent hook. SetStatusBarTexture clears the bar color, so OnShow re-applies
-- it via ApplyBarColor right after (the SWT-B06 fix); a bar with neither colorToken
-- nor color set (ranged base) is left alone and colored each frame by its OnUpdate.
function addon.CreateSwingBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
    bar:SetStatusBarTexture(PlayerFrameHealthBar:GetStatusBarTexture():GetTexture())
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.5)

    bar.spark = bar:CreateTexture(nil, "OVERLAY")
    bar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    bar.spark:SetSize(SPARK_SIZE, SPARK_SIZE * 1.2)
    bar.spark:SetBlendMode("ADD")
    -- Anchored to the fill texture's right edge, so it tracks the fill automatically
    -- on SetValue — no per-frame repositioning. Adjust the Y offset to move it.
    bar.spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, -1)
    bar.spark:Hide()

    local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -3, 2)
    border:SetPoint("BOTTOMRIGHT", 3, -2)
    border:SetBackdrop({
        --edgeFile = "Interface\\FriendsFrame\\UI-Toast-Border",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 8.5,
    })
    bar.border = border

    -- Parented to the border frame so it draws above the bar's edge.
    bar.text = border:CreateFontString(nil, "OVERLAY", "GameFontHighlight") -- FRIZQT 12px white + shadow
    bar.text:SetPoint("RIGHT", bar, "RIGHT", -3, 0)

    bar:SetScript("OnShow", function(self)
        self:SetStatusBarTexture(PlayerFrameHealthBar:GetStatusBarTexture():GetTexture())
        addon.ApplyBarColor(self)
        self.border:SetBackdropBorderColor(PlayerFrameTexture:GetVertexColor())
    end)

    return bar
end

-- Resolve and apply a bar's color. A bar carries either a class token in
-- bar.colorToken (read LIVE from RAID_CLASS_COLORS, so it tracks cfClassColors'
-- Shaman-blue fix instead of the Era pink default) or a literal RGB array in
-- bar.color (the castbar-style colors that aren't class colors). SetStatusBarTexture
-- wipes the bar color, so OnShow re-applies via this (the SWT-B06 fix).
function addon.ApplyBarColor(bar)
    if bar.colorToken then
        local c = RAID_CLASS_COLORS[bar.colorToken]
        if c then bar:SetStatusBarColor(c.r, c.g, c.b) end
    elseif bar.color then
        bar:SetStatusBarColor(bar.color[1], bar.color[2], bar.color[3])
    end
end

-- Read a Blizzard casting-bar color field (e.g. "failedCastColor",
-- "startCastColor", "nonInterruptibleColor") as r, g, b. These are the castbar
-- palette colors that aren't class colors; sourcing them live keeps us matched to
-- Blizzard instead of hardcoding the RGBs.
function addon.CastbarColor(field)
    local c = CastingBarFrame[field]
    if c.GetRGB then return c:GetRGB() end
    return c.r, c.g, c.b
end

-- SetValue + spark + remaining-time text, identical for every bar.
function addon.UpdateSwingBar(bar, progress, remaining)
    bar:SetValue(progress)
    bar.spark:SetShown(remaining > 0)
    bar.text:SetText(remaining > 0 and string.format("%.1f", remaining) or "")
end

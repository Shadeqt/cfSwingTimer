local _, addon = ...

-- The one bar type. Dimensions follow the Blizzard CastingBarFrame; only the
-- "thin" border style was ever used, so it is the single inlined border here.
local BAR_WIDTH = 200
local BAR_HEIGHT = 10
local BAR_SPACING = 2
local SPARK_SIZE = 32

addon.BAR_WIDTH = BAR_WIDTH
addon.BAR_HEIGHT = BAR_HEIGHT
addon.BAR_SPACING = BAR_SPACING
addon.playerGUID = UnitGUID("player")

-- The single StatusBar builder, shared by melee (MH/OH) and ranged (base + cast).
-- Bars are transient (hidden out of combat, shown on first swing/shot), so texture
-- and border color are read off the player frame in OnShow rather than via a
-- persistent hook. SetStatusBarTexture clears the bar color, so OnShow re-applies
-- bar.color right after (the SWT-B06 fix); a bar with no fixed color (ranged base)
-- leaves bar.color nil and is colored each frame by its own OnUpdate.
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
    bar.spark:SetSize(SPARK_SIZE, SPARK_SIZE)
    bar.spark:SetBlendMode("ADD")
    bar.spark:SetPoint("CENTER", bar, "LEFT", 0, 0)
    bar.spark:Hide()

    local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -4, 4)
    border:SetPoint("BOTTOMRIGHT", 4, -4)
    border:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 12,
    })
    bar.border = border

    -- Parented to the border frame so it draws above the bar's edge.
    bar.text = border:CreateFontString(nil, "OVERLAY")
    bar.text:SetFont("Fonts\\FRIZQT__.ttf", 11)
    bar.text:SetPoint("RIGHT", bar, "RIGHT", -3, 0)

    bar:SetScript("OnShow", function(self)
        self:SetStatusBarTexture(PlayerFrameHealthBar:GetStatusBarTexture():GetTexture())
        if self.color then
            self:SetStatusBarColor(self.color[1], self.color[2], self.color[3])
        end
        self.border:SetBackdropBorderColor(PlayerFrameTexture:GetVertexColor())
    end)

    return bar
end

-- SetValue + spark + remaining-time text, identical for every bar.
function addon.UpdateSwingBar(bar, progress, remaining)
    bar:SetValue(progress)
    if remaining > 0 then
        bar.spark:Show()
        bar.spark:ClearAllPoints()
        bar.spark:SetPoint("CENTER", bar, "LEFT", progress * bar:GetWidth(), 0)
    else
        bar.spark:Hide()
    end
    bar.text:SetText(remaining > 0 and string.format("%.1f", remaining) or "")
end

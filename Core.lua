local BAR_W, BAR_H = 195, 13

cfSwingTimer = {
    BAR_W = BAR_W,
    BAR_H = BAR_H,
}

function cfSwingTimer.CreateSwingBar(parent, speed)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(BAR_W, BAR_H)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
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

    bar.border = bar:CreateTexture(nil, "OVERLAY")
    bar.border:SetTexture("Interface\\CastingBar\\UI-CastingBar-Border")
    bar.border:SetSize(256, 64)
    bar.border:SetPoint("TOP", bar, "TOP", 0, 26)

    bar.text = bar:CreateFontString(nil, "OVERLAY")
    bar.text:SetFont("Fonts\\FRIZQT__.ttf", 11)
    bar.text:SetPoint("RIGHT", bar, "RIGHT", -3, 0)

    return bar
end

function cfSwingTimer.UpdateBar(bar, elapsed)
    if bar.timer > 0 then bar.timer = math.max(0, bar.timer - elapsed) end
    local pct = 1 - bar.timer / bar.speed
    bar:SetValue(pct)
    if bar.timer > 0 then
        bar.spark:Show()
        bar.spark:ClearAllPoints()
        bar.spark:SetPoint("CENTER", bar, "LEFT", pct * BAR_W, 0)
    else
        bar.spark:Hide()
    end
    bar.text:SetText(string.format("%.1f", bar.timer))
end

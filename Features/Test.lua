local _, addon = ...

-- /cfst -- developer preview, mirroring cfCastbars' /cfcb. Toggles a static
-- display of every swing-timer bar (MH, OH, and on a hunter the ranged + cast
-- bars) so they can be sized and placed out of combat.
--
-- All preview logic lives here -- the engines (Melee/Ranged) carry NO test code.
-- While active we (a) hijack each driver bar's OnUpdate with a painter that parks
-- a fixed fill, and (b) hooksecurefunc its Hide so the engines' leave-combat /
-- unequip hides are immediately reversed. Toggling off restores the saved OnUpdate
-- and the engines resume untouched. Self-contained: comment out its toc line to
-- remove the command entirely.

local shown = false
local savedOnUpdate = {} -- driver bar -> its production OnUpdate, restored on toggle-off
local hookedHide = {}    -- driver bars whose Hide we've already hooked

-- Reverse any Hide while the preview is active. Hook installed lazily, once per bar.
local function keepShown(bar)
    if not hookedHide[bar] then
        hooksecurefunc(bar, "Hide", function(self)
            if shown then self:Show() end
        end)
        hookedHide[bar] = true
    end
    bar:Show()
end

local function park(bar, painter)
    savedOnUpdate[bar] = bar:GetScript("OnUpdate")
    bar:SetScript("OnUpdate", painter)
end

local function unpark(bar)
    bar:SetScript("OnUpdate", savedOnUpdate[bar])
    savedOnUpdate[bar] = nil
    bar:Hide()
end

-- Painters run every frame while parked; they re-show the child bars too (the
-- engine may toggle those off on an event), so the whole group stays visible.
local function paintMelee()
    addon.offHandBar:Show()
    addon.UpdateSwingBar(addon.mainHandBar, 0.66, 1.5)
    addon.UpdateSwingBar(addon.offHandBar, 0.33, 0.8)
end

local function paintRanged()
    addon.castBar:Show()
    addon.rangedBar:SetStatusBarColor(1, 1, 1)
    addon.UpdateSwingBar(addon.rangedBar, 0.5, 1.0)
    addon.SetClip(0.3)
    addon.UpdateSwingBar(addon.castBar, 0.4, 0.9)
end

local function ShowAll()
    shown = true
    keepShown(addon.mainHandBar)
    park(addon.mainHandBar, paintMelee)
    if addon.rangedBar then -- only exists on a hunter
        keepShown(addon.rangedBar)
        park(addon.rangedBar, paintRanged)
    end
end

local function HideAll()
    shown = false -- clear first so the Hide hook lets the bars stay hidden
    unpark(addon.mainHandBar)
    if addon.rangedBar then
        unpark(addon.rangedBar)
    end
end

SLASH_CFST1 = "/cfst"
SlashCmdList["CFST"] = function()
    if shown then HideAll() else ShowAll() end
end

local _, addon = ...

-- Options-panel preview: show the swing-timer bars statically so they can be placed with the position
-- sliders out of combat. Driven ONLY by the panel (Settings.lua's SettingsPanel hooks + /cfst), through
-- addon.PreviewShow / PreviewHide.
--
-- Isolation: all preview logic lives here -- the engines (Melee/Ranged/Core) carry NO preview code. We
-- reach into their bars from the outside and restore whatever we change, so removing this file's .toc
-- line drops the preview with the engines untouched.
--
-- Simple by construction -- no hooks, no per-frame work: we SUSPEND each driver bar's OnUpdate (save it,
-- set it to nil) and paint the fill ONCE. With the loop suspended nothing repaints or idle-hides the bar,
-- so the static display costs nothing per frame and needs no keep-shown hook. A bar disabled via its
-- checkbox carries Init's ApplyToggles Show-hook, so if we Show() it here that hook just re-hides it --
-- disabled bars never appear, with no special-casing and nothing for the gate to fight.

local shown = false
local savedOnUpdate = {} -- driver bar -> its production OnUpdate (false if it had none) while previewing

-- Suspend a driver bar's engine loop so nothing repaints or idle-hides it while we hold a static fill.
local function suspend(bar)
    if savedOnUpdate[bar] == nil then
        savedOnUpdate[bar] = bar:GetScript("OnUpdate") or false
        bar:SetScript("OnUpdate", nil)
    end
end

-- Restore the engine loop and hide the bar (the engine resumes combat-driven visibility).
local function restore(bar)
    if savedOnUpdate[bar] ~= nil then
        bar:SetScript("OnUpdate", savedOnUpdate[bar] or nil)
        savedOnUpdate[bar] = nil
    end
    bar:Hide()
end

-- One-shot painters (run once, on show). Show() precedes the value/color calls because OnShow re-applies
-- the bar texture, which would otherwise wipe the color (Core.lua:59-65). Disabled bars re-hide themselves
-- via their ApplyToggles gate.
local function paintMelee()
    addon.mainHandBar:Show()
    addon.UpdateSwingBar(addon.mainHandBar, 0.66, 1.5)
    addon.offHandBar:Show()
    addon.UpdateSwingBar(addon.offHandBar, 0.33, 0.8)
end

local function paintRanged()
    addon.rangedBar:Show()
    addon.rangedBar:SetStatusBarColor(1, 1, 1)
    addon.UpdateSwingBar(addon.rangedBar, 0.5, 1.0)
    addon.SetClip(0.3)
    addon.castBar:Show()
    addon.UpdateSwingBar(addon.castBar, 0.4, 0.9)
end

function addon.PreviewShow()
    if shown then return end
    shown = true
    suspend(addon.mainHandBar)
    paintMelee()
    if addon.rangedBar then -- hunter only
        suspend(addon.rangedBar)
        paintRanged()
    end
end

function addon.PreviewHide()
    if not shown then return end
    shown = false
    restore(addon.mainHandBar)
    if addon.rangedBar then restore(addon.rangedBar) end
end

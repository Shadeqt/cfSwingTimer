local addonName, addon = ...

-- Settings feature bootstrap: DB schema, the merge/prune InitDB, and the two load-time appliers that
-- realize the saved settings (positions + bar toggles). Everything here reaches INTO the engine-owned
-- bars from the outside -- the engine files (Melee/Ranged/Core) are never edited -- so the whole feature
-- is removable by dropping Init.lua + Settings.lua, their two .toc lines, and the SavedVariables line.

-- DB schema (single source of truth for cfSwingTimerDB keys). InitDB() merges newly-added defaults and
-- prunes any key no longer in the schema, matching the sibling cf* addons.
--
-- The OH/cast Y defaults reproduce today's hardcoded layout via addon.BAR_HEIGHT, which is why this file
-- loads AFTER Core.lua (Core sets addon.BAR_HEIGHT at its own load). Note the 2x factor: OH is anchored
-- TOP -> mainHandBar BOTTOM at offset -BAR_HEIGHT (Melee.lua:39), so the two CENTERS sit one bar-height
-- apart from the edge-to-edge anchoring PLUS the explicit -BAR_HEIGHT offset = 2*BAR_HEIGHT
-- center-to-center. Same for cast one bar above ranged (Ranged.lua:98).
addon.defaults = {
    -- Bars (visibility gated externally by ApplyToggles' Show-hooks -- the engine is never edited)
    MeleeBars  = true,
    OffHandBar = true,
    RangedBar  = true,   -- Hunter-only; inert on other classes
    CastBar    = true,   -- Hunter-only
    -- Per-bar positions: independent X/Y offsets from UIParent CENTER
    MhX = 0, MhY = -150,
    OhX = 0, OhY = -150 - 2 * addon.BAR_HEIGHT,
    RangedX = 0, RangedY = -120,
    CastX = 0, CastY = -120 + 2 * addon.BAR_HEIGHT,
}

function addon.InitDB()
    cfSwingTimerDB = cfSwingTimerDB or {}
    -- Merge newly-added defaults.
    for key, value in pairs(addon.defaults) do
        if cfSwingTimerDB[key] == nil then
            cfSwingTimerDB[key] = value
        end
    end
    -- Prune keys no longer in the schema.
    for key in pairs(cfSwingTimerDB) do
        if addon.defaults[key] == nil then
            cfSwingTimerDB[key] = nil
        end
    end
end

-- Re-anchor every bar to UIParent CENTER at its saved X/Y. Called at load and again from each position
-- slider's value-changed callback (live movement). Overrides the engine's eager SetPoint literals --
-- including OH's and cast's parent-relative anchors -- from the outside, without editing the engine.
-- clipZone needs no handling: it's anchored to rangedBar, so it rides the ranged bar. rangedBar/castBar
-- are nil off a Hunter, so place() no-ops on them.
function addon.ApplyPositions()
    local function place(bar, x, y)
        if not bar then return end
        bar:ClearAllPoints()
        bar:SetPoint("CENTER", UIParent, "CENTER", x, y)
    end
    place(addon.mainHandBar, cfSwingTimerDB.MhX,     cfSwingTimerDB.MhY)
    place(addon.offHandBar,  cfSwingTimerDB.OhX,     cfSwingTimerDB.OhY)
    place(addon.rangedBar,   cfSwingTimerDB.RangedX, cfSwingTimerDB.RangedY)
    place(addon.castBar,     cfSwingTimerDB.CastX,   cfSwingTimerDB.CastY)
end

-- Gate a disabled bar's visibility with a permanent Show-hook that immediately re-hides it, so the
-- engine's own Show()/SetShown() calls are reversed without touching engine source. Reload-gated: the
-- hooks are installed here at load from the saved DB, so flipping a checkbox only takes effect on the
-- next /reload. Because the engine never reads cfSwingTimerDB, there is no file-load nil-crash risk.
function addon.ApplyToggles()
    local function gate(bar, enabled)
        if bar and not enabled then
            bar:Hide()
            hooksecurefunc(bar, "Show", bar.Hide) -- any later Show() self-corrects to Hide()
        end
    end
    gate(addon.mainHandBar, cfSwingTimerDB.MeleeBars)
    gate(addon.offHandBar,  cfSwingTimerDB.OffHandBar)
    gate(addon.rangedBar,   cfSwingTimerDB.RangedBar)   -- nil off a Hunter -> gate() no-ops
    gate(addon.castBar,     cfSwingTimerDB.CastBar)
end

EventUtil.ContinueOnAddOnLoaded(addonName, function()
    addon.InitDB()          -- DB populated first (sibling contract; avoids nil-bound settings)
    addon.SetupSettings()   -- register the panel now that the DB exists
    addon.ApplyPositions()  -- bars already exist (built at file-load); UIParent exists
    addon.ApplyToggles()    -- external Show-hooks gate the disabled bars (no engine edits)
end)

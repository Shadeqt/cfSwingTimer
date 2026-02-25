-- Spells that replace auto-attack and reset the MH swing timer
-- Fires as SPELL_DAMAGE / SPELL_MISSED instead of SWING_DAMAGE / SWING_MISSED
cfSwingTimer_SwingReset = {
    -- Warrior: Heroic Strike
    [78]    = "Heroic Strike (Rank 1)",
    [284]   = "Heroic Strike (Rank 2)",
    [285]   = "Heroic Strike (Rank 3)",
    [1608]  = "Heroic Strike (Rank 4)",
    [11564] = "Heroic Strike (Rank 5)",
    [11565] = "Heroic Strike (Rank 6)",
    [11566] = "Heroic Strike (Rank 7)",
    [11567] = "Heroic Strike (Rank 8)",
    [25286] = "Heroic Strike (Rank 9)",
    [29707] = "Heroic Strike (Rank 10)", -- TBC
    [30324] = "Heroic Strike (Rank 11)", -- TBC

    -- Warrior: Cleave
    [845]   = "Cleave (Rank 1)",
    [7369]  = "Cleave (Rank 2)",
    [11608] = "Cleave (Rank 3)",
    [11609] = "Cleave (Rank 4)",
    [20569] = "Cleave (Rank 5)",
    [25231] = "Cleave (Rank 6)", -- TBC

    -- Druid: Maul
    [6807]  = "Maul (Rank 1)",
    [6808]  = "Maul (Rank 2)",
    [6809]  = "Maul (Rank 3)",
    [8972]  = "Maul (Rank 4)",
    [9745]  = "Maul (Rank 5)",
    [9880]  = "Maul (Rank 6)",
    [9881]  = "Maul (Rank 7)",
    [26996] = "Maul (Rank 8)", -- TBC

    -- Hunter: Raptor Strike
    [2973]  = "Raptor Strike (Rank 1)",
    [14260] = "Raptor Strike (Rank 2)",
    [14261] = "Raptor Strike (Rank 3)",
    [14262] = "Raptor Strike (Rank 4)",
    [14263] = "Raptor Strike (Rank 5)",
    [14264] = "Raptor Strike (Rank 6)",
    [14265] = "Raptor Strike (Rank 7)",
    [14266] = "Raptor Strike (Rank 8)",
    [27014] = "Raptor Strike (Rank 9)", -- TBC
}

-- Ranged auto-attack spells tracked by the swing timer
cfSwingTimer_RangedShot = {
    [75]   = "Auto Shot",
    [5019] = "Shoot (Wand)",
    [3018] = "Shoot (Bow/Gun/Crossbow)",
    [2764] = "Throw",
}

-- Subset that auto-repeats (cooldown = speed - castTime)
cfSwingTimer_AutoRepeat = {
    [75]   = "Auto Shot",
    [5019] = "Shoot (Wand)",
}

-- Spells that pause the MH swing timer during cast
cfSwingTimer_SlamPause = {
    -- Warrior: Slam
    [1464]  = "Slam (Rank 1)",
    [8820]  = "Slam (Rank 2)",
    [11604] = "Slam (Rank 3)",
    [11605] = "Slam (Rank 4)",
    [25241] = "Slam (Rank 5)", -- TBC
    [25242] = "Slam (Rank 6)", -- TBC
}

-- TBC: Aimed Shot resets auto shot timer on cast start
cfSwingTimer_AimedShot = {
    [19434] = "Aimed Shot (Rank 1)",
    [20900] = "Aimed Shot (Rank 2)",
    [20901] = "Aimed Shot (Rank 3)",
    [20902] = "Aimed Shot (Rank 4)",
    [20903] = "Aimed Shot (Rank 5)",
    [20904] = "Aimed Shot (Rank 6)",
    [27065] = "Aimed Shot (Rank 7)",  -- TBC
}

-- Hunter shots that block auto-shot during cast (combined table)
cfSwingTimer_HunterCast = {}
for id, name in pairs(cfSwingTimer_AimedShot) do
    cfSwingTimer_HunterCast[id] = name
end
-- Steady Shot
cfSwingTimer_HunterCast[34120] = "Steady Shot"          -- TBC
-- Multi-Shot
cfSwingTimer_HunterCast[2643]  = "Multi-Shot (Rank 1)"
cfSwingTimer_HunterCast[14288] = "Multi-Shot (Rank 2)"
cfSwingTimer_HunterCast[14289] = "Multi-Shot (Rank 3)"
cfSwingTimer_HunterCast[14290] = "Multi-Shot (Rank 4)"
cfSwingTimer_HunterCast[25294] = "Multi-Shot (Rank 5)"  -- TBC
cfSwingTimer_HunterCast[27021] = "Multi-Shot (Rank 6)"  -- TBC

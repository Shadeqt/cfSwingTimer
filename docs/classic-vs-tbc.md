# Vanilla vs TBC: Swing Timer Mechanics

Game mechanics and how they compare between Vanilla (1.12) and TBC (2.x).

---

## Extra Attacks (Windfury, Sword Spec, Hand of Justice, etc.)

### Combat log event order when an extra attack procs

```
1. SWING_DAMAGE         <- normal swing lands
2. SPELL_EXTRA_ATTACKS  <- proc fires (amount = number of extra swings)
3. SWING_DAMAGE         <- extra attack lands ~100-200ms later
```

The normal swing (#1) always resets the timer. The question is whether
the extra attack's SWING_DAMAGE (#3) resets it again.

### Vanilla (1.12)

Extra attacks **DO** reset the swing timer.

When the extra attack lands at #3, the timer resets again. The
~100-200ms of progress since the normal swing is lost.

### TBC (2.1+)

Extra attacks do **NOT** reset the swing timer.

Patch 2.1.2 changed Sword Specialization:
> "Extra attacks will appear in white and act like any auto-attack.
> They will no longer reset the swing time of your weapon."

The extra attack at #3 has no effect on the timer — it keeps ticking
from where #1 reset it.

### Chain procs

Extra attacks CAN trigger further procs from other sources. A paladin
documented 8 hits in a row from Ironfoe + Hand of Justice.

- Windfury has a ~1.5s internal cooldown (cannot proc off itself)
- Sword Spec cannot proc off its own extra attacks
- Cross-source procs are allowed (Sword Spec can proc off Windfury)
- TBC 2.2.0 restricted this further: "Sword Specialization: This
  talent's free extra attacks can no longer trigger additional extra
  attacks"

### Summary

| Behavior                    | Vanilla 1.12     | TBC 2.1+          |
|-----------------------------|------------------|--------------------|
| Extra attack resets timer?  | Yes              | No                 |
| Chain procs across sources? | Yes              | Limited (2.2.0)    |

### References

- LibClassicSwingTimerAPI v2.0.7 (May 2024): "Extra attacks gain
  always reset swing timer. Removed skip next attack event logic to
  reflect current in game behavior."
  https://github.com/Ralgathor/LibClassicSwingTimerAPI/blob/main/CHANGELOG.md

- ClassicRogueCraft Swing Timing Guide:
  https://classicroguecraft.com/swing-timing-guide/

- Blizzard Forums — Auto Attack Swing Resets:
  https://us.forums.blizzard.com/en/wow/t/auto-attack-swing-resets/833161

- TBC DPS Warrior Sim — "Extra attack no longer reset swing timer":
  https://github.com/TheGroxEmpire/TBC_DPS_Warrior_Sim/commit/8d66e3a

- TBC Warrior issue #31 (confirmed fix in TBC Classic 2.5.1.38521):
  https://github.com/magey/tbc-warrior/issues/31

- Classic Warrior issue #25 (chain proc documentation):
  https://github.com/magey/classic-warrior/issues/25

---

## Aimed Shot and the Auto Shot Timer

### Vanilla (1.12)

Aimed Shot does **NOT** reset the auto shot timer on cast start.

The auto shot cycle continues running during the Aimed Shot cast. The
server-side cooldown keeps ticking. After Aimed Shot lands, the next
auto shot fires based on remaining cooldown — not a full reset from
when the cast began.

### TBC (2.x)

Aimed Shot **resets** the auto shot timer on **cast start**.

The moment Aimed Shot begins casting, the server resets the auto shot
cooldown to a full weapon speed. Any remaining cooldown progress is
lost.

### Summary

| Behavior                         | Vanilla 1.12       | TBC 2.x              |
|----------------------------------|--------------------|-----------------------|
| Aimed Shot resets auto shot?     | No (on cast start) | Yes (on cast start)   |
| Auto shot cycle during cast      | Keeps ticking      | Reset to full speed   |

---

## Ranged Shot Speed API

### Vanilla (1.12)

`GetSpellInfo()` returns **no cast time** for Auto Shot and Multi-Shot.
Shot time must be calculated manually from base weapon speed + haste:

```
hastedSpeed = UnitRangedDamage("player")
baseSpeed   = tooltip scan (unhasted)
castTime    = baseCastTime * (hastedSpeed / baseSpeed)
```

### TBC (2.x)

`GetSpellInfo()` returns the correct cast time for both Auto Shot and
Multi-Shot. The manual calculation is unnecessary.

### Summary

| Behavior                         | Vanilla 1.12                | TBC 2.x              |
|----------------------------------|----------------------------|-----------------------|
| Auto Shot speed from API?        | No (must calculate)        | Yes                   |
| Multi-Shot speed from API?       | No (must calculate)        | Yes                   |

---

## Slam and the Melee Swing Timer

### Vanilla (1.12) and TBC (2.x)

Slam **resets** the swing timer when the cast finishes. Auto-attacks
cannot fire while the player is casting.

However, warriors exploit this with the "Slam batching" macro:

```
#showtooltip Slam
/cast Slam
/stopattack
```

By stopping auto-attack during the cast, the reset has no swing timer
to affect. If Slam's cast time is longer than the remaining swing time,
the swing was already "due" — so the warrior swings immediately after
Slam finishes. The reset only matters if Slam lands while the swing
timer is still actively counting down.

#### Addon behavior (Era)

On `SPELL_CAST_SUCCESS` for Slam: if MH swing timer was still active
(elapsed < speed), reset `mhSwingStart = now`. If the timer had already
expired (elapsed >= speed), do nothing — the next `SWING_DAMAGE` picks
it up naturally.

### WotLK (3.0.2+)

Slam **pauses/suspends** the swing timer instead of resetting it. The
timer freezes during the cast and resumes from where it was.

### Patch history

| Patch | Change |
|-------|--------|
| **1.2.0** (Dec 2004) | "Warriors will now resume attacking after performing a Slam attack." (Before this, auto-attack stopped entirely after Slam.) |
| **2.0.3** (Jan 2007) | "Removed Slam's casting time interruption." (Slam cast can no longer be pushed back by taking damage.) |
| **3.0.2** (Oct 2008) | "Slam now suspends the weapon swing timer rather than resetting it." (WotLK — does not apply to Vanilla or TBC.) |

### Summary

| Behavior                     | Vanilla 1.12      | TBC 2.x            | WotLK 3.0.2+      |
|------------------------------|-------------------|---------------------|--------------------|
| Slam effect on swing timer   | Reset (cast end)  | Reset (cast end)    | Pause/resume       |
| Cast pushback from damage?   | Yes               | No (removed 2.0.3)  | No                 |

### References

- Blizzard hotfix (January 7, 2020, posted by Kaivax): "Fixed a bug
  that caused /stopattack and /startattack macros to pause the swing
  timer (rather than reset it) when used with abilities such as Slam."
  https://us.forums.blizzard.com/en/wow/t/wow-classic-hotfixes-updated-november-16/361448/108

- Patch 3.0.2 official notes (WotLK pre-patch): "Slam now suspends
  the weapon swing timer rather than resetting it."
  https://warcraft.wiki.gg/wiki/Patch_3.0.2

- Slam — Warcraft Wiki:
  https://warcraft.wiki.gg/wiki/Slam

- Slam batching guide (r/classicwow):
  https://www.reddit.com/r/classicwow/comments/ejl0d6/warrior_slam_batching_what_ive_learned_so_far/


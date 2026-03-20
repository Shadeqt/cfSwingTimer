# Melee Swing Timer Mechanics (Classic Era)

---

## Auto-Attack Cycle

The player has a main hand (MH) and optionally an off hand (OH). Each
has its own swing timer based on weapon speed from `UnitAttackSpeed()`.

```
swing lands → SWING_DAMAGE/SWING_MISSED → timer resets → counts up → swing lands
```

MH and OH run independently. A swing can either hit (SWING_DAMAGE) or
miss (SWING_MISSED: miss, dodge, parry, block, etc.). Both reset the
timer for that hand.

OH deals 50% damage baseline (modified by talents).

---

## Off-Hand Forced Delay

When auto-attack is enabled, OH gets a forced delay of **half its swing
speed** before it can swing. This happens every time auto-attack
activates, regardless of range.

- If enabled out of range, the delay runs while approaching. By the
  time the player reaches melee, it may have already expired.
- If enabled in melee range, MH swings immediately (if ready) and OH
  waits the half-speed delay.

The delay is internal to the game engine. There is no API event when
the delay starts — only `PLAYER_ENTER_COMBAT` (auto-attack toggled on)
signals that it may have been imposed.

---

## Parry Haste

When the player's attack is parried, the MH swing timer is accelerated.

- Reduction: 40% of MH weapon speed added to elapsed time
- Floor: swing cannot be reduced below 20% of weapon speed remaining
- Only affects MH, never OH
- Triggered by: `SWING_MISSED` where `destGUID == playerGUID` and
  miss type is `"PARRY"`

Example: 2.5s MH speed, 0.5s elapsed, enemy parries.
Reduction = 1.0s. New elapsed = 1.5s. Remaining = 1.0s.
Floor = 0.5s (20% of 2.5). 1.0s > 0.5s, so no floor cap.

---

## Extra Attacks

Procs like Windfury, Sword Specialization, and Hand of Justice grant
extra melee swings.

### Event order

```
1. SWING_DAMAGE         <- normal swing lands, timer resets
2. SPELL_EXTRA_ATTACKS  <- proc fires (amount = N extra swings)
3. SWING_DAMAGE         <- extra attack(s) land ~100-200ms later
```

Each extra attack's `SWING_DAMAGE` resets the timer again. The
~100-200ms of progress since the normal swing is lost.

### Proc interactions

- Windfury has a ~1.5s internal cooldown (cannot proc off itself)
- Sword Spec cannot proc off its own extra attacks
- Cross-source procs are allowed (Sword Spec can proc off Windfury)

### Addon handling

Track `SPELL_EXTRA_ATTACKS` amount. For each subsequent MH
`SWING_DAMAGE`, decrement the counter instead of resetting the timer.
When counter reaches 0, the next MH swing resets normally.

---

## Swing Resets

Actions that reset the MH swing timer to zero (full weapon speed wait):

| Cause | Details |
|-------|---------|
| Slam | Resets on cast end (`SPELL_CAST_SUCCESS`). Only if timer was still active (elapsed < speed). |
| Extra attacks | Each extra swing's `SWING_DAMAGE` resets the timer. |
| Equipment change | Changing weapon in slots 16/17 resets both MH and OH. |
| Spell casts | Most spell casts with a cast time reset the swing timer. Exceptions: spells on the no-reset list (dynamite, Steady Shot, etc.). |

---

## Next-Melee Replacers

Heroic Strike, Cleave, Raptor Strike, and Maul **replace** the next
MH swing — they don't reset the timer.

- Queued with `UNIT_SPELLCAST_SENT`
- Lands as `SPELL_DAMAGE` or `SPELL_MISSED` instead of `SWING_DAMAGE`
- Timer resets on land, same as a normal swing
- Can be cancelled before the swing fires (dequeue check:
  `C_Spell.IsCurrentSpell()` returns false)

The bar can change color while a replacer is queued to indicate the
upcoming special attack.

---

## Haste Changes Mid-Swing

When attack speed changes during an active swing (e.g. Flurry procs,
buffs expire), the remaining time scales proportionally.

```
multiplier = newSpeed / oldSpeed
newRemaining = oldRemaining * multiplier
```

Detected via `UNIT_ATTACK_SPEED`. The timer adjusts so progress is
preserved proportionally — a swing that was 60% done stays 60% done
at the new speed.

---

## WoW Events

### CLEU (COMBAT_LOG_EVENT_UNFILTERED)

| Subevent | What it tells us |
|----------|-----------------|
| `SWING_DAMAGE` | Melee hit landed. `isOffHand` flag at index 21 distinguishes MH/OH. Resets timer for that hand. |
| `SWING_MISSED` | Melee swing missed (miss, dodge, parry, block, etc.). `isOffHand` at index 13. Resets timer. |
| `SPELL_EXTRA_ATTACKS` | Extra attack proc fired. `amount` at index 15 = number of extra swings. |
| `SPELL_DAMAGE` | Spell hit landed. Used for next-melee replacers (HS/Cleave). Check spell ID against replacer list. |
| `SPELL_MISSED` | Spell missed. Same as above for replacers that miss. |
| `SPELL_CAST_SUCCESS` | Spell cast completed. Used for Slam reset detection. |

### Unit Events

| Event | What it tells us |
|-------|-----------------|
| `UNIT_ATTACK_SPEED` | Weapon speed changed (haste buff, Flurry, etc.). Rescale active timers. |
| `UNIT_SPELLCAST_SENT` | Spell queued. Used to detect HS/Cleave queue for bar coloring. |

### Player Events

| Event | What it tells us |
|-------|-----------------|
| `PLAYER_ENTER_COMBAT` | Auto-attack toggled ON. OH forced delay may be imposed. |
| `PLAYER_LEAVE_COMBAT` | Auto-attack toggled OFF. NOT the same as leaving combat (that's `PLAYER_REGEN_ENABLED`). |
| `PLAYER_ENTERING_WORLD` | Login/reload. Initialize weapon speeds. |
| `PLAYER_EQUIPMENT_CHANGED` | Weapon swapped. Reset timers, update speeds. |

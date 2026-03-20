# Ranged Swing Timer Mechanics (Classic Era)

---

## Auto Shot Cycle

Ranged auto-attack is a continuous loop of shot + reload:

```
weapon speed = shot time + reload time
```

Shot time is ~0.5s base, scales with haste. Reload is the remainder.

Example: 3.0s bow, 15% haste → 2.6s speed → ~0.43s shot + ~2.17s reload.

The cycle repeats as long as auto shot is enabled, the player is
standing still, not casting, and has a valid target in range.

---

## Shot Phase

The ~0.5s shoot animation at the start of each cycle. During this phase:

- Player must stand still (movement cancels the shot)
- Cannot start other spell casts
- No pushback from damage taken

The game does not treat this as a "cast" — it's a shoot animation.
`UnitCastingInfo` does not return anything during the shot phase.

---

## Reload Phase

Countdown after the shot fires until the next shot can begin. During
this phase the player is free to:

- Move
- Cast spells (Aimed Shot, Multi-Shot, etc.)
- Change targets

The reload timer keeps ticking regardless of what the player does.

---

## Retry

When the auto shot cycle is ready to fire but conditions aren't met
(moving, mid-cast, no target, out of range), the server retries every
~0.5s until conditions are met.

### FAILED vs FAILED_QUIET

- `UNIT_SPELLCAST_FAILED` — real failure, shot is cancelled
- `UNIT_SPELLCAST_FAILED_QUIET` — ambiguous. Fires in various
  situations, not all of which are real failures. Some are the server's
  retry polling, some are noise from target switching or other actions.

**Status: which FAILED_QUIET scenarios actually delay the next shot vs
being harmless noise needs more in-game testing.**

Current implementation: only starts retry timer on FAILED_QUIET if
no cast is active (`castEnd == 0`), to avoid false triggers during
hunter spell casts.

---

## Shots vs Casts

Ranged abilities fall into two categories:

### Shots (Auto Shot, Multi-Shot)

- Use the same ~0.5s shoot animation
- No pushback from damage
- API returns **no cast time** (`GetSpellInfo` returns 0)
- Cast time must be calculated manually (see Shot Time Calculation)
- Multi-Shot uses the same shot time as Auto Shot

### Casts (Aimed Shot)

- Real cast with its own cast time
- **Gets pushback** from damage taken (diminishing returns)
- API **does return** cast time via `GetSpellInfo`
- Shows in `UnitCastingInfo`

---

## Clipping

Starting a cast or shot when reload is almost done delays the next
auto shot. Both shots and casts block auto shot.

Example: reload has 0.2s left, player starts Multi-Shot. Auto shot
would have fired in 0.2s but now waits until Multi-Shot finishes +
next retry window.

The addon shows a clip zone on the reload bar indicating how much
time would be lost if a shot-speed spell is cast at that point.

---

## Pushback

Only affects casts (Aimed Shot), not shots (Auto Shot, Multi-Shot).

Each hit taken during a cast pushes the completion time back. The
pushback amount diminishes with each hit:

| Hit # | Cumulative pushback (seconds) |
|-------|-------------------------------|
| 1     | 1.0                           |
| 2     | 1.8                           |
| 3     | 2.4                           |
| 4     | 2.8                           |
| 5     | 3.0 (cap)                     |

Damage sources: SWING_DAMAGE, SPELL_DAMAGE, RANGE_DAMAGE,
ENVIRONMENTAL_DAMAGE where `destGUID == playerGUID`.

---

## Shot Time Calculation (Era)

In Classic Era, the API returns no cast time for Auto Shot and
Multi-Shot. Shot time must be derived manually:

```
hastedSpeed    = UnitRangedDamage("player")
baseSpeed      = tooltip scan (unhasted, from weapon tooltip)
hasteModifier  = hastedSpeed / baseSpeed
shotTime       = baseShotTime * hasteModifier
```

Where `baseShotTime` is 0.5s (500ms) for Auto Shot and Multi-Shot.

The base weapon speed is obtained by scanning the ranged weapon
tooltip for the "Speed X.XX" line, since no API returns unhasted
weapon speed in Classic.

---

## Feign Death

Resets the server's auto shot cycle entirely. The server discards
current cycle progress and starts fresh. Auto shot must be re-enabled
(player stands up / moves / jumps) before a new cycle begins.

See `docs/feign-death-mechanics.md` for detailed investigation of
the recovery timing.

---

## WoW Events

### CLEU (COMBAT_LOG_EVENT_UNFILTERED)

| Subevent | What it tells us |
|----------|-----------------|
| `SPELL_CAST_START` (Auto Shot/Multi-Shot) | Shot phase started. Start shoot timer. |
| `SPELL_CAST_START` (Aimed Shot) | Hunter cast started. Start cast bar. |
| `SWING_DAMAGE` / `SPELL_DAMAGE` / `RANGE_DAMAGE` / `ENVIRONMENTAL_DAMAGE` | Damage taken. Apply pushback if mid-cast. |

### Unit Events

| Event | What it tells us |
|-------|-----------------|
| `UNIT_SPELLCAST_SUCCEEDED` | Shot/cast completed. Start reload (for shots) or stop cast bar (for casts). |
| `UNIT_SPELLCAST_FAILED` | Cast explicitly failed. Clear shot timer and/or cast state. |
| `UNIT_SPELLCAST_FAILED_QUIET` | Server retry or ambiguous failure. Start retry timer if not mid-cast. |
| `UNIT_SPELLCAST_INTERRUPTED` | Cast interrupted. Clear cast state. |

### Player Events

| Event | What it tells us |
|-------|-----------------|
| `START_AUTOREPEAT_SPELL` | Auto shot enabled. |
| `STOP_AUTOREPEAT_SPELL` | Auto shot disabled. Clear retry state. |
| `PLAYER_ENTERING_WORLD` | Login/reload. Check for ranged weapon, show/hide bar. |
| `PLAYER_EQUIPMENT_CHANGED` | Ranged slot changed. Update visibility and speeds. |

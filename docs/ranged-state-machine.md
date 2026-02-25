# Ranged Auto Shot: State Machine

Investigation as of 2026-02-22 10:59.

---

## Cycle

```
weapon speed = cast time + reload time
```

Cast time is ~0.5s base, scales with haste. Reload is the remainder.

Example: 3.0s bow, 15% haste → 2.6s speed → ~0.43s cast + ~2.17s reload.

---

## States

```
IDLE ──(enable auto shot)──> CAST
                               │
                   ┌───────────┘
                   v
                 CAST (~0.5s, haste-scaled)
                   │
         success ──┼── interrupted
                   │        │
                   v        v
                RELOAD    RETRY (0.5s server interval)
                   │        │
        expires ───┤   met ─┼── not met
         + OK      │        │       │
           │       │        v       v
           v       │      CAST   RETRY (loops)
         CAST <────┘
```

### Transitions

| From | To | Trigger |
|---|---|---|
| IDLE | CAST | Auto shot enabled, standing still, valid target |
| IDLE | RELOAD | Auto shot enabled but conditions not met (rare — usually enters CAST) |
| CAST | RELOAD | Cast completes (SPELL_CAST_SUCCESS) — arrow fires |
| CAST | RETRY | Interrupted: moved, started casting, lost target |
| RELOAD | CAST | Timer expires, player standing still, not casting, valid target |
| RELOAD | RETRY | Timer expires, conditions not met (moving, casting, no target) |
| RETRY | CAST | 0.5s passes, conditions now met |
| RETRY | RETRY | 0.5s passes, conditions still not met |
| any | IDLE | Auto shot disabled (STOP_AUTOREPEAT_SPELL) |
| any | full reset | Feign Death |

---

## What blocks/allows during each phase

| Action | During RELOAD | During CAST |
|---|---|---|
| Moving | OK | Interrupts → RETRY |
| Casting Aimed/Multi/Steady Shot | OK, reload keeps ticking | Interrupts → RETRY |
| Casting other spells (bandage, etc.) | OK, reload keeps ticking | Interrupts → RETRY |
| Losing target | OK, reload ticks | Interrupts (if server hasn't confirmed shot) |
| Feign Death | Full cycle reset | Full cycle reset |

The blocking is mutual:
- The ~0.5s auto shot cast blocks starting other spell casts.
- Other spell casts block auto shot from entering CAST phase.

When reload expires but the player is mid-Aimed Shot, auto shot waits.
The server retries every ~0.5s until the player finishes casting and
stands still.

---

## Clipping

Starting a spell cast when reload is almost done pushes auto shot back.

Example: reload has 0.2s left, player starts Multi-Shot (0.5s cast).
Auto shot would have fired in 0.2s but now waits until Multi-Shot
finishes + next 0.5s retry window.

---

## Haste

All timers scale with haste:
- Weapon speed: `UnitRangedDamage("player")` returns hasted speed
- Cast time: `baseCast * (hastedSpeed / baseWeaponSpeed)`
- Reload: `hastedSpeed - hastedCastTime`

Base weapon speed comes from the weapon tooltip (unhasted). The ratio
`hastedSpeed / baseSpeed` is the haste modifier applied to cast time.

---

## Feign Death

Resets the server's auto shot cycle entirely. The server discards
current cycle progress and starts fresh. Auto shot must be re-enabled
(player stands up / moves / jumps) before a new cycle begins.

---

## Events (WoW API)

| Event | What it tells us |
|---|---|
| START_AUTOREPEAT_SPELL | Auto shot enabled (IDLE → active) |
| STOP_AUTOREPEAT_SPELL | Auto shot disabled (but may be tab-target bounce — needs debounce) |
| UNIT_SPELLCAST_SUCCEEDED (Auto Shot) | Cast completed, arrow fired (CAST → RELOAD) |
| UNIT_SPELLCAST_FAILED_QUIET (Auto Shot) | Server tried to fire, conditions not met (→ RETRY) |
| UNIT_SPELLCAST_FAILED (Auto Shot) | Cast explicitly failed |
| CLEU SPELL_CAST_START (Auto Shot) | Server confirmed cast started (useful as fallback) |
| CLEU SPELL_CAST_START (Aimed/Multi/Steady) | Hunter spell cast started — blocks auto shot |
| CLEU SPELL_CAST_SUCCESS/FAILED (Aimed/Multi/Steady) | Hunter spell cast ended — unblocks auto shot |

---

## Open questions

- Does STOP_AUTOREPEAT_SPELL always need debouncing, or only on
  tab-target? Current implementation uses 0.5s debounce.
- Exact server retry interval: assumed 0.5s. Could vary with latency.
- Feign Death reset duration: current formula uses
  `elapsed + speed + RETRY_INTERVAL`. Needs in-game verification.
- Vanilla Aimed Shot: does not reset auto shot on cast start (unlike
  TBC). See classic-vs-tbc.md. Current code has TBC behavior.

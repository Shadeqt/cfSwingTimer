# Ranged Auto Shot: Investigation Notes

Investigation as of 2026-02-22 10:59.

For general ranged mechanics, see `ranged-mechanics.md`.

---

## State Diagram

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

## What Blocks/Allows During Each Phase

| Action | During RELOAD | During CAST |
|---|---|---|
| Moving | OK | Interrupts → RETRY |
| Casting Aimed/Multi Shot | OK, reload keeps ticking | Interrupts → RETRY |
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

## Open Questions

- Does STOP_AUTOREPEAT_SPELL always need debouncing, or only on
  tab-target? Current implementation uses 0.5s debounce.
- Exact server retry interval: assumed 0.5s. Could vary with latency.
- Feign Death reset duration: current formula uses
  `elapsed + speed + RETRY_INTERVAL`. Needs in-game verification.
- Vanilla Aimed Shot: does not reset auto shot on cast start (unlike
  TBC). See classic-vs-tbc.md. Current code has TBC behavior.
- UNIT_SPELLCAST_FAILED_QUIET: which scenarios actually delay the
  next shot vs being harmless noise? Needs systematic testing.

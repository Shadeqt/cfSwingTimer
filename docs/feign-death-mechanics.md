# Feign Death & Auto-Shot Recovery

## Summary

After Feign Death is cast, there is always a lockout before the next
auto-shot fires. The lockout scales with weapon speed. FD_END
(`MIRROR_TIMER_STOP`) is **not** a reliable reference point — in some
sessions the server holds FD active until the lockout expires, making
FD_END and CAST_START simultaneous. This is not "instant" behavior;
the lockout is still present, just hidden inside the FD duration.

**Status: Under investigation. Do not implement until mechanics are resolved.**

## Event Detection

- FD cast: `UNIT_SPELLCAST_SUCCEEDED` (spellId 5384)
- FD end: `MIRROR_TIMER_STOP` ("FEIGNDEATH")
- Note: `SPELL_AURA_REMOVED` does NOT fire for FD in Classic Anniversary

## Tested Weapons

| Weapon | Base Speed | Hasted Speed | Reload |
|--------|-----------|-------------|--------|
| B      | —         | 2.32s       | 1.87s  |
| C      | 3.40      | 2.96s       | 2.52s  |

## Lockout Data

### 2.32 weapon (FD_END → CAST_START, early tests)
- Range: 1.84–2.19s (mean ~2.06s, spread 0.35s)
- reload + tick analysis: offsets 0.07–0.36s (reasonable)
- speed + tick analysis: gives negative values (doesn't fit)
- Note: these sessions had FD_END fire early (visible gap after FD_END)

### 2.96 weapon — FD_END fires early (lockout visible after FD_END)
- FD_END → CAST_START range: 3.09–3.19s (4 clean samples)
- **Disproves flat 2.0s lockout** — clearly scales with weapon speed
- speed + tick analysis: offsets 0.13–0.23s (reasonable)

### 2.96 weapon — FD_END fires at lockout expiry (gap hidden inside FD)
- FD_END → CAST_START = 0.00s (FD_END and CAST fire on same timestamp)
- But SUCCEEDED(FD) → CAST_START reveals the real lockout:
- Range: 2.92–3.53s (11 samples across 2 sessions)
- START_AUTOREPEAT fires BEFORE FD_END in these cases, proving FD
  is still active while the lockout runs. FAILED_QUIET (skip) events
  occur between START_AUTOREPEAT and FD_END.
- The server holds FD active until the lockout expires, then dispatches
  FD_END and CAST_START together.

### 2.96 weapon — all data combined (SUCCEEDED(FD) → CAST_START)

| Session type | Samples | Range |
|-------------|---------|-------|
| FD_END early | 4 clean | 5.47–6.83s (but FD lasted 2.38–3.73s, so lockout from FD_END is 3.09–3.19s) |
| FD_END at expiry | 11 | 2.92–3.53s (lockout = full duration from FD cast) |

## Formula Candidates

### Flat 2.0s lockout
- Disproved by 2.96 weapon (3.09+ gaps)

### Reload + next server tick
- Works for 2.32 weapon (offsets 0.07–0.36s)
- Doesn't fit 2.96 weapon (offsets 0.56–0.90s — too high)

### Weapon speed + next server tick
- Works for 2.96 weapon (offsets 0.13–0.23s from FD_END-early data)
- Doesn't fit 2.32 weapon (gives negative values)

## Server Tick Pattern

Between FD_END and CAST_START (when FD_END fires early), the client
receives multiple `FAILED_QUIET` responses spaced ~0.5s apart.

Also observed DURING FD in the "FD_END at expiry" sessions:
START_AUTOREPEAT fires, then FAILED_QUIET (skip) events at ~0.5s
intervals until FD_END + CAST_START fire simultaneously.

Example with 2.32 weapon (T=223302.02):

```
FD_END    223302.02
FAIL 1    223302.02  (+0.00)
FAIL 2    223302.66  (+0.64)
FAIL 3    223303.15  (+0.49)
FAIL 4    223303.65  (+0.50)
CAST      223304.03  (+0.38)
```

## Open Questions

1. **Why does FD_END timing vary between sessions?** In some sessions
   FD_END fires early (visible lockout after), in others the server
   holds FD active until lockout expires. Same character/weapons.
   Both have the same underlying lockout — only the FD_END anchor differs.
2. In "FD_END early" sessions, the lockout is ~3.1s from FD_END.
   In "FD_END at expiry" sessions, the lockout is ~3.0–3.5s from FD cast.
   Are these the same formula with different anchors, or genuinely different?
3. Does the lockout formula depend on reload, weapon speed, or something else?
   Neither reload+tick nor speed+tick fits both weapon speeds cleanly.
4. The 2.32 weapon's lockout (~2.0s) happens to be close to weapon speed
   AND close to reload+tick. Need more weapon speeds to disambiguate.
5. Does server state (combat vs out-of-combat, target status) affect FD recovery?
6. FD broken by expiry (full 6min duration) — same behavior?

# Performance check

Baseline: `6b60162`. Both versions ran the same repeatable Lua 5.1
fixture workloads. CPU figures are medians of five samples on the same host.
Native API calls are mocked: these timings describe the Lua workloads, not
in-game frame rates or network latency.

| Workload | Metadata reads before → after | Inventory reads before → after | Item calculations before → after | CPU ms before → after |
|---|---:|---:|---:|---:|
| 2,000 menu projections | 12,000 → 6 | 0 → 0 | 0 → 0 | 70.3 → 64.7 |
| 100 unrelated addon loads | 3,800 → 0 | 3,800 → 0 | 0 → 0 | 45.1 → 8.8 |
| 1,000 unchanged spec snapshots | 0 → 0 | 0 → 0 | 8,000 → 0 | 268.7 → 15.1 |

The six remaining metadata reads are the first three items warming the cache.
Later projections of those item results require no further native metadata reads.

## Changes

- Move inspection data projection, enhancement coverage and bar ordering into
  `InspectionModel.lua`; keep frame creation, input and drawing in `InspectionPanel.lua`.
- Cache only complete native item metadata per item result. Failed reads retry,
  relevant item-data events invalidate cached values, and weak keys do not keep
  discarded item results alive. Invalidation stamps are capped at 512 item IDs.
- Reuse alternative-tree profiles across snapshots of the same talent profile.
  Existing intrinsic item/profile caches can then reuse their calculations;
  wearer-specific set counts and bonuses are still applied for each snapshot.
- Attach late-loading UI without rescanning complete equipment/talent data when
  unrelated addons load. Pending gear or unresolved talent APIs still retry.
  Login, equipment, talent, item-data and inspection events still refresh scores.
- Reuse enhancement classification for highlight labels, shared sort callbacks
  and record comparison field lists. Skip unchanged native hover colour updates.

## Validation

All 5,149 regression checks pass, and all 39 Lua files compile under Lua 5.1.
Added checks cover metadata reuse, corrected and late names, unrelated addon loads,
alternative-profile reuse across snapshots, late-data/API recovery and repeated
unchanged hover callbacks.
Scoring formulas, saved preferences, inspection cooldowns and visible features
are unchanged. No idle per-frame loop was added; minimap dragging remains the
only use of `OnUpdate`. Item-loading and inspection retries remain bounded.

## Reproduce

With Python and `lupa` installed, run from the repository root:

```sh
python3 FossieGearScore/tests/run_tests.py
python3 FossieGearScore/tests/benchmark_hot_paths.py --samples 5
```

To measure an older checkout using the same benchmark driver, pass
`--addon-root /path/to/older/checkout/FossieGearScore`. Call counts should be
repeatable; CPU timings vary between hosts. Native rendering, other addons and
actual client CPU/memory behaviour still need in-game profiling.

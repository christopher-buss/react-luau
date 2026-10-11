# Activity external-store reveal correctness

The mirror follows React commit
[`2860e00cf8780dc2d59b87f3ff28ac88b908660f`](https://github.com/facebook/react/commit/2860e00cf8780dc2d59b87f3ff28ac88b908660f)
([#36947](https://github.com/facebook/react/pull/36947)), included in React
`v19.3.0` at `1d34f91dfde6bba84d08b683aaba164c7194dacb`.

`updateSyncExternalStore` retains its passive `updateStoreInstance` effect on
every render. `HookHasEffect` still depends on changed snapshot, getter, or
subscription. Ordinary unchanged commits skip this effect; Activity reconnect
runs it and detects mutations missed while the subscription was disconnected.

## Prerequisites

The branch starts at fork `origin/main` `9351444`. Its prerequisite commits
retain the existing external-store port (`301dd93`), Suspense effects
(`9e6d492`), and Activity ledger, public roots, lifecycle, hidden callbacks, and
client semantics (`e27beae`, `355230c`, `8668948`, `e525471`, `eacef3e`).
The feature diff starts at `5dd316f`; these prerequisite imports are separate
commits. React 18 transitions are unnecessary for these two regressions and
remain outside this branch. The hidden-callback import omits the transition
queue's `lanes` field, which is absent in the selected base.

The current [React-Luau external-store PR #24](https://github.com/Roblox/react-luau/pull/24)
uses `47b379d952853bd0aef8e780f8715e263d5558a9`. Its tree equals `301dd93`
exactly; the selected prerequisite therefore retains its latest source and test
port. The PR has no review comments or review findings to carry forward.

## Source and test ledger

| Upstream source or test | React-Luau target | Port status | Deviation |
| --- | --- | --- | --- |
| `ReactFiberHooks.js` `HookNoFlags` import and `updateSyncExternalStore` | `modules/react-reconciler/src/ReactFiberHooks.new.lua` | Adapted | React 17 `pushEffect` stores the callback directly; there is no separate effect instance. Luau closure replaces JavaScript `bind`. Existing React 17 consistency-check scheduling remains. |
| `ReactFiberHooks.js` `updateStoreInstance` comment | Existing `updateStoreInstance` in the same target | Out of scope | The upstream hunk only fixes a comment typo and explains reveal; local behavior already matches. |
| `useSyncExternalStore-test.js` `detects store mutations from a layout effect while an Activity subtree is being revealed` | `modules/react-reconciler/src/__tests__/useSyncExternalStoreActivity.spec.lua` first case | Adapted | Explicit package imports, `createElement`, synchronous `ReactNoop.act`, and `Scheduler.toHaveYielded` replace JS imports, JSX, async internal-test-utils act, and assertLog. Names, order, rendered text, subscriber counts, and scheduling are preserved. |
| `useSyncExternalStore-test.js` `detects store mutations that happened while an Activity subtree was hidden, even if the subtree bails out of rendering when revealed` | Same target, second case | Adapted | Same mechanics; React.memo bailout, hidden mutation, empty log, reveal log, and rendered-output assertions are preserved. |
| `useSyncExternalStore-test.js` `Text` and `createExternalStore` helpers | Same target, suite helpers | Adapted | `Scheduler.unstable_yieldValue` replaces Scheduler.log. LuauPolyfill.Set represents JS Set and keeps batched listener notification. Unchanged unrelated upstream cases stay in their existing test port. |

## Verification

The isolated harness mounts this branch's `modules/*/src`, its own copied
`WorkspaceStatic/jest` matchers, and installed Jest-Lua/polyfill dependencies.
It never mounts Anime Rush's reconciler. The copy of the prior strict-effects
harness is generated with `.harness/gen.mjs <fork> <anime-rush>` from
`.harness`; the generated mapping, config, and artifacts are local and ignored.

Run the CLI with the installed direct Rojo executable on PATH, bypassing the
rokit shim that requires a manifest in this standalone checkout:

```powershell
$env:PATH = 'D:/packages/mise/installs/github-rojo-rbx-rojo/7.7.1;' + $env:PATH
node --env-file=<anime-rush>/.env <anime-rush>/node_modules/@isentinel/jest-roblox/bin/jest-roblox.js --config jest.config.json --backend open-cloud --no-coverage
```

The cloud runner pins each task to its uploaded place version. Its bootstrap
sets development mode and the mock Scheduler through ReactGlobals. Local
studio-cli execution cannot start because the independently launched Studio
is at its login screen; this is an execution prerequisite, not a test failure.

At baseline `5dd316f`, the first case fails the final reveal log
(`revision:1`, `revision:2`), and the second fails the final memoized reveal log
(`b:updated`). Earlier output and subscriber-count assertions pass in both.
The first runtime slice passes its one regression before adding the second.

The broader external-store run has 18 passes, three failures, and one skipped
case across 22 tests. Baseline `5dd316f` reproduces the same three failures
across its older 20-test suite (16 passes, one skipped): `defers unbatched
listener updates on a concurrent root`, `handles errors thrown while reading
the snapshot`, and `retries a consistency check that throws through an error
boundary`. The first expects older scheduling; the latter two reject the
existing warning-channel error log. These prerequisite-suite failures remain
outside the feature diff. Selene 0.31 checks the changed runtime and new suite
with zero errors or warnings. StyLua 2.2 checks both with `--syntax Luau`.

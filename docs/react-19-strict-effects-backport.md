# React 19 Strict Effects backport

This backport mirrors React 19 Strict Effects: in development, a fiber that
mounts inside a strict tree runs its layout effects, refs, and passive effects,
disconnects them all, and connects them again. Upstream source and tests are
the contract.

## Pin and dependency

- Upstream tag: `v19.3.0`
- Upstream commit: `1d34f91dfde6bba84d08b683aaba164c7194dacb`
- Source repository: `facebook/react`
- Required React-Luau base: `eacef3eb` (`backport-react-19-2-activity`), which
  stacks on the React 18 Suspense effects and transitions backports. Strict
  Effects reuses that branch's layout disappear/reappear and passive
  disconnect/reconnect traversals.

The behavior-bearing upstream chain:

- `9209c30ff98528cfbbe9df0774fda0b117975a25` — strict root option and levels
- `5d1ce651393524639a3b4b1e861a0413a4d25629` — double invoke through the
  disconnect/reconnect paths
- `987292815c68be0fd5916d1f9b0d6c983e2db7ce` — remove `enableStrictEffects`
- `811022232efed62a3c943701bc99d18655bc78b3` — always run
  `componentWillUnmount`
- `3d1da1f9ab7d54984c096e6a04c8729f3a50fd8a` — concurrent roots are not strict
  by default
- `74dd2da9ac4bf82ff1232694e971879bb07f37dc` — remove `enableModernStrictMode`
- `67e47593b607ecc08ac59361d8aba7ad2eef028a` — Offscreen `PlacementDEV` case
- `129154cedf159a4f4a76634889e98d06760278cc` — moved children do not double
  invoke

## Contract

- `TypeOfMode` has `StrictLegacyMode` and `StrictEffectsMode`. The single
  `StrictMode` bit is gone.
- A plain concurrent root is not strict. The `<StrictMode>` element, or the
  `unstable_strictMode` root option, adds both bits. Render double invocation
  therefore becomes opt-in too.
- In `__DEV__`, a newly placed fiber in a strict tree runs: mount, layout
  cleanup and ref detach, passive cleanup, layout mount and ref attach, passive
  mount. A visible Offscreen whose visibility changed does the same for its
  subtree. Production builds do not double invoke.
- Legacy roots never get `StrictEffectsMode`.

## Source ledger

| Upstream source or symbol | React-Luau target | Port status | Deviation |
| --- | --- | --- | --- |
| `ReactTypeOfMode.js` strict bits | `ReactTypeOfMode.lua` | Adapted | React 17 bit layout kept; `StrictLegacyMode` takes the old bit, `StrictEffectsMode` the next free bit. |
| `ReactFiberFlags.js` `PlacementDEV` | `ReactFiberFlags.lua` | Adapted | Next free bit in the React 17 layout. |
| `ReactFiber.js` `createHostRootFiber`, `REACT_STRICT_MODE_TYPE` | `ReactFiber.new.lua` | Adapted | React-Luau keeps blocking roots; they are strict only on request, and `BlockingMode` admits `StrictEffectsMode`. |
| `ReactFiberRoot.js`, `ReactFiberReconciler.js` `isStrictMode` | `ReactFiberRoot.new.lua`, `ReactFiberReconciler.new.lua` | Adapted | Appended after the existing `hydrate` and `hydrationCallbacks` parameters. |
| `ReactDOMRoot.js` `unstable_strictMode` | `ReactRobloxRoot.lua`, `ReactRobloxHostTypes.roblox.lua` | Direct | None. |
| `ReactTestRenderer.js` `unstable_strictMode` | `ReactTestRenderer.lua` | Direct | None. |
| `ReactChildFiber.js` `placeChild`, `placeSingleChild` | `ReactChildFiber.new.lua` | Direct | None. |
| `ReactFiberBeginWork.js` `remountFiber`, strict render readers | `ReactFiberBeginWork.new.lua` | Direct | Hydration `PlacementDEV` sites have no target. |
| `ReactFiberClassComponent.js` `MountLayoutDev` | `ReactFiberClassComponent.new.lua` | Direct | None. |
| `ReactFiberHooks.js` `mountEffect`, `mountLayoutEffect`, `mountImperativeHandle`, `bailoutHooks` | `ReactFiberHooks.new.lua` | Direct | None. |
| `ReactFiberCommitWork.js` `disappearLayoutEffectsForDEVValidation`, `reappearLayoutEffectsForDEVValidation` | `ReactFiberCommitWork.new.lua` | Adapted | Wrap the existing recursive walks. `reappearLayoutEffects` gains `includeWorkInProgressEffects`; `nil` keeps the Suspense and Activity callers. |
| `ReactFiberCommitWork.js` `disconnectPassiveEffect`, `reconnectPassiveEffects` | `ReactFiberCommitWork.new.lua` | Adapted | The Activity walks move to module scope and are shared. Hidden Activity Offscreen fibers stop both walks. |
| `ReactFiberCommitWork.js` `invoke*InDEV` | `ReactFiberCommitWork.new.lua` | Direct | `__DEV__` gate only. |
| `ReactFiberWorkLoop.js` `doubleInvokeEffectsInDEVIfNecessary` and helpers | `ReactFiberWorkLoop.new.lua` | Adapted | `Update` stands in for `Visibility`; no `runWithFiberInDEV` (the debug fiber is set and reset); no `setIsStrictModeForDevtools`; functions live on `mod` to stay under the Luau 200-local limit; recursive `invokeEffectsInDev`. |
| `ReactFiberUpdateQueue`, `ReactStrictModeWarnings`, act warning, `findDOMNode` warning readers | Matching modules | Direct | Read `StrictLegacyMode`. |
| `shared/ReactFeatureFlags.js` | `ReactFeatureFlags.lua` | Direct | `enableDoubleInvokingEffects` removed; React 19 has no Strict Effects flag. |
| `ReactFiberDevToolsHook.js` `setIsStrictModeForDevtools` and console dimming | No target | Out of scope | React 19 console dimming is excluded. Logs are not silenced during the double invocation. |
| Hydration double invoke | No target | Out of scope | ReactRoblox does not hydrate. |

## Test ledger

### `StrictEffectsMode-test.js` → `StrictEffectsMode.spec.lua`

All 15 cases in upstream order. Translation: `ReactNoop.act`, `table.insert`
logs, `PureComponent:extend`, explicit `"root"` IDs where upstream omits one.

| Upstream test | Port status | Deviation |
| --- | --- | --- |
| `should double invoke effects after a re-suspend` | Skipped | React-Luau keeps React 17 Suspense timing: a default update that re-suspends visible content waits for the fallback timeout. The upstream log needs React 18's immediate fallback commit. |
| Every other case | Direct | None. |

### `StrictEffectsModeDefaults-test.internal.js` → `StrictEffectsModeDefaults-internal.spec.lua`

All 14 cases. `waitFor`, `waitForAll`, and `waitForPaint` map to
`toFlushAndYieldThrough`, `toFlushAndYield`, and `toFlushUntilNextPaint`.

| Upstream test | Port status | Deviation |
| --- | --- | --- |
| Two cases that read `Scheduler.log` during the double invoke | Adapted | Upstream silences `Scheduler.log` while it double invokes. React-Luau does not, so the yields include the double invocation. |
| `disconnects refs during double invoking` | Adapted | `toHaveBeenNthCalledWith(2, nil)`; Jest-Lua records a nil mock argument as a placeholder. |
| Every other case | Direct | None. |

### `ActivityStrictMode-test.js` → `ActivityStrictMode.spec.lua`

All five cases. `should double invoke effects on unsuspended child` drops the
upstream sibling pre-warming render; React-Luau has no sibling prewarming.

### `ReactStrictMode-test.internal.js` → `react/src/__tests__/ReactStrictMode-internal.spec.lua`

All five `levels` cases through `ReactRoblox.createRoot`. The stray `","` text
children of the upstream JSX are omitted; ReactRoblox has no text instances.

### `ReactStrictMode-test.js`

| Upstream test | Port status | Deviation |
| --- | --- | --- |
| `console logs logging` › `does not disable logs for effect double invoke` | Adapted | Appended to `ReactStrictMode.spec.lua`; ReactRoblox replaces ReactDOM. |
| Other `console logs logging` cases | Out of scope | They need React 19 render-phase console behavior. |
| Remaining cases | Base behavior | Already ported from an older pin; unchanged. |

### Existing suites

React-Luau's React 17 suites expected the old strict concurrent root: double
render logs, strict-mode lifecycle and legacy-context warnings, and act effect
warnings. `ReactComponentLifeCycle`, `ReactComponentLifeCycle.roblox`,
`DebugTracing-test.internal`, `ReactHooksWithNoopRenderer`, `ReactIncremental`,
`ReactIncrementalReflection`, `ReactIncrementalUpdates`, `ReactNewContext`,
`ReactStrictMode`, and `forwardRef` now expect the upstream React 18+ result,
where a plain concurrent root is not strict. `ReactStrictMode`'s precommit
cases use a legacy root, and its Concurrent Mode warning cases render inside
`StrictMode`, as upstream does.

## Verification

The repository's Foreman harness (`rotrieve`, `robloxdev-cli`) is unavailable.
The suites run through `jest-roblox` on Open Cloud from a local Rojo harness
that mounts each module beside Jest-Lua 3.16. That harness is not committed.
Its baseline at `eacef3eb` already fails in `Activity`, `ActivityErrorStacks`,
`ActivityLegacySuspense`, `ReactComponentLifeCycle.roblox` naming conventions,
`ReactLazy-internal`, `ReactSuspenseEffectsSemantics`, `ReactTransition`,
`ReactStartTransition`, and the ReactRoblox `Activity` suite. This backport
adds no failure to that set.

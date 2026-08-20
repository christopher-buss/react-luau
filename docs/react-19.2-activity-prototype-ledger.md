# React 19.2 Activity prototype ledger

This branch answers one question: can React-Luau expose a client-only
`React.Activity` whose hidden trees retain state, hide their host instances,
disconnect effects, render hidden updates at offscreen priority, and contain
Suspense without importing React's server architecture?

The prototype is deliberately throwaway. It is not a complete Activity
backport and does not belong on `main` without a new full-backport review.

## Pin and dependency

- Upstream tag: `v19.2.0`
- Upstream commit: `ae74234eae6ebd62f19190731278e20bc1c37d51`
- Source repository: `facebook/react`
- Required React-Luau base: the green React 18 Suspense effect-semantics
  backport, before any implementation in this branch

The public acceptance seam is `React.Activity`, rendered through
`ReactRoblox.createRoot`. The standalone contract is translated from the
upstream reconciler tests and observed through the renderer's public root.

## Scope

The prototype includes:

- `mode="visible"` and `mode="hidden"`
- preserved component state across visible, hidden, and visible transitions
- host subtree hide and reveal
- layout-effect disappear and reappear behavior
- passive-effect disconnect and reconnect behavior
- offscreen-priority initial rendering and hidden updates
- Suspense containment inside a hidden Activity
- nested Activity visibility and effect behavior needed by the representative
  contracts

The prototype excludes:

- Fizz and all server rendering
- hydration and dehydrated Activity boundaries
- RSC, Server Components, and Flight
- Activity hydration callbacks and host-config Activity instances
- selective hydration, replay, hydration errors, and hydration lanes
- DOM-specific hidden attributes and persistence renderers
- transition tracing, cache pools, View Transitions, performance tracks, and
  gesture transitions
- `use`, sibling prerendering, and React 19 promise instrumentation
- production-ready Strict Effects support; the suite remains a reviewed
  contract, but React-Luau's Strict Effects runtime is separately disabled
- `unstable_LegacyHidden` modernization

## Client source ledger

| Upstream source or symbol | React-Luau target | Port status | Deviation |
| --- | --- | --- | --- |
| `packages/shared/ReactSymbols.js` — `REACT_ACTIVITY_TYPE` | `modules/shared/src/ReactSymbols.lua` | Adapted | React-Luau uses numeric symbols, not `Symbol.for`. |
| `packages/shared/ReactTypes.js` — `ActivityProps` | `modules/shared/src/ReactTypes.lua` | Adapted | Luau uses optional fields and `React_Node`; `name` has no client behavior and is omitted. |
| `packages/shared/getComponentNameFromType.js` — Activity name | `modules/shared/src/getComponentName.lua` | Direct | The public symbol reports `Activity`. |
| `packages/shared/isValidElementType.js` — intrinsic type validation | `modules/shared/src/isValidElementType.lua` | Direct | The Activity symbol is a valid element type. |
| `packages/react/src/ReactClient.js` — `Activity` export | `modules/react/src/React.lua` | Direct | The export uses the React-Luau symbol table. |
| `packages/react/index.stable.development.js` and `packages/react/index.stable.js` — package export | `modules/react/src/init.lua`, `modules/react/src/React.lua` | Adapted | React-Luau has one Rojo package entry rather than generated JS bundles. |
| `packages/react-reconciler/src/ReactWorkTags.js` — `ActivityComponent` | `modules/react-reconciler/src/ReactWorkTags.lua` | Prototype adaptation | A distinct tag is retained only if the client wrapper is needed; otherwise the public symbol maps directly to the existing Offscreen tag and this deviation is documented beside the mapping. |
| `packages/react-reconciler/src/ReactFiber.js` — `createFiberFromActivity` and type dispatch | `modules/react-reconciler/src/ReactFiber.new.lua` | Adapted | Hydration state and Activity instances are excluded. |
| `packages/react-reconciler/src/ReactFiberBeginWork.js` — `mountActivityChildren` and client path of `updateActivityComponent` | `modules/react-reconciler/src/ReactFiberBeginWork.new.lua` | Adapted | The hydration branches are excluded. Client behavior delegates to the existing Offscreen implementation. |
| `packages/react-reconciler/src/ReactFiberBeginWork.js` — `updateOffscreenComponent`, `deferHiddenOffscreenComponent` | `modules/react-reconciler/src/ReactFiberBeginWork.new.lua` | Existing dependency plus adaptation | React-Luau already defers hidden trees with `OffscreenLane`; React 19 cache pools, transition tracing, hidden context, and atomic hidden-update entanglement are not present. |
| `packages/react-reconciler/src/ReactFiberOffscreenComponent.js` — state and visibility bits | `modules/react-reconciler/src/ReactFiberOffscreenComponent.lua` | Adapted | Add only the passive-effects-connected bit needed by the client prototype; cache, tracing, and retry fields stay out of scope. |
| `packages/react-reconciler/src/ReactFiberCompleteWork.js` — Activity completion and Offscreen `Visibility` marking | `modules/react-reconciler/src/ReactFiberCompleteWork.new.lua` | Existing dependency plus adaptation | Dehydrated Activity completion is excluded. Existing Offscreen visibility scheduling remains the client mechanism. |
| `packages/react-reconciler/src/ReactFiberCommitWork.js` — `disappearLayoutEffects` and `reappearLayoutEffects` | `modules/react-reconciler/src/ReactFiberCommitWork.new.lua` | Base dependency | Supplied by the React 18 Suspense effect-semantics backport on which this prototype is stacked. |
| `packages/react-reconciler/src/ReactFiberCommitWork.js` — `disconnectPassiveEffect` and `reconnectPassiveEffects` | `modules/react-reconciler/src/ReactFiberCommitWork.new.lua` | Adapted | Port only hook/class traversal needed by React-Luau. Profiler, cache, tracing, host-resource, and View Transition cases are excluded. |
| `packages/react-reconciler/src/ReactFiberCommitWork.js` — Offscreen passive mount/unmount branches | `modules/react-reconciler/src/ReactFiberCommitWork.new.lua` | Adapted | Visibility state is stored on the existing Offscreen state node or an equivalent client-only marker. |
| `packages/react-reconciler/src/ReactFiberCommitWork.js` — `hideOrUnhideAllChildren` | `modules/react-reconciler/src/ReactFiberCommitWork.new.lua` | Existing dependency | ReactRoblox host hiding uses its existing renderer callbacks rather than DOM hidden attributes. |
| `packages/react-reconciler/src/ReactFiberCommitEffects.js` — class hidden callbacks | `modules/react-reconciler/src/ReactFiberCommitWork.new.lua`, `modules/react-reconciler/src/ReactFiberClassComponent.new.lua` | Out of prototype scope | Representative prototype behavior uses function components; deferral of class `setState` callbacks remains a known missing semantic. |
| `packages/react-reconciler/src/ReactFiberClassUpdateQueue.js` — hidden callback queues and hidden lane stripping | `modules/react-reconciler/src/ReactUpdateQueue.new.lua` | Out of prototype scope | React-Luau lacks React 19's atomic hidden-update queue model. |
| `packages/react-reconciler/src/ReactFiberConcurrentUpdates.js` — mark updates under hidden Offscreen | `modules/react-reconciler/src/ReactFiberWorkLoop.new.lua` and update queues | Out of prototype scope | The prototype demonstrates existing `OffscreenLane` deferral but does not claim React 19 anti-tearing guarantees for concurrent hidden updates. |
| `packages/react-reconciler/src/ReactFiberLane.js` and `ReactFiberRoot.js` — `hiddenUpdates`, `markHiddenUpdate`, lane restoration | `modules/react-reconciler/src/ReactFiberLane.lua`, `ReactFiberRoot.new.lua` | Out of prototype scope | The existing React 17 Offscreen lane is retained; the root hidden-update map is not backported. |
| `packages/react-reconciler/src/ReactFiberHiddenContext.js` — base-lane entanglement | No direct target | Out of prototype scope | React-Luau's React 17 renderer carries Offscreen base lanes without React 19's hidden-context stack. |
| `packages/react-reconciler/src/ReactFiberNewContext.js` — deferred-tree context propagation | `modules/react-reconciler/src/ReactFiberNewContext.new.lua` | Existing React 17 behavior | No React 19 context-propagation rewrite is included. |
| `packages/react-reconciler/src/ReactFiberSuspenseContext.js` — hidden Offscreen as Suspense handler | `modules/react-reconciler/src/ReactFiberSuspenseContext.new.lua` | Adapted | Port the client hidden-tree handler only. Shell-boundary policy and dehydrated Activity handling are excluded. |
| `packages/react-reconciler/src/ReactFiberThrow.js` — Offscreen capture | `modules/react-reconciler/src/ReactFiberThrow.new.lua` | Adapted | Use the Offscreen child as the capture boundary; dehydrated Activity capture is excluded. |
| `packages/react-reconciler/src/ReactFiberUnwindWork.js` — Offscreen stack unwind | `modules/react-reconciler/src/ReactFiberUnwindWork.new.lua` | Existing dependency | No Activity hydration stack is added. |
| `packages/react-reconciler/src/getComponentNameFromFiber.js` and `ReactFiberComponentStack.js` — Activity frames | `modules/shared/src/getComponentName.lua`, `modules/react-reconciler/src/ReactFiberComponentStack.lua` | Adapted | A direct-Offscreen prototype reports the public element as Activity where representable; exact internal stack parity is not required. |
| `packages/react-reconciler/src/ReactFiberWorkLoop.js` — Strict Effects traversal for Activity/Offscreen | `modules/react-reconciler/src/ReactFiberWorkLoop.new.lua` | Out of prototype scope | React-Luau disables double-invoked effects; this remains a separate backport decision. |
| `packages/react-reconciler/src/ReactFiberActivityComponent.js` — dehydrated Activity state | No target | Out of scope | The file is entirely hydration state. |
| `packages/react-reconciler/src/ReactFiberCommitHostEffects.js` — hydrated Activity callback | No target | Out of scope | ReactRoblox has no Activity hydration instance. |
| `packages/react-reconciler/src/ReactFiberHydrationContext.js`, `ReactFiberHydrationDiffs.js`, `ReactFiberReconciler.js`, `ReactInternalTypes.js`, and `forks/ReactFiberConfig.custom.js` — Activity hydration plumbing | No target | Out of scope | Hydration, dehydrated Activity instances, and hydration callbacks are deliberately excluded. |
| `packages/react-reconciler/src/ReactFiberConfigWithNoHydration.js` — unsupported Activity host methods | No target | Out of scope | No server/hydration API is introduced. |

## Test ledger

The relevant upstream suites are read from the pinned commit. Representative
cases are ported red to green; omitted cases remain named here so the prototype
cannot be mistaken for a full backport.

### `Activity-test.js`

| Upstream test | React-Luau target | Port status | Deviation |
| --- | --- | --- | --- |
| `unstable-defer-without-hiding should never toggle the visibility of its children` | Existing LegacyHidden suites | Out of scope | LegacyHidden is not the prototype subject. |
| `does not defer in legacy mode` | Existing LegacyHidden suites | Out of scope | Legacy roots are not the acceptance seam. |
| `does defer in concurrent mode` | Activity prototype reconciler suite | Adapted | Uses Activity hidden mode through a concurrent root and the existing Offscreen scheduler log. |
| `mounts without layout effects when hidden` | Activity prototype reconciler suite | Direct | Depends on the Suspense effect-semantics base. |
| `mounts/unmounts layout effects when visibility changes (starting visible)` | Activity prototype reconciler suite | Direct | Representative layout lifecycle contract. |
| `nested offscreen does not call componentWillUnmount when hidden` | Ledger only | Out of prototype scope | Class lifecycle regression remains required for a full backport. |
| `mounts/unmounts layout effects when visibility changes (starting hidden)` | Activity prototype reconciler suite | Direct | Representative initial-hidden contract. |
| `hides children of offscreen after layout effects are destroyed` | Activity prototype reconciler suite | Direct | Verifies commit ordering through the renderer. |
| `does not toggle effects for LegacyHidden component` | Existing LegacyHidden suites | Out of scope | LegacyHidden is unchanged. |
| `hides new insertions into an already hidden tree` | Activity prototype renderer suite | Direct | ReactRoblox host instances replace Noop host nodes. |
| `hides updated nodes inside an already hidden tree` | Activity prototype renderer suite | Adapted | ReactRoblox host properties replace the Noop `hidden` prop. |
| `revealing a hidden tree at high priority does not cause tearing` | Ledger only | Out of prototype scope | Requires React 19's root hidden-update map and lane entanglement. |
| `regression: Activity instance is sometimes null during setState` | Ledger only | Out of scope | The client-only prototype has no public Activity instance Fiber. |
| `class component setState callbacks do not fire until tree is visible` | Ledger only | Out of prototype scope | Hidden class callback queues are not included. |
| `does not call componentDidUpdate when reappearing a hidden class component` | Ledger only | Out of prototype scope | Function-component acceptance seam only. |
| `when reusing old components (hidden -> visible), layout effects fire with same timing as if it were brand new` | Activity prototype reconciler suite | Adapted | Representative sibling ordering case. |
| `when reusing old components (hidden -> visible), layout effects fire with same timing as if it were brand new (includes setState callback)` | Ledger only | Out of prototype scope | Class hidden callbacks are excluded. |
| `defer passive effects when prerendering a new Activity tree` | Activity prototype reconciler suite | Direct | Representative initial-hidden passive contract. |
| `do not defer passive effects when prerendering a new LegacyHidden tree` | Existing LegacyHidden suites | Out of scope | LegacyHidden is unchanged. |
| `passive effects are connected and disconnected when the visibility changes` | Activity prototype reconciler suite | Direct | Representative passive lifecycle contract. |
| `passive effects are unmounted on hide in the same order as during a deletion: parent before child` | Activity prototype reconciler suite | Direct | Parent-before-child disconnect ordering is required. |
| skipped `don't defer passive effects when prerendering in a tree whose effects are already connected` | Ledger only | Out of scope | Upstream also skips this contract. |
| `does not mount effects when prerendering a nested Activity boundary` | Activity prototype reconciler suite | Direct | Representative nested hidden tree contract. |
| `reveal an outer Activity boundary without revealing an inner one` | Activity prototype reconciler suite | Direct | Representative nested reveal contract. |
| `insertion effects are not disconnected when the visibility changes` | Ledger only | Out of prototype scope | React-Luau does not expose `useInsertionEffect`. |
| `warns if you pass a hidden prop` | Ledger only | Out of prototype scope | Diagnostic parity is not needed to answer feasibility. |

### `ActivitySuspense-test.js` and `ActivityLegacySuspense-test.js`

The suites contain the same eight behaviors. The legacy suite throws a custom
thenable and is the translation source because React-Luau does not expose
React 19's `use` hook.

| Upstream test | React-Luau target | Port status | Deviation |
| --- | --- | --- | --- |
| `basic example of suspending inside hidden tree` | Activity prototype reconciler suite | Adapted | Throws a React-Luau-compatible thenable. |
| `LegacyHidden does not handle suspense` | Existing LegacyHidden coverage | Out of scope | Activity behavior is compared conceptually; LegacyHidden is unchanged. |
| `Regression: Suspending on hide should not infinite loop.` | Activity prototype reconciler suite | Adapted | Use the available internal `act` equivalent. |
| `suspending inside currently hidden tree that's switching to visible` | Activity prototype reconciler suite | Adapted | Prewarming-specific React 19 log entries are omitted. |
| `suspending inside currently visible tree that's switching to hidden` | Activity prototype reconciler suite | Adapted | Prewarming-specific React 19 log entries are omitted. |
| `update that suspends inside hidden tree` | Activity prototype reconciler suite | Adapted | Throws a custom thenable. |
| `updates at multiple priorities that suspend inside hidden tree` | Ledger only | Out of prototype scope | Full parity requires React 19 hidden-update lane bookkeeping. |
| `detect updates to a hidden tree during a concurrent event` | Ledger only | Out of prototype scope | This is the explicit atomic hidden-update/anti-tearing contract omitted by the prototype. |

### `ActivityStrictMode-test.js`

| Upstream test | React-Luau target | Port status | Deviation |
| --- | --- | --- | --- |
| `should trigger strict effects when offscreen is visible` | Ledger only | Out of prototype scope | React-Luau's Strict Effects double invocation is disabled. |
| `should not trigger strict effects when offscreen is hidden` | Ledger only | Out of prototype scope | React-Luau's Strict Effects double invocation is disabled. |
| `should not cause infinite render loop when StrictMode is used with Suspense and synchronous set states` | Existing Suspense/StrictMode coverage | Base dependency | The Suspense backport owns this regression surface. |
| `should double invoke effects on unsuspended child` | Ledger only | Out of prototype scope | React 19 prewarming and Strict Effects are both excluded. |

### Effect-semantics dependency

`ReactSuspenseEffectsSemantics-test.js` is the upstream contract for layout
effect disappear/reappear and ref behavior. The stacked React 18 Suspense
backport owns that suite and its runtime implementation. The Activity prototype
reuses those lifecycle walkers and adds Activity-specific passive effect tests;
it does not duplicate the base suite.

`StrictEffectsMode-test.js` is reviewed because Activity has distinct Strict
Effects traversal rules. It is not ported in this prototype because the shared
React-Luau Strict Effects flag is disabled and enabling it is a separate
backport.

## Prototype exit criteria

The prototype is feasible only if all of these are observable through a public
concurrent root:

1. A stateful child keeps the same state across visible, hidden, and visible.
2. ReactRoblox host instances leave and return to the visible host tree without
   remounting component state.
3. Layout effects disconnect before host hiding and reconnect after reveal.
4. Passive effects disconnect parent before child and reconnect on reveal.
5. Initial hidden work and a hidden update are scheduled after visible work at
   the existing Offscreen priority.
6. A thrown thenable inside hidden Activity does not replace visible sibling UI
   with the parent Suspense fallback.

Passing these criteria proves the client-only design is technically viable. It
does not prove the omitted React 19 anti-tearing, class callback, Strict Effects,
or hydration contracts.

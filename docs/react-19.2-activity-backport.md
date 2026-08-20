# React 19.2 client Activity backport

This backport mirrors the client behavior of `React.Activity` that can run in
React-Luau and ReactRoblox. Upstream source and tests are the contract. Server,
hydration, DOM, and features that React-Luau does not expose remain explicit
capability exclusions rather than reconstructed substitutes.

## Pin and dependency

- Upstream tag: `v19.2.0`
- Upstream commit: `ae74234eae6ebd62f19190731278e20bc1c37d51`
- Source repository: `facebook/react`
- Required React-Luau base: `9e6d492861d2473c95bf5046e3f26165c7caf410`
  (`React 18 Suspense effects`)

The public seam is `React.Activity` rendered through a concurrent public root.
The standalone suites use ReactNoop for exact scheduler observations and
ReactRoblox for host behavior.

The behavior-bearing upstream chain is pinned to:

- `0412f0c1a46ef60032b70c43d55ec010f908855f` — Offscreen state node
- `419cc9c3799bc296c3c2a2c93880826aca680886` — hidden insertions and updates
- `a10a9a6b5b891dd3ce238bf39a6147bb0f3a1d2a` — host hide ordering
- `79f54c16dc3d5298e6037df75db2beb3552896e9` — hidden-update anti-tearing
- `82e9e9909876591dbe808cdac7110610e63c3896` — hidden Suspense capture
- `c3d7a7e3d72937443ef75b7e29335c98ad0f1424` — deleted Activity update safety
- `5e4e2dae0ba1836d26fa4e5edb4475d3b3e0a60c` — hidden class callbacks
- `cfb6cfa25031992569a328530b4fb8612a5d377b` — reappear commit ordering
- `4ea064eb0915b355b584bff376e90dbae0e8b169` — initial hidden passive effects
- `80f3d88190c07c2da11b5cac58a44c3b90fbc296` — passive visibility changes
- `ab075a232409ea1f566526c6a5dca30f658280de` — initial hidden layout effects
- `4bd245e9ee22458bcd5b68524c47eaaab2cf2058` — nested layout effects
- `d1e35c70398a3341d2e090d09a0863c7fe6c3325` — layout disappear gating
- `d3d4d3a46b014ab0f6edc443c19fcdba09105f20` — insertion effects
- `539bbdbd86d9cd342aabde4cb08e398751789103` — hidden-prop diagnostic
- `68f00c901c05e3a91f6cc77b660bc2334700f163` — stable Activity export

## Capability boundary

The shipped contract includes:

- visible and hidden modes, including the visible default
- preserved component state and host identity
- hidden initial rendering and updates at Offscreen priority
- atomic hidden-update classification and reveal anti-tearing
- layout and passive effect disconnect/reconnect ordering
- deferred class callbacks and reappear lifecycle ordering
- hidden Suspense capture, retry, and multiple-priority updates
- nested Activity visibility semantics
- Activity component names in stacks and development diagnostics

The renderer does not implement:

- Fizz, server rendering, RSC, Flight, or server exports
- hydration, selective hydration, replay, or dehydrated Activity boundaries
- DOM fragment refs, DOM events, hidden attributes, or persistence renderers
- `use`, React 19 promise instrumentation, or sibling prewarming
- `useInsertionEffect`, Strict Effects double invocation, cache pools,
  transition tracing, profiler tracks, resources, View Transitions, or gestures
- React Refresh behavior

Those exclusions follow missing renderer or public capabilities. They do not
remove any client Activity behavior that React-Luau can express.

## Client source ledger

| Upstream source or symbol | React-Luau target | Port status | Deviation |
| --- | --- | --- | --- |
| `shared/ReactSymbols.js`, `ReactTypes.js`, `getComponentNameFromType.js`, `isValidElementType.js` | Matching files in `modules/shared/src` | Adapted | Numeric symbols and Luau types replace JavaScript symbols and Flow. |
| `react/src/ReactClient.js` and stable index exports | `modules/react/src/React.lua` and `init.lua` | Adapted | React-Luau has one Rojo entry point. |
| `ReactFiber.js` Activity dispatch | `ReactFiber.new.lua` | Adapted | Activity maps to the existing Offscreen Fiber. Upstream used this client shape before adding a wrapper solely for partial hydration. |
| `ReactWorkTags.js` `ActivityComponent` wrapper | No client target | Out of scope | The separate React 19 tag owns dehydrated Activity state; ReactRoblox has no hydration. |
| `ReactFiberActivityComponent.js` | No target | Out of scope | The file contains dehydrated Activity state only. |
| `ReactFiberBeginWork.js` Offscreen client path | `ReactFiberBeginWork.new.lua` | Adapted | Existing React 17 Offscreen base lanes are retained; cache and tracing state are absent. |
| `ReactFiberOffscreenComponent.js` instance visibility | `ReactFiberOffscreenComponent.lua` and `ReactFiber.new.lua` | Adapted | The instance stores only client visibility and retry state needed by the available renderer. |
| `ReactFiberConcurrentUpdates.js` hidden classification | `ReactFiberWorkLoop.new.lua`, hook and class enqueue paths | Adapted | React-Luau's older reconciler has no split concurrent-update module, so equivalent atomic classification stays in its existing scheduling seam. |
| `ReactFiberHooks.js` hidden update lane stripping | `ReactFiberHooks.new.lua` | Direct | Hidden updates disregard added base lanes until their outer lane commits. |
| `ReactFiberClassUpdateQueue.js` hidden lanes and callbacks | `ReactUpdateQueue.new.lua` | Adapted | React-Luau's class queue stores update objects rather than separate callback arrays. |
| `ReactFiberLane.js`, `ReactFiberRoot.js` hidden update map | `ReactFiberLane.lua`, `ReactFiberRoot.new.lua`, `ReactInternalTypes.lua` | Adapted | The existing 31-bit lane layout and zero-indexed lane maps are preserved. |
| `ReactFiberHiddenContext.js` base lanes | Existing Offscreen state and render-lane stack | Adapted | Only the lane behavior exercised by the client suites is ported; cache context is absent. |
| `ReactFiberCompleteWork.js` visibility scheduling | `ReactFiberCompleteWork.new.lua` | Adapted | Existing React-Luau flags remain numerically stable. |
| `ReactFiberCommitWork.js` layout, passive, class, and host traversals | `ReactFiberCommitWork.new.lua` | Adapted | Profiler, cache, tracing, resource, and View Transition cases are excluded. |
| `ReactFiberSuspenseContext.js`, `ReactFiberThrow.js`, `ReactFiberUnwindWork.js` | Matching reconciler modules | Adapted | A hidden Activity Offscreen Fiber is the client capture boundary. |
| `getComponentNameFromFiber.js`, `ReactFiberComponentStack.js` | Shared name lookup and `ReactFiberComponentStack.lua` | Adapted | The public Activity element type supplies the built-in frame. |
| `ReactFiberWorkLoop.js` Strict Effects traversal | No Activity delta | Out of scope | React-Luau disables Strict Effects double invocation globally. |
| `ReactFiberCommitWork.js` insertion-effect visibility behavior | No target | Out of scope | React-Luau does not expose `useInsertionEffect`. |
| Hydration, reconciler Activity instances, DOM event replay, and host hydration config | No target | Out of scope | ReactRoblox has no hydration architecture. |

## Test ledger

Port status describes the required translation. Gate results are recorded only
after each test has run red and green.

### `Activity-test.js`

| Upstream test | Port status | Deviation |
| --- | --- | --- |
| `unstable-defer-without-hiding should never toggle the visibility of its children` | Direct | Preserve the LegacyHidden comparison. |
| `does not defer in legacy mode` | Direct | Preserve the legacy-root contract. |
| `does defer in concurrent mode` | Direct | Preserve scheduler ordering. |
| `mounts without layout effects when hidden` | Direct | Owned by the Suspense-effects base plus Activity visibility. |
| `mounts/unmounts layout effects when visibility changes (starting visible)` | Direct | None. |
| `nested offscreen does not call componentWillUnmount when hidden` | Direct | None. |
| `mounts/unmounts layout effects when visibility changes (starting hidden)` | Direct | None. |
| `hides children of offscreen after layout effects are destroyed` | Direct | ReactNoop observes hidden state; ReactRoblox separately observes parenting. |
| `does not toggle effects for LegacyHidden component` | Direct | Preserve the comparison. |
| `hides new insertions into an already hidden tree` | Direct | None. |
| `hides updated nodes inside an already hidden tree` | Direct | None. |
| `revealing a hidden tree at high priority does not cause tearing` | Direct | Requires root hidden-update bookkeeping. |
| `regression: Activity instance is sometimes null during setState` | Adapted | The direct Offscreen client instance replaces the hydration wrapper instance. |
| `class component setState callbacks do not fire until tree is visible` | Direct | None. |
| `does not call componentDidUpdate when reappearing a hidden class component` | Direct | None. |
| `when reusing old components (hidden -> visible), layout effects fire with same timing as if it were brand new` | Direct | None. |
| Same test including a `setState` callback | Direct | None. |
| `defer passive effects when prerendering a new Activity tree` | Direct | None. |
| `do not defer passive effects when prerendering a new LegacyHidden tree` | Direct | Preserve the comparison. |
| `passive effects are connected and disconnected when the visibility changes` | Direct | None. |
| `passive effects are unmounted on hide in the same order as during a deletion: parent before child` | Direct | None. |
| Skipped `don't defer passive effects when prerendering in a tree whose effects are already connected` | Direct | Preserve the upstream skip and name. |
| `does not mount effects when prerendering a nested Activity boundary` | Direct | None. |
| `reveal an outer Activity boundary without revealing an inner one` | Direct | None. |
| `insertion effects are not disconnected when the visibility changes` | Out of scope | `useInsertionEffect` is not a React-Luau API. |
| `warns if you pass a hidden prop` | Adapted | Jest-Lua console capture replaces `assertConsoleErrorDev`. |

### Suspense suites

`ActivityLegacySuspense-test.js` is the direct translation source because it
throws a custom thenable. `ActivitySuspense-test.js` repeats the same eight
behaviors through React 19 `use` and adds promise/prewarming logs that
React-Luau cannot express.

| `ActivityLegacySuspense-test.js` test | Port status | Deviation |
| --- | --- | --- |
| `basic example of suspending inside hidden tree` | Adapted | Luau thenable and scheduler helpers only. |
| `LegacyHidden does not handle suspense` | Adapted | Preserve the comparison. |
| `Regression: Suspending on hide should not infinite loop.` | Adapted | Use the available public `act`. |
| `suspending inside currently hidden tree that's switching to visible` | Adapted | React 19 prewarming logs are absent. |
| `suspending inside currently visible tree that's switching to hidden` | Adapted | React 19 prewarming logs are absent. |
| `update that suspends inside hidden tree` | Adapted | Luau thenable only. |
| `updates at multiple priorities that suspend inside hidden tree` | Adapted | Preserve the lane ordering. |
| `detect updates to a hidden tree during a concurrent event` | Adapted | Preserve the atomic anti-tearing assertion. |

### Strict and adjacent suites

| Upstream suite and test | Port status | Deviation |
| --- | --- | --- |
| `ActivityStrictMode-test.js` — `should not cause infinite render loop when StrictMode is used with Suspense and synchronous set states` | Direct | Does not require Strict Effects. |
| The other three `ActivityStrictMode-test.js` cases | Out of scope | They require Strict Effects double invocation and, for one case, sibling prewarming. |
| `ReactErrorStacks-test.js` — `includes built-in for Activity` | Adapted | Use React-Luau's existing component-stack assertion seam. |
| `ReactLazy-test.internal.js` — `throws with a useful error when wrapping Activity with lazy()` | Adapted | Use the existing Jest-Lua lazy suite and error formatting. |
| `storeComponentFilters-test.js` — `should filter Activity` | Base behavior | Activity intentionally uses the already-filtered Offscreen tag in this no-hydration renderer. |
| Five Activity cases in `ReactDeferredValue-test.js` | Out of scope | They require React 19's `useDeferredValue(value, initialValue)` contract, a separate backport. |
| Activity cases in `ReactSiblingPrerendering-test.js` | Out of scope | React-Luau does not implement sibling prewarming. |
| Activity cases in `ReactSuspenseyCommitPhase-test.js` | Out of scope | ReactRoblox has no suspensey host resources or suspended commit phase. |
| Activity case in `ReactTransitionTracing-test.js` | Out of scope | Transition tracing is disabled. |
| Activity insertion-effect cleanup in `ReactHooksWithNoopRenderer-test.js` | Out of scope | `useInsertionEffect` is not exposed. |
| React Refresh Activity ref cases | Out of scope | React-Luau does not ship React Refresh. |
| ReactDOM fragment-ref, event, server, and hydration Activity suites | Out of scope | They are DOM or hydration contracts. |

## Renderer acceptance

ReactRoblox tests additionally verify that hidden host Instances are detached,
restored to their original parent without remounting, deleted safely while
hidden, and remain hidden when inserted or updated under an already-hidden
Activity. ReactRoblox does not model DOM sibling insertion order: its existing
`insertBefore` operation is equivalent to assigning `Parent`, so Activity does
not introduce a stronger ordering contract than the renderer already provides.

## Completion criteria

The backport is complete when every Direct, Adapted, and Base behavior row is
green, every exclusion remains tied to a missing renderer capability, all
available standalone gates pass, Anime Rush's patched packages contain the
same runtime, the complete Anime Rush gate set passes, and both repositories'
working trees and pull requests are current and clean.

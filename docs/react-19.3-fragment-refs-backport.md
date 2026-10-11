# React 19.3 Fragment refs backport

React release `v19.3.0`, pinned to
[`1d34f91dfde6bba84d08b683aaba164c7194dacb`](https://github.com/facebook/react/tree/1d34f91dfde6bba84d08b683aaba164c7194dacb),
supplies the Fragment ref lifecycle, traversal, host membership, methods, and
source tests. This fork adapts the complete applicable API to native Roblox
Instances. The underlying reconciler retains its React 17 architecture.

## Prerequisite composition

The feature starts at fork main `9351444c2db37caa08b38ad5de90f438db9221ea`.
Only required existing feature history is composed:

| Composition commit | Retained prerequisite |
| --- | --- |
| `db39ebbe2ec3583dc323c10c2e2d6bfdcec4091e` | Strict Effects `77cfe4f`, Activity `eacef3e`, transition `9626a5b`, Suspense effects `9e6d492` ancestry. |
| `577b45fc0c19c7ef674483cf831c614f26ffe493` | Ref-as-prop `a6ed95e` feature patch; unrelated diverged main history excluded. |
| `5627e91968f6bac46d182b93af45591a9acc7c6f` | Callback cleanup series `16c0c2e`, `167bc72`, `e7a0c1a`, `3b3d619`, `e781672`, `1b4860c`, `7cc8646`. |
| `8177053d456c32657f5d1449e0dac4b7fa4ab4c8` | Activity portal correction `11e342a`. |
| `16014a8b9c4430f0f9b45160795a0be1744200cc` | Nested Activity/LegacyHidden `c31223d` feature tests/docs; matching runtime guards retained from portal history. Unrelated insertion/Effect Event history excluded. |

Composed Strict Effects assigns bit 18 to PlacementDEV. PortalStatic therefore
uses bit 19 in this standalone fork. Integrations retain their own distinct bit
allocations. Activity external-store `f9de21e` and hidden-error `926cddb` are
adjacent features outside this composition; Anime Rush already ships them and
preserves them when integrating this backport.

## Native public contract

A ref-bearing Fragment owns a stable handle without adding a host wrapper.
Callback cleanup, callback replacement, ref removal, Strict replay, Activity
hide/reveal, and logical traversal follow the pinned source. Host membership
tracks initial insertions, deletions, portals, hidden boundaries, and reconnection.

The handle provides native signal event subscription, Fragment-wide once and
cancellation, `focus`, `focusLast`, `blur`, `getClientRects`, `getRootNode`,
`compareTreePosition`, `observeUsing`, `unobserveUsing`, and `scrollIntoView`.
ReactRoblox exposes `getFragmentInstances`, `createResizeObserver`, and
`createIntersectionObserver` with typed native boundaries. The renderer host
hooks are `createFragmentInstance`, `updateFragmentInstanceFiber`,
`commitNewChildToFragmentInstance`, and `deleteChildFromFragmentInstance`.
Deletion additionally disposes native ownership with `destroyFragmentInstance`;
ordinary ref removal, callback replacement, Strict replay, and hiding preserve
logical registrations.

Shared flags enable Fragment refs, reverse instance handles, and scrolling.
Fragment HostText traversal remains disabled because ReactRoblox rejects bare
text hosts; generic Noop/Test renderer text support is unchanged. Those renderers
retain upstream nil handles and no-op hooks.

## Reconciler and renderer source ledger

All upstream paths below are under `packages/` at the release pin. Target paths
are relative to this repository. Every behavior-bearing source has an explicit
mapping or exclusion; architecture and engine differences are recorded per row.
| Upstream source or test | React-Luau target | Port status | Deviation |
| --- | --- | --- | --- |
| `react-reconciler/src/ReactChildFiber.js`, root Fragment retention and Fragment ref coercion | `modules/react-reconciler/src/ReactChildFiber.new.lua` | Adapted | Ref-as-prop prerequisite supplies `props.ref`; old child collection paths retain separate Fragment dispatch instead of modern `updateElement`. |
| `react-reconciler/src/ReactFiberBeginWork.js`, `updateFragment` | `modules/react-reconciler/src/ReactFiberBeginWork.new.lua` | Direct behavior | Luau forward declaration permits existing later `markRef` definition. Existing React 17 Ref flag remains. |
| `react-reconciler/src/ReactFiberCommitEffects.js`, Fragment `commitAttachRef` case | `modules/react-reconciler/src/ReactFiberCommitWork.new.lua` | Direct behavior | React 17 retains ref effects in its combined commit module. |
| `react-reconciler/src/ReactFiberCommitWork.js`, Fragment mutation/layout/deletion/disappear/reappear cases | `modules/react-reconciler/src/ReactFiberCommitWork.new.lua`, `ReactFiberWorkLoop.new.lua` | Adapted | Existing recursive React 17 walks execute Fragment attachment/detachment before descendants. Mutation receives current error reporter and reads prior hidden ancestry instead of modern traversal context. |
| `react-reconciler/src/ReactFiberFragmentInstance.js`, all four exported functions and ancestry predicates | `modules/react-reconciler/src/ReactFiberFragmentInstance.lua` | Direct eligible-host behavior | Separate file preserved. HostSingleton is absent. HostText membership stays independently disabled while ordinary generic text rendering remains. |
| `react-reconciler/src/ReactFiberCommitHostEffects.js`, placement membership collection and insertion helpers | `modules/react-reconciler/src/ReactFiberCommitWork.new.lua` placement helpers | Adapted | Older architecture keeps placement in combined commit module. Four membership functions remain in separate helper module. Portals keep physical placement containers and independent logical Fragment ancestry. Moves skip initial membership effects by `alternate`. |
| `react-reconciler/src/ReactFiberTreeReflection.js`, visible Fragment traversals, ancestry, sibling, containment/order, LCA | `modules/react-reconciler/src/ReactFiberTreeReflection.lua` | Direct eligible-host behavior | HostSingleton and Fragment HostText traversal excluded. Luau siblings use two return values. Optional callback arguments use explicit nil. Pinned `isFragmentContainedByFiber` ignores otherFiber; preserve source limitation, do not use it for truthful logical host containment. |
| `react-reconciler/src/forks/ReactFiberConfig.custom.js`, Fragment hooks and type | `modules/react-reconciler/src/ReactFiberHostConfig.lua` and existing reconciler initializer | Adapted | Renderer hooks inject through the existing config table; renderer-specific object type replaces Flow opaque/null shape. |
| `react-noop-renderer/src/createReactNoop.js`, Fragment hooks | `modules/react-noop-renderer/src/createReactNoop.lua` | Direct | Noop returns nil handle and no-op membership hooks, as upstream. Native deletion disposal is additional no-op. |
| `react-test-renderer/src/ReactFiberConfigTestHost.js`, Fragment hooks | `modules/react-test-renderer/src/ReactTestHostConfig.lua` | Direct | Test renderer returns nil handle and no-op membership hooks, as upstream. Existing host-config test fork already initializes that renderer and needs no new export wrapper. Native deletion disposal is additional no-op. |
| `shared/ReactFeatureFlags.js`, four Fragment flags | `modules/shared/src/ReactFeatureFlags.lua` | Adapted | Refs, instance handles, and scrolling enabled; bare HostText traversal disabled because ReactRoblox rejects bare text nodes. No global flag enables nonexistent DOM APIs. |
| `shared/forks/ReactFeatureFlags.native-fb.js`, `.native-oss.js`, `.test-renderer.js`, `.test-renderer.native-fb.js`, `.test-renderer.www.js`, `.www-dynamic.js`, `.www.js` | No target | Out of scope | These React build forks do not ship in React-Luau; its actual flag table applies. |
| `react-art/src/ReactFiberConfigART.js`, `react-native-renderer/src/ReactFiberConfigNative.js`, `ReactFiberConfigFabric.js` | No target | Out of scope | Those renderers do not ship in React-Luau. Retained Roblox, Noop, and Test renderers receive actual hooks. |
| `react-dom-bindings/src/client/ReactFiberConfigDOM.js`, four host hooks and FragmentInstance methods | `modules/react-roblox/src/client/ReactRobloxFragmentInstance.lua`, `ReactRobloxHostConfig.lua`, `FragmentFocus.lua`, `FragmentQueries.lua`, `FragmentScroll.lua`, `RobloxFragmentObservers.lua`, and `RobloxFragmentGeometry.lua` | Adapted | Native GUI/signal/observer methods replace DOM operations; record precise host deviations and source-linked tests separately. |
| `shared/ReactDOMFragmentRefShared.js` | No DOM target | Out of scope | DOM document-position constants excluded; host exposes truthful logical compareTreePosition contract. |
| `react/src/__tests__/ReactElementValidator-test.internal.js`, illegal attributes case; `ReactJSXElementValidator-test.js`, Fragment cases | `modules/react/src/ReactElementValidator.lua`, `modules/react/src/__tests__/ReactElementValidator-internal.spec.lua` | Adapted | Both Luau createElement and JSX share the existing validator; no separate JSX test suite ships. Existing complete illegal-attributes case retains behavior with release message allowing ref. |
| `react-dom/src/__tests__/ReactDOMFragmentRefs-test.js`, `attaches a ref to Fragment`; `accepts a ref callback`; `is available in effects` | `modules/react-reconciler/src/__tests__/ReactFragmentRefs.spec.lua`, first three cases | Adapted | Actual ReactRoblox roots/Folder/TextLabel hosts, explicit Luau imports and synchronous act replace DOM/JS harness. Wrapper-free host hierarchy remains asserted. |
| Same suite, `runs the ref cleanup when an inline ref callback changes identity`; `runs the ref cleanup when the ref is removed from a mounted Fragment`; `detaches and reattaches Fragment refs when StrictMode double invokes` | Same target, next three cases | Adapted | Complete upstream logs, identity checks, render steps, and DEV/prod branch preserved. Scheduler yield assertions replace assertLog. |
| React-Luau keyed collection reconciliation | Same target, `updates callback refs on keyed Fragments in child collections` | Roblox adaptation regression | Public refs verify older separate keyed Fragment collection paths; this is explicitly additional adapter coverage, not an invented upstream mirror case. |
| React-Luau hidden Fragment deletion | Same target, `cleans up a hidden Fragment callback only once before deletion` | Roblox adaptation regression | Prior-hidden deletion guard preserves a single callback cleanup after Activity disconnection; the complete root/ref lifecycle is public renderer coverage. |


## Complete Fragment source test ledger

| Upstream case/source | React-Luau target | Port status | Deviation |
| --- | --- | --- | --- |
| ReactDOMFragmentRefs-test.js:68 — attaches a ref to Fragment | `modules/react-reconciler/src/__tests__/ReactFragmentRefs.spec.lua` | Adapted source case | Existing React17 commit architecture; actual ReactRoblox public root, callback cleanup and exact upstream logs preserved. |
| ReactDOMFragmentRefs-test.js:89 — accepts a ref callback | `modules/react-reconciler/src/__tests__/ReactFragmentRefs.spec.lua` | Adapted source case | Existing React17 commit architecture; actual ReactRoblox public root, callback cleanup and exact upstream logs preserved. |
| ReactDOMFragmentRefs-test.js:105 — is available in effects | `modules/react-reconciler/src/__tests__/ReactFragmentRefs.spec.lua` | Adapted source case | Existing React17 commit architecture; actual ReactRoblox public root, callback cleanup and exact upstream logs preserved. |
| ReactDOMFragmentRefs-test.js:126 — attaches fragment handles to nodes | `modules/react-roblox/src/client/__tests__/FragmentMembership.spec.lua` | Adapted source case | Private weak membership registry and frozen getFragmentInstances snapshot replace arbitrary host properties and JS Set. |
| ReactDOMFragmentRefs-test.js:165 — runs the ref cleanup when an inline ref callback changes identity | `modules/react-reconciler/src/__tests__/ReactFragmentRefs.spec.lua` | Adapted source case | Existing React17 commit architecture; actual ReactRoblox public root, callback cleanup and exact upstream logs preserved. |
| ReactDOMFragmentRefs-test.js:224 — runs the ref cleanup when the ref is removed from a mounted Fragment | `modules/react-reconciler/src/__tests__/ReactFragmentRefs.spec.lua` | Adapted source case | Existing React17 commit architecture; actual ReactRoblox public root, callback cleanup and exact upstream logs preserved. |
| ReactDOMFragmentRefs-test.js:259 — detaches and reattaches Fragment refs when StrictMode double invokes | `modules/react-reconciler/src/__tests__/ReactFragmentRefs.spec.lua` | Adapted source case | Existing React17 commit architecture; actual ReactRoblox public root, callback cleanup and exact upstream logs preserved. |
| ReactDOMFragmentRefs-test.js:313 — focuses the first focusable child | `modules/react-roblox/src/client/__tests__/FragmentFocus.roblox.spec.lua` | Adapted source case | Native TextBox editing / GuiService selection channels replace document activeElement. Candidate and ancestry eligibility includes Interactable; exact case sequence uses actual client GUI. |
| ReactDOMFragmentRefs-test.js:346 — focuses deeply nested focusable children, depth first | `modules/react-roblox/src/client/__tests__/FragmentFocus.roblox.spec.lua` | Adapted source case | Native TextBox editing / GuiService selection channels replace document activeElement. Candidate and ancestry eligibility includes Interactable; exact case sequence uses actual client GUI. |
| ReactDOMFragmentRefs-test.js:372 — preserves document order when adding and removing children | `modules/react-roblox/src/client/__tests__/FragmentFocus.roblox.spec.lua` | Adapted source case | Native TextBox editing / GuiService selection channels replace document activeElement. Candidate and ancestry eligibility includes Interactable; exact case sequence uses actual client GUI. |
| ReactDOMFragmentRefs-test.js:416 — keeps focus on the first focusable child if already focused | `modules/react-roblox/src/client/__tests__/FragmentFocus.roblox.spec.lua` | Adapted source case | Native TextBox editing / GuiService selection channels replace document activeElement. Candidate and ancestry eligibility includes Interactable; exact case sequence uses actual client GUI. |
| ReactDOMFragmentRefs-test.js:451 — keeps focus on a nested child if already focused | `modules/react-roblox/src/client/__tests__/FragmentFocus.roblox.spec.lua` | Adapted source case | Native TextBox editing / GuiService selection channels replace document activeElement. Candidate and ancestry eligibility includes Interactable; exact case sequence uses actual client GUI. |
| ReactDOMFragmentRefs-test.js:485 — focuses the first focusable child in a fieldset | `modules/react-roblox/src/client/__tests__/FragmentFocus.roblox.spec.lua` | Adapted source case | Original fieldset case title/order retained; Frame/TextLabel/StreetCity TextBox counterpart traverses native candidates. Roblox has no HTML form/fieldset delegation semantics. |
| ReactDOMFragmentRefs-test.js:514 — focuses the last focusable child | `modules/react-roblox/src/client/__tests__/FragmentFocus.roblox.spec.lua` | Adapted source case | Native TextBox editing / GuiService selection channels replace document activeElement. Candidate and ancestry eligibility includes Interactable; exact case sequence uses actual client GUI. |
| ReactDOMFragmentRefs-test.js:552 — focuses deeply nested focusable children, depth first | `modules/react-roblox/src/client/__tests__/FragmentFocus.roblox.spec.lua` | Adapted source case | Native TextBox editing / GuiService selection channels replace document activeElement. Candidate and ancestry eligibility includes Interactable; exact case sequence uses actual client GUI. |
| ReactDOMFragmentRefs-test.js:582 — removes focus from an element inside of the Fragment | `modules/react-roblox/src/client/__tests__/FragmentFocus.roblox.spec.lua` | Adapted source case | Native TextBox editing / GuiService selection channels replace document activeElement. Candidate and ancestry eligibility includes Interactable; exact case sequence uses actual client GUI. |
| ReactDOMFragmentRefs-test.js:612 — removes focus from a nested element inside of the Fragment | `modules/react-roblox/src/client/__tests__/FragmentFocus.roblox.spec.lua` | Adapted source case | Native TextBox editing / GuiService selection channels replace document activeElement. Candidate and ancestry eligibility includes Interactable; exact case sequence uses actual client GUI. |
| ReactDOMFragmentRefs-test.js:642 — removes focus from a portaled element inside of the Fragment | `modules/react-roblox/src/client/__tests__/FragmentFocus.roblox.spec.lua` | Adapted source case | Native TextBox editing / GuiService selection channels replace document activeElement. Candidate and ancestry eligibility includes Interactable; exact case sequence uses actual client GUI. |
| ReactDOMFragmentRefs-test.js:677 — does not remove focus from elements outside of the Fragment | `modules/react-roblox/src/client/__tests__/FragmentFocus.roblox.spec.lua` | Adapted source case | Native TextBox editing / GuiService selection channels replace document activeElement. Candidate and ancestry eligibility includes Interactable; exact case sequence uses actual client GUI. |
| ReactDOMFragmentRefs-test.js:717 — adds and removes event listeners from children | `modules/react-roblox/src/client/__tests__/FragmentMethods.spec.lua` | Adapted source case | BindableEvent.Event/native signals replace DOM click. Host-first callback; no bubbling. Exact event count/identities asserted; native engine handler order uses exact unordered multiset when same signal has several listeners. |
| ReactDOMFragmentRefs-test.js:799 — regression: does not detach a registered listener when removing an unregistered one | `modules/react-roblox/src/client/__tests__/FragmentMethods.spec.lua` | Adapted source case | BindableEvent.Event/native signals replace DOM click. Host-first callback; no bubbling. Exact event count/identities asserted; native engine handler order uses exact unordered multiset when same signal has several listeners. |
| ReactDOMFragmentRefs-test.js:840 — matches listeners by their normalized capture flag | `No Roblox counterpart` | Out of scope | Native engine signals have no DOM capture/passive/bubbling or library dispatch. |
| ReactDOMFragmentRefs-test.js:881 — adds and removes event listeners from children with multiple fragments | `modules/react-roblox/src/client/__tests__/FragmentMethods.spec.lua` | Adapted source case | BindableEvent.Event/native signals replace DOM click. Host-first callback; no bubbling. Exact event count/identities asserted; native engine handler order uses exact unordered multiset when same signal has several listeners. |
| ReactDOMFragmentRefs-test.js:960 — adds an event listener to a newly added child | `modules/react-roblox/src/client/__tests__/FragmentMethods.spec.lua` | Adapted source case | BindableEvent.Event/native signals replace DOM click. Host-first callback; no bubbling. Exact event count/identities asserted; native engine handler order uses exact unordered multiset when same signal has several listeners. |
| ReactDOMFragmentRefs-test.js:1008 — fires a once listener only once across existing children | `modules/react-roblox/src/client/__tests__/FragmentMethods.spec.lua` | Adapted source case | BindableEvent.Event/native signals replace DOM click. Host-first callback; no bubbling. Exact event count/identities asserted; native engine handler order uses exact unordered multiset when same signal has several listeners. |
| ReactDOMFragmentRefs-test.js:1047 — does not re-arm a once listener when a new child is inserted | `modules/react-roblox/src/client/__tests__/FragmentMethods.spec.lua` | Adapted source case | BindableEvent.Event/native signals replace DOM click. Host-first callback; no bubbling. Exact event count/identities asserted; native engine handler order uses exact unordered multiset when same signal has several listeners. |
| ReactDOMFragmentRefs-test.js:1102 — should remove the listener when the signal is aborted before registration | `modules/react-roblox/src/client/__tests__/FragmentMethods.spec.lua` | Adapted source case | External colon cancellation adapter aborted+subscribe replaces AbortSignal; stale old-registration cancellation cannot remove new registration. |
| ReactDOMFragmentRefs-test.js:1135 — should remove the listener when the signal is aborted after registration | `modules/react-roblox/src/client/__tests__/FragmentMethods.spec.lua` | Adapted source case | External colon cancellation adapter aborted+subscribe replaces AbortSignal; stale old-registration cancellation cannot remove new registration. |
| ReactDOMFragmentRefs-test.js:1173 — should NOT remove the new subscription when the signal for the old subscription is aborted | `modules/react-roblox/src/client/__tests__/FragmentMethods.spec.lua` | Adapted source case | External colon cancellation adapter aborted+subscribe replaces AbortSignal; stale old-registration cancellation cannot remove new registration. |
| ReactDOMFragmentRefs-test.js:1218 — adds an event listener to a newly added text child | `No Roblox counterpart` | Out of scope | ReactRoblox prohibits HostText; TextLabel and TextBox remain ordinary host Instances. |
| ReactDOMFragmentRefs-test.js:1261 — removes event listeners from a deleted text child | `No Roblox counterpart` | Out of scope | ReactRoblox prohibits HostText; TextLabel and TextBox remain ordinary host Instances. |
| ReactDOMFragmentRefs-test.js:1315 — applies event listeners to host children nested within non-host children | `modules/react-roblox/src/client/__tests__/FragmentMethods.spec.lua` | Adapted source case | BindableEvent.Event/native signals replace DOM click. Host-first callback; no bubbling. Exact event count/identities asserted; native engine handler order uses exact unordered multiset when same signal has several listeners. |
| ReactDOMFragmentRefs-test.js:1350 — allows adding and cleaning up listeners in effects | `modules/react-roblox/src/client/__tests__/FragmentMethods.spec.lua` | Adapted source case | BindableEvent.Event/native signals replace DOM click. Host-first callback; no bubbling. Exact event count/identities asserted; native engine handler order uses exact unordered multiset when same signal has several listeners. |
| ReactDOMFragmentRefs-test.js:1398 — does not apply removed event listeners to new children | `modules/react-roblox/src/client/__tests__/FragmentMethods.spec.lua` | Adapted source case | BindableEvent.Event/native signals replace DOM click. Host-first callback; no bubbling. Exact event count/identities asserted; native engine handler order uses exact unordered multiset when same signal has several listeners. |
| ReactDOMFragmentRefs-test.js:1428 — removes a capture listener registered with boolean when removed with options object | `No Roblox counterpart` | Out of scope | Native engine signals have no DOM capture/passive/bubbling or library dispatch. |
| ReactDOMFragmentRefs-test.js:1465 — removes a capture listener registered with options object when removed with boolean | `No Roblox counterpart` | Out of scope | Native engine signals have no DOM capture/passive/bubbling or library dispatch. |
| ReactDOMFragmentRefs-test.js:1502 — applies event listeners to portaled children | `modules/react-roblox/src/client/__tests__/FragmentMethods.spec.lua` | Adapted source case | BindableEvent.Event/native signals replace DOM click. Host-first callback; no bubbling. Exact event count/identities asserted; native engine handler order uses exact unordered multiset when same signal has several listeners. |
| ReactDOMFragmentRefs-test.js:1538 — applies event listeners to children portaled in after registration | `modules/react-roblox/src/client/__tests__/FragmentMethods.spec.lua` | Adapted source case | BindableEvent.Event/native signals replace DOM click. Host-first callback; no bubbling. Exact event count/identities asserted; native engine handler order uses exact unordered multiset when same signal has several listeners. |
| ReactDOMFragmentRefs-test.js:1589 — does not apply event listeners to hidden trees | `modules/react-roblox/src/client/__tests__/FragmentMethods.spec.lua` | Adapted source case | BindableEvent.Event/native signals replace DOM click. Host-first callback; no bubbling. Exact event count/identities asserted; native engine handler order uses exact unordered multiset when same signal has several listeners. Hidden hosts are physically detached; retained native handles test membership suspension without inventing hidden DOM access. |
| ReactDOMFragmentRefs-test.js:1625 — applies event listeners to visible trees | `modules/react-roblox/src/client/__tests__/FragmentMethods.spec.lua` | Adapted source case | BindableEvent.Event/native signals replace DOM click. Host-first callback; no bubbling. Exact event count/identities asserted; native engine handler order uses exact unordered multiset when same signal has several listeners. Hidden hosts are physically detached; retained native handles test membership suspension without inventing hidden DOM access. |
| ReactDOMFragmentRefs-test.js:1661 — handles Activity modes switching | `modules/react-roblox/src/client/__tests__/FragmentMethods.spec.lua` | Adapted source case | BindableEvent.Event/native signals replace DOM click. Host-first callback; no bubbling. Exact event count/identities asserted; native engine handler order uses exact unordered multiset when same signal has several listeners. Hidden hosts are physically detached; retained native handles test membership suspension without inventing hidden DOM access. |
| ReactDOMFragmentRefs-test.js:1714 — does not dispatch fragment events from text children while hidden | `No Roblox counterpart` | Out of scope | ReactRoblox prohibits HostText; TextLabel and TextBox remain ordinary host Instances. |
| ReactDOMFragmentRefs-test.js:1777 — fires events on the host parent if bubbles=true | `No Roblox counterpart` | Out of scope | Native engine signals have no DOM capture/passive/bubbling or library dispatch. |
| ReactDOMFragmentRefs-test.js:1835 — fires events on self, and only self if bubbles=false | `No Roblox counterpart` | Out of scope | Native engine signals have no DOM capture/passive/bubbling or library dispatch. |
| ReactDOMFragmentRefs-test.js:1914 — attaches intersection observers to children | `modules/react-roblox/src/client/__tests__/ReactRobloxFragmentObservation.roblox.spec.lua` | Adapted source case | Native boundary observer owner tokens replace browser objects; deterministic post-paint mock retains complete deletion/Activity sequences and exits. Private frozen membership snapshots replace host Set caching. |
| ReactDOMFragmentRefs-test.js:1975 — keeps a removed child observed until after the intersection exit, then unobserves it | `modules/react-roblox/src/client/__tests__/ReactRobloxFragmentObservation.roblox.spec.lua` | Adapted source case | Native boundary observer owner tokens replace browser objects; deterministic post-paint mock retains complete deletion/Activity sequences and exits. Private frozen membership snapshots replace host Set caching. |
| ReactDOMFragmentRefs-test.js:2022 — unobserveUsing() releases deleted children that were waiting for an exit record | `modules/react-roblox/src/client/__tests__/ReactRobloxFragmentObservation.roblox.spec.lua` | Adapted source case | Native boundary observer owner tokens replace browser objects; deterministic post-paint mock retains complete deletion/Activity sequences and exits. Private frozen membership snapshots replace host Set caching. |
| ReactDOMFragmentRefs-test.js:2048 — unobserves ResizeObserver targets as soon as a child is deleted | `modules/react-roblox/src/client/__tests__/ReactRobloxFragmentObservation.roblox.spec.lua` | Adapted source case | Native boundary observer owner tokens replace browser objects; deterministic post-paint mock retains complete deletion/Activity sequences and exits. Private frozen membership snapshots replace host Set caching. |
| ReactDOMFragmentRefs-test.js:2086 — unobserves a replaced child after post-paint and keeps the new child observed | `modules/react-roblox/src/client/__tests__/ReactRobloxFragmentObservation.roblox.spec.lua` | Adapted source case | Native boundary observer owner tokens replace browser objects; deterministic post-paint mock retains complete deletion/Activity sequences and exits. Private frozen membership snapshots replace host Set caching. |
| ReactDOMFragmentRefs-test.js:2123 — keeps a child observed if Activity shows it again before the delayed unobserve | `modules/react-roblox/src/client/__tests__/ReactRobloxFragmentObservation.roblox.spec.lua` | Adapted source case | Native boundary observer owner tokens replace browser objects; deterministic post-paint mock retains complete deletion/Activity sequences and exits. Private frozen membership snapshots replace host Set caching. |
| ReactDOMFragmentRefs-test.js:2159 — warns when unobserveUsing() is called with an observer that was not observed | `modules/react-roblox/src/client/__tests__/ReactRobloxFragmentObservation.roblox.spec.lua` | Adapted source case | Native boundary observer owner tokens replace browser objects; deterministic post-paint mock retains complete deletion/Activity sequences and exits. Private frozen membership snapshots replace host Set caching. |
| ReactDOMFragmentRefs-test.js:2191 — attaches handles to observed elements to allow caching of observers | `modules/react-roblox/src/client/__tests__/ReactRobloxFragmentObservation.roblox.spec.lua` | Adapted source case | Native boundary observer owner tokens replace browser objects; deterministic post-paint mock retains complete deletion/Activity sequences and exits. Private frozen membership snapshots replace host Set caching. |
| ReactDOMFragmentRefs-test.js:2313 — returns the bounding client rects of all children | `modules/react-roblox/src/client/__tests__/FragmentRects.roblox.spec.lua` | Adapted source case | Frozen unrotated layout-pixel records from GuiBase2d AbsolutePosition/AbsoluteSize replace DOMRect; no clipping/paint/occlusion claim. |
| ReactDOMFragmentRefs-test.js:2354 — returns the root node of the parent | `modules/react-roblox/src/client/__tests__/FragmentQueries.roblox.spec.lua` | Adapted source case | Physical topmost Instance ancestry getRootNode; named compareTreePosition frozen relationship booleans replace DOM numeric bit masks. Logical React order and portal physical divergence are explicit. |
| ReactDOMFragmentRefs-test.js:2377 — returns the topmost disconnected element if the fragment and parent are unmounted | `modules/react-roblox/src/client/__tests__/FragmentQueries.roblox.spec.lua` | Adapted source case | Physical topmost Instance ancestry getRootNode; named compareTreePosition frozen relationship booleans replace DOM numeric bit masks. Logical React order and portal physical divergence are explicit. |
| ReactDOMFragmentRefs-test.js:2409 — returns self when only the fragment was unmounted | `modules/react-roblox/src/client/__tests__/FragmentQueries.roblox.spec.lua` | Adapted source case | Physical topmost Instance ancestry getRootNode; named compareTreePosition frozen relationship booleans replace DOM numeric bit masks. Logical React order and portal physical divergence are explicit. |
| ReactDOMFragmentRefs-test.js:2448 — returns the relationship between the fragment instance and a given node | `modules/react-roblox/src/client/__tests__/FragmentQueries.roblox.spec.lua` | Adapted source case | Physical topmost Instance ancestry getRootNode; named compareTreePosition frozen relationship booleans replace DOM numeric bit masks. Logical React order and portal physical divergence are explicit. |
| ReactDOMFragmentRefs-test.js:2580 — handles fragment instances with one child | `modules/react-roblox/src/client/__tests__/FragmentQueries.roblox.spec.lua` | Adapted source case | Physical topmost Instance ancestry getRootNode; named compareTreePosition frozen relationship booleans replace DOM numeric bit masks. Logical React order and portal physical divergence are explicit. |
| ReactDOMFragmentRefs-test.js:2662 — handles empty fragment instances | `modules/react-roblox/src/client/__tests__/FragmentQueries.roblox.spec.lua` | Adapted source case | Physical topmost Instance ancestry getRootNode; named compareTreePosition frozen relationship booleans replace DOM numeric bit masks. Logical React order and portal physical divergence are explicit. |
| ReactDOMFragmentRefs-test.js:2756 — handles empty fragments nested inside non-host wrappers | `modules/react-roblox/src/client/__tests__/FragmentQueries.roblox.spec.lua` | Adapted source case | Physical topmost Instance ancestry getRootNode; named compareTreePosition frozen relationship booleans replace DOM numeric bit masks. Logical React order and portal physical divergence are explicit. |
| ReactDOMFragmentRefs-test.js:2801 — handles nested children | `modules/react-roblox/src/client/__tests__/FragmentQueries.roblox.spec.lua` | Adapted source case | Physical topmost Instance ancestry getRootNode; named compareTreePosition frozen relationship booleans replace DOM numeric bit masks. Logical React order and portal physical divergence are explicit. |
| ReactDOMFragmentRefs-test.js:2872 — returns disconnected for comparison with an unmounted fragment instance | `modules/react-roblox/src/client/__tests__/FragmentQueries.roblox.spec.lua` | Adapted source case | Physical topmost Instance ancestry getRootNode; named compareTreePosition frozen relationship booleans replace DOM numeric bit masks. Logical React order and portal physical divergence are explicit. |
| ReactDOMFragmentRefs-test.js:2923 — compares a root-level Fragment | `modules/react-roblox/src/client/__tests__/FragmentQueries.roblox.spec.lua` | Adapted source case | Physical topmost Instance ancestry getRootNode; named compareTreePosition frozen relationship booleans replace DOM numeric bit masks. Logical React order and portal physical divergence are explicit. |
| ReactDOMFragmentRefs-test.js:3034 — handles portaled elements | `modules/react-roblox/src/client/__tests__/FragmentQueries.roblox.spec.lua` | Adapted source case | Physical topmost Instance ancestry getRootNode; named compareTreePosition frozen relationship booleans replace DOM numeric bit masks. Logical React order and portal physical divergence are explicit. |
| ReactDOMFragmentRefs-test.js:3084 — handles multiple portals to the same element | `modules/react-roblox/src/client/__tests__/FragmentQueries.roblox.spec.lua` | Adapted source case | Physical topmost Instance ancestry getRootNode; named compareTreePosition frozen relationship booleans replace DOM numeric bit masks. Logical React order and portal physical divergence are explicit. |
| ReactDOMFragmentRefs-test.js:3201 — handles empty fragments | `modules/react-roblox/src/client/__tests__/FragmentQueries.roblox.spec.lua` | Adapted source case | Physical topmost Instance ancestry getRootNode; named compareTreePosition frozen relationship booleans replace DOM numeric bit masks. Logical React order and portal physical divergence are explicit. |
| ReactDOMFragmentRefs-test.js:3255 — positions empty portaled fragments against the portal container | `modules/react-roblox/src/client/__tests__/FragmentQueries.roblox.spec.lua` | Adapted source case | Physical topmost Instance ancestry getRootNode; named compareTreePosition frozen relationship booleans replace DOM numeric bit masks. Logical React order and portal physical divergence are explicit. |
| ReactDOMFragmentRefs-test.js:3305 — does not yet support options | `modules/react-roblox/src/client/__tests__/FragmentScroll.roblox.spec.lua` | Adapted source case | ScrollingFrame ancestor CanvasPosition/clamping replace DOM scrolling; boolean alignment and empty sibling/parent fallback preserved; DOM option objects rejected. |
| ReactDOMFragmentRefs-test.js:3322 — settles scroll on the first child by default, or if alignToTop=true | `modules/react-roblox/src/client/__tests__/FragmentScroll.roblox.spec.lua` | Adapted source case | ScrollingFrame ancestor CanvasPosition/clamping replace DOM scrolling; boolean alignment and empty sibling/parent fallback preserved; DOM option objects rejected. |
| ReactDOMFragmentRefs-test.js:3358 — calls scrollIntoView on the last child if alignToTop is false | `modules/react-roblox/src/client/__tests__/FragmentScroll.roblox.spec.lua` | Adapted source case | ScrollingFrame ancestor CanvasPosition/clamping replace DOM scrolling; boolean alignment and empty sibling/parent fallback preserved; DOM option objects rejected. |
| ReactDOMFragmentRefs-test.js:3385 — handles portaled elements -- same scroll container | `modules/react-roblox/src/client/__tests__/FragmentScroll.roblox.spec.lua` | Adapted source case | ScrollingFrame ancestor CanvasPosition/clamping replace DOM scrolling; boolean alignment and empty sibling/parent fallback preserved; DOM option objects rejected. |
| ReactDOMFragmentRefs-test.js:3426 — handles portaled elements -- different scroll container | `modules/react-roblox/src/client/__tests__/FragmentScroll.roblox.spec.lua` | Adapted source case | ScrollingFrame ancestor CanvasPosition/clamping replace DOM scrolling; boolean alignment and empty sibling/parent fallback preserved; DOM option objects rejected. |
| ReactDOMFragmentRefs-test.js:3527 — calls scrollIntoView on the next sibling by default, or if alignToTop=true | `modules/react-roblox/src/client/__tests__/FragmentScroll.roblox.spec.lua` | Adapted source case | ScrollingFrame ancestor CanvasPosition/clamping replace DOM scrolling; boolean alignment and empty sibling/parent fallback preserved; DOM option objects rejected. |
| ReactDOMFragmentRefs-test.js:3561 — finds host siblings when the empty fragment is nested in a non-host wrapper | `modules/react-roblox/src/client/__tests__/FragmentScroll.roblox.spec.lua` | Adapted source case | ScrollingFrame ancestor CanvasPosition/clamping replace DOM scrolling; boolean alignment and empty sibling/parent fallback preserved; DOM option objects rejected. |
| ReactDOMFragmentRefs-test.js:3595 — calls scrollIntoView on the prev sibling if alignToTop is false | `modules/react-roblox/src/client/__tests__/FragmentScroll.roblox.spec.lua` | Adapted source case | ScrollingFrame ancestor CanvasPosition/clamping replace DOM scrolling; boolean alignment and empty sibling/parent fallback preserved; DOM option objects rejected. |
| ReactDOMFragmentRefs-test.js:3632 — calls scrollIntoView on the parent if there are no siblings | `modules/react-roblox/src/client/__tests__/FragmentScroll.roblox.spec.lua` | Adapted source case | ScrollingFrame ancestor CanvasPosition/clamping replace DOM scrolling; boolean alignment and empty sibling/parent fallback preserved; DOM option objects rejected. |
| ReactDOMFragmentRefs-test.js:3652 — scrolls the host element when the fallback target is a ShadowRoot container | `No Roblox counterpart` | Out of scope | Roblox has no ShadowRoot/DocumentFragment host; physical Instance ancestry supplies root/container fallback. |
| ReactDOMFragmentRefs-test.js:3670 — warns without scrolling when the fallback target is a detached DocumentFragment container | `No Roblox counterpart` | Out of scope | Roblox has no ShadowRoot/DocumentFragment host; physical Instance ancestry supplies root/container fallback. |
| ReactDOMFragmentRefs-test.js:3694 — getClientRects includes text node bounds | `No Roblox counterpart` | Out of scope | ReactRoblox prohibits HostText; TextLabel and TextBox remain ordinary host Instances. |
| ReactDOMFragmentRefs-test.js:3716 — getClientRects includes both text and element bounds | `No Roblox counterpart` | Out of scope | ReactRoblox prohibits HostText; TextLabel and TextBox remain ordinary host Instances. |
| ReactDOMFragmentRefs-test.js:3746 — compareDocumentPosition works with text children | `No Roblox counterpart` | Out of scope | ReactRoblox prohibits HostText; TextLabel and TextBox remain ordinary host Instances. |
| ReactDOMFragmentRefs-test.js:3767 — focus is a no-op on text-only fragment | `No Roblox counterpart` | Out of scope | ReactRoblox prohibits HostText; TextLabel and TextBox remain ordinary host Instances. |
| ReactDOMFragmentRefs-test.js:3785 — focusLast is a no-op on text-only fragment | `No Roblox counterpart` | Out of scope | ReactRoblox prohibits HostText; TextLabel and TextBox remain ordinary host Instances. |
| ReactDOMFragmentRefs-test.js:3802 — warns when observeUsing is called on text-only fragment | `No Roblox counterpart` | Out of scope | ReactRoblox prohibits HostText; TextLabel and TextBox remain ordinary host Instances. |
| ReactDOMFragmentRefs-test.js:3827 — scrollIntoView works on text-only fragment using Range API | `No Roblox counterpart` | Out of scope | ReactRoblox prohibits HostText; TextLabel and TextBox remain ordinary host Instances. |
| ReactDOMFragmentRefs-test.js:3857 — scrollIntoView scrolls to text siblings of an empty fragment using the Range API | `No Roblox counterpart` | Out of scope | ReactRoblox prohibits HostText; TextLabel and TextBox remain ordinary host Instances. |
| ReactDOMFragmentRefs-test.js:3899 — treats passive:true and passive:false as same listener per DOM spec | `No Roblox counterpart` | Out of scope | Native engine signals have no DOM capture/passive/bubbling or library dispatch. |
| ReactDOMFragmentRefs-test.js:3938 — removes a listener registered with passive:false when removed with passive:true | `No Roblox counterpart` | Out of scope | Native engine signals have no DOM capture/passive/bubbling or library dispatch. |

## Behavior-bearing host source symbols

Every source reference below is `packages/react-dom-bindings/src/client/ReactFiberConfigDOM.js` at the release pin. The split files keep cohesive Roblox responsibilities; the adapter symbols are host replacements, not a claim of identical DOM APIs.

| Upstream symbols / pinned lines | Roblox target and status | Behavior and deviation |
| --- | --- | --- |
| `FragmentInstance` L3025–3031 | `ReactRobloxFragmentInstance.lua`, adapted | Stable reconciler Fiber handle; weak private host ownership instead of writable DOM node properties. |
| `addEventListener`, `addEventListenerToChild` L3032–3115 | Same file `addEventListener`, `attachListener`, adapted | First-level visible membership; supported native signal whitelist; class filtering; callback `(sourceInstance, ...nativeArgs)`; registration gate suppresses removed or replaced connection delivery. |
| `removeEventListener`, `removeEventListenerFromChild` L3116–3162 | Same file `removeEventListener`, adapted | Exact event+listener identity; disconnect all owned native connections; cancellation cleanup exactly once. |
| `isOnceOption`, `getAttachOptions`, `normalizeListenerOptions`, `indexOfEventListener` L3163–3217 | Same file registration lookup / option validation / once state, adapted | Fragment-wide once consumed and removed before callback invocation. Native capture/passive omitted and rejected rather than falsely normalized. Cancellation adapter keeps pre-aborted and stale-registration semantics. |
| `dispatchEvent` L3218–3272 | No counterpart, out of scope | RBXScriptSignal has no public dispatch operation and no DOM event propagation tree; caller emits an actual BindableEvent or lets the engine deliver an input signal. No synthetic dispatch/bubbling layer. |
| `focus`, `setFocusOnFiberIfFocusable`, `focusLast`, `collectChildren` L3273–3318 | `FragmentFocus.lua`, adapted | Visible deep logical Fiber order; native auto/text/selection channel per candidate. TextBox capture and GuiService selection eligibility/ownership replace browser element focus; already-focused eligible candidate stops traversal. |
| `blur`, `blurActiveElementWithinFragment` L3319–3359 | Same helper, adapted | Releases owned text/selection focus only; nested and portal logical containment; outside focus retained. |
| `observeUsing`, `observeChild` L3360–3413 | `ReactRobloxFragmentInstance.lua`, adapted | GuiObject first-level hosts only; colon observer interface and per-Fragment ownership; no bare HostText registration. |
| `unobserveUsing`, `unobserveChild` L3414–3459 | Same file, adapted | Removes active and pending owner registrations; unregistered warning preserved; retained deleted handle may explicitly cancel pending exit. |
| `isIntersectionObserver`, `cancelPendingIntersectionUnobserve`, `unobservePendingChildren`, `schedulePendingIntersectionUnobserve` L3460–3536 | `RobloxFragmentObservers.lua` lifecycle methods / host observer protocol, adapted | `unobserveAfterExit`, `releaseOwner`, `releaseOwnerAfterExit` replace browser constructor detection; owner tokens preserve overlaps. Native dirty signals and one-shot frame settlement deliver intersection exit before removing pending ownership; resize release immediate. |
| `getClientRects`, `collectClientRects` L3537–3562 | `FragmentQueries.lua` + `RobloxFragmentGeometry.lua`, adapted | Immutable unrotated raw layout snapshots of first-level GuiBase2d hosts; geometry distinct from visibility/clipping/paint; bare text bounds excluded. |
| `getRootNode` L3563–3581 | `FragmentQueries.lua`, adapted | Physical topmost Instance ancestry, not React mount container. Retained detached handle falls back to self as pinned source. |
| `compareDocumentPosition`, `validateDocumentPositionWithFiberTree` L3582–3746 | Same helper `compareTreePosition`, adapted | Named frozen record with preceding/following/contains/containedBy/disconnected/implementationSpecific; truthful Fiber logical order, exact host map, and explicitly marked portal physical divergence; no arbitrary DOM bits. |
| `scrollTextNodeIntoView` L3747–3761 | No counterpart, out of scope | Roblox renderer prohibits bare HostText; TextLabel is an ordinary host Instance, not DOM Text/Range. |
| `scrollIntoView` L3762–3851 | `FragmentScroll.lua`, adapted | Boolean alignment, first/last child and empty next/previous/parent fallback; nested ScrollingFrame physical ancestry and CanvasPosition scale/clamping; DOM option objects unsupported as pinned source. |
| `addFragmentHandleToFiber`, `addFragmentHandleToInstance` L3852–3876 | `ReactRobloxFragmentInstance.lua` private `addHandle`, adapted | Private weak host registry plus handle-owned members; public `getFragmentInstances` frozen snapshot replaces host `.reactFragments` Set. |
| `createFragmentInstance` L3877–3890 | Same file / `ReactRobloxHostConfig.lua`, adapted | Four upstream hooks exposed through existing renderer injection; stable handle created and visible first-level membership recorded. |
| `updateFragmentInstanceFiber` L3891–3897 | Same files, direct behavior | Replace Fiber pointer without resetting logical registrations or handle identity. |
| `commitNewChildToFragmentInstance` L3898–3929 | Same files, adapted | Connect new visible child to active listeners/observers/private registry, including portals and Activity reveal; host class filter remains native. |
| `deleteChildFromFragmentInstance` L3930–3968 | Same files, adapted | Disconnect child signals, unobserve or queue final intersection exit, release reverse membership; preserve logical registrations for new children/reveal. |
| Renderer deletion disposal (no upstream fifth hook) | Same files `destroyFragmentInstance`, Roblox addition | Empty Fragment/native cancellation cleanup requires explicit deletion disposal. Ordinary callback identity/ref removal/Strict replay preserve subscriptions. Pending native observer final exit is retained until delivery or explicit retained-handle cancellation. |
| `ReactDOMFragmentRefShared.js` position constants / feature flags | `FragmentQueries.lua`, `shared/ReactFeatureFlags.lua`, adapted / DOM bits excluded | Fragment refs, reverse handles, scroll enabled; HostText disabled. No unsupported DOM constants exposed. The reconciler and build fork source mapping appears above. |
| `utils/IntersectionMocks.js` constructor metadata and idempotent observe | Source observation suite `createMockObserver`, adapted | Owner-aware native boundary preserves observer source sequence, mock delivery/logs, normalized rootMargin/thresholds. |

Paths in the symbol table are under `modules/react-roblox/src/client/` unless specified. `ReactRoblox.lua` exports `getFragmentInstances`, `createResizeObserver`, and `createIntersectionObserver`; `src/init.lua` exports the native public Luau types. Exact `ReactRobloxComponentTree.getFiberFromInstance` uses host/root maps without guessing from Instance ancestry.

## Native observer and geometry contract

`RobloxFragmentGeometry` implements `getClientRect`, `rectangle`, `isVisible`, `getIntersection`, and `validateIntersectionTarget`; internal exported `getClippingRect` in `modules/react-roblox/src/client/RobloxFragmentGeometry.lua` computes the native scroll window and supplies the same origin/bounds to `FragmentScroll.scrollIntoView`. A left scrollbar shifts the viewport origin; nearest scrolling leaves an already visible target unchanged instead of adding a spurious horizontal canvas offset. Raw rectangles intentionally ignore clipping and rotation. Intersection supports ScreenGui viewport and GuiObject ClipsDescendants geometry. ScrollingFrame clipping uses `AbsoluteWindowSize` and the actual left scrollbar window origin, with window-size and scrollbar property subscriptions; a public native gutter regression preserves raw `getClientRects` bounds while excluding the scrollbar from intersection. It rejects SurfaceGui/BillboardGui and rotated targets/clipping chains precisely. Occlusion is outside geometric intersection semantics. `RobloxFragmentObservers` implements factories plus `observe`, `unobserve`, `unobserveAfterExit`, `releaseOwner`, `releaseOwnerAfterExit`, `disconnect`, and `takeRecords`. Native adapters validate/normalize thresholds and root margins, rebuild ancestry subscriptions, and schedule one frame settlement rather than permanently poll targets. Owner tokens keep overlapping Fragments independent; resize targets release immediately, intersection removal preserves a final exit before releasing a pending owner.

## Verification and exact native event deviations

The 88 rows above are the complete original source case order, including repeated titles in separate families. Adapted rows identify their exact retained title and suite; exclusions have no fabricated mirror test. Concrete pass evidence and revisions are supplied by the standalone and client gate reports; a row's adaptation status alone is not a test-pass claim.

Native same-signal callback ordering differs from DOM registration order: engine delivery may invoke a later direct listener before an earlier Fragment listener. Multi-listener assertions compare exact sorted identities/counts, preserving emission sequence and no missing or duplicate callbacks. No synthetic reorder layer exists. Native signals do not bubble, so nested Fragment ownership follows first-level host membership rather than DOM propagation. The Activity source cases use physically retained native handles where hidden hosts are detached. Source teardown removes/destroys its container without adding a React root unmount that would alter the source effect-cleanup scenario.

The suite contains 68 applicable adapted source cases and 20 explicit engine exclusions. Additional adapter regressions live in `FragmentNativeEvents.spec.lua` and `FragmentMembership.spec.lua`: cancellation boundary errors permit later re-registration and preserve a synchronous reentrant replacement, once is removed before reentrant child emission, stale cancellation cannot remove a new registration, and retained deletion releases reverse ownership and cancellation while frozen prior snapshots remain valid. Foreign cancellation, observer deletion, and manual unobserve failures attempt all remaining cleanup before surfacing the first preserved error; public regressions cover each boundary. Native immediate delivery is empirically tested; removed-registration queued-delivery suppression is implemented by exact registration+connection identity gates, but actual deferred engine delivery has not been dynamically demonstrated in the current client context.


## Prerequisite test translations

Retained prerequisites use their own pinned source revisions. Suspense acceptance
cases preserve null child slots with explicit Luau sentinels, stable callback refs
with `useCallback`, and child-before-parent reconnection logs. These translations
follow `ReactSuspenseEffectsSemantics-test.js` at the release pin: class reveal
L849–867, nested host reveal L972–981, and stable RefCheckerOuter L2827–2834.
The ActivityLegacySuspense thenable captures its own record and defers an
already-resolved notification, following `ae74234eae6ebd62f19190731278e20bc1c37d51`
L78–98. Legacy fixtures install mocked timers before loading modules, matching the pinned Jest config’s globally enabled legacy fake timers. The Noop JSX snapshot adapter writes the named `props.children` field when synthesizing a Fragment; JavaScript object shorthand translates to an explicit Luau key (`ae74234eae6ebd62f19190731278e20bc1c37d51`, `createReactNoop.js` L1094–1105). The renderer Activity suite exercises real host Instances through
ReactRoblox's own act boundary; it does not mix two renderer host configurations.

The asynchronous act task boundary bypasses mocked timers, matching pinned `shared/enqueueTask.js`: Luau uses a one-shot `RunService.Heartbeat` callback instead of a `LuauPolyfill.setTimeout` closure that captures Jest’s mocked `task.delay`. A hundred-task probe verifies a true native turn: recursive `task.defer` can exceed Roblox’s reentrancy limit of 80 in one turn. This keeps pending-timer flushing and the next asynchronous act iteration on separate queues. The ref-as-prop prerequisite keeps module-pattern components enabled. Luau
function constructors cannot store JavaScript properties, so class prop
resolution reads defaultProps only from table constructors. The source algorithm
is `8a13ea0b7a4b161add410779e0abe2cd4cc230d2` L1229–1265. Retained string-ref
expectations use the pinned markRef error; transition errors preserve the
existing Error wrapper with an explicit Luau assertion.

The hidden Activity suspension prerequisite preserves `DidCapture` and removes
attempted child lanes before completion; completion skips bubbling a captured
hidden tree so it cannot overwrite those filtered lanes. The paired source is
`ae74234eae6ebd62f19190731278e20bc1c37d51`, BeginWork L642–687 and L827–871,
CompleteWork L1939–1950. Existing nested and legacy visibility guards remain.
The retained Legacy fixture mirrors the pinned asynchronous one-paint act loop,
including awaited `waitFor`/`waitForPaint`; the mock scheduler exposes its pinned
`scheduledCallback ~= nil` pending-work query. A native awaited turn drains Luau
promises in place of unsupported JavaScript `jest.runAllTicks`. The old renderer's
`flushSync` lacks modern synchronous passive flushing, so the final concurrent
event case explicitly calls public `flushPassiveEffects` before the unchanged
source log assertion. Commit `33c44d8bb85ca94fb68aacad4ab0c2f4a7f82215` contains
these required source/interop translations and the named Noop snapshot field.

## Recorded native verification

Fresh actual-client executions pass all 85 retained public callbacks in both
DEV and production on runtime commit
`c1078af394e01203e5024e48d843829c5186a98b`: 18 focus, 17 query, 2 rectangle,
14 scroll, 17 event methods, 7 cleanup/event regressions, 2 membership, and
8 observer cases. Engine `0.742.0.7421053` reports viewport 1809×910 and inset
(0, 58); both actual `__DEV__` values are recorded. SignalBehavior is unreadable
in that context. Expected static-key and cleanup-boundary warnings are retained.
The left-gutter scroll regression reproduces CanvasPosition (20, 300) before the
fix and (0, 300) after it, with the target already inside the actual native window.
The additional gutter cases do not alter the original 88-source-case ledger.

## Verification harness and capability limits

The verification harness maps these repository modules beside public Jest-Lua
and Luau polyfill dependencies from the Anime Rush workspace. Harness projects,
setup files, uploaded places, and reports are external local verification
artifacts and do not ship as runtime files. DEV sets `__DEV__ = true`; production
sets `__DEV__ = false`. Both set `__ROACT_17_MOCK_SCHEDULER__ = true`, `CI = true`,
and compatibility warnings. Production setup explicitly returns a module value.

To reproduce the public server gates, install the Anime Rush workspace's frozen
pnpm dependencies and provide its configured Open Cloud `.env`. Run the following
Node setup from this standalone checkout, with `ANIME_RUSH` set to that workspace's
absolute path. Rojo 7.7.1 must be on PATH. The generated `.harness/`, project,
configurations, place, and report files are local verification artifacts; exclude
them in `.git/info/exclude` and do not package them.

Save this as `.harness/setup.mjs`, then run `node .harness/setup.mjs`:

```javascript
import fs from 'node:fs';
import path from 'node:path';
const workspace = process.env.ANIME_RUSH;
if (!workspace) throw new Error('Set ANIME_RUSH to the workspace absolute path');
const deps = path.join(workspace, 'node_modules');
const installed = JSON.parse(fs.readFileSync(path.join(deps, 'default.project.json')));
const packages = {};
for (const [name, node] of Object.entries(installed.tree['@rbxts-js'])) {
  if (!name.startsWith('$')) packages[name] = { $path: path.resolve(deps, node.$path).replaceAll('\\', '/') };
}
for (const directory of fs.readdirSync('modules')) {
  const manifest = `modules/${directory}/rotriever.toml`;
  if (!fs.existsSync(manifest)) continue;
  const name = /^name = "(.*)"/m.exec(fs.readFileSync(manifest, 'utf8'))[1];
  if (name !== 'ExampleApp') packages[name] = { $path: `modules/${directory}/src` };
}
for (const directory of ['dev', 'dev2', 'setup']) fs.mkdirSync(`.harness/${directory}`, { recursive: true });
for (const name of Object.keys(packages)) {
  fs.writeFileSync(`.harness/dev/${name}.lua`, `return require(script.Parent.Parent.${name})\n`);
  fs.writeFileSync(`.harness/dev2/${name}.lua`, `return require(script.Parent.Parent.Parent.Parent.${name})\n`);
}
fs.writeFileSync('.harness/dev/ReactNoop.lua', 'return require(script.Parent.Parent.ReactNoopRenderer)\n');
fs.writeFileSync('.harness/setup/globals.lua', `local ReactGlobals = require(script.Parent.Parent.Parent.ReactGlobals)
local flags = { __DEV__ = _G.__HARNESS_PROD__ ~= true, __COMPAT_WARNINGS__ = true, __ROACT_17_MOCK_SCHEDULER__ = true, CI = true }
for key, value in flags do _G[key] = value ReactGlobals[key] = value end
return nil
`);
fs.writeFileSync('.harness/setup/prod.lua', '_G.__HARNESS_PROD__ = true\nreturn nil\n');
const tree = {
  $className: 'DataModel',
  ServerScriptService: { $className: 'ServerScriptService', $properties: { LoadStringEnabled: true } },
  ReplicatedStorage: { $className: 'ReplicatedStorage', Packages: {
    $className: 'Folder', ...packages, Dev: { $path: '.harness/dev' },
    _Workspace: { $className: 'Folder', jest: { $path: 'WorkspaceStatic/jest' },
      TestRunner: { $className: 'Folder', Dev: { $path: '.harness/dev2' } }, setup: { $path: '.harness/setup' } }
  } }
};
fs.writeFileSync('harness.project.json', JSON.stringify({ name: 'react-luau-harness', tree }, null, 2));
const names = ['react', 'shared', 'react-noop-renderer', 'react-test-renderer', 'react-roblox'];
const configs = { core: names.slice(0, 4), 'react-shared': ['react', 'shared'], 'test-renderer': ['react-test-renderer'], roblox: ['react-roblox'] };
const suites = fs.readdirSync('modules/react-reconciler/src/__tests__').filter(n => n.endsWith('.spec.lua')).sort();
for (let batch = 0; batch < 5; batch++) configs[`reconciler-${batch}`] = ['react-reconciler'];
for (const [group, modules] of Object.entries(configs)) for (const mode of ['dev', 'prod']) {
  const batch = group.startsWith('reconciler-') ? Number(group.slice(-1)) : null;
  const config = { backend: 'open-cloud', jestPath: 'ReplicatedStorage/Packages/Jest',
    rojoProject: 'harness.project.json', placeFile: 'harness.rbxl', timeout: 600000,
    test: { testTimeout: 30000, projectTimeout: 0,
      setupFiles: [...(mode === 'prod' ? ['./.harness/setup/prod'] : []), './.harness/setup/globals'],
      setupFilesAfterEnv: ['./WorkspaceStatic/jest/testSetupFile'],
      projects: modules.map(name => ({ test: { displayName: name, outDir: `modules/${name}/src`,
        include: batch === null ? [`modules/${name}/src/**/__tests__/*.spec.lua`] :
          suites.slice(batch * 10, batch === 4 ? undefined : (batch + 1) * 10).map(file => `modules/${name}/src/__tests__/${file}`)
      } })) } };
  fs.writeFileSync(`jest.${group}.${mode}.config.json`, JSON.stringify(config, null, 2));
}
```

Use each generated group (`core`, `roblox`, `reconciler-0` through
`reconciler-4`) sequentially in both modes. The following PowerShell invocation
runs one group and saves its exact counts:

```powershell
node --env-file="$env:ANIME_RUSH/.env" "$env:ANIME_RUSH/node_modules/@isentinel/jest-roblox/bin/jest-roblox.js" --config jest.core.dev.config.json --backend open-cloud --no-coverage --formatters json --outputFile core-dev.json
```

The five sorted reconciler partitions cover all 49 retained suite files, without
changing assertions or excluding failure cases. `--testPathPattern` and
`--testNamePattern` narrow a diagnostic run; its filtered cases are counted
separately from original skipped cases. Noop has no matching standalone suites of its own; retained reconciler suites exercise its adapter. TestRenderer has its own retained suites and is also exercised through reconciler tests. Package aggregation and original assertion execution are reported separately when a public runner serialization error prevents a complete result.

The native `bin/ci.sh` pipeline requires unavailable `rotrieve`, `roblox-cli`,
`robloxdev-cli`, and private package installation. Its engine flags include
EnableLoadModule and DebugDisableOptimizedBytecode. The public Open Cloud runner
clamps each task to 300 seconds regardless of its larger recovery poll timeout;
complete reconciler coverage is partitioned into five disjoint file batches.
Task creation shares a five-per-minute rate limit and concurrent-task limit, so
new cloud launches run sequentially.

JestRuntime detects native loading with `pcall(debug.loadmodule, ModuleScript)`.
The Open Cloud server probe reports `debug.loadmodule is not enabled`. The five
unchanged Shared stack/module-name assertions fail identically on pre-feature
`16014a8` and the feature under loadstring. These are preserved alternate-backend
failures; the native metadata verification gate lacks its loader prerequisite.
Native geometry/focus/scroll fixtures set `ScreenGui.ResetOnSpawn = false`: an isolated-place avatar respawn otherwise destroys a fixture during its retained frame waits. This fixture correction preserves original assertions and geometry behavior. Standard client Jest also cannot read ModuleScript.Source in its security context.
Owned native-client execution runs the retained public case bodies with explicit
assertion translations and records that separate evidence.

The five preserved metadata failure titles are:

- `errorToString gives stack trace for Error`
- `parseReactError parses errors created by errorToString`
- `parseReactError separates the stack frame from the rethrow`
- `function components gets fileName:lineNumber from anonymous function`
- `Lazy components gets fileName:lineNumber from lazy-wrapped anonymous function`

They reside in `modules/shared/src/__tests__/ErrorHandling.roblox.spec.lua` and
`getComponentName.roblox.spec.lua`. To reproduce the native prerequisite probe,
write the following setup module, prepend its path to the configuration's
`setupFiles`, and run those original suites using
`--testPathPattern 'ErrorHandling|getComponentName'`:

```lua
local candidate = Instance.new("ModuleScript")
local ok, result = pcall(debug.loadmodule, candidate)
candidate:Destroy()
assert(ok, "debug.loadmodule prerequisite unavailable: " .. tostring(result))
return nil
```

The setup fails with the named missing capability before any assertion runs;
removing the probe reproduces the five preserved loadstring metadata failures.

## Available whole-suite results

Counts are pass / fail / skip / total. The reconciler partitions are disjoint;
diagnostic filtered cases, targeted prerequisite replays, and native callbacks
are excluded from their totals. A failed aggregate remains failed. The final
batch-0, package aggregates, and native runs use `c1078af`; earlier unaffected
partitions retain equivalent source/configuration inputs, with changed async
act consumers replayed separately.

| Original suite group | DEV | Production |
| --- | --- | --- |
| Reconciler partition 0 | 94 / 14 / 10 / 118 | 102 / 2 / 10 / 114 |
| Reconciler partition 1 | 118 / 0 / 3 / 121 | 118 / 0 / 3 / 121 |
| Reconciler partition 2 | 234 / 0 / 36 / 270 | 233 / 0 / 36 / 269 |
| Reconciler partition 3 | 194 / 2 / 7 / 203 | 195 / 1 / 7 / 203 |
| Reconciler partition 4 | 90 / 1 / 14 / 105 | 77 / 1 / 14 / 92 |
| React and Shared | 302 / 5 / 28 / 335 | 285 / 5 / 28 / 318 |
| ReactRoblox | 134 / 0 / 44 / 178 | 134 / 0 / 44 / 178 |
| TestRenderer (external reporting adapter) | 46 / 2 / 0 / 48 | 47 / 1 / 0 / 48 |
| Reconciler total | 730 / 17 / 70 / 817 | 725 / 4 / 70 / 799 |

Additional required prerequisite gates pass: Legacy Activity/Suspense 8/8
in each mode; asynchronous Noop/TestRenderer act consumers 6/6 in each mode;
100 native task callbacks complete while a mocked timer remains pending.
The native callback evidence is separately 85/85 in each mode. Roblox server
skips retain the client-only cases; they are exercised by that native evidence.

The original failed titles remain unchanged:

| Original failure title | Suite | Observed modes |
| --- | --- | --- |
| Activity nested offscreen does not call componentWillUnmount when hidden | `Activity.spec.lua` | DEV, Production |
| Activity regression: Activity instance is sometimes null during setState | `Activity.spec.lua` | DEV |
| Activity passive effects are unmounted on hide in the same order as during a deletion: parent before child | `Activity.spec.lua` | DEV, Production |
| ReactErrorStacks includes built-in for Activity | `ActivityErrorStacks.spec.lua` | DEV |
| Naming conventions should warn if using old Roact didMount naming in Component | `ReactComponentLifeCycle.roblox.spec.lua` | DEV |
| Naming conventions should warn if using old Roact shouldUpdate naming in Component | `ReactComponentLifeCycle.roblox.spec.lua` | DEV |
| Naming conventions should warn if using old Roact willUpdate naming in Component | `ReactComponentLifeCycle.roblox.spec.lua` | DEV |
| Naming conventions should warn if using old Roact didUpdate naming in Component | `ReactComponentLifeCycle.roblox.spec.lua` | DEV |
| Naming conventions should warn if using old Roact willUnmount naming in Component | `ReactComponentLifeCycle.roblox.spec.lua` | DEV |
| Naming conventions should warn if using old Roact didMount naming in PureComponent | `ReactComponentLifeCycle.roblox.spec.lua` | DEV |
| Naming conventions should warn if using old Roact shouldUpdate naming in PureComponent | `ReactComponentLifeCycle.roblox.spec.lua` | DEV |
| Naming conventions should warn if using old Roact willUpdate naming in PureComponent | `ReactComponentLifeCycle.roblox.spec.lua` | DEV |
| Naming conventions should warn if using old Roact didUpdate naming in PureComponent | `ReactComponentLifeCycle.roblox.spec.lua` | DEV |
| Naming conventions should warn if using old Roact willUnmount naming in PureComponent | `ReactComponentLifeCycle.roblox.spec.lua` | DEV |
| ReactLazy throws with a useful error when wrapping Activity with lazy() | `ReactLazy-internal.spec.lua` | DEV, Production |
| ReactLazy warns about ref on functions for lazy-loaded components | `ReactLazy-internal.spec.lua` | DEV |
| ReactTransition should not interrupt transitions with normal pri updates | `ReactTransition.spec.lua` | DEV, Production |
| errorToString gives stack trace for Error | `ErrorHandling.roblox.spec.lua` | DEV, Production |
| parseReactError parses errors created by errorToString | `ErrorHandling.roblox.spec.lua` | DEV, Production |
| parseReactError separates the stack frame from the rethrow | `ErrorHandling.roblox.spec.lua` | DEV, Production |
| function components gets fileName:lineNumber from anonymous function | `getComponentName.roblox.spec.lua` | DEV, Production |
| Lazy components gets fileName:lineNumber from lazy-wrapped anonymous function | `getComponentName.roblox.spec.lua` | DEV, Production |
| ReactTestRenderer warns correctly for refs on SFCs | `ReactTestRenderer-internal.spec.lua` | DEV |
| ReactTestRenderer supports forwardRef | `ReactTestRenderer-internal.spec.lua` | DEV, Production |


## TestRenderer result transport

Public Jest Roblox CLI `0.4.6` with JestCore `3.16.0-ts.1` retains raw Expect `failureDetails` containing cyclic
Fiber graphs. The installed Jest Roblox CLI serializes its post-run aggregate
through `RunnerResult.build` and `HttpService.JSONEncode`; raw cycles reject the
entire result. Default reporter plus `--gameOutput` yields no retained messages
in this environment. An external reporting-only copy removes each assertion's
raw `failureDetails` after completion. Original `failureMessages`, titles,
statuses, suite counts, and test counts remain unchanged. Both the feature and
`16014a8` use the identical copy: TestRenderer returns 46/2/0/48 in DEV and
47/1/0/48 in production. The two failures are retained pre-ref-as-prop warning
and snapshot expectations, not Fragment regressions.

The published `src/cli/init.lua` SHA-256 is
`bf5b36c05623b220081ddab87ec53b606258427c818607e7d0c9a3988906adc8`.
After generating the harness above, save the following external adaptation as
`.harness/reporting.mjs`, run it with Node, and use the generated
`jest.test-renderer.dev.config.json` and production counterpart. This adapts the
reporting boundary, never matcher/assertion values or renderer state:

```javascript
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
const project = JSON.parse(fs.readFileSync('harness.project.json', 'utf8'));
const mount = project.tree.ReplicatedStorage.Packages.JestCore;
const source = path.join(mount.$path, 'src/cli/init.lua');
const bytes = fs.readFileSync(source);
if (crypto.createHash('sha256').update(bytes).digest('hex') !==
    'bf5b36c05623b220081ddab87ec53b606258427c818607e7d0c9a3988906adc8') {
  throw new Error('Verify the published JestCore reporting boundary before adapting it');
}
fs.cpSync(mount.$path, '.harness/jest-core-reporting', { recursive: true });
const needle = '\t\treturn { globalConfig = globalConfig, results = results }';
const adapter = `\t\tfor _, suite in ipairs(results.testResults) do
\t\t\tfor _, assertion in ipairs(suite.testResults) do
\t\t\t\tassertion.failureDetails = {}
\t\t\tend
\t\tend
`;
if (bytes.toString().split(needle).length !== 2) throw new Error('Unexpected aggregate boundary');
fs.writeFileSync('.harness/jest-core-reporting/src/cli/init.lua', bytes.toString().replace(needle, adapter + needle));
mount.$path = '.harness/jest-core-reporting';
fs.writeFileSync('harness.reporting.project.json', JSON.stringify(project, null, 2));
for (const mode of ['dev', 'prod']) {
  const file = `jest.test-renderer.${mode}.config.json`;
  const config = JSON.parse(fs.readFileSync(file, 'utf8'));
  config.rojoProject = 'harness.reporting.project.json';
  config.placeFile = 'harness.reporting.rbxl';
  fs.writeFileSync(file, JSON.stringify(config, null, 2));
}
```

Static verification on runtime `c1078af` covers all 44 changed Lua files relative
to `16014a8`: `stylua 0.18.1 --check`, `selene 0.28.0`, and
`luau-compile --null` pass; Selene reports zero errors/warnings. `git diff --check`
passes. The original native CI pipeline and native module-debug gate remain
unavailable for the exact prerequisites described above; public behavior and
preserved alternate-backend failures are reported separately.


## Preserved baseline compatibility failures

The pre-feature composed prerequisite revision is
`16014a8b9c4430f0f9b45160795a0be1744200cc`. Identical original source assertions
and external reporting adapters reproduce the current failures on that revision:

| Comparison | Baseline evidence | Current evidence |
| --- | --- | --- |
| Activity nested-hide lifecycle, `Activity.spec.lua:310` | Expected `{"child"}`; actual `{"child", "componentWillUnmount"}`. | Same exact log mismatch on `c1078af`. |
| Activity passive-hide ordering, `Activity.spec.lua:1099` | Expected `{"Unmount Parent", "Unmount Child"}`; actual `{"Unmount Child", "Unmount Parent"}`. | Same exact log mismatch on `c1078af`. |
| Activity warning, `Activity.spec.lua:672` | Existing warning says `asynchronously later calls tries` and includes an extra Activity frame. | Same warning text/stack mismatch. |
| Activity error-stack and ten old Roact naming cases | Original two-suite run: 20 pass, 11 fail, 0 skip, 31 total. Naming source locations are `[C]:-1`; error stack contains an extra CatchingBoundary frame. | Same eleven failed titles in the full DEV partition. |
| Lazy/Transition | Original two-suite run: 11 pass, 3 fail, 11 skip, 25 total in DEV. | Exact same three failed titles; production omits the DEV-only ref warning. |
| Shared native debug metadata | Original five metadata assertions fail under loadstring. Native `debug.loadmodule` capability is unavailable. | Same five alternate-backend assertion failures; native gate remains blocked. |
| TestRenderer | DEV 46/2/0/48; production 47/1/0/48. | Exact same titles/messages/counts after removing only raw reporting failureDetails. |

These comparisons preserve original assertions. The two Activity ordering cases
are executed behavior failures, not unavailable checks. The naming and Shared
source-location failures depend on native module-debug metadata; warning-stack
and ref-as-prop expectations retain their existing compatibility differences.
An earlier baseline whole-partition attempt reaches the actual 120-second task
deadline, so its incomplete output supplies no pass or aggregate claim. Focused
original cases supply the comparison above.

The whole-suite status is intentionally failed where the table records original
compatibility failures. All applicable Fragment public cases, ownership/error
regressions, required Legacy suspension corrections, and native GUI method cases
pass. Integration retains unrelated shipped transition/store/error backports.

To inspect source inventory without local artifacts, use the content-addressed
runtime revision and baseline:

```powershell
git diff --name-only 9351444c2db37caa08b38ad5de90f438db9221ea c1078af394e01203e5024e48d843829c5186a98b
$scope = @(git diff --name-only 16014a8b9c4430f0f9b45160795a0be1744200cc c1078af394e01203e5024e48d843829c5186a98b -- '*.lua')
stylua --check @scope
selene @scope
foreach ($file in $scope) { luau-compile --null $file }
git diff --check
```

Use the pinned tool versions above. Each commit records its source rationale and
Codex attribution; the standalone branch includes this ledger and all retained
tests, without external places, credential files, result blobs, or harness copies.

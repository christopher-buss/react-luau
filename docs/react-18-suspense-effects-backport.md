# React 18 Suspense effect semantics backport

## Upstream baseline

The behavior target is React `v18.0.0`, tag commit
`c0357aecab57835e1519589ac994fd33a7deb1af`.

The source history is:

- `7c1ba2b57d37df165da0f19c65ccc174866b5af7` — initial Suspense layout
  semantics and test suite;
- `e16d61c3000e2de6217d06b9afad162e883f73c4` — Offscreen layout lifecycle;
- `d0f348dc1b1ab1c3f7377f918d8ffd3fa64c6918` — failed layout semantics fix;
- `a97b5ac078499e33bbcf937935ab7139a317bac4` — visibility-change gating;
- `34600f4fadf526028a21c94030510fbed20e4665` — reappear traversal;
- `262ff7ad2c4a018de9992731fcf8a8f9c91083d8` — disappear traversal;
- `9ab90de602357407fb03a27715b61761a258a8c4` — Offscreen ownership;
- `ae5d26154b1e206774533a8313221d309f273090` — LegacyHidden exclusion.

## Source ledger

| Upstream source or test | React-Luau target | Port status | Deviation |
| --- | --- | --- | --- |
| `packages/shared/ReactFeatureFlags.js`: `enableSuspenseLayoutEffectSemantics` | `modules/shared/src/ReactFeatureFlags.lua` | Adapted | React-Luau has one feature flag module instead of renderer forks. The stable React 18 client behavior is enabled. |
| `packages/react-reconciler/src/ReactFiberCommitWork.new.js`: Offscreen mutation and layout handling | `modules/react-reconciler/src/ReactFiberCommitWork.new.lua` | Adapted | React-Luau retains the recursive React 17 commit traversal. Equivalent recursive disappear and reappear walks preserve upstream pre-order cleanup, post-order setup, nested-hidden pruning, error continuation, class lifecycles, and ref handling. |
| `packages/react-reconciler/src/ReactFiberCommitWork.new.js`: `hideOrUnhideAllChildren` | `modules/react-reconciler/src/ReactFiberCommitWork.new.lua` | Direct | Only topmost host nodes are hidden or revealed, matching React 18. |
| `packages/react-reconciler/src/ReactFiberCompleteWork.new.js`: Offscreen visibility scheduling | `modules/react-reconciler/src/ReactFiberCompleteWork.new.lua` | Adapted | The React 17 flag layout uses `Update` for Offscreen visibility work instead of React 18's separate `Visibility` flag. |
| `packages/react-reconciler/src/ReactFiberFlags.js`: `Visibility` | Existing `Update` flag in `modules/react-reconciler/src/ReactFiberFlags.lua` | Adapted | A new bit would only duplicate the existing React 17 mutation dispatch path. |
| `packages/react-reconciler/src/ReactFiberFlags.js`: `LayoutStatic` and `RefStatic` | No target | Out of scope | React 18.0.0's disappear and reappear traversals still visit the complete Offscreen subtree and contain TODOs to use these flags. React-Luau's recursive adaptation does the same, so the unused optimization flags do not affect behavior. |
| `packages/react-reconciler/src/ReactFiberHooks.new.js`: set `LayoutStatic` | No target | Out of scope | Static-flag optimization is not consulted by the React 18.0.0 behavior-bearing traversal. Hook layout effects are read directly from each fiber's effect list. |
| `packages/react-reconciler/src/ReactFiberClassComponent.new.js`: set `LayoutStatic` | No target | Out of scope | Static-flag optimization is not consulted; class lifecycles are selected by fiber tag during the complete traversal. |
| `packages/react-reconciler/src/ReactFiberBeginWork.new.js`: preserve static flags on bailout | Existing bailout and recursive traversal | Out of scope | The complete traversal reaches memoized fibers without relying on `LayoutStatic`; the memoization test covers this deviation. |
| `packages/react-reconciler/src/ReactFiberCompleteWork.old.js`, `ReactFiberCommitWork.old.js`, `ReactFiberHooks.old.js`, and `ReactFiberClassComponent.old.js` | No target | Out of scope | React-Luau ships only its new reconciler fork. |
| Renderer-specific feature flag forks | `modules/shared/src/ReactFeatureFlags.lua` | Adapted | React-Luau does not build separate DOM, native, WWW, and test-renderer flag forks. |
| `ReactSuspenseEffectsSemanticsDOM-test.js` | No direct target | Out of scope | React-Luau has no DOM renderer. Topmost host-node visibility and nested host traversal are covered through the mutation ReactNoop renderer. |
| `ReactOffscreen-test.js` follow-up cases | No direct target | Out of scope | React-Luau does not expose React 18's `unstable_Offscreen`; the same internal Offscreen lifecycle is exercised through public `React.Suspense`. |
| `ReactSuspense-test.internal.js` follow-up case | Existing `ReactSuspense-internal.spec.lua` plus the new semantics suite | Adapted | The public Suspense lifecycle suite owns the layout contract; the existing internal suite continues to own general thrown-wakeable behavior. |
| `ReactSuspenseWithNoopRenderer-test.js` follow-up cases | `ReactSuspenseEffectsSemantics.spec.lua` | Adapted | Relevant concurrent Noop behavior is asserted in the dedicated semantics suite. |

## Test ledger

Every case from React 18.0.0's
`packages/react-reconciler/src/__tests__/ReactSuspenseEffectsSemantics-test.js`
is present in
`modules/react-reconciler/src/__tests__/ReactSuspenseEffectsSemantics.spec.lua`
in upstream order.

| Upstream test | Port status | Deviation |
| --- | --- | --- |
| `should not change behavior in concurrent mode` | Adapted | The unavailable `getCacheForType` cache is a controllable Luau thenable; layout events remain the assertion seam. |
| `should not change behavior in sync` | Adapted | Uses `ReactNoop.createLegacyRoot`; layout events remain the assertion seam. |
| `should not be destroyed or recreated in legacy roots` | Adapted | Uses a controllable thenable instead of the upstream cache. |
| `should be destroyed and recreated for function components` | Adapted | A synchronous fallback commit replaces Jest virtual-time expiration; lifecycle order is unchanged. |
| `should be destroyed and recreated for class components` | Adapted | Luau class construction and `:` lifecycle calls replace JavaScript classes. |
| `should be destroyed and recreated when nested below host components` | Adapted | Host shape is asserted through ReactNoop and lifecycle order. |
| `should be destroyed and recreated even if there is a bailout because of memoization` | Adapted | Uses Luau's `React.memo` comparator function. |
| `should respect nested suspense boundaries` | Adapted | Uses synchronous fallback commits; nested cleanup and recreation assertions are preserved. |
| `should show nested host nodes if multiple boundaries resolve at the same time` | Adapted | Host visibility is exercised through ReactNoop's mutation host config rather than DOM. |
| `should be cleaned up inside of a fallback that suspends` | Adapted | Uses controllable thenables and layout-only observations. |
| `should be cleaned up inside of a fallback that suspends (alternate)` | Adapted | Uses controllable thenables and layout-only observations. |
| `should be cleaned up deeper inside of a subtree that suspends` | Adapted | Uses controllable thenables and layout-only observations. |
| `are properly handled for componentDidMount` | Adapted | Error recovery scheduling differs; assertions preserve continued sibling layout work and ErrorBoundary recovery. |
| `are properly handled for componentWillUnmount` | Adapted | Error recovery scheduling differs; assertions preserve continued cleanup, fallback mount, and ErrorBoundary recovery. |
| `are properly handled for layout effect creation` | Adapted | Error recovery scheduling differs; assertions preserve continued layout setup and ErrorBoundary recovery. |
| `are properly handled for layout effect destruction` | Adapted | Error recovery scheduling differs; assertions preserve continued layout cleanup and ErrorBoundary recovery. |
| `should be only destroy layout effects once if a tree suspends in multiple places` | Adapted | Two controllable thenables replace cached text resources. |
| `should be only destroy layout effects once if a component suspends multiple times` | Adapted | The component switches between two controllable thenables. |
| `should not be cleared within legacy roots` | Adapted | Uses one callback ref and its enclosing layout effect as the public observation seam. |
| `should be cleared and reset for host components` | Adapted | Uses one callback ref and its enclosing layout effect as the public observation seam. |
| `should be cleared and reset for class components` | Adapted | Uses a Luau class ref and its enclosing layout effect. |
| `should be cleared and reset for function components with useImperativeHandle` | Adapted | Uses a Luau forward-ref component and callback ref. |
| `should not reset for user-managed values` | Adapted | Uses a user-owned ref-shaped table that is never attached to a host node. |
| `are properly handled in ref callbacks` | Adapted | Error recovery scheduling differs; assertions preserve continued layout setup and ErrorBoundary recovery. |

React-Luau does not expose React 18 cache ownership APIs, so cache retention and
release are outside this client layout lifecycle backport.

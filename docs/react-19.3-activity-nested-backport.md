# React 19.3 nested hidden boundary visibility

The mirror pins React commit
[`1d68bce19c9409ed70604d1d16b70b68ce71dc4a`](https://github.com/facebook/react/commit/1d68bce19c9409ed70604d1d16b70b68ce71dc4a)
(#34821). An inner Activity or Suspense Offscreen must preserve a hidden
ancestor that controls the same host node. A HostComponent between the
boundaries ends that direct relationship.

The branch starts at React-Luau main `9351444` and applies the existing React 18
transition, Suspense effects, React 19.2 Activity, and insertion/Effect Event
hook mirrors as separate prerequisites. The hook prerequisite reuses
`646a31b`, the existing counterpart of PR #28's `8e0a62c`; insertion effects
preserve every lifecycle assertion in the new Suspense test. Effect Events are
an adjacent prerequisite in that existing commit, not this feature's scope.

The exact Activity fixture also exposes a missing React 19.2 prerequisite:
initially hidden Offscreen mounts need a visibility effect even without
descendant mutations. `7d70661` ports React 19.2 CompleteWork lines 1926–1932.
React-Luau's existing `Update` flag represents the upstream `Visibility` flag.

| Upstream source or test | React-Luau target | Port status | Deviation |
| --- | --- | --- | --- |
| `ReactFiberCommitWork.js` direct hidden Offscreen tracking, HostComponent reset, Offscreen visibility guard | `modules/react-reconciler/src/ReactFiberCommitWork.new.lua` `hasHiddenOffscreenDirectParent`, `commitWork` | Adapted | React 17 commits children before parents; a finished-tree ancestor scan replaces stack state. HostComponent and HostRoot end the scan. LegacyHidden remains supported. |
| `Activity-test.js` `reveal an inner Activity boundary without revealing an outer one on the same host child` | `modules/react-reconciler/src/__tests__/Activity.spec.lua`, same name | Adapted | JSX becomes createElement; ReactNoop.act executes the synchronous act callback. The memoized element, render order, and both expected outputs remain. |
| `Activity-test.js` `reveal an inner Suspense boundary without revealing an outer Activity on the same host child` | `modules/react-reconciler/src/__tests__/Activity.spec.lua`, same name | Adapted | React 17 lacks Promise children. A component throws the same never-settling Promise at its original sibling position. All three renders and expected outputs remain. |
| `ReactSuspenseEffectsSemantics-test.js` `should wait to reveal an inner child when inner one reveals first` and its Text/AsyncText setup | `modules/react-reconciler/src/__tests__/ReactSuspenseEffectsSemantics.spec.lua`, same name | Adapted | The existing controllable thenable replaces getCacheForType. Scheduler yields replace Scheduler.log/assertLog; all lifecycle logs and rendered output expectations remain. |
| React 19.2 `ReactFiberCompleteWork.js` initial hidden mount visibility effect | `modules/react-reconciler/src/ReactFiberCompleteWork.new.lua` | Adapted prerequisite | Update represents Visibility. LegacyHidden keeps its existing prerender-only behavior. |

The first fixture fails its initial output before the mount prerequisite:
the expected hidden div is visible. With that prerequisite, both Activity
cases pass even before the direct-parent guard. React 17's shared Update and
Visibility bit schedules an outer re-hide, masking the specific upstream
inner-reveal failure. These passing baseline cases are contract coverage,
not proof of a nested-unhide RED/GREEN cycle.

Standalone verification uses the existing ReactNoop renderer, the standalone
modules, and public Jest/polyfill dependencies installed by Anime Rush. The
local `.harness` mounts no Anime Rush React runtime. Studio CLI fails to start
the run within its 45-second bootstrap window; Open Cloud executes the tests
with the uploaded place version pinned by the Jest CLI.

The complete Suspense case retains its upstream assertions but is skipped:
React 17 delays the concurrent fallback commit inside act. The first
resuspension yields only `Suspend:InnerAsync` and `Text:InnerFallback render`,
instead of also committing insertion/layout/passive effects and retrying the
pending child. The same timing mismatch occurs before the new guard.
Changing the test to flushSync or dropping lifecycle assertions would alter
the pinned contract; modern Suspense retry scheduling remains a separate port.

Full standalone Activity and Suspense effects execution records 34 passed,
16 failed, and 2 skipped across 52 cases. The same 16 existing cases fail at
prerequisite revision `7d70661` with the same tests and harness but without the
direct-parent guard. Both new Activity cases pass. These full suites have a
baseline failure, not a green full-suite result. Existing warning text differs
from its expected modern wording; other failures cover legacy/deferred output,
class lifecycles, refs, and passive ordering. The focused three-specimen run
with the exact Suspense case enabled records 2 passed and 1 failed before
that case is marked skipped.

StyLua 2.5.2 check, Selene 0.31.0 (zero errors/warnings/parse errors), and
git diff --check pass for both runtime files and both changed test files.
The private rotrieve/robloxdev-cli analysis and execution harness is absent;
the public Open Cloud harness provides the execution results above.

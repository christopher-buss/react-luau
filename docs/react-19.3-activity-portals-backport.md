# Activity portal visibility

The mirror ports React commit
[`52684925368a41a0c9fbfca9016cdcbb72fc9d1e`](https://github.com/facebook/react/commit/52684925368a41a0c9fbfca9016cdcbb72fc9d1e)
([#35091](https://github.com/facebook/react/pull/35091)), included in React 19.3.0
tag `1d34f91dfde6bba84d08b683aaba164c7194dacb`.

The standalone branch starts at current fork main `9351444` and merges the
existing Activity branch `eacef3e`. Its retained prerequisite commits are
`532f2e8` and `9626a5b` (transitions), `9e6d492` (Suspense effects), and
`e27beae`, `355230c`, `8668948`, `e525471`, `eacef3e` (Activity). The merge base
for this feature is `94f1c57403b8ee231058bb187b3bf9407657b374`.
The independent nested Activity guard (`cdf16ec`) and initial hidden visibility
scheduling (`31adf5b`) are separate temporary prerequisite commits; integration
uses that backport's common helper and completion hunk. The feature-only diff
base is `31adf5b8485bb9e1a7a7a92c4c3df05fb1beb5a3`.

| Upstream source or test | React-Luau target | Port status | Deviation |
| --- | --- | --- | --- |
| `ReactFiberCommitWork.js`, `hideOrUnhideAllChildren`, `hideOrUnhideAllChildrenOnFiber`, `hideOrUnhideNearestPortals`, `hideOrUnhideNearestPortalsOnFiber` | `modules/react-reconciler/src/ReactFiberCommitWork.new.lua` | Adapted | The control flow and four function boundaries mirror upstream. Existing `hideInstance`/`unhideInstance` callbacks replace modern commit wrappers. ReactRoblox has neither HostHoistable nor dehydrated host instances. Forward declarations support recursive Luau calls. |
| `ReactFiberCommitWork.js`, HostPortal mutation visibility context | `modules/react-reconciler/src/ReactFiberCommitWork.new.lua`, `hasHiddenOffscreenDirectParent` | Adapted | The React 17 mutation walk has no upstream visibility-context variables. An ancestor walk reads the same finished-tree state. Crossing HostPortal causes it to retain hidden ancestors beyond HostComponent parents. The common nested Activity guard owns the base walk. |
| `ReactFiberCompleteWork.js`, HostPortal completion | `modules/react-reconciler/src/ReactFiberCompleteWork.new.lua` | Direct | Set PortalStatic before bubbling properties. |
| `ReactFiberFlags.js`, PortalStatic and StaticMask | `modules/react-reconciler/src/ReactFiberFlags.lua` | Adapted | Preserve existing bits; the standalone fork uses free bit 18. Anime Rush uses free bit 20 above StoreConsistency and PlacementDEV. |
| `ReactDOMActivity-test.js`, `hiding an Activity boundary also hides the direct children of any portals it contains, regardless of how deeply nested they are` | `modules/react-roblox/src/client/__tests__/ReactRobloxActivityPortals.spec.lua` | Adapted | Preserve name, tree, state update, act ordering, and visibility assertions. Folder/TextLabel replace div/text. Detached Parent assertions replace display:none serialization. |
| `ReactDOMActivity-test.js`, `revealing an Activity boundary inside a portal does not reveal the portal contents if has a hidden Activity parent` | Same test suite | Skipped | Preserve name, tree, initial hidden states, reveal update, act ordering, and visibility assertions. Initially hidden Instances have no connected refs or DOM serialization, so absence from the two containers replaces hidden-markup assertions. |

ReactRoblox `act` synchronously flushes its mocked scheduler; fake timers replace
upstream's asynchronous internal-test-utils act machinery. Both cases use the
actual public ReactRoblox root and portal renderer. No React-internal test is
reconstructed inside Anime Rush.

The existing public package harness mounts this branch's `modules/*` beside
Jest-Lua/polyfill dependencies from the package store. Open Cloud executes the
exact uploaded place version. `bin/testing.sh` and `bin/ci.sh` additionally
require private `rotrieve` and `roblox-cli`/`robloxdev-cli` executables unavailable
on this machine; that unavailable harness is distinct from passing public
Jest-Lua execution. The fork has no separate CONTRIBUTING.md.

The first complete upstream case fails on the prerequisite baseline at the
portal-host Parent assertion and passes after the traversal port. The complete
second case remains skipped: the clean unskipped run passes the first case but
fails the second case's initial portal-container assertion (expected zero
attached children, received one), before the reveal update can execute. Both
an initial hidden Update flag and the direct hidden-ancestor guard are present.
This older nested hidden-prerender scheduling gap remains a required follow-up;
no empirical claim is made about that case's reveal assertion.

Studio-cli first reproduces the first regression (one failure), then later
launches fail to bootstrap within 45 and 90 seconds. Public Open Cloud execution
runs the equivalent standalone Jest-Lua cases; unavailable Studio launches are
infrastructure failures, not test failures.

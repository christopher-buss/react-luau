# Hidden Activity error isolation

React commit [717e70843e68db648d2fc75c57d1a61465a9f7f9](https://github.com/facebook/react/commit/717e70843e68db648d2fc75c57d1a61465a9f7f9)
([#35074](https://github.com/facebook/react/pull/35074)) prevents an ordinary
render error from escaping a hidden Activity into the visible ancestor Error
Boundary. Reveal retries the failed child and allows the ancestor to handle it.

The branch reuses the existing Activity prerequisite chain through
`eacef3e30540be8c0a11a3d2ab132008790ab96c`; the fix is a separate commit.
Activity begin-work already restores committed children after capture, and
unwind already converts `ShouldCapture` to `DidCapture`. Promise suspension
continues through its existing independent branch.

| Upstream source or test | React-Luau target | Port status | Deviation |
| --- | --- | --- | --- |
| `packages/react-reconciler/src/ReactFiberThrow.js`, `throwException`, Offscreen ordinary-error branch | `modules/react-reconciler/src/ReactFiberThrow.new.lua`, `throwException` | Adapted | Activity uses a public Offscreen Fiber directly; legacy hidden fibers retain their behavior. React 17 records root error recovery after finding a class/root handler, so abandoned hidden prerenders do not synchronously retry the root. |
| `packages/react-reconciler/src/__tests__/ActivityErrorHandling-test.js`, complete suite and sole test | `modules/react-reconciler/src/__tests__/ActivityErrorHandling.spec.lua` | Adapted | `Component:extend`, `Error.new`, synchronous Noop `act`, `unstable_yieldValue`, and `toHaveYielded` replace their JS counterparts. The Noop Fragment serializer uses positional props; expected fragments adapt that representation. React 17 logs two caught-error warnings on reveal; the mirror checks both while preserving the upstream two fallback yields and complete output assertions. |
| `packages/react-refresh/src/__tests__/ReactFreshIntegration-test.js`, Scope ref test gate | No runtime target | Out of scope | The changed gate concerns React Refresh and the experimental Scope API, which this client Activity fix does not ship. |

## Verification

The complete upstream mirror test fails on the prerequisite revision: hidden
`Oops!` renders the outer fallback and violates the initial `Visible` log.
It passes after this fix, including both initial output and reveal fallback
assertions. Open Cloud executes the standalone runtime through the Jest Roblox
CLI with `__DEV__` enabled and Scheduler mock enabled.

The repository-native `bin/testing.sh` cannot run here: `rotrieve`,
`roblox-cli`, and `robloxdev-cli` are absent and `Packages` is uninstalled.
The alternative harness mounts this checkout's `modules/*/src` and the installed
public Jest and polyfill packages. Its globals setup sets `__DEV__`,
`__COMPAT_WARNINGS__`, and `__ROACT_17_MOCK_SCHEDULER__` on both `_G` and
ReactGlobals. Each cloud execution pins the exact uploaded place version.
Local `studio-cli` execution fails to boot within 45 seconds before tests start;
this is distinct from a test failure.

Reproduction uses a local Rojo `harness.project.json` and `jest.config.json`
with `jestPath: ReplicatedStorage/Packages/Jest`, setup files for those globals
and `WorkspaceStatic/jest/testSetupFile`, and reconciler tests discovered under
`modules/react-reconciler/src/**/__tests__/*.spec.lua`. Run:

```text
jest-roblox --config jest.config.json --backend open-cloud --testPathPattern ActivityErrorHandling --no-coverage
selene --config selene.toml modules/react-reconciler/src/ReactFiberThrow.new.lua modules/react-reconciler/src/__tests__/ActivityErrorHandling.spec.lua
git diff --check
```

The repository-pinned StyLua 0.18.1 checks both changed source and the complete
new test successfully. Selene and `git diff --check` pass. The source retains
the older generic casts and punctuation; using a newer formatter would mix
unrelated changes into the backport.

The adjacent existing `ActivityErrorStacks` test fails its duplicate
caught-warning matcher on both the fixed runtime and the untouched Activity
prerequisite runtime. That baseline test remains unchanged.

-- ROBLOX upstream: https://github.com/facebook/react/blob/ae74234eae6ebd62f19190731278e20bc1c37d51/packages/react-reconciler/src/__tests__/ActivityLegacySuspense-test.js

local Packages = script.Parent.Parent.Parent
local JestGlobals = require(Packages.Dev.JestGlobals)
local beforeEach = JestGlobals.beforeEach
local afterEach = JestGlobals.afterEach
local describe = JestGlobals.describe
local it = JestGlobals.it
local jest = JestGlobals.jest
local jestExpect = JestGlobals.expect
local Promise = require(Packages.Promise)

local React
local ReactNoop
local Scheduler
local textCache
local enqueueTask

-- ROBLOX upstream: https://github.com/facebook/react/blob/ae74234eae6ebd62f19190731278e20bc1c37d51/packages/internal-test-utils/ReactInternalTestUtils.js#L37-L41
-- ROBLOX DEVIATION: Await the native task helper through Luau's promise API.
local function waitForTask()
	Promise.new(function(resume)
		enqueueTask(resume)
	end):expect()
end

-- ROBLOX upstream: https://github.com/facebook/react/blob/ae74234eae6ebd62f19190731278e20bc1c37d51/packages/internal-test-utils/internalAct.js#L115-L167
-- ROBLOX DEVIATION: Keep the retained renderer's act scope while awaiting
-- native tasks between upstream's individual paint and timer flushes.
local function act(scope)
	local thenable = ReactNoop.act(function()
		return Promise.new(function(resolve, reject)
			local ok, result = pcall(function()
				waitForTask()
				scope()
				while true do
					waitForTask()
					if not Scheduler.unstable_hasPendingWork() then
						if jest.getTimerCount() > 0 then
							-- ROBLOX DEVIATION: Jest-Lua has no process.nextTick queue;
							-- the awaited native turn drains Luau promise continuations.
							jest.runOnlyPendingTimers()
							waitForTask()
						end
						if not Scheduler.unstable_hasPendingWork() then
							break
						end
					end
					Scheduler.unstable_flushUntilNextPaint()
				end
			end)
			if ok then
				resolve(result)
			else
				reject(result)
			end
		end)
	end)
	Promise.new(function(resolve, reject)
		thenable:andThen(resolve, reject)
	end):expect()
end

describe("Activity Suspense", function()
	beforeEach(function()
		jest.resetModules()
		-- ROBLOX upstream: https://github.com/facebook/react/blob/ae74234eae6ebd62f19190731278e20bc1c37d51/scripts/jest/config.base.js#L31-L34
		-- ROBLOX DEVIATION: This package harness enables upstream's global
		-- fake timers in the fixture before renderer modules capture timers.
		jest.useFakeTimers()

		React = require(Packages.React)
		ReactNoop = require(Packages.Dev.ReactNoopRenderer)
		Scheduler = require(Packages.Scheduler)
		textCache = {}
		enqueueTask = require(Packages.Shared).enqueueTask
	end)
	afterEach(function()
		jest.useRealTimers()
	end)

	local function resolveText(text)
		local record = textCache[text]
		if record == nil then
			textCache[text] = {
				status = "resolved",
				value = text,
			}
		elseif record.status == "pending" then
			record.status = "resolved"
			record.value = text
			for _, ping in record.thenable.pings do
				ping()
			end
		end
	end

	local function readText(text)
		local record = textCache[text]
		if record ~= nil then
			if record.status == "pending" then
				Scheduler.unstable_yieldValue("Suspend! [" .. text .. "]")
				error(record.thenable)
			elseif record.status == "rejected" then
				error(record.value)
			end
			return record.value
		end

		Scheduler.unstable_yieldValue("Suspend! [" .. text .. "]")
		local thenable = { pings = {} }
		local newRecord = {
			status = "pending",
			thenable = thenable,
			value = thenable,
		}
		-- ROBLOX upstream: https://github.com/facebook/react/blob/ae74234eae6ebd62f19190731278e20bc1c37d51/packages/react-reconciler/src/__tests__/ActivityLegacySuspense-test.js#L78-L98
		-- ROBLOX DEVIATION: Declare the captured record before the Luau method;
		-- the thenable remains valid when a later render clears its cache entry.
		function thenable:andThen(resolve)
			if newRecord.status == "pending" then
				table.insert(self.pings, resolve)
			else
				task.defer(resolve, newRecord.value)
			end
		end
		textCache[text] = newRecord
		error(thenable)
	end

	local function Text(props)
		Scheduler.unstable_yieldValue(props.text)
		return props.text
	end

	local function AsyncText(props)
		readText(props.text)
		Scheduler.unstable_yieldValue(props.text)
		return props.text
	end

	it("basic example of suspending inside hidden tree", function()
		local function App()
			return React.createElement(
				React.Suspense,
				{ fallback = React.createElement(Text, { text = "Loading..." }) },
				React.createElement(
					"span",
					nil,
					React.createElement(Text, { text = "Visible" })
				),
				React.createElement(
					React.Activity,
					{ mode = "hidden" },
					React.createElement(
						"span",
						nil,
						React.createElement(AsyncText, { text = "Hidden" })
					)
				)
			)
		end

		local root = ReactNoop.createRoot()
		act(function()
			root.render(React.createElement(App))
		end)
		jestExpect(Scheduler).toHaveYielded({ "Visible", "Suspend! [Hidden]" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement("span", nil, "Visible")
		)

		act(function()
			resolveText("Hidden")
		end)
		jestExpect(Scheduler).toHaveYielded({ "Hidden" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				React.Fragment,
				nil,
				React.createElement("span", nil, "Visible"),
				React.createElement("span", { hidden = true }, "Hidden")
			)
		)
	end)

	it("LegacyHidden does not handle suspense", function()
		local function App()
			return React.createElement(
				React.Suspense,
				{ fallback = React.createElement(Text, { text = "Loading..." }) },
				React.createElement(
					"span",
					nil,
					React.createElement(Text, { text = "Visible" })
				),
				React.createElement(
					React.unstable_LegacyHidden,
					{ mode = "hidden" },
					React.createElement(
						"span",
						nil,
						React.createElement(AsyncText, { text = "Hidden" })
					)
				)
			)
		end

		local root = ReactNoop.createRoot()
		act(function()
			root.render(React.createElement(App))
		end)
		jestExpect(Scheduler).toHaveYielded({
			"Visible",
			"Suspend! [Hidden]",
			"Loading...",
		})
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				React.Fragment,
				nil,
				React.createElement("span", { hidden = true }, "Visible"),
				"Loading..."
			)
		)
	end)

	it("Regression: Suspending on hide should not infinite loop.", function()
		local setMode
		local function Container(props)
			local mode, updateMode = React.useState("visible")
			setMode = updateMode
			React.useEffect(function()
				return function()
					Scheduler.unstable_yieldValue("Clear [" .. props.text .. "]")
					textCache[props.text] = nil
				end
			end)
			return React.createElement(
				React.Suspense,
				{ fallback = "Loading" },
				React.createElement(
					React.Activity,
					{ mode = mode },
					React.createElement(AsyncText, { text = props.text })
				)
			)
		end

		local root = ReactNoop.createRoot()
		act(function()
			root.render(React.createElement(Container, { text = "hello" }))
		end)
		-- ROBLOX deviation: React-Luau does not implement sibling prewarming.
		jestExpect(Scheduler).toHaveYielded({ "Suspend! [hello]" })
		jestExpect(root).toMatchRenderedOutput("Loading")

		act(function()
			resolveText("hello")
		end)
		jestExpect(Scheduler).toHaveYielded({ "hello" })
		jestExpect(root).toMatchRenderedOutput("hello")

		act(function()
			setMode("hidden")
		end)
		jestExpect(Scheduler).toHaveYielded({ "Clear [hello]", "Suspend! [hello]" })
		jestExpect(root).toMatchRenderedOutput("")
	end)

	local function Details(props)
		return React.createElement(
			React.Suspense,
			{ fallback = React.createElement(Text, { text = "Loading..." }) },
			React.createElement(
				"span",
				nil,
				React.createElement(Text, {
					text = if props.open then "Open" else "Closed",
				})
			),
			React.createElement(
				React.Activity,
				{ mode = if props.open then "visible" else "hidden" },
				React.createElement("span", nil, props.children)
			)
		)
	end

	it("suspending inside currently hidden tree that's switching to visible", function()
		local root = ReactNoop.createRoot()
		act(function()
			root.render(
				React.createElement(
					Details,
					{ open = false },
					React.createElement(AsyncText, { text = "Async" })
				)
			)
		end)
		jestExpect(Scheduler).toHaveYielded({ "Closed", "Suspend! [Async]" })
		jestExpect(root).toMatchRenderedOutput(React.createElement("span", nil, "Closed"))

		act(function()
			React.startTransition(function()
				root.render(
					React.createElement(
						Details,
						{ open = true },
						React.createElement(AsyncText, { text = "Async" })
					)
				)
			end)
		end)
		jestExpect(Scheduler).toHaveYielded({ "Open", "Suspend! [Async]", "Loading..." })
		jestExpect(root).toMatchRenderedOutput(React.createElement("span", nil, "Closed"))

		act(function()
			resolveText("Async")
		end)
		jestExpect(Scheduler).toHaveYielded({ "Open", "Async" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				React.Fragment,
				nil,
				React.createElement("span", nil, "Open"),
				React.createElement("span", nil, "Async")
			)
		)
	end)

	it("suspending inside currently visible tree that's switching to hidden", function()
		local root = ReactNoop.createRoot()
		act(function()
			root.render(
				React.createElement(
					Details,
					{ open = true },
					React.createElement(Text, { text = "(empty)" })
				)
			)
		end)
		jestExpect(Scheduler).toHaveYielded({ "Open", "(empty)" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				React.Fragment,
				nil,
				React.createElement("span", nil, "Open"),
				React.createElement("span", nil, "(empty)")
			)
		)

		act(function()
			React.startTransition(function()
				root.render(
					React.createElement(
						Details,
						{ open = true },
						React.createElement(AsyncText, { text = "Async" })
					)
				)
			end)
		end)
		jestExpect(Scheduler).toHaveYielded({ "Open", "Suspend! [Async]", "Loading..." })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				React.Fragment,
				nil,
				React.createElement("span", nil, "Open"),
				React.createElement("span", nil, "(empty)")
			)
		)

		act(function()
			React.startTransition(function()
				root.render(
					React.createElement(
						Details,
						{ open = false },
						React.createElement(AsyncText, { text = "Async" })
					)
				)
			end)
		end)
		jestExpect(Scheduler).toHaveYielded({ "Closed", "Suspend! [Async]" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				React.Fragment,
				nil,
				React.createElement("span", nil, "Closed"),
				React.createElement("span", { hidden = true }, "(empty)")
			)
		)

		act(function()
			resolveText("Async")
		end)
		jestExpect(Scheduler).toHaveYielded({ "Async" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				React.Fragment,
				nil,
				React.createElement("span", nil, "Closed"),
				React.createElement("span", { hidden = true }, "Async")
			)
		)
	end)

	it("update that suspends inside hidden tree", function()
		local setText
		local function Child()
			local text, updateText = React.useState("A")
			setText = updateText
			return React.createElement(AsyncText, { text = text })
		end
		local function App(props)
			return React.createElement(
				React.Activity,
				{ mode = if props.show then "visible" else "hidden" },
				React.createElement("span", nil, React.createElement(Child))
			)
		end

		local root = ReactNoop.createRoot()
		resolveText("A")
		act(function()
			root.render(React.createElement(App, { show = false }))
		end)
		jestExpect(Scheduler).toHaveYielded({ "A" })

		act(function()
			React.startTransition(function()
				setText("B")
			end)
		end)
	end)

	it("updates at multiple priorities that suspend inside hidden tree", function()
		local setText
		local setStep
		local function Child()
			local text, updateText = React.useState("A")
			local step, updateStep = React.useState(0)
			setText = updateText
			setStep = updateStep
			return React.createElement(AsyncText, { text = text .. step })
		end
		local function App(props)
			return React.createElement(
				React.Activity,
				{ mode = if props.show then "visible" else "hidden" },
				React.createElement("span", nil, React.createElement(Child))
			)
		end

		local root = ReactNoop.createRoot()
		resolveText("A0")
		act(function()
			root.render(React.createElement(App, { show = false }))
		end)
		jestExpect(Scheduler).toHaveYielded({ "A0" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement("span", { hidden = true }, "A0")
		)

		act(function()
			React.startTransition(function()
				setStep(1)
			end)
			ReactNoop.flushSync(function()
				setText("B")
			end)
		end)
		jestExpect(Scheduler).toHaveYielded({ "Suspend! [B0]", "Suspend! [B1]" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement("span", { hidden = true }, "A0")
		)

		act(function()
			resolveText("B1")
		end)
		jestExpect(Scheduler).toHaveYielded({ "B1" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement("span", { hidden = true }, "B1")
		)
	end)

	it("detect updates to a hidden tree during a concurrent event", function()
		local setInner
		local function Child(props)
			local inner, updateInner = React.useState(0)
			setInner = updateInner
			React.useEffect(function()
				Scheduler.unstable_yieldValue(
					if inner ~= props.outer
						then "Tearing! Inner and outer are inconsistent!"
						else "Inner and outer are consistent"
				)
			end, { inner, props.outer })
			return React.createElement(Text, { text = "Inner: " .. inner })
		end

		local setOuter
		local function App(props)
			local outer, updateOuter = React.useState(0)
			setOuter = updateOuter
			return React.createElement(
				React.Fragment,
				nil,
				React.createElement(
					React.Activity,
					{ mode = if props.show then "visible" else "hidden" },
					React.createElement(
						"span",
						nil,
						React.createElement(Child, { outer = outer })
					)
				),
				React.createElement(
					"span",
					nil,
					React.createElement(Text, { text = "Outer: " .. outer })
				),
				React.createElement(
					React.Suspense,
					{ fallback = React.createElement(Text, { text = "Loading..." }) },
					React.createElement(
						"span",
						nil,
						React.createElement(Text, { text = "Sibling: " .. outer })
					)
				)
			)
		end

		local root = ReactNoop.createRoot()
		resolveText("Async: 0")
		act(function()
			root.render(React.createElement(App, { show = true }))
		end)
		jestExpect(Scheduler).toHaveYielded({
			"Inner: 0",
			"Outer: 0",
			"Sibling: 0",
			"Inner and outer are consistent",
		})
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				React.Fragment,
				nil,
				React.createElement("span", nil, "Inner: 0"),
				React.createElement("span", nil, "Outer: 0"),
				React.createElement("span", nil, "Sibling: 0")
			)
		)

		act(function()
			React.startTransition(function()
				setOuter(1)
				setInner(1)
				root.render(React.createElement(App, { show = false }))
			end)
			-- ROBLOX upstream: https://github.com/facebook/react/blob/ae74234eae6ebd62f19190731278e20bc1c37d51/packages/internal-test-utils/ReactInternalTestUtils.js#L43-L75
			-- ROBLOX DEVIATION: Preserve awaited waitFor's bounded yield and
			-- native task boundaries with the retained Scheduler log matcher.
			waitForTask()
			Scheduler.unstable_flushNumberOfYields(1)
			waitForTask()
			jestExpect(Scheduler).toHaveYielded({ "Outer: 1" })
			jestExpect(root).toMatchRenderedOutput(
				React.createElement(
					React.Fragment,
					nil,
					React.createElement("span", nil, "Inner: 0"),
					React.createElement("span", nil, "Outer: 0"),
					React.createElement("span", nil, "Sibling: 0")
				)
			)

			React.startTransition(function()
				setOuter(2)
				setInner(2)
			end)
			-- ROBLOX upstream: https://github.com/facebook/react/blob/ae74234eae6ebd62f19190731278e20bc1c37d51/packages/internal-test-utils/ReactInternalTestUtils.js#L259-L278
			-- ROBLOX DEVIATION: Preserve awaited waitForPaint's single paint
			-- and native task boundaries before comparing the original log.
			waitForTask()
			Scheduler.unstable_flushUntilNextPaint()
			waitForTask()
			jestExpect(Scheduler).toHaveYielded({ "Sibling: 1" })
			jestExpect(root).toMatchRenderedOutput(
				React.createElement(
					React.Fragment,
					nil,
					React.createElement("span", { hidden = true }, "Inner: 0"),
					React.createElement("span", nil, "Outer: 1"),
					React.createElement("span", nil, "Sibling: 1")
				)
			)

			ReactNoop.flushSync(function()
				root.render(React.createElement(App, { show = true }))
			end)
			-- ROBLOX upstream: https://github.com/facebook/react/blob/ae74234eae6ebd62f19190731278e20bc1c37d51/packages/react-reconciler/src/__tests__/ActivityLegacySuspense-test.js#L577-L591
			-- ROBLOX DEVIATION: The retained renderer's flushSync predates
			-- synchronous passive effects; drain that phase before the same log.
			ReactNoop.flushPassiveEffects()
			jestExpect(Scheduler).toHaveYielded({
				"Inner: 1",
				"Outer: 1",
				"Sibling: 1",
				"Inner and outer are consistent",
			})
		end)

		jestExpect(Scheduler).toHaveYielded({
			"Inner: 2",
			"Outer: 2",
			"Sibling: 2",
			"Inner and outer are consistent",
		})
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				React.Fragment,
				nil,
				React.createElement("span", nil, "Inner: 2"),
				React.createElement("span", nil, "Outer: 2"),
				React.createElement("span", nil, "Sibling: 2")
			)
		)
	end)
end)

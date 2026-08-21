-- ROBLOX upstream: https://github.com/facebook/react/blob/ae74234eae6ebd62f19190731278e20bc1c37d51/packages/react-reconciler/src/__tests__/Activity-test.js
-- ROBLOX DEVIATION: This throwaway client prototype exercises the public
-- ReactRoblox root instead of ReactNoop so host Instance hiding is observable.

local Packages = script.Parent.Parent.Parent.Parent

local JestGlobals = require(Packages.Dev.JestGlobals)
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local it = JestGlobals.it
local jest = JestGlobals.jest
local jestExpect = JestGlobals.expect

local React
local ReactNoop
local ReactRoblox
local Scheduler
local parent
local root

describe("Activity prototype", function()
	beforeEach(function()
		jest.resetModules()
		jest.useFakeTimers()

		React = require(Packages.React)
		ReactNoop = require(Packages.Dev.ReactNoopRenderer)
		ReactRoblox = require(Packages.ReactRoblox)
		Scheduler = require(Packages.Scheduler)
		parent = Instance.new("Folder")
		root = ReactRoblox.createRoot(parent)
	end)

	it("retains state and host instances while hidden", function()
		local setCount

		local function Child()
			local count, updateCount = React.useState(1)
			setCount = updateCount
			return React.createElement("IntValue", {
				Name = "Stateful",
				Value = count,
			})
		end

		local function renderActivity(mode)
			root:render(
				React.createElement(
					React.Activity,
					{ mode = mode },
					React.createElement(Child)
				)
			)
		end

		ReactRoblox.act(function()
			renderActivity("visible")
		end)

		local hostInstance = parent:FindFirstChild("Stateful")
		jestExpect(hostInstance).never.toBeNil()
		jestExpect((hostInstance :: IntValue).Value).toBe(1)

		ReactRoblox.act(function()
			setCount(2)
		end)
		jestExpect((hostInstance :: IntValue).Value).toBe(2)

		ReactRoblox.act(function()
			renderActivity("hidden")
		end)
		jestExpect(parent:FindFirstChild("Stateful")).toBeNil()

		ReactRoblox.act(function()
			renderActivity("visible")
		end)
		jestExpect(parent:FindFirstChild("Stateful")).toBe(hostInstance)
		jestExpect((hostInstance :: IntValue).Value).toBe(2)
	end)

	it("disconnects layout effects before hiding and reconnects after reveal", function()
		local events = {}
		local hostInstance

		local function Child()
			React.useLayoutEffect(function()
				table.insert(events, "mount layout")
				return function()
					jestExpect((hostInstance :: Instance).Parent).toBe(parent)
					table.insert(events, "unmount layout")
				end
			end, {})
			return React.createElement("Folder", {
				Name = "LayoutChild",
				ref = function(instance)
					if instance ~= nil then
						hostInstance = instance
					end
				end,
			})
		end

		local function renderActivity(mode)
			root:render(
				React.createElement(
					React.Activity,
					{ mode = mode },
					React.createElement(Child)
				)
			)
		end

		ReactRoblox.act(function()
			renderActivity("visible")
		end)
		jestExpect(events).toEqual({ "mount layout" })

		events = {}
		ReactRoblox.act(function()
			renderActivity("hidden")
		end)
		jestExpect(events).toEqual({ "unmount layout" })
		jestExpect((hostInstance :: Instance).Parent).toBeNil()

		events = {}
		ReactRoblox.act(function()
			renderActivity("visible")
		end)
		jestExpect(events).toEqual({ "mount layout" })
		jestExpect((hostInstance :: Instance).Parent).toBe(parent)
	end)

	it("disconnects passive effects while prerendering hidden updates", function()
		local events = {}

		local function Child(props)
			React.useEffect(function()
				table.insert(events, "mount " .. props.step)
				return function()
					table.insert(events, "unmount " .. props.step)
				end
			end, { props.step })
			return React.createElement("IntValue", {
				Name = "PassiveChild",
				Value = props.step,
			})
		end

		local function renderActivity(mode, step)
			root:render(
				React.createElement(
					React.Activity,
					{ mode = mode },
					React.createElement(Child, { step = step })
				)
			)
		end

		ReactRoblox.act(function()
			renderActivity("visible", 1)
		end)
		jestExpect(events).toEqual({ "mount 1" })

		events = {}
		ReactRoblox.act(function()
			renderActivity("hidden", 1)
		end)
		jestExpect(events).toEqual({ "unmount 1" })

		events = {}
		ReactRoblox.act(function()
			renderActivity("hidden", 2)
		end)
		jestExpect(events).toEqual({})

		ReactRoblox.act(function()
			renderActivity("visible", 2)
		end)
		jestExpect(events).toEqual({ "mount 2" })
	end)

	it("defers passive effects for an initially hidden tree", function()
		local events = {}

		local function Child()
			React.useEffect(function()
				table.insert(events, "mount")
				return function()
					table.insert(events, "unmount")
				end
			end, {})
			return React.createElement("Folder")
		end

		local function renderActivity(mode)
			root:render(
				React.createElement(
					React.Activity,
					{ mode = mode },
					React.createElement(Child)
				)
			)
		end

		ReactRoblox.act(function()
			renderActivity("hidden")
		end)
		jestExpect(events).toEqual({})

		ReactRoblox.act(function()
			renderActivity("visible")
		end)
		jestExpect(events).toEqual({ "mount" })
	end)

	it("disconnects passive effects parent before child", function()
		local events = {}

		local function Child()
			React.useEffect(function()
				table.insert(events, "mount child")
				return function()
					table.insert(events, "unmount child")
				end
			end, {})
			return React.createElement("Folder")
		end

		local function Parent()
			React.useEffect(function()
				table.insert(events, "mount parent")
				return function()
					table.insert(events, "unmount parent")
				end
			end, {})
			return React.createElement(Child)
		end

		local function renderActivity(mode)
			root:render(
				React.createElement(
					React.Activity,
					{ mode = mode },
					React.createElement(Parent)
				)
			)
		end

		ReactRoblox.act(function()
			renderActivity("visible")
		end)
		jestExpect(events).toEqual({ "mount child", "mount parent" })

		events = {}
		ReactRoblox.act(function()
			renderActivity("hidden")
		end)
		jestExpect(events).toEqual({ "unmount parent", "unmount child" })
	end)

	it("defers hidden renders and updates behind visible work", function()
		local setHiddenText

		local function Text(props)
			Scheduler.unstable_yieldValue(props.text)
			return props.text
		end

		local function HiddenText()
			local text, updateText = React.useState("Hidden A")
			setHiddenText = updateText
			return React.createElement(Text, { text = text })
		end

		local function App(props)
			return React.createElement(
				React.Fragment,
				nil,
				React.createElement(
					React.Activity,
					{ mode = "hidden" },
					React.createElement(HiddenText)
				),
				React.createElement(Text, { text = props.visibleText })
			)
		end

		local noopRoot = ReactNoop.createRoot()
		noopRoot.render(React.createElement(App, { visibleText = "Visible A" }))
		jestExpect(Scheduler).toFlushAndYieldThrough({ "Visible A" })
		jestExpect(Scheduler).toFlushAndYield({ "Hidden A" })

		setHiddenText("Hidden B")
		noopRoot.render(React.createElement(App, { visibleText = "Visible B" }))
		jestExpect(Scheduler).toFlushAndYieldThrough({ "Visible B" })
		jestExpect(Scheduler).toFlushAndYield({ "Hidden B" })
	end)

	it("contains Suspense inside a hidden Activity", function()
		local resolved = false
		local pings = {}
		local wakeable = {}

		function wakeable:andThen(resolve)
			table.insert(pings, resolve)
		end

		local function Text(props)
			Scheduler.unstable_yieldValue(props.text)
			return props.text
		end

		local function AsyncText()
			if not resolved then
				Scheduler.unstable_yieldValue("Suspend hidden")
				error(wakeable)
			end
			return React.createElement(Text, { text = "Hidden ready" })
		end

		local noopRoot = ReactNoop.createRoot()
		noopRoot.render(
			React.createElement(
				React.Suspense,
				{ fallback = React.createElement(Text, { text = "Fallback" }) },
				React.createElement(Text, { text = "Visible" }),
				React.createElement(
					React.Activity,
					{ mode = "hidden" },
					React.createElement(AsyncText)
				)
			)
		)

		jestExpect(Scheduler).toFlushAndYield({ "Visible", "Suspend hidden" })
		jestExpect(noopRoot).toMatchRenderedOutput("Visible")

		resolved = true
		for _, ping in pings do
			ping()
		end
		jestExpect(Scheduler).toFlushAndYield({ "Hidden ready" })
	end)
end)

-- ROBLOX upstream: https://github.com/facebook/react/blob/ae74234eae6ebd62f19190731278e20bc1c37d51/packages/react-reconciler/src/__tests__/Activity-test.js

local Packages = script.Parent.Parent.Parent
local JestGlobals = require(Packages.Dev.JestGlobals)
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local it = JestGlobals.it
local jest = JestGlobals.jest
local jestExpect = JestGlobals.expect

local React
local ReactNoop
local Scheduler

describe("Activity", function()
	beforeEach(function()
		jest.resetModules()

		React = require(Packages.React)
		ReactNoop = require(Packages.Dev.ReactNoopRenderer)
		Scheduler = require(Packages.Scheduler)
	end)

	local function Text(props)
		Scheduler.unstable_yieldValue(props.text)
		return React.createElement("span", { prop = props.text }, props.children)
	end

	it("revealing a hidden tree at high priority does not cause tearing", function()
		local currentOuter = nil
		local currentInner = nil

		local function areOuterAndInnerConsistent()
			return currentOuter == nil
				or currentInner == nil
				or currentOuter == currentInner
		end

		local setInner
		local function Child()
			local inner, updateInner = React.useState(0)
			setInner = updateInner

			React.useEffect(function()
				currentInner = inner
				return function()
					currentInner = nil
				end
			end, { inner })

			return React.createElement(Text, { text = "Inner: " .. inner })
		end

		local setOuter
		local function App(props)
			local outer, updateOuter = React.useState(0)
			setOuter = updateOuter

			React.useEffect(function()
				currentOuter = outer
				return function()
					currentOuter = nil
				end
			end, { outer })

			return React.createElement(
				React.Fragment,
				nil,
				React.createElement(Text, { text = "Outer: " .. outer }),
				React.createElement(
					React.Activity,
					{ mode = if props.show then "visible" else "hidden" },
					React.createElement(Child)
				)
			)
		end

		local root = ReactNoop.createRoot()
		ReactNoop.act(function()
			root.render(React.createElement(App, { show = false }))
		end)
		jestExpect(Scheduler).toHaveYielded({ "Outer: 0", "Inner: 0" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				React.Fragment,
				nil,
				React.createElement("span", { prop = "Outer: 0" }),
				React.createElement("span", { hidden = true, prop = "Inner: 0" })
			)
		)
		jestExpect(areOuterAndInnerConsistent()).toBe(true)

		setOuter(1)
		setInner(1)
		jestExpect(Scheduler).toFlushUntilNextPaint({ "Outer: 1" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				React.Fragment,
				nil,
				React.createElement("span", { prop = "Outer: 1" }),
				React.createElement("span", { hidden = true, prop = "Inner: 0" })
			)
		)

		React.startTransition(function()
			setOuter(2)
			setInner(2)
		end)

		ReactNoop.flushSync(function()
			root.render(React.createElement(App, { show = true }))
		end)

		jestExpect(Scheduler).toHaveYielded({ "Outer: 1", "Inner: 1" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				React.Fragment,
				nil,
				React.createElement("span", { prop = "Outer: 1" }),
				React.createElement("span", { prop = "Inner: 1" })
			)
		)
		jestExpect(areOuterAndInnerConsistent()).toBe(true)

		jestExpect(Scheduler).toFlushAndYield({ "Outer: 2", "Inner: 2" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				React.Fragment,
				nil,
				React.createElement("span", { prop = "Outer: 2" }),
				React.createElement("span", { prop = "Inner: 2" })
			)
		)
		jestExpect(areOuterAndInnerConsistent()).toBe(true)
	end)

	it("class component setState callbacks do not fire until tree is visible", function()
		local root = ReactNoop.createRoot()
		local child

		local Child = React.Component:extend("Child")
		function Child:init()
			self.state = { text = "A" }
		end
		function Child:render()
			child = self
			return React.createElement(Text, { text = self.state.text })
		end

		ReactNoop.act(function()
			root.render(
				React.createElement(
					React.Activity,
					{ mode = "hidden" },
					React.createElement(Child)
				)
			)
		end)
		jestExpect(Scheduler).toHaveYielded({ "A" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement("span", { hidden = true, prop = "A" })
		)

		ReactNoop.act(function()
			child:setState({ text = "B" }, function()
				Scheduler.unstable_yieldValue("B update finished")
			end)
		end)
		jestExpect(Scheduler).toHaveYielded({ "B" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement("span", { hidden = true, prop = "B" })
		)

		ReactNoop.act(function()
			root.render(
				React.createElement(
					React.Activity,
					{ mode = "visible" },
					React.createElement(Child)
				)
			)
			child:setState({ text = "C" }, function()
				Scheduler.unstable_yieldValue("C update finished")
			end)
		end)
		jestExpect(Scheduler).toHaveYielded({
			"C",
			"B update finished",
			"C update finished",
		})
		jestExpect(root).toMatchRenderedOutput(
			React.createElement("span", { prop = "C" })
		)
	end)
end)

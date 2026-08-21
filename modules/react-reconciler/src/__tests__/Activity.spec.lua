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

	it(
		"unstable-defer-without-hiding should never toggle the visibility of its children",
		function()
			local function App(props)
				return React.createElement(
					React.Fragment,
					nil,
					React.createElement(Text, { text = "Normal" }),
					React.createElement(
						React.unstable_LegacyHidden,
						{ mode = props.mode },
						React.createElement(Text, { text = "Deferred" })
					)
				)
			end

			local root = ReactNoop.createRoot()
			ReactNoop.act(function()
				root.render(
					React.createElement(App, { mode = "unstable-defer-without-hiding" })
				)
				jestExpect(Scheduler).toFlushUntilNextPaint({ "Normal" })
				jestExpect(root).toMatchRenderedOutput(
					React.createElement("span", { prop = "Normal" })
				)
			end)
			jestExpect(Scheduler).toHaveYielded({ "Deferred" })
			jestExpect(root).toMatchRenderedOutput(
				React.createElement(
					React.Fragment,
					nil,
					React.createElement("span", { prop = "Normal" }),
					React.createElement("span", { prop = "Deferred" })
				)
			)

			ReactNoop.act(function()
				root.render(React.createElement(App, { mode = "visible" }))
			end)
			jestExpect(Scheduler).toHaveYielded({ "Normal", "Deferred" })
			jestExpect(root).toMatchRenderedOutput(
				React.createElement(
					React.Fragment,
					nil,
					React.createElement("span", { prop = "Normal" }),
					React.createElement("span", { prop = "Deferred" })
				)
			)

			ReactNoop.act(function()
				root.render(
					React.createElement(App, { mode = "unstable-defer-without-hiding" })
				)
				jestExpect(Scheduler).toFlushUntilNextPaint({ "Normal" })
				jestExpect(root).toMatchRenderedOutput(
					React.createElement(
						React.Fragment,
						nil,
						React.createElement("span", { prop = "Normal" }),
						React.createElement("span", { prop = "Deferred" })
					)
				)
			end)
			jestExpect(Scheduler).toHaveYielded({ "Deferred" })
			jestExpect(root).toMatchRenderedOutput(
				React.createElement(
					React.Fragment,
					nil,
					React.createElement("span", { prop = "Normal" }),
					React.createElement("span", { prop = "Deferred" })
				)
			)
		end
	)

	it("does not defer in legacy mode", function()
		local setState
		local function Foo()
			local state, updateState = React.useState("A")
			setState = updateState
			return React.createElement(Text, { text = state })
		end

		local root = ReactNoop.createLegacyRoot()
		ReactNoop.act(function()
			root.render(
				React.createElement(
					React.Fragment,
					nil,
					React.createElement(
						React.unstable_LegacyHidden,
						{ mode = "hidden" },
						React.createElement(Foo)
					),
					React.createElement(Text, { text = "Outside" })
				)
			)
		end)
		jestExpect(Scheduler).toHaveYielded({ "A", "Outside" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				React.Fragment,
				nil,
				React.createElement("span", { prop = "A" }),
				React.createElement("span", { prop = "Outside" })
			)
		)

		ReactNoop.act(function()
			setState("B")
		end)
		jestExpect(Scheduler).toHaveYielded({ "B" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				React.Fragment,
				nil,
				React.createElement("span", { prop = "B" }),
				React.createElement("span", { prop = "Outside" })
			)
		)
	end)

	it("does defer in concurrent mode", function()
		local setState
		local function Foo()
			local state, updateState = React.useState("A")
			setState = updateState
			return React.createElement(Text, { text = state })
		end

		local root = ReactNoop.createRoot()
		ReactNoop.act(function()
			root.render(
				React.createElement(
					React.Fragment,
					nil,
					React.createElement(
						React.unstable_LegacyHidden,
						{ mode = "hidden" },
						React.createElement(Foo)
					),
					React.createElement(Text, { text = "Outside" })
				)
			)
			jestExpect(Scheduler).toFlushUntilNextPaint({ "Outside" })
		end)
		jestExpect(Scheduler).toHaveYielded({ "A" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				React.Fragment,
				nil,
				React.createElement("span", { prop = "A" }),
				React.createElement("span", { prop = "Outside" })
			)
		)

		ReactNoop.act(function()
			setState("B")
		end)
		jestExpect(Scheduler).toHaveYielded({ "B" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				React.Fragment,
				nil,
				React.createElement("span", { prop = "B" }),
				React.createElement("span", { prop = "Outside" })
			)
		)
	end)

	local function LayoutChild()
		React.useLayoutEffect(function()
			Scheduler.unstable_yieldValue("Mount layout")
			return function()
				Scheduler.unstable_yieldValue("Unmount layout")
			end
		end, {})
		return React.createElement(Text, { text = "Child" })
	end

	it("mounts without layout effects when hidden", function()
		local root = ReactNoop.createRoot()
		ReactNoop.act(function()
			root.render(
				React.createElement(
					React.Activity,
					{ mode = "hidden" },
					React.createElement(LayoutChild)
				)
			)
		end)
		jestExpect(Scheduler).toHaveYielded({ "Child" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement("span", { hidden = true, prop = "Child" })
		)

		ReactNoop.act(function()
			root.render(
				React.createElement(
					React.Activity,
					{ mode = "visible" },
					React.createElement(LayoutChild)
				)
			)
		end)
		jestExpect(Scheduler).toHaveYielded({ "Child", "Mount layout" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement("span", { prop = "Child" })
		)
	end)

	it(
		"mounts/unmounts layout effects when visibility changes (starting visible)",
		function()
			local root = ReactNoop.createRoot()
			local function renderActivity(mode)
				root.render(
					React.createElement(
						React.Activity,
						{ mode = mode },
						React.createElement(LayoutChild)
					)
				)
			end

			ReactNoop.act(function()
				renderActivity("visible")
			end)
			jestExpect(Scheduler).toHaveYielded({ "Child", "Mount layout" })
			jestExpect(root).toMatchRenderedOutput(
				React.createElement("span", { prop = "Child" })
			)

			ReactNoop.act(function()
				renderActivity("hidden")
			end)
			jestExpect(Scheduler).toHaveYielded({ "Unmount layout", "Child" })
			jestExpect(root).toMatchRenderedOutput(
				React.createElement("span", { hidden = true, prop = "Child" })
			)

			ReactNoop.act(function()
				renderActivity("visible")
			end)
			jestExpect(Scheduler).toHaveYielded({ "Child", "Mount layout" })
			jestExpect(root).toMatchRenderedOutput(
				React.createElement("span", { prop = "Child" })
			)
		end
	)

	it("nested offscreen does not call componentWillUnmount when hidden", function()
		local ClassComponent = React.Component:extend("ClassComponent")
		function ClassComponent:render()
			return React.createElement(Text, { text = "child" })
		end
		function ClassComponent:componentWillUnmount()
			Scheduler.unstable_yieldValue("componentWillUnmount")
		end
		function ClassComponent:componentDidMount()
			Scheduler.unstable_yieldValue("componentDidMount")
		end

		local root = ReactNoop.createRoot()
		local function renderModes(outerMode, innerMode)
			root.render(
				React.createElement(
					React.Activity,
					{ mode = outerMode },
					React.createElement(
						React.Activity,
						{ mode = innerMode },
						React.createElement(ClassComponent)
					)
				)
			)
		end

		ReactNoop.act(function()
			renderModes("hidden", "hidden")
		end)
		jestExpect(Scheduler).toHaveYielded({ "child" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement("span", { hidden = true, prop = "child" })
		)

		for _, modes in
			{
				{ "hidden", "visible" },
				{ "hidden", "hidden" },
				{ "hidden", "visible" },
			}
		do
			ReactNoop.act(function()
				renderModes(modes[1], modes[2])
			end)
			jestExpect(Scheduler).toHaveYielded({ "child" })
			jestExpect(root).toMatchRenderedOutput(
				React.createElement("span", { hidden = true, prop = "child" })
			)
		end

		ReactNoop.act(function()
			renderModes("visible", "hidden")
		end)
		jestExpect(Scheduler).toHaveYielded({ "child" })

		ReactNoop.act(function()
			renderModes("hidden", "visible")
		end)
		jestExpect(Scheduler).toHaveYielded({ "child" })
	end)

	it(
		"mounts/unmounts layout effects when visibility changes (starting hidden)",
		function()
			local root = ReactNoop.createRoot()
			local function renderActivity(mode)
				root.render(
					React.createElement(
						React.Activity,
						{ mode = mode },
						React.createElement(LayoutChild)
					)
				)
			end

			ReactNoop.act(function()
				renderActivity("hidden")
			end)
			jestExpect(Scheduler).toHaveYielded({ "Child" })
			jestExpect(root).toMatchRenderedOutput(
				React.createElement("span", { hidden = true, prop = "Child" })
			)

			ReactNoop.act(function()
				renderActivity("visible")
			end)
			jestExpect(Scheduler).toHaveYielded({ "Child", "Mount layout" })
			jestExpect(root).toMatchRenderedOutput(
				React.createElement("span", { prop = "Child" })
			)

			ReactNoop.act(function()
				renderActivity("hidden")
			end)
			jestExpect(Scheduler).toHaveYielded({ "Unmount layout", "Child" })
			jestExpect(root).toMatchRenderedOutput(
				React.createElement("span", { hidden = true, prop = "Child" })
			)
		end
	)

	it("hides children of offscreen after layout effects are destroyed", function()
		local root = ReactNoop.createRoot()
		local function Child()
			React.useLayoutEffect(function()
				Scheduler.unstable_yieldValue("Mount layout")
				return function()
					jestExpect(root).toMatchRenderedOutput(
						React.createElement("span", { prop = "Child" })
					)
					Scheduler.unstable_yieldValue("Unmount layout")
				end
			end, {})
			return React.createElement(Text, { text = "Child" })
		end

		ReactNoop.act(function()
			root.render(
				React.createElement(
					React.Activity,
					{ mode = "visible" },
					React.createElement(Child)
				)
			)
		end)
		jestExpect(Scheduler).toHaveYielded({ "Child", "Mount layout" })

		ReactNoop.act(function()
			root.render(
				React.createElement(
					React.Activity,
					{ mode = "hidden" },
					React.createElement(Child)
				)
			)
		end)
		jestExpect(Scheduler).toHaveYielded({ "Unmount layout", "Child" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement("span", { hidden = true, prop = "Child" })
		)
	end)

	it("does not toggle effects for LegacyHidden component", function()
		local root = ReactNoop.createRoot()
		local function renderLegacyHidden(mode)
			root.render(
				React.createElement(
					React.unstable_LegacyHidden,
					{ mode = mode },
					React.createElement(LayoutChild)
				)
			)
		end

		ReactNoop.act(function()
			renderLegacyHidden("visible")
		end)
		jestExpect(Scheduler).toHaveYielded({ "Child", "Mount layout" })

		ReactNoop.act(function()
			renderLegacyHidden("hidden")
		end)
		jestExpect(Scheduler).toHaveYielded({ "Child" })

		ReactNoop.act(function()
			renderLegacyHidden("visible")
		end)
		jestExpect(Scheduler).toHaveYielded({ "Child" })

		ReactNoop.act(function()
			root.render(nil)
		end)
		jestExpect(Scheduler).toHaveYielded({ "Unmount layout" })
	end)

	it("hides new insertions into an already hidden tree", function()
		local root = ReactNoop.createRoot()
		ReactNoop.act(function()
			root.render(
				React.createElement(
					React.Activity,
					{ mode = "hidden" },
					React.createElement("span", nil, "Hi")
				)
			)
		end)
		jestExpect(root).toMatchRenderedOutput(
			React.createElement("span", { hidden = true }, "Hi")
		)

		ReactNoop.act(function()
			root.render(
				React.createElement(
					React.Activity,
					{ mode = "hidden" },
					React.createElement("span", nil, "Hi"),
					React.createElement("span", nil, "Something new")
				)
			)
		end)
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				React.Fragment,
				nil,
				React.createElement("span", { hidden = true }, "Hi"),
				React.createElement("span", { hidden = true }, "Something new")
			)
		)
	end)

	it("hides updated nodes inside an already hidden tree", function()
		local root = ReactNoop.createRoot()
		local function renderActivity(activityMode, childHidden)
			root.render(
				React.createElement(
					React.Activity,
					{ mode = activityMode },
					React.createElement("span", { hidden = childHidden }, "Hi")
				)
			)
		end

		ReactNoop.act(function()
			renderActivity("hidden", nil)
		end)
		jestExpect(root).toMatchRenderedOutput(
			React.createElement("span", { hidden = true }, "Hi")
		)

		ReactNoop.act(function()
			renderActivity("hidden", false)
		end)
		jestExpect(root).toMatchRenderedOutput(
			React.createElement("span", { hidden = true }, "Hi")
		)

		ReactNoop.act(function()
			renderActivity("visible", true)
		end)
		jestExpect(root).toMatchRenderedOutput(
			React.createElement("span", { hidden = true }, "Hi")
		)

		ReactNoop.act(function()
			renderActivity("visible", nil)
		end)
		jestExpect(root).toMatchRenderedOutput(React.createElement("span", nil, "Hi"))
	end)

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

	it("regression: Activity instance is sometimes null during setState", function()
		local setState
		local function Child()
			local state, updateState = React.useState("Initial")
			setState = updateState
			return React.createElement(Text, { text = state })
		end

		local root = ReactNoop.createRoot()
		ReactNoop.act(function()
			root.render(React.createElement(React.Activity))
		end)
		jestExpect(Scheduler).toHaveYielded({})
		jestExpect(root).toMatchRenderedOutput(nil)

		ReactNoop.act(function()
			React.startTransition(function()
				root.render(
					React.createElement(
						React.Activity,
						nil,
						React.createElement(Child),
						React.createElement(Text, { text = "Sibling" })
					)
				)
			end)
			jestExpect(Scheduler).toFlushAndYieldThrough({ "Initial" })

			ReactNoop.flushSync(function()
				root.render(nil)
			end)

			jestExpect(function()
				setState("Updated")
			end).toErrorDev(
				"Can't perform a React state update on a component that hasn't mounted yet. "
					.. "This indicates that you have a side-effect in your render function that "
					.. "asynchronously tries to update the component. "
					.. "Move this work to useEffect instead.\n"
					.. "    in Child (at **)"
			)
		end)
		jestExpect(root).toMatchRenderedOutput(nil)
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

	it(
		"does not call componentDidUpdate when reappearing a hidden class component",
		function()
			local Child = React.Component:extend("Child")
			function Child:componentDidMount()
				Scheduler.unstable_yieldValue("componentDidMount")
			end
			function Child:componentDidUpdate()
				Scheduler.unstable_yieldValue("componentDidUpdate")
			end
			function Child:componentWillUnmount()
				Scheduler.unstable_yieldValue("componentWillUnmount")
			end
			function Child:render()
				return "Child"
			end

			local root = ReactNoop.createRoot()
			local function renderActivity(mode)
				root.render(
					React.createElement(
						React.Activity,
						{ mode = mode },
						React.createElement(Child)
					)
				)
			end

			ReactNoop.act(function()
				renderActivity("visible")
			end)
			jestExpect(Scheduler).toHaveYielded({ "componentDidMount" })

			ReactNoop.act(function()
				renderActivity("hidden")
			end)
			jestExpect(Scheduler).toHaveYielded({ "componentWillUnmount" })

			ReactNoop.act(function()
				renderActivity("visible")
			end)
			jestExpect(Scheduler).toHaveYielded({ "componentDidMount" })
		end
	)

	it(
		"when reusing old components (hidden -> visible), layout effects fire "
			.. "with same timing as if it were brand new",
		function()
			local function Child(props)
				React.useLayoutEffect(function()
					Scheduler.unstable_yieldValue("Mount " .. props.label)
					return function()
						Scheduler.unstable_yieldValue("Unmount " .. props.label)
					end
				end, { props.label })
				return props.label
			end

			local root = ReactNoop.createRoot()
			ReactNoop.act(function()
				root.render(
					React.createElement(
						React.Activity,
						{ mode = "visible" },
						React.createElement(Child, { key = "B", label = "B" })
					)
				)
			end)
			jestExpect(Scheduler).toHaveYielded({ "Mount B" })

			ReactNoop.act(function()
				root.render(
					React.createElement(
						React.Activity,
						{ mode = "hidden" },
						React.createElement(Child, { key = "B", label = "B" })
					)
				)
			end)
			jestExpect(Scheduler).toHaveYielded({ "Unmount B" })

			ReactNoop.act(function()
				root.render(
					React.createElement(
						React.Activity,
						{ mode = "visible" },
						React.createElement(Child, { key = "A", label = "A" }),
						React.createElement(Child, { key = "B", label = "B" }),
						React.createElement(Child, { key = "C", label = "C" })
					)
				)
			end)
			jestExpect(Scheduler).toHaveYielded({ "Mount A", "Mount B", "Mount C" })
		end
	)

	it(
		"when reusing old components (hidden -> visible), layout effects fire "
			.. "with same timing as if it were brand new (includes setState callback)",
		function()
			local Child = React.Component:extend("Child")
			function Child:componentDidMount()
				Scheduler.unstable_yieldValue("Mount " .. self.props.label)
			end
			function Child:componentWillUnmount()
				Scheduler.unstable_yieldValue("Unmount " .. self.props.label)
			end
			function Child:render()
				return self.props.label
			end

			local bRef = React.createRef()
			local root = ReactNoop.createRoot()
			ReactNoop.act(function()
				root.render(
					React.createElement(
						React.Activity,
						{ mode = "visible" },
						React.createElement(Child, {
							key = "B",
							ref = bRef,
							label = "B",
						})
					)
				)
			end)
			jestExpect(Scheduler).toHaveYielded({ "Mount B" })
			local b = bRef.current

			ReactNoop.act(function()
				root.render(
					React.createElement(
						React.Activity,
						{ mode = "hidden" },
						React.createElement(Child, {
							key = "B",
							ref = bRef,
							label = "B",
						})
					)
				)
			end)
			jestExpect(Scheduler).toHaveYielded({ "Unmount B" })

			ReactNoop.act(function()
				b:setState(nil, function()
					Scheduler.unstable_yieldValue("setState callback B")
				end)
				root.render(
					React.createElement(
						React.Activity,
						{ mode = "visible" },
						React.createElement(Child, { key = "A", label = "A" }),
						React.createElement(Child, {
							key = "B",
							ref = bRef,
							label = "B",
						}),
						React.createElement(Child, { key = "C", label = "C" })
					)
				)
			end)
			jestExpect(Scheduler).toHaveYielded({
				"Mount A",
				"Mount B",
				"setState callback B",
				"Mount C",
			})
		end
	)

	local function PassiveChild(props)
		React.useEffect(function()
			Scheduler.unstable_yieldValue("Mount " .. props.label)
			return function()
				Scheduler.unstable_yieldValue("Unmount " .. props.label)
			end
		end, { props.label })
		return React.createElement(Text, { text = props.label })
	end

	it("defer passive effects when prerendering a new Activity tree", function()
		local function App(props)
			return React.createElement(
				React.Fragment,
				nil,
				React.createElement(PassiveChild, { label = "Shell" }),
				React.createElement(
					React.Activity,
					{ mode = if props.showMore then "visible" else "hidden" },
					React.createElement(PassiveChild, { label = "More" })
				)
			)
		end

		local root = ReactNoop.createRoot()
		ReactNoop.act(function()
			root.render(React.createElement(App, { showMore = false }))
		end)
		jestExpect(Scheduler).toHaveYielded({ "Shell", "Mount Shell", "More" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				React.Fragment,
				nil,
				React.createElement("span", { prop = "Shell" }),
				React.createElement("span", { hidden = true, prop = "More" })
			)
		)

		ReactNoop.act(function()
			root.render(React.createElement(App, { showMore = true }))
		end)
		jestExpect(Scheduler).toHaveYielded({ "Shell", "More", "Mount More" })
	end)

	it(
		"do not defer passive effects when prerendering a new LegacyHidden tree",
		function()
			local function App(props)
				return React.createElement(
					React.Fragment,
					nil,
					React.createElement(PassiveChild, { label = "Shell" }),
					React.createElement(React.unstable_LegacyHidden, {
						mode = if props.showMore
							then "visible"
							else "unstable-defer-without-hiding",
					}, React.createElement(PassiveChild, { label = "More" }))
				)
			end

			local root = ReactNoop.createRoot()
			ReactNoop.act(function()
				root.render(React.createElement(App, { showMore = false }))
			end)
			jestExpect(Scheduler).toHaveYielded({
				"Shell",
				"Mount Shell",
				"More",
				"Mount More",
			})
			jestExpect(root).toMatchRenderedOutput(
				React.createElement(
					React.Fragment,
					nil,
					React.createElement("span", { prop = "Shell" }),
					React.createElement("span", { prop = "More" })
				)
			)

			ReactNoop.act(function()
				root.render(React.createElement(App, { showMore = true }))
			end)
			jestExpect(Scheduler).toHaveYielded({ "Shell", "More" })
		end
	)

	it(
		"passive effects are connected and disconnected when the visibility changes",
		function()
			local function Child(props)
				React.useEffect(function()
					Scheduler.unstable_yieldValue("Commit mount [" .. props.step .. "]")
					return function()
						Scheduler.unstable_yieldValue(
							"Commit unmount [" .. props.step .. "]"
						)
					end
				end, { props.step })
				return React.createElement(Text, { text = props.step })
			end

			local function App(props)
				local child = React.useMemo(function()
					return React.createElement(Child, { step = props.step })
				end, { props.step })
				return React.createElement(
					React.Activity,
					{ mode = if props.show then "visible" else "hidden" },
					child
				)
			end

			local root = ReactNoop.createRoot()
			ReactNoop.act(function()
				root.render(React.createElement(App, { show = true, step = 1 }))
			end)
			jestExpect(Scheduler).toHaveYielded({ 1, "Commit mount [1]" })
			jestExpect(root).toMatchRenderedOutput(
				React.createElement("span", { prop = 1 })
			)

			ReactNoop.act(function()
				root.render(React.createElement(App, { show = false, step = 1 }))
			end)
			jestExpect(Scheduler).toHaveYielded({ "Commit unmount [1]" })
			jestExpect(root).toMatchRenderedOutput(
				React.createElement("span", { hidden = true, prop = 1 })
			)

			ReactNoop.act(function()
				root.render(React.createElement(App, { show = false, step = 2 }))
			end)
			jestExpect(Scheduler).toHaveYielded({ 2 })
			jestExpect(root).toMatchRenderedOutput(
				React.createElement("span", { hidden = true, prop = 2 })
			)

			ReactNoop.act(function()
				root.render(React.createElement(App, { show = true, step = 2 }))
			end)
			jestExpect(Scheduler).toHaveYielded({ "Commit mount [2]" })
			jestExpect(root).toMatchRenderedOutput(
				React.createElement("span", { prop = 2 })
			)
		end
	)

	it(
		"passive effects are unmounted on hide in the same order as during a deletion: parent before child",
		function()
			local function Child()
				React.useEffect(function()
					Scheduler.unstable_yieldValue("Mount Child")
					return function()
						Scheduler.unstable_yieldValue("Unmount Child")
					end
				end, {})
				return React.createElement("div", nil, "Hi")
			end
			local function Parent()
				React.useEffect(function()
					Scheduler.unstable_yieldValue("Mount Parent")
					return function()
						Scheduler.unstable_yieldValue("Unmount Parent")
					end
				end, {})
				return React.createElement(Child)
			end
			local function App(props)
				return React.createElement(
					React.Activity,
					{ mode = if props.show then "visible" else "hidden" },
					React.createElement(Parent)
				)
			end

			local root = ReactNoop.createRoot()
			ReactNoop.act(function()
				root.render(React.createElement(App, { show = true }))
			end)
			jestExpect(Scheduler).toHaveYielded({ "Mount Child", "Mount Parent" })

			ReactNoop.act(function()
				root.render(nil)
			end)
			jestExpect(Scheduler).toHaveYielded({ "Unmount Parent", "Unmount Child" })

			ReactNoop.act(function()
				root.render(React.createElement(App, { show = true }))
			end)
			jestExpect(Scheduler).toHaveYielded({ "Mount Child", "Mount Parent" })

			ReactNoop.act(function()
				root.render(React.createElement(App, { show = false }))
			end)
			jestExpect(Scheduler).toHaveYielded({ "Unmount Parent", "Unmount Child" })
		end
	)

	it.skip(
		"don't defer passive effects when prerendering in a tree whose effects are already connected",
		function()
			local function App(props)
				return React.createElement(
					React.Fragment,
					nil,
					React.createElement(PassiveChild, {
						label = "Shell " .. props.step,
					}),
					React.createElement(
						React.Activity,
						{ mode = if props.showMore then "visible" else "hidden" },
						React.createElement(PassiveChild, {
							label = "More " .. props.step,
						})
					)
				)
			end

			local root = ReactNoop.createRoot()
			ReactNoop.act(function()
				root.render(React.createElement(App, { showMore = true, step = 1 }))
			end)
			jestExpect(Scheduler).toHaveYielded({
				"Shell 1",
				"More 1",
				"Mount Shell 1",
				"Mount More 1",
			})

			ReactNoop.act(function()
				root.render(React.createElement(App, { showMore = false, step = 2 }))
			end)
			jestExpect(Scheduler).toHaveYielded({
				"Shell 2",
				"Unmount Shell 1",
				"Mount Shell 2",
				"More 2",
				"Unmount More 1",
				"Mount More 2",
			})
		end
	)

	it("does not mount effects when prerendering a nested Activity boundary", function()
		local function App(props)
			local child = React.useMemo(function()
				return React.createElement(
					"div",
					nil,
					React.createElement(PassiveChild, { label = "Outer" }),
					if props.showInner
						then React.createElement(
							React.Activity,
							{ mode = "visible" },
							React.createElement(
								"div",
								nil,
								React.createElement(PassiveChild, { label = "Inner" })
							)
						)
						else nil
				)
			end, { props.showInner })
			return React.createElement(
				React.Activity,
				{ mode = if props.showOuter then "visible" else "hidden" },
				child
			)
		end

		local root = ReactNoop.createRoot()
		ReactNoop.act(function()
			root.render(
				React.createElement(App, { showOuter = false, showInner = false })
			)
		end)
		jestExpect(Scheduler).toHaveYielded({ "Outer" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				"div",
				{ hidden = true },
				React.createElement("span", { prop = "Outer" })
			)
		)

		ReactNoop.act(function()
			root.render(React.createElement(App, { showOuter = false, showInner = true }))
		end)
		jestExpect(Scheduler).toHaveYielded({ "Outer", "Inner" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				"div",
				{ hidden = true },
				React.createElement("span", { prop = "Outer" }),
				React.createElement(
					"div",
					nil,
					React.createElement("span", { prop = "Inner" })
				)
			)
		)

		ReactNoop.act(function()
			root.render(React.createElement(App, { showOuter = true, showInner = true }))
		end)
		jestExpect(Scheduler).toHaveYielded({ "Mount Outer", "Mount Inner" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				"div",
				nil,
				React.createElement("span", { prop = "Outer" }),
				React.createElement(
					"div",
					nil,
					React.createElement("span", { prop = "Inner" })
				)
			)
		)
	end)

	it("reveal an outer Activity boundary without revealing an inner one", function()
		local function App(props)
			local child = React.useMemo(function()
				return React.createElement(
					"div",
					nil,
					React.createElement(PassiveChild, { label = "Outer" }),
					React.createElement(
						React.Activity,
						{ mode = if props.showInner then "visible" else "hidden" },
						React.createElement(
							"div",
							nil,
							React.createElement(PassiveChild, { label = "Inner" })
						)
					)
				)
			end, { props.showInner })
			return React.createElement(
				React.Activity,
				{ mode = if props.showOuter then "visible" else "hidden" },
				child
			)
		end

		local root = ReactNoop.createRoot()
		ReactNoop.act(function()
			root.render(
				React.createElement(App, { showOuter = false, showInner = false })
			)
		end)
		jestExpect(Scheduler).toHaveYielded({ "Outer", "Inner" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				"div",
				{ hidden = true },
				React.createElement("span", { prop = "Outer" }),
				React.createElement(
					"div",
					{ hidden = true },
					React.createElement("span", { prop = "Inner" })
				)
			)
		)

		ReactNoop.act(function()
			root.render(React.createElement(App, { showOuter = true, showInner = false }))
		end)
		jestExpect(Scheduler).toHaveYielded({ "Mount Outer" })
		jestExpect(root).toMatchRenderedOutput(
			React.createElement(
				"div",
				nil,
				React.createElement("span", { prop = "Outer" }),
				React.createElement(
					"div",
					{ hidden = true },
					React.createElement("span", { prop = "Inner" })
				)
			)
		)
	end)

	-- ROBLOX deviation: useInsertionEffect is not implemented in React-Luau.

	it("warns if you pass a hidden prop", function()
		local function App()
			return React.createElement(
				React.Activity,
				{ hidden = true },
				React.createElement("div")
			)
		end

		local root = ReactNoop.createRoot()
		jestExpect(function()
			ReactNoop.act(function()
				root.render(React.createElement(App, { show = true, step = 1 }))
			end)
		end).toErrorDev(
			'<Activity> doesn\'t accept a hidden prop. Use mode="hidden" instead.\n'
				.. "- <Activity hidden>\n"
				.. '+ <Activity mode="hidden">\n'
				.. "    in Activity (at **)\n"
				.. "    in App (at **)"
		)
	end)
end)

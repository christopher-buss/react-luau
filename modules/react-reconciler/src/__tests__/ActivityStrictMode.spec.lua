-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-reconciler/src/__tests__/ActivityStrictMode-test.js

local Packages = script.Parent.Parent.Parent
local JestGlobals = require(Packages.Dev.JestGlobals)
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local it = JestGlobals.it
local jest = JestGlobals.jest
local jestExpect = JestGlobals.expect

local React
local Activity
local ReactNoop
local act
local log
local __DEV__

describe("Activity StrictMode", function()
	beforeEach(function()
		jest.resetModules()
		log = {}

		React = require(Packages.React)
		Activity = React.Activity
		ReactNoop = require(Packages.Dev.ReactNoopRenderer)
		-- ROBLOX DEVIATION: ReactNoop.act replaces internal-test-utils act, and
		-- ReactGlobals supplies the __DEV__ build global for @gate __DEV__.
		act = ReactNoop.act
		__DEV__ = require(Packages.ReactGlobals).__DEV__
	end)

	local function Component(props)
		local label = props.label
		React.useEffect(function()
			table.insert(log, label .. ": useEffect mount")
			return function()
				table.insert(log, label .. ": useEffect unmount")
			end
		end)

		React.useLayoutEffect(function()
			table.insert(log, label .. ": useLayoutEffect mount")
			return function()
				table.insert(log, label .. ": useLayoutEffect unmount")
			end
		end)

		table.insert(log, label .. ": render")

		return React.createElement("span", nil, "label")
	end

	-- @gate __DEV__
	it("should trigger strict effects when offscreen is visible", function()
		if not __DEV__ then
			return
		end
		act(function()
			ReactNoop.render(
				React.createElement(
					React.StrictMode,
					nil,
					React.createElement(
						Activity,
						{ mode = "visible" },
						React.createElement(Component, { label = "A" })
					)
				)
			)
		end)

		jestExpect(log).toEqual({
			"A: render",
			"A: render",
			"A: useLayoutEffect mount",
			"A: useEffect mount",
			"A: useLayoutEffect unmount",
			"A: useEffect unmount",
			"A: useLayoutEffect mount",
			"A: useEffect mount",
		})
	end)

	-- @gate __DEV__
	it("should not trigger strict effects when offscreen is hidden", function()
		if not __DEV__ then
			return
		end
		act(function()
			ReactNoop.render(
				React.createElement(
					React.StrictMode,
					nil,
					React.createElement(
						Activity,
						{ mode = "hidden" },
						React.createElement(Component, { label = "A" })
					)
				)
			)
		end)

		jestExpect(log).toEqual({ "A: render", "A: render" })

		log = {}

		act(function()
			ReactNoop.render(
				React.createElement(
					React.StrictMode,
					nil,
					React.createElement(
						Activity,
						{ mode = "hidden" },
						React.createElement(Component, { label = "A" }),
						React.createElement(Component, { label = "B" })
					)
				)
			)
		end)

		jestExpect(log).toEqual({ "A: render", "A: render", "B: render", "B: render" })

		log = {}

		act(function()
			ReactNoop.render(
				React.createElement(
					React.StrictMode,
					nil,
					React.createElement(
						Activity,
						{ mode = "visible" },
						React.createElement(Component, { label = "A" })
					)
				)
			)
		end)

		jestExpect(log).toEqual({
			"A: render",
			"A: render",
			"A: useLayoutEffect mount",
			"A: useEffect mount",
			"A: useLayoutEffect unmount",
			"A: useEffect unmount",
			"A: useLayoutEffect mount",
			"A: useEffect mount",
		})

		log = {}

		act(function()
			ReactNoop.render(
				React.createElement(
					React.StrictMode,
					nil,
					React.createElement(
						Activity,
						{ mode = "hidden" },
						React.createElement(Component, { label = "A" })
					)
				)
			)
		end)

		jestExpect(log).toEqual({
			"A: useLayoutEffect unmount",
			"A: useEffect unmount",
			"A: render",
			"A: render",
		})
	end)

	it(
		"should not cause infinite render loop when StrictMode is used with Suspense and synchronous set states",
		function()
			-- This is a regression test, see https://github.com/facebook/react/pull/25179 for more details.
			local function App()
				local state, setState = React.useState(false)

				React.useLayoutEffect(function()
					setState(true)
				end, {})

				React.useEffect(function()
					-- Empty useEffect with empty dependency array is needed to trigger infinite render loop.
				end, {})

				return state
			end

			act(function()
				ReactNoop.render(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(React.Suspense, nil, React.createElement(App))
					)
				)
			end)
		end
	)

	-- @gate __DEV__
	it("should double invoke effects on unsuspended child", function()
		if not __DEV__ then
			return
		end
		local shouldSuspend = true
		-- ROBLOX DEVIATION: a Luau thenable replaces the JavaScript Promise.
		local pings = {}
		local resolved = false
		local suspensePromise = {}
		function suspensePromise:andThen(onFulfill)
			if resolved then
				onFulfill()
			else
				table.insert(pings, onFulfill)
			end
		end
		local function resolve()
			resolved = true
			for _, ping in pings do
				ping()
			end
		end

		local Child

		local function Parent()
			table.insert(log, "Parent rendered")
			React.useEffect(function()
				table.insert(log, "Parent mount")
				return function()
					table.insert(log, "Parent unmount")
				end
			end)

			return React.createElement(
				React.Suspense,
				{ fallback = "fallback" },
				React.createElement(Child)
			)
		end

		function Child()
			table.insert(log, "Child rendered")
			React.useEffect(function()
				table.insert(log, "Child mount")
				return function()
					table.insert(log, "Child unmount")
				end
			end)
			if shouldSuspend then
				table.insert(log, "Child suspended")
				error(suspensePromise)
			end
			return nil
		end

		act(function()
			ReactNoop.render(
				React.createElement(
					React.StrictMode,
					nil,
					React.createElement(
						Activity,
						{ mode = "visible" },
						React.createElement(Parent)
					)
				)
			)
		end)

		table.insert(log, "------------------------------")

		act(function()
			resolve()
			shouldSuspend = false
		end)

		-- ROBLOX DEVIATION: React-Luau does not implement sibling prewarming,
		-- so the upstream pre-warming render of Child is absent.
		jestExpect(log).toEqual({
			"Parent rendered",
			"Parent rendered",
			"Child rendered",
			"Child suspended",
			"Parent mount",
			"Parent unmount",
			"Parent mount",
			"------------------------------",
			"Child rendered",
			"Child rendered",
			"Child mount",
			"Child unmount",
			"Child mount",
		})
	end)

	-- @gate __DEV__
	it(
		"should double invoke effects on newly inserted children while Activity becomes visible",
		function()
			if not __DEV__ then
				return
			end
			local function Parent(props)
				table.insert(log, "Parent rendered")
				React.useEffect(function()
					table.insert(log, "Parent mount")
					return function()
						table.insert(log, "Parent unmount")
					end
				end)

				return React.createElement("div", nil, props.children)
			end

			local function Child(props)
				local name = props.name
				table.insert(log, "Child " .. name .. " rendered")
				React.useEffect(function()
					table.insert(log, "Child " .. name .. " mount")
					return function()
						table.insert(log, "Child " .. name .. " unmount")
					end
				end)

				return nil
			end

			act(function()
				ReactNoop.render(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(
							Activity,
							{ mode = "hidden" },
							React.createElement(Parent)
						)
					)
				)
			end)

			jestExpect(log).toEqual({ "Parent rendered", "Parent rendered" })

			table.clear(log)
			act(function()
				ReactNoop.render(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(
							Activity,
							{ mode = "visible" },
							React.createElement(
								Parent,
								nil,
								React.createElement(Child, { name = "one" })
							)
						)
					)
				)
			end)

			jestExpect(log).toEqual({
				"Parent rendered",
				"Parent rendered",
				"Child one rendered",
				"Child one rendered",
				"Child one mount",
				"Parent mount",
				-- StrictMode double invocation
				"Parent unmount",
				"Child one unmount",
				"Child one mount",
				"Parent mount",
			})

			table.clear(log)
			act(function()
				ReactNoop.render(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(
							Activity,
							{ mode = "visible" },
							React.createElement(
								Parent,
								nil,
								React.createElement(Child, { name = "one" })
							)
						)
					)
				)
			end)

			jestExpect(log).toEqual({
				"Parent rendered",
				"Parent rendered",
				"Child one rendered",
				"Child one rendered",
				-- single Effect invocation. No double invocation on update.
				"Child one unmount",
				"Parent unmount",
				"Child one mount",
				"Parent mount",
			})

			table.clear(log)
			act(function()
				ReactNoop.render(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(
							Activity,
							{ mode = "visible" },
							React.createElement(
								Parent,
								nil,
								React.createElement(Child, { name = "one" }),
								React.createElement(Child, { name = "two" })
							)
						)
					)
				)
			end)

			jestExpect(log).toEqual({
				"Parent rendered",
				"Parent rendered",
				"Child one rendered",
				"Child one rendered",
				"Child two rendered",
				"Child two rendered",
				-- single Effect invocation for existing Components.
				"Child one unmount",
				"Parent unmount",
				"Child one mount",
				"Child two mount",
				"Parent mount",
				-- Double Effect invocation for new Component "two"
				"Child two unmount",
				"Child two mount",
			})
		end
	)
end)

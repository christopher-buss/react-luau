-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-reconciler/src/__tests__/StrictEffectsMode-test.js
--[[*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @emails react-core
 ]]

local Packages = script.Parent.Parent.Parent
local JestGlobals = require(Packages.Dev.JestGlobals)
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local it = JestGlobals.it
local jest = JestGlobals.jest
local jestExpect = JestGlobals.expect

local React
local ReactNoop
local act
local __DEV__

describe("StrictEffectsMode", function()
	beforeEach(function()
		jest.resetModules()
		-- ROBLOX DEVIATION: ReactNoop.act replaces internal-test-utils act, and
		-- ReactGlobals supplies the __DEV__ build global. React-Luau's
		-- renderToRootWithID requires a root ID, so cases that omit it upstream
		-- pass "root".
		__DEV__ = require(Packages.ReactGlobals).__DEV__

		React = require(Packages.React)
		ReactNoop = require(Packages.Dev.ReactNoopRenderer)
		act = ReactNoop.act
	end)

	-- @gate !disableLegacyMode
	it("should not double invoke effects in legacy mode", function()
		local log = {}
		local function App(props)
			React.useEffect(function()
				table.insert(log, "useEffect mount")
				return function()
					table.insert(log, "useEffect unmount")
				end
			end)

			React.useLayoutEffect(function()
				table.insert(log, "useLayoutEffect mount")
				return function()
					table.insert(log, "useLayoutEffect unmount")
				end
			end)

			return props.text
		end

		local root = ReactNoop.createLegacyRoot()
		act(function()
			root.render(
				React.createElement(
					React.StrictMode,
					nil,
					React.createElement(App, { text = "mount" })
				)
			)
		end)

		jestExpect(log).toEqual({ "useLayoutEffect mount", "useEffect mount" })
	end)

	it("double invoking for effects works properly", function()
		local log = {}
		local function App(props)
			React.useEffect(function()
				table.insert(log, "useEffect mount")
				return function()
					table.insert(log, "useEffect unmount")
				end
			end)

			React.useLayoutEffect(function()
				table.insert(log, "useLayoutEffect mount")
				return function()
					table.insert(log, "useLayoutEffect unmount")
				end
			end)

			return props.text
		end

		act(function()
			ReactNoop.renderToRootWithID(
				React.createElement(
					React.StrictMode,
					nil,
					React.createElement(App, { text = "mount" })
				),
				"root"
			)
		end)

		if __DEV__ then
			jestExpect(log).toEqual({
				"useLayoutEffect mount",
				"useEffect mount",
				"useLayoutEffect unmount",
				"useEffect unmount",
				"useLayoutEffect mount",
				"useEffect mount",
			})
		else
			jestExpect(log).toEqual({ "useLayoutEffect mount", "useEffect mount" })
		end

		table.clear(log)
		act(function()
			ReactNoop.renderToRootWithID(
				React.createElement(
					React.StrictMode,
					nil,
					React.createElement(App, { text = "update" })
				),
				"root"
			)
		end)

		jestExpect(log).toEqual({
			"useLayoutEffect unmount",
			"useLayoutEffect mount",
			"useEffect unmount",
			"useEffect mount",
		})

		table.clear(log)
		act(function()
			ReactNoop.unmountRootWithID("root")
		end)

		jestExpect(log).toEqual({ "useLayoutEffect unmount", "useEffect unmount" })
	end)

	it(
		"multiple effects are double invoked in the right order (all mounted, all unmounted, all remounted)",
		function()
			local log = {}
			local function App(props)
				React.useEffect(function()
					table.insert(log, "useEffect One mount")
					return function()
						table.insert(log, "useEffect One unmount")
					end
				end)

				React.useEffect(function()
					table.insert(log, "useEffect Two mount")
					return function()
						table.insert(log, "useEffect Two unmount")
					end
				end)

				return props.text
			end

			act(function()
				ReactNoop.renderToRootWithID(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(App, { text = "mount" })
					),
					"root"
				)
			end)

			if __DEV__ then
				jestExpect(log).toEqual({
					"useEffect One mount",
					"useEffect Two mount",
					"useEffect One unmount",
					"useEffect Two unmount",
					"useEffect One mount",
					"useEffect Two mount",
				})
			else
				jestExpect(log).toEqual({ "useEffect One mount", "useEffect Two mount" })
			end

			table.clear(log)
			act(function()
				ReactNoop.renderToRootWithID(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(App, { text = "update" })
					),
					"root"
				)
			end)

			jestExpect(log).toEqual({
				"useEffect One unmount",
				"useEffect Two unmount",
				"useEffect One mount",
				"useEffect Two mount",
			})

			table.clear(log)
			act(function()
				ReactNoop.unmountRootWithID("root")
			end)

			jestExpect(log).toEqual({ "useEffect One unmount", "useEffect Two unmount" })
		end
	)

	it(
		"multiple layout effects are double invoked in the right order (all mounted, all unmounted, all remounted)",
		function()
			local log = {}
			local function App(props)
				React.useLayoutEffect(function()
					table.insert(log, "useLayoutEffect One mount")
					return function()
						table.insert(log, "useLayoutEffect One unmount")
					end
				end)

				React.useLayoutEffect(function()
					table.insert(log, "useLayoutEffect Two mount")
					return function()
						table.insert(log, "useLayoutEffect Two unmount")
					end
				end)

				return props.text
			end

			act(function()
				ReactNoop.renderToRootWithID(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(App, { text = "mount" })
					),
					"root"
				)
			end)

			if __DEV__ then
				jestExpect(log).toEqual({
					"useLayoutEffect One mount",
					"useLayoutEffect Two mount",
					"useLayoutEffect One unmount",
					"useLayoutEffect Two unmount",
					"useLayoutEffect One mount",
					"useLayoutEffect Two mount",
				})
			else
				jestExpect(log).toEqual({
					"useLayoutEffect One mount",
					"useLayoutEffect Two mount",
				})
			end

			table.clear(log)
			act(function()
				ReactNoop.renderToRootWithID(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(App, { text = "update" })
					),
					"root"
				)
			end)

			jestExpect(log).toEqual({
				"useLayoutEffect One unmount",
				"useLayoutEffect Two unmount",
				"useLayoutEffect One mount",
				"useLayoutEffect Two mount",
			})

			table.clear(log)
			act(function()
				ReactNoop.unmountRootWithID("root")
			end)

			jestExpect(log).toEqual({
				"useLayoutEffect One unmount",
				"useLayoutEffect Two unmount",
			})
		end
	)

	it(
		"useEffect and useLayoutEffect is called twice when there is no unmount",
		function()
			local log = {}
			local function App(props)
				React.useEffect(function()
					table.insert(log, "useEffect mount")
				end)

				React.useLayoutEffect(function()
					table.insert(log, "useLayoutEffect mount")
				end)

				return props.text
			end

			act(function()
				ReactNoop.renderToRootWithID(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(App, { text = "mount" })
					),
					"root"
				)
			end)

			if __DEV__ then
				jestExpect(log).toEqual({
					"useLayoutEffect mount",
					"useEffect mount",
					"useLayoutEffect mount",
					"useEffect mount",
				})
			else
				jestExpect(log).toEqual({ "useLayoutEffect mount", "useEffect mount" })
			end

			table.clear(log)
			act(function()
				ReactNoop.renderToRootWithID(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(App, { text = "update" })
					),
					"root"
				)
			end)

			jestExpect(log).toEqual({ "useLayoutEffect mount", "useEffect mount" })

			table.clear(log)
			act(function()
				ReactNoop.unmountRootWithID("root")
			end)

			jestExpect(log).toEqual({})
		end
	)

	it("passes the right context to class component lifecycles", function()
		local log = {}
		local App = React.PureComponent:extend("App")

		function App:test() end

		function App:componentDidMount()
			self:test()
			table.insert(log, "componentDidMount")
		end

		function App:componentDidUpdate()
			self:test()
			table.insert(log, "componentDidUpdate")
		end

		function App:componentWillUnmount()
			self:test()
			table.insert(log, "componentWillUnmount")
		end

		function App:render()
			return nil
		end

		act(function()
			ReactNoop.renderToRootWithID(
				React.createElement(React.StrictMode, nil, React.createElement(App)),
				"root"
			)
		end)

		if __DEV__ then
			jestExpect(log).toEqual({
				"componentDidMount",
				"componentWillUnmount",
				"componentDidMount",
			})
		else
			jestExpect(log).toEqual({ "componentDidMount" })
		end
	end)

	it("double invoking works for class components", function()
		local log = {}
		local App = React.PureComponent:extend("App")

		function App:componentDidMount()
			table.insert(log, "componentDidMount")
		end

		function App:componentDidUpdate()
			table.insert(log, "componentDidUpdate")
		end

		function App:componentWillUnmount()
			table.insert(log, "componentWillUnmount")
		end

		function App:render()
			return self.props.text
		end

		act(function()
			ReactNoop.renderToRootWithID(
				React.createElement(
					React.StrictMode,
					nil,
					React.createElement(App, { text = "mount" })
				),
				"root"
			)
		end)

		if __DEV__ then
			jestExpect(log).toEqual({
				"componentDidMount",
				"componentWillUnmount",
				"componentDidMount",
			})
		else
			jestExpect(log).toEqual({ "componentDidMount" })
		end

		table.clear(log)
		act(function()
			ReactNoop.renderToRootWithID(
				React.createElement(
					React.StrictMode,
					nil,
					React.createElement(App, { text = "update" })
				),
				"root"
			)
		end)

		jestExpect(log).toEqual({ "componentDidUpdate" })

		table.clear(log)
		act(function()
			ReactNoop.unmountRootWithID("root")
		end)

		jestExpect(log).toEqual({ "componentWillUnmount" })
	end)

	it(
		"invokes componentWillUnmount for class components without componentDidMount",
		function()
			local log = {}
			local App = React.PureComponent:extend("App")

			function App:componentDidUpdate()
				table.insert(log, "componentDidUpdate")
			end

			function App:componentWillUnmount()
				table.insert(log, "componentWillUnmount")
			end

			function App:render()
				return self.props.text
			end

			act(function()
				ReactNoop.renderToRootWithID(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(App, { text = "mount" })
					),
					"root"
				)
			end)

			if __DEV__ then
				jestExpect(log).toEqual({ "componentWillUnmount" })
			else
				jestExpect(log).toEqual({})
			end

			table.clear(log)
			act(function()
				ReactNoop.renderToRootWithID(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(App, { text = "update" })
					),
					"root"
				)
			end)

			jestExpect(log).toEqual({ "componentDidUpdate" })

			table.clear(log)
			act(function()
				ReactNoop.unmountRootWithID("root")
			end)

			jestExpect(log).toEqual({ "componentWillUnmount" })
		end
	)

	-- @gate !disableLegacyMode
	it("should not double invoke class lifecycles in legacy mode", function()
		local log = {}
		local App = React.PureComponent:extend("App")

		function App:componentDidMount()
			table.insert(log, "componentDidMount")
		end

		function App:componentDidUpdate()
			table.insert(log, "componentDidUpdate")
		end

		function App:componentWillUnmount()
			table.insert(log, "componentWillUnmount")
		end

		function App:render()
			return self.props.text
		end

		local root = ReactNoop.createLegacyRoot()
		act(function()
			root.render(
				React.createElement(
					React.StrictMode,
					nil,
					React.createElement(App, { text = "mount" })
				)
			)
		end)

		jestExpect(log).toEqual({ "componentDidMount" })
	end)

	it("double flushing passive effects only results in one double invoke", function()
		local log = {}
		local function App(props)
			local state, setState = React.useState(0)
			React.useEffect(function()
				if state ~= 1 then
					setState(1)
				end
				table.insert(log, "useEffect mount")
				return function()
					table.insert(log, "useEffect unmount")
				end
			end)

			React.useLayoutEffect(function()
				table.insert(log, "useLayoutEffect mount")
				return function()
					table.insert(log, "useLayoutEffect unmount")
				end
			end)

			table.insert(log, props.text)
			return props.text
		end

		act(function()
			ReactNoop.renderToRootWithID(
				React.createElement(
					React.StrictMode,
					nil,
					React.createElement(App, { text = "mount" })
				),
				"root"
			)
		end)

		if __DEV__ then
			jestExpect(log).toEqual({
				"mount",
				"mount",
				"useLayoutEffect mount",
				"useEffect mount",
				"useLayoutEffect unmount",
				"useEffect unmount",
				"useLayoutEffect mount",
				"useEffect mount",
				"mount",
				"mount",
				"useLayoutEffect unmount",
				"useLayoutEffect mount",
				"useEffect unmount",
				"useEffect mount",
			})
		else
			jestExpect(log).toEqual({
				"mount",
				"useLayoutEffect mount",
				"useEffect mount",
				"mount",
				"useLayoutEffect unmount",
				"useLayoutEffect mount",
				"useEffect unmount",
				"useEffect mount",
			})
		end
	end)

	it("newly mounted components after initial mount get double invoked", function()
		local log = {}
		local _setShowChild
		local function Child()
			React.useEffect(function()
				table.insert(log, "Child useEffect mount")
				return function()
					table.insert(log, "Child useEffect unmount")
				end
			end)
			React.useLayoutEffect(function()
				table.insert(log, "Child useLayoutEffect mount")
				return function()
					table.insert(log, "Child useLayoutEffect unmount")
				end
			end)

			return nil
		end

		local function App()
			local showChild, setShowChild = React.useState(false)
			_setShowChild = setShowChild
			React.useEffect(function()
				table.insert(log, "App useEffect mount")
				return function()
					table.insert(log, "App useEffect unmount")
				end
			end)
			React.useLayoutEffect(function()
				table.insert(log, "App useLayoutEffect mount")
				return function()
					table.insert(log, "App useLayoutEffect unmount")
				end
			end)

			return showChild and React.createElement(Child) or nil
		end

		act(function()
			ReactNoop.renderToRootWithID(
				React.createElement(React.StrictMode, nil, React.createElement(App)),
				"root"
			)
		end)

		if __DEV__ then
			jestExpect(log).toEqual({
				"App useLayoutEffect mount",
				"App useEffect mount",
				"App useLayoutEffect unmount",
				"App useEffect unmount",
				"App useLayoutEffect mount",
				"App useEffect mount",
			})
		else
			jestExpect(log).toEqual({ "App useLayoutEffect mount", "App useEffect mount" })
		end

		table.clear(log)
		act(function()
			_setShowChild(true)
		end)

		if __DEV__ then
			jestExpect(log).toEqual({
				"App useLayoutEffect unmount",
				"Child useLayoutEffect mount",
				"App useLayoutEffect mount",
				"App useEffect unmount",
				"Child useEffect mount",
				"App useEffect mount",
				"Child useLayoutEffect unmount",
				"Child useEffect unmount",
				"Child useLayoutEffect mount",
				"Child useEffect mount",
			})
		else
			jestExpect(log).toEqual({
				"App useLayoutEffect unmount",
				"Child useLayoutEffect mount",
				"App useLayoutEffect mount",
				"App useEffect unmount",
				"Child useEffect mount",
				"App useEffect mount",
			})
		end
	end)

	it("reordering keyed children does not re-run effects", function()
		local log = {}
		local function Child(props)
			local label = props.label
			React.useEffect(function()
				table.insert(log, label .. " useEffect mount")
				return function()
					table.insert(log, label .. " useEffect unmount")
				end
			end, {})
			React.useLayoutEffect(function()
				table.insert(log, label .. " useLayoutEffect mount")
				return function()
					table.insert(log, label .. " useLayoutEffect unmount")
				end
			end, {})

			return nil
		end

		local function App(props)
			local children = {}
			for _, key in props.keys do
				table.insert(
					children,
					React.createElement(Child, { key = key, label = key })
				)
			end
			return children
		end

		act(function()
			ReactNoop.render(
				React.createElement(
					React.StrictMode,
					nil,
					React.createElement(App, { keys = { "a", "b" } })
				)
			)
		end)

		if __DEV__ then
			jestExpect(log).toEqual({
				"a useLayoutEffect mount",
				"b useLayoutEffect mount",
				"a useEffect mount",
				"b useEffect mount",
				"a useLayoutEffect unmount",
				"b useLayoutEffect unmount",
				"a useEffect unmount",
				"b useEffect unmount",
				"a useLayoutEffect mount",
				"b useLayoutEffect mount",
				"a useEffect mount",
				"b useEffect mount",
			})
		else
			jestExpect(log).toEqual({
				"a useLayoutEffect mount",
				"b useLayoutEffect mount",
				"a useEffect mount",
				"b useEffect mount",
			})
		end

		-- Reordering existing children must not re-run their effects. The
		-- components are neither unmounted nor remounted, and their effect
		-- dependencies have not changed.
		table.clear(log)
		act(function()
			ReactNoop.render(
				React.createElement(
					React.StrictMode,
					nil,
					React.createElement(App, { keys = { "b", "a" } })
				)
			)
		end)

		jestExpect(log).toEqual({})
	end)

	it("classes and functions are double invoked together correctly", function()
		local log = {}
		local ClassChild = React.PureComponent:extend("ClassChild")

		function ClassChild:componentDidMount()
			table.insert(log, "componentDidMount")
		end

		function ClassChild:componentWillUnmount()
			table.insert(log, "componentWillUnmount")
		end

		function ClassChild:render()
			return self.props.text
		end

		local function FunctionChild(props)
			React.useEffect(function()
				table.insert(log, "useEffect mount")
				return function()
					table.insert(log, "useEffect unmount")
				end
			end)
			React.useLayoutEffect(function()
				table.insert(log, "useLayoutEffect mount")
				return function()
					table.insert(log, "useLayoutEffect unmount")
				end
			end)
			return props.text
		end

		local function App(props)
			return React.createElement(
				React.Fragment,
				nil,
				React.createElement(ClassChild, { text = props.text }),
				React.createElement(FunctionChild, { text = props.text })
			)
		end

		act(function()
			ReactNoop.renderToRootWithID(
				React.createElement(
					React.StrictMode,
					nil,
					React.createElement(App, { text = "mount" })
				),
				"root"
			)
		end)

		if __DEV__ then
			jestExpect(log).toEqual({
				"componentDidMount",
				"useLayoutEffect mount",
				"useEffect mount",
				"componentWillUnmount",
				"useLayoutEffect unmount",
				"useEffect unmount",
				"componentDidMount",
				"useLayoutEffect mount",
				"useEffect mount",
			})
		else
			jestExpect(log).toEqual({
				"componentDidMount",
				"useLayoutEffect mount",
				"useEffect mount",
			})
		end

		table.clear(log)
		act(function()
			ReactNoop.renderToRootWithID(
				React.createElement(
					React.StrictMode,
					nil,
					React.createElement(App, { text = "mount" })
				),
				"root"
			)
		end)

		jestExpect(log).toEqual({
			"useLayoutEffect unmount",
			"useLayoutEffect mount",
			"useEffect unmount",
			"useEffect mount",
		})

		table.clear(log)
		act(function()
			ReactNoop.unmountRootWithID("root")
		end)

		jestExpect(log).toEqual({
			"componentWillUnmount",
			"useLayoutEffect unmount",
			"useEffect unmount",
		})
	end)

	it(
		"classes without componentDidMount and functions are double invoked together correctly",
		function()
			local log = {}
			local ClassChild = React.PureComponent:extend("ClassChild")

			function ClassChild:componentWillUnmount()
				table.insert(log, "componentWillUnmount")
			end

			function ClassChild:render()
				return self.props.text
			end

			local function FunctionChild(props)
				React.useEffect(function()
					table.insert(log, "useEffect mount")
					return function()
						table.insert(log, "useEffect unmount")
					end
				end)
				React.useLayoutEffect(function()
					table.insert(log, "useLayoutEffect mount")
					return function()
						table.insert(log, "useLayoutEffect unmount")
					end
				end)
				return props.text
			end

			local function App(props)
				return React.createElement(
					React.Fragment,
					nil,
					React.createElement(ClassChild, { text = props.text }),
					React.createElement(FunctionChild, { text = props.text })
				)
			end

			act(function()
				ReactNoop.renderToRootWithID(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(App, { text = "mount" })
					),
					"root"
				)
			end)

			if __DEV__ then
				jestExpect(log).toEqual({
					"useLayoutEffect mount",
					"useEffect mount",
					"componentWillUnmount",
					"useLayoutEffect unmount",
					"useEffect unmount",
					"useLayoutEffect mount",
					"useEffect mount",
				})
			else
				jestExpect(log).toEqual({ "useLayoutEffect mount", "useEffect mount" })
			end

			table.clear(log)
			act(function()
				ReactNoop.renderToRootWithID(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(App, { text = "mount" })
					),
					"root"
				)
			end)

			jestExpect(log).toEqual({
				"useLayoutEffect unmount",
				"useLayoutEffect mount",
				"useEffect unmount",
				"useEffect mount",
			})

			table.clear(log)
			act(function()
				ReactNoop.unmountRootWithID("root")
			end)

			jestExpect(log).toEqual({
				"componentWillUnmount",
				"useLayoutEffect unmount",
				"useEffect unmount",
			})
		end
	)

	-- @gate __DEV__
	-- ROBLOX DEVIATION: skipped. React-Luau keeps React 17 Suspense timing, so
	-- a default update that re-suspends visible content waits for the
	-- fallback timeout instead of committing the fallback. The upstream log
	-- depends on React 18's immediate fallback commit.
	it.skip("should double invoke effects after a re-suspend", function()
		if not __DEV__ then
			return
		end
		-- Not using log.push because it silences double render logs.
		local log = {}
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
		local function Fallback()
			table.insert(log, "Fallback")
			return "Loading"
		end

		local Child

		local function Parent(props)
			table.insert(log, "Parent rendered")

			React.useEffect(function()
				table.insert(log, "Parent create")
				return function()
					table.insert(log, "Parent destroy")
				end
			end, {})

			-- ROBLOX DEVIATION: a Luau array cannot hold nil, so a sentinel
			-- stands in for the omitted prop in the dependency list.
			React.useEffect(function()
				table.insert(log, "Parent dep create")
				return function()
					table.insert(log, "Parent dep destroy")
				end
			end, { if props.prop == nil then "undefined" else props.prop })

			return React.createElement(
				React.Suspense,
				{ fallback = React.createElement(Fallback) },
				React.createElement(Child, { prop = props.prop })
			)
		end

		function Child(props)
			local count, forceUpdate = React.useState(0)
			local ref = React.useRef(nil)
			table.insert(log, "Child rendered")
			React.useEffect(function()
				table.insert(log, "Child create")
				return function()
					table.insert(log, "Child destroy")
					ref.current = true
				end
			end, {})
			local key = tostring(props.prop) .. "-" .. tostring(count)
			React.useEffect(function()
				table.insert(log, "Child dep create")
				if ref.current == true then
					ref.current = false
					forceUpdate(function(c)
						return c + 1
					end)
					table.insert(log, "-----------------------after setState")
					return nil
				end

				return function()
					table.insert(log, "Child dep destroy")
				end
			end, { key })

			if shouldSuspend then
				table.insert(log, "Child suspended")
				error(suspensePromise)
			end
			return nil
		end

		-- Initial mount
		shouldSuspend = false
		act(function()
			ReactNoop.render(
				React.createElement(React.StrictMode, nil, React.createElement(Parent))
			)
		end)

		-- Now re-suspend
		shouldSuspend = true
		log = {}
		act(function()
			ReactNoop.render(
				React.createElement(React.StrictMode, nil, React.createElement(Parent))
			)
		end)

		-- ROBLOX DEVIATION: React-Luau does not implement sibling prewarming,
		-- so the upstream pre-warming render of Child is absent.
		jestExpect(log).toEqual({
			"Parent rendered",
			"Parent rendered",
			"Child rendered",
			"Child suspended",
			"Fallback",
			"Fallback",
		})

		log = {}
		-- while suspended, update
		act(function()
			ReactNoop.render(
				React.createElement(
					React.StrictMode,
					nil,
					React.createElement(Parent, { prop = "bar" })
				)
			)
		end)

		jestExpect(log).toEqual({
			"Parent rendered",
			"Parent rendered",
			"Child rendered",
			"Child suspended",
			"Fallback",
			"Fallback",
			"Parent dep destroy",
			"Parent dep create",
		})

		log = {}
		-- Now resolve and commit
		act(function()
			resolve()
			shouldSuspend = false
		end)

		jestExpect(log).toEqual({
			"Child rendered",
			"Child rendered",
			-- !!! Committed, destroy and create effect.
			-- !!! The other effect is not destroyed and created
			-- !!! because the dep didn't change
			"Child dep destroy",
			"Child dep create",

			-- Double invoke both effects
			"Child destroy",
			"Child dep destroy",
			"Child create",
			"Child dep create",
			-- Fires setState
			"-----------------------after setState",
			"Child rendered",
			"Child rendered",
			"Child dep create",
		})
	end)
end)

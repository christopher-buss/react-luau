-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-reconciler/src/__tests__/StrictEffectsModeDefaults-test.internal.js
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

-- ROBLOX DEVIATION: ReactGlobals supplies the __DEV__ build global.
local __DEV__ = require(Packages.ReactGlobals).__DEV__

local React
local ReactNoop
local Scheduler
local act

describe("StrictEffectsMode defaults", function()
	beforeEach(function()
		jest.resetModules()

		React = require(Packages.React)
		ReactNoop = require(Packages.Dev.ReactNoopRenderer)
		Scheduler = require(Packages.Scheduler)
		-- ROBLOX DEVIATION: ReactNoop.act replaces internal-test-utils act.
		-- waitFor, waitForAll, and waitForPaint map to the Scheduler matchers
		-- toFlushAndYieldThrough, toFlushAndYield, and toFlushUntilNextPaint.
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

		act(function()
			ReactNoop.renderLegacySyncRoot(
				React.createElement(
					React.StrictMode,
					nil,
					React.createElement(App, { text = "mount" })
				)
			)
		end)

		jestExpect(log).toEqual({ "useLayoutEffect mount", "useEffect mount" })
	end)

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

		act(function()
			ReactNoop.renderLegacySyncRoot(
				React.createElement(
					React.StrictMode,
					nil,
					React.createElement(App, { text = "mount" })
				)
			)
		end)

		jestExpect(log).toEqual({ "componentDidMount" })
	end)

	if __DEV__ then
		it(
			"should flush double-invoked effects within the same frame as layout effects if there are no passive effects",
			function()
				local log = {}
				local function ComponentWithEffects(props)
					local label = props.label
					React.useLayoutEffect(function()
						Scheduler.unstable_yieldValue(
							'useLayoutEffect mount "' .. label .. '"'
						)
						table.insert(log, 'useLayoutEffect mount "' .. label .. '"')
						return function()
							Scheduler.unstable_yieldValue(
								'useLayoutEffect unmount "' .. label .. '"'
							)
							table.insert(log, 'useLayoutEffect unmount "' .. label .. '"')
						end
					end)

					return label
				end

				act(function()
					ReactNoop.render(
						React.createElement(
							React.StrictMode,
							nil,
							React.createElement(ComponentWithEffects, { label = "one" })
						)
					)

					-- ROBLOX DEVIATION: upstream silences Scheduler.log while it double
					-- invokes effects (React 19 console dimming). React-Luau does not, so
					-- the yields include the double invocation.
					jestExpect(Scheduler).toFlushUntilNextPaint({
						'useLayoutEffect mount "one"',
						'useLayoutEffect unmount "one"',
						'useLayoutEffect mount "one"',
					})
					jestExpect(log).toEqual({
						'useLayoutEffect mount "one"',
						'useLayoutEffect unmount "one"',
						'useLayoutEffect mount "one"',
					})
				end)

				table.clear(log)
				act(function()
					ReactNoop.render(
						React.createElement(
							React.StrictMode,
							nil,
							React.createElement(ComponentWithEffects, { label = "one" }),
							React.createElement(ComponentWithEffects, { label = "two" })
						)
					)

					jestExpect(log).toEqual({})
					jestExpect(Scheduler).toFlushUntilNextPaint({
						-- Cleanup and re-run "one" (and "two") since there is no dependencies array.
						'useLayoutEffect unmount "one"',
						'useLayoutEffect mount "one"',
						'useLayoutEffect mount "two"',

						-- ROBLOX DEVIATION: see the first paint.
						'useLayoutEffect unmount "two"',
						'useLayoutEffect mount "two"',
					})
					jestExpect(log).toEqual({
						-- Cleanup and re-run "one" (and "two") since there is no dependencies array.
						'useLayoutEffect unmount "one"',
						'useLayoutEffect mount "one"',
						'useLayoutEffect mount "two"',

						-- Since "two" is new, it should be double-invoked.
						'useLayoutEffect unmount "two"',
						'useLayoutEffect mount "two"',
					})
				end)
			end
		)

		-- This test also verifies that double-invoked effects flush synchronously
		-- within the same frame as passive effects.
		it("should double invoke effects only for newly mounted components", function()
			local log = {}
			local function ComponentWithEffects(props)
				local label = props.label
				React.useEffect(function()
					table.insert(log, 'useEffect mount "' .. label .. '"')
					Scheduler.unstable_yieldValue('useEffect mount "' .. label .. '"')
					return function()
						table.insert(log, 'useEffect unmount "' .. label .. '"')
						Scheduler.unstable_yieldValue(
							'useEffect unmount "' .. label .. '"'
						)
					end
				end)

				React.useLayoutEffect(function()
					table.insert(log, 'useLayoutEffect mount "' .. label .. '"')
					Scheduler.unstable_yieldValue(
						'useLayoutEffect mount "' .. label .. '"'
					)
					return function()
						table.insert(log, 'useLayoutEffect unmount "' .. label .. '"')
						Scheduler.unstable_yieldValue(
							'useLayoutEffect unmount "' .. label .. '"'
						)
					end
				end)

				return label
			end

			act(function()
				ReactNoop.render(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(ComponentWithEffects, { label = "one" })
					)
				)

				-- ROBLOX DEVIATION: upstream silences Scheduler.log while it double
				-- invokes effects (React 19 console dimming). React-Luau does not, so
				-- the yields include the double invocation.
				jestExpect(Scheduler).toFlushAndYield({
					'useLayoutEffect mount "one"',
					'useEffect mount "one"',
					'useLayoutEffect unmount "one"',
					'useEffect unmount "one"',
					'useLayoutEffect mount "one"',
					'useEffect mount "one"',
				})
				jestExpect(log).toEqual({
					'useLayoutEffect mount "one"',
					'useEffect mount "one"',
					'useLayoutEffect unmount "one"',
					'useEffect unmount "one"',
					'useLayoutEffect mount "one"',
					'useEffect mount "one"',
				})
			end)

			table.clear(log)
			act(function()
				ReactNoop.render(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(ComponentWithEffects, { label = "one" }),
						React.createElement(ComponentWithEffects, { label = "two" })
					)
				)

				jestExpect(Scheduler).toFlushAndYieldThrough({
					-- Cleanup and re-run "one" (and "two") since there is no dependencies array.
					'useLayoutEffect unmount "one"',
					'useLayoutEffect mount "one"',
					'useLayoutEffect mount "two"',
				})
				jestExpect(log).toEqual({
					-- Cleanup and re-run "one" (and "two") since there is no dependencies array.
					'useLayoutEffect unmount "one"',
					'useLayoutEffect mount "one"',
					'useLayoutEffect mount "two"',
				})
				table.clear(log)
				-- ROBLOX DEVIATION: see the first flush.
				jestExpect(Scheduler).toFlushAndYield({
					'useEffect unmount "one"',
					'useEffect mount "one"',
					'useEffect mount "two"',
					'useLayoutEffect unmount "two"',
					'useEffect unmount "two"',
					'useLayoutEffect mount "two"',
					'useEffect mount "two"',
				})
				jestExpect(log).toEqual({
					'useEffect unmount "one"',
					'useEffect mount "one"',
					'useEffect mount "two"',

					-- Since "two" is new, it should be double-invoked.
					'useLayoutEffect unmount "two"',
					'useEffect unmount "two"',
					'useLayoutEffect mount "two"',
					'useEffect mount "two"',
				})
			end)
		end)

		it("double invoking for effects for modern roots", function()
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
				ReactNoop.render(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(App, { text = "mount" })
					)
				)
			end)

			jestExpect(log).toEqual({
				"useLayoutEffect mount",
				"useEffect mount",
				"useLayoutEffect unmount",
				"useEffect unmount",
				"useLayoutEffect mount",
				"useEffect mount",
			})

			table.clear(log)
			act(function()
				ReactNoop.render(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(App, { text = "update" })
					)
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
				ReactNoop.render(nil)
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
					ReactNoop.render(
						React.createElement(
							React.StrictMode,
							nil,
							React.createElement(App, { text = "mount" })
						)
					)
				end)

				jestExpect(log).toEqual({
					"useEffect One mount",
					"useEffect Two mount",
					"useEffect One unmount",
					"useEffect Two unmount",
					"useEffect One mount",
					"useEffect Two mount",
				})

				table.clear(log)
				act(function()
					ReactNoop.render(
						React.createElement(
							React.StrictMode,
							nil,
							React.createElement(App, { text = "update" })
						)
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
					ReactNoop.render(nil)
				end)

				jestExpect(log).toEqual({
					"useEffect One unmount",
					"useEffect Two unmount",
				})
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
					ReactNoop.render(
						React.createElement(
							React.StrictMode,
							nil,
							React.createElement(App, { text = "mount" })
						)
					)
				end)

				jestExpect(log).toEqual({
					"useLayoutEffect One mount",
					"useLayoutEffect Two mount",
					"useLayoutEffect One unmount",
					"useLayoutEffect Two unmount",
					"useLayoutEffect One mount",
					"useLayoutEffect Two mount",
				})

				table.clear(log)
				act(function()
					ReactNoop.render(
						React.createElement(
							React.StrictMode,
							nil,
							React.createElement(App, { text = "update" })
						)
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
					ReactNoop.render(nil)
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
					ReactNoop.render(
						React.createElement(
							React.StrictMode,
							nil,
							React.createElement(App, { text = "mount" })
						)
					)
				end)

				jestExpect(log).toEqual({
					"useLayoutEffect mount",
					"useEffect mount",
					"useLayoutEffect mount",
					"useEffect mount",
				})

				table.clear(log)
				act(function()
					ReactNoop.render(
						React.createElement(
							React.StrictMode,
							nil,
							React.createElement(App, { text = "update" })
						)
					)
				end)

				jestExpect(log).toEqual({ "useLayoutEffect mount", "useEffect mount" })

				table.clear(log)
				act(function()
					ReactNoop.render(nil)
				end)

				jestExpect(log).toEqual({})
			end
		)

		it("disconnects refs during double invoking", function()
			local onRefMock = jest.fn()
			local function App(props)
				return React.createElement("span", {
					ref = function(ref)
						onRefMock(ref)
					end,
				}, "text")
			end

			act(function()
				ReactNoop.render(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(App, { text = "mount" })
					)
				)
			end)

			jestExpect(#onRefMock.mock.calls).toBe(3)
			jestExpect(onRefMock.mock.calls[1][1]).never.toBeNil()
			-- ROBLOX DEVIATION: Jest-Lua records a nil mock argument as a
			-- placeholder, so the nil call is asserted through its matcher.
			jestExpect(onRefMock).toHaveBeenNthCalledWith(2, nil)
			jestExpect(onRefMock.mock.calls[3][1]).never.toBeNil()
		end)

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
				ReactNoop.render(
					React.createElement(React.StrictMode, nil, React.createElement(App))
				)
			end)

			jestExpect(log).toEqual({
				"componentDidMount",
				"componentWillUnmount",
				"componentDidMount",
			})
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
				ReactNoop.render(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(App, { text = "mount" })
					)
				)
			end)

			jestExpect(log).toEqual({
				"componentDidMount",
				"componentWillUnmount",
				"componentDidMount",
			})

			table.clear(log)
			act(function()
				ReactNoop.render(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(App, { text = "update" })
					)
				)
			end)

			jestExpect(log).toEqual({ "componentDidUpdate" })

			table.clear(log)
			act(function()
				ReactNoop.render(nil)
			end)

			jestExpect(log).toEqual({ "componentWillUnmount" })
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

			table.clear(log)
			act(function()
				ReactNoop.render(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(App, { text = "mount" })
					)
				)
			end)

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
		end)

		it("newly mounted components after initial mount get double invoked", function()
			local _setShowChild
			local log = {}
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
				ReactNoop.render(
					React.createElement(React.StrictMode, nil, React.createElement(App))
				)
			end)

			jestExpect(log).toEqual({
				"App useLayoutEffect mount",
				"App useEffect mount",
				"App useLayoutEffect unmount",
				"App useEffect unmount",
				"App useLayoutEffect mount",
				"App useEffect mount",
			})

			table.clear(log)
			act(function()
				_setShowChild(true)
			end)

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
					React.StrictMode,
					nil,
					React.createElement(ClassChild, { text = props.text }),
					React.createElement(FunctionChild, { text = props.text })
				)
			end

			act(function()
				ReactNoop.render(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(App, { text = "mount" })
					)
				)
			end)

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

			table.clear(log)
			act(function()
				ReactNoop.render(
					React.createElement(
						React.StrictMode,
						nil,
						React.createElement(App, { text = "mount" })
					)
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
				ReactNoop.render(nil)
			end)

			jestExpect(log).toEqual({
				"componentWillUnmount",
				"useLayoutEffect unmount",
				"useEffect unmount",
			})
		end)
	end
end)

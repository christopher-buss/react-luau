-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react/src/__tests__/ReactStrictMode-test.internal.js
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

describe("ReactStrictMode", function()
	local React
	local ReactRoblox
	local act

	beforeEach(function()
		jest.resetModules()
		React = require(Packages.React)
		-- ROBLOX DEVIATION: ReactRoblox replaces ReactDOMClient, a Folder
		-- replaces the DOM container, and ReactRoblox.act replaces
		-- internal-test-utils act.
		ReactRoblox = require(Packages.Dev.ReactRoblox)

		act = ReactRoblox.act
	end)

	describe("levels", function()
		local log

		beforeEach(function()
			log = {}
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

			return nil
		end

		it("should default to not strict", function()
			act(function()
				local container = Instance.new("Folder")
				local root = ReactRoblox.createRoot(container)
				root:render(React.createElement(Component, { label = "A" }))
			end)

			jestExpect(log).toEqual({
				"A: render",
				"A: useLayoutEffect mount",
				"A: useEffect mount",
			})
		end)

		if __DEV__ then
			it("should support enabling strict mode via createRoot option", function()
				act(function()
					local container = Instance.new("Folder")
					local root = ReactRoblox.createRoot(container, {
						unstable_strictMode = true,
					})
					root:render(React.createElement(Component, { label = "A" }))
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

			it("should include legacy + strict effects mode", function()
				act(function()
					local container = Instance.new("Folder")
					local root = ReactRoblox.createRoot(container)
					root:render(
						React.createElement(
							React.StrictMode,
							nil,
							React.createElement(Component, { label = "A" })
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

			it("should allow level to be increased with nesting", function()
				-- ROBLOX DEVIATION: ReactRoblox has no text Instances, so the stray
				-- "," text children of the upstream JSX are omitted.
				act(function()
					local container = Instance.new("Folder")
					local root = ReactRoblox.createRoot(container)
					root:render(
						React.createElement(
							React.Fragment,
							nil,
							React.createElement(Component, { label = "A" }),
							React.createElement(
								React.StrictMode,
								nil,
								React.createElement(Component, { label = "B" })
							)
						)
					)
				end)

				jestExpect(log).toEqual({
					"A: render",
					"B: render",
					"B: render",
					"A: useLayoutEffect mount",
					"B: useLayoutEffect mount",
					"A: useEffect mount",
					"B: useEffect mount",
					"B: useLayoutEffect unmount",
					"B: useEffect unmount",
					"B: useLayoutEffect mount",
					"B: useEffect mount",
				})
			end)

			it("should support nested strict mode on initial mount", function()
				local function Wrapper(props)
					return props.children
				end
				-- ROBLOX DEVIATION: ReactRoblox has no text Instances, so the stray
				-- "," text children of the upstream JSX are omitted.
				act(function()
					local container = Instance.new("Folder")
					local root = ReactRoblox.createRoot(container)
					root:render(
						React.createElement(
							Wrapper,
							nil,
							React.createElement(Component, { label = "A" }),
							React.createElement(
								React.StrictMode,
								nil,
								React.createElement(Component, { label = "B" })
							)
						)
					)
				end)

				jestExpect(log).toEqual({
					"A: render",
					"B: render",
					"B: render",
					"A: useLayoutEffect mount",
					"B: useLayoutEffect mount",
					"A: useEffect mount",
					"B: useEffect mount",
					-- TODO: this is currently broken
					-- 'B: useLayoutEffect unmount',
					-- 'B: useEffect unmount',
					-- 'B: useLayoutEffect mount',
					-- 'B: useEffect mount',
				})
			end)
		end
	end)
end)

-- ROBLOX upstream: https://github.com/facebook/react/blob/2860e00cf8780dc2d59b87f3ff28ac88b908660f/packages/react-reconciler/src/__tests__/useSyncExternalStore-test.js#L355-L478
-- ROBLOX DEVIATION: The two Activity regressions form a standalone suite;
-- unaffected upstream tests retain their existing separate port.
--[[
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * Licensed under the MIT license in the root LICENSE file.
]]
local Packages = script.Parent.Parent.Parent
local JestGlobals = require(Packages.Dev.JestGlobals)
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local it = JestGlobals.it
local jest = JestGlobals.jest
local jestExpect = JestGlobals.expect
local Set = require(Packages.LuauPolyfill).Set

local React
local ReactNoop
local Scheduler
local act
local useLayoutEffect
local useSyncExternalStore

describe("useSyncExternalStore", function()
	beforeEach(function()
		jest.resetModules()
		React = require(Packages.React)
		ReactNoop = require(Packages.Dev.ReactNoopRenderer)
		Scheduler = require(Packages.Scheduler)
		useLayoutEffect = React.useLayoutEffect
		useSyncExternalStore = React.useSyncExternalStore
		-- ROBLOX DEVIATION: ReactNoop.act drains the same render/passive work
		-- synchronously; Scheduler's matcher replaces assertLog.
		act = ReactNoop.act
	end)

	local function Text(props)
		Scheduler.unstable_yieldValue(props.text)
		return props.text
	end

	-- ROBLOX upstream: https://github.com/facebook/react/blob/2860e00cf8780dc2d59b87f3ff28ac88b908660f/packages/react-reconciler/src/__tests__/useSyncExternalStore-test.js#L121-L141
	local function createExternalStore(initialState)
		local listeners = Set.new()
		local currentState = initialState
		return {
			set = function(text)
				currentState = text
				ReactNoop.batchedUpdates(function()
					listeners:forEach(function(listener)
						listener()
					end)
				end)
			end,
			subscribe = function(listener)
				listeners:add(listener)
				return function()
					listeners:delete(listener)
				end
			end,
			getState = function()
				return currentState
			end,
			getSubscriberCount = function()
				return listeners.size
			end,
		}
	end

	it(
		"detects store mutations from a layout effect while an Activity subtree is being revealed",
		function()
			local store = createExternalStore("revision:1")
			-- ROBLOX DEVIATION: Forward locals replace JavaScript function hoisting.
			local Wrapper
			local Subscriber
			local function App(props)
				return React.createElement(
					React.Activity,
					{ mode = props.mode },
					React.createElement(
						Wrapper,
						{ revision = props.revision },
						React.createElement(Subscriber)
					)
				)
			end
			Wrapper = function(props)
				useLayoutEffect(function()
					store.set("revision:" .. props.revision)
				end, { props.revision })
				return React.createElement(
					React.Fragment,
					nil,
					"wrapper:",
					props.revision,
					", ",
					props.children
				)
			end
			Subscriber = function()
				local revision = useSyncExternalStore(store.subscribe, store.getState)
				return React.createElement(Text, { text = revision })
			end
			local root = ReactNoop.createRoot()
			act(function()
				root.render(
					React.createElement(App, { mode = "visible", revision = "1" })
				)
			end)
			jestExpect(Scheduler).toHaveYielded({ "revision:1" })
			jestExpect(root).toMatchRenderedOutput("wrapper:1, revision:1")
			jestExpect(store.getSubscriberCount()).toBe(1)

			act(function()
				root.render(React.createElement(App, { mode = "hidden", revision = "1" }))
			end)
			jestExpect(Scheduler).toHaveYielded({ "revision:1" })
			jestExpect(store.getSubscriberCount()).toBe(0)

			act(function()
				root.render(
					React.createElement(App, { mode = "visible", revision = "2" })
				)
			end)
			jestExpect(Scheduler).toHaveYielded({ "revision:1", "revision:2" })
			jestExpect(store.getSubscriberCount()).toBe(1)
			jestExpect(root).toMatchRenderedOutput("wrapper:2, revision:2")
		end
	)

	it(
		"detects store mutations that happened while an Activity subtree was "
			.. "hidden, even if the subtree bails out of rendering when revealed",
		function()
			local store = createExternalStore("initial")
			local Subscriber = React.memo(function(props)
				local value = useSyncExternalStore(store.subscribe, store.getState)
				return React.createElement(Text, { text = props.label .. ":" .. value })
			end)
			local function App(props)
				return React.createElement(
					React.Activity,
					{ mode = props.mode },
					React.createElement(Subscriber, { label = props.label })
				)
			end
			local root = ReactNoop.createRoot()
			act(function()
				root.render(React.createElement(App, { mode = "visible", label = "a" }))
			end)
			jestExpect(Scheduler).toHaveYielded({ "a:initial" })
			jestExpect(root).toMatchRenderedOutput("a:initial")
			jestExpect(store.getSubscriberCount()).toBe(1)

			act(function()
				root.render(React.createElement(App, { mode = "visible", label = "b" }))
			end)
			jestExpect(Scheduler).toHaveYielded({ "b:initial" })
			jestExpect(root).toMatchRenderedOutput("b:initial")

			act(function()
				root.render(React.createElement(App, { mode = "hidden", label = "b" }))
			end)
			jestExpect(store.getSubscriberCount()).toBe(0)

			act(function()
				store.set("updated")
			end)
			jestExpect(Scheduler).toHaveYielded({})

			act(function()
				root.render(React.createElement(App, { mode = "visible", label = "b" }))
			end)
			jestExpect(Scheduler).toHaveYielded({ "b:updated" })
			jestExpect(store.getSubscriberCount()).toBe(1)
			jestExpect(root).toMatchRenderedOutput("b:updated")
		end
	)
end)

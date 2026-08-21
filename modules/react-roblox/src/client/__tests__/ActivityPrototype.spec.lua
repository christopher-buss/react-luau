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
local ReactRoblox
local parent
local root

describe("Activity prototype", function()
	beforeEach(function()
		jest.resetModules()
		jest.useFakeTimers()

		React = require(Packages.React)
		ReactRoblox = require(Packages.ReactRoblox)
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
end)

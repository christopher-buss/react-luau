-- ROBLOX upstream: https://github.com/facebook/react/blob/ae74234eae6ebd62f19190731278e20bc1c37d51/packages/react-reconciler/src/__tests__/ReactErrorStacks-test.js

local Packages = script.Parent.Parent.Parent
local LuauPolyfill = require(Packages.LuauPolyfill)
local Error = LuauPolyfill.Error
local JestGlobals = require(Packages.Dev.JestGlobals)
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local it = JestGlobals.it
local jest = JestGlobals.jest
local jestExpect = JestGlobals.expect

local React
local ReactNoop

describe("ReactErrorStacks", function()
	beforeEach(function()
		jest.resetModules()

		React = require(Packages.React)
		ReactNoop = require(Packages.Dev.ReactNoopRenderer)
	end)

	it("includes built-in for Activity", function()
		local componentStack
		local function SomethingThatErrors()
			error(Error.new("uh oh"), 0)
		end

		local CatchingBoundary = React.Component:extend("CatchingBoundary")
		function CatchingBoundary:init()
			self.state = { error = nil }
		end
		function CatchingBoundary.getDerivedStateFromError(error_)
			return { error = error_ }
		end
		function CatchingBoundary:componentDidCatch(error_, info)
			componentStack = info.componentStack
		end
		function CatchingBoundary:render()
			if self.state.error ~= nil then
				return nil
			end
			return self.props.children
		end

		local root = ReactNoop.createRoot()
		jestExpect(function()
			ReactNoop.act(function()
				root.render(
					React.createElement(
						CatchingBoundary,
						nil,
						React.createElement(
							React.Activity,
							nil,
							React.createElement(SomethingThatErrors)
						)
					)
				)
			end)
		end).toErrorDev(
			"The above error occurred in the <SomethingThatErrors> component:",
			{
				logAllErrors = true,
			}
		)

		jestExpect(componentStack).toContain("in SomethingThatErrors")
		jestExpect(componentStack).toContain("in Activity")
		jestExpect(componentStack).toContain("in CatchingBoundary")
	end)
end)

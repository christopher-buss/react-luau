-- ROBLOX upstream: https://github.com/facebook/react/blob/ae74234eae6ebd62f19190731278e20bc1c37d51/packages/react-reconciler/src/__tests__/ActivityStrictMode-test.js

local Packages = script.Parent.Parent.Parent
local JestGlobals = require(Packages.Dev.JestGlobals)
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local it = JestGlobals.it
local jest = JestGlobals.jest

local React
local ReactNoop

describe("Activity StrictMode", function()
	beforeEach(function()
		jest.resetModules()

		React = require(Packages.React)
		ReactNoop = require(Packages.Dev.ReactNoopRenderer)
	end)

	-- ROBLOX deviation: The other upstream cases require Strict Effects and
	-- sibling prewarming, which React-Luau does not implement.
	it(
		"should not cause infinite render loop when StrictMode is used with Suspense and synchronous set states",
		function()
			local function App()
				local state, setState = React.useState(false)

				React.useLayoutEffect(function()
					setState(true)
				end, {})

				React.useEffect(function() end, {})

				return state
			end

			ReactNoop.act(function()
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
end)

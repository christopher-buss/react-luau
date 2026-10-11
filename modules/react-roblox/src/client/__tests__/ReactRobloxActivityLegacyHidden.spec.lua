-- ROBLOX upstream: https://github.com/facebook/react/blob/52684925368a41a0c9fbfca9016cdcbb72fc9d1e/packages/react-dom/src/__tests__/ReactDOMActivity-test.js#L1-L134
-- ROBLOX DEVIATION: Folder/TextLabel replace div/text; Parent=nil replaces
-- display:none assertions because ReactRoblox hides by detaching Instances.
local Packages = script.Parent.Parent.Parent.Parent
local JestGlobals = require(Packages.Dev.JestGlobals)
local beforeEach = JestGlobals.beforeEach
local afterEach = JestGlobals.afterEach
local describe = JestGlobals.describe
local it = JestGlobals.it
local jest = JestGlobals.jest
local jestExpect = JestGlobals.expect

local React
local Activity
local useState
local ReactRoblox
local act
local container

describe("ReactDOMActivity", function()
	beforeEach(function()
		jest.resetModules()
		jest.useFakeTimers()
		React = require(Packages.React)
		Activity = React.Activity
		useState = React.useState
		ReactRoblox = require(Packages.ReactRoblox)
		act = ReactRoblox.act
		container = Instance.new("Folder")
		container.Parent = workspace
	end)

	afterEach(function()
		container:Destroy()
	end)

	it("reveals an Activity inside LegacyHidden without hiding its content", function()
		local root = ReactRoblox.createRoot(container)
		local function App(props)
			return React.createElement(
				React.unstable_LegacyHidden,
				{ mode = "unstable-defer-without-hiding" },
				React.createElement(
					Activity,
					{ mode = props.mode },
					React.createElement("TextLabel", { Text = "Content" })
				)
			)
		end
		act(function()
			root:render(React.createElement(App, { mode = "hidden" }))
		end)
		jestExpect(#container:GetChildren()).toBe(0)
		act(function()
			root:render(React.createElement(App, { mode = "visible" }))
		end)
		jestExpect(#container:GetChildren()).toBe(1)
		jestExpect(container:GetChildren()[1].Text).toBe("Content")
	end)
end)

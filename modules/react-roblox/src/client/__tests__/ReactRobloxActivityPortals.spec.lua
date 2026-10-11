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

	it(
		"hiding an Activity boundary also hides the direct children of any portals it contains, regardless of how deeply nested they are",
		function()
			local portalContainer = Instance.new("Folder")
			local setShow
			local function Accordion(props)
				local shouldShow, updateShow = useState(true)
				setShow = updateShow
				return React.createElement(Activity, {
					mode = if shouldShow then "visible" else "hidden",
				}, props.children)
			end

			local function App(_props)
				return React.createElement(
					Accordion,
					nil,
					React.createElement(
						"Folder",
						nil,
						ReactRoblox.createPortal(
							React.createElement("TextLabel", { Text = "Portal contents" }),
							portalContainer
						)
					)
				)
			end

			local root = ReactRoblox.createRoot(container)
			act(function()
				root:render(React.createElement(App))
			end)
			local host = container:GetChildren()[1]
			local portalHost = portalContainer:GetChildren()[1]
			jestExpect(host.ClassName).toBe("Folder")
			jestExpect(#host:GetChildren()).toBe(0)
			jestExpect(portalHost.Text).toBe("Portal contents")

			act(function()
				setShow(false)
			end)
			jestExpect(host.Parent).toBeNil()
			jestExpect(portalHost.Parent).toBeNil()
			jestExpect(portalHost.Text).toBe("Portal contents")
		end
	)

	it(
		"revealing an Activity boundary inside a portal does not reveal the portal contents if has a hidden Activity parent",
		function()
			local portalContainer = Instance.new("Folder")
			local setShow
			local function Accordion(props)
				local shouldShow, updateShow = useState(false)
				setShow = updateShow
				return React.createElement(Activity, {
					mode = if shouldShow then "visible" else "hidden",
				}, props.children)
			end

			local function App(_props)
				return React.createElement(
					Activity,
					{ mode = "hidden" },
					React.createElement(
						"Folder",
						nil,
						ReactRoblox.createPortal(
							React.createElement(
								Accordion,
								nil,
								React.createElement(
									"TextLabel",
									{ Text = "Portal contents" }
								)
							),
							portalContainer
						)
					)
				)
			end

			local root = ReactRoblox.createRoot(container)
			act(function()
				root:render(React.createElement(App))
			end)
			-- ROBLOX DEVIATION: Initially hidden Instances have no connected refs and
			-- no DOM serialization; assert absence from both host containers.
			jestExpect(#container:GetChildren()).toBe(0)
			jestExpect(#portalContainer:GetChildren()).toBe(0)

			act(function()
				setShow(true)
			end)
			jestExpect(#container:GetChildren()).toBe(0)
			jestExpect(#portalContainer:GetChildren()).toBe(0)
		end
	)
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

-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom/src/__tests__/ReactDOMFragmentRefs-test.js#L2311-L2350
-- ROBLOX DEVIATION: Native raw layout supplies one rectangle per GUI rather
-- than multiple DOM border/text runs. Read-only properties use real settled layout.
local Packages = script.Parent.Parent.Parent.Parent
local JestGlobals = require(Packages.Dev.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach, jest =
	JestGlobals.beforeEach, JestGlobals.afterEach, JestGlobals.jest
local React, ReactRoblox, parent, root
local describeClient = if game:GetService("RunService"):IsClient()
	then describe
	else describe.skip
describeClient("FragmentRefs getClientRects", function()
	beforeEach(function()
		jest.resetModules()
		React = require(Packages.React)
		ReactRoblox = require(Packages.ReactRoblox)
		parent = Instance.new("ScreenGui")
		parent.IgnoreGuiInset = true
		parent.Parent = game:GetService("Players").LocalPlayer.PlayerGui
		root = ReactRoblox.createRoot(parent)
	end)
	afterEach(function()
		ReactRoblox.act(function()
			root:unmount()
		end)
		parent:Destroy()
	end)
	it("returns the bounding client rects of all children", function()
		local fragmentRef, childARef, childBRef =
			React.createRef(), React.createRef(), React.createRef()
		local function Test()
			return React.createElement(React.Fragment, { ref = fragmentRef }, {
				React.createElement("Frame", {
					ref = childARef,
					Position = UDim2.fromOffset(1, 2),
					Size = UDim2.fromOffset(3, 4),
				}),
				React.createElement("Frame", {
					ref = childBRef,
					Position = UDim2.fromOffset(9, 10),
					Size = UDim2.fromOffset(11, 12),
				}),
			})
		end
		ReactRoblox.act(function()
			root:render(React.createElement(Test))
		end)
		for _ = 1, 4 do
			game:GetService("RunService").RenderStepped:Wait()
		end
		local clientRects = fragmentRef.current:getClientRects()
		expect(#clientRects).toBe(2)
		expect(clientRects[1].left).toBe(1)
		expect(clientRects[2].left).toBe(9)
		-- ROBLOX DEVIATION: IgnoreGuiInset layout offsets are converted into the
		-- engine's raw GUI inset coordinates rather than normalized viewport pixels.
		local inset = game:GetService("GuiService"):GetGuiInset()
		expect(clientRects[1]).toEqual({
			x = 1,
			y = 2 - inset.Y,
			width = 3,
			height = 4,
			left = 1,
			top = 2 - inset.Y,
			right = 4,
			bottom = 6 - inset.Y,
		})
	end)
	-- ROBLOX DEVIATION: Raw layout snapshots are frozen and deliberately do not
	-- describe paint clipping, rotation polygons, or deeper host cardinality.
	it("returns immutable raw layout snapshots for clipped and rotated hosts", function()
		local fragmentRef = React.createRef()
		local function Test(props)
			return React.createElement(React.Fragment, { ref = fragmentRef }, {
				React.createElement(
					"Frame",
					{
						key = "first",
						Position = UDim2.fromOffset(props.left, 100),
						Size = UDim2.fromOffset(50, 50),
						ClipsDescendants = true,
						Rotation = 45,
					},
					React.createElement("Frame", {
						Position = UDim2.fromOffset(200, 200),
						Size = UDim2.fromOffset(50, 50),
					})
				),
				React.createElement("Frame", {
					key = "second",
					Position = UDim2.fromOffset(400, 100),
					Size = UDim2.fromOffset(50, 50),
				}),
			})
		end
		ReactRoblox.act(function()
			root:render(React.createElement(Test, { left = 100 }))
		end)
		for _ = 1, 4 do
			game:GetService("RunService").RenderStepped:Wait()
		end
		local previous = fragmentRef.current:getClientRects()
		expect(#previous).toBe(2)
		expect(previous[1].left).toBe(100)
		expect(previous[1].width).toBe(50)
		expect(table.isfrozen(previous)).toBe(true)
		expect(table.isfrozen(previous[1])).toBe(true)
		ReactRoblox.act(function()
			root:render(React.createElement(Test, { left = 150 }))
		end)
		for _ = 1, 4 do
			game:GetService("RunService").RenderStepped:Wait()
		end
		expect(previous[1].left).toBe(100)
		expect(fragmentRef.current:getClientRects()[1].left).toBe(150)
	end)
end)

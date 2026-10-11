-- Roblox-specific GUI adapter regressions, run in a real engine client.
-- The upstream observeUsing cases remain in ReactRobloxFragmentObservation.
local Packages = script.Parent.Parent.Parent.Parent
local JestGlobals = require(Packages.Dev.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local beforeEach = JestGlobals.beforeEach
local afterEach = JestGlobals.afterEach
local expect = JestGlobals.expect
local jest = JestGlobals.jest
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReactRoblox
local gui
local observers

local function settle()
	for _ = 1, 4 do
		RunService.RenderStepped:Wait()
	end
	task.wait()
end

local clientDescribe = if RunService:IsClient() then describe else describe.skip
clientDescribe("Roblox Fragment observer client geometry", function()
	beforeEach(function()
		jest.resetModules()
		jest.useRealTimers()
		ReactRoblox = require(Packages.ReactRoblox)
		gui = Instance.new("ScreenGui")
		gui.IgnoreGuiInset = true
		gui.Parent = Players.LocalPlayer.PlayerGui
		observers = {}
	end)

	afterEach(function()
		for _, observer in observers do
			observer:disconnect()
		end
		gui:Destroy()
	end)

	it("reports literal content sizes and clipped intersection thresholds", function()
		local parent = Instance.new("Frame")
		parent.Position = UDim2.fromOffset(100, 80)
		parent.Size = UDim2.fromOffset(100, 100)
		parent.ClipsDescendants = true
		parent.Parent = gui
		local target = Instance.new("Frame")
		target.Position = UDim2.fromOffset(50, 0)
		target.Size = UDim2.fromOffset(100, 40)
		target.Parent = parent
		settle()
		local inset = GuiService:GetGuiInset()
		local sizes = {}
		local entries = {}
		local resize = ReactRoblox.createResizeObserver(function(records)
			for _, entry in records do
				table.insert(sizes, entry.contentRect.width)
			end
		end)
		local intersection = ReactRoblox.createIntersectionObserver(function(records)
			for _, entry in records do
				table.insert(entries, entry)
			end
		end, { threshold = { 0, 0.5, 1 } })
		table.insert(observers, resize)
		table.insert(observers, intersection)
		resize:observe(target)
		intersection:observe(target)
		settle()
		expect(sizes).toEqual({ 100 })
		expect(entries[1].boundingClientRect.x).toBe(150 - inset.X)
		expect(entries[1].boundingClientRect.y).toBe(80 - inset.Y)
		expect(entries[1].boundingClientRect.width).toBe(100)
		expect(entries[1].boundingClientRect.height).toBe(40)
		expect(entries[1].intersectionRatio).toBe(0.5)
		target.Position = UDim2.fromOffset(0, 0)
		target.Size = UDim2.fromOffset(80, 40)
		settle()
		expect(sizes).toEqual({ 100, 80 })
		expect(#entries).toBe(2)
		expect(entries[2].intersectionRatio).toBe(1)
		gui.Enabled = false
		settle()
		expect(#entries).toBe(3)
		expect(entries[3].isIntersecting).toBe(false)
		expect(entries[3].intersectionRatio).toBe(0)
	end)

	it("tracks ScrollingFrame clipping and expands the viewport by rootMargin", function()
		local scroll = Instance.new("ScrollingFrame")
		scroll.Position = UDim2.fromOffset(100, 100)
		scroll.Size = UDim2.fromOffset(200, 100)
		scroll.CanvasSize = UDim2.fromOffset(200, 500)
		scroll.ScrollBarThickness = 0
		scroll.BorderSizePixel = 0
		scroll.Parent = gui
		local target = Instance.new("Frame")
		target.Position = UDim2.fromOffset(0, 150)
		target.Size = UDim2.fromOffset(100, 100)
		target.Parent = scroll
		settle()
		local ratios = {}
		local observer = ReactRoblox.createIntersectionObserver(function(entries)
			for _, entry in entries do
				table.insert(ratios, entry.intersectionRatio)
			end
		end, { root = scroll, threshold = { 0, 0.5, 1 } })
		table.insert(observers, observer)
		observer:observe(target)
		settle()
		scroll.CanvasPosition = Vector2.new(0, 100)
		settle()
		scroll.CanvasPosition = Vector2.new(0, 150)
		settle()
		expect(ratios).toEqual({ 0, 0.5, 1 })
		observer:disconnect()
		local expandedRatios = {}
		local margin = ReactRoblox.createIntersectionObserver(function(entries)
			for _, entry in entries do
				table.insert(expandedRatios, entry.intersectionRatio)
			end
		end, { root = gui, rootMargin = "0px 0px 100px 0px" })
		table.insert(observers, margin)
		target.Parent = gui
		target.Position = UDim2.new(0, 0, 1, 20)
		target.Size = UDim2.fromOffset(100, 50)
		settle()
		margin:observe(target)
		settle()
		expect(expandedRatios).toEqual({ 1 })
	end)

	it("retains overlapping owners and cancels a reveal's delayed release", function()
		local target = Instance.new("Frame")
		target.Size = UDim2.fromOffset(40, 40)
		target.Position = UDim2.fromOffset(100, 100)
		target.Parent = gui
		settle()
		local ratios = {}
		local observer = ReactRoblox.createIntersectionObserver(function(entries)
			for _, entry in entries do
				table.insert(ratios, entry.intersectionRatio)
			end
		end)
		table.insert(observers, observer)
		local first, second = {}, {}
		observer:observe(target, first)
		observer:observe(target, second)
		settle()
		observer:unobserveAfterExit(target, first)
		target.Position = UDim2.new(1, 100, 0, 100)
		settle()
		target.Position = UDim2.fromOffset(100, 100)
		settle()
		observer:unobserveAfterExit(target, second)
		observer:observe(target, second)
		settle()
		target.Position = UDim2.new(1, 100, 0, 100)
		settle()
		expect(ratios).toEqual({ 1, 0, 1, 0 })
	end)

	it("delivers a later exit when the callback removes its own target", function()
		local target = Instance.new("Frame")
		target.Position = UDim2.fromOffset(100, 100)
		target.Size = UDim2.fromOffset(40, 40)
		target.Parent = gui
		settle()
		local ratios = {}
		local observer
		observer = ReactRoblox.createIntersectionObserver(function(entries)
			for _, entry in entries do
				table.insert(ratios, entry.intersectionRatio)
			end
			if #ratios == 1 then
				target.Parent = nil
				observer:unobserveAfterExit(target)
			end
		end)
		table.insert(observers, observer)
		observer:observe(target)
		settle()
		expect(ratios).toEqual({ 1, 0 })
		target:Destroy()
	end)

	it(
		"reports UIScale changes and rejects unsupported projected or rotated intersections",
		function()
			local parent = Instance.new("Frame")
			parent.Position = UDim2.fromOffset(100, 100)
			parent.Size = UDim2.fromOffset(200, 200)
			parent.Parent = gui
			local scale = Instance.new("UIScale")
			scale.Scale = 2
			scale.Parent = parent
			local target = Instance.new("Frame")
			target.Position = UDim2.fromOffset(10, 20)
			target.Size = UDim2.fromOffset(30, 40)
			target.Parent = parent
			settle()
			local sizes = {}
			local resize = ReactRoblox.createResizeObserver(function(entries)
				for _, entry in entries do
					table.insert(
						sizes,
						{ entry.contentRect.width, entry.contentRect.height }
					)
				end
			end)
			table.insert(observers, resize)
			resize:observe(target)
			settle()
			scale.Scale = 1
			settle()
			expect(sizes).toEqual({ { 60, 80 }, { 30, 40 } })
			local intersection = ReactRoblox.createIntersectionObserver(function() end)
			table.insert(observers, intersection)
			parent.ClipsDescendants = true
			parent.Rotation = 30
			settle()
			expect(function()
				intersection:observe(target)
			end).toThrow(
				"Fragment intersection observers do not support rotated GUI geometry"
			)
			local surface = Instance.new("SurfaceGui")
			surface.Parent = gui
			target.Parent = surface
			expect(function()
				intersection:observe(target)
			end).toThrow(
				"Fragment intersection observers do not support SurfaceGui or BillboardGui targets"
			)
		end
	)

	it(
		"delivers the final intersection exit when an observed Fragment is deleted",
		function()
			local React = require(Packages.React)
			local fragmentRef = React.createRef()
			local ratios = {}
			local observer = ReactRoblox.createIntersectionObserver(function(entries)
				for _, entry in entries do
					table.insert(ratios, entry.intersectionRatio)
				end
			end)
			table.insert(observers, observer)
			local root = ReactRoblox.createRoot(gui)
			ReactRoblox.act(function()
				root:render(
					React.createElement(
						React.Fragment,
						{ ref = fragmentRef },
						React.createElement("Frame", {
							Position = UDim2.fromOffset(100, 100),
							Size = UDim2.fromOffset(40, 40),
						})
					)
				)
			end)
			fragmentRef.current:observeUsing(observer)
			settle()
			ReactRoblox.act(function()
				root:render(nil)
			end)
			settle()
			expect(ratios).toEqual({ 1, 0 })
			ReactRoblox.act(function()
				root:unmount()
			end)
		end
	)

	it(
		"lets a saved deleted Fragment cancel pending exits during effect cleanup",
		function()
			local React = require(Packages.React)
			local fragmentRef = React.createRef()
			local ratios = {}
			local observer = ReactRoblox.createIntersectionObserver(function(entries)
				for _, entry in entries do
					table.insert(ratios, entry.intersectionRatio)
				end
			end)
			table.insert(observers, observer)
			local root = ReactRoblox.createRoot(gui)
			ReactRoblox.act(function()
				root:render(
					React.createElement(
						React.Fragment,
						{ ref = fragmentRef },
						React.createElement("Frame", {
							Position = UDim2.fromOffset(100, 100),
							Size = UDim2.fromOffset(40, 40),
						})
					)
				)
			end)
			local savedFragment = fragmentRef.current
			savedFragment:observeUsing(observer)
			settle()
			ReactRoblox.act(function()
				root:render(nil)
			end)
			savedFragment:unobserveUsing(observer)
			settle()
			expect(ratios).toEqual({ 1 })
			ReactRoblox.act(function()
				root:unmount()
			end)
		end
	)
end)

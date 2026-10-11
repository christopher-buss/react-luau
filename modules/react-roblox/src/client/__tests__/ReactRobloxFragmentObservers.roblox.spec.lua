-- Roblox-specific public adapter contracts. Upstream method/membership cases
-- remain in ReactRobloxFragmentObservation.roblox.spec.lua.
local Packages = script.Parent.Parent.Parent.Parent
local JestGlobals = require(Packages.Dev.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local beforeEach = JestGlobals.beforeEach
local afterEach = JestGlobals.afterEach
local expect = JestGlobals.expect
local jest = JestGlobals.jest
local React
local ReactRoblox
local act
local container
local root
local observers

beforeEach(function()
	jest.resetModules()
	React = require(Packages.React)
	ReactRoblox = require(Packages.ReactRoblox)
	act = ReactRoblox.act
	container = Instance.new("Folder")
	root = ReactRoblox.createRoot(container)
	observers = {}
end)

afterEach(function()
	for _, observer in observers do
		observer:disconnect()
	end
	act(function()
		root:unmount()
	end)
	container:Destroy()
end)

describe("Roblox Fragment observer adapters", function()
	it("reports the initial content size of an observed GuiObject", function()
		local entries = {}
		local observer = ReactRoblox.createResizeObserver(function(records)
			for _, entry in records do
				table.insert(entries, entry)
			end
		end)
		table.insert(observers, observer)
		local childRef = React.createRef()
		act(function()
			root:render(React.createElement("Frame", { ref = childRef }))
		end)
		observer:observe(childRef.current)
		task.wait()
		task.wait()
		expect(#entries).toBe(1)
		expect(entries[1].target).toBe(childRef.current)
		expect(entries[1].contentRect.width).toBe(childRef.current.AbsoluteSize.X)
		expect(entries[1].contentRect.height).toBe(childRef.current.AbsoluteSize.Y)
		expect(entries[1].contentRect.x).toBe(0)
		expect(entries[1].contentRect.y).toBe(0)
	end)

	it("releases only one owner's targets when the observer is shared", function()
		local entries = {}
		local observer = ReactRoblox.createResizeObserver(function(records)
			for _, entry in records do
				table.insert(entries, entry.target.Name)
			end
		end)
		table.insert(observers, observer)
		local first = Instance.new("Frame")
		first.Name = "first"
		first.Parent = container
		local second = Instance.new("Frame")
		second.Name = "second"
		second.Parent = container
		local owner = {}
		observer:observe(first, owner)
		observer:observe(second, owner)
		observer:observe(second)
		observer:releaseOwner(owner)
		task.wait()
		task.wait()
		expect(entries).toEqual({ "second" })
	end)

	it(
		"cancels initial delivery on unobserve or disconnect and can observe again",
		function()
			local deliveries = 0
			local observer = ReactRoblox.createResizeObserver(function()
				deliveries += 1
			end)
			table.insert(observers, observer)
			local target = Instance.new("Frame")
			target.Parent = container
			observer:observe(target)
			observer:unobserve(target)
			task.wait()
			task.wait()
			expect(deliveries).toBe(0)
			observer:observe(target)
			observer:disconnect()
			task.wait()
			task.wait()
			expect(deliveries).toBe(0)
			observer:observe(target)
			task.wait()
			task.wait()
			expect(deliveries).toBe(1)
		end
	)

	it("normalizes margins and thresholds and rejects unsupported options", function()
		local observer = ReactRoblox.createIntersectionObserver(
			function() end,
			{ rootMargin = "1px 2%", threshold = { 1, 0.5, 0.5, 0 } }
		)
		table.insert(observers, observer)
		expect(observer.rootMargin).toBe("1px 2% 1px 2%")
		expect(observer.thresholds).toEqual({ 0, 0.5, 1 })
		expect(function()
			ReactRoblox.createIntersectionObserver(function() end, { threshold = 2 })
		end).toThrow(
			"IntersectionObserver thresholds must be finite numbers between 0 and 1"
		)
		expect(function()
			ReactRoblox.createIntersectionObserver(function() end, { rootMargin = "1em" })
		end).toThrow(
			"IntersectionObserver rootMargin must contain one to four px or % values"
		)
		expect(function()
			ReactRoblox.createIntersectionObserver(
				function() end,
				{ trackVisibility = true }
			)
		end).toThrow(
			"Unsupported Fragment intersection observer option: trackVisibility"
		)
	end)

	it(
		"releases a deleted resize owner immediately while keeping another owner",
		function()
			local entries = {}
			local observer = ReactRoblox.createResizeObserver(function(records)
				for _, entry in records do
					table.insert(entries, entry.target.Name)
				end
			end)
			table.insert(observers, observer)
			local first = Instance.new("Frame")
			first.Name = "first"
			first.Parent = container
			local second = Instance.new("Frame")
			second.Name = "second"
			second.Parent = container
			local owner = {}
			observer:observe(first, owner)
			observer:observe(second, owner)
			observer:observe(second)
			observer:releaseOwnerAfterExit(owner)
			task.wait()
			task.wait()
			expect(entries).toEqual({ "second" })
		end
	)
end)

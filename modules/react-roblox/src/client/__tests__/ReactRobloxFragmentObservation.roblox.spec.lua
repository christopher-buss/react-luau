-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom/src/__tests__/ReactDOMFragmentRefs-test.js#L1880-L2331
-- ROBLOX DEVIATION: Frame/Name replace div/id; native observer mocks remain the
-- external observer boundary. Colon methods translate JavaScript methods, and
-- owner tokens preserve shared observer subscriptions on Roblox.
local Packages = script.Parent.Parent.Parent.Parent
local JestGlobals = require(Packages.Dev.JestGlobals)
local beforeEach = JestGlobals.beforeEach
local afterEach = JestGlobals.afterEach
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect
local jest = JestGlobals.jest
local React
local ReactRoblox
local act
local container
local root
local pendingFrames
local mockObserver

local function createMockObserver(callback)
	local observedTargets = {}
	local owners = {}
	local pending = {}
	local external = {}
	local observer = { rootMargin = "0px", thresholds = { 0 } }
	function observer:observe(target, owner)
		owner = owner or external
		if owners[target] == nil then
			owners[target] = {}
			table.insert(observedTargets, target)
		end
		owners[target][owner] = true
		if pending[target] then
			pending[target][owner] = nil
		end
	end
	function observer:unobserve(target, owner)
		owner = owner or external
		if owners[target] == nil then
			return
		end
		owners[target][owner] = nil
		if pending[target] then
			pending[target][owner] = nil
		end
		if next(owners[target]) == nil then
			owners[target] = nil
			pending[target] = nil
			table.remove(observedTargets, table.find(observedTargets, target))
		end
	end
	function observer:unobserveAfterExit(target, owner)
		owner = owner or external
		pending[target] = pending[target] or {}
		local token = {}
		pending[target][owner] = token
		table.insert(pendingFrames, function()
			if pending[target] and pending[target][owner] == token then
				self:unobserve(target, owner)
			end
		end)
	end
	function observer:releaseOwner(owner)
		for _, target in table.clone(observedTargets) do
			self:unobserve(target, owner)
		end
	end
	function observer:simulate(records)
		local entries = {}
		for _, record in records do
			if owners[record[1]] then
				table.insert(
					entries,
					{ target = record[1], intersectionRatio = record[2] }
				)
			end
		end
		callback(entries)
	end
	observer.observedTargets = observedTargets
	return observer
end

local function observedIds(observer)
	local names = {}
	for _, target in observer.observedTargets do
		table.insert(names, target.Name)
	end
	return names
end

local function flushPostPaintCallbacks()
	local callbacks = pendingFrames
	pendingFrames = {}
	for _, callback in callbacks do
		callback()
	end
end

beforeEach(function()
	jest.resetModules()
	jest.useFakeTimers()
	React = require(Packages.React)
	ReactRoblox = require(Packages.ReactRoblox)
	act = ReactRoblox.act
	container = Instance.new("Folder")
	root = ReactRoblox.createRoot(container)
	pendingFrames = {}
end)

afterEach(function()
	act(function()
		root:unmount()
	end)
	container:Destroy()
end)

describe("observeUsing", function()
	it("attaches intersection observers to children", function()
		local logs = {}
		mockObserver = createMockObserver(function(entries)
			for _, entry in entries do
				table.insert(logs, entry.target.Name)
			end
		end)
		local function Test(props)
			local fragmentRef = React.useRef(nil)
			React.useEffect(function()
				fragmentRef.current:observeUsing(mockObserver)
				local lastRefValue = fragmentRef.current
				return function()
					lastRefValue:unobserveUsing(mockObserver)
				end
			end, {})
			return React.createElement(
				"Frame",
				{ Name = "parent" },
				React.createElement(
					React.Fragment,
					{ ref = fragmentRef },
					React.createElement("Frame", { Name = "childA" }),
					if props.showB
						then React.createElement("Frame", { Name = "childB" })
						else nil
				)
			)
		end
		local function simulateAllChildrenIntersecting()
			local parent = container:GetChildren()[1]
			local records = {}
			if parent then
				for _, child in parent:GetChildren() do
					table.insert(records, { child, 1 })
				end
			end
			mockObserver:simulate(records)
		end
		act(function()
			root:render(React.createElement(Test, { showB = false }))
		end)
		simulateAllChildrenIntersecting()
		expect(logs).toEqual({ "childA" })
		logs = {}
		act(function()
			root:render(React.createElement(Test, { showB = true }))
		end)
		simulateAllChildrenIntersecting()
		expect(logs).toEqual({ "childA", "childB" })
		logs = {}
		act(function()
			root:render(React.createElement(Test, { showB = false }))
		end)
		simulateAllChildrenIntersecting()
		expect(logs).toEqual({ "childA" })
		logs = {}
		act(function()
			root:render(nil)
		end)
		simulateAllChildrenIntersecting()
		expect(logs).toEqual({})
	end)

	it(
		"keeps a removed child observed until after the intersection exit, then unobserves it",
		function()
			local logs = {}
			local observer = createMockObserver(function(entries)
				for _, entry in entries do
					table.insert(
						logs,
						{ id = entry.target.Name, ratio = entry.intersectionRatio }
					)
				end
			end)
			local fragmentRef = React.createRef()
			local function Test(props)
				React.useEffect(function()
					fragmentRef.current:observeUsing(observer)
				end, {})
				return React.createElement(
					"Frame",
					{ Name = "parent" },
					React.createElement(
						React.Fragment,
						{ ref = fragmentRef },
						React.createElement("Frame", { Name = "childA" }),
						if props.showB
							then React.createElement("Frame", { Name = "childB" })
							else nil
					)
				)
			end
			act(function()
				root:render(React.createElement(Test, { showB = true }))
			end)
			local childA = container:FindFirstChild("childA", true)
			local childB = container:FindFirstChild("childB", true)
			expect(observedIds(observer)).toEqual({ "childA", "childB" })
			act(function()
				root:render(React.createElement(Test, { showB = false }))
			end)
			expect(observedIds(observer)).toEqual({ "childA", "childB" })
			expect(childB.Parent).toBeNil()
			observer:simulate({ { childA, 1 }, { childB, 0 } })
			expect(logs).toEqual({
				{ id = "childA", ratio = 1 },
				{ id = "childB", ratio = 0 },
			})
			flushPostPaintCallbacks()
			expect(observedIds(observer)).toEqual({ "childA" })
		end
	)

	it(
		"unobserveUsing() releases deleted children that were waiting for an exit record",
		function()
			local observer = createMockObserver(function() end)
			local fragmentRef = React.createRef()
			local function Test(props)
				React.useEffect(function()
					fragmentRef.current:observeUsing(observer)
				end, {})
				return React.createElement(
					React.Fragment,
					{ ref = fragmentRef },
					React.createElement("Frame", { Name = "childA" }),
					if props.showB
						then React.createElement("Frame", { Name = "childB" })
						else nil
				)
			end
			act(function()
				root:render(React.createElement(Test, { showB = true }))
			end)
			act(function()
				root:render(React.createElement(Test, { showB = false }))
			end)
			expect(observedIds(observer)).toEqual({ "childA", "childB" })
			fragmentRef.current:unobserveUsing(observer)
			expect(observedIds(observer)).toEqual({})
		end
	)

	it("unobserves ResizeObserver targets as soon as a child is deleted", function()
		local observedTargets = {}
		local resizeObserver = {}
		function resizeObserver:observe(target)
			table.insert(observedTargets, target)
		end
		function resizeObserver:unobserve(target)
			local index = table.find(observedTargets, target)
			if index ~= nil then
				table.remove(observedTargets, index)
			end
		end
		local fragmentRef = React.createRef()
		local function Test(props)
			React.useEffect(function()
				fragmentRef.current:observeUsing(resizeObserver)
			end, {})
			return React.createElement(
				React.Fragment,
				{ ref = fragmentRef },
				React.createElement("Frame", { Name = "childA" }),
				if props.showB
					then React.createElement("Frame", { Name = "childB" })
					else nil
			)
		end
		local function names()
			local ids = {}
			for _, target in observedTargets do
				table.insert(ids, target.Name)
			end
			return ids
		end
		act(function()
			root:render(React.createElement(Test, { showB = true }))
		end)
		expect(names()).toEqual({ "childA", "childB" })
		act(function()
			root:render(React.createElement(Test, { showB = false }))
		end)
		expect(names()).toEqual({ "childA" })
	end)

	it(
		"unobserves a replaced child after post-paint and keeps the new child observed",
		function()
			local observer = createMockObserver(function() end)
			local fragmentRef = React.createRef()
			local childRef = React.createRef()
			local function Test(props)
				React.useEffect(function()
					fragmentRef.current:observeUsing(observer)
				end, {})
				return React.createElement(
					React.Fragment,
					{ ref = fragmentRef },
					if props.showChild
						then React.createElement(
							"Frame",
							{ Name = "child", ref = childRef }
						)
						else nil
				)
			end
			act(function()
				root:render(React.createElement(Test, { showChild = true }))
			end)
			local firstChild = childRef.current
			expect(observedIds(observer)).toEqual({ "child" })
			act(function()
				root:render(React.createElement(Test, { showChild = false }))
			end)
			expect(observedIds(observer)).toEqual({ "child" })
			expect(observer.observedTargets[1]).toBe(firstChild)
			act(function()
				root:render(React.createElement(Test, { showChild = true }))
			end)
			local secondChild = childRef.current
			expect(secondChild).never.toBe(firstChild)
			expect(#observer.observedTargets).toBe(2)
			expect(observer.observedTargets[1]).toBe(firstChild)
			expect(observer.observedTargets[2]).toBe(secondChild)
			flushPostPaintCallbacks()
			expect(#observer.observedTargets).toBe(1)
			expect(observer.observedTargets[1]).toBe(secondChild)
		end
	)

	it(
		"keeps a child observed if Activity shows it again before the delayed unobserve",
		function()
			local observer = createMockObserver(function() end)
			local fragmentRef = React.createRef()
			local function Test(props)
				React.useEffect(function()
					fragmentRef.current:observeUsing(observer)
				end, {})
				return React.createElement(
					React.Fragment,
					{ ref = fragmentRef },
					React.createElement(
						React.Activity,
						{ mode = props.mode },
						React.createElement("Frame", { Name = "child" })
					)
				)
			end
			act(function()
				root:render(React.createElement(Test, { mode = "visible" }))
			end)
			local child = container:FindFirstChild("child", true)
			expect(observedIds(observer)).toEqual({ "child" })
			act(function()
				root:render(React.createElement(Test, { mode = "hidden" }))
			end)
			-- ROBLOX DEVIATION: Activity detaches instead of display:none. The native
			-- observer boundary retains the same Instance while its parent is nil.
			expect(observer.observedTargets[1]).toBe(child)
			expect(observedIds(observer)).toEqual({ "child" })
			act(function()
				root:render(React.createElement(Test, { mode = "visible" }))
			end)
			expect(container:FindFirstChild("child", true)).toBe(child)
			expect(observedIds(observer)).toEqual({ "child" })
			flushPostPaintCallbacks()
			expect(observedIds(observer)).toEqual({ "child" })
		end
	)

	it(
		"warns when unobserveUsing() is called with an observer that was not observed",
		function()
			local fragmentRef = React.createRef()
			local observer = createMockObserver(function() end)
			local observer2 = createMockObserver(function() end)
			local function Test()
				return React.createElement(
					React.Fragment,
					{ ref = fragmentRef },
					React.createElement("Frame")
				)
			end
			act(function()
				root:render(React.createElement(Test))
			end)
			local warning = "You are calling unobserveUsing() with an observer that is not being observed with this fragment "
				.. "instance. First attach the observer with observeUsing()"
			-- ROBLOX DEVIATION: The Jest-Lua console matcher requires an explicit
			-- stack-less option for this imperative warning, like assertConsoleErrorDev.
			expect(function()
				fragmentRef.current:unobserveUsing(observer)
			end).toErrorDev(warning, { withoutStack = true })
			fragmentRef.current:observeUsing(observer)
			expect(function()
				fragmentRef.current:unobserveUsing(observer2)
			end).toErrorDev(warning, { withoutStack = true })
		end
	)

	it("attaches handles to observed elements to allow caching of observers", function()
		local targetToCallbackMap = setmetatable({}, { __mode = "k" })
		local cachedObserver = nil
		local function createObserverIfNeeded(fragmentInstance, onIntersection)
			local callbacks = targetToCallbackMap[fragmentInstance] or {}
			table.insert(callbacks, onIntersection)
			targetToCallbackMap[fragmentInstance] = callbacks
			if cachedObserver ~= nil then
				return cachedObserver
			end
			local observer = createMockObserver(function(entries)
				for _, entry in entries do
					-- ROBLOX DEVIATION: Instances cannot carry arbitrary object fields.
					-- The renderer exports the same handles through a weak registry.
					for _, fragment in ReactRoblox.getFragmentInstances(entry.target) do
						for _, callback in targetToCallbackMap[fragment] or {} do
							callback(entry)
						end
					end
					for _, callback in targetToCallbackMap[entry.target] or {} do
						callback(entry)
					end
				end
			end)
			cachedObserver = observer
			return observer
		end
		local function IntersectionObserverFragment(props)
			local fragmentRef = React.useRef(nil)
			React.useLayoutEffect(function()
				local observer =
					createObserverIfNeeded(fragmentRef.current, props.onIntersection)
				fragmentRef.current:observeUsing(observer)
				local lastRefValue = fragmentRef.current
				return function()
					lastRefValue:unobserveUsing(observer)
				end
			end, {})
			return React.createElement(
				React.Fragment,
				{ ref = fragmentRef },
				props.children
			)
		end
		local logs = {}
		local function logIntersection(id)
			table.insert(logs, "observe: " .. id)
		end
		local function ChildWithManualIO(props)
			local divRef = React.useRef(nil)
			React.useLayoutEffect(function()
				local observer = createObserverIfNeeded(divRef.current, function()
					logIntersection(props.id)
				end)
				observer:observe(divRef.current)
				return function()
					observer:unobserve(divRef.current)
				end
			end, {})
			return React.createElement("Frame", { Name = props.id, ref = divRef })
		end
		local function Test()
			return React.createElement(
				React.Fragment,
				nil,
				React.createElement(
					IntersectionObserverFragment,
					{
						onIntersection = function()
							logIntersection("grandparent")
						end,
					},
					React.createElement(IntersectionObserverFragment, {
						onIntersection = function()
							logIntersection("parentA")
						end,
					}, React.createElement("Frame", { Name = "childA" }))
				),
				React.createElement(
					IntersectionObserverFragment,
					{
						onIntersection = function()
							logIntersection("parentB")
						end,
					},
					React.createElement("Frame", { Name = "childB" }),
					React.createElement(ChildWithManualIO, { id = "childC" })
				)
			)
		end
		act(function()
			root:render(React.createElement(Test))
		end)
		cachedObserver:simulate({ { container:FindFirstChild("childA", true), 1 } })
		expect(logs).toEqual({ "observe: grandparent", "observe: parentA" })
		logs = {}
		cachedObserver:simulate({ { container:FindFirstChild("childB", true), 1 } })
		expect(logs).toEqual({ "observe: parentB" })
		logs = {}
		cachedObserver:simulate({ { container:FindFirstChild("childC", true), 1 } })
		expect(logs).toEqual({ "observe: parentB", "observe: childC" })
	end)
end)

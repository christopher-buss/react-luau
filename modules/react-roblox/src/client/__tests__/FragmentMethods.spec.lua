-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom/src/__tests__/ReactDOMFragmentRefs-test.js#L715-L837
-- ROBLOX DEVIATION: BindableEvent.Event substitutes native signal delivery for
-- DOM click dispatch. Engine signals have no bubbling or capture phases; host
-- callbacks receive the originating Instance before the native arguments.
-- ROBLOX DEVIATION: Native signals deliver connected handlers in engine order,
-- not DOM registration order. Compare callback membership, preserving emit order.

local Packages = script.Parent.Parent.Parent.Parent
local JestGlobals = require(Packages.Dev.JestGlobals)
local beforeEach = JestGlobals.beforeEach
local afterEach = JestGlobals.afterEach
local describe = JestGlobals.describe
local it = JestGlobals.it
local jest = JestGlobals.jest
local expect = JestGlobals.expect

local React
local ReactRoblox
local parent
local root

describe("FragmentRefs events", function()
	beforeEach(function()
		jest.resetModules()
		React = require(Packages.React)
		ReactRoblox = require(Packages.ReactRoblox)
		parent = Instance.new("Folder")
		root = ReactRoblox.createRoot(parent)
	end)

	afterEach(function()
		-- ROBLOX DEVIATION: Mirror the upstream container teardown without an
		-- added React unmount. Its rerender-only cleanup reads the current ref.
		parent:Destroy()
	end)

	it("adds and removes event listeners from children", function()
		local parentRef = React.createRef()
		local fragmentRef = React.createRef()
		local childARef = React.createRef()
		local childBRef = React.createRef()
		local logs = {}
		local function handleFragmentRefClicks()
			table.insert(logs, "fragmentRef")
		end
		local function Test()
			React.useEffect(function()
				local handle = fragmentRef.current
				handle:addEventListener("Event", handleFragmentRefClicks)
				return function()
					handle:removeEventListener("Event", handleFragmentRefClicks)
				end
			end, {})
			return React.createElement(
				"BindableEvent",
				{ ref = parentRef },
				React.createElement(
					React.Fragment,
					{ ref = fragmentRef },
					React.createElement("BindableEvent", { ref = childARef }),
					React.createElement(
						React.Fragment,
						nil,
						React.createElement("BindableEvent", { ref = childBRef })
					)
				)
			)
		end
		ReactRoblox.act(function()
			root:render(React.createElement(Test))
		end)
		childARef.current.Event:Connect(function()
			table.insert(logs, "A")
		end)
		childBRef.current.Event:Connect(function()
			table.insert(logs, "B")
		end)
		parentRef.current:Fire()
		task.wait()
		expect(logs).toEqual({})
		childARef.current:Fire()
		task.wait()
		table.sort(logs)
		expect(logs).toEqual({ "A", "fragmentRef" })
		logs = {}
		childBRef.current:Fire()
		task.wait()
		table.sort(logs)
		expect(logs).toEqual({ "B", "fragmentRef" })
		logs = {}
		fragmentRef.current:removeEventListener("Event", handleFragmentRefClicks)
		childARef.current:Fire()
		task.wait()
		expect(logs).toEqual({ "A" })
		logs = {}
		childBRef.current:Fire()
		task.wait()
		expect(logs).toEqual({ "B" })
	end)

	-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom/src/__tests__/ReactDOMFragmentRefs-test.js#L798-L837
	it(
		"regression: does not detach a registered listener when removing an unregistered one",
		function()
			local fragmentRef = React.createRef()
			local childRef = React.createRef()
			local logs = {}
			local function registeredListener()
				table.insert(logs, "registered")
			end
			local function unregisteredListener()
				table.insert(logs, "unregistered")
			end
			ReactRoblox.act(function()
				root:render(
					React.createElement(
						React.Fragment,
						{ ref = fragmentRef },
						React.createElement("BindableEvent", { ref = childRef })
					)
				)
			end)
			fragmentRef.current:addEventListener("Event", registeredListener)
			childRef.current:Fire()
			task.wait()
			expect(logs).toEqual({ "registered" })
			fragmentRef.current:removeEventListener("Event", unregisteredListener)
			logs = {}
			childRef.current:Fire()
			task.wait()
			expect(logs).toEqual({ "registered" })
			fragmentRef.current:removeEventListener("Event", registeredListener)
			logs = {}
			childRef.current:Fire()
			task.wait()
			expect(logs).toEqual({})
		end
	)

	-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom/src/__tests__/ReactDOMFragmentRefs-test.js#L880-L957
	-- ROBLOX DEVIATION: Native Event does not bubble from B to the outer host.
	-- The two sibling Fragment subscriptions on C remain independent.
	it(
		"adds and removes event listeners from children with multiple fragments",
		function()
			local fragmentRef = React.createRef()
			local nestedFragmentRef = React.createRef()
			local nestedFragmentRef2 = React.createRef()
			local childARef = React.createRef()
			local childBRef = React.createRef()
			local childCRef = React.createRef()
			ReactRoblox.act(function()
				root:render(
					React.createElement(
						"Folder",
						nil,
						React.createElement(
							React.Fragment,
							{ ref = fragmentRef },
							React.createElement("BindableEvent", { ref = childARef }),
							React.createElement(
								"Folder",
								nil,
								React.createElement(
									React.Fragment,
									{ ref = nestedFragmentRef },
									React.createElement(
										"BindableEvent",
										{ ref = childBRef }
									)
								)
							),
							React.createElement(
								React.Fragment,
								{ ref = nestedFragmentRef2 },
								React.createElement("BindableEvent", { ref = childCRef })
							)
						)
					)
				)
			end)
			local logs = {}
			local function handleFragmentRefClicks()
				table.insert(logs, "fragmentRef")
			end
			local function handleNestedFragmentRefClicks()
				table.insert(logs, "nestedFragmentRef")
			end
			local function handleNestedFragmentRef2Clicks()
				table.insert(logs, "nestedFragmentRef2")
			end
			fragmentRef.current:addEventListener("Event", handleFragmentRefClicks)
			nestedFragmentRef.current:addEventListener(
				"Event",
				handleNestedFragmentRefClicks
			)
			nestedFragmentRef2.current:addEventListener(
				"Event",
				handleNestedFragmentRef2Clicks
			)
			childBRef.current:Fire()
			task.wait()
			expect(logs).toEqual({ "nestedFragmentRef" })
			logs = {}
			childARef.current:Fire()
			task.wait()
			expect(logs).toEqual({ "fragmentRef" })
			logs = {}
			childCRef.current:Fire()
			task.wait()
			table.sort(logs)
			expect(logs).toEqual({ "fragmentRef", "nestedFragmentRef2" })
			logs = {}
			fragmentRef.current:removeEventListener("Event", handleFragmentRefClicks)
			nestedFragmentRef.current:removeEventListener(
				"Event",
				handleNestedFragmentRefClicks
			)
			childCRef.current:Fire()
			task.wait()
			expect(logs).toEqual({ "nestedFragmentRef2" })
		end
	)

	-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom/src/__tests__/ReactDOMFragmentRefs-test.js#L959-L1099
	it("adds an event listener to a newly added child", function()
		local fragmentRef = React.createRef()
		local childRef = React.createRef()
		local showChild
		local function Component()
			local shouldShowChild, setShouldShowChild = React.useState(false)
			showChild = function()
				setShouldShowChild(true)
			end
			return React.createElement(
				"Folder",
				nil,
				React.createElement(
					React.Fragment,
					{ ref = fragmentRef },
					React.createElement("BindableEvent", { Name = "a" }),
					if shouldShowChild
						then React.createElement(
							"BindableEvent",
							{ ref = childRef, Name = "b" }
						)
						else nil
				)
			)
		end
		ReactRoblox.act(function()
			root:render(React.createElement(Component))
		end)
		expect(fragmentRef.current).never.toBeNil()
		expect(childRef.current).toBeNil()
		local hasClicked = false
		fragmentRef.current:addEventListener("Event", function()
			hasClicked = true
		end)
		ReactRoblox.act(function()
			showChild()
		end)
		expect(childRef.current).never.toBeNil()
		childRef.current:Fire()
		task.wait()
		expect(hasClicked).toBe(true)
	end)

	it("fires a once listener only once across existing children", function()
		local fragmentRef = React.createRef()
		local childARef = React.createRef()
		local childBRef = React.createRef()
		ReactRoblox.act(function()
			root:render(
				React.createElement(
					"Folder",
					nil,
					React.createElement(
						React.Fragment,
						{ ref = fragmentRef },
						React.createElement(
							"BindableEvent",
							{ ref = childARef, Name = "a" }
						),
						React.createElement(
							"BindableEvent",
							{ ref = childBRef, Name = "b" }
						)
					)
				)
			)
		end)
		local logs = {}
		fragmentRef.current:addEventListener("Event", function()
			table.insert(logs, "once")
		end, { once = true })
		childARef.current:Fire()
		task.wait()
		expect(logs).toEqual({ "once" })
		logs = {}
		childBRef.current:Fire()
		task.wait()
		expect(logs).toEqual({})
	end)

	it("does not re-arm a once listener when a new child is inserted", function()
		local fragmentRef = React.createRef()
		local childARef = React.createRef()
		local childBRef = React.createRef()
		local showChildB
		local function Component()
			local shouldShowChildB, setShouldShowChildB = React.useState(false)
			showChildB = function()
				setShouldShowChildB(true)
			end
			return React.createElement(
				"Folder",
				nil,
				React.createElement(
					React.Fragment,
					{ ref = fragmentRef },
					React.createElement("BindableEvent", { ref = childARef, Name = "a" }),
					if shouldShowChildB
						then React.createElement(
							"BindableEvent",
							{ ref = childBRef, Name = "b" }
						)
						else nil
				)
			)
		end
		ReactRoblox.act(function()
			root:render(React.createElement(Component))
		end)
		local logs = {}
		fragmentRef.current:addEventListener("Event", function()
			table.insert(logs, "once")
		end, { once = true })
		childARef.current:Fire()
		task.wait()
		expect(logs).toEqual({ "once" })
		ReactRoblox.act(function()
			showChildB()
		end)
		logs = {}
		childBRef.current:Fire()
		task.wait()
		expect(logs).toEqual({})
	end)

	-- ROBLOX DEVIATION: This native cancellation boundary substitutes the
	-- AbortController test harness. subscribe uses colon and returns cleanup.
	local function cancellationController()
		local callbacks = {}
		local signal = { aborted = false }
		function signal:subscribe(callback)
			callbacks[callback] = true
			return function()
				callbacks[callback] = nil
			end
		end
		local function abort()
			signal.aborted = true
			for callback in callbacks do
				callback()
			end
		end
		return signal, abort
	end

	-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom/src/__tests__/ReactDOMFragmentRefs-test.js#L1101-L1215
	it(
		"should remove the listener when the signal is aborted before registration",
		function()
			local fragmentRef = React.createRef()
			local childRef = React.createRef()
			local logs = {}
			local function registeredListener()
				table.insert(logs, "registered")
			end
			ReactRoblox.act(function()
				root:render(
					React.createElement(
						React.Fragment,
						{ ref = fragmentRef },
						React.createElement("BindableEvent", { ref = childRef })
					)
				)
			end)
			local signal, abort = cancellationController()
			abort()
			fragmentRef.current:addEventListener(
				"Event",
				registeredListener,
				{ signal = signal }
			)
			childRef.current:Fire()
			task.wait()
			expect(logs).toEqual({})
			fragmentRef.current:addEventListener("Event", registeredListener)
			logs = {}
			childRef.current:Fire()
			task.wait()
			expect(logs).toEqual({ "registered" })
		end
	)

	it(
		"should remove the listener when the signal is aborted after registration",
		function()
			local fragmentRef = React.createRef()
			local childRef = React.createRef()
			local logs = {}
			local function registeredListener()
				table.insert(logs, "registered")
			end
			ReactRoblox.act(function()
				root:render(
					React.createElement(
						React.Fragment,
						{ ref = fragmentRef },
						React.createElement("BindableEvent", { ref = childRef })
					)
				)
			end)
			local signal, abort = cancellationController()
			fragmentRef.current:addEventListener(
				"Event",
				registeredListener,
				{ signal = signal }
			)
			childRef.current:Fire()
			task.wait()
			expect(logs).toEqual({ "registered" })
			logs = {}
			abort()
			childRef.current:Fire()
			task.wait()
			expect(logs).toEqual({})
			fragmentRef.current:addEventListener("Event", registeredListener)
			logs = {}
			childRef.current:Fire()
			task.wait()
			expect(logs).toEqual({ "registered" })
		end
	)

	it(
		"should NOT remove the new subscription when the signal for the old subscription is aborted",
		function()
			local fragmentRef = React.createRef()
			local childRef = React.createRef()
			local logs = {}
			local function registeredListener()
				table.insert(logs, "registered")
			end
			ReactRoblox.act(function()
				root:render(
					React.createElement(
						React.Fragment,
						{ ref = fragmentRef },
						React.createElement("BindableEvent", { ref = childRef })
					)
				)
			end)
			local signal, abort = cancellationController()
			fragmentRef.current:addEventListener(
				"Event",
				registeredListener,
				{ signal = signal }
			)
			childRef.current:Fire()
			task.wait()
			expect(logs).toEqual({ "registered" })
			fragmentRef.current:removeEventListener("Event", registeredListener)
			logs = {}
			childRef.current:Fire()
			task.wait()
			expect(logs).toEqual({})
			fragmentRef.current:addEventListener("Event", registeredListener)
			logs = {}
			childRef.current:Fire()
			task.wait()
			expect(logs).toEqual({ "registered" })
			logs = {}
			abort()
			childRef.current:Fire()
			task.wait()
			expect(logs).toEqual({ "registered" })
		end
	)

	-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom/src/__tests__/ReactDOMFragmentRefs-test.js#L1314-L1425
	it(
		"applies event listeners to host children nested within non-host children",
		function()
			local fragmentRef = React.createRef()
			local childRef = React.createRef()
			local nestedChildRef = React.createRef()
			local function Wrapper(props)
				return props.children
			end
			ReactRoblox.act(function()
				root:render(
					React.createElement(
						"Folder",
						nil,
						React.createElement(
							React.Fragment,
							{ ref = fragmentRef },
							React.createElement(
								"BindableEvent",
								{ ref = childRef, Name = "Host A" }
							),
							React.createElement(
								Wrapper,
								nil,
								React.createElement(
									Wrapper,
									nil,
									React.createElement(
										Wrapper,
										nil,
										React.createElement(
											"BindableEvent",
											{ ref = nestedChildRef, Name = "Host B" }
										)
									)
								)
							)
						)
					)
				)
			end)
			local logs = {}
			fragmentRef.current:addEventListener("Event", function(host)
				table.insert(logs, host.Name)
			end)
			expect(logs).toEqual({})
			childRef.current:Fire()
			task.wait()
			expect(logs).toEqual({ "Host A" })
			nestedChildRef.current:Fire()
			task.wait()
			expect(logs).toEqual({ "Host A", "Host B" })
		end
	)

	it("allows adding and cleaning up listeners in effects", function()
		local logs = {}
		local function logClick(host)
			table.insert(logs, host.Name)
		end
		local rerender
		local childRef = React.createRef()
		local removeEventListeners
		local function Test()
			local fragmentRef = React.useRef(nil)
			local _, setState = React.useState(0)
			rerender = function()
				setState(function(state)
					return state + 1
				end)
			end
			removeEventListeners = function()
				fragmentRef.current:removeEventListener("Event", logClick)
			end
			React.useEffect(function()
				fragmentRef.current:addEventListener("Event", logClick)
				return removeEventListeners
			end)
			return React.createElement(
				React.Fragment,
				{ ref = fragmentRef },
				React.createElement("BindableEvent", { ref = childRef, Name = "child-a" })
			)
		end
		ReactRoblox.act(function()
			root:render(React.createElement(Test))
		end)
		expect(logs).toEqual({})
		childRef.current:Fire()
		task.wait()
		expect(logs).toEqual({ "child-a" })
		logs = {}
		ReactRoblox.act(rerender)
		childRef.current:Fire()
		task.wait()
		expect(logs).toEqual({ "child-a" })
	end)

	it("does not apply removed event listeners to new children", function()
		local fragmentRef = React.createRef()
		local childRef = React.createRef()
		local function Test()
			return React.createElement(
				React.Fragment,
				{ ref = fragmentRef },
				React.createElement("BindableEvent", { ref = childRef, Name = "child-a" })
			)
		end
		local logs = {}
		local function logClick(host)
			table.insert(logs, host.Name)
		end
		ReactRoblox.act(function()
			root:render(React.createElement(Test))
		end)
		fragmentRef.current:addEventListener("Event", logClick)
		local childA = childRef.current
		childA:Fire()
		task.wait()
		expect(logs).toEqual({ "child-a" })
		logs = {}
		fragmentRef.current:removeEventListener("Event", logClick)
		childA:Fire()
		task.wait()
		expect(logs).toEqual({})
	end)

	-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom/src/__tests__/ReactDOMFragmentRefs-test.js#L1501-L1585
	it("applies event listeners to portaled children", function()
		local fragmentRef = React.createRef()
		local childARef = React.createRef()
		local childBRef = React.createRef()
		local portal = Instance.new("Folder")
		local function Test()
			return React.createElement(
				React.Fragment,
				{ ref = fragmentRef },
				React.createElement(
					"BindableEvent",
					{ ref = childARef, Name = "child-a" }
				),
				ReactRoblox.createPortal(
					React.createElement(
						"BindableEvent",
						{ ref = childBRef, Name = "child-b" }
					),
					portal
				)
			)
		end
		ReactRoblox.act(function()
			root:render(React.createElement(Test))
		end)
		local logs = {}
		fragmentRef.current:addEventListener("Event", function(host)
			table.insert(logs, host.Name)
		end)
		childARef.current:Fire()
		task.wait()
		expect(logs).toEqual({ "child-a" })
		logs = {}
		childBRef.current:Fire()
		task.wait()
		expect(logs).toEqual({ "child-b" })
		ReactRoblox.act(function()
			root:unmount()
		end)
		portal:Destroy()
	end)

	it("applies event listeners to children portaled in after registration", function()
		local fragmentRef = React.createRef()
		local childARef = React.createRef()
		local childBRef = React.createRef()
		local portal = Instance.new("Folder")
		local showChildB
		local function Test()
			local shouldShowChildB, setShouldShowChildB = React.useState(false)
			showChildB = function()
				setShouldShowChildB(true)
			end
			return React.createElement(
				React.Fragment,
				{ ref = fragmentRef },
				ReactRoblox.createPortal(
					React.createElement(
						React.Fragment,
						nil,
						React.createElement(
							"BindableEvent",
							{ ref = childARef, Name = "child-a" }
						),
						if shouldShowChildB
							then React.createElement(
								"BindableEvent",
								{ ref = childBRef, Name = "child-b" }
							)
							else nil
					),
					portal
				)
			)
		end
		ReactRoblox.act(function()
			root:render(React.createElement(Test))
		end)
		local logs = {}
		fragmentRef.current:addEventListener("Event", function(host)
			table.insert(logs, host.Name)
		end)
		childARef.current:Fire()
		task.wait()
		expect(logs).toEqual({ "child-a" })
		ReactRoblox.act(function()
			showChildB()
		end)
		logs = {}
		childBRef.current:Fire()
		task.wait()
		expect(logs).toEqual({ "child-b" })
		ReactRoblox.act(function()
			root:unmount()
		end)
		portal:Destroy()
	end)

	-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom/src/__tests__/ReactDOMFragmentRefs-test.js#L1587-L1711
	describe("with activity", function()
		-- ROBLOX DEVIATION: Hidden Roblox hosts are detached, so parent children
		-- expose only the visible signal targets; initially hidden refs are unset.
		it("does not apply event listeners to hidden trees", function()
			local parentRef = React.createRef()
			local fragmentRef = React.createRef()
			local function Test()
				return React.createElement(
					"Folder",
					{ ref = parentRef },
					React.createElement(
						React.Fragment,
						{ ref = fragmentRef },
						React.createElement("BindableEvent", { Name = "Child 1" }),
						React.createElement(
							React.Activity,
							{ mode = "hidden" },
							React.createElement("BindableEvent", { Name = "Child 2" })
						),
						React.createElement("BindableEvent", { Name = "Child 3" })
					)
				)
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			local logs = {}
			fragmentRef.current:addEventListener("Event", function(host)
				table.insert(logs, host.Name)
			end)
			local child1 = parentRef.current:FindFirstChild("Child 1")
			local child3 = parentRef.current:FindFirstChild("Child 3")
			child1:Fire()
			child3:Fire()
			task.wait()
			expect(logs).toEqual({ "Child 1", "Child 3" })
		end)

		it("applies event listeners to visible trees", function()
			local parentRef = React.createRef()
			local fragmentRef = React.createRef()
			local function Test()
				return React.createElement(
					"Folder",
					{ ref = parentRef },
					React.createElement(
						React.Fragment,
						{ ref = fragmentRef },
						React.createElement("BindableEvent", { Name = "Child 1" }),
						React.createElement(
							React.Activity,
							{ mode = "visible" },
							React.createElement("BindableEvent", { Name = "Child 2" })
						),
						React.createElement("BindableEvent", { Name = "Child 3" })
					)
				)
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			local logs = {}
			fragmentRef.current:addEventListener("Event", function(host)
				table.insert(logs, host.Name)
			end)
			parentRef.current:FindFirstChild("Child 1"):Fire()
			parentRef.current:FindFirstChild("Child 2"):Fire()
			parentRef.current:FindFirstChild("Child 3"):Fire()
			task.wait()
			expect(logs).toEqual({ "Child 1", "Child 2", "Child 3" })
		end)

		it("handles Activity modes switching", function()
			local fragmentRef = React.createRef()
			local fragmentRef2 = React.createRef()
			local parentRef = React.createRef()
			local child1Ref = React.createRef()
			local child2Ref = React.createRef()
			local function Test(props)
				return React.createElement(
					"Folder",
					{ ref = parentRef },
					React.createElement(
						React.Fragment,
						{ ref = fragmentRef },
						React.createElement(
							React.Activity,
							{ mode = props.mode },
							React.createElement(
								"BindableEvent",
								{ ref = child1Ref, Name = "child1" }
							),
							React.createElement(
								React.Fragment,
								{ ref = fragmentRef2 },
								React.createElement(
									"BindableEvent",
									{ ref = child2Ref, Name = "child2" }
								)
							)
						)
					)
				)
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test, { mode = "visible" }))
			end)
			local logs = {}
			fragmentRef.current:addEventListener("Event", function()
				table.insert(logs, "clicked 1")
			end)
			fragmentRef2.current:addEventListener("Event", function()
				table.insert(logs, "clicked 2")
			end)
			local child1 = child1Ref.current
			local child2 = child2Ref.current
			child2:Fire()
			task.wait()
			table.sort(logs)
			expect(logs).toEqual({ "clicked 1", "clicked 2" })
			logs = {}
			ReactRoblox.act(function()
				root:render(React.createElement(Test, { mode = "hidden" }))
			end)
			child1:Fire()
			child2:Fire()
			task.wait()
			expect(logs).toEqual({})
			logs = {}
			ReactRoblox.act(function()
				root:render(React.createElement(Test, { mode = "visible" }))
			end)
			child2:Fire()
			task.wait()
			table.sort(logs)
			expect(logs).toEqual({ "clicked 1", "clicked 2" })
		end)
	end)
end)

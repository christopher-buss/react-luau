-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom/src/__tests__/ReactDOMFragmentRefs-test.js#L32-L121
-- ROBLOX DEVIATION: ReactRoblox roots and Folder/TextLabel hosts replace DOM;
-- synchronous act and explicit imports replace the JavaScript test harness.
local Packages = script.Parent.Parent.Parent
local JestGlobals = require(Packages.Dev.JestGlobals)
local describe = JestGlobals.describe
local beforeEach = JestGlobals.beforeEach
local afterEach = JestGlobals.afterEach
local it = JestGlobals.it
local jest = JestGlobals.jest
local expect = JestGlobals.expect

local React
local ReactRoblox
local act
local container
local Scheduler

describe("FragmentRefs", function()
	beforeEach(function()
		jest.resetModules()
		jest.useFakeTimers()
		React = require(Packages.React)
		ReactRoblox = require(Packages.ReactRoblox)
		act = ReactRoblox.act
		Scheduler = require(Packages.Scheduler)
		container = Instance.new("Folder")
		container.Parent = workspace
	end)

	afterEach(function()
		container:Destroy()
	end)

	it("attaches a ref to Fragment", function()
		local fragmentRef = React.createRef()
		local root = ReactRoblox.createRoot(container)
		act(function()
			root:render(
				React.createElement(
					"Folder",
					{ Name = "parent" },
					React.createElement(
						React.Fragment,
						{ ref = fragmentRef },
						React.createElement("TextLabel", { Name = "child", Text = "Hi" })
					)
				)
			)
		end)
		local parent = container:GetChildren()[1]
		expect(parent.Name).toBe("parent")
		expect(#parent:GetChildren()).toBe(1)
		expect(parent:GetChildren()[1].Text).toBe("Hi")
		expect(fragmentRef.current).never.toBeNil()
	end)

	it("accepts a ref callback", function()
		local fragmentRef
		local root = ReactRoblox.createRoot(container)
		act(function()
			root:render(React.createElement(React.Fragment, {
				ref = function(ref)
					fragmentRef = ref
				end,
			}, React.createElement("TextLabel", { Name = "child", Text = "Hi" })))
		end)
		expect(fragmentRef._fragmentFiber).toBeTruthy()
	end)

	it("is available in effects", function()
		local function Test()
			local fragmentRef = React.useRef(nil)
			React.useLayoutEffect(function()
				expect(fragmentRef.current).never.toBeNil()
			end)
			React.useEffect(function()
				expect(fragmentRef.current).never.toBeNil()
			end)
			return React.createElement(
				React.Fragment,
				{ ref = fragmentRef },
				React.createElement("Folder")
			)
		end
		local root = ReactRoblox.createRoot(container)
		act(function()
			root:render(React.createElement(Test))
		end)
	end)

	-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom/src/__tests__/ReactDOMFragmentRefs-test.js#L165-L222
	-- ROBLOX DEVIATION: Scheduler yield assertions replace assertLog.
	it("runs the ref cleanup when an inline ref callback changes identity", function()
		local fragmentInstances = {}
		local rerender
		local function Test()
			local step, setStep = React.useState(0)
			rerender = function()
				setStep(function(previous)
					return previous + 1
				end)
			end
			return React.createElement(
				React.Fragment,
				{
					ref = function(fragmentInstance)
						table.insert(fragmentInstances, fragmentInstance)
						Scheduler.unstable_yieldValue("fragment attach " .. step)
						return function()
							Scheduler.unstable_yieldValue("fragment cleanup " .. step)
						end
					end,
				},
				React.createElement("Folder", {
					Name = "child",
					ref = function()
						Scheduler.unstable_yieldValue("host attach " .. step)
						return function()
							Scheduler.unstable_yieldValue("host cleanup " .. step)
						end
					end,
				})
			)
		end
		local root = ReactRoblox.createRoot(container)
		act(function()
			root:render(React.createElement(Test))
		end)
		expect(Scheduler).toHaveYielded({ "fragment attach 0", "host attach 0" })
		act(rerender)
		expect(Scheduler).toHaveYielded({
			"fragment cleanup 0",
			"host cleanup 0",
			"fragment attach 1",
			"host attach 1",
		})
		act(function()
			root:render(nil)
		end)
		expect(Scheduler).toHaveYielded({ "fragment cleanup 1", "host cleanup 1" })
		expect(fragmentInstances).toHaveLength(2)
		expect(fragmentInstances[1]).toBe(fragmentInstances[2])
	end)

	-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom/src/__tests__/ReactDOMFragmentRefs-test.js#L224-L257
	it("runs the ref cleanup when the ref is removed from a mounted Fragment", function()
		local function Test(props)
			return React.createElement(React.Fragment, {
				ref = if props.withRef
					then function()
						Scheduler.unstable_yieldValue("attach")
						return function()
							Scheduler.unstable_yieldValue("cleanup")
						end
					end
					else nil,
			}, React.createElement("Folder", { Name = "child" }))
		end
		local root = ReactRoblox.createRoot(container)
		act(function()
			root:render(React.createElement(Test, { withRef = true }))
		end)
		expect(Scheduler).toHaveYielded({ "attach" })
		act(function()
			root:render(React.createElement(Test, { withRef = false }))
		end)
		expect(Scheduler).toHaveYielded({ "cleanup" })
		act(function()
			root:render(nil)
		end)
		expect(Scheduler).toHaveYielded({})
	end)

	-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom/src/__tests__/ReactDOMFragmentRefs-test.js#L259-L311
	it("detaches and reattaches Fragment refs when StrictMode double invokes", function()
		local logs = {}
		local rerender
		local function Test()
			local step, setStep = React.useState(0)
			rerender = function()
				setStep(function(previous)
					return previous + 1
				end)
			end
			return React.createElement(React.Fragment, {
				ref = function()
					table.insert(logs, "attach " .. step)
					return function()
						table.insert(logs, "cleanup " .. step)
					end
				end,
			}, React.createElement("Folder", { Name = "child" }))
		end
		local root = ReactRoblox.createRoot(container)
		act(function()
			root:render(
				React.createElement(React.StrictMode, nil, React.createElement(Test))
			)
		end)
		if require(Packages.ReactGlobals).__DEV__ then
			expect(logs).toEqual({ "attach 0", "cleanup 0", "attach 0" })
		else
			expect(logs).toEqual({ "attach 0" })
		end
		table.clear(logs)
		act(rerender)
		expect(logs).toEqual({ "cleanup 0", "attach 1" })
	end)

	-- ROBLOX DEVIATION: Adapter regression exercises prior-hidden deletion in
	-- React-Luau's recursive commit walk through its public Activity boundary.
	it("cleans up a hidden Fragment callback only once before deletion", function()
		local logs = {}
		local function ref(handle)
			if handle == nil then
				table.insert(logs, "detach")
				return nil
			end
			table.insert(logs, "attach")
			return function()
				table.insert(logs, "cleanup")
			end
		end
		local function element(mode)
			return React.createElement(
				React.Activity,
				{ mode = mode },
				React.createElement(
					React.Fragment,
					{ ref = ref },
					React.createElement("Folder")
				)
			)
		end
		local root = ReactRoblox.createRoot(container)
		act(function()
			root:render(element("visible"))
		end)
		expect(logs).toEqual({ "attach" })
		act(function()
			root:render(element("hidden"))
		end)
		expect(logs).toEqual({ "attach", "cleanup" })
		act(function()
			root:unmount()
		end)
		expect(logs).toEqual({ "attach", "cleanup" })
	end)

	-- ROBLOX DEVIATION: Adapter regression covers React-Luau's keyed collection
	-- reconciliation paths, which differ from upstream JavaScript child arrays.
	it("updates callback refs on keyed Fragments in child collections", function()
		local logs = {}
		local handles = {}
		local function element(step)
			return React.createElement("Folder", nil, {
				React.createElement("Folder", { key = "before" }),
				React.createElement(React.Fragment, {
					key = "group",
					ref = function(handle)
						table.insert(handles, handle)
						table.insert(logs, "attach " .. step)
						return function()
							table.insert(logs, "cleanup " .. step)
						end
					end,
				}, React.createElement("Folder")),
				React.createElement("Folder", { key = "after" }),
			})
		end
		local root = ReactRoblox.createRoot(container)
		act(function()
			root:render(element(0))
		end)
		expect(logs).toEqual({ "attach 0" })
		table.clear(logs)
		act(function()
			root:render(element(1))
		end)
		expect(logs).toEqual({ "cleanup 0", "attach 1" })
		expect(handles[1]).toBe(handles[2])
	end)
end)

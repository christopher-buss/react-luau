-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom/src/__tests__/ReactDOMFragmentRefs-test.js#L125-L162
-- ROBLOX DEVIATION: Instances cannot store a reactFragments field. The public
-- renderer lookup returns a frozen membership snapshot instead of a live Set.
local Packages = script.Parent.Parent.Parent.Parent
local JestGlobals = require(Packages.Dev.JestGlobals)
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach
local describe, it, expect, jest =
	JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.jest
local React, ReactRoblox, parent, root
describe("FragmentRefs membership", function()
	beforeEach(function()
		jest.resetModules()
		React = require(Packages.React)
		ReactRoblox = require(Packages.ReactRoblox)
		parent = Instance.new("Folder")
		root = ReactRoblox.createRoot(parent)
	end)
	afterEach(function()
		ReactRoblox.act(function()
			root:unmount()
		end)
		parent:Destroy()
	end)
	it("attaches fragment handles to nodes", function()
		local fragmentParentRef = React.createRef()
		local fragmentRef = React.createRef()
		local function Test(props)
			return React.createElement(
				React.Fragment,
				{ ref = fragmentParentRef },
				React.createElement(
					React.Fragment,
					{ ref = fragmentRef },
					React.createElement("Folder", { Name = "childA" }),
					React.createElement("Folder", { Name = "childB" })
				),
				React.createElement("Folder", { Name = "childC" }),
				if props.show
					then React.createElement("Folder", { Name = "childD" })
					else nil
			)
		end
		ReactRoblox.act(function()
			root:render(React.createElement(Test, { show = false }))
		end)
		local childA = parent:FindFirstChild("childA")
		local childB = parent:FindFirstChild("childB")
		local childC = parent:FindFirstChild("childC")
		expect(
			table.find(ReactRoblox.getFragmentInstances(childA), fragmentRef.current)
				~= nil
		).toBe(true)
		expect(
			table.find(ReactRoblox.getFragmentInstances(childB), fragmentRef.current)
				~= nil
		).toBe(true)
		expect(
			table.find(ReactRoblox.getFragmentInstances(childC), fragmentRef.current)
				~= nil
		).toBe(false)
		expect(
			table.find(
				ReactRoblox.getFragmentInstances(childA),
				fragmentParentRef.current
			) ~= nil
		).toBe(true)
		expect(
			table.find(
				ReactRoblox.getFragmentInstances(childB),
				fragmentParentRef.current
			) ~= nil
		).toBe(true)
		expect(
			table.find(
				ReactRoblox.getFragmentInstances(childC),
				fragmentParentRef.current
			) ~= nil
		).toBe(true)
		ReactRoblox.act(function()
			root:render(React.createElement(Test, { show = true }))
		end)
		local childD = parent:FindFirstChild("childD")
		expect(
			table.find(ReactRoblox.getFragmentInstances(childD), fragmentRef.current)
				~= nil
		).toBe(false)
		expect(
			table.find(
				ReactRoblox.getFragmentInstances(childD),
				fragmentParentRef.current
			) ~= nil
		).toBe(true)
	end)

	-- ROBLOX DEVIATION: This regression covers private native ownership disposal,
	-- not an additional React reconciliation contract.
	it(
		"releases reverse ownership and cancellation when a retained handle is deleted",
		function()
			local fragmentRef = React.createRef()
			local childRef = React.createRef()
			local released = false
			local signal = { aborted = false }
			function signal:subscribe(_callback)
				return function()
					released = true
				end
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
			local handle = fragmentRef.current
			local child = childRef.current
			handle:addEventListener("Event", function()
				error("deleted event delivered")
			end, { signal = signal })
			local snapshot = ReactRoblox.getFragmentInstances(child)
			ReactRoblox.act(function()
				root:render(nil)
			end)
			expect(released).toBe(true)
			expect(ReactRoblox.getFragmentInstances(child)).toEqual({})
			expect(snapshot).toEqual({ handle })
			expect(table.isfrozen(snapshot)).toBe(true)
		end
	)
end)

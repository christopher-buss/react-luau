-- ROBLOX DEVIATION: These renderer regressions cover native signal ownership
-- and the external cancellation adapter, which are absent from the DOM suite.
local Packages = script.Parent.Parent.Parent.Parent
local JestGlobals = require(Packages.Dev.JestGlobals)
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach
local describe, it, expect, jest =
	JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.jest
local React, ReactRoblox, parent, root, fragmentRef, firstRef, secondRef
describe("Fragment native event ownership", function()
	beforeEach(function()
		jest.resetModules()
		React = require(Packages.React)
		ReactRoblox = require(Packages.ReactRoblox)
		parent = Instance.new("Folder")
		root = ReactRoblox.createRoot(parent)
		fragmentRef = React.createRef()
		firstRef = React.createRef()
		secondRef = React.createRef()
		ReactRoblox.act(function()
			root:render(
				React.createElement(
					React.Fragment,
					{ ref = fragmentRef },
					React.createElement("BindableEvent", { ref = firstRef }),
					React.createElement("BindableEvent", { ref = secondRef })
				)
			)
		end)
	end)
	afterEach(function()
		ReactRoblox.act(function()
			root:unmount()
		end)
		parent:Destroy()
	end)
	it("permits re-registration after the cancellation boundary throws", function()
		local logs = {}
		local function listener(host, value)
			table.insert(logs, { host, value })
		end
		local signal = { aborted = false }
		function signal:subscribe(_callback)
			error("cancellation boundary failed")
		end
		expect(function()
			fragmentRef.current:addEventListener("Event", listener, { signal = signal })
		end).toThrow("cancellation boundary failed")
		fragmentRef.current:addEventListener("Event", listener)
		firstRef.current:Fire("restored")
		task.wait()
		expect(logs).toEqual({ { firstRef.current, "restored" } })
	end)

	it("preserves a reentrant replacement when cancellation subscribe throws", function()
		local logs = {}
		local function listener(_host, value)
			table.insert(logs, value)
		end
		local signal = { aborted = false }
		function signal:subscribe(callback)
			callback()
			fragmentRef.current:addEventListener("Event", listener)
			error("replacement boundary failed")
		end
		expect(function()
			fragmentRef.current:addEventListener("Event", listener, { signal = signal })
		end).toThrow("replacement boundary failed")
		firstRef.current:Fire("replacement")
		task.wait()
		expect(logs).toEqual({ "replacement" })
	end)
	it(
		"consumes a once registration before its callback emits another child signal",
		function()
			local logs = {}
			fragmentRef.current:addEventListener("Event", function(host)
				table.insert(logs, host)
				secondRef.current:Fire()
			end, { once = true })
			firstRef.current:Fire()
			task.wait()
			expect(logs).toEqual({ firstRef.current })
		end
	)

	it(
		"ignores a stale cancellation delivery after the listener is re-registered",
		function()
			local logs = {}
			local function listener(_host, value)
				table.insert(logs, value)
			end
			local pendingAbort
			local unsubscribed = false
			local signal = { aborted = false }
			function signal:subscribe(callback)
				pendingAbort = callback
				return function()
					unsubscribed = true
				end
			end
			fragmentRef.current:addEventListener("Event", listener, { signal = signal })
			fragmentRef.current:removeEventListener("Event", listener)
			expect(unsubscribed).toBe(true)
			fragmentRef.current:addEventListener("Event", listener)
			pendingAbort()
			firstRef.current:Fire("new")
			task.wait()
			expect(logs).toEqual({ "new" })
		end
	)
end)

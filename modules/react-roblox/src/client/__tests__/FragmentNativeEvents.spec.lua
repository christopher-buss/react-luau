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
	it("finishes native deletion when an external cancellation cleanup throws", function()
		local fragment = fragmentRef.current
		local firstHost, secondHost = firstRef.current, secondRef.current
		local secondReleased = false
		local delivered = false
		local firstSignal = { aborted = false }
		function firstSignal:subscribe(_callback)
			return function()
				error("cancellation cleanup failed")
			end
		end
		local secondSignal = { aborted = false }
		function secondSignal:subscribe(_callback)
			return function()
				secondReleased = true
			end
		end
		fragment:addEventListener("Event", function()
			delivered = true
		end, { signal = firstSignal })
		fragment:addEventListener("Event", function()
			delivered = true
		end, { signal = secondSignal })
		expect(function()
			ReactRoblox.act(function()
				root:render(nil)
			end)
		end).toThrow("cancellation cleanup failed")
		expect(secondReleased).toBe(true)
		expect(parent:GetChildren()).toEqual({})
		expect(ReactRoblox.getFragmentInstances(firstHost)).toEqual({})
		expect(ReactRoblox.getFragmentInstances(secondHost)).toEqual({})
		firstHost:Fire()
		secondHost:Fire()
		task.wait()
		expect(delivered).toBe(false)
	end)
	it("finishes observer deletion when an external release hook throws", function()
		ReactRoblox.act(function()
			root:render(
				React.createElement(
					React.Fragment,
					{ ref = fragmentRef },
					React.createElement("Frame", { ref = firstRef }),
					React.createElement("Frame", { ref = secondRef })
				)
			)
		end)
		local fragment = fragmentRef.current
		local firstHost, secondHost = firstRef.current, secondRef.current
		local observed = {}
		local firstRemoval = true
		local observer = {}
		function observer:observe(target)
			observed[target] = true
		end
		function observer:unobserve(target)
			observed[target] = nil
			if firstRemoval then
				firstRemoval = false
				error("target cleanup failed")
			end
		end
		function observer:unobserveAfterExit(target)
			self:unobserve(target)
		end
		function observer:releaseOwner(_owner)
			for target in observed do
				self:unobserve(target)
			end
		end
		function observer:releaseOwnerAfterExit(_owner)
			error("observer release failed")
		end
		local otherObserved = {}
		local otherObserver = {}
		function otherObserver:observe(target)
			otherObserved[target] = true
		end
		function otherObserver:unobserve(target)
			otherObserved[target] = nil
		end
		fragment:observeUsing(observer)
		fragment:observeUsing(otherObserver)
		expect(function()
			ReactRoblox.act(function()
				root:render(nil)
			end)
		end).toThrow("observer release failed")
		expect(observed).toEqual({})
		expect(otherObserved).toEqual({})
		expect(parent:GetChildren()).toEqual({})
		expect(ReactRoblox.getFragmentInstances(firstHost)).toEqual({})
		expect(ReactRoblox.getFragmentInstances(secondHost)).toEqual({})
	end)
	it("finishes removing a child when an external observer cleanup throws", function()
		local function render(showFirst)
			root:render(
				React.createElement(
					React.Fragment,
					{ ref = fragmentRef },
					if showFirst
						then React.createElement(
							"Frame",
							{ key = "first", ref = firstRef }
						)
						else nil,
					React.createElement("Frame", { key = "second", ref = secondRef })
				)
			)
		end
		ReactRoblox.act(function()
			render(true)
		end)
		local firstHost = firstRef.current
		local observed = {}
		local observer = {}
		function observer:observe(target)
			observed[target] = true
		end
		function observer:unobserve(target)
			observed[target] = nil
			if target == firstHost then
				error("removed child cleanup failed")
			end
		end
		fragmentRef.current:observeUsing(observer)
		expect(function()
			ReactRoblox.act(function()
				render(false)
			end)
		end).toThrow("removed child cleanup failed")
		expect(firstHost.Parent).toBeNil()
		expect(ReactRoblox.getFragmentInstances(firstHost)).toEqual({})
		expect(observed).toEqual({})
	end)
	it("finishes hiding nested Fragment children when observer cleanup throws", function()
		local innerRef = React.createRef()
		local function render(mode)
			root:render(
				React.createElement(
					React.Fragment,
					{ ref = fragmentRef },
					React.createElement(
						React.Activity,
						{ mode = mode },
						React.createElement(
							React.Fragment,
							{ ref = innerRef },
							React.createElement("Frame", { ref = firstRef }),
							React.createElement("Frame", { ref = secondRef })
						)
					)
				)
			)
		end
		ReactRoblox.act(function()
			render("visible")
		end)
		local firstHost, secondHost = firstRef.current, secondRef.current
		local ownedTargets = {}
		local observer = {}
		local firstRemoval = true
		local stateBeforeRecovery
		function observer:observe(target, owner)
			ownedTargets[owner] = ownedTargets[owner] or {}
			ownedTargets[owner][target] = true
		end
		function observer:unobserve(target, owner)
			ownedTargets[owner][target] = nil
			if firstRemoval then
				firstRemoval = false
				error("hidden child cleanup failed")
			end
		end
		function observer:releaseOwner(owner)
			ownedTargets[owner] = {}
		end
		function observer:releaseOwnerAfterExit(owner)
			if stateBeforeRecovery == nil then
				stateBeforeRecovery = {
					firstHidden = firstHost.Parent == nil,
					secondHidden = secondHost.Parent == nil,
					firstMembership = #ReactRoblox.getFragmentInstances(firstHost),
					secondMembership = #ReactRoblox.getFragmentInstances(secondHost),
				}
			end
			self:releaseOwner(owner)
		end
		local outerHandle, innerHandle = fragmentRef.current, innerRef.current
		outerHandle:observeUsing(observer)
		innerHandle:observeUsing(observer)
		expect(function()
			ReactRoblox.act(function()
				render("hidden")
			end)
		end).toThrow("hidden child cleanup failed")
		expect(stateBeforeRecovery).toEqual({
			firstHidden = true,
			secondHidden = true,
			firstMembership = 0,
			secondMembership = 0,
		})
		expect(firstHost.Parent).toBeNil()
		expect(secondHost.Parent).toBeNil()
		expect(ReactRoblox.getFragmentInstances(firstHost)).toEqual({})
		expect(ReactRoblox.getFragmentInstances(secondHost)).toEqual({})
		expect(ownedTargets[outerHandle]).toEqual({})
		expect(ownedTargets[innerHandle]).toEqual({})
	end)
	it("finishes manual observer removal when a target cleanup throws", function()
		ReactRoblox.act(function()
			root:render(
				React.createElement(
					React.Fragment,
					{ ref = fragmentRef },
					React.createElement("Frame", { ref = firstRef }),
					React.createElement("Frame", { ref = secondRef })
				)
			)
		end)
		local observed = {}
		local firstRemoval = true
		local ownerReleased = false
		local observer = {}
		function observer:observe(target)
			observed[target] = true
		end
		function observer:unobserve(target)
			observed[target] = nil
			if firstRemoval then
				firstRemoval = false
				error("manual target cleanup failed")
			end
		end
		function observer:releaseOwner(_owner)
			ownerReleased = true
		end
		fragmentRef.current:observeUsing(observer)
		expect(function()
			fragmentRef.current:unobserveUsing(observer)
		end).toThrow("manual target cleanup failed")
		expect(observed).toEqual({})
		expect(ownerReleased).toBe(true)
		expect(#parent:GetChildren()).toBe(2)
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

--!strict
-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom-bindings/src/client/ReactFiberConfigDOM.js#L3025-L3216
-- ROBLOX DEVIATION: Native signals have no capture, bubbling, passive options,
-- or dispatchEvent. Callbacks receive the source Instance before native args.
local Packages = script.Parent.Parent.Parent
local Geometry = require(script.Parent.RobloxFragmentGeometry)
local describeError = require(Packages.Shared).describeError
export type ClientRect = Geometry.ClientRect
export type FocusOptions = { channel: ("auto" | "text" | "selection")? }
export type TreePosition = {
	preceding: boolean,
	following: boolean,
	contains: boolean,
	containedBy: boolean,
	disconnected: boolean,
	implementationSpecific: boolean,
}
export type CancellationSignal = {
	aborted: boolean,
	subscribe: (self: CancellationSignal, onAbort: () -> ()) -> () -> (),
}
export type EventOptions = { once: boolean?, signal: CancellationSignal? }
export type Observer = {
	observe: (self: Observer, target: GuiObject, owner: any?) -> (),
	unobserve: (self: Observer, target: GuiObject, owner: any?) -> (),
	unobserveAfterExit: ((self: Observer, target: GuiObject, owner: any?) -> ())?,
	releaseOwner: ((self: Observer, owner: any) -> ())?,
	releaseOwnerAfterExit: ((self: Observer, owner: any) -> ())?,
}
export type FragmentInstance = {
	addEventListener: (
		self: FragmentInstance,
		event: string,
		listener: (Instance, ...any) -> (),
		options: EventOptions?
	) -> (),
	removeEventListener: (
		self: FragmentInstance,
		event: string,
		listener: (Instance, ...any) -> ()
	) -> (),
	focus: (self: FragmentInstance, options: FocusOptions?) -> (),
	focusLast: (self: FragmentInstance, options: FocusOptions?) -> (),
	blur: (self: FragmentInstance) -> (),
	observeUsing: (self: FragmentInstance, observer: Observer) -> (),
	unobserveUsing: (self: FragmentInstance, observer: Observer) -> (),
	getClientRects: (self: FragmentInstance) -> { ClientRect },
	getRootNode: (self: FragmentInstance) -> Instance | FragmentInstance,
	compareTreePosition: (
		self: FragmentInstance,
		other: Instance | FragmentInstance
	) -> TreePosition,
	scrollIntoView: (self: FragmentInstance, alignToTop: boolean?) -> (),
}
local FragmentInstance = {}
FragmentInstance.__index = FragmentInstance
local exports = {}
local fragmentsByInstance = setmetatable({}, { __mode = "k" })
local eventClasses = {
	Changed = "Instance",
	AncestryChanged = "Instance",
	Destroying = "Instance",
	ChildAdded = "Instance",
	ChildRemoved = "Instance",
	AttributeChanged = "Instance",
	Event = "BindableEvent",
	Activated = "GuiButton",
	MouseButton1Click = "GuiButton",
	MouseButton1Down = "GuiButton",
	MouseButton1Up = "GuiButton",
	MouseButton2Click = "GuiButton",
	MouseButton2Down = "GuiButton",
	MouseButton2Up = "GuiButton",
	InputBegan = "GuiObject",
	InputChanged = "GuiObject",
	InputEnded = "GuiObject",
	MouseEnter = "GuiObject",
	MouseLeave = "GuiObject",
	MouseMoved = "GuiObject",
	MouseWheelBackward = "GuiObject",
	MouseWheelForward = "GuiObject",
	SelectionGained = "GuiObject",
	SelectionLost = "GuiObject",
	TouchLongPress = "GuiObject",
	TouchPan = "GuiObject",
	TouchPinch = "GuiObject",
	TouchRotate = "GuiObject",
	TouchSwipe = "GuiObject",
	TouchTap = "GuiObject",
	Focused = "TextBox",
	FocusLost = "TextBox",
	ReturnPressedFromOnScreenKeyboard = "TextBox",
}
local function reflection()
	-- ROBLOX DEVIATION: Host injection precedes reconciler initialization.
	return require(Packages.ReactReconciler.ReactFiberTreeReflection)
end
local function addHandle(instance, fragment)
	fragment._members[instance] = true
	local handles = fragmentsByInstance[instance]
	if handles == nil then
		handles = {}
		fragmentsByInstance[instance] = handles
	end
	if table.find(handles, fragment) == nil then
		table.insert(handles, fragment)
	end
end
local function removeHandle(instance, fragment)
	fragment._members[instance] = nil
	local handles = fragmentsByInstance[instance]
	if handles == nil then
		return
	end
	local index = table.find(handles, fragment)
	if index ~= nil then
		table.remove(handles, index)
	end
	if #handles == 0 then
		fragmentsByInstance[instance] = nil
	end
end
local function attachListener(instance, registration)
	if
		not instance:IsA(eventClasses[registration.event])
		or registration.connections[instance] ~= nil
	then
		return
	end
	local connection
	connection = instance[registration.event]:Connect(function(...)
		-- ROBLOX DEVIATION: Membership removal invalidates deferred delivery.
		if
			registration.fragment._deleted
			or not registration.active
			or registration.connections[instance] ~= connection
		then
			return
		end
		if registration.once then
			registration.fragment:removeEventListener(
				registration.event,
				registration.listener
			)
		end
		registration.listener(instance, ...)
	end)
	registration.connections[instance] = connection
end
local function detachListener(instance, registration)
	local connection = registration.connections[instance]
	if connection ~= nil then
		registration.connections[instance] = nil
		connection:Disconnect()
	end
end
function FragmentInstance:addEventListener(event, listener, options)
	assert(eventClasses[event] ~= nil, "Unsupported Fragment event: " .. tostring(event))
	assert(type(listener) == "function", "Fragment event listener must be a function")
	if self._deleted then
		return
	end
	if options ~= nil then
		assert(type(options) == "table", "Fragment event options must be a table")
		assert(
			options.capture == nil and options.passive == nil,
			"Fragment native events do not support capture or passive options"
		)
	end
	local signal = if options ~= nil then options.signal else nil
	if signal ~= nil and signal.aborted then
		return
	end
	for _, registration in self._eventListeners do
		if registration.event == event and registration.listener == listener then
			return
		end
	end
	local registration = {
		event = event,
		listener = listener,
		fragment = self,
		once = options ~= nil and options.once == true,
		active = true,
		connections = {},
		cleanup = nil,
	}
	table.insert(self._eventListeners, registration)
	if signal ~= nil then
		-- ROBLOX DEVIATION: External cancellation adapters replace AbortSignal.
		local subscribed, cleanup = pcall(signal.subscribe, signal, function()
			if registration.active then
				self:removeEventListener(event, listener)
			end
		end)
		if not subscribed then
			if registration.active then
				self:removeEventListener(event, listener)
			end
			error(cleanup, 0)
		end
		if type(cleanup) ~= "function" then
			if registration.active then
				self:removeEventListener(event, listener)
			end
			error("Fragment cancellation subscribe must return cleanup", 0)
		end
		if registration.active then
			registration.cleanup = cleanup
		else
			cleanup()
		end
	end
	if registration.active then
		reflection().traverseFragmentInstancesAndTextInstances(
			self._fragmentFiber,
			function(child)
				attachListener(child.stateNode, registration)
				return false
			end
		)
	end
end
function FragmentInstance:removeEventListener(event, listener)
	for index, registration in self._eventListeners do
		if registration.event == event and registration.listener == listener then
			registration.active = false
			table.remove(self._eventListeners, index)
			for instance in registration.connections do
				detachListener(instance, registration)
			end
			if registration.cleanup ~= nil then
				local cleanup = registration.cleanup
				registration.cleanup = nil
				cleanup()
			end
			return
		end
	end
end
-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom-bindings/src/client/ReactFiberConfigDOM.js#L3360-L3535
-- ROBLOX DEVIATION: Colon observer methods accept a Fragment owner token.
-- Exit adapters release pending targets through releaseOwner during cleanup.
local function observeInstance(instance, observer, fragment, targets)
	if instance:IsA("GuiObject") then
		observer:observe(instance, fragment)
		targets[instance] = true
	end
end
function FragmentInstance:observeUsing(observer)
	if self._deleted then
		return
	end
	assert(
		type(observer.observe) == "function" and type(observer.unobserve) == "function",
		"Fragment observers must provide observe and unobserve methods"
	)
	assert(
		observer.unobserveAfterExit == nil or type(observer.releaseOwner) == "function",
		"Fragment exit observers must provide releaseOwner"
	)
	local targets = self._observers[observer]
	if targets == nil then
		targets = {}
		self._observers[observer] = targets
	end
	reflection().traverseFragmentInstancesAndTextInstances(
		self._fragmentFiber,
		function(child)
			observeInstance(child.stateNode, observer, self, targets)
			return false
		end
	)
end
function FragmentInstance:unobserveUsing(observer)
	local targets = self._observers[observer]
	if targets == nil then
		if self._retiredObservers ~= nil and self._retiredObservers[observer] then
			self._retiredObservers[observer] = nil
			if observer.releaseOwner ~= nil then
				observer:releaseOwner(self)
			end
			return
		end
		if require(Packages.ReactGlobals).__DEV__ then
			require(Packages.Shared).console.error(
				"You are calling unobserveUsing() with an observer that is not being observed with this fragment instance. First attach the observer with observeUsing()"
			)
		end
		return
	end
	self._observers[observer] = nil
	-- ROBLOX DEVIATION: A foreign target cleanup must not prevent releasing
	-- the remaining targets and owner after observation bookkeeping is removed.
	local firstError = nil
	for instance in targets do
		local ok, cleanupError =
			xpcall(observer.unobserve, describeError, observer, instance, self)
		if not ok and firstError == nil then
			firstError = cleanupError
		end
	end
	if observer.releaseOwner ~= nil then
		local ok, cleanupError =
			xpcall(observer.releaseOwner, describeError, observer, self)
		if not ok and firstError == nil then
			firstError = cleanupError
		end
	end
	if firstError ~= nil then
		error(firstError, 0)
	end
end
-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom-bindings/src/client/ReactFiberConfigDOM.js#L3852-L3968
function exports.createFragmentInstance(fiber)
	local fragment = setmetatable({
		_fragmentFiber = fiber,
		_members = {},
		_eventListeners = {},
		_observers = {},
		_deleted = false,
	}, FragmentInstance)
	reflection().traverseFragmentInstancesAndTextInstances(fiber, function(child)
		addHandle(child.stateNode, fragment)
		return false
	end)
	return fragment
end
function exports.updateFragmentInstanceFiber(fiber, fragment)
	fragment._fragmentFiber = fiber
end
function exports.commitNewChildToFragmentInstance(instance, fragment)
	for _, registration in fragment._eventListeners do
		attachListener(instance, registration)
	end
	for observer, targets in fragment._observers do
		observeInstance(instance, observer, fragment, targets)
	end
	addHandle(instance, fragment)
end
function exports.deleteChildFromFragmentInstance(instance, fragment)
	-- ROBLOX DEVIATION: A foreign exit hook can throw. Release its target as a
	-- fallback, finish other observers and membership, then surface the first error.
	local firstError = nil
	for _, registration in fragment._eventListeners do
		detachListener(instance, registration)
	end
	for observer, targets in fragment._observers do
		if targets[instance] then
			targets[instance] = nil
			local cleanup = observer.unobserveAfterExit or observer.unobserve
			local ok, cleanupError =
				xpcall(cleanup, describeError, observer, instance, fragment)
			if not ok then
				if firstError == nil then
					firstError = cleanupError
				end
				if observer.unobserveAfterExit ~= nil then
					xpcall(
						observer.unobserve,
						describeError,
						observer,
						instance,
						fragment
					)
				end
			end
		end
	end
	removeHandle(instance, fragment)
	if firstError ~= nil then
		error(firstError, 0)
	end
end
function exports.getFragmentInstances(instance)
	local handles = fragmentsByInstance[instance]
	return table.freeze(if handles ~= nil then table.clone(handles) else {})
end
-- ROBLOX DEVIATION: Native connections and cancellation adapters need deletion
-- disposal even for empty Fragments. Ref detachment and hiding retain handles.
function exports.destroyFragmentInstance(fragment)
	fragment._deleted = true
	local firstError = nil
	local function dispose(cleanup, ...)
		local ok, cleanupError = xpcall(cleanup, describeError, ...)
		if not ok and firstError == nil then
			firstError = cleanupError
		end
		return ok
	end
	while #fragment._eventListeners > 0 do
		local registration = fragment._eventListeners[1]
		-- ROBLOX DEVIATION: Foreign cancellation cleanup must not interrupt
		-- disposal of the remaining native subscriptions or host deletion.
		dispose(
			fragment.removeEventListener,
			fragment,
			registration.event,
			registration.listener
		)
	end
	for instance in fragment._members do
		removeHandle(instance, fragment)
	end
	-- ROBLOX DEVIATION: Keep only weak observer identities so a saved handle can
	-- cancel pending exits in passive cleanup without retaining idle observers.
	fragment._retiredObservers = setmetatable({}, { __mode = "k" })
	for observer, targets in fragment._observers do
		fragment._observers[observer] = nil
		fragment._retiredObservers[observer] = true
		local released = true
		if observer.releaseOwnerAfterExit ~= nil then
			released = dispose(observer.releaseOwnerAfterExit, observer, fragment)
		end
		if observer.releaseOwnerAfterExit == nil or not released then
			for instance in targets do
				if observer.unobserveAfterExit ~= nil and released then
					if
						not dispose(
							observer.unobserveAfterExit,
							observer,
							instance,
							fragment
						)
					then
						released = false
						dispose(observer.unobserve, observer, instance, fragment)
					end
				else
					if not dispose(observer.unobserve, observer, instance, fragment) then
						released = false
					end
				end
			end
		end
		-- ROBLOX DEVIATION: If an external composite exit hook fails, release
		-- known targets independently and try its owner cleanup as a final fallback.
		if not released and observer.releaseOwner ~= nil then
			dispose(observer.releaseOwner, observer, fragment)
		end
	end
	if firstError ~= nil then
		error(firstError, 0)
	end
end
FragmentInstance.getRootNode = require(script.Parent.FragmentQueries).getRootNode
FragmentInstance.getClientRects = require(script.Parent.FragmentQueries).getClientRects
FragmentInstance.compareTreePosition =
	require(script.Parent.FragmentQueries).compareTreePosition
FragmentInstance.focus = require(script.Parent.FragmentFocus).focus
FragmentInstance.focusLast = require(script.Parent.FragmentFocus).focusLast
FragmentInstance.blur = require(script.Parent.FragmentFocus).blur
FragmentInstance.scrollIntoView = require(script.Parent.FragmentScroll).scrollIntoView
return exports

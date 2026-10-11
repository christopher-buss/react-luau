--!strict
-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom-bindings/src/client/ReactFiberConfigDOM.js#L3273-L3295
-- ROBLOX DEVIATION: GuiService selection replaces DOM keyboard focus; native
-- text focus remains a separate channel. Channels default to per-candidate auto.
local Packages = script.Parent.Parent.Parent
local Geometry = require(script.Parent.RobloxFragmentGeometry)
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local exports = {}
-- ROBLOX DEVIATION: Native focus supports only a channel option. DOM focus
-- options cannot be honored by CaptureFocus or GuiService selection.
local function resolveChannel(options)
	if options == nil then
		return "auto"
	end
	assert(type(options) == "table", "Fragment focus options must be a table")
	for key in options do
		assert(key == "channel", "Unsupported Fragment focus option: " .. tostring(key))
	end
	local channel = if options.channel == nil then "auto" else options.channel
	assert(
		channel == "auto" or channel == "text" or channel == "selection",
		"Fragment focus channel must be auto, text, or selection"
	)
	return channel
end
-- ROBLOX DEVIATION: A non-interactable ancestor is a disabled Fragment group,
-- even where the native selection navigator accepts one of its descendants.
local function isEligible(instance)
	if not instance:IsA("GuiObject") or not Geometry.isVisible(instance) then
		return false
	end
	local ancestor = instance
	while ancestor ~= nil do
		if ancestor:IsA("GuiObject") and not ancestor.Interactable then
			return false
		end
		ancestor = ancestor.Parent
	end
	return true
end
local function setFocusOnFiberIfFocusable(child, channel)
	local instance = child.stateNode
	if not isEligible(instance) then
		return false
	end
	if channel ~= "selection" and instance:IsA("TextBox") and instance.TextEditable then
		if UserInputService:GetFocusedTextBox() == instance then
			return true
		end
		instance:CaptureFocus()
		if UserInputService:GetFocusedTextBox() == instance then
			return true
		end
	end
	if channel == "text" or not instance.Selectable then
		return false
	end
	if GuiService.SelectedObject == instance then
		return true
	end
	GuiService.SelectedObject = instance
	return GuiService.SelectedObject == instance
end
function exports.focus(fragment, options)
	if fragment._deleted then
		return
	end
	local channel = resolveChannel(options)
	local reflection = require(Packages.ReactReconciler.ReactFiberTreeReflection)
	reflection.traverseFragmentInstancesAndTextInstancesDeeply(
		fragment._fragmentFiber,
		setFocusOnFiberIfFocusable,
		channel
	)
end
-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom-bindings/src/client/ReactFiberConfigDOM.js#L3297-L3317
function exports.focusLast(fragment, options)
	if fragment._deleted then
		return
	end
	local channel = resolveChannel(options)
	local children = {}
	local reflection = require(Packages.ReactReconciler.ReactFiberTreeReflection)
	reflection.traverseFragmentInstancesAndTextInstancesDeeply(
		fragment._fragmentFiber,
		function(child)
			table.insert(children, child)
			return false
		end
	)
	for index = #children, 1, -1 do
		if setFocusOnFiberIfFocusable(children[index], channel) then
			break
		end
	end
end
-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom-bindings/src/client/ReactFiberConfigDOM.js#L3319-L3359
-- ROBLOX DEVIATION: Native text focus and navigation selection are independent.
function exports.blur(fragment)
	if fragment._deleted then
		return
	end
	local selected = GuiService.SelectedObject
	local focused = UserInputService:GetFocusedTextBox()
	local reflection = require(Packages.ReactReconciler.ReactFiberTreeReflection)
	reflection.traverseFragmentInstancesAndTextInstances(
		fragment._fragmentFiber,
		function(child)
			local instance = child.stateNode
			if
				focused ~= nil
				and (focused == instance or focused:IsDescendantOf(instance))
			then
				focused:ReleaseFocus()
				focused = nil
			end
			if
				selected ~= nil
				and (selected == instance or selected:IsDescendantOf(instance))
			then
				GuiService.SelectedObject = nil
				selected = nil
			end
			return focused == nil and selected == nil
		end
	)
end
return exports

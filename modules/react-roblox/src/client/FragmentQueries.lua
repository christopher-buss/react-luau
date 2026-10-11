--!strict
-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom-bindings/src/client/ReactFiberConfigDOM.js#L3563-L3580
-- ROBLOX DEVIATION: Instance ancestry has no composed/shadow root option.
local Packages = script.Parent.Parent.Parent
local exports = {}
-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom-bindings/src/client/ReactFiberConfigDOM.js#L3537-L3561
-- ROBLOX DEVIATION: Each shallow GuiBase2d host contributes one raw rectangle;
-- non-GUI Instances have no layout rectangle and Roblox has no bare text ranges.
function exports.getClientRects(fragment)
	local rects = {}
	if fragment._deleted then
		return table.freeze(rects)
	end
	local reflection = require(Packages.ReactReconciler.ReactFiberTreeReflection)
	local geometry = require(script.Parent.RobloxFragmentGeometry)
	reflection.traverseFragmentInstancesAndTextInstances(
		fragment._fragmentFiber,
		function(child)
			if child.stateNode:IsA("GuiBase2d") then
				table.insert(rects, geometry.getClientRect(child.stateNode))
			end
			return false
		end
	)
	return table.freeze(rects)
end
local function position(flags)
	flags.preceding = flags.preceding == true
	flags.following = flags.following == true
	flags.contains = flags.contains == true
	flags.containedBy = flags.containedBy == true
	flags.disconnected = flags.disconnected == true
	flags.implementationSpecific = flags.implementationSpecific == true
	return table.freeze(flags)
end
local function sameFiber(first, second)
	return first == second or first.alternate == second or second.alternate == first
end
local function ancestorPath(fiber)
	local path = {}
	while fiber ~= nil do
		table.insert(path, fiber)
		fiber = fiber.return_
	end
	return path
end
local function physicalParent(fiber, reflection)
	local portalContainer = reflection.getFragmentPortalContainerInfo(fiber)
	if portalContainer ~= nil then
		return portalContainer
	end
	local host = reflection.getFragmentParentInstanceOrContainerFiber(fiber)
	return if host ~= nil then reflection.getInstanceFromHostFiber(host) else nil
end
local function physicallyContains(parent, child)
	return parent ~= nil
		and child ~= nil
		and (parent == child or child:IsDescendantOf(parent))
end
local function portalBoundary(fiber)
	local tags = require(Packages.ReactReconciler.ReactWorkTags)
	fiber = fiber.return_
	while fiber ~= nil do
		if fiber.tag == tags.HostPortal then
			return fiber
		end
		if fiber.tag == tags.HostComponent or fiber.tag == tags.HostRoot then
			return nil
		end
		fiber = fiber.return_
	end
	return nil
end
function exports.getRootNode(fragment)
	if fragment._deleted then
		return fragment
	end
	local reflection = require(Packages.ReactReconciler.ReactFiberTreeReflection)
	-- ROBLOX DEVIATION: An owning portal determines physical Instance ancestry;
	-- the logical host parent does not contain the portaled Fragment position.
	local instance = physicalParent(fragment._fragmentFiber, reflection)
	-- ROBLOX DEVIATION: Deletion clears stateNode before retained return pointers.
	if instance == nil then
		return fragment
	end
	while instance.Parent ~= nil do
		instance = instance.Parent
	end
	return instance
end
-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom-bindings/src/client/ReactFiberConfigDOM.js#L3582-L3760
-- ROBLOX DEVIATION: Relationship records describe committed Fiber ancestry and
-- order. Disconnected Instances receive no arbitrary order; Roblox has no DOM.
function exports.compareTreePosition(fragment, other)
	local reflection = require(Packages.ReactReconciler.ReactFiberTreeReflection)
	-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom-bindings/src/client/ReactFiberConfigDOM.js#L3586-L3592
	if fragment._deleted or not reflection.isFiberMounted(fragment._fragmentFiber) then
		return position({ disconnected = true })
	end
	local otherFiber
	if typeof(other) == "Instance" then
		otherFiber =
			require(script.Parent.ReactRobloxComponentTree).getFiberFromInstance(other)
	else
		assert(
			type(other) == "table" and other._fragmentFiber ~= nil,
			"compareTreePosition requires an Instance or FragmentInstance"
		)
		if other._deleted or not reflection.isFiberMounted(other._fragmentFiber) then
			return position({ disconnected = true })
		end
		otherFiber = other._fragmentFiber
	end
	if otherFiber == nil then
		return position({ disconnected = true, implementationSpecific = true })
	end
	local fiber = fragment._fragmentFiber
	if sameFiber(fiber, otherFiber) then
		return position({})
	end
	-- ROBLOX DEVIATION: Logical containment survives portals. Flag escaped
	-- physical ancestry and distinct portal owners without inventing DOM order.
	local ownPhysicalParent = physicalParent(fiber, reflection)
	local otherPhysicalTarget = if typeof(other) == "Instance"
		then other
		else physicalParent(otherFiber, reflection)
	if reflection.doesFiberContain(otherFiber, fiber) then
		return position({
			preceding = true,
			contains = true,
			implementationSpecific = not physicallyContains(
				otherPhysicalTarget,
				ownPhysicalParent
			),
		})
	end
	if reflection.doesFiberContain(fiber, otherFiber) then
		return position({
			containedBy = true,
			implementationSpecific = not physicallyContains(
				ownPhysicalParent,
				otherPhysicalTarget
			),
		})
	end
	local ownPortal, otherPortal = portalBoundary(fiber), portalBoundary(otherFiber)
	local implementationSpecific = ownPortal ~= otherPortal
		and (ownPortal ~= nil or otherPortal ~= nil)
	local ownPath, otherPath = ancestorPath(fiber), ancestorPath(otherFiber)
	local ownIndex, otherIndex = #ownPath, #otherPath
	if not sameFiber(ownPath[ownIndex], otherPath[otherIndex]) then
		return position({ disconnected = true, implementationSpecific = true })
	end
	while sameFiber(ownPath[ownIndex], otherPath[otherIndex]) do
		ownIndex -= 1
		otherIndex -= 1
	end
	local sibling = ownPath[ownIndex + 1].child
	while sibling ~= nil do
		if sameFiber(sibling, ownPath[ownIndex]) then
			return position({
				following = true,
				implementationSpecific = implementationSpecific,
			})
		end
		if sameFiber(sibling, otherPath[otherIndex]) then
			return position({
				preceding = true,
				implementationSpecific = implementationSpecific,
			})
		end
		sibling = sibling.sibling
	end
	error("Unable to compare committed Fiber siblings")
end
return exports

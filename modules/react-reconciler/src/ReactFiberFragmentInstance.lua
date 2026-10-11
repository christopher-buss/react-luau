--!nonstrict
-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-reconciler/src/ReactFiberFragmentInstance.js#L10-L133
-- ROBLOX DEVIATION: React-Luau has no HostSingleton renderer. Its optional
-- HostText membership stays gated independently from ordinary text rendering.
local Packages = script.Parent.Parent
local ReactWorkTags = require(script.Parent.ReactWorkTags)
local ReactFiberHostConfig = require(script.Parent.ReactFiberHostConfig)
local ReactFeatureFlags = require(Packages.Shared).ReactFeatureFlags
local exports = {}

local function isFragmentInstanceHostBoundary(fiber)
	return fiber.tag == ReactWorkTags.HostComponent or fiber.tag == ReactWorkTags.HostRoot
end

local function isFragmentInstanceParent(fiber)
	return fiber.tag == ReactWorkTags.Fragment and fiber.stateNode ~= nil
end

function exports.commitNewChildToFragmentInstances(fiber, parentFragmentInstances)
	if
		(
			fiber.tag ~= ReactWorkTags.HostComponent
			and not (
				ReactFeatureFlags.enableFragmentRefsTextNodes
				and fiber.tag == ReactWorkTags.HostText
			)
		)
		or fiber.alternate ~= nil
		or parentFragmentInstances == nil
	then
		return
	end
	for _, fragmentInstance in parentFragmentInstances do
		ReactFiberHostConfig.commitNewChildToFragmentInstance(
			fiber.stateNode,
			fragmentInstance
		)
	end
end

function exports.commitFragmentInstanceInsertionEffects(fiber)
	local parent = fiber.return_
	while parent ~= nil do
		if isFragmentInstanceParent(parent) then
			ReactFiberHostConfig.commitNewChildToFragmentInstance(
				fiber.stateNode,
				parent.stateNode
			)
		end
		if isFragmentInstanceHostBoundary(parent) then
			return
		end
		parent = parent.return_
	end
end

function exports.commitFragmentInstanceDeletionEffects(fiber)
	local parent = fiber.return_
	while parent ~= nil do
		if isFragmentInstanceParent(parent) then
			ReactFiberHostConfig.deleteChildFromFragmentInstance(
				fiber.stateNode,
				parent.stateNode
			)
		end
		if isFragmentInstanceHostBoundary(parent) then
			return
		end
		parent = parent.return_
	end
end

function exports.getParentFragmentInstances(fiber)
	local parentFragmentInstances = nil
	local parent = fiber.return_
	while parent ~= nil do
		if isFragmentInstanceParent(parent) then
			if parentFragmentInstances == nil then
				parentFragmentInstances = { parent.stateNode }
			else
				table.insert(parentFragmentInstances, parent.stateNode)
			end
		end
		if isFragmentInstanceHostBoundary(parent) then
			break
		end
		parent = parent.return_
	end
	return parentFragmentInstances
end

return exports

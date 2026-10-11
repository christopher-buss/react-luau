--!strict
-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom-bindings/src/client/ReactFiberConfigDOM.js#L3762-L3848
local exports = {}
local Packages = script.Parent.Parent.Parent
-- ROBLOX DEVIATION: Native canvas scrolling implements the browser's nearest
-- inline alignment, including targets larger than the scrolling window.
local function nearestHorizontalOffset(left, width, windowLeft, windowWidth, canvasOffset)
	local startDelta = left - windowLeft
	local endDelta = startDelta + width - windowWidth
	if startDelta < 0 and endDelta > 0 then
		return canvasOffset
	end
	if startDelta < 0 then
		return canvasOffset + (if width > windowWidth then endDelta else startDelta)
	end
	if endDelta > 0 then
		return canvasOffset + (if width > windowWidth then startDelta else endDelta)
	end
	return canvasOffset
end
-- ROBLOX DEVIATION: Roblox exposes canvas offsets instead of native DOM scrolling.
-- Snapshot every target before writing offsets; layout settles after the call.
local function collectScrollCommands(instance, alignToTop, commands)
	if not instance:IsA("GuiObject") then
		return
	end
	local bounds = instance.AbsolutePosition
	local size = instance.AbsoluteSize
	local ancestor = instance.Parent
	local innerDelta = Vector2.zero
	while ancestor ~= nil do
		if ancestor:IsA("ScrollingFrame") then
			local position = ancestor.AbsolutePosition
			local window = ancestor.AbsoluteWindowSize
			local canvas = ancestor.CanvasPosition
			local targetBounds = bounds - innerDelta
			local top = targetBounds.Y - position.Y + canvas.Y
			local targetY = if alignToTop then top else top + size.Y - window.Y
			local targetX = nearestHorizontalOffset(
				targetBounds.X,
				size.X,
				position.X,
				window.X,
				canvas.X
			)
			local maximum = ancestor.AbsoluteCanvasSize - window
			local resolved = Vector2.new(
				math.clamp(targetX, 0, math.max(0, maximum.X)),
				math.clamp(targetY, 0, math.max(0, maximum.Y))
			)
			table.insert(commands, { ancestor, resolved })
			-- ROBLOX DEVIATION: CanvasPosition and absolute geometry both use
			-- screen pixels, including UIScale. Account for pending inner writes.
			innerDelta += resolved - canvas
		end
		ancestor = ancestor.Parent
	end
end
function exports.scrollIntoView(fragment, alignToTop)
	if type(alignToTop) == "table" then
		error(
			"FragmentInstance.scrollIntoView() does not support scrollIntoViewOptions. Use the alignToTop boolean instead."
		)
	end
	if fragment._deleted then
		return
	end
	local reflection = require(Packages.ReactReconciler.ReactFiberTreeReflection)
	local children, commands = {}, {}
	reflection.traverseFragmentInstancesAndTextInstances(
		fragment._fragmentFiber,
		function(child)
			table.insert(children, child)
			return false
		end
	)
	local resolvedAlignToTop = alignToTop ~= false
	-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom-bindings/src/client/ReactFiberConfigDOM.js#L3781-L3799
	if #children == 0 then
		local previous, following =
			reflection.getFragmentInstanceOrTextInstanceSiblings(fragment._fragmentFiber)
		local target
		if resolvedAlignToTop then
			target = following
				or previous
				or reflection.getFragmentParentInstanceOrContainerFiber(
					fragment._fragmentFiber
				)
		else
			target = previous or following
		end
		if target ~= nil then
			collectScrollCommands(
				reflection.getInstanceFromHostFiber(target),
				resolvedAlignToTop,
				commands
			)
		end
	end
	local start, finish, step = #children, 1, -1
	-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom-bindings/src/client/ReactFiberConfigDOM.js#L3835-L3848
	if not resolvedAlignToTop then
		start, finish, step = 1, #children, 1
	end
	for index = start, finish, step do
		collectScrollCommands(children[index].stateNode, resolvedAlignToTop, commands)
	end
	for _, command in commands do
		command[1].CanvasPosition = command[2]
	end
end
return exports

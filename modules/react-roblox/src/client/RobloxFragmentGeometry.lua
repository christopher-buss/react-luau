--!strict
-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom-bindings/src/client/ReactFiberConfigDOM.js#L3555-L3571
-- ROBLOX DEVIATION: GuiObject layout supplies one unrotated rectangle, rather
-- than DOM border/text-run rectangles. Every snapshot uses GUI inset coordinates.
export type ClientRect = {
	x: number,
	y: number,
	width: number,
	height: number,
	left: number,
	top: number,
	right: number,
	bottom: number,
}
export type Margin = { value: number, percent: boolean }
export type Intersection = {
	rootBounds: ClientRect?,
	boundingClientRect: ClientRect,
	intersectionRect: ClientRect,
	isIntersecting: boolean,
	intersectionRatio: number,
}

local function rectangle(x: number, y: number, width: number, height: number): ClientRect
	return table.freeze({
		x = x,
		y = y,
		width = width,
		height = height,
		left = x,
		top = y,
		right = x + width,
		bottom = y + height,
	})
end

local function getClientRect(gui: GuiBase2d): ClientRect
	local position = gui.AbsolutePosition
	local size = gui.AbsoluteSize
	return rectangle(position.X, position.Y, size.X, size.Y)
end

local function getClippingRect(gui: GuiBase2d): ClientRect
	if not gui:IsA("ScrollingFrame") then
		return getClientRect(gui)
	end
	-- ROBLOX DEVIATION: Native scrolling clips scrollbar gutters even when
	-- transparent; left gutters move the clipping origin independently of canvas inset.
	local position = gui.AbsolutePosition
	local size = gui.AbsoluteSize
	local window = gui.AbsoluteWindowSize
	local leftInset = if gui.VerticalScrollBarPosition
			== Enum.VerticalScrollBarPosition.Left
		then size.X - window.X
		else 0
	return rectangle(position.X + leftInset, position.Y, window.X, window.Y)
end

local function isVisible(gui: Instance): boolean
	local ancestor: Instance? = gui
	while ancestor ~= nil do
		if ancestor:IsA("GuiObject") and not ancestor.Visible then
			return false
		elseif ancestor:IsA("LayerCollector") and not ancestor.Enabled then
			return false
		end
		ancestor = ancestor.Parent
	end
	return true
end

local function intersect(first: ClientRect, second: ClientRect): (ClientRect, boolean)
	local left = math.max(first.left, second.left)
	local top = math.max(first.top, second.top)
	local right = math.min(first.right, second.right)
	local bottom = math.min(first.bottom, second.bottom)
	return rectangle(left, top, math.max(0, right - left), math.max(0, bottom - top)),
		right >= left and bottom >= top
end

local function validateTarget(gui: GuiObject)
	-- ROBLOX DEVIATION: World-space GUI projection and rotated clipping need
	-- renderer-specific polygons. Reject them instead of reporting false visibility.
	if not gui:IsA("GuiObject") then
		error("Fragment observers require a GuiObject target", 3)
	end
	local ancestor: Instance? = gui
	while ancestor ~= nil do
		if ancestor:IsA("SurfaceGui") or ancestor:IsA("BillboardGui") then
			error(
				"Fragment intersection observers do not support SurfaceGui or BillboardGui targets",
				3
			)
		elseif ancestor:IsA("GuiObject") and ancestor.AbsoluteRotation % 360 ~= 0 then
			error(
				"Fragment intersection observers do not support rotated GUI geometry",
				3
			)
		end
		ancestor = ancestor.Parent
	end
end

-- ROBLOX DEVIATION: Intersection measures GUI visibility and geometric clipping;
-- engine painting, occlusion, transparency, and ZIndex are not observable here.
local function getIntersection(
	gui: GuiObject,
	root: GuiBase2d?,
	margins: { Margin }
): Intersection
	validateTarget(gui)
	local bounds = getClientRect(gui)
	local screen: ScreenGui? = nil
	local ancestor: Instance? = gui.Parent
	while ancestor ~= nil do
		if ancestor:IsA("ScreenGui") then
			screen = ancestor
			break
		end
		ancestor = ancestor.Parent
	end
	local rootBounds: ClientRect? = nil
	local intersection = bounds
	local intersects = isVisible(gui) and screen ~= nil and screen:IsDescendantOf(game)
	if root ~= nil then
		intersects = intersects and gui:IsDescendantOf(root)
		rootBounds = getClippingRect(root)
	elseif screen ~= nil then
		rootBounds = getClientRect(screen)
	end
	if rootBounds ~= nil then
		local amounts = {}
		for index, margin in margins do
			amounts[index] = if margin.percent
				then margin.value * rootBounds.width / 100
				else margin.value
		end
		rootBounds = rectangle(
			rootBounds.x - amounts[4],
			rootBounds.y - amounts[1],
			math.max(0, rootBounds.width + amounts[2] + amounts[4]),
			math.max(0, rootBounds.height + amounts[1] + amounts[3])
		)
		local overlaps
		intersection, overlaps = intersect(intersection, rootBounds)
		intersects = intersects and overlaps
	end
	ancestor = gui.Parent
	while ancestor ~= nil and ancestor ~= root and ancestor ~= screen do
		if ancestor:IsA("GuiObject") and ancestor.ClipsDescendants then
			local overlaps
			intersection, overlaps = intersect(intersection, getClippingRect(ancestor))
			intersects = intersects and overlaps
		end
		ancestor = ancestor.Parent
	end
	if not intersects then
		intersection = rectangle(0, 0, 0, 0)
	end
	local area = bounds.width * bounds.height
	local ratio = if area > 0
		then intersection.width * intersection.height / area
		else if intersects then 1 else 0
	return {
		rootBounds = rootBounds,
		boundingClientRect = bounds,
		intersectionRect = intersection,
		isIntersecting = intersects,
		intersectionRatio = ratio,
	}
end

return {
	getClientRect = getClientRect,
	isVisible = isVisible,
	getIntersection = getIntersection,
	validateIntersectionTarget = validateTarget,
	rectangle = rectangle,
}

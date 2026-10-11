--!strict
-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom-bindings/src/client/ReactFiberConfigDOM.js#L3360-L3537
-- ROBLOX DEVIATION: Roblox has no native browser observers. GUI property signals
-- settle on one engine frame per dirty batch; no permanent frame poll is owned.
local RunService = game:GetService("RunService")
local Geometry = require(script.Parent.RobloxFragmentGeometry)

local function disconnectConnections(connections)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function parseMargins(value)
	if type(value) ~= "string" then
		error(
			"IntersectionObserver rootMargin must contain one to four px or % values",
			3
		)
	end
	local margins = {}
	local tokens = {}
	for token in string.gmatch(value, "%S+") do
		local amount, unit = string.match(token, "^([%+%-]?[%d%.]+)(px)$")
		if amount == nil then
			amount, unit = string.match(token, "^([%+%-]?[%d%.]+)(%%)$")
		end
		local numeric = tonumber(amount)
		if not finite(numeric) then
			error(
				"IntersectionObserver rootMargin must contain one to four px or % values",
				3
			)
		end
		table.insert(margins, { value = numeric, percent = unit == "%" })
		table.insert(tokens, token)
	end
	if #margins < 1 or #margins > 4 then
		error(
			"IntersectionObserver rootMargin must contain one to four px or % values",
			3
		)
	end
	if #margins == 1 then
		margins[2], tokens[2] = margins[1], tokens[1]
	end
	if #margins == 2 then
		margins[3], tokens[3] = margins[1], tokens[1]
	end
	if #margins == 3 then
		margins[4], tokens[4] = margins[2], tokens[2]
	end
	return margins, table.concat(tokens, " ")
end

local function parseThresholds(value)
	local values = if type(value) == "table" then table.clone(value) else { value }
	for _, threshold in values do
		if not finite(threshold) or threshold < 0 or threshold > 1 then
			error(
				"IntersectionObserver thresholds must be finite numbers between 0 and 1",
				3
			)
		end
	end
	if #values == 0 then
		table.insert(values, 0)
	end
	table.sort(values)
	local thresholds = {}
	for _, threshold in values do
		if thresholds[#thresholds] ~= threshold then
			table.insert(thresholds, threshold)
		end
	end
	return table.freeze(thresholds)
end

local function thresholdIndex(thresholds, ratio)
	for index, threshold in thresholds do
		if ratio < threshold then
			return index
		end
	end
	return #thresholds + 1
end

local function createObserver(callback, intersectionOptions)
	assert(type(callback) == "function", "Fragment observer callback must be a function")
	local observer = {}
	local externalOwner = {}
	local targets = {}
	local order = {}
	local dirty = {}
	local queue = {}
	local frameConnection = nil
	local deliveryThread = nil
	local margins = nil
	local thresholds = nil
	local root = nil
	local schedule
	local refreshConnections
	local releaseTarget

	if intersectionOptions ~= nil then
		for option in intersectionOptions do
			if option ~= "root" and option ~= "rootMargin" and option ~= "threshold" then
				error(
					"Unsupported Fragment intersection observer option: "
						.. tostring(option),
					3
				)
			end
		end
		root = intersectionOptions.root
		if
			root ~= nil
			and (
				typeof(root) ~= "Instance"
				or not (root:IsA("GuiObject") or root:IsA("ScreenGui"))
			)
		then
			error(
				"Fragment intersection observer root must be a GuiObject or ScreenGui",
				3
			)
		end
		if root ~= nil and root:IsA("GuiObject") then
			Geometry.validateIntersectionTarget(root)
		end
		local marginText
		margins, marginText = parseMargins(intersectionOptions.rootMargin or "0px")
		thresholds = parseThresholds(
			if intersectionOptions.threshold == nil
				then 0
				else intersectionOptions.threshold
		)
		observer.root = root
		observer.rootMargin = marginText
		observer.thresholds = thresholds
	end

	local function releasePending(pendingBatch)
		for target, release in pendingBatch do
			local state = targets[target]
			if state == release.state then
				for owner, token in release.owners do
					if state.pending[owner] == token then
						state.owners[owner], state.pending[owner] = nil, nil
					end
				end
				if next(state.owners) == nil then
					releaseTarget(target)
				end
			end
		end
	end

	local function drain()
		local records = {}
		for _, queued in queue do
			if targets[queued.target] == queued.state then
				table.insert(records, queued.entry)
			end
		end
		table.clear(queue)
		return records
	end

	local function flush()
		frameConnection = nil
		local batch = dirty
		dirty = {}
		local pendingBatch = {}
		for _, target in order do
			local state = targets[target]
			if batch[target] and state ~= nil then
				pendingBatch[target] =
					{ state = state, owners = table.clone(state.pending) }
				local entry
				local changed
				if intersectionOptions ~= nil then
					entry = Geometry.getIntersection(target, root, margins)
					entry.target = target
					entry.time = os.clock() * 1000
					local index = thresholdIndex(thresholds, entry.intersectionRatio)
					changed = state.last == nil
						or index ~= state.thresholdIndex
						or entry.isIntersecting ~= state.last.isIntersecting
					state.thresholdIndex = index
				else
					local size = target.AbsoluteSize
					entry = {
						target = target,
						contentRect = Geometry.rectangle(0, 0, size.X, size.Y),
						contentBoxSize = table.freeze({
							table.freeze({ inlineSize = size.X, blockSize = size.Y }),
						}),
					}
					changed = state.last == nil
						or size.X ~= state.last.contentRect.width
						or size.Y ~= state.last.contentRect.height
				end
				state.last = entry
				if changed then
					table.insert(
						queue,
						{ target = target, state = state, entry = table.freeze(entry) }
					)
				end
			end
		end
		deliveryThread = task.defer(function()
			deliveryThread = nil
			local entries = drain()
			local ok, failure = true, nil
			if #entries > 0 then
				ok, failure = pcall(callback, entries, observer)
			end
			releasePending(pendingBatch)
			if not ok then
				error(failure, 0)
			end
		end)
	end

	schedule = function(target)
		if targets[target] == nil then
			return
		end
		dirty[target] = true
		if frameConnection == nil then
			local signal = if RunService:IsClient()
				then RunService.RenderStepped
				else RunService.Heartbeat
			frameConnection = signal:Once(flush)
		end
	end

	releaseTarget = function(target)
		local state = targets[target]
		if state == nil then
			return
		end
		disconnectConnections(state.connections)
		targets[target] = nil
		dirty[target] = nil
		local index = table.find(order, target)
		if index ~= nil then
			table.remove(order, index)
		end
		if #order == 0 then
			if frameConnection ~= nil then
				frameConnection:Disconnect()
				frameConnection = nil
			end
			if deliveryThread ~= nil then
				task.cancel(deliveryThread)
				deliveryThread = nil
			end
			table.clear(queue)
		end
	end

	refreshConnections = function(target)
		local state = targets[target]
		disconnectConnections(state.connections)
		local function changed()
			schedule(target)
		end
		local function ancestryChanged()
			if targets[target] == state then
				refreshConnections(target)
				changed()
			end
		end
		table.insert(state.connections, target.AncestryChanged:Connect(ancestryChanged))
		table.insert(
			state.connections,
			target.Destroying:Connect(function()
				if intersectionOptions == nil then
					releaseTarget(target)
				else
					for owner in state.owners do
						state.pending[owner] = {}
					end
					changed()
				end
			end)
		)
		local ancestor = target
		while ancestor ~= nil do
			if ancestor:IsA("GuiBase2d") then
				for _, property in
					{ "AbsoluteSize", "AbsolutePosition", "AbsoluteRotation" }
				do
					table.insert(
						state.connections,
						ancestor:GetPropertyChangedSignal(property):Connect(changed)
					)
				end
			end
			if intersectionOptions ~= nil then
				if ancestor:IsA("GuiObject") then
					for _, property in { "Visible", "ClipsDescendants" } do
						table.insert(
							state.connections,
							ancestor:GetPropertyChangedSignal(property):Connect(changed)
						)
					end
				elseif ancestor:IsA("LayerCollector") then
					table.insert(
						state.connections,
						ancestor:GetPropertyChangedSignal("Enabled"):Connect(changed)
					)
				end
			else
				break
			end
			ancestor = ancestor.Parent
		end
		if root ~= nil and not target:IsDescendantOf(root) then
			for _, property in { "AbsoluteSize", "AbsolutePosition" } do
				table.insert(
					state.connections,
					root:GetPropertyChangedSignal(property):Connect(changed)
				)
			end
		end
	end

	function observer:observe(target, owner)
		if typeof(target) ~= "Instance" or not target:IsA("GuiObject") then
			error("Fragment observers require a GuiObject target", 2)
		end
		if intersectionOptions ~= nil then
			Geometry.validateIntersectionTarget(target)
		end
		owner = owner or externalOwner
		local state = targets[target]
		if state == nil then
			state = { owners = {}, pending = {}, connections = {}, last = nil }
			targets[target] = state
			table.insert(order, target)
			refreshConnections(target)
		end
		state.owners[owner] = true
		state.pending[owner] = nil
		schedule(target)
	end

	function observer:unobserve(target, owner)
		local state = targets[target]
		if state == nil then
			return
		end
		owner = owner or externalOwner
		state.owners[owner], state.pending[owner] = nil, nil
		if next(state.owners) == nil then
			releaseTarget(target)
		end
	end

	-- ROBLOX upstream: https://github.com/facebook/react/blob/065bc84eb50914fa1bc60983eac0b0b717186d74/packages/react-dom-bindings/src/client/ReactFiberConfigDOM.js#L3451-L3528
	-- ROBLOX DEVIATION: Per-owner release prevents a shared observer registration
	-- from removing another Fragment or explicit target registration.
	function observer:unobserveAfterExit(target, owner)
		if intersectionOptions == nil then
			self:unobserve(target, owner)
			return
		end
		local state = targets[target]
		owner = owner or externalOwner
		if state ~= nil and state.owners[owner] then
			state.pending[owner] = {}
			schedule(target)
		end
	end

	function observer:takeRecords()
		local entries = drain()
		return entries
	end

	function observer:releaseOwner(owner)
		for _, target in table.clone(order) do
			self:unobserve(target, owner)
		end
	end

	function observer:disconnect()
		for _, target in table.clone(order) do
			releaseTarget(target)
		end
	end

	return observer
end

local function createResizeObserver(callback)
	return createObserver(callback, nil)
end

local function createIntersectionObserver(callback, options)
	return createObserver(callback, options or {})
end

return {
	createResizeObserver = createResizeObserver,
	createIntersectionObserver = createIntersectionObserver,
}

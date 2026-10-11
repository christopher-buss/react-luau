--!strict
--[[*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 *
 ]]
-- ROBLOX upstream: https://github.com/facebook/react/blob/ae74234eae6ebd62f19190731278e20bc1c37d51/packages/shared/enqueueTask.js
-- ROBLOX DEVIATION: Heartbeat provides an unmocked native turn. task.defer
-- chains share a turn and reach Roblox's task reentrancy limit of 80.
local RunService = game:GetService("RunService")

return function(callback: () -> ())
	RunService.Heartbeat:Once(function()
		callback()
	end)
end

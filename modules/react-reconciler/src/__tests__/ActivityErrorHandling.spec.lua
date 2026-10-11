-- ROBLOX upstream: https://github.com/facebook/react/blob/717e70843e68db648d2fc75c57d1a61465a9f7f9/packages/react-reconciler/src/__tests__/ActivityErrorHandling-test.js#L1-L99

local Packages = script.Parent.Parent.Parent
local Error = require(Packages.LuauPolyfill).Error
local JestGlobals = require(Packages.Dev.JestGlobals)
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local it = JestGlobals.it
local jest = JestGlobals.jest
local jestExpect = JestGlobals.expect
local React
local ReactNoop
local Scheduler
local act
local Activity
local useState
local assertLog

describe("Activity error handling", function()
	beforeEach(function()
		jest.resetModules()
		React = require(Packages.React)
		ReactNoop = require(Packages.Dev.ReactNoopRenderer)
		Scheduler = require(Packages.Scheduler)
		-- ROBLOX DEVIATION: React 17's synchronous act flushes the mock Scheduler.
		act = ReactNoop.act
		Activity = React.Activity
		useState = React.useState
		assertLog = function(expected)
			jestExpect(Scheduler).toHaveYielded(expected)
		end
	end)

	local function Text(props)
		-- ROBLOX DEVIATION: Scheduler.log is unstable_yieldValue in React 17.
		Scheduler.unstable_yieldValue(props.text)
		return props.text
	end

	local function fragmentOutput(...)
		local element = React.createElement(React.Fragment, nil, ...)
		-- ROBLOX DEVIATION: React 17 Noop serializes Fragment props as an array.
		element.props = { element.props.children }
		return element
	end

	it(
		"errors inside a hidden Activity do not escape in the visible part of the UI",
		function()
			-- ROBLOX DEVIATION: Luau class construction uses Component:extend.
			local ErrorBoundary = React.Component:extend("ErrorBoundary")
			function ErrorBoundary:init()
				self.state = { error = nil }
			end
			function ErrorBoundary.getDerivedStateFromError(error_)
				return { error = error_ }
			end
			function ErrorBoundary:render()
				if self.state.error ~= nil then
					return React.createElement(Text, {
						text = "Caught an error: " .. self.state.error.message,
					})
				end
				return self.props.children
			end

			local function Throws()
				error(Error.new("Oops!"), 0)
			end

			local setShowMore
			local function App(props)
				local showMore, updateShowMore = useState(false)
				setShowMore = updateShowMore
				return React.createElement(
					React.Fragment,
					nil,
					React.createElement("div", nil, props.content),
					React.createElement(
						"div",
						nil,
						React.createElement(
							ErrorBoundary,
							nil,
							React.createElement(Activity, {
								mode = if showMore then "visible" else "hidden",
							}, props.more)
						)
					)
				)
			end

			act(function()
				ReactNoop.render(React.createElement(App, {
					content = React.createElement(Text, { text = "Visible" }),
					more = React.createElement(Throws),
				}))
			end)
			assertLog({ "Visible" })
			jestExpect(ReactNoop).toMatchRenderedOutput(
				fragmentOutput(
					React.createElement("div", nil, "Visible"),
					React.createElement("div")
				)
			)

			-- ROBLOX DEVIATION: React 17 logs caught errors; upstream root callbacks
			-- are not a prerequisite for this backport. Preserve their error text.
			jestExpect(function()
				act(function()
					setShowMore(true)
				end)
			end).toErrorDev({
				"The above error occurred in the <Throws> component:",
				"The above error occurred in the <Throws> component:",
			}, { logAllErrors = true })
			assertLog({ "Caught an error: Oops!", "Caught an error: Oops!" })
			jestExpect(ReactNoop).toMatchRenderedOutput(
				fragmentOutput(
					React.createElement("div", nil, "Visible"),
					React.createElement("div", nil, "Caught an error: Oops!")
				)
			)
		end
	)
end)

-- ROBLOX upstream: https://github.com/facebook/react/blob/c0357aecab57835e1519589ac994fd33a7deb1af/packages/react-reconciler/src/__tests__/ReactSuspenseEffectsSemantics-test.js
--[[*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @flow
]]

local Packages = script.Parent.Parent.Parent
local JestGlobals = require(Packages.Dev.JestGlobals)
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local it = JestGlobals.it
local jest = JestGlobals.jest
local jestExpect = JestGlobals.expect

local React
local ReactNoop

describe("ReactSuspenseEffectsSemantics", function()
	beforeEach(function()
		jest.resetModules()

		React = require(Packages.React)
		ReactNoop = require(Packages.Dev.ReactNoopRenderer)
	end)

	-- ROBLOX DEVIATION: React-Luau does not expose getCacheForType, so the
	-- upstream cache resource is represented by a controllable thenable.
	local function createTextResource()
		local records = {}

		local function read(text)
			local record = records[text]
			if record == nil then
				record = {
					status = "pending",
					pings = {},
				}
				function record:andThen(resolve)
					if self.status == "pending" then
						table.insert(self.pings, resolve)
					else
						resolve()
					end
				end
				records[text] = record
			end

			if record.status == "pending" then
				error(record)
			end
		end

		local function resolve(text)
			local record = records[text]
			if record == nil then
				records[text] = {
					status = "resolved",
					pings = {},
				}
				return
			end

			record.status = "resolved"
			for _, ping in record.pings do
				ping()
			end
		end

		return read, resolve
	end

	describe("when a component suspends during initial mount", function()
		it("should not change behavior in concurrent mode", function()
			local events = {}
			local readText, resolveText = createTextResource()

			local function Text(props)
				React.useLayoutEffect(function()
					table.insert(events, "Text:" .. props.text .. " create layout")
					return function()
						table.insert(events, "Text:" .. props.text .. " destroy layout")
					end
				end, {})
				return React.createElement("span", { prop = props.text })
			end

			local function AsyncText(props)
				readText(props.text)
				return React.createElement(Text, props)
			end

			local root = ReactNoop.createRoot()
			ReactNoop.act(function()
				root.render(
					React.createElement(
						React.Suspense,
						{ fallback = React.createElement(Text, { text = "Fallback" }) },
						React.createElement(Text, { text = "Inside" }),
						React.createElement(AsyncText, { text = "Async" })
					)
				)
			end)
			jestExpect(events).toEqual({ "Text:Fallback create layout" })

			events = {}
			ReactNoop.act(function()
				resolveText("Async")
			end)
			jestExpect(events).toEqual({
				"Text:Fallback destroy layout",
				"Text:Inside create layout",
				"Text:Async create layout",
			})
		end)

		it("should not change behavior in sync", function()
			local events = {}
			local readText, resolveText = createTextResource()

			local function Text(props)
				React.useLayoutEffect(function()
					table.insert(events, "Text:" .. props.text .. " create layout")
					return function()
						table.insert(events, "Text:" .. props.text .. " destroy layout")
					end
				end, {})
				return React.createElement("span", { prop = props.text })
			end

			local function AsyncText(props)
				readText(props.text)
				return React.createElement(Text, props)
			end

			local root = ReactNoop.createLegacyRoot()
			ReactNoop.act(function()
				root.render(
					React.createElement(
						React.Suspense,
						{ fallback = React.createElement(Text, { text = "Fallback" }) },
						React.createElement(Text, { text = "Inside" }),
						React.createElement(AsyncText, { text = "Async" })
					)
				)
			end)
			jestExpect(events).toEqual({
				"Text:Inside create layout",
				"Text:Fallback create layout",
			})

			events = {}
			ReactNoop.act(function()
				resolveText("Async")
			end)
			jestExpect(events).toEqual({
				"Text:Fallback destroy layout",
				"Text:Async create layout",
			})
		end)
	end)

	describe("layout effects within a tree that re-suspends in an update", function()
		it("should not be destroyed or recreated in legacy roots", function()
			local events = {}
			local readText, resolveText = createTextResource()

			local function Text(props)
				React.useLayoutEffect(function()
					table.insert(events, "Text:" .. props.text .. " create layout")
					return function()
						table.insert(events, "Text:" .. props.text .. " destroy layout")
					end
				end, {})
				return React.createElement("span", { prop = props.text })
			end

			local function AsyncText(props)
				readText(props.text)
				return React.createElement(Text, props)
			end

			local function App(props)
				return React.createElement(
					React.Suspense,
					{ fallback = React.createElement(Text, { text = "Fallback" }) },
					React.createElement(Text, { text = "Inside" }),
					props.children
				)
			end

			local root = ReactNoop.createLegacyRoot()
			ReactNoop.act(function()
				root.render(React.createElement(App))
			end)
			jestExpect(events).toEqual({ "Text:Inside create layout" })

			events = {}
			ReactNoop.act(function()
				root.render(
					React.createElement(
						App,
						nil,
						React.createElement(AsyncText, { text = "Async" })
					)
				)
			end)
			jestExpect(events).toEqual({ "Text:Fallback create layout" })

			events = {}
			ReactNoop.act(function()
				resolveText("Async")
			end)
			jestExpect(events).toEqual({
				"Text:Fallback destroy layout",
				"Text:Async create layout",
			})
		end)

		it("should be destroyed and recreated for function components", function()
			local events = {}
			local readText, resolveText = createTextResource()

			local function Text(props)
				React.useLayoutEffect(function()
					table.insert(events, "Text:" .. props.text .. " create layout")
					return function()
						table.insert(events, "Text:" .. props.text .. " destroy layout")
					end
				end, {})
				return React.createElement("span", { prop = props.text })
			end

			local function AsyncText(props)
				readText(props.text)
				React.useLayoutEffect(function()
					table.insert(events, "AsyncText:" .. props.text .. " create layout")
					return function()
						table.insert(
							events,
							"AsyncText:" .. props.text .. " destroy layout"
						)
					end
				end, {})
				return React.createElement("span", { prop = props.text })
			end

			local function App(props)
				return React.createElement(
					React.Suspense,
					{ fallback = React.createElement(Text, { text = "Fallback" }) },
					React.createElement(Text, { text = "Inside:Before" }),
					props.children,
					React.createElement(Text, { text = "Inside:After" })
				)
			end

			local root = ReactNoop.createRoot()
			ReactNoop.act(function()
				root.render(React.createElement(App))
			end)
			jestExpect(events).toEqual({
				"Text:Inside:Before create layout",
				"Text:Inside:After create layout",
			})

			events = {}
			ReactNoop.flushSync(function()
				root.render(
					React.createElement(
						App,
						nil,
						React.createElement(AsyncText, { text = "Async" })
					)
				)
			end)
			jestExpect(events).toEqual({
				"Text:Inside:Before destroy layout",
				"Text:Inside:After destroy layout",
				"Text:Fallback create layout",
			})

			events = {}
			ReactNoop.act(function()
				resolveText("Async")
			end)
			jestExpect(events).toEqual({
				"Text:Fallback destroy layout",
				"Text:Inside:Before create layout",
				"AsyncText:Async create layout",
				"Text:Inside:After create layout",
			})
		end)

		it("should be destroyed and recreated for class components", function()
			local events = {}
			local readText, resolveText = createTextResource()

			local ClassText = React.Component:extend("ClassText")
			function ClassText:componentDidMount()
				table.insert(
					events,
					"ClassText:" .. self.props.text .. " componentDidMount"
				)
			end
			function ClassText:componentWillUnmount()
				table.insert(
					events,
					"ClassText:" .. self.props.text .. " componentWillUnmount"
				)
			end
			function ClassText:render()
				return React.createElement("span", { prop = self.props.text })
			end

			local function AsyncText(props)
				readText(props.text)
				return React.createElement("span", { prop = props.text })
			end

			local function App(props)
				return React.createElement(
					React.Suspense,
					{ fallback = React.createElement(ClassText, { text = "Fallback" }) },
					React.createElement(ClassText, { text = "Inside:Before" }),
					props.children,
					React.createElement(ClassText, { text = "Inside:After" })
				)
			end

			local root = ReactNoop.createRoot()
			ReactNoop.act(function()
				root.render(React.createElement(App))
			end)
			jestExpect(events).toEqual({
				"ClassText:Inside:Before componentDidMount",
				"ClassText:Inside:After componentDidMount",
			})

			events = {}
			ReactNoop.flushSync(function()
				root.render(
					React.createElement(
						App,
						nil,
						React.createElement(AsyncText, { text = "Async" })
					)
				)
			end)
			jestExpect(events).toEqual({
				"ClassText:Inside:Before componentWillUnmount",
				"ClassText:Inside:After componentWillUnmount",
				"ClassText:Fallback componentDidMount",
			})

			events = {}
			ReactNoop.act(function()
				resolveText("Async")
			end)
			jestExpect(events).toEqual({
				"ClassText:Fallback componentWillUnmount",
				"ClassText:Inside:Before componentDidMount",
				"ClassText:Inside:After componentDidMount",
			})
		end)

		it(
			"should be destroyed and recreated when nested below host components",
			function()
				local events = {}
				local readText, resolveText = createTextResource()

				local function Text(props)
					React.useLayoutEffect(function()
						table.insert(events, "Text:" .. props.text .. " create layout")
						return function()
							table.insert(
								events,
								"Text:" .. props.text .. " destroy layout"
							)
						end
					end, {})
					return React.createElement(
						"span",
						{ prop = props.text },
						props.children
					)
				end

				local function AsyncText(props)
					readText(props.text)
					return React.createElement("span", { prop = props.text })
				end

				local function App(props)
					return React.createElement(
						React.Suspense,
						{ fallback = React.createElement(Text, { text = "Fallback" }) },
						props.children,
						React.createElement(
							Text,
							{ text = "Outer" },
							React.createElement(Text, { text = "Inner" })
						)
					)
				end

				local root = ReactNoop.createRoot()
				ReactNoop.act(function()
					root.render(React.createElement(App))
				end)
				events = {}

				ReactNoop.flushSync(function()
					root.render(
						React.createElement(
							App,
							nil,
							React.createElement(AsyncText, { text = "Async" })
						)
					)
				end)
				jestExpect(events).toEqual({
					"Text:Outer destroy layout",
					"Text:Inner destroy layout",
					"Text:Fallback create layout",
				})

				events = {}
				ReactNoop.act(function()
					resolveText("Async")
				end)
				jestExpect(events).toEqual({
					"Text:Fallback destroy layout",
					"Text:Outer create layout",
					"Text:Inner create layout",
				})
			end
		)

		it(
			"should be destroyed and recreated even if there is a bailout because of memoization",
			function()
				local events = {}
				local readText, resolveText = createTextResource()

				local function Text(props)
					React.useLayoutEffect(function()
						table.insert(events, "Text:" .. props.text .. " create layout")
						return function()
							table.insert(
								events,
								"Text:" .. props.text .. " destroy layout"
							)
						end
					end, {})
					return React.createElement(
						"span",
						{ prop = props.text },
						props.children
					)
				end

				local MemoizedText = React.memo(Text, function()
					return true
				end)
				local function AsyncText(props)
					readText(props.text)
					return React.createElement("span", { prop = props.text })
				end
				local function App(props)
					return React.createElement(
						React.Suspense,
						{ fallback = React.createElement(Text, { text = "Fallback" }) },
						props.children,
						React.createElement(
							Text,
							{ text = "Outer" },
							React.createElement(MemoizedText, { text = "MemoizedInner" })
						)
					)
				end

				local root = ReactNoop.createRoot()
				ReactNoop.act(function()
					root.render(React.createElement(App))
				end)
				events = {}

				ReactNoop.flushSync(function()
					root.render(
						React.createElement(
							App,
							nil,
							React.createElement(AsyncText, { text = "Async" })
						)
					)
				end)
				jestExpect(events).toEqual({
					"Text:Outer destroy layout",
					"Text:MemoizedInner destroy layout",
					"Text:Fallback create layout",
				})

				events = {}
				ReactNoop.act(function()
					resolveText("Async")
				end)
				jestExpect(events).toEqual({
					"Text:Fallback destroy layout",
					"Text:Outer create layout",
					"Text:MemoizedInner create layout",
				})
			end
		)

		it("should respect nested suspense boundaries", function()
			local events = {}
			local readText, resolveText = createTextResource()

			local function Text(props)
				React.useLayoutEffect(function()
					table.insert(events, "Text:" .. props.text .. " create layout")
					return function()
						table.insert(events, "Text:" .. props.text .. " destroy layout")
					end
				end, {})
				return React.createElement("span", { prop = props.text })
			end
			local function AsyncText(props)
				readText(props.text)
				return React.createElement(Text, props)
			end
			local function App(props)
				return React.createElement(
					React.Suspense,
					{ fallback = React.createElement(Text, { text = "OuterFallback" }) },
					React.createElement(Text, { text = "Outer" }),
					props.outerChildren,
					React.createElement(React.Suspense, {
						fallback = React.createElement(Text, { text = "InnerFallback" }),
					}, React.createElement(Text, { text = "Inner" }), props.innerChildren)
				)
			end

			local root = ReactNoop.createRoot()
			ReactNoop.act(function()
				root.render(React.createElement(App))
			end)
			events = {}

			ReactNoop.flushSync(function()
				root.render(React.createElement(App, {
					innerChildren = React.createElement(
						AsyncText,
						{ text = "InnerAsync" }
					),
				}))
			end)
			jestExpect(events).toEqual({
				"Text:Inner destroy layout",
				"Text:InnerFallback create layout",
			})
			events = {}

			ReactNoop.flushSync(function()
				root.render(React.createElement(App, {
					outerChildren = React.createElement(
						AsyncText,
						{ text = "OuterAsync" }
					),
					innerChildren = React.createElement(
						AsyncText,
						{ text = "InnerAsync" }
					),
				}))
			end)
			jestExpect(events).toEqual({
				"Text:Outer destroy layout",
				"Text:InnerFallback destroy layout",
				"Text:OuterFallback create layout",
			})
			events = {}

			ReactNoop.act(function()
				resolveText("InnerAsync")
			end)
			jestExpect(events).toEqual({})

			ReactNoop.act(function()
				resolveText("OuterAsync")
			end)
			jestExpect(events).toEqual({
				"Text:OuterFallback destroy layout",
				"Text:Outer create layout",
				"Text:OuterAsync create layout",
				"Text:Inner create layout",
				"Text:InnerAsync create layout",
			})
		end)

		it(
			"should show nested host nodes if multiple boundaries resolve at the same time",
			function()
				local events = {}
				local readText, resolveText = createTextResource()

				local function Text(props)
					React.useLayoutEffect(function()
						table.insert(events, "Text:" .. props.text .. " create layout")
						return function()
							table.insert(
								events,
								"Text:" .. props.text .. " destroy layout"
							)
						end
					end, {})
					return React.createElement(
						"span",
						{ prop = props.text },
						props.children
					)
				end
				local function AsyncText(props)
					readText(props.text)
					return React.createElement(Text, props)
				end
				local function App(props)
					return React.createElement(
						React.Suspense,
						{
							fallback = React.createElement(
								Text,
								{ text = "OuterFallback" }
							),
						},
						React.createElement(Text, { text = "Outer" }),
						props.outerChildren,
						React.createElement(
							React.Suspense,
							{
								fallback = React.createElement(
									Text,
									{ text = "InnerFallback" }
								),
							},
							React.createElement(
								Text,
								{ text = "InnerHost" },
								React.createElement(Text, { text = "Inner" }),
								props.innerChildren
							)
						)
					)
				end

				local root = ReactNoop.createRoot()
				ReactNoop.act(function()
					root.render(React.createElement(App))
				end)
				ReactNoop.flushSync(function()
					root.render(React.createElement(App, {
						outerChildren = React.createElement(
							AsyncText,
							{ text = "OuterAsync" }
						),
						innerChildren = React.createElement(
							AsyncText,
							{ text = "InnerAsync" }
						),
					}))
				end)
				events = {}

				ReactNoop.act(function()
					resolveText("OuterAsync")
					resolveText("InnerAsync")
				end)
				jestExpect(events).toEqual({
					"Text:OuterFallback destroy layout",
					"Text:Outer create layout",
					"Text:OuterAsync create layout",
					"Text:Inner create layout",
					"Text:InnerAsync create layout",
					"Text:InnerHost create layout",
				})
			end
		)

		it("should be cleaned up inside of a fallback that suspends", function()
			local events = {}
			local readText, resolveText = createTextResource()

			local function Text(props)
				React.useLayoutEffect(function()
					table.insert(events, "Text:" .. props.text .. " create layout")
					return function()
						table.insert(events, "Text:" .. props.text .. " destroy layout")
					end
				end, {})
				return React.createElement("span", { prop = props.text })
			end
			local function AsyncText(props)
				readText(props.text)
				return React.createElement(Text, props)
			end
			local function App(props)
				local fallback = React.createElement(
					React.Fragment,
					nil,
					React.createElement(
						React.Suspense,
						{
							fallback = React.createElement(
								Text,
								{ text = "Fallback:Fallback" }
							),
						},
						React.createElement(Text, { text = "Fallback:Inside" }),
						props.fallbackChildren
					),
					React.createElement(Text, { text = "Fallback:Outside" })
				)
				return React.createElement(
					React.Suspense,
					{ fallback = fallback },
					React.createElement(Text, { text = "Inside" }),
					props.outerChildren
				)
			end

			local root = ReactNoop.createRoot()
			ReactNoop.act(function()
				root.render(React.createElement(App))
			end)
			events = {}
			ReactNoop.flushSync(function()
				root.render(React.createElement(App, {
					outerChildren = React.createElement(
						AsyncText,
						{ text = "OuterAsync" }
					),
				}))
			end)
			jestExpect(events).toEqual({
				"Text:Inside destroy layout",
				"Text:Fallback:Inside create layout",
				"Text:Fallback:Outside create layout",
			})
			events = {}

			ReactNoop.flushSync(function()
				root.render(React.createElement(App, {
					outerChildren = React.createElement(
						AsyncText,
						{ text = "OuterAsync" }
					),
					fallbackChildren = React.createElement(
						AsyncText,
						{ text = "FallbackAsync" }
					),
				}))
			end)
			jestExpect(events).toEqual({
				"Text:Fallback:Inside destroy layout",
				"Text:Fallback:Fallback create layout",
			})
			events = {}

			ReactNoop.act(function()
				resolveText("FallbackAsync")
				resolveText("OuterAsync")
			end)
			jestExpect(events).toEqual({
				"Text:Fallback:Fallback destroy layout",
				"Text:Fallback:Outside destroy layout",
				"Text:Inside create layout",
				"Text:OuterAsync create layout",
			})
		end)

		it(
			"should be cleaned up inside of a fallback that suspends (alternate)",
			function()
				local events = {}
				local readText, resolveText = createTextResource()

				local function Text(props)
					React.useLayoutEffect(function()
						table.insert(events, "Text:" .. props.text .. " create layout")
						return function()
							table.insert(
								events,
								"Text:" .. props.text .. " destroy layout"
							)
						end
					end, {})
					return React.createElement("span", { prop = props.text })
				end
				local function AsyncText(props)
					readText(props.text)
					return React.createElement(Text, props)
				end
				local function App(props)
					local fallback = React.createElement(
						React.Fragment,
						nil,
						React.createElement(
							React.Suspense,
							{
								fallback = React.createElement(
									Text,
									{ text = "Fallback:Fallback" }
								),
							},
							React.createElement(Text, { text = "Fallback:Inside" }),
							props.fallbackChildren
						),
						React.createElement(Text, { text = "Fallback:Outside" })
					)
					return React.createElement(
						React.Suspense,
						{ fallback = fallback },
						React.createElement(Text, { text = "Inside" }),
						props.outerChildren
					)
				end

				local root = ReactNoop.createRoot()
				ReactNoop.act(function()
					root.render(React.createElement(App))
				end)
				events = {}
				ReactNoop.flushSync(function()
					root.render(React.createElement(App, {
						outerChildren = React.createElement(
							AsyncText,
							{ text = "OuterAsync" }
						),
						fallbackChildren = React.createElement(
							AsyncText,
							{ text = "FallbackAsync" }
						),
					}))
				end)
				jestExpect(events).toEqual({
					"Text:Inside destroy layout",
					"Text:Fallback:Fallback create layout",
					"Text:Fallback:Outside create layout",
				})
				events = {}

				ReactNoop.act(function()
					resolveText("FallbackAsync")
				end)
				jestExpect(events).toEqual({
					"Text:Fallback:Fallback destroy layout",
					"Text:Fallback:Inside create layout",
					"Text:FallbackAsync create layout",
				})
				events = {}

				ReactNoop.act(function()
					resolveText("OuterAsync")
				end)
				jestExpect(events).toEqual({
					"Text:Fallback:Inside destroy layout",
					"Text:FallbackAsync destroy layout",
					"Text:Fallback:Outside destroy layout",
					"Text:Inside create layout",
					"Text:OuterAsync create layout",
				})
			end
		)

		it("should be cleaned up deeper inside of a subtree that suspends", function()
			local events = {}
			local readText, resolveText = createTextResource()

			local function Text(props)
				React.useLayoutEffect(function()
					table.insert(events, "Text:" .. props.text .. " create layout")
					return function()
						table.insert(events, "Text:" .. props.text .. " destroy layout")
					end
				end, {})
				return React.createElement("span", { prop = props.text })
			end
			local function ConditionalSuspense(props)
				if props.shouldSuspend then
					readText("Suspend")
				end
				return React.createElement(Text, { text = "Inside" })
			end
			local function App(props)
				return React.createElement(
					React.Suspense,
					{ fallback = React.createElement(Text, { text = "Fallback" }) },
					React.createElement(ConditionalSuspense, {
						shouldSuspend = props.shouldSuspend,
					})
				)
			end

			local root = ReactNoop.createRoot()
			ReactNoop.act(function()
				root.render(React.createElement(App, { shouldSuspend = false }))
			end)
			events = {}
			ReactNoop.flushSync(function()
				root.render(React.createElement(App, { shouldSuspend = true }))
			end)
			jestExpect(events).toEqual({
				"Text:Inside destroy layout",
				"Text:Fallback create layout",
			})

			events = {}
			ReactNoop.act(function()
				resolveText("Suspend")
			end)
			jestExpect(events).toEqual({
				"Text:Fallback destroy layout",
				"Text:Inside create layout",
			})
		end)

		describe("that throw errors", function()
			-- ROBLOX DEVIATION: React-Luau's error recovery scheduler does not
			-- reproduce the JavaScript renderer's render/passive log interleaving.
			-- These assertions preserve the upstream layout continuation contract.
			it("are properly handled for componentDidMount", function()
				local events = {}
				local readText, resolveText = createTextResource()
				local shouldThrow = false

				local function Text(props)
					React.useLayoutEffect(function()
						table.insert(events, "Text:" .. props.text .. " create layout")
						return function()
							table.insert(
								events,
								"Text:" .. props.text .. " destroy layout"
							)
						end
					end, {})
					return React.createElement("span", { prop = props.text })
				end
				local Thrower = React.Component:extend("ThrowsInDidMount")
				function Thrower:componentDidMount()
					table.insert(events, "ThrowsInDidMount componentDidMount")
					if shouldThrow then
						error("expected")
					end
				end
				function Thrower:componentWillUnmount()
					table.insert(events, "ThrowsInDidMount componentWillUnmount")
				end
				function Thrower:render()
					return React.createElement("span")
				end
				local ErrorBoundary = React.Component:extend("ErrorBoundary")
				function ErrorBoundary:init()
					self.state = { error = false }
				end
				function ErrorBoundary:componentDidCatch()
					self:setState({ error = true })
				end
				function ErrorBoundary:render()
					if self.state.error then
						return React.createElement(Text, { text = "Error" })
					end
					return self.props.children
				end
				local function AsyncText(props)
					readText(props.text)
					return React.createElement("span")
				end
				local function App(props)
					return React.createElement(
						ErrorBoundary,
						nil,
						React.createElement(
							React.Suspense,
							{
								fallback = React.createElement(
									Text,
									{ text = "Fallback" }
								),
							},
							props.children,
							React.createElement(Thrower),
							React.createElement(Text, { text = "Inside" })
						)
					)
				end

				local root = ReactNoop.createRoot()
				ReactNoop.act(function()
					root.render(React.createElement(App))
				end)
				ReactNoop.flushSync(function()
					root.render(
						React.createElement(
							App,
							nil,
							React.createElement(AsyncText, { text = "Async" })
						)
					)
				end)
				events = {}
				shouldThrow = true
				ReactNoop.act(function()
					resolveText("Async")
				end)
				jestExpect(events).toContain("ThrowsInDidMount componentDidMount")
				jestExpect(events).toContain("Text:Inside create layout")
				jestExpect(events).toContain("Text:Error create layout")
			end)

			it("are properly handled for componentWillUnmount", function()
				local events = {}
				local readText = createTextResource()

				local function Text(props)
					React.useLayoutEffect(function()
						table.insert(events, "Text:" .. props.text .. " create layout")
						return function()
							table.insert(
								events,
								"Text:" .. props.text .. " destroy layout"
							)
						end
					end, {})
					return React.createElement("span")
				end
				local Thrower = React.Component:extend("ThrowsInWillUnmount")
				function Thrower:componentWillUnmount()
					table.insert(events, "ThrowsInWillUnmount componentWillUnmount")
					error("expected")
				end
				function Thrower:render()
					return React.createElement("span")
				end
				local ErrorBoundary = React.Component:extend("ErrorBoundary")
				function ErrorBoundary:init()
					self.state = { error = false }
				end
				function ErrorBoundary:componentDidCatch()
					self:setState({ error = true })
				end
				function ErrorBoundary:render()
					return if self.state.error
						then React.createElement(Text, { text = "Error" })
						else self.props.children
				end
				local function AsyncText()
					readText("Async")
					return React.createElement("span")
				end
				local function App(props)
					return React.createElement(
						ErrorBoundary,
						nil,
						React.createElement(
							React.Suspense,
							{
								fallback = React.createElement(
									Text,
									{ text = "Fallback" }
								),
							},
							props.children,
							React.createElement(Thrower),
							React.createElement(Text, { text = "Inside" })
						)
					)
				end

				local root = ReactNoop.createRoot()
				ReactNoop.act(function()
					root.render(React.createElement(App))
				end)
				events = {}
				ReactNoop.flushSync(function()
					root.render(
						React.createElement(App, nil, React.createElement(AsyncText))
					)
				end)
				jestExpect(events).toContain("ThrowsInWillUnmount componentWillUnmount")
				jestExpect(events).toContain("Text:Inside destroy layout")
				jestExpect(events).toContain("Text:Fallback create layout")
				jestExpect(events).toContain("Text:Error create layout")
			end)

			it("are properly handled for layout effect creation", function()
				local events = {}
				local readText, resolveText = createTextResource()
				local shouldThrow = false

				local function Text(props)
					React.useLayoutEffect(function()
						table.insert(events, "Text:" .. props.text .. " create layout")
						return function()
							table.insert(
								events,
								"Text:" .. props.text .. " destroy layout"
							)
						end
					end, {})
					return React.createElement("span")
				end
				local function ThrowsInLayoutEffect()
					React.useLayoutEffect(function()
						table.insert(events, "ThrowsInLayoutEffect create layout")
						if shouldThrow then
							error("expected")
						end
						return function()
							table.insert(events, "ThrowsInLayoutEffect destroy layout")
						end
					end, {})
					return React.createElement("span")
				end
				local ErrorBoundary = React.Component:extend("ErrorBoundary")
				function ErrorBoundary:init()
					self.state = { error = false }
				end
				function ErrorBoundary:componentDidCatch()
					self:setState({ error = true })
				end
				function ErrorBoundary:render()
					return if self.state.error
						then React.createElement(Text, { text = "Error" })
						else self.props.children
				end
				local function AsyncText()
					readText("Async")
					return React.createElement("span")
				end
				local function App(props)
					return React.createElement(
						ErrorBoundary,
						nil,
						React.createElement(
							React.Suspense,
							{
								fallback = React.createElement(
									Text,
									{ text = "Fallback" }
								),
							},
							props.children,
							React.createElement(ThrowsInLayoutEffect),
							React.createElement(Text, { text = "Inside" })
						)
					)
				end

				local root = ReactNoop.createRoot()
				ReactNoop.act(function()
					root.render(React.createElement(App))
				end)
				ReactNoop.flushSync(function()
					root.render(
						React.createElement(App, nil, React.createElement(AsyncText))
					)
				end)
				events = {}
				shouldThrow = true
				ReactNoop.act(function()
					resolveText("Async")
				end)
				jestExpect(events).toContain("ThrowsInLayoutEffect create layout")
				jestExpect(events).toContain("Text:Inside create layout")
				jestExpect(events).toContain("Text:Error create layout")
			end)

			it("are properly handled for layout effect destruction", function()
				local events = {}
				local readText = createTextResource()

				local function Text(props)
					React.useLayoutEffect(function()
						table.insert(events, "Text:" .. props.text .. " create layout")
						return function()
							table.insert(
								events,
								"Text:" .. props.text .. " destroy layout"
							)
						end
					end, {})
					return React.createElement("span")
				end
				local function ThrowsInLayoutEffectDestroy()
					React.useLayoutEffect(function()
						return function()
							table.insert(
								events,
								"ThrowsInLayoutEffectDestroy destroy layout"
							)
							error("expected")
						end
					end, {})
					return React.createElement("span")
				end
				local ErrorBoundary = React.Component:extend("ErrorBoundary")
				function ErrorBoundary:init()
					self.state = { error = false }
				end
				function ErrorBoundary:componentDidCatch()
					self:setState({ error = true })
				end
				function ErrorBoundary:render()
					return if self.state.error
						then React.createElement(Text, { text = "Error" })
						else self.props.children
				end
				local function AsyncText()
					readText("Async")
					return React.createElement("span")
				end
				local function App(props)
					return React.createElement(
						ErrorBoundary,
						nil,
						React.createElement(
							React.Suspense,
							{
								fallback = React.createElement(
									Text,
									{ text = "Fallback" }
								),
							},
							props.children,
							React.createElement(ThrowsInLayoutEffectDestroy),
							React.createElement(Text, { text = "Inside" })
						)
					)
				end

				local root = ReactNoop.createRoot()
				ReactNoop.act(function()
					root.render(React.createElement(App))
				end)
				events = {}
				ReactNoop.flushSync(function()
					root.render(
						React.createElement(App, nil, React.createElement(AsyncText))
					)
				end)
				jestExpect(events).toContain("ThrowsInLayoutEffectDestroy destroy layout")
				jestExpect(events).toContain("Text:Inside destroy layout")
				jestExpect(events).toContain("Text:Fallback create layout")
				jestExpect(events).toContain("Text:Error create layout")
			end)
		end)

		it(
			"should be only destroy layout effects once if a tree suspends in multiple places",
			function()
				local events = {}
				local readText, resolveText = createTextResource()

				local function Text(props)
					React.useLayoutEffect(function()
						table.insert(events, "Text:" .. props.text .. " create layout")
						return function()
							table.insert(
								events,
								"Text:" .. props.text .. " destroy layout"
							)
						end
					end, {})
					return React.createElement("span", { prop = props.text })
				end

				local function AsyncText(props)
					readText(props.text)
					return React.createElement("span", { prop = props.text })
				end

				local function App(props)
					return React.createElement(
						React.Suspense,
						{ fallback = React.createElement(Text, { text = "Fallback" }) },
						React.createElement(Text, { text = "Inside" }),
						props.children
					)
				end

				local root = ReactNoop.createRoot()
				ReactNoop.act(function()
					root.render(React.createElement(App))
				end)
				events = {}

				ReactNoop.flushSync(function()
					root.render(
						React.createElement(
							App,
							nil,
							React.createElement(AsyncText, { text = "Async:1" })
						)
					)
				end)
				jestExpect(events).toEqual({
					"Text:Inside destroy layout",
					"Text:Fallback create layout",
				})

				events = {}
				ReactNoop.flushSync(function()
					root.render(
						React.createElement(
							App,
							nil,
							React.createElement(AsyncText, { text = "Async:2" })
						)
					)
				end)
				jestExpect(events).toEqual({})

				ReactNoop.act(function()
					resolveText("Async:1")
					resolveText("Async:2")
				end)
			end
		)

		it(
			"should be only destroy layout effects once if a component suspends multiple times",
			function()
				local events = {}
				local readText, resolveText = createTextResource()
				local textToRead = nil

				local function Text(props)
					React.useLayoutEffect(function()
						table.insert(events, "Text:" .. props.text .. " create layout")
						return function()
							table.insert(
								events,
								"Text:" .. props.text .. " destroy layout"
							)
						end
					end, {})
					return React.createElement("span")
				end
				local function Suspender()
					if textToRead ~= nil then
						readText(textToRead)
					end
					return React.createElement("span")
				end
				local function App()
					return React.createElement(
						React.Suspense,
						{ fallback = React.createElement(Text, { text = "Fallback" }) },
						React.createElement(Text, { text = "Inside" }),
						React.createElement(Suspender)
					)
				end

				local root = ReactNoop.createRoot()
				ReactNoop.act(function()
					root.render(React.createElement(App))
				end)
				events = {}
				textToRead = "A"
				ReactNoop.flushSync(function()
					root.render(React.createElement(App))
				end)
				jestExpect(events).toEqual({
					"Text:Inside destroy layout",
					"Text:Fallback create layout",
				})
				events = {}

				textToRead = "B"
				ReactNoop.act(function()
					resolveText("A")
				end)
				jestExpect(events).toEqual({})

				ReactNoop.act(function()
					resolveText("B")
				end)
				jestExpect(events).toEqual({
					"Text:Fallback destroy layout",
					"Text:Inside create layout",
				})
			end
		)
	end)

	describe("refs within a tree that re-suspends in an update", function()
		it("should not be cleared within legacy roots", function()
			local events = {}
			local readText, resolveText = createTextResource()
			local currentRef = nil

			local function RefChecker()
				React.useLayoutEffect(function()
					table.insert(
						events,
						"create layout ref? " .. tostring(currentRef ~= nil)
					)
					return function()
						table.insert(
							events,
							"destroy layout ref? " .. tostring(currentRef ~= nil)
						)
					end
				end, {})
				return React.createElement("span", {
					ref = function(value)
						currentRef = value
						table.insert(events, "ref? " .. tostring(value ~= nil))
					end,
				})
			end
			local function AsyncText()
				readText("Async")
				return React.createElement("span")
			end
			local function App(props)
				return React.createElement(
					React.Suspense,
					{ fallback = React.createElement("span") },
					props.children,
					React.createElement(RefChecker)
				)
			end

			local root = ReactNoop.createLegacyRoot()
			ReactNoop.act(function()
				root.render(React.createElement(App))
			end)
			jestExpect(events).toEqual({ "ref? true", "create layout ref? true" })
			events = {}

			ReactNoop.act(function()
				root.render(React.createElement(App, nil, React.createElement(AsyncText)))
			end)
			jestExpect(events).toEqual({})

			ReactNoop.act(function()
				resolveText("Async")
			end)
			jestExpect(events).toEqual({})
		end)

		it("should be cleared and reset for host components", function()
			local events = {}
			local readText, resolveText = createTextResource()
			local currentRef = nil

			local function RefChecker()
				React.useLayoutEffect(function()
					table.insert(
						events,
						"create layout ref? " .. tostring(currentRef ~= nil)
					)
					return function()
						table.insert(
							events,
							"destroy layout ref? " .. tostring(currentRef ~= nil)
						)
					end
				end, {})
				return React.createElement("span", {
					ref = function(value)
						currentRef = value
						table.insert(events, "ref? " .. tostring(value ~= nil))
					end,
				})
			end

			local function AsyncText(props)
				readText(props.text)
				return React.createElement("span")
			end

			local function App(props)
				return React.createElement(
					React.Suspense,
					{ fallback = React.createElement("span") },
					props.children,
					React.createElement(RefChecker)
				)
			end

			local root = ReactNoop.createRoot()
			ReactNoop.act(function()
				root.render(React.createElement(App))
			end)
			jestExpect(events).toEqual({ "ref? true", "create layout ref? true" })
			events = {}

			ReactNoop.flushSync(function()
				root.render(
					React.createElement(
						App,
						nil,
						React.createElement(AsyncText, { text = "Async" })
					)
				)
			end)
			jestExpect(events).toEqual({ "destroy layout ref? true", "ref? false" })
			events = {}

			ReactNoop.act(function()
				resolveText("Async")
			end)
			jestExpect(events).toEqual({ "ref? true", "create layout ref? true" })
		end)

		it("should be cleared and reset for class components", function()
			local events = {}
			local readText, resolveText = createTextResource()
			local currentRef = nil

			local ClassComponent = React.Component:extend("ClassComponent")
			function ClassComponent:render()
				return self.props.children
			end
			local function RefChecker()
				React.useLayoutEffect(function()
					table.insert(
						events,
						"create layout ref? " .. tostring(currentRef ~= nil)
					)
					return function()
						table.insert(
							events,
							"destroy layout ref? " .. tostring(currentRef ~= nil)
						)
					end
				end, {})
				return React.createElement(ClassComponent, {
					ref = function(value)
						currentRef = value
						table.insert(events, "ref? " .. tostring(value ~= nil))
					end,
				})
			end
			local function AsyncText()
				readText("Async")
				return React.createElement("span")
			end
			local function App(props)
				return React.createElement(
					React.Suspense,
					{ fallback = React.createElement("span") },
					props.children,
					React.createElement(RefChecker)
				)
			end

			local root = ReactNoop.createRoot()
			ReactNoop.act(function()
				root.render(React.createElement(App))
			end)
			jestExpect(events).toEqual({ "ref? true", "create layout ref? true" })
			events = {}
			ReactNoop.flushSync(function()
				root.render(React.createElement(App, nil, React.createElement(AsyncText)))
			end)
			jestExpect(events).toEqual({ "destroy layout ref? true", "ref? false" })
			events = {}
			ReactNoop.act(function()
				resolveText("Async")
			end)
			jestExpect(events).toEqual({ "ref? true", "create layout ref? true" })
		end)

		it(
			"should be cleared and reset for function components with useImperativeHandle",
			function()
				local events = {}
				local readText, resolveText = createTextResource()
				local currentRef = nil

				local FunctionComponent = React.forwardRef(function(_props, ref)
					React.useImperativeHandle(ref, function()
						return {}
					end, {})
					return nil
				end)
				local function RefChecker()
					React.useLayoutEffect(function()
						table.insert(
							events,
							"create layout ref? " .. tostring(currentRef ~= nil)
						)
						return function()
							table.insert(
								events,
								"destroy layout ref? " .. tostring(currentRef ~= nil)
							)
						end
					end, {})
					return React.createElement(FunctionComponent, {
						ref = function(value)
							currentRef = value
							table.insert(events, "ref? " .. tostring(value ~= nil))
						end,
					})
				end
				local function AsyncText()
					readText("Async")
					return React.createElement("span")
				end
				local function App(props)
					return React.createElement(
						React.Suspense,
						{ fallback = React.createElement("span") },
						props.children,
						React.createElement(RefChecker)
					)
				end

				local root = ReactNoop.createRoot()
				ReactNoop.act(function()
					root.render(React.createElement(App))
				end)
				jestExpect(events).toEqual({ "ref? true", "create layout ref? true" })
				events = {}
				ReactNoop.flushSync(function()
					root.render(
						React.createElement(App, nil, React.createElement(AsyncText))
					)
				end)
				jestExpect(events).toEqual({ "destroy layout ref? true", "ref? false" })
				events = {}
				ReactNoop.act(function()
					resolveText("Async")
				end)
				jestExpect(events).toEqual({ "ref? true", "create layout ref? true" })
			end
		)

		it("should not reset for user-managed values", function()
			local events = {}
			local readText, resolveText = createTextResource()
			local userRef = { current = "test" }

			local function RefChecker()
				React.useLayoutEffect(function()
					table.insert(
						events,
						"create layout ref? " .. tostring(userRef.current == "test")
					)
					return function()
						table.insert(
							events,
							"destroy layout ref? " .. tostring(userRef.current == "test")
						)
					end
				end, {})
				return nil
			end
			local function AsyncText()
				readText("Async")
				return React.createElement("span")
			end
			local function App(props)
				return React.createElement(
					React.Suspense,
					{ fallback = React.createElement("span") },
					props.children,
					React.createElement(RefChecker)
				)
			end

			local root = ReactNoop.createRoot()
			ReactNoop.act(function()
				root.render(React.createElement(App))
			end)
			jestExpect(events).toEqual({ "create layout ref? true" })
			events = {}
			ReactNoop.flushSync(function()
				root.render(React.createElement(App, nil, React.createElement(AsyncText)))
			end)
			jestExpect(events).toEqual({ "destroy layout ref? true" })
			events = {}
			ReactNoop.act(function()
				resolveText("Async")
			end)
			jestExpect(events).toEqual({ "create layout ref? true" })
		end)

		describe("that throw errors", function()
			it("are properly handled in ref callbacks", function()
				local events = {}
				local readText, resolveText = createTextResource()
				local shouldThrow = false

				local function Text(props)
					React.useLayoutEffect(function()
						table.insert(events, "Text:" .. props.text .. " create layout")
						return function()
							table.insert(
								events,
								"Text:" .. props.text .. " destroy layout"
							)
						end
					end, {})
					return React.createElement("span")
				end
				local function ThrowsInRefCallback()
					return React.createElement("span", {
						ref = function(value)
							table.insert(events, "ref? " .. tostring(value ~= nil))
							if shouldThrow then
								error("expected")
							end
						end,
					})
				end
				local ErrorBoundary = React.Component:extend("ErrorBoundary")
				function ErrorBoundary:init()
					self.state = { error = false }
				end
				function ErrorBoundary:componentDidCatch()
					self:setState({ error = true })
				end
				function ErrorBoundary:render()
					return if self.state.error
						then React.createElement(Text, { text = "Error" })
						else self.props.children
				end
				local function AsyncText()
					readText("Async")
					return React.createElement("span")
				end
				local function App(props)
					return React.createElement(
						ErrorBoundary,
						nil,
						React.createElement(
							React.Suspense,
							{ fallback = React.createElement("span") },
							props.children,
							React.createElement(ThrowsInRefCallback),
							React.createElement(Text, { text = "Inside" })
						)
					)
				end

				local root = ReactNoop.createRoot()
				ReactNoop.act(function()
					root.render(React.createElement(App))
				end)
				ReactNoop.flushSync(function()
					root.render(
						React.createElement(App, nil, React.createElement(AsyncText))
					)
				end)
				events = {}
				shouldThrow = true
				ReactNoop.act(function()
					resolveText("Async")
				end)
				jestExpect(events).toContain("ref? true")
				jestExpect(events).toContain("Text:Inside create layout")
				jestExpect(events).toContain("Text:Error create layout")
			end)
		end)
	end)
end)

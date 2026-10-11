-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom/src/__tests__/ReactDOMFragmentRefs-test.js#L3300-L3650
-- ROBLOX DEVIATION: Native CanvasPosition observations replace mocked DOM
-- scrollIntoView calls, preserving target order through final scroll offsets.
-- Native fixtures use zero borders so the viewport equals its literal size.
local Packages = script.Parent.Parent.Parent.Parent
local JestGlobals = require(Packages.Dev.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach, jest =
	JestGlobals.beforeEach, JestGlobals.afterEach, JestGlobals.jest
local React, ReactRoblox, parent, root
local describeClient = if game:GetService("RunService"):IsClient()
	then describe
	else describe.skip
local function settle()
	for _ = 1, 4 do
		game:GetService("RunService").RenderStepped:Wait()
	end
end
describeClient("FragmentRefs scrollIntoView", function()
	beforeEach(function()
		jest.resetModules()
		React = require(Packages.React)
		ReactRoblox = require(Packages.ReactRoblox)
		parent = Instance.new("ScreenGui")
		parent.IgnoreGuiInset = true
		parent.Parent = game:GetService("Players").LocalPlayer.PlayerGui
		root = ReactRoblox.createRoot(parent)
	end)
	afterEach(function()
		ReactRoblox.act(function()
			root:unmount()
		end)
		parent:Destroy()
	end)
	it("does not yet support options", function()
		local fragmentRef = React.createRef()
		ReactRoblox.act(function()
			root:render(React.createElement(React.Fragment, { ref = fragmentRef }))
		end)
		expect(function()
			fragmentRef.current:scrollIntoView({ block = "start" })
		end).toThrow(
			"FragmentInstance.scrollIntoView() does not support scrollIntoViewOptions. Use the alignToTop boolean instead."
		)
	end)
	describe("with children", function()
		it(
			"settles scroll on the first child by default, or if alignToTop=true",
			function()
				local fragmentRef, childARef, childBRef, scrollingRef =
					React.createRef(),
					React.createRef(),
					React.createRef(),
					React.createRef()
				local function Test()
					return React.createElement(
						"ScrollingFrame",
						{
							ref = scrollingRef,
							Size = UDim2.fromOffset(200, 100),
							CanvasSize = UDim2.fromOffset(200, 1000),
							ScrollBarThickness = 0,
							BorderSizePixel = 0,
						},
						React.createElement(React.Fragment, { ref = fragmentRef }, {
							React.createElement("Frame", {
								ref = childARef,
								Position = UDim2.fromOffset(0, 300),
								Size = UDim2.fromOffset(50, 50),
							}),
							React.createElement("Frame", {
								ref = childBRef,
								Position = UDim2.fromOffset(0, 600),
								Size = UDim2.fromOffset(50, 50),
							}),
						})
					)
				end
				ReactRoblox.act(function()
					root:render(React.createElement(Test))
				end)
				settle()
				fragmentRef.current:scrollIntoView()
				expect(scrollingRef.current.CanvasPosition.Y).toBe(300)
				scrollingRef.current.CanvasPosition = Vector2.zero
				settle()
				fragmentRef.current:scrollIntoView(true)
				expect(scrollingRef.current.CanvasPosition.Y).toBe(300)
			end
		)
		it("calls scrollIntoView on the last child if alignToTop is false", function()
			local fragmentRef, scrollingRef = React.createRef(), React.createRef()
			local function Test()
				return React.createElement(
					"ScrollingFrame",
					{
						ref = scrollingRef,
						Size = UDim2.fromOffset(200, 100),
						CanvasSize = UDim2.fromOffset(200, 1000),
						ScrollBarThickness = 0,
						BorderSizePixel = 0,
					},
					React.createElement(React.Fragment, { ref = fragmentRef }, {
						React.createElement("Frame", {
							Position = UDim2.fromOffset(0, 300),
							Size = UDim2.fromOffset(50, 50),
						}),
						React.createElement("Frame", {
							Position = UDim2.fromOffset(0, 600),
							Size = UDim2.fromOffset(50, 50),
						}),
					})
				)
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			settle()
			fragmentRef.current:scrollIntoView(false)
			expect(scrollingRef.current.CanvasPosition.Y).toBe(550)
		end)
		it("handles portaled elements -- same scroll container", function()
			local fragmentRef, childARef, childBRef =
				React.createRef(), React.createRef(), React.createRef()
			local scrolling = Instance.new("ScrollingFrame")
			scrolling.Size = UDim2.fromOffset(200, 100)
			scrolling.CanvasSize = UDim2.fromOffset(200, 1000)
			scrolling.ScrollBarThickness = 0
			scrolling.BorderSizePixel = 0
			scrolling.Parent = parent
			ReactRoblox.act(function()
				root:unmount()
			end)
			root = ReactRoblox.createRoot(scrolling)
			local function Test()
				return React.createElement(React.Fragment, { ref = fragmentRef }, {
					ReactRoblox.createPortal(
						React.createElement("Frame", {
							ref = childARef,
							Name = "child-a",
							Position = UDim2.fromOffset(0, 300),
							Size = UDim2.fromOffset(50, 50),
						}),
						scrolling
					),
					React.createElement("Frame", {
						ref = childBRef,
						Name = "child-b",
						Position = UDim2.fromOffset(0, 600),
						Size = UDim2.fromOffset(50, 50),
					}),
				})
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			settle()
			fragmentRef.current:scrollIntoView()
			expect(scrolling.CanvasPosition.Y).toBe(300)
		end)
		it("handles portaled elements -- different scroll container", function()
			local fragmentRef, headerChildRef, childARef, childBRef, childCRef =
				React.createRef(),
				React.createRef(),
				React.createRef(),
				React.createRef(),
				React.createRef()
			local parentARef, parentBRef, parentCRef, scrollingRef, nestedRef =
				React.createRef(),
				React.createRef(),
				React.createRef(),
				React.createRef(),
				React.createRef()
			local function Test(props)
				return React.createElement(React.Fragment, nil, {
					React.createElement(
						"Frame",
						{ Name = "header", Size = UDim2.fromOffset(100, 100) },
						React.createElement(
							"Frame",
							{ ref = parentARef, Name = "parent-a" }
						)
					),
					React.createElement("ScrollingFrame", {
						ref = parentBRef,
						Name = "parent-b",
						Size = UDim2.fromOffset(200, 100),
						CanvasSize = UDim2.fromOffset(200, 1000),
						ScrollBarThickness = 0,
						BorderSizePixel = 0,
					}),
					React.createElement("ScrollingFrame", {
						ref = scrollingRef,
						Name = "scroll-container",
						Size = UDim2.fromOffset(200, 100),
						CanvasSize = UDim2.fromOffset(200, 1000),
						ScrollBarThickness = 0,
						BorderSizePixel = 0,
					}, {
						React.createElement("Frame", {
							ref = parentCRef,
							Name = "parent-c",
							Size = UDim2.fromOffset(200, 1000),
						}),
						React.createElement("ScrollingFrame", {
							ref = nestedRef,
							Name = "scroll-container-nested",
							Size = UDim2.fromOffset(100, 100),
							CanvasSize = UDim2.fromOffset(100, 1000),
							ScrollBarThickness = 0,
							BorderSizePixel = 0,
						}, React.createElement("Frame", { Name = "parent-d" })),
					}),
					props.mountFragment and React.createElement(
						React.Fragment,
						{ ref = fragmentRef },
						{
							ReactRoblox.createPortal(
								React.createElement("Frame", {
									ref = headerChildRef,
									Name = "header-content",
									Size = UDim2.fromOffset(50, 50),
								}),
								parentARef.current
							),
							ReactRoblox.createPortal(
								React.createElement("Frame", {
									ref = childARef,
									Name = "child-a",
									Position = UDim2.fromOffset(0, 300),
									Size = UDim2.fromOffset(50, 50),
								}),
								parentBRef.current
							),
							ReactRoblox.createPortal(
								React.createElement("Frame", {
									ref = childBRef,
									Name = "child-b",
									Position = UDim2.fromOffset(0, 600),
									Size = UDim2.fromOffset(50, 50),
								}),
								parentBRef.current
							),
							ReactRoblox.createPortal(
								React.createElement("Frame", {
									ref = childCRef,
									Name = "child-c",
									Position = UDim2.fromOffset(0, 400),
									Size = UDim2.fromOffset(50, 50),
								}),
								parentCRef.current
							),
						}
					) or nil,
				})
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test, { mountFragment = false }))
			end)
			ReactRoblox.act(function()
				root:render(React.createElement(Test, { mountFragment = true }))
			end)
			settle()
			fragmentRef.current:scrollIntoView()
			expect(parentBRef.current.CanvasPosition.Y).toBe(300)
			expect(scrollingRef.current.CanvasPosition.Y).toBe(400)
			expect(nestedRef.current.CanvasPosition.Y).toBe(0)
			parentBRef.current.CanvasPosition = Vector2.zero
			scrollingRef.current.CanvasPosition = Vector2.zero
			settle()
			fragmentRef.current:scrollIntoView(false)
			expect(parentBRef.current.CanvasPosition.Y).toBe(550)
			expect(scrollingRef.current.CanvasPosition.Y).toBe(350)
			expect(nestedRef.current.CanvasPosition.Y).toBe(0)
		end)
	end)
	describe("without children", function()
		it(
			"calls scrollIntoView on the next sibling by default, or if alignToTop=true",
			function()
				local fragmentRef, scrollingRef, siblingARef, siblingBRef =
					React.createRef(),
					React.createRef(),
					React.createRef(),
					React.createRef()
				local function Test()
					return React.createElement("ScrollingFrame", {
						ref = scrollingRef,
						Size = UDim2.fromOffset(200, 100),
						CanvasSize = UDim2.fromOffset(200, 1000),
						ScrollBarThickness = 0,
						BorderSizePixel = 0,
					}, {
						React.createElement("Frame", {
							ref = siblingARef,
							Position = UDim2.fromOffset(0, 300),
							Size = UDim2.fromOffset(50, 50),
						}),
						React.createElement(React.Fragment, { ref = fragmentRef }),
						React.createElement("Frame", {
							ref = siblingBRef,
							Position = UDim2.fromOffset(0, 600),
							Size = UDim2.fromOffset(50, 50),
						}),
					})
				end
				ReactRoblox.act(function()
					root:render(React.createElement(Test))
				end)
				settle()
				fragmentRef.current:scrollIntoView()
				expect(scrollingRef.current.CanvasPosition.Y).toBe(600)
				scrollingRef.current.CanvasPosition = Vector2.zero
				settle()
				fragmentRef.current:scrollIntoView(true)
				expect(scrollingRef.current.CanvasPosition.Y).toBe(600)
			end
		)
		it(
			"finds host siblings when the empty fragment is nested in a non-host wrapper",
			function()
				local fragmentRef, scrollingRef, beforeRef, afterRef =
					React.createRef(),
					React.createRef(),
					React.createRef(),
					React.createRef()
				local function Wrapper(props)
					return props.children
				end
				local function Test()
					return React.createElement("ScrollingFrame", {
						ref = scrollingRef,
						Size = UDim2.fromOffset(200, 100),
						CanvasSize = UDim2.fromOffset(200, 1000),
						ScrollBarThickness = 0,
						BorderSizePixel = 0,
					}, {
						React.createElement("Frame", {
							ref = beforeRef,
							Position = UDim2.fromOffset(0, 300),
							Size = UDim2.fromOffset(50, 50),
						}),
						React.createElement(
							Wrapper,
							nil,
							React.createElement(React.Fragment, { ref = fragmentRef })
						),
						React.createElement("Frame", {
							ref = afterRef,
							Position = UDim2.fromOffset(0, 600),
							Size = UDim2.fromOffset(50, 50),
						}),
					})
				end
				ReactRoblox.act(function()
					root:render(React.createElement(Test))
				end)
				settle()
				fragmentRef.current:scrollIntoView()
				expect(scrollingRef.current.CanvasPosition.Y).toBe(600)
				scrollingRef.current.CanvasPosition = Vector2.zero
				settle()
				fragmentRef.current:scrollIntoView(false)
				expect(scrollingRef.current.CanvasPosition.Y).toBe(250)
			end
		)
		it("calls scrollIntoView on the prev sibling if alignToTop is false", function()
			local fragmentRef, siblingARef, siblingBRef, scrollingRef =
				React.createRef(), React.createRef(), React.createRef(), React.createRef()
			local function Wrapper(props)
				return props.children
			end
			local function Child()
				return React.createElement(
					Wrapper,
					nil,
					React.createElement("Frame", {
						ref = siblingARef,
						Name = "C",
						Position = UDim2.fromOffset(0, 300),
						Size = UDim2.fromOffset(50, 50),
					})
				)
			end
			local function Test()
				return React.createElement("ScrollingFrame", {
					ref = scrollingRef,
					Name = "A",
					Size = UDim2.fromOffset(200, 100),
					CanvasSize = UDim2.fromOffset(200, 1000),
					ScrollBarThickness = 0,
					BorderSizePixel = 0,
				}, {
					React.createElement(
						"Frame",
						{ Name = "B", Size = UDim2.fromOffset(50, 50) }
					),
					React.createElement(Child),
					React.createElement(React.Fragment, { ref = fragmentRef }),
					React.createElement("Frame", {
						ref = siblingBRef,
						Name = "D",
						Position = UDim2.fromOffset(0, 600),
						Size = UDim2.fromOffset(50, 50),
					}),
					React.createElement(
						"Frame",
						{ Name = "E", Size = UDim2.fromOffset(50, 50) }
					),
				})
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			settle()
			fragmentRef.current:scrollIntoView(false)
			expect(scrollingRef.current.CanvasPosition.Y).toBe(250)
		end)
		it("calls scrollIntoView on the parent if there are no siblings", function()
			local fragmentRef, parentRef, scrollingRef =
				React.createRef(), React.createRef(), React.createRef()
			local function Wrapper(props)
				return props.children
			end
			ReactRoblox.act(function()
				root:render(
					React.createElement(
						"ScrollingFrame",
						{
							ref = scrollingRef,
							Size = UDim2.fromOffset(200, 100),
							CanvasSize = UDim2.fromOffset(200, 1000),
							ScrollBarThickness = 0,
							BorderSizePixel = 0,
						},
						React.createElement(
							"Frame",
							{
								ref = parentRef,
								Position = UDim2.fromOffset(0, 300),
								Size = UDim2.fromOffset(50, 50),
							},
							React.createElement(
								Wrapper,
								nil,
								React.createElement(React.Fragment, { ref = fragmentRef })
							)
						)
					)
				)
			end)
			settle()
			fragmentRef.current:scrollIntoView()
			expect(scrollingRef.current.CanvasPosition.Y).toBe(300)
		end)
		-- ROBLOX DEVIATION: Native nested scrolling uses screen-pixel canvas offsets;
		-- an outer container aligns the target after the inner container scrolls.
	end)
	describe("Roblox host adapters", function()
		it(
			"aligns nested scrolling ancestors using the resulting inner position",
			function()
				local fragmentRef, outerRef, innerRef =
					React.createRef(), React.createRef(), React.createRef()
				local function Test()
					return React.createElement(
						"ScrollingFrame",
						{
							ref = outerRef,
							Size = UDim2.fromOffset(200, 100),
							CanvasSize = UDim2.fromOffset(200, 2000),
							ScrollBarThickness = 0,
							BorderSizePixel = 0,
						},
						React.createElement(
							"ScrollingFrame",
							{
								ref = innerRef,
								Position = UDim2.fromOffset(0, 500),
								Size = UDim2.fromOffset(200, 100),
								CanvasSize = UDim2.fromOffset(200, 1000),
								ScrollBarThickness = 0,
								BorderSizePixel = 0,
							},
							React.createElement(
								React.Fragment,
								{ ref = fragmentRef },
								React.createElement("Frame", {
									Position = UDim2.fromOffset(0, 300),
									Size = UDim2.fromOffset(50, 50),
								})
							)
						)
					)
				end
				ReactRoblox.act(function()
					root:render(React.createElement(Test))
				end)
				settle()
				fragmentRef.current:scrollIntoView()
				expect(innerRef.current.CanvasPosition.Y).toBe(300)
				expect(outerRef.current.CanvasPosition.Y).toBe(500)
				innerRef.current.CanvasPosition = Vector2.zero
				outerRef.current.CanvasPosition = Vector2.zero
				settle()
				fragmentRef.current:scrollIntoView(false)
				expect(innerRef.current.CanvasPosition.Y).toBe(250)
				expect(outerRef.current.CanvasPosition.Y).toBe(500)
			end
		)
		it("uses screen-pixel canvas offsets under UIScale", function()
			local fragmentRef, scrollingRef = React.createRef(), React.createRef()
			ReactRoblox.act(function()
				root:render(React.createElement("ScrollingFrame", {
					ref = scrollingRef,
					Size = UDim2.fromOffset(200, 100),
					CanvasSize = UDim2.fromOffset(400, 1000),
					ScrollBarThickness = 0,
					BorderSizePixel = 0,
				}, {
					React.createElement("UIScale", { Scale = 2 }),
					React.createElement(
						React.Fragment,
						{ ref = fragmentRef },
						React.createElement("Frame", {
							Position = UDim2.fromOffset(300, 300),
							Size = UDim2.fromOffset(50, 50),
						})
					),
				}))
			end)
			settle()
			fragmentRef.current:scrollIntoView()
			expect(scrollingRef.current.CanvasPosition).toBe(Vector2.new(300, 600))
			scrollingRef.current.CanvasPosition = Vector2.zero
			settle()
			fragmentRef.current:scrollIntoView(false)
			expect(scrollingRef.current.CanvasPosition).toBe(Vector2.new(300, 500))
		end)
		it("clamps scroll offsets to the available canvas", function()
			local fragmentRef, scrollingRef = React.createRef(), React.createRef()
			local function Test(props)
				return React.createElement(
					"ScrollingFrame",
					{
						ref = scrollingRef,
						Size = UDim2.fromOffset(200, 100),
						CanvasSize = UDim2.fromOffset(200, 400),
						ScrollBarThickness = 0,
						BorderSizePixel = 0,
					},
					React.createElement(
						React.Fragment,
						{ ref = fragmentRef },
						React.createElement("Frame", {
							Position = UDim2.fromOffset(0, props.top),
							Size = UDim2.fromOffset(50, 50),
						})
					)
				)
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test, { top = 900 }))
			end)
			settle()
			fragmentRef.current:scrollIntoView()
			expect(scrollingRef.current.CanvasPosition.Y).toBe(300)
			ReactRoblox.act(function()
				root:render(React.createElement(Test, { top = -100 }))
			end)
			settle()
			fragmentRef.current:scrollIntoView(false)
			expect(scrollingRef.current.CanvasPosition.Y).toBe(0)
		end)
		it("uses nearest horizontal alignment for oversized targets", function()
			local fragmentRef, scrollingRef = React.createRef(), React.createRef()
			local function Test(props)
				return React.createElement(
					"ScrollingFrame",
					{
						ref = scrollingRef,
						Size = UDim2.fromOffset(200, 100),
						CanvasSize = UDim2.fromOffset(1000, 1000),
						ScrollBarThickness = 0,
						BorderSizePixel = 0,
					},
					React.createElement(
						React.Fragment,
						{ ref = fragmentRef },
						React.createElement("Frame", {
							Position = UDim2.fromOffset(props.left, 300),
							Size = UDim2.fromOffset(500, 50),
						})
					)
				)
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test, { left = 100 }))
			end)
			scrollingRef.current.CanvasPosition = Vector2.new(200, 0)
			settle()
			fragmentRef.current:scrollIntoView()
			expect(scrollingRef.current.CanvasPosition.X).toBe(200)
			ReactRoblox.act(function()
				root:render(React.createElement(Test, { left = 250 }))
			end)
			scrollingRef.current.CanvasPosition = Vector2.new(200, 0)
			settle()
			fragmentRef.current:scrollIntoView()
			expect(scrollingRef.current.CanvasPosition.X).toBe(250)
			ReactRoblox.act(function()
				root:render(React.createElement(Test, { left = -200 }))
			end)
			scrollingRef.current.CanvasPosition = Vector2.new(200, 0)
			settle()
			fragmentRef.current:scrollIntoView()
			expect(scrollingRef.current.CanvasPosition.X).toBe(100)
		end)
	end)
end)

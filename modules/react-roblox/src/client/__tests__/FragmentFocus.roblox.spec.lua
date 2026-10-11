-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom/src/__tests__/ReactDOMFragmentRefs-test.js#L310-L713
-- ROBLOX DEVIATION: Native GuiService selection replaces DOM activeElement for
-- link/tabIndex cases. Editable TextBoxes exercise the separate text channel.
local Packages = script.Parent.Parent.Parent.Parent
local JestGlobals = require(Packages.Dev.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach, jest =
	JestGlobals.beforeEach, JestGlobals.afterEach, JestGlobals.jest
local GuiService = game:GetService("GuiService")
local React, ReactRoblox, parent, root
-- ROBLOX DEVIATION: Browser anchors have intrinsic layout; native GUI fixtures
-- require explicit positive sizes before GuiService considers them eligible.
local function host(className, props, children)
	props = props or {}
	props.Size = UDim2.fromOffset(200, 100)
	return React.createElement(className, props, children)
end
local function settle()
	for _ = 1, 4 do
		game:GetService("RunService").RenderStepped:Wait()
	end
end

-- ROBLOX DEVIATION: Native client focus cannot execute in the server harness.
local describeClient = if game:GetService("RunService"):IsClient()
	then describe
	else describe.skip
describeClient("FragmentRefs focus methods", function()
	beforeEach(function()
		jest.resetModules()
		React = require(Packages.React)
		ReactRoblox = require(Packages.ReactRoblox)
		parent = Instance.new("ScreenGui")
		-- ROBLOX DEVIATION: Test containers must survive character respawns.
		parent.ResetOnSpawn = false
		parent.Parent = game:GetService("Players").LocalPlayer.PlayerGui
		root = ReactRoblox.createRoot(parent)
	end)
	afterEach(function()
		GuiService.SelectedObject = nil
		ReactRoblox.act(function()
			root:unmount()
		end)
		parent:Destroy()
	end)
	describe("focus()", function()
		it("focuses the first focusable child", function()
			local fragmentRef = React.createRef()
			local function Test()
				return host(
					"Frame",
					nil,
					React.createElement(React.Fragment, { ref = fragmentRef }, {
						host("Frame", { Name = "child-a", Selectable = false }),
						React.createElement("Folder"),
						host("TextButton", { Name = "child-b", Selectable = true }),
						host("TextButton", { Name = "child-c", Selectable = true }),
					})
				)
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			settle()
			ReactRoblox.act(function()
				fragmentRef.current:focus({ channel = "selection" })
			end)
			expect(GuiService.SelectedObject.Name).toEqual("child-b")
			GuiService.SelectedObject = nil
		end)
		it("focuses deeply nested focusable children, depth first", function()
			local fragmentRef = React.createRef()
			local function Test()
				return React.createElement(React.Fragment, { ref = fragmentRef }, {
					host(
						"Frame",
						{ Name = "child-a", Selectable = false },
						host(
							"Frame",
							{ Name = "grandchild-a", Selectable = true },
							host(
								"TextButton",
								{ Name = "greatgrandchild-a", Selectable = true }
							)
						)
					),
					host("TextButton", { Name = "child-b", Selectable = true }),
				})
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			settle()
			ReactRoblox.act(function()
				fragmentRef.current:focus({ channel = "selection" })
			end)
			expect(GuiService.SelectedObject.Name).toEqual("grandchild-a")
		end)
		it("preserves document order when adding and removing children", function()
			local fragmentRef = React.createRef()
			local function Test(props)
				return React.createElement(React.Fragment, { ref = fragmentRef }, {
					props.showA and host(
						"TextButton",
						{ key = "A", Name = "child-a", Selectable = true }
					) or nil,
					props.showB and host(
						"TextButton",
						{ key = "B", Name = "child-b", Selectable = true }
					) or nil,
				})
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test, { showA = true, showB = false }))
			end)
			settle()
			ReactRoblox.act(function()
				fragmentRef.current:focus({ channel = "selection" })
			end)
			expect(GuiService.SelectedObject.Name).toEqual("child-a")
			GuiService.SelectedObject = nil
			ReactRoblox.act(function()
				root:render(React.createElement(Test, { showA = true, showB = true }))
			end)
			settle()
			ReactRoblox.act(function()
				fragmentRef.current:focus({ channel = "selection" })
			end)
			expect(GuiService.SelectedObject.Name).toEqual("child-a")
			GuiService.SelectedObject = nil
			ReactRoblox.act(function()
				root:render(React.createElement(Test, { showA = false, showB = true }))
			end)
			settle()
			ReactRoblox.act(function()
				fragmentRef.current:focus({ channel = "selection" })
			end)
			expect(GuiService.SelectedObject.Name).toEqual("child-b")
			GuiService.SelectedObject = nil
		end)
		it("keeps focus on the first focusable child if already focused", function()
			local fragmentRef, childRef = React.createRef(), React.createRef()
			local function Test()
				return React.createElement(React.Fragment, { ref = fragmentRef }, {
					host(
						"TextButton",
						{ ref = childRef, Name = "child-a", Selectable = true }
					),
					host("TextButton", { Name = "child-b", Selectable = true }),
				})
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			settle()
			GuiService.SelectedObject = childRef.current
			expect(GuiService.SelectedObject.Name).toEqual("child-a")
			ReactRoblox.act(function()
				fragmentRef.current:focus({ channel = "selection" })
			end)
			expect(GuiService.SelectedObject.Name).toEqual("child-a")
			GuiService.SelectedObject = nil
		end)
		it("keeps focus on a nested child if already focused", function()
			local fragmentRef, nestedRef = React.createRef(), React.createRef()
			local function Test()
				return React.createElement(React.Fragment, { ref = fragmentRef }, {
					host(
						"Frame",
						{ Selectable = false },
						host("TextBox", {
							ref = nestedRef,
							Name = "nested-input",
							TextEditable = true,
						})
					),
					host("TextButton", { Name = "sibling-link", Selectable = true }),
				})
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			settle()
			nestedRef.current:CaptureFocus()
			expect(game:GetService("UserInputService"):GetFocusedTextBox().Name).toEqual(
				"nested-input"
			)
			ReactRoblox.act(function()
				fragmentRef.current:focus()
			end)
			expect(game:GetService("UserInputService"):GetFocusedTextBox().Name).toEqual(
				"nested-input"
			)
			expect(GuiService.SelectedObject).toBeNil()
			nestedRef.current:ReleaseFocus()
		end)
		-- ROBLOX DEVIATION: HTML fieldset/legend/input hosts become a native GUI
		-- container, label, and editable TextBoxes; no HTML form semantics are claimed.
		it("focuses the first focusable child in a fieldset", function()
			local fragmentRef = React.createRef()
			local function Test()
				return React.createElement(
					React.Fragment,
					{ ref = fragmentRef },
					host("Frame", { Selectable = false }, {
						host("TextLabel", { Text = "Shipping", Selectable = false }),
						host("TextBox", { Name = "street", TextEditable = true }),
						host("TextBox", { Name = "city", TextEditable = true }),
					})
				)
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			settle()
			ReactRoblox.act(function()
				fragmentRef.current:focus()
			end)
			expect(game:GetService("UserInputService"):GetFocusedTextBox().Name).toEqual(
				"street"
			)
			game:GetService("UserInputService"):GetFocusedTextBox():ReleaseFocus()
		end)
	end)
	describe("focusLast()", function()
		it("focuses the last focusable child", function()
			local fragmentRef = React.createRef()
			local function Wrapper(props)
				return props.children
			end
			local function Test()
				return host(
					"Frame",
					nil,
					React.createElement(React.Fragment, { ref = fragmentRef }, {
						host("TextButton", { Name = "child-a", Selectable = true }),
						host("TextButton", { Name = "child-b", Selectable = true }),
						React.createElement(
							Wrapper,
							nil,
							host("TextButton", { Name = "child-c", Selectable = true })
						),
						host("Frame", { Name = "child-d", Selectable = false }),
						React.createElement("Folder", { Name = "child-e" }),
					})
				)
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			settle()
			ReactRoblox.act(function()
				fragmentRef.current:focusLast({ channel = "selection" })
			end)
			expect(GuiService.SelectedObject.Name).toEqual("child-c")
			GuiService.SelectedObject = nil
		end)
		it("focuses deeply nested focusable children, depth first", function()
			local fragmentRef = React.createRef()
			local function Test()
				return React.createElement(React.Fragment, { ref = fragmentRef }, {
					host("Frame", { Name = "child-a", Selectable = false }, {
						host("TextButton", { Name = "grandchild-a", Selectable = true }),
						host("TextButton", { Name = "grandchild-b", Selectable = true }),
					}),
					host("Frame", { Name = "child-b", Selectable = true }, {
						host("TextButton", { Name = "grandchild-a", Selectable = true }),
						host("TextButton", { Name = "grandchild-b", Selectable = true }),
					}),
				})
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			settle()
			ReactRoblox.act(function()
				fragmentRef.current:focusLast({ channel = "selection" })
			end)
			expect(GuiService.SelectedObject.Name).toEqual("grandchild-b")
		end)
	end)
	describe("blur()", function()
		it("removes focus from an element inside of the Fragment", function()
			local fragmentRef = React.createRef()
			local function Test()
				return React.createElement(
					React.Fragment,
					{ ref = fragmentRef },
					host("TextButton", { Name = "child-a", Selectable = true })
				)
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			settle()
			ReactRoblox.act(function()
				fragmentRef.current:focus({ channel = "selection" })
			end)
			expect(GuiService.SelectedObject.Name).toEqual("child-a")
			ReactRoblox.act(function()
				fragmentRef.current:blur()
			end)
			expect(GuiService.SelectedObject).toBeNil()
		end)
		it("removes focus from a nested element inside of the Fragment", function()
			local fragmentRef = React.createRef()
			local function Test()
				return React.createElement(
					React.Fragment,
					{ ref = fragmentRef },
					host(
						"Frame",
						{ Selectable = false },
						host("TextBox", { Name = "nested-input", TextEditable = true })
					)
				)
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			settle()
			ReactRoblox.act(function()
				fragmentRef.current:focus({ channel = "text" })
			end)
			expect(game:GetService("UserInputService"):GetFocusedTextBox().Name).toEqual(
				"nested-input"
			)
			ReactRoblox.act(function()
				fragmentRef.current:blur()
			end)
			expect(game:GetService("UserInputService"):GetFocusedTextBox()).toBeNil()
		end)
		it("removes focus from a portaled element inside of the Fragment", function()
			local fragmentRef = React.createRef()
			local function Test()
				return host(
					"Frame",
					{ Selectable = false },
					React.createElement(
						React.Fragment,
						{ ref = fragmentRef },
						ReactRoblox.createPortal(
							host(
								"Frame",
								{ Selectable = false },
								host(
									"TextBox",
									{ Name = "portaled-input", TextEditable = true }
								)
							),
							parent
						)
					)
				)
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			settle()
			ReactRoblox.act(function()
				fragmentRef.current:focus({ channel = "text" })
			end)
			expect(game:GetService("UserInputService"):GetFocusedTextBox().Name).toEqual(
				"portaled-input"
			)
			ReactRoblox.act(function()
				fragmentRef.current:blur()
			end)
			expect(game:GetService("UserInputService"):GetFocusedTextBox()).toBeNil()
		end)
		it("does not remove focus from elements outside of the Fragment", function()
			local fragmentRefA, fragmentRefB = React.createRef(), React.createRef()
			local function Test()
				return React.createElement(React.Fragment, { ref = fragmentRefA }, {
					host("TextButton", { Name = "child-a", Selectable = true }),
					React.createElement(
						React.Fragment,
						{ ref = fragmentRefB },
						host("TextButton", { Name = "child-b", Selectable = true })
					),
				})
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			settle()
			ReactRoblox.act(function()
				fragmentRefA.current:focus({ channel = "selection" })
			end)
			expect(GuiService.SelectedObject.Name).toEqual("child-a")
			ReactRoblox.act(function()
				fragmentRefB.current:blur()
			end)
			expect(GuiService.SelectedObject.Name).toEqual("child-a")
		end)
		-- ROBLOX DEVIATION: Native adapter regressions extend the upstream focus
		-- contract with disabled group ancestry; DOM fieldsets remain unsupported.
	end)
	describe("Roblox host adapters", function()
		it("skips candidates under disabled or invisible ancestors", function()
			local fragmentRef = React.createRef()
			local function Test()
				return React.createElement(React.Fragment, { ref = fragmentRef }, {
					host(
						"Frame",
						{ Selectable = false, Interactable = false },
						host("TextButton", { Name = "disabled-child", Selectable = true })
					),
					host(
						"Frame",
						{ Selectable = false, Visible = false },
						host("TextButton", { Name = "hidden-child", Selectable = true })
					),
					host("TextButton", { Name = "eligible-child", Selectable = true }),
				})
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			settle()
			fragmentRef.current:focus({ channel = "selection" })
			expect(GuiService.SelectedObject.Name).toEqual("eligible-child")
		end)
		it("keeps text and selection channels independent", function()
			local fragmentRef, frameRef = React.createRef(), React.createRef()
			local function Test()
				return React.createElement(
					React.Fragment,
					{ ref = fragmentRef },
					host(
						"Frame",
						{ ref = frameRef, Name = "selectable-parent", Selectable = true },
						host("TextBox", { Name = "editable-child", TextEditable = true })
					)
				)
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			settle()
			fragmentRef.current:focus({ channel = "text" })
			expect(game:GetService("UserInputService"):GetFocusedTextBox().Name).toBe(
				"editable-child"
			)
			expect(GuiService.SelectedObject).toBeNil()
			fragmentRef.current:blur()
			fragmentRef.current:focus({ channel = "selection" })
			expect(GuiService.SelectedObject).toBe(frameRef.current)
			expect(game:GetService("UserInputService"):GetFocusedTextBox()).toBeNil()
			fragmentRef.current:blur()
			expect(GuiService.SelectedObject).toBeNil()
		end)
		it(
			"auto prefers editable text and falls back to selection on the same candidate",
			function()
				local fragmentRef, textRef = React.createRef(), React.createRef()
				local function Test(props)
					return React.createElement(React.Fragment, { ref = fragmentRef }, {
						host("TextBox", {
							ref = textRef,
							Name = "first-candidate",
							TextEditable = props.editable,
							Selectable = true,
						}),
						host(
							"TextButton",
							{ Name = "second-candidate", Selectable = true }
						),
					})
				end
				ReactRoblox.act(function()
					root:render(React.createElement(Test, { editable = true }))
				end)
				settle()
				fragmentRef.current:focus()
				expect(game:GetService("UserInputService"):GetFocusedTextBox()).toBe(
					textRef.current
				)
				expect(GuiService.SelectedObject).toBeNil()
				fragmentRef.current:blur()
				ReactRoblox.act(function()
					root:render(React.createElement(Test, { editable = false }))
				end)
				settle()
				fragmentRef.current:focus()
				expect(GuiService.SelectedObject).toBe(textRef.current)
				expect(game:GetService("UserInputService"):GetFocusedTextBox()).toBeNil()
			end
		)
		it("releases only each owned focus channel", function()
			local fragmentRef, ownedTextRef, ownedSelectionRef, outsideTextRef, outsideSelectionRef =
				React.createRef(),
				React.createRef(),
				React.createRef(),
				React.createRef(),
				React.createRef()
			local function Test()
				return React.createElement(React.Fragment, nil, {
					React.createElement(React.Fragment, { ref = fragmentRef }, {
						host("TextBox", { ref = ownedTextRef, TextEditable = true }),
						host(
							"TextButton",
							{ ref = ownedSelectionRef, Selectable = true }
						),
					}),
					host("TextBox", { ref = outsideTextRef, TextEditable = true }),
					host("TextButton", { ref = outsideSelectionRef, Selectable = true }),
				})
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			settle()
			ownedTextRef.current:CaptureFocus()
			GuiService.SelectedObject = outsideSelectionRef.current
			fragmentRef.current:blur()
			expect(game:GetService("UserInputService"):GetFocusedTextBox()).toBeNil()
			expect(GuiService.SelectedObject).toBe(outsideSelectionRef.current)
			outsideTextRef.current:CaptureFocus()
			GuiService.SelectedObject = ownedSelectionRef.current
			fragmentRef.current:blur()
			expect(game:GetService("UserInputService"):GetFocusedTextBox()).toBe(
				outsideTextRef.current
			)
			expect(GuiService.SelectedObject).toBeNil()
			ownedTextRef.current:CaptureFocus()
			GuiService.SelectedObject = ownedSelectionRef.current
			fragmentRef.current:blur()
			expect(game:GetService("UserInputService"):GetFocusedTextBox()).toBeNil()
			expect(GuiService.SelectedObject).toBeNil()
		end)
		it("skips candidates inside disabled LayerCollectors", function()
			local fragmentRef = React.createRef()
			local disabledGui = Instance.new("ScreenGui")
			disabledGui.ResetOnSpawn = false
			disabledGui.Enabled = false
			disabledGui.Parent = parent.Parent
			local function Test()
				return React.createElement(React.Fragment, { ref = fragmentRef }, {
					ReactRoblox.createPortal(
						host("TextBox", { Name = "disabled-text", TextEditable = true }),
						disabledGui
					),
					host(
						"TextButton",
						{ Name = "eligible-selection", Selectable = true }
					),
				})
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			settle()
			fragmentRef.current:focus()
			expect(GuiService.SelectedObject.Name).toBe("eligible-selection")
			expect(game:GetService("UserInputService"):GetFocusedTextBox()).toBeNil()
			ReactRoblox.act(function()
				root:unmount()
			end)
			disabledGui:Destroy()
		end)
		it("rejects unsupported focus options", function()
			local fragmentRef = React.createRef()
			ReactRoblox.act(function()
				root:render(React.createElement(React.Fragment, { ref = fragmentRef }))
			end)
			expect(function()
				fragmentRef.current:focus({ channel = "pointer" })
			end).toThrow("Fragment focus channel must be auto, text, or selection")
			expect(function()
				fragmentRef.current:focusLast({ channel = "pointer" })
			end).toThrow("Fragment focus channel must be auto, text, or selection")
			expect(function()
				fragmentRef.current:focus({ preventScroll = true })
			end).toThrow("Unsupported Fragment focus option: preventScroll")
		end)
	end)
end)

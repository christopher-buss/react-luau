-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom/src/__tests__/ReactDOMFragmentRefs-test.js#L2352-L3296
-- ROBLOX DEVIATION: Physical Instance-root ancestry replaces document/shadow
-- roots. React's retained-deleted-handle self result is preserved.
local Packages = script.Parent.Parent.Parent.Parent
local JestGlobals = require(Packages.Dev.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach, jest =
	JestGlobals.beforeEach, JestGlobals.afterEach, JestGlobals.jest
local React, ReactRoblox, parent, root
local function position(
	preceding,
	following,
	contains,
	containedBy,
	disconnected,
	implementationSpecific
)
	return {
		preceding = preceding,
		following = following,
		contains = contains,
		containedBy = containedBy,
		disconnected = disconnected,
		implementationSpecific = implementationSpecific,
	}
end
describe("FragmentRefs queries", function()
	beforeEach(function()
		jest.resetModules()
		React = require(Packages.React)
		ReactRoblox = require(Packages.ReactRoblox)
		parent = Instance.new("Folder")
		parent.Parent = game:GetService("ReplicatedStorage")
		root = ReactRoblox.createRoot(parent)
	end)
	afterEach(function()
		ReactRoblox.act(function()
			root:unmount()
		end)
		parent:Destroy()
	end)
	describe("getRootNode", function()
		it("returns the root node of the parent", function()
			local fragmentRef = React.createRef()
			local function Test()
				return React.createElement(
					"Folder",
					nil,
					React.createElement(
						React.Fragment,
						{ ref = fragmentRef },
						React.createElement("Folder")
					)
				)
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			expect(fragmentRef.current:getRootNode()).toBe(game)
		end)
		it(
			"returns the topmost disconnected element if the fragment and parent are unmounted",
			function()
				local containerRef, parentRef, fragmentRef =
					React.createRef(), React.createRef(), React.createRef()
				local function Test(props)
					return React.createElement(
						"Folder",
						{ ref = containerRef, Name = "container" },
						if props.mounted
							then React.createElement(
								"Folder",
								{ ref = parentRef, Name = "parent" },
								React.createElement(
									React.Fragment,
									{ ref = fragmentRef },
									React.createElement("Folder")
								)
							)
							else nil
					)
				end
				ReactRoblox.act(function()
					root:render(React.createElement(Test, { mounted = true }))
				end)
				expect(fragmentRef.current:getRootNode()).toBe(game)
				local fragmentHandle = fragmentRef.current
				ReactRoblox.act(function()
					root:render(React.createElement(Test, { mounted = false }))
				end)
				expect(fragmentHandle:getRootNode()).toBe(fragmentHandle)
			end
		)
		it("returns self when only the fragment was unmounted", function()
			local fragmentRef, parentRef = React.createRef(), React.createRef()
			local function Test(props)
				return React.createElement(
					"Folder",
					{ ref = parentRef, Name = "parent" },
					if props.mounted
						then React.createElement(
							React.Fragment,
							{ ref = fragmentRef },
							React.createElement("Folder")
						)
						else nil
				)
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test, { mounted = true }))
			end)
			expect(fragmentRef.current:getRootNode()).toBe(game)
			local fragmentHandle = fragmentRef.current
			ReactRoblox.act(function()
				root:render(React.createElement(Test, { mounted = false }))
			end)
			expect(fragmentHandle:getRootNode()).toBe(fragmentHandle)
		end)
		-- ROBLOX upstream: https://github.com/facebook/react/blob/1d34f91dfde6bba84d08b683aaba164c7194dacb/packages/react-dom/src/__tests__/ReactDOMFragmentRefs-test.js#L2434-L2577
		-- ROBLOX DEVIATION: Compare logical tree positions, not DOM bit masks. Unknown
		-- Instances have no arbitrary preceding/following order; root maps to container.
	end)
	describe("compareTreePosition", function()
		it(
			"returns the relationship between the fragment instance and a given node",
			function()
				local fragmentRef, beforeRef, afterRef =
					React.createRef(), React.createRef(), React.createRef()
				local middleChildRef, firstChildRef, lastChildRef, containerRef =
					React.createRef(),
					React.createRef(),
					React.createRef(),
					React.createRef()
				local disconnectedElement = Instance.new("Folder")
				local function Test()
					return React.createElement(
						"Folder",
						{ ref = containerRef, Name = "container" },
						{
							React.createElement(
								"Folder",
								{ ref = beforeRef, Name = "before" }
							),
							React.createElement(React.Fragment, { ref = fragmentRef }, {
								React.createElement(
									"Folder",
									{ ref = firstChildRef, Name = "first" }
								),
								React.createElement(
									"Folder",
									{ ref = middleChildRef, Name = "middle" }
								),
								React.createElement(
									"Folder",
									{ ref = lastChildRef, Name = "last" }
								),
							}),
							React.createElement(
								"Folder",
								{ ref = afterRef, Name = "after" }
							),
						}
					)
				end
				ReactRoblox.act(function()
					root:render(React.createElement(Test))
				end)
				expect(fragmentRef.current:compareTreePosition(parent)).toEqual(
					position(true, false, true, false, false, false)
				)
				expect(fragmentRef.current:compareTreePosition(beforeRef.current)).toEqual(
					position(true, false, false, false, false, false)
				)
				expect(fragmentRef.current:compareTreePosition(afterRef.current)).toEqual(
					position(false, true, false, false, false, false)
				)
				expect(fragmentRef.current:compareTreePosition(firstChildRef.current)).toEqual(
					position(false, false, false, true, false, false)
				)
				expect(fragmentRef.current:compareTreePosition(middleChildRef.current)).toEqual(
					position(false, false, false, true, false, false)
				)
				expect(fragmentRef.current:compareTreePosition(lastChildRef.current)).toEqual(
					position(false, false, false, true, false, false)
				)
				expect(fragmentRef.current:compareTreePosition(containerRef.current)).toEqual(
					position(true, false, true, false, false, false)
				)
				expect(fragmentRef.current:compareTreePosition(disconnectedElement)).toEqual(
					position(false, false, false, false, true, true)
				)
				disconnectedElement:Destroy()
			end
		)
		it("handles fragment instances with one child", function()
			local fragmentRef, beforeRef, afterRef, containerRef, onlyChildRef =
				React.createRef(),
				React.createRef(),
				React.createRef(),
				React.createRef(),
				React.createRef()
			local disconnectedElement = Instance.new("Folder")
			local function Test()
				return React.createElement(
					"Folder",
					{ Name = "container", ref = containerRef },
					React.createElement("Folder", { Name = "innercontainer" }, {
						React.createElement(
							"Folder",
							{ ref = beforeRef, Name = "before" }
						),
						React.createElement(
							React.Fragment,
							{ ref = fragmentRef },
							React.createElement(
								"Folder",
								{ ref = onlyChildRef, Name = "within" }
							)
						),
						React.createElement("Folder", { ref = afterRef, Name = "after" }),
					})
				)
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			expect(fragmentRef.current:compareTreePosition(beforeRef.current)).toEqual(
				position(true, false, false, false, false, false)
			)
			expect(fragmentRef.current:compareTreePosition(afterRef.current)).toEqual(
				position(false, true, false, false, false, false)
			)
			expect(fragmentRef.current:compareTreePosition(onlyChildRef.current)).toEqual(
				position(false, false, false, true, false, false)
			)
			expect(fragmentRef.current:compareTreePosition(containerRef.current)).toEqual(
				position(true, false, true, false, false, false)
			)
			expect(fragmentRef.current:compareTreePosition(disconnectedElement)).toEqual(
				position(false, false, false, false, true, true)
			)
			disconnectedElement:Destroy()
		end)
		-- ROBLOX DEVIATION: Empty Fragments have exact logical Fiber positions, so
		-- they need neither DOM fallback ambiguity nor implementation-specific flags.
		it("handles empty fragment instances", function()
			local fragmentRef, beforeParentRef, beforeRef, afterRef, afterParentRef, containerRef =
				React.createRef(),
				React.createRef(),
				React.createRef(),
				React.createRef(),
				React.createRef(),
				React.createRef()
			local function Test()
				return React.createElement(React.Fragment, nil, {
					React.createElement(
						"Folder",
						{ Name = "before-container", ref = beforeParentRef }
					),
					React.createElement(
						"Folder",
						{ Name = "container", ref = containerRef },
						{
							React.createElement(
								"Folder",
								{ Name = "before", ref = beforeRef }
							),
							React.createElement(React.Fragment, { ref = fragmentRef }),
							React.createElement(
								"Folder",
								{ Name = "after", ref = afterRef }
							),
						}
					),
					React.createElement(
						"Folder",
						{ Name = "after-container", ref = afterParentRef }
					),
				})
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			expect(fragmentRef.current:compareTreePosition(parent)).toEqual(
				position(true, false, true, false, false, false)
			)
			expect(fragmentRef.current:compareTreePosition(beforeRef.current)).toEqual(
				position(true, false, false, false, false, false)
			)
			expect(fragmentRef.current:compareTreePosition(beforeParentRef.current)).toEqual(
				position(true, false, false, false, false, false)
			)
			expect(fragmentRef.current:compareTreePosition(afterRef.current)).toEqual(
				position(false, true, false, false, false, false)
			)
			expect(fragmentRef.current:compareTreePosition(afterParentRef.current)).toEqual(
				position(false, true, false, false, false, false)
			)
			expect(fragmentRef.current:compareTreePosition(containerRef.current)).toEqual(
				position(true, false, true, false, false, false)
			)
		end)
		it("handles empty fragments nested inside non-host wrappers", function()
			local fragmentRef, beforeRef, afterRef =
				React.createRef(), React.createRef(), React.createRef()
			local function Wrapper(props)
				return props.children
			end
			local function Test()
				return React.createElement("Folder", nil, {
					React.createElement("Folder", { ref = beforeRef, Name = "before" }),
					React.createElement(
						Wrapper,
						nil,
						React.createElement(React.Fragment, { ref = fragmentRef })
					),
					React.createElement("Folder", { ref = afterRef, Name = "after" }),
				})
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			expect(fragmentRef.current:compareTreePosition(beforeRef.current)).toEqual(
				position(true, false, false, false, false, false)
			)
			expect(fragmentRef.current:compareTreePosition(afterRef.current)).toEqual(
				position(false, true, false, false, false, false)
			)
		end)
		it("handles nested children", function()
			local fragmentRef, nestedFragmentRef, childARef, childBRef, childCRef =
				React.createRef(),
				React.createRef(),
				React.createRef(),
				React.createRef(),
				React.createRef()
			local function Child()
				return React.createElement("Folder", { ref = childCRef, Name = "C" })
			end
			local function Test()
				return React.createElement(React.Fragment, { ref = fragmentRef }, {
					React.createElement("Folder", { ref = childARef, Name = "A" }),
					React.createElement(
						React.Fragment,
						{ ref = nestedFragmentRef },
						React.createElement("Folder", { ref = childBRef, Name = "B" })
					),
					React.createElement(Child),
				})
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			expect(fragmentRef.current:compareTreePosition(childARef.current)).toEqual(
				position(false, false, false, true, false, false)
			)
			expect(fragmentRef.current:compareTreePosition(childBRef.current)).toEqual(
				position(false, false, false, true, false, false)
			)
			expect(fragmentRef.current:compareTreePosition(childCRef.current)).toEqual(
				position(false, false, false, true, false, false)
			)
		end)
		it(
			"returns disconnected for comparison with an unmounted fragment instance",
			function()
				local fragmentRef, containerRef = React.createRef(), React.createRef()
				local function Test(props)
					return React.createElement(
						"Folder",
						{ ref = containerRef },
						if props.mount
							then React.createElement(
								React.Fragment,
								{ ref = fragmentRef },
								React.createElement("Folder")
							)
							else nil
					)
				end
				ReactRoblox.act(function()
					root:render(React.createElement(Test, { mount = true }))
				end)
				local fragmentHandle = fragmentRef.current
				expect(fragmentHandle:compareTreePosition(containerRef.current)).toEqual(
					position(true, false, true, false, false, false)
				)
				ReactRoblox.act(function()
					root:render(React.createElement(Test, { mount = false }))
				end)
				expect(fragmentHandle:compareTreePosition(containerRef.current)).toEqual(
					position(false, false, false, false, true, false)
				)
			end
		)
		it("compares a root-level Fragment", function()
			local fragmentRef, emptyFragmentRef, childRef, siblingPrecedingRef, siblingFollowingRef =
				React.createRef(),
				React.createRef(),
				React.createRef(),
				React.createRef(),
				React.createRef()
			local function Test()
				return React.createElement(React.Fragment, nil, {
					React.createElement("Folder", { ref = siblingPrecedingRef }),
					React.createElement(
						React.Fragment,
						{ ref = fragmentRef },
						React.createElement("Folder", { ref = childRef })
					),
					React.createElement(React.Fragment, { ref = emptyFragmentRef }),
					React.createElement("Folder", { ref = siblingFollowingRef }),
				})
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test))
			end)
			local fragmentInstance, emptyFragmentInstance =
				fragmentRef.current, emptyFragmentRef.current
			assert(fragmentInstance ~= nil, "Expected fragment instance to be non-null")
			assert(
				emptyFragmentInstance ~= nil,
				"Expected empty fragment instance to be non-null"
			)
			expect(fragmentInstance:compareTreePosition(childRef.current)).toEqual(
				position(false, false, false, true, false, false)
			)
			expect(fragmentInstance:compareTreePosition(siblingPrecedingRef.current)).toEqual(
				position(true, false, false, false, false, false)
			)
			expect(fragmentInstance:compareTreePosition(siblingFollowingRef.current)).toEqual(
				position(false, true, false, false, false, false)
			)
			expect(emptyFragmentInstance:compareTreePosition(childRef.current)).toEqual(
				position(true, false, false, false, false, false)
			)
			expect(emptyFragmentInstance:compareTreePosition(siblingPrecedingRef.current)).toEqual(
				position(true, false, false, false, false, false)
			)
			expect(emptyFragmentInstance:compareTreePosition(siblingFollowingRef.current)).toEqual(
				position(false, true, false, false, false, false)
			)
		end)
		-- ROBLOX DEVIATION: Portal relationships retain logical Fiber containment and
		-- order; escaped physical parentage is flagged rather than DOM-ordered.
		describe("with portals", function()
			it("handles portaled elements", function()
				local fragmentRef, portaledSiblingRef, portaledChildRef =
					React.createRef(), React.createRef(), React.createRef()
				local function Test()
					return React.createElement("Folder", { Name = "wrapper" }, {
						ReactRoblox.createPortal(
							React.createElement(
								"Folder",
								{ ref = portaledSiblingRef, Name = "A" }
							),
							parent
						),
						React.createElement(React.Fragment, { ref = fragmentRef }, {
							ReactRoblox.createPortal(
								React.createElement(
									"Folder",
									{ ref = portaledChildRef, Name = "B" }
								),
								parent
							),
							React.createElement("Folder", { Name = "C" }),
						}),
					})
				end
				ReactRoblox.act(function()
					root:render(React.createElement(Test))
				end)
				expect(
					fragmentRef.current:compareTreePosition(portaledSiblingRef.current)
				).toEqual(position(true, false, false, false, false, true))
				expect(fragmentRef.current:compareTreePosition(portaledChildRef.current)).toEqual(
					position(false, false, false, true, false, true)
				)
			end)
			it("handles multiple portals to the same element", function()
				local fragmentRef, childARef, childBRef, childCRef, childDRef, childERef =
					React.createRef(),
					React.createRef(),
					React.createRef(),
					React.createRef(),
					React.createRef(),
					React.createRef()
				local body = Instance.new("Folder")
				body.Parent = parent.Parent
				parent.Name = "container"
				parent.Parent = body
				local function Test()
					local mounted, setMounted = React.useState(false)
					React.useEffect(function()
						setMounted(true)
					end)
					return React.createElement(React.Fragment, nil, {
						ReactRoblox.createPortal(
							React.createElement(React.Fragment, { ref = fragmentRef }, {
								React.createElement(
									"Folder",
									{ Name = "A", ref = childARef }
								),
								mounted and React.createElement(
									"Folder",
									{ Name = "C", ref = childCRef },
									React.createElement(
										"Folder",
										{ Name = "D", ref = childDRef }
									)
								) or nil,
							}),
							body
						),
						ReactRoblox.createPortal(
							React.createElement("Folder", { Name = "B", ref = childBRef }),
							body
						),
						React.createElement("Folder", { Name = "E", ref = childERef }),
					})
				end
				ReactRoblox.act(function()
					root:render(React.createElement(Test))
				end)
				-- ROBLOX DEVIATION: The real client settles passive effects through native
				-- scheduling; DOM outerHTML is represented by physical Instance child names.
				task.wait()
				ReactRoblox.act(function() end)
				local names = {}
				for _, child in body:GetChildren() do
					table.insert(names, child.Name)
				end
				expect(names).toEqual({ "container", "A", "B", "C" })
				expect(parent:GetChildren()[1].Name).toBe("E")
				expect(childCRef.current:GetChildren()[1].Name).toBe("D")
				-- ROBLOX DEVIATION: External shared portal containers have no unique logical Fiber identity.
				expect(fragmentRef.current:compareTreePosition(body)).toEqual(
					position(false, false, false, false, true, true)
				)
				expect(fragmentRef.current:compareTreePosition(childARef.current)).toEqual(
					position(false, false, false, true, false, false)
				)
				expect(fragmentRef.current:compareTreePosition(childBRef.current)).toEqual(
					position(false, true, false, false, false, true)
				)
				expect(fragmentRef.current:compareTreePosition(childCRef.current)).toEqual(
					position(false, false, false, true, false, false)
				)
				expect(fragmentRef.current:compareTreePosition(childDRef.current)).toEqual(
					position(false, false, false, true, false, false)
				)
				expect(fragmentRef.current:compareTreePosition(childERef.current)).toEqual(
					position(false, true, false, false, false, true)
				)
				ReactRoblox.act(function()
					root:unmount()
				end)
				parent.Parent = game:GetService("ReplicatedStorage")
				body:Destroy()
			end)
			it("handles empty fragments", function()
				local fragmentRef, childARef, childBRef =
					React.createRef(), React.createRef(), React.createRef()
				local body = Instance.new("Folder")
				body.Parent = parent.Parent
				parent.Parent = body
				local function Test()
					return React.createElement(React.Fragment, nil, {
						React.createElement("Folder", { ref = childARef, Name = "A" }),
						ReactRoblox.createPortal(
							React.createElement(React.Fragment, { ref = fragmentRef }),
							body
						),
						React.createElement("Folder", { ref = childBRef, Name = "B" }),
					})
				end
				ReactRoblox.act(function()
					root:render(React.createElement(Test))
				end)
				expect(fragmentRef.current:compareTreePosition(body)).toEqual(
					position(false, false, false, false, true, true)
				)
				expect(fragmentRef.current:compareTreePosition(childARef.current)).toEqual(
					position(true, false, false, false, false, true)
				)
				expect(fragmentRef.current:compareTreePosition(childBRef.current)).toEqual(
					position(false, true, false, false, false, true)
				)
				ReactRoblox.act(function()
					root:unmount()
				end)
				parent.Parent = game:GetService("ReplicatedStorage")
				body:Destroy()
			end)
			it(
				"positions empty portaled fragments against the portal container",
				function()
					local fragmentRef, reactParentRef =
						React.createRef(), React.createRef()
					local portalTarget = Instance.new("Folder")
					portalTarget.Name = "portal-target"
					portalTarget.Parent = parent.Parent
					local function Test()
						return React.createElement(
							"Folder",
							{ ref = reactParentRef, Name = "react-parent" },
							ReactRoblox.createPortal(
								React.createElement(React.Fragment, { ref = fragmentRef }),
								portalTarget
							)
						)
					end
					ReactRoblox.act(function()
						root:render(React.createElement(Test))
					end)
					-- ROBLOX DEVIATION: An external portal container is not a unique logical
					-- Fiber; the React parent remains a logical ancestor despite physical escape.
					expect(fragmentRef.current:compareTreePosition(portalTarget)).toEqual(
						position(false, false, false, false, true, true)
					)
					expect(
						fragmentRef.current:compareTreePosition(reactParentRef.current)
					).toEqual(position(true, false, true, false, false, true))
					ReactRoblox.act(function()
						root:unmount()
					end)
					portalTarget:Destroy()
				end
			)
			-- ROBLOX DEVIATION: An owning portal determines the Fragment's physical
			-- root. Portals emitted by its children do not move the Fragment position.
		end)
	end)
	describe("Roblox host adapters", function()
		it("returns the physical root of an owning disconnected portal", function()
			local fragmentRef, ordinaryRef = React.createRef(), React.createRef()
			local portalTarget = Instance.new("Folder")
			ReactRoblox.act(function()
				root:render(React.createElement(React.Fragment, nil, {
					React.createElement(
						React.Fragment,
						{ ref = ordinaryRef },
						React.createElement("Folder")
					),
					ReactRoblox.createPortal(
						React.createElement(
							React.Fragment,
							{ ref = fragmentRef },
							React.createElement("Folder")
						),
						portalTarget
					),
				}))
			end)
			expect(ordinaryRef.current:getRootNode()).toBe(game)
			expect(fragmentRef.current:getRootNode()).toBe(portalTarget)
			ReactRoblox.act(function()
				root:unmount()
			end)
			portalTarget:Destroy()
		end)
		it("preserves inverse relationships and committed sibling order", function()
			local outerRef, firstRef, secondRef, secondHostRef =
				React.createRef(), React.createRef(), React.createRef(), React.createRef()
			local function Test(props)
				local first = React.createElement(
					React.Fragment,
					{ key = "first", ref = firstRef },
					React.createElement("Folder")
				)
				local second = React.createElement(
					React.Fragment,
					{ key = "second", ref = secondRef },
					React.createElement("Folder", { ref = secondHostRef })
				)
				return React.createElement(
					React.Fragment,
					{ ref = outerRef },
					if props.reverse then { second, first } else { first, second }
				)
			end
			ReactRoblox.act(function()
				root:render(React.createElement(Test, { reverse = false }))
			end)
			expect(firstRef.current:compareTreePosition(firstRef.current)).toEqual(
				position(false, false, false, false, false, false)
			)
			expect(firstRef.current:compareTreePosition(secondRef.current)).toEqual(
				position(false, true, false, false, false, false)
			)
			expect(secondRef.current:compareTreePosition(firstRef.current)).toEqual(
				position(true, false, false, false, false, false)
			)
			expect(outerRef.current:compareTreePosition(firstRef.current)).toEqual(
				position(false, false, false, true, false, false)
			)
			expect(firstRef.current:compareTreePosition(outerRef.current)).toEqual(
				position(true, false, true, false, false, false)
			)
			ReactRoblox.act(function()
				root:render(React.createElement(Test, { reverse = true }))
			end)
			expect(firstRef.current:compareTreePosition(secondRef.current)).toEqual(
				position(true, false, false, false, false, false)
			)
			expect(secondRef.current:compareTreePosition(firstRef.current)).toEqual(
				position(false, true, false, false, false, false)
			)
			expect(firstRef.current:compareTreePosition(secondHostRef.current)).toEqual(
				position(true, false, false, false, false, false)
			)
		end)
		it(
			"reports separate renderer roots and known deleted handles as disconnected",
			function()
				local firstRef, secondRef = React.createRef(), React.createRef()
				local secondContainer = Instance.new("Folder")
				secondContainer.Parent = parent.Parent
				local secondRoot = ReactRoblox.createRoot(secondContainer)
				ReactRoblox.act(function()
					root:render(
						React.createElement(
							React.Fragment,
							{ ref = firstRef },
							React.createElement("Folder")
						)
					)
					secondRoot:render(
						React.createElement(
							React.Fragment,
							{ ref = secondRef },
							React.createElement("Folder")
						)
					)
				end)
				local secondHandle = secondRef.current
				expect(firstRef.current:compareTreePosition(secondHandle)).toEqual(
					position(false, false, false, false, true, true)
				)
				expect(secondHandle:compareTreePosition(firstRef.current)).toEqual(
					position(false, false, false, false, true, true)
				)
				ReactRoblox.act(function()
					secondRoot:unmount()
				end)
				expect(firstRef.current:compareTreePosition(secondHandle)).toEqual(
					position(false, false, false, false, true, false)
				)
				expect(secondHandle:compareTreePosition(firstRef.current)).toEqual(
					position(false, false, false, false, true, false)
				)
				secondContainer:Destroy()
			end
		)
	end)
end)

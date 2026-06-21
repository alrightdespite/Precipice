local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local MarketController = require(script.Parent.Parent.Controllers.MarketController)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek
local doCleanup = Fusion.doCleanup

local function formatNum(n: number): string
	if n >= 1000000 then
		return string.format("%.1fM", n / 1000000)
	end
	if n >= 1000 then
		return string.format("%.1fK", n / 1000)
	end
	return tostring(math.floor(n))
end

local TAB_BROWSE = "Browse"
local TAB_MY = "My Listings"

local MarketScreen = {}
local _scope = nil

function MarketScreen.open(uiController)
	if _scope then
		return
	end
	_scope = Fusion.scoped(Fusion)
	local scope = _scope

	local activeTab = scope:Value(TAB_BROWSE)
	local activeTierFilter = scope:Value(nil :: number?)
	local listings = scope:Value({} :: { any })
	local myListings = scope:Value({} :: { any })
	local isLoading = scope:Value(false)
	local statusMsg = scope:Value("")
	local currentPage = scope:Value(1)

	local showModal = scope:Value(false)
	local modalCompound = scope:Value("")
	local modalQty = scope:Value("")
	local modalPrice = scope:Value("")

	local feePreview = scope:Computed(function(use)
		local price = tonumber(use(modalPrice)) or 0
		local qty = tonumber(use(modalQty)) or 0
		if price <= 0 or qty <= 0 then
			return ""
		end
		local fee = math.floor(price * qty * 0.01)
		local receive = math.floor(price * qty * 0.95)
		return string.format("Fee: %s ◈ · You receive: %s ◈", formatNum(fee), formatNum(receive))
	end)

	local function loadBrowse()
		isLoading:set(true)
		local tier = peek(activeTierFilter)
		local page = peek(currentPage)
		task.spawn(function()
			local ok, result = MarketController.browse(tier, page)
			isLoading:set(false)
			if ok and type(result) == "table" then
				if page == 1 then
					listings:set(result)
				else
					local combined = table.clone(peek(listings))
					for _, e in ipairs(result) do
						table.insert(combined, e)
					end
					listings:set(combined)
				end
			end
		end)
	end

	local function buildListingCard(entry, isMine: boolean)
		local statusLabel = scope:Value(isMine and "Cancel" or "Buy")
		return scope:New("Frame")({
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundColor3 = Theme.Colors.SurfaceRaised,
			BorderSizePixel = 0,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 96),
					PaddingTop = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 6),
				}),
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				scope:New("TextLabel")({
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, 22),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.TextPrimary,
					FontFace = Theme.Font.Label,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = (entry.compoundId or "?") .. " ×" .. tostring(entry.quantity or 0),
				}),
				scope:New("TextLabel")({
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 16),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.TextSecondary,
					FontFace = Theme.Font.Body,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = formatNum(entry.price or 0) .. " ◈ each · " .. tostring(entry.sellerId or "?"),
				}),
				scope:New("Frame")({
					Name = "ActionWrap",
					Size = UDim2.fromOffset(80, 40),
					Position = UDim2.new(1, -88, 0.5, -20),
					BackgroundTransparency = 1,
					[Children] = {
						Components.Button(scope, {
							Text = statusLabel,
							Style = isMine and "danger" or "primary",
							OnClick = function()
								task.spawn(function()
									if isMine then
										local ok, err = MarketController.cancelListing(entry.listingId)
										if not ok then
											statusMsg:set(tostring(err))
										end
									else
										statusLabel:set("…")
										local ok, err = MarketController.buyListing(entry.listingId)
										if ok then
											statusLabel:set("Bought!")
										else
											statusLabel:set(tostring(err))
											task.delay(2, function()
												statusLabel:set("Buy")
											end)
										end
									end
								end)
							end,
						}),
					},
				}),
			},
		})
	end

	-- Tab bar
	local tabFrames = {}
	for _, tabName in ipairs({ TAB_BROWSE, TAB_MY }) do
		local t = tabName
		table.insert(
			tabFrames,
			scope:New("TextButton")({
				Size = UDim2.new(0.5, 0, 1, 0),
				BackgroundColor3 = scope:Computed(function(use)
					return use(activeTab) == t and Theme.Colors.AccentDim or Theme.Colors.Surface
				end),
				BorderSizePixel = 0,
				Text = "",
				[Children] = {
					scope:New("TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						TextColor3 = scope:Computed(function(use)
							return use(activeTab) == t and Theme.Colors.Accent or Theme.Colors.TextSecondary
						end),
						FontFace = Theme.Font.Label,
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Center,
						Text = t,
					}),
				},
				[OnEvent("Activated")] = function()
					activeTab:set(t)
					if t == TAB_BROWSE then
						currentPage:set(1)
						loadBrowse()
					end
				end,
			})
		)
	end

	-- Tier filter
	local tierBtns = {}
	for i = 1, 7 do
		local tier = i
		table.insert(
			tierBtns,
			scope:New("TextButton")({
				Size = UDim2.fromOffset(36, 28),
				BackgroundColor3 = scope:Computed(function(use)
					return use(activeTierFilter) == tier and Theme.Colors.Tier[tier] or Theme.Colors.SurfaceRaised
				end),
				BorderSizePixel = 0,
				Text = "",
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
					scope:New("TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						TextColor3 = Color3.new(1, 1, 1),
						FontFace = Theme.Font.Label,
						TextSize = 11,
						TextXAlignment = Enum.TextXAlignment.Center,
						Text = "T" .. i,
					}),
				},
				[OnEvent("Activated")] = function()
					activeTierFilter:set(peek(activeTierFilter) == tier and nil or tier)
					currentPage:set(1)
					loadBrowse()
				end,
			})
		)
	end

	-- Modal
	local modal = scope:New("Frame")({
		Name = "Modal",
		Size = UDim2.new(0.9, 0, 0, 300),
		Position = UDim2.new(0.05, 0, 0.15, 0),
		BackgroundColor3 = Theme.Colors.Surface,
		BorderSizePixel = 0,
		ZIndex = 20,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 16),
				PaddingTop = UDim.new(0, 16),
				PaddingBottom = UDim.new(0, 16),
			}),
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10),
			}),
			scope:New("TextLabel")({
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.TextPrimary,
				FontFace = Theme.Font.Header,
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = "Create Listing",
			}),
			scope:New("TextBox")({
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = Theme.Colors.SurfaceRaised,
				BorderSizePixel = 0,
				TextColor3 = Theme.Colors.TextPrimary,
				FontFace = Theme.Font.Body,
				TextSize = 13,
				PlaceholderText = "Compound ID",
				Text = modalCompound,
				ClearTextOnFocus = false,
				[Fusion.OnChange("Text")] = function(val)
					modalCompound:set(val)
				end,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 8) }),
				},
			}),
			scope:New("TextBox")({
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = Theme.Colors.SurfaceRaised,
				BorderSizePixel = 0,
				TextColor3 = Theme.Colors.TextPrimary,
				FontFace = Theme.Font.Body,
				TextSize = 13,
				PlaceholderText = "Quantity",
				Text = modalQty,
				ClearTextOnFocus = false,
				[Fusion.OnChange("Text")] = function(val)
					modalQty:set(val)
				end,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 8) }),
				},
			}),
			scope:New("TextBox")({
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = Theme.Colors.SurfaceRaised,
				BorderSizePixel = 0,
				TextColor3 = Theme.Colors.TextPrimary,
				FontFace = Theme.Font.Body,
				TextSize = 13,
				PlaceholderText = "Price per unit",
				Text = modalPrice,
				ClearTextOnFocus = false,
				[Fusion.OnChange("Text")] = function(val)
					modalPrice:set(val)
				end,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 8) }),
				},
			}),
			scope:New("TextLabel")({
				LayoutOrder = 5,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.TextSecondary,
				FontFace = Theme.Font.Body,
				TextSize = 11,
				Text = feePreview,
			}),
			scope:New("Frame")({
				LayoutOrder = 6,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 8),
					}),
					scope:New("Frame")({
						Size = UDim2.new(0.6, -4, 1, 0),
						BackgroundTransparency = 1,
						[Children] = {
							Components.Button(scope, {
								Text = "Confirm",
								OnClick = function()
									local compound = peek(modalCompound)
									local qty = tonumber(peek(modalQty))
									local price = tonumber(peek(modalPrice))
									if not compound or compound == "" or not qty or not price then
										return
									end
									task.spawn(function()
										local ok, err = MarketController.createListing(compound, qty, price)
										if ok then
											showModal:set(false)
											statusMsg:set("Listing created.")
										else
											statusMsg:set(tostring(err))
										end
									end)
								end,
							}),
						},
					}),
					scope:New("Frame")({
						Size = UDim2.new(0.4, -4, 1, 0),
						BackgroundTransparency = 1,
						[Children] = {
							Components.Button(scope, {
								Text = "Cancel",
								Style = "secondary",
								OnClick = function()
									showModal:set(false)
								end,
							}),
						},
					}),
				},
			}),
		},
	})

	loadBrowse()

	scope:New("ScreenGui")({
		Name = "MarketScreen",
		Enabled = true,
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Parent = Players.LocalPlayer.PlayerGui,
		[Children] = {
			scope:New("TextButton")({
				Name = "CloseBtn",
				Size = UDim2.fromOffset(36, 36),
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 8),
				BackgroundTransparency = 1,
				Text = "✕",
				TextColor3 = Theme.Colors.TextSecondary,
				FontFace = Theme.Font.Header,
				TextSize = 20,
				ZIndex = 20,
				[OnEvent("Activated")] = function()
					if uiController then
						uiController.openScreen("Home")
					end
				end,
			}),
			scope:New("Frame")({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, 56),
				BackgroundColor3 = Theme.Colors.Surface,
				BorderSizePixel = 0,
				[Children] = {
					scope:New("TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.TextPrimary,
						FontFace = Theme.Font.Header,
						TextSize = 18,
						TextXAlignment = Enum.TextXAlignment.Center,
						Text = "Market",
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Tabs",
				Size = UDim2.new(1, 0, 0, 44),
				Position = UDim2.fromOffset(0, 56),
				BackgroundColor3 = Theme.Colors.Surface,
				BorderSizePixel = 0,
				[Children] = {
					scope:New("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal }),
					table.unpack(tabFrames),
				},
			}),
			-- Browse panel
			scope:New("Frame")({
				Name = "BrowsePanel",
				Size = UDim2.new(1, -24, 1, -140),
				Position = UDim2.fromOffset(12, 108),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use)
					return use(activeTab) == TAB_BROWSE
				end),
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
					}),
					scope:New("Frame")({
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 36),
						BackgroundTransparency = 1,
						[Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								Padding = UDim.new(0, 4),
							}),
							table.unpack(tierBtns),
						},
					}),
					scope:New("ScrollingFrame")({
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 1, -100),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ScrollBarThickness = 0,
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						CanvasSize = UDim2.fromScale(0, 0),
						[Children] = {
							scope:New("UIListLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 4),
							}),
							scope:Computed(function(use)
								local rows = {}
								for _, entry in ipairs(use(listings)) do
									table.insert(rows, buildListingCard(entry, false))
								end
								return rows
							end),
						},
					}),
					scope:New("Frame")({
						LayoutOrder = 3,
						Size = UDim2.new(1, 0, 0, 44),
						BackgroundTransparency = 1,
						[Children] = {
							Components.Button(scope, {
								Text = "Load more",
								Style = "secondary",
								OnClick = function()
									currentPage:set(peek(currentPage) + 1)
									loadBrowse()
								end,
							}),
						},
					}),
					scope:New("TextLabel")({
						LayoutOrder = 4,
						Size = UDim2.new(1, 0, 0, 20),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.TextSecondary,
						FontFace = Theme.Font.Body,
						TextSize = 11,
						Text = statusMsg,
					}),
				},
			}),
			-- My listings panel
			scope:New("Frame")({
				Name = "MyListingsPanel",
				Size = UDim2.new(1, -24, 1, -140),
				Position = UDim2.fromOffset(12, 108),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use)
					return use(activeTab) == TAB_MY
				end),
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
					}),
					scope:New("Frame")({
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 44),
						BackgroundTransparency = 1,
						[Children] = {
							Components.Button(scope, {
								Text = "+ Create listing",
								OnClick = function()
									modalCompound:set("")
									modalQty:set("")
									modalPrice:set("")
									showModal:set(true)
								end,
							}),
						},
					}),
					scope:New("ScrollingFrame")({
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 1, -60),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ScrollBarThickness = 0,
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						CanvasSize = UDim2.fromScale(0, 0),
						[Children] = {
							scope:New("UIListLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 4),
							}),
							scope:Computed(function(use)
								local rows = {}
								for _, entry in ipairs(use(myListings)) do
									table.insert(rows, buildListingCard(entry, true))
								end
								return rows
							end),
						},
					}),
				},
			}),
			-- Modal overlay
			scope:New("Frame")({
				Name = "ModalOverlay",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
				ZIndex = 19,
				Visible = showModal,
				[Children] = { modal },
			}),
		},
	})
end

function MarketScreen.close()
	if _scope then
		doCleanup(_scope)
		_scope = nil
	end
end

return MarketScreen

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local EconomyConstants = require(ReplicatedStorage.Shared.Config.EconomyConstants)
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local SyndicateController = require(script.Parent.Parent.Controllers.SyndicateController)
local JointController = require(script.Parent.Parent.Controllers.JointController)

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

-- Keys/costs must match SyndicateService.purchaseUpgrade's validUpgrades + the
-- §17 crest progression (animated requires crest, broadcast requires animated).
local SYNDICATE_UPGRADES = {
	{ key = "thirdSlot", label = "Third Joint Slot", cost = EconomyConstants.SYNDICATE_THIRD_SLOT_COST },
	{ key = "crest", label = "Syndicate Crest", cost = EconomyConstants.SYNDICATE_CREST_COST },
	{ key = "animatedCrest", label = "Animated Crest", cost = EconomyConstants.SYNDICATE_ANIMATED_CREST_COST },
	{ key = "broadcastCrest", label = "Broadcast Crest", cost = EconomyConstants.SYNDICATE_BROADCAST_CREST_COST },
}

local SyndicateScreen = {}
local _scope = nil

function SyndicateScreen.open(uiController)
	if _scope then
		return
	end
	_scope = Fusion.scoped(Fusion)
	local scope = _scope
	local st = StateController.get()

	local syndicateValue = scope:Value(st.syndicate)
	local pendingInviteValue = scope:Value(st.pendingInvite)
	local statusMsg = scope:Value("")
	local disbandConfirm = scope:Value(false)
	local contributeInput = scope:Value("")
	local createNameInput = scope:Value("")
	local inviteInput = scope:Value("")

	local localUserId = Players.LocalPlayer and Players.LocalPlayer.UserId or 0

	table.insert(
		scope,
		StateController.Changed:Connect(function(patch)
			if patch.syndicate ~= nil then
				syndicateValue:set(patch.syndicate)
			end
			if patch.pendingInvite ~= nil then
				pendingInviteValue:set(patch.pendingInvite)
			end
		end)
	)

	local hasSyndicate = scope:Computed(function(use)
		return use(syndicateValue) ~= nil
	end)

	local function setStatus(msg: string)
		statusMsg:set(msg)
		task.delay(3, function()
			if peek(statusMsg) == msg then
				statusMsg:set("")
			end
		end)
	end

	-- Member role for local player
	local localRole = scope:Computed(function(use)
		local syn = use(syndicateValue)
		if not syn then
			return nil
		end
		local member = syn.members[localUserId]
		return member and member.role or nil
	end)
	local canManage = scope:Computed(function(use)
		local role = use(localRole)
		return role == "Founder" or role == "Officer"
	end)

	-- Build member row
	local function buildMemberRow(userId: number, memberData: { role: string, displayName: string })
		return scope:New("Frame")({
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = Theme.Colors.SurfaceRaised,
			BorderSizePixel = 0,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
					PaddingTop = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 6),
				}),
				scope:New("TextLabel")({
					Size = UDim2.new(1, -120, 1, 0),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.TextPrimary,
					FontFace = Theme.Font.Label,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = memberData.displayName ~= "" and memberData.displayName or tostring(userId),
				}),
				-- Role badge
				scope:New("Frame")({
					Size = UDim2.fromOffset(64, 24),
					Position = UDim2.new(1, -140, 0.5, -12),
					BackgroundColor3 = memberData.role == "Founder" and Theme.Colors.Accent
						or memberData.role == "Officer" and Theme.Colors.AccentDim
						or Theme.Colors.SurfaceRaised,
					BorderSizePixel = 0,
					[Children] = {
						scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
						scope:New("TextLabel")({
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							TextColor3 = Color3.new(1, 1, 1),
							FontFace = Theme.Font.Label,
							TextSize = 10,
							TextXAlignment = Enum.TextXAlignment.Center,
							Text = memberData.role,
						}),
					},
				}),
				-- Manage buttons (only shown to founders/officers, not for self)
				scope:New("Frame")({
					Size = UDim2.fromOffset(60, 36),
					Position = UDim2.new(1, -64, 0.5, -18),
					BackgroundTransparency = 1,
					Visible = scope:Computed(function(use)
						return use(canManage) and userId ~= localUserId
					end),
					[Children] = {
						scope:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							Padding = UDim.new(0, 4),
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
						Components.Button(scope, {
							Text = "Kick",
							Style = "danger",
							Size = UDim2.fromOffset(28, 28),
							OnClick = function()
								task.spawn(function()
									local ok, err = SyndicateController.kick(userId)
									if not ok then
										setStatus(tostring(err))
									end
								end)
							end,
						}),
					},
				}),
			},
		})
	end

	-- Build joint slot card
	local function buildJointSlot(slotIdx: number)
		local slotData = scope:Computed(function(use)
			local syn = use(syndicateValue)
			if not syn or not syn.jointSlots then
				return nil
			end
			return syn.jointSlots[slotIdx]
		end)
		local slotState = scope:Computed(function(use)
			local sd = use(slotData)
			return sd and sd.state or "EMPTY"
		end)

		return scope:New("Frame")({
			Size = UDim2.new(1, 0, 0, 72),
			BackgroundColor3 = Theme.Colors.SurfaceRaised,
			BorderSizePixel = 0,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
					PaddingTop = UDim.new(0, 8),
					PaddingBottom = UDim.new(0, 8),
				}),
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				scope:New("TextLabel")({
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.TextSecondary,
					FontFace = Theme.Font.Label,
					TextSize = 11,
					Text = "Joint Slot " .. slotIdx,
				}),
				scope:New("TextLabel")({
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundTransparency = 1,
					TextColor3 = scope:Computed(function(use)
						local s = use(slotState)
						if s == "RUNNING" then
							return Theme.Colors.Accent
						end
						if s == "COMPLETE" then
							return Theme.Colors.Success
						end
						return Theme.Colors.TextPrimary
					end),
					FontFace = Theme.Font.Label,
					TextSize = 13,
					Text = slotState,
				}),
				scope:New("Frame")({
					LayoutOrder = 3,
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundTransparency = 1,
					[Children] = {
						scope:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							Padding = UDim.new(0, 6),
						}),
						Components.Button(scope, {
							Text = "Cancel",
							Style = "danger",
							Size = UDim2.fromOffset(64, 28),
							Disabled = scope:Computed(function(use)
								local s = use(slotState)
								return s == "EMPTY" or s == "COMPLETE"
							end),
							OnClick = function()
								task.spawn(function()
									local ok, err = JointController.cancel(slotIdx)
									if not ok then
										setStatus(tostring(err))
									end
								end)
							end,
						}),
					},
				}),
			},
		})
	end

	-- No syndicate view
	local noSynView = scope:New("Frame")({
		Name = "NoSyndicate",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use)
			return not use(hasSyndicate)
		end),
		[Children] = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 24),
				PaddingRight = UDim.new(0, 24),
				PaddingTop = UDim.new(0, 16),
			}),
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 12),
			}),
			-- Pending invite card
			scope:New("Frame")({
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 68),
				BackgroundColor3 = Theme.Colors.AccentDim,
				BorderSizePixel = 0,
				Visible = scope:Computed(function(use)
					return use(pendingInviteValue) ~= nil
				end),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 12),
						PaddingRight = UDim.new(0, 12),
						PaddingTop = UDim.new(0, 8),
						PaddingBottom = UDim.new(0, 8),
					}),
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					scope:New("TextLabel")({
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 18),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.Accent,
						FontFace = Theme.Font.Label,
						TextSize = 13,
						Text = scope:Computed(function(use)
							local inv = use(pendingInviteValue)
							return inv and ("Invite: " .. inv.syndicateName) or ""
						end),
					}),
					scope:New("Frame")({
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 0, 32),
						BackgroundTransparency = 1,
						[Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								Padding = UDim.new(0, 8),
							}),
							Components.Button(scope, {
								Text = "Accept",
								Size = UDim2.fromOffset(80, 32),
								OnClick = function()
									local inv = peek(pendingInviteValue)
									if not inv then
										return
									end
									task.spawn(function()
										local ok, err = SyndicateController.acceptInvite(inv.syndicateId)
										if not ok then
											setStatus(tostring(err))
										end
									end)
								end,
							}),
							Components.Button(scope, {
								Text = "Decline",
								Style = "secondary",
								Size = UDim2.fromOffset(80, 32),
								OnClick = function()
									task.spawn(function()
										SyndicateController.declineInvite()
										StateController.set({ pendingInvite = nil })
									end)
								end,
							}),
						},
					}),
				},
			}),
			-- Create syndicate
			scope:New("TextLabel")({
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.TextSecondary,
				FontFace = Theme.Font.Body,
				TextSize = 13,
				Text = "You are not in a syndicate.",
			}),
			scope:New("TextBox")({
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = Theme.Colors.SurfaceRaised,
				BorderSizePixel = 0,
				TextColor3 = Theme.Colors.TextPrimary,
				FontFace = Theme.Font.Body,
				TextSize = 13,
				PlaceholderText = "Syndicate name",
				Text = createNameInput,
				ClearTextOnFocus = false,
				[Fusion.OnChange("Text")] = function(v)
					createNameInput:set(v)
				end,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 8) }),
				},
			}),
			scope:New("Frame")({
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
				[Children] = {
					Components.Button(scope, {
						Text = "Create Syndicate",
						OnClick = function()
							local name = peek(createNameInput)
							if name == "" then
								return
							end
							task.spawn(function()
								local ok, err = SyndicateController.create(name)
								if not ok then
									setStatus(tostring(err))
								end
							end)
						end,
					}),
				},
			}),
		},
	})

	-- In syndicate view
	local inSynView = scope:New("ScrollingFrame")({
		Name = "InSyndicate",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromScale(0, 0),
		Visible = hasSyndicate,
		[Children] = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 16),
			}),
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			-- Header info
			scope:New("Frame")({
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 56),
				BackgroundColor3 = Theme.Colors.Surface,
				BorderSizePixel = 0,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 12),
						PaddingRight = UDim.new(0, 12),
						PaddingTop = UDim.new(0, 8),
					}),
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 2),
					}),
					scope:New("TextLabel")({
						Size = UDim2.new(1, 0, 0, 22),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.TextPrimary,
						FontFace = Theme.Font.Header,
						TextSize = 16,
						Text = scope:Computed(function(use)
							local syn = use(syndicateValue)
							return syn and syn.name or ""
						end),
					}),
					scope:New("TextLabel")({
						Size = UDim2.new(1, 0, 0, 14),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.TextSecondary,
						FontFace = Theme.Font.Body,
						TextSize = 11,
						Text = scope:Computed(function(use)
							local syn = use(syndicateValue)
							if not syn then
								return ""
							end
							local count = 0
							for _ in pairs(syn.members) do
								count += 1
							end
							return count .. "/" .. (syn.memberCap or 10) .. " members · " .. formatNum(syn.vaultBalance or 0) .. " ◈ vault"
						end),
					}),
				},
			}),
			-- Members section
			scope:New("TextLabel")({
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.TextSecondary,
				FontFace = Theme.Font.Label,
				TextSize = 11,
				Text = "MEMBERS",
			}),
			scope:New("Frame")({
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					scope:Computed(function(use)
						local syn = use(syndicateValue)
						if not syn then
							return {}
						end
						local rows = {}
						for uid, memberData in pairs(syn.members) do
							table.insert(rows, buildMemberRow(uid, memberData))
						end
						return rows
					end),
				},
			}),
			-- Invite
			scope:New("TextLabel")({
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.TextSecondary,
				FontFace = Theme.Font.Label,
				TextSize = 11,
				Text = "INVITE (user ID)",
				Visible = canManage,
			}),
			scope:New("Frame")({
				LayoutOrder = 5,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
				Visible = canManage,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 8),
					}),
					scope:New("TextBox")({
						Size = UDim2.new(0.6, -4, 1, 0),
						BackgroundColor3 = Theme.Colors.SurfaceRaised,
						BorderSizePixel = 0,
						TextColor3 = Theme.Colors.TextPrimary,
						FontFace = Theme.Font.Body,
						TextSize = 13,
						PlaceholderText = "User ID",
						Text = inviteInput,
						ClearTextOnFocus = false,
						[Fusion.OnChange("Text")] = function(v)
							inviteInput:set(v)
						end,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
							scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 8) }),
						},
					}),
					scope:New("Frame")({
						Size = UDim2.new(0.4, -4, 1, 0),
						BackgroundTransparency = 1,
						[Children] = {
							Components.Button(scope, {
								Text = "Invite",
								OnClick = function()
									local uid = tonumber(peek(inviteInput))
									if not uid then
										return
									end
									task.spawn(function()
										local ok, err = SyndicateController.invite(uid)
										if ok then
											setStatus("Invite sent.")
											inviteInput:set("")
										else
											setStatus(tostring(err))
										end
									end)
								end,
							}),
						},
					}),
				},
			}),
			-- Vault contribution
			scope:New("TextLabel")({
				LayoutOrder = 6,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.TextSecondary,
				FontFace = Theme.Font.Label,
				TextSize = 11,
				Text = "CONTRIBUTE TO VAULT",
			}),
			scope:New("Frame")({
				LayoutOrder = 7,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
					scope:New("TextBox")({
						Size = UDim2.new(0.6, -4, 1, 0),
						BackgroundColor3 = Theme.Colors.SurfaceRaised,
						BorderSizePixel = 0,
						TextColor3 = Theme.Colors.TextPrimary,
						FontFace = Theme.Font.Body,
						TextSize = 13,
						PlaceholderText = "Amount",
						Text = contributeInput,
						ClearTextOnFocus = false,
						[Fusion.OnChange("Text")] = function(v)
							contributeInput:set(v)
						end,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
							scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 8) }),
						},
					}),
					scope:New("Frame")({
						Size = UDim2.new(0.4, -4, 1, 0),
						BackgroundTransparency = 1,
						[Children] = {
							Components.Button(scope, {
								Text = "Contribute",
								OnClick = function()
									local amt = tonumber(peek(contributeInput))
									if not amt or amt <= 0 then
										return
									end
									task.spawn(function()
										local ok, err = SyndicateController.contributeVault(amt)
										if ok then
											setStatus("Contributed!")
											contributeInput:set("")
										else
											setStatus(tostring(err))
										end
									end)
								end,
							}),
						},
					}),
				},
			}),
			-- Upgrades
			scope:New("TextLabel")({
				LayoutOrder = 8,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.TextSecondary,
				FontFace = Theme.Font.Label,
				TextSize = 11,
				Text = "UPGRADES",
			}),
			scope:New("Frame")({
				LayoutOrder = 9,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = (function()
					local items = {
						scope:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Vertical,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 4),
						}),
					}
					for i, upg in ipairs(SYNDICATE_UPGRADES) do
						local upgKey = upg.key
						local owned = scope:Computed(function(use)
							local syn = use(syndicateValue)
							return syn and syn.upgrades and syn.upgrades[upgKey] == true or false
						end)
						table.insert(
							items,
							scope:New("Frame")({
								LayoutOrder = i, AutomaticSize = Enum.AutomaticSize.Y,
								Size = UDim2.new(1, 0, 0, 44),
								BackgroundColor3 = Theme.Colors.SurfaceRaised,
								BorderSizePixel = 0,
								[Children] = {
									scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
									scope:New("UIPadding")({
										PaddingLeft = UDim.new(0, 12),
										PaddingRight = UDim.new(0, 10),
										PaddingTop = UDim.new(0, 4),
									}),
									scope:New("UIListLayout")({ FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
									scope:New("TextLabel")({
										LayoutOrder = 1,
										Size = UDim2.new(1, 0, 0, 18),
										BackgroundTransparency = 1,
										TextColor3 = Theme.Colors.TextPrimary,
										FontFace = Theme.Font.Label,
										TextSize = 13,
										Text = upg.label,
									}),
									scope:New("TextLabel")({
										LayoutOrder = 2,
										Size = UDim2.new(1, 0, 0, 14),
										BackgroundTransparency = 1,
										TextColor3 = scope:Computed(function(use)
											return use(owned) and Theme.Colors.Success or Theme.Colors.TextSecondary
										end),
										FontFace = Theme.Font.Body,
										TextSize = 11,
										Text = scope:Computed(function(use)
											return use(owned) and "Owned" or formatNum(upg.cost) .. " ◈"
										end),
									}),
									scope:New("Frame")({
										Size = UDim2.fromOffset(80, 32),
										LayoutOrder = 3,
										BackgroundTransparency = 1,
										[Children] = {
											Components.Button(scope, {
												Text = "Buy",
												Disabled = owned,
												OnClick = function()
													task.spawn(function()
														local ok, err = SyndicateController.purchaseUpgrade(upgKey)
														if not ok then
															setStatus(tostring(err))
														end
													end)
												end,
											}),
										},
									}),
								},
							})
						)
					end
					return items
				end)(),
			}),
			-- Joint slots
			scope:New("TextLabel")({
				LayoutOrder = 10,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.TextSecondary,
				FontFace = Theme.Font.Label,
				TextSize = 11,
				Text = "JOINT SLOTS",
			}),
			scope:New("Frame")({
				LayoutOrder = 11,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({ FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 4) }),
					buildJointSlot(1),
					buildJointSlot(2),
					buildJointSlot(3),
				},
			}),
			-- Status message
			scope:New("TextLabel")({
				LayoutOrder = 12,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.TextSecondary,
				FontFace = Theme.Font.Body,
				TextSize = 11,
				Text = statusMsg,
			}),
			-- Danger zone
			scope:New("TextLabel")({
				LayoutOrder = 13,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Danger,
				FontFace = Theme.Font.Label,
				TextSize = 11,
				Text = "DANGER ZONE",
			}),
			scope:New("Frame")({
				LayoutOrder = 14,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
					scope:New("Frame")({
						Size = UDim2.new(0.5, -4, 1, 0),
						BackgroundTransparency = 1,
						[Children] = {
							Components.Button(scope, {
								Text = scope:Computed(function(use)
									return use(disbandConfirm) and "Confirm Disband?" or "Disband"
								end),
								Style = "danger",
								Disabled = scope:Computed(function(use)
									return use(localRole) ~= "Founder"
								end),
								OnClick = function()
									if peek(disbandConfirm) then
										disbandConfirm:set(false)
										task.spawn(function()
											local ok, err = SyndicateController.disbandConfirm()
											if not ok then
												setStatus(tostring(err))
											end
										end)
									else
										-- Step 1: arm the server-side pending disband (sets _pendingDisbands);
										-- without this, disbandConfirm fails with "no pending disband".
										task.spawn(function()
											local ok, vaultBalance, err = SyndicateController.disband()
											if ok then
												disbandConfirm:set(true)
												setStatus(
													string.format("Confirm — %s ◈ vault will be lost.", formatNum(vaultBalance))
												)
												task.delay(5, function()
													disbandConfirm:set(false)
												end)
											else
												setStatus(tostring(err))
											end
										end)
									end
								end,
							}),
						},
					}),
				},
			}),
		},
	})

	scope:New("ScreenGui")({
		Name = "SyndicateScreen",
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
						Text = "Syndicate",
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Content",
				Size = UDim2.new(1, 0, 1, -56),
				Position = UDim2.fromOffset(0, 56),
				BackgroundTransparency = 1,
				[Children] = {
					noSynView,
					inSynView,
				},
			}),
		},
	})
end

function SyndicateScreen.close()
	if _scope then
		doCleanup(_scope)
		_scope = nil
	end
end

return SyndicateScreen

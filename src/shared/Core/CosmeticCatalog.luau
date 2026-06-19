-- CosmeticCatalog: the §24 personal cosmetic catalog + pure ownership/purchase/equip logic.
-- No Roblox globals. Lune-testable. Zero gameplay effect (§24) — purely visual.
--
-- Four categories: labSkin, particles, hudAccent, patentStamp. Each has exactly one free default.
-- Acquisition: "pellets"/"catalysts" purchase, "prestige5" auto-unlock (equippable at Prestige 5;
-- previewable earlier), or "event" pass grant. No cosmetic is Robux-exclusive (§24).
-- Syndicate crests are NOT here — they are Syndicate property (§17, SyndicateService).

local CosmeticCatalog = {}

local PRESTIGE_VOID_LEVEL = 5

CosmeticCatalog.CATEGORIES = { "labSkin", "particles", "hudAccent", "patentStamp" }

-- id → { category, name, currency?, price?, unlock?, default? }
-- ids are category-prefixed to stay globally unique; `name` is the §24 display name.
CosmeticCatalog.ITEMS = {
	-- ── Lab Skins ──
	skin_industrial_standard = { category = "labSkin", name = "Industrial Standard", default = true },
	skin_arctic_research = { category = "labSkin", name = "Arctic Research", currency = "pellets", price = 500 },
	skin_carbon_black = { category = "labSkin", name = "Carbon Black", currency = "pellets", price = 1200 },
	skin_oxidized_copper = { category = "labSkin", name = "Oxidized Copper", currency = "catalysts", price = 80 },
	skin_gold_standard = { category = "labSkin", name = "Gold Standard", currency = "catalysts", price = 200 },
	skin_void = { category = "labSkin", name = "Void", unlock = "prestige5" },
	skin_industrial_hazmat = { category = "labSkin", name = "Industrial Hazmat", unlock = "event" },

	-- ── Particle Sets ──
	fx_standard_emission = { category = "particles", name = "Standard Emission", default = true },
	fx_neon_burst = { category = "particles", name = "Neon Burst", currency = "pellets", price = 300 },
	fx_ember_cascade = { category = "particles", name = "Ember Cascade", currency = "catalysts", price = 150 },
	fx_void = { category = "particles", name = "Void Particles", unlock = "prestige5" },

	-- ── HUD Accent Color ──
	hud_blue_white = { category = "hudAccent", name = "Blue-White", default = true },
	hud_biosafe_green = { category = "hudAccent", name = "Biosafe Green", currency = "pellets", price = 200 },
	hud_lab_amber = { category = "hudAccent", name = "Lab Amber", currency = "pellets", price = 100 },
	hud_hazard_red = { category = "hudAccent", name = "Hazard Red", currency = "catalysts", price = 100 },
	hud_gold = { category = "hudAccent", name = "Gold", currency = "catalysts", price = 150 },

	-- ── Patent Stamp Style ──
	stamp_standard = { category = "patentStamp", name = "Standard", default = true },
	stamp_minimal = { category = "patentStamp", name = "Minimal", currency = "pellets", price = 250 },
	stamp_broadcast = { category = "patentStamp", name = "Broadcast", currency = "catalysts", price = 200 },
	stamp_cascade_seal = { category = "patentStamp", name = "Cascade Seal", unlock = "event" },
}

function CosmeticCatalog.get(id: string): any
	return CosmeticCatalog.ITEMS[id]
end

-- Items in a category, in stable display order: free default first, then Pellet items by price,
-- then Catalyst items by price, then unlocks (prestige/event); ties broken by id. For the UI.
function CosmeticCatalog.byCategory(category: string): { { id: string, item: any } }
	local out = {}
	for id, item in pairs(CosmeticCatalog.ITEMS) do
		if item.category == category then
			table.insert(out, { id = id, item = item })
		end
	end
	local function rank(e): number
		if e.item.default then
			return 0
		elseif e.item.currency == "pellets" then
			return 1
		elseif e.item.currency == "catalysts" then
			return 2
		end
		return 3 -- prestige5 / event unlocks
	end
	table.sort(out, function(a, b)
		local ra, rb = rank(a), rank(b)
		if ra ~= rb then
			return ra < rb
		end
		local pa, pb = a.item.price or 0, b.item.price or 0
		if pa ~= pb then
			return pa < pb
		end
		return a.id < b.id
	end)
	return out
end

local function prestigeLevel(data: any): number
	return (data.prestige and data.prestige.level) or 0
end

-- Owned = free default, explicitly purchased/granted, or a Prestige-5 unlock the player has reached.
function CosmeticCatalog.isOwned(data: any, id: string): boolean
	local item = CosmeticCatalog.ITEMS[id]
	if item == nil then
		return false
	end
	if item.default then
		return true
	end
	if data.cosmetics and data.cosmetics.owned and data.cosmetics.owned[id] then
		return true
	end
	if item.unlock == "prestige5" and prestigeLevel(data) >= PRESTIGE_VOID_LEVEL then
		return true
	end
	return false
end

-- Can this id be bought with currency right now? (currency item, not already owned, can afford)
function CosmeticCatalog.canPurchase(data: any, id: string): (boolean, string?)
	local item = CosmeticCatalog.ITEMS[id]
	if item == nil then
		return false, "unknown cosmetic"
	end
	if item.default then
		return false, "already owned"
	end
	if item.currency == nil then
		-- prestige5 / event unlocks are not Pellet/Catalyst purchases
		return false, "not purchasable"
	end
	if CosmeticCatalog.isOwned(data, id) then
		return false, "already owned"
	end
	local balance = (data.balances and data.balances[item.currency]) or 0
	if balance < item.price then
		return false, "insufficient " .. item.currency
	end
	return true, nil
end

-- Can this id be equipped? Must be owned (Void/event items only once unlocked/granted).
function CosmeticCatalog.canEquip(data: any, id: string): (boolean, string?)
	local item = CosmeticCatalog.ITEMS[id]
	if item == nil then
		return false, "unknown cosmetic"
	end
	if not CosmeticCatalog.isOwned(data, id) then
		return false, "not owned"
	end
	return true, nil
end

return CosmeticCatalog

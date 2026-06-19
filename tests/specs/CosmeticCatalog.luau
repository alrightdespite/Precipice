-- CosmeticCatalog tests: §24 ownership / purchase / equip rules.

local spec = require("../spec")
local CosmeticCatalog = require("../../src/shared/Core/CosmeticCatalog")

local describe, it, expect = spec.describe, spec.it, spec.expect

local function profile(pellets: number, catalysts: number, prestige: number, owned: { [string]: boolean }?)
	return {
		balances = { pellets = pellets, catalysts = catalysts },
		prestige = { level = prestige },
		cosmetics = { owned = owned or {}, equipped = {} },
	}
end

describe("CosmeticCatalog — isOwned", function()
	it("free defaults are always owned", function()
		local p = profile(0, 0, 0)
		expect(CosmeticCatalog.isOwned(p, "skin_industrial_standard")).toBeTrue()
		expect(CosmeticCatalog.isOwned(p, "fx_standard_emission")).toBeTrue()
		expect(CosmeticCatalog.isOwned(p, "hud_blue_white")).toBeTrue()
		expect(CosmeticCatalog.isOwned(p, "stamp_standard")).toBeTrue()
	end)

	it("non-default items are not owned by default", function()
		expect(CosmeticCatalog.isOwned(profile(0, 0, 0), "skin_arctic_research")).toBeFalse()
	end)

	it("explicitly purchased items are owned", function()
		expect(CosmeticCatalog.isOwned(profile(0, 0, 0, { skin_arctic_research = true }), "skin_arctic_research")).toBeTrue()
	end)

	it("Void unlocks at Prestige 5, not before", function()
		expect(CosmeticCatalog.isOwned(profile(0, 0, 4), "skin_void")).toBeFalse()
		expect(CosmeticCatalog.isOwned(profile(0, 0, 5), "skin_void")).toBeTrue()
		expect(CosmeticCatalog.isOwned(profile(0, 0, 6), "fx_void")).toBeTrue()
	end)

	it("unknown id is not owned", function()
		expect(CosmeticCatalog.isOwned(profile(0, 0, 0), "nope")).toBeFalse()
	end)
end)

describe("CosmeticCatalog — canPurchase", function()
	it("affordable Pellet item: ok", function()
		local ok = CosmeticCatalog.canPurchase(profile(1000, 0, 0), "skin_arctic_research")
		expect(ok).toBeTrue()
	end)

	it("insufficient currency: rejected", function()
		local ok, err = CosmeticCatalog.canPurchase(profile(100, 0, 0), "skin_arctic_research")
		expect(ok).toBeFalse()
		expect(err).toBe("insufficient pellets")
	end)

	it("affordable Catalyst item checks catalysts not pellets", function()
		expect((CosmeticCatalog.canPurchase(profile(0, 80, 0), "skin_oxidized_copper"))).toBeTrue()
		expect((CosmeticCatalog.canPurchase(profile(999999, 0, 0), "skin_oxidized_copper"))).toBeFalse()
	end)

	it("default item: already owned", function()
		local ok, err = CosmeticCatalog.canPurchase(profile(1000, 0, 0), "stamp_standard")
		expect(ok).toBeFalse()
		expect(err).toBe("already owned")
	end)

	it("Prestige/event unlocks are not purchasable", function()
		local ok1, err1 = CosmeticCatalog.canPurchase(profile(999999, 999999, 0), "skin_void")
		expect(ok1).toBeFalse()
		expect(err1).toBe("not purchasable")
		local ok2, err2 = CosmeticCatalog.canPurchase(profile(999999, 999999, 0), "skin_industrial_hazmat")
		expect(ok2).toBeFalse()
		expect(err2).toBe("not purchasable")
	end)

	it("already-owned currency item cannot be re-bought", function()
		local ok, err = CosmeticCatalog.canPurchase(profile(1000, 0, 0, { skin_arctic_research = true }), "skin_arctic_research")
		expect(ok).toBeFalse()
		expect(err).toBe("already owned")
	end)
end)

describe("CosmeticCatalog — canEquip", function()
	it("a free default can be equipped", function()
		expect((CosmeticCatalog.canEquip(profile(0, 0, 0), "hud_blue_white"))).toBeTrue()
	end)

	it("an unowned item cannot be equipped", function()
		local ok, err = CosmeticCatalog.canEquip(profile(0, 0, 0), "hud_gold")
		expect(ok).toBeFalse()
		expect(err).toBe("not owned")
	end)

	it("Void can be equipped only at Prestige 5", function()
		expect((CosmeticCatalog.canEquip(profile(0, 0, 4), "skin_void"))).toBeFalse()
		expect((CosmeticCatalog.canEquip(profile(0, 0, 5), "skin_void"))).toBeTrue()
	end)
end)

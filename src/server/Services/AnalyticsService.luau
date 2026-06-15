-- AnalyticsService: fire-and-forget event tracking stub.
-- All emits are no-ops until an analytics provider is wired (Phase 12 / pre-launch).
-- Never errors the caller. Call sites use Events constants — no raw strings.

local AnalyticsService = {}

AnalyticsService.Events = {
	SYNTHESIS_NATURAL  = "synthesis_natural",
	SYNTHESIS_SKIP     = "synthesis_skip",
	LAB_ANALYZE        = "lab_analyze",
	LAB_DISCOVERY      = "lab_discovery",
	MARKET_LIST        = "market_list",
	MARKET_BUY         = "market_buy",
	MARKET_CANCEL      = "market_cancel",
	PRESTIGE           = "prestige",
	CONTRACT_CLAIM     = "contract_claim",
	FLUX_EARN          = "flux_earn",
	BLUEPRINT_PURCHASE = "blueprint_purchase",
	JOINT_COMPLETE     = "joint_complete",
	EXOTIC_WORLD_FIRST = "exotic_world_first",
	PATENT_CLAIM       = "patent_claim",
}

function AnalyticsService.track(_eventName: string, _payload: { [string]: any })
	-- TODO: wire to analytics provider (Phase 12 / pre-launch)
end

return AnalyticsService

-- Centralized type aliases shared across remotes, services, and client controllers.

export type SlotRecord = {
	state: string, -- "EMPTY" | "RUNNING" | "DONE" | "REVEALING"
	compoundId: string?,
	workRemaining: number?,
	lastTickAt: number?,
	mode: string?, -- "extraction" | "synthesis" | "stabilized"
	isActive: boolean,
}

export type VaultData = { [string]: number } -- compoundId → quantity

export type BalanceData = {
	pellets: number,
	catalysts: number,
	rushUses: number,
	timerSkipUses: number,
}

export type PatentRecord = {
	compoundId: string,
	holderId: number?,
	holderCount: number,
	challengerId: number?,
	challengerCount: number,
	windowEnd: number?,
	state: string, -- "UNCLAIMED" | "HELD" | "CHALLENGED" | "IMMUNE"
}

export type JointSlotRecord = {
	index: number,
	state: string, -- "EMPTY" | "STAGED" | "RUNNING" | "COMPLETE"
	openerId: number?,
	openerCompound: string?,
	contributorId: number?,
	contributorCompound: string?,
	resultId: string?,
	expiresAt: number?,
}

export type LeaderboardEntry = {
	userId: number,
	displayName: string,
	score: number,
	rank: number,
}

export type ContractRecord = {
	slotIndex: number,
	templateId: string,
	description: string,
	progress: number,
	target: number,
	claimed: boolean,
	pelletReward: number,
	difficulty: string,
}

export type SyndicateData = {
	id: string,
	name: string,
	members: { [number]: { role: string, displayName: string } },
	vaultPellets: number,
	upgrades: { [string]: boolean },
	jointSlots: { [number]: JointSlotRecord },
	memberCap: number,
}

export type FormulaLogEntry = {
	compoundId: string,
	recipeId: string?,
	discoveredAt: number,
}

export type OfflineBreakdownEntry = {
	tier: number,
	pellets: number,
}

export type AnnouncementData = {
	kind: string,
	message: string,
	tier: number?,
}

return {}

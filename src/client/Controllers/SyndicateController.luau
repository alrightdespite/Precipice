local RemoteController = require(script.Parent.RemoteController)
local StateController = require(script.Parent.StateController)

local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
type SyndicateData = Types.SyndicateData

local SyndicateController = {}

function SyndicateController.create(name: string): (boolean, string?)
	return RemoteController.invoke("SyndicateCreate", name)
end

function SyndicateController.invite(targetUserId: number): (boolean, string?)
	return RemoteController.invoke("SyndicateInvite", targetUserId)
end

function SyndicateController.kick(targetUserId: number): (boolean, string?)
	return RemoteController.invoke("SyndicateKick", targetUserId)
end

function SyndicateController.promote(targetUserId: number): (boolean, string?)
	return RemoteController.invoke("SyndicatePromote", targetUserId)
end

function SyndicateController.contributeVault(amount: number): (boolean, string?)
	return RemoteController.invoke("SyndicateContributeVault", amount)
end

function SyndicateController.acceptInvite(syndicateId: string): (boolean, string?)
	return RemoteController.invoke("SyndicateAcceptInvite", syndicateId)
end

function SyndicateController.declineInvite(): (boolean, string?)
	return RemoteController.invoke("SyndicateDeclineInvite")
end

function SyndicateController.rename(newName: string): (boolean, string?)
	return RemoteController.invoke("SyndicateRename", newName)
end

function SyndicateController.purchaseUpgrade(upgradeName: string): (boolean, string?)
	return RemoteController.invoke("SyndicatePurchaseUpgrade", upgradeName)
end

function SyndicateController.expandCap(): (boolean, string?)
	return RemoteController.invoke("SyndicateExpandCap")
end

function SyndicateController.disband(): (boolean, string?)
	return RemoteController.invoke("SyndicateDisband")
end

function SyndicateController.disbandConfirm(): (boolean, string?)
	return RemoteController.invoke("SyndicateDisbandConfirm")
end

function SyndicateController.getSyndicate(): SyndicateData?
	return StateController.get().syndicate
end

function SyndicateController.getPendingInvite(): { syndicateId: string, inviterUserId: number, syndicateName: string }?
	return StateController.get().pendingInvite
end

function SyndicateController.init(): typeof(SyndicateController)
	return SyndicateController
end

return SyndicateController

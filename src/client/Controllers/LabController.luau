local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Compounds = require(ReplicatedStorage.Shared.Data.Compounds)
local RecipeResolver = require(ReplicatedStorage.Shared.Core.RecipeResolver)
local LabButtonStateLogic = require(ReplicatedStorage.Shared.Core.LabButtonStateLogic)
local RemoteController = require(script.Parent.RemoteController)
local StateController = require(script.Parent.StateController)

local LabController = {}

function LabController.analyze(
	input1: string,
	input2: string
): (boolean, { result: string?, residue: number?, fee: number? } | string)
	return RemoteController.invoke("LabAnalyze", input1, input2)
end

-- Derives the button label from live StateController state + input tiers.
function LabController.getButtonState(input1: string?, input2: string?): string
	if input1 == nil or input2 == nil then
		return "SELECT_INPUTS"
	end

	local c1 = Compounds[input1]
	local c2 = Compounds[input2]
	if not c1 or not c2 then
		return "INVALID"
	end

	local tier1: number = c1.tier
	local tier2: number = c2.tier

	-- Build discovered set from formulaLog
	local log = StateController.get().formulaLog
	local discovered: { [string]: boolean } = {}
	for _, entry in ipairs(log) do
		discovered[entry.compoundId] = true
	end

	-- Check if any result compound for this pair is discovered
	local resultIds = RecipeResolver.getResultIds(input1, input2)
	local isDiscovered = false
	for _, rid in ipairs(resultIds) do
		if discovered[rid] then
			isDiscovered = true
			break
		end
	end

	return LabButtonStateLogic.compute({
		input1 = input1,
		input2 = input2,
		tier1 = tier1,
		tier2 = tier2,
		isJointRequired = RecipeResolver.isJointRequired(input1, input2),
		isDiscovered = isDiscovered,
		isVariablePair = RecipeResolver.isVariablePair(input1, input2),
	})
end

function LabController.getFormulaLog()
	return StateController.get().formulaLog
end

function LabController.init(): typeof(LabController)
	return LabController
end

return LabController

-- Pure client-side button state derivation. No Roblox globals. Lune-testable.
-- LabController wraps this with live data; tests call it directly with mocks.

local LabButtonStateLogic = {}

export type ButtonStateParams = {
	input1: string?,
	input2: string?,
	tier1: number,
	tier2: number,
	isJointRequired: boolean,
	isDiscovered: boolean,
	isVariablePair: boolean,
}

-- Returns one of: SELECT_INPUTS | INVALID | JOINT_REQUIRED | ANALYZE | SYNTHESIZE | SYNTHESIZE_VARIABLE
function LabButtonStateLogic.compute(params: ButtonStateParams): string
	if params.input1 == nil or params.input2 == nil then
		return "SELECT_INPUTS"
	end
	if params.tier1 >= 7 or params.tier2 >= 7 then
		return "INVALID"
	end
	if params.isJointRequired then
		return "JOINT_REQUIRED"
	end
	if not params.isDiscovered then
		return "ANALYZE"
	end
	if params.isVariablePair then
		return "SYNTHESIZE_VARIABLE"
	end
	return "SYNTHESIZE"
end

return LabButtonStateLogic

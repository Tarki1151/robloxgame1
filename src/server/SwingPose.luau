--!strict
--[[
	SwingPose
	The slash animation, driven by joint rather than by asset.

	Roblox animations are uploaded assets: built in the Animation Editor,
	published to an account, and played by ID. Nothing in a repo can produce
	one, so the swing is posed directly instead - the shoulder is rotated back
	on the windup and swept forward on the cut, with the torso turning into it.

	Works on both rigs. R6 keeps its shoulder joint in the Torso and calls it
	"Right Shoulder"; R15 keeps it in the arm itself and calls it
	"RightShoulder", so the joint is looked up rather than assumed.

	Joint C0 is what is written, not Transform. Roblox's own animations drive
	Transform, so posing C0 stacks on top of the idle and walk cycles instead
	of fighting them - no need to disable the stock Animate script.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local SwingPose = {}

-- Characters mid-swing, so a second swing restarts rather than stacking.
local active: { [Model]: number } = {}

local function findJoint(character: Model, names: { string }): Motor6D?
	for _, name in names do
		for _, item in character:GetDescendants() do
			if item:IsA("Motor6D") and item.Name == name then
				return item
			end
		end
	end
	return nil
end

--[[
	Where the arm should be, given how far through the swing we are.

	Two phases. The windup pulls the arm back over the first WindupFraction of
	the duration; the cut sweeps it forward through the rest. Both are eased -
	the windup slows as it reaches the top, the cut accelerates out of it -
	because a constant-speed swing reads as a mechanism, not a person.
]]
local function swingAngle(progress: number): number
	local windup = Config.Sword.WindupFraction

	if progress < windup then
		local phase = progress / windup
		-- Ease out: fast off the mark, settling at the top of the windup.
		return -Config.Sword.WindupAngle * (1 - (1 - phase) * (1 - phase))
	end

	local phase = (progress - windup) / (1 - windup)
	-- Ease in then out: the blade accelerates through the cut and stops.
	local eased = phase * phase * (3 - 2 * phase)
	return -Config.Sword.WindupAngle + (Config.Sword.WindupAngle + Config.Sword.SwingAngle) * eased
end

--[[
	Plays one swing on a character.

	Runs on its own thread and restores every joint it touched, so a character
	that dies or unequips mid-swing is not left with a bent arm.
]]
function SwingPose.play(character: Model, trail: Trail?)
	local shoulder = findJoint(character, { "Right Shoulder", "RightShoulder" })
	if not shoulder then
		return
	end

	local waist = findJoint(character, { "RootJoint", "Waist" })

	local shoulderRest = shoulder.C0
	local waistRest = if waist then waist.C0 else nil

	-- A token, so a swing started later can tell an earlier one to stop.
	local token = os.clock()
	active[character] = token

	if trail then
		trail.Enabled = true
	end

	task.spawn(function()
		local elapsed = 0

		while elapsed < Config.Sword.SwingDuration do
			elapsed += RunService.Heartbeat:Wait()

			-- Superseded by a newer swing, or the character is gone.
			if active[character] ~= token or not character.Parent then
				return
			end

			local progress = math.min(elapsed / Config.Sword.SwingDuration, 1)
			local angle = swingAngle(progress)

			-- The shoulder's X axis points along the arm on both rigs, so a
			-- rotation about X lifts and drops it.
			shoulder.C0 = shoulderRest * CFrame.Angles(angle, 0, 0)

			if waist and waistRest then
				-- The body turns into the cut and unwinds with it.
				local twist = math.sin(progress * math.pi) * Config.Sword.TorsoTwist
				waist.C0 = waistRest * CFrame.Angles(0, twist, 0)
			end
		end

		if active[character] == token then
			active[character] = nil
			shoulder.C0 = shoulderRest
			if waist and waistRest then
				waist.C0 = waistRest
			end
			if trail then
				trail.Enabled = false
			end
		end
	end)
end

return SwingPose

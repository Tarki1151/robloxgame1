--[[
	PoseService
	The animation pack, driven from code.

	Roblox animation packs are uploaded assets: you build them in the Animation
	Editor, publish them, and play the resulting asset IDs. This project has no
	uploaded assets, so instead the R6 Motor6D joints are posed directly every
	frame. Same visual result, nothing to upload.

	Poses:
	  Idle    - floating upright, arms and legs drifting
	  Flight  - airborne: leans forward, legs trail behind
	  Slash   - sword swing, overrides the right arm briefly

	If you later record real animations, keep AvatarService as-is and replace
	this service with Animator:LoadAnimation calls.

	R6 only. R15 has a different joint set, so the service reports it and
	stops rather than posing half a body.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local AvatarService = require(script.Parent.AvatarService)

local PoseService = {}

type Rig = {
	character: Model,
	humanoid: Humanoid,
	joints: { [string]: Motor6D },
	-- Lives in HumanoidRootPart rather than the Torso, and is what lifts the
	-- whole visible body off the ground.
	rootJoint: Motor6D?,
	rootRest: CFrame,
	-- Neutral C0 of every joint, captured once so poses are offsets from the
	-- rig's own rest pose rather than hardcoded numbers.
	rest: { [string]: CFrame },
	-- Current blended value per joint, so poses ease instead of snapping.
	current: { [string]: CFrame },
	wings: { Weld }?,
	wingRest: { CFrame },
	slashUntil: number,
}

local JOINT_NAMES = {
	"Right Shoulder",
	"Left Shoulder",
	"Right Hip",
	"Left Hip",
	"Neck",
}

local rigs: { [Player]: Rig } = {}

local function collectRig(character: Model): Rig?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		warn(
			"[PoseService] R6 required for the classic noob pose set. "
				.. "Set Game Settings > Avatar > Rig Type to R6."
		)
		return nil
	end

	local torso = character:FindFirstChild("Torso")
	if not torso then
		return nil
	end

	local joints: { [string]: Motor6D } = {}
	local rest: { [string]: CFrame } = {}
	local current: { [string]: CFrame } = {}

	for _, name in JOINT_NAMES do
		local joint = torso:FindFirstChild(name)
		if joint and joint:IsA("Motor6D") then
			joints[name] = joint
			rest[name] = joint.C0
			current[name] = joint.C0
		end
	end

	-- R6 ignores Humanoid.HipHeight, so hovering is done by raising the root
	-- joint: the Torso and everything jointed to it lifts, while the invisible
	-- HumanoidRootPart stays on the ground and keeps normal walking working.
	local root = character:FindFirstChild("HumanoidRootPart")
	local rootJoint = if root then root:FindFirstChild("RootJoint") else nil
	local rootMotor = if rootJoint and rootJoint:IsA("Motor6D") then rootJoint else nil

	local wings = AvatarService:GetWings(character)
	local wingRest: { CFrame } = {}
	if wings then
		for index, weld in wings do
			wingRest[index] = weld.C0
		end
	end

	return {
		character = character,
		humanoid = humanoid,
		joints = joints,
		rootJoint = rootMotor,
		rootRest = if rootMotor then rootMotor.C0 else CFrame.identity,
		rest = rest,
		current = current,
		wings = wings,
		wingRest = wingRest,
		slashUntil = 0,
	}
end

--[[
	Target C0 for each joint this frame.

	Returned as offsets applied on top of the rest pose, so the numbers stay
	readable: "rotate the shoulder back by 0.2 radians", not a raw matrix.
]]
local function targetsFor(rig: Rig, now: number): { [string]: CFrame }
	local state = rig.humanoid:GetState()
	local airborne = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping

	local targets: { [string]: CFrame } = {}
	local drift = math.sin(now * Config.Pose.IdleSpeed)

	if airborne then
		-- Flight: arms swept back, legs trailing, head up.
		local lean = Config.Pose.FlightLean
		targets["Right Shoulder"] = CFrame.Angles(0, 0, -lean)
		targets["Left Shoulder"] = CFrame.Angles(0, 0, lean)
		targets["Right Hip"] = CFrame.Angles(Config.Pose.FlightLegAngle, 0, 0)
		targets["Left Hip"] = CFrame.Angles(Config.Pose.FlightLegAngle * 0.7, 0, 0)
		targets["Neck"] = CFrame.Angles(-0.2, 0, 0)
	else
		-- Idle float: everything hangs and drifts slowly.
		local arm = drift * Config.Pose.IdleArmSwing
		local leg = drift * Config.Pose.IdleLegSwing
		targets["Right Shoulder"] = CFrame.Angles(arm, 0, -0.12)
		targets["Left Shoulder"] = CFrame.Angles(-arm, 0, 0.12)
		targets["Right Hip"] = CFrame.Angles(leg, 0, 0)
		targets["Left Hip"] = CFrame.Angles(-leg, 0, 0)
		targets["Neck"] = CFrame.Angles(drift * 0.05, 0, 0)
	end

	-- Slash overrides the sword arm regardless of the pose underneath.
	if now < rig.slashUntil then
		local progress = 1 - (rig.slashUntil - now) / Config.Sword.SwingDuration
		-- Up fast, down slow: a chop rather than a windmill.
		local swing = math.sin(progress * math.pi) * 2.6
		targets["Right Shoulder"] = CFrame.Angles(-swing, 0, -0.3)
	end

	return targets
end

local function flapWings(rig: Rig, now: number)
	if not rig.wings then
		return
	end

	for index, weld in rig.wings do
		local restOffset = rig.wingRest[index]
		if restOffset then
			-- Welds alternate left, right, left, right - so pair number is
			-- every second entry, and each pair lags the one above it.
			local pair = math.floor((index - 1) / 2)
			local side = if index % 2 == 1 then -1 else 1
			local phase = now * Config.Wings.FlapSpeed * math.pi * 2 - pair * Config.Wings.PairDelay
			local flap = math.sin(phase) * Config.Wings.FlapAmount

			weld.C0 = restOffset * CFrame.Angles(0, 0, flap * side)
		end
	end
end

local function step(deltaTime: number)
	local now = os.clock()
	local alpha = math.min(deltaTime * Config.Pose.BlendSpeed, 1)

	for player, rig in rigs do
		if not rig.character.Parent or rig.humanoid.Health <= 0 then
			rigs[player] = nil
			continue
		end

		-- Hover: the body floats and bobs. Airborne, it also pitches forward.
		local rootMotor = rig.rootJoint
		if rootMotor then
			local bob = math.sin(now * Config.Pose.BobSpeed * math.pi * 2) * Config.Pose.BobAmount
			local state = rig.humanoid:GetState()
			local airborne = state == Enum.HumanoidStateType.Freefall
				or state == Enum.HumanoidStateType.Jumping
			local lean = if airborne then -Config.Pose.FlightLean else 0

			local goal = rig.rootRest
				* CFrame.new(0, Config.Pose.HoverHeight + bob, 0)
				* CFrame.Angles(lean, 0, 0)
			rootMotor.C0 = rootMotor.C0:Lerp(goal, alpha)
		end

		for name, offset in targetsFor(rig, now) do
			local joint = rig.joints[name]
			local rest = rig.rest[name]
			if joint and rest then
				local goal = rest * offset
				rig.current[name] = rig.current[name]:Lerp(goal, alpha)
				joint.C0 = rig.current[name]
			end
		end

		flapWings(rig, now)
	end
end

-- Called by AvatarService's sword when the player swings.
function PoseService:Slash(player: Player)
	local rig = rigs[player]
	if rig then
		rig.slashUntil = os.clock() + Config.Sword.SwingDuration
	end
end

local function onCharacterAdded(player: Player, character: Model)
	-- AvatarService builds the wings; wait a frame so they exist.
	task.defer(function()
		rigs[player] = collectRig(character)
	end)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

function PoseService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		rigs[player] = nil
	end)

	-- AvatarService owns the sword; it calls back here instead of requiring
	-- this service, which would be a require cycle.
	AvatarService.OnSwing = function(player: Player)
		PoseService:Slash(player)
	end

	RunService.Heartbeat:Connect(step)
end

return PoseService

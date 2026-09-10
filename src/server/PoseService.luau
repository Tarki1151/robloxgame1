--[[
	PoseService
	The NPC's animation set, driven from code.

	Roblox animation packs are uploaded assets: you build them in the Animation
	Editor, publish them, and play the resulting IDs. Nothing in a repo can
	produce those IDs, so instead the R6 Motor6D joints are posed directly
	every frame. Same result on screen, nothing to upload.

	Poses:
	  Idle   - floating upright, arms and legs drifting
	  Chase  - walking at a player: leans forward, legs trail
	  Swing  - melee or special windup, overrides the sword arm

	Players are untouched: they keep their normal Roblox animations.

	If you record real animations later, keep NpcService as-is and replace this
	service with Animator:LoadAnimation calls.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local NpcService = require(script.Parent.NpcService)

local PoseService = {}

type Rig = {
	joints: { [string]: Motor6D },
	-- Rest C0 of every joint, captured once, so poses are offsets from the
	-- rig's own neutral pose rather than hardcoded matrices.
	rest: { [string]: CFrame },
	current: { [string]: CFrame },
	rootJoint: Motor6D?,
	rootRest: CFrame,
	wingRest: { CFrame },
}

local JOINT_NAMES = {
	"Right Shoulder",
	"Left Shoulder",
	"Right Hip",
	"Left Hip",
	"Neck",
}

local rigs: { [Model]: Rig } = {}

local function buildRig(npc): Rig?
	local torso = npc.torso
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
	-- HumanoidRootPart stays on the ground and keeps walking working.
	local rootJoint = npc.root:FindFirstChild("RootJoint")
	local rootMotor = if rootJoint and rootJoint:IsA("Motor6D") then rootJoint else nil

	local wingRest: { CFrame } = {}
	for index, weld in npc.wings do
		wingRest[index] = weld.C0
	end

	return {
		joints = joints,
		rest = rest,
		current = current,
		rootJoint = rootMotor,
		rootRest = if rootMotor then rootMotor.C0 else CFrame.identity,
		wingRest = wingRest,
	}
end

-- Target offsets for each joint this frame, on top of the rest pose.
local function targetsFor(npc, now: number): { [string]: CFrame }
	local moving = npc.humanoid.MoveDirection.Magnitude > 0.1
	local targets: { [string]: CFrame } = {}
	local drift = math.sin(now * Config.Pose.IdleSpeed)

	if moving then
		targets["Right Shoulder"] = CFrame.Angles(0, 0, -0.25)
		targets["Left Shoulder"] = CFrame.Angles(0, 0, 0.25)
		targets["Right Hip"] = CFrame.Angles(Config.Pose.ChaseLegAngle, 0, 0)
		targets["Left Hip"] = CFrame.Angles(Config.Pose.ChaseLegAngle * 0.6, 0, 0)
		targets["Neck"] = CFrame.Angles(-0.15, 0, 0)
	else
		local arm = drift * Config.Pose.IdleArmSwing
		local leg = drift * Config.Pose.IdleLegSwing
		targets["Right Shoulder"] = CFrame.Angles(arm, 0, -0.12)
		targets["Left Shoulder"] = CFrame.Angles(-arm, 0, 0.12)
		targets["Right Hip"] = CFrame.Angles(leg, 0, 0)
		targets["Left Hip"] = CFrame.Angles(-leg, 0, 0)
		targets["Neck"] = CFrame.Angles(drift * 0.05, 0, 0)
	end

	-- A swing overrides the sword arm whatever the body is doing.
	if now < npc.swingUntil then
		local progress = 1 - (npc.swingUntil - now) / Config.Pose.SwingDuration
		-- Up fast, down slow: a chop rather than a windmill.
		local swing = math.sin(progress * math.pi) * 2.6
		targets["Right Shoulder"] = CFrame.Angles(-swing, 0, -0.3)
	end

	return targets
end

local function flapWings(npc, rig: Rig, now: number)
	for index, weld in npc.wings do
		local restOffset = rig.wingRest[index]
		if restOffset then
			-- Welds alternate left, right, left, right - so the pair number is
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

	for character, npc in NpcService:GetNpcs() do
		local rig = rigs[character]
		if not rig then
			rig = buildRig(npc)
			rigs[character] = rig
		end

		if rig and character.Parent and npc.humanoid.Health > 0 then
			-- Hover: the body floats and bobs, and leans when chasing.
			local rootMotor = rig.rootJoint
			if rootMotor then
				local bob = math.sin(now * Config.Pose.BobSpeed * math.pi * 2) * Config.Pose.BobAmount
				local moving = npc.humanoid.MoveDirection.Magnitude > 0.1
				local lean = if moving then -Config.Pose.ChaseLean else 0

				local goal = rig.rootRest
					* CFrame.new(0, Config.Pose.HoverHeight + bob, 0)
					* CFrame.Angles(lean, 0, 0)
				rootMotor.C0 = rootMotor.C0:Lerp(goal, alpha)
			end

			for name, offset in targetsFor(npc, now) do
				local joint = rig.joints[name]
				local rest = rig.rest[name]
				if joint and rest then
					local goal = rest * offset
					rig.current[name] = rig.current[name]:Lerp(goal, alpha)
					joint.C0 = rig.current[name]
				end
			end

			flapWings(npc, rig, now)
		elseif not character.Parent then
			rigs[character] = nil
		end
	end
end

function PoseService:Start()
	RunService.Heartbeat:Connect(step)
end

return PoseService

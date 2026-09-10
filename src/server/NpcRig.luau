--!strict
--[[
	NpcRig
	Builds a classic R6 character from scratch, part by part.

	A player's character is assembled by Roblox from their avatar. An NPC gets
	none of that, so the rig is written out here: the six body parts, the
	HumanoidRootPart, and the Motor6D joints that connect them.

	The offsets below are the standard R6 ones. They matter: PoseService poses
	this rig by name ("Right Shoulder", "RootJoint"), exactly as it would a
	real R6 player character.
]]

local NpcRig = {}

local HALF_PI = math.pi / 2

local function makePart(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function joint(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = c0
	motor.C1 = c1
	motor.Parent = part0
	return motor
end

function NpcRig.build(name: string, color: Color3, material: Enum.Material, scale: number): Model
	local character = Instance.new("Model")
	character.Name = name

	-- Every part and every joint offset is multiplied by scale, so a bigger
	-- beast is the same rig at a larger size rather than a stretched one.
	local function size(x: number, y: number, z: number): Vector3
		return Vector3.new(x, y, z) * scale
	end

	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * scale, y * scale, z * scale)
	end

	local torso = makePart("Torso", size(2, 2, 1), color, material)
	torso.Parent = character

	local head = makePart("Head", size(2, 1, 1), color, material)
	head.Parent = character

	-- The classic head is a 1.25x scaled block; without the mesh it reads as
	-- a flat brick rather than a noob head.
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25) * scale
	headMesh.Parent = head

	local rightArm = makePart("Right Arm", size(1, 2, 1), color, material)
	rightArm.Parent = character
	local leftArm = makePart("Left Arm", size(1, 2, 1), color, material)
	leftArm.Parent = character
	local rightLeg = makePart("Right Leg", size(1, 2, 1), color, material)
	rightLeg.Parent = character
	local leftLeg = makePart("Left Leg", size(1, 2, 1), color, material)
	leftLeg.Parent = character

	-- Invisible collision box the Humanoid actually walks around with.
	local root = makePart("HumanoidRootPart", size(2, 2, 1), color, material)
	root.Transparency = 1
	root.CanCollide = false
	root.Parent = character

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = character

	character.PrimaryPart = root

	joint(
		"RootJoint",
		root,
		torso,
		at(0, 0, 0) * CFrame.Angles(-HALF_PI, 0, math.pi),
		at(0, 0, 0) * CFrame.Angles(-HALF_PI, 0, math.pi)
	)
	joint(
		"Neck",
		torso,
		head,
		at(0, 1, 0) * CFrame.Angles(-HALF_PI, 0, math.pi),
		at(0, -0.5, 0) * CFrame.Angles(-HALF_PI, 0, math.pi)
	)
	joint(
		"Right Shoulder",
		torso,
		rightArm,
		at(1, 0.5, 0) * CFrame.Angles(0, HALF_PI, 0),
		at(-0.5, 0.5, 0) * CFrame.Angles(0, HALF_PI, 0)
	)
	joint(
		"Left Shoulder",
		torso,
		leftArm,
		at(-1, 0.5, 0) * CFrame.Angles(0, -HALF_PI, 0),
		at(0.5, 0.5, 0) * CFrame.Angles(0, -HALF_PI, 0)
	)
	joint(
		"Right Hip",
		torso,
		rightLeg,
		at(1, -1, 0) * CFrame.Angles(0, HALF_PI, 0),
		at(0.5, 1, 0) * CFrame.Angles(0, HALF_PI, 0)
	)
	joint(
		"Left Hip",
		torso,
		leftLeg,
		at(-1, -1, 0) * CFrame.Angles(0, -HALF_PI, 0),
		at(-0.5, 1, 0) * CFrame.Angles(0, -HALF_PI, 0)
	)

	return character
end

return NpcRig

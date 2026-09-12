--!strict
--[[
	Keep
	What stands inside the castle walls: the central keep, steps up to the
	wall walk, a well, and the barrels, crates and torches that make a
	courtyard look lived in rather than like an empty box.

	Placed relative to the castle's own origin, so moving the castle in Config
	takes all of this with it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Keep = {}

local function block(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

--[[
	The keep itself: four walls around a doorway, a floor and a roof.

	Built as walls rather than one solid block so it can be walked into, with
	the front split either side of the door for the same reason the castle
	gatehouse is - parts cannot have holes cut in them.
]]
local function buildKeep(origin: CFrame, parent: Instance)
	local size = Config.Keep.Size
	local stone = Config.Castle.StoneColor
	local dark = Config.Castle.StoneDarkColor
	local doorWidth = Config.Keep.DoorWidth
	local doorHeight = Config.Keep.DoorHeight

	block(
		"KeepFloor",
		Vector3.new(size.X, 1, size.Z),
		origin * CFrame.new(0, 2.5, 0),
		dark,
		Config.Castle.Material,
		parent
	)

	-- Back and sides.
	block(
		"KeepBack",
		Vector3.new(size.X, size.Y, 2),
		origin * CFrame.new(0, size.Y / 2 + 2, -size.Z / 2),
		stone,
		Config.Castle.Material,
		parent
	)
	for _, side in { -1, 1 } do
		block(
			"KeepSide",
			Vector3.new(2, size.Y, size.Z),
			origin * CFrame.new(side * size.X / 2, size.Y / 2 + 2, 0),
			stone,
			Config.Castle.Material,
			parent
		)
	end

	-- Front, split around the door.
	local segment = (size.X - doorWidth) / 2
	for _, side in { -1, 1 } do
		block(
			"KeepFront",
			Vector3.new(segment, size.Y, 2),
			origin * CFrame.new(side * (doorWidth / 2 + segment / 2), size.Y / 2 + 2, size.Z / 2),
			stone,
			Config.Castle.Material,
			parent
		)
	end
	block(
		"KeepLintel",
		Vector3.new(doorWidth, size.Y - doorHeight, 2),
		origin * CFrame.new(0, doorHeight + (size.Y - doorHeight) / 2 + 2, size.Z / 2),
		stone,
		Config.Castle.Material,
		parent
	)

	-- Roof: a flat cap with its own battlements.
	block(
		"KeepRoof",
		Vector3.new(size.X + 4, 2, size.Z + 4),
		origin * CFrame.new(0, size.Y + 3, 0),
		dark,
		Config.Castle.Material,
		parent
	)

	local step = Config.Castle.MerlonWidth + Config.Castle.MerlonGap
	local across = math.floor((size.X + 4) / step)
	for index = 0, across do
		local x = -(size.X + 4) / 2 + index * step
		for _, side in { -1, 1 } do
			block(
				"KeepMerlon",
				Vector3.new(Config.Castle.MerlonWidth, Config.Castle.MerlonHeight, 2),
				origin * CFrame.new(x, size.Y + 4 + Config.Castle.MerlonHeight / 2, side * (size.Z + 4) / 2),
				dark,
				Config.Castle.Material,
				parent
			)
		end
	end

	-- Windows: dark slots, so the walls are not blank.
	for _, side in { -1, 1 } do
		for _, level in { 0.4, 0.75 } do
			block(
				"Window",
				Vector3.new(2.4, 4, 2.4),
				origin * CFrame.new(side * size.X / 2, size.Y * level + 2, size.Z * 0.22),
				Color3.fromRGB(18, 16, 20),
				Enum.Material.Glass,
				parent
			)
		end
	end
end

-- A torch: post, head, light and flame particles.
local function torch(cframe: CFrame, parent: Instance)
	local post = block(
		"TorchPost",
		Vector3.new(0.6, 5, 0.6),
		cframe * CFrame.new(0, 2.5, 0),
		Config.Keep.WoodDarkColor,
		Enum.Material.Wood,
		parent
	)

	local head = block(
		"TorchHead",
		Vector3.new(1.2, 1.2, 1.2),
		cframe * CFrame.new(0, 5.4, 0),
		Config.Keep.FlameColor,
		Enum.Material.Neon,
		parent
	)

	local light = Instance.new("PointLight")
	light.Color = Config.Keep.FlameColor
	light.Brightness = 2
	light.Range = 22
	light.Parent = head

	local fire = Instance.new("Fire")
	fire.Heat = 6
	fire.Size = 4
	fire.Color = Config.Keep.FlameColor
	fire.Parent = head

	return post
end

local function barrel(cframe: CFrame, parent: Instance)
	local body = block(
		"Barrel",
		Vector3.new(3.4, 4, 3.4),
		cframe * CFrame.new(0, 2, 0),
		Config.Keep.WoodColor,
		Enum.Material.Wood,
		parent
	)
	body.Shape = Enum.PartType.Cylinder
	body.CFrame = cframe * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.pi / 2)

	-- Two iron hoops, which is most of what makes a cylinder read as a barrel.
	for _, level in { -0.9, 0.9 } do
		local hoop = block(
			"Hoop",
			Vector3.new(0.5, 3.6, 3.6),
			cframe * CFrame.new(0, 2 + level, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Config.Keep.MetalColor,
			Enum.Material.Metal,
			parent
		)
		hoop.Shape = Enum.PartType.Cylinder
	end
end

local function crate(cframe: CFrame, size: number, parent: Instance)
	block(
		"Crate",
		Vector3.new(size, size, size),
		cframe * CFrame.new(0, size / 2, 0),
		Config.Keep.WoodColor,
		Enum.Material.WoodPlanks,
		parent
	)
end

local function well(cframe: CFrame, parent: Instance)
	local ring = block(
		"WellRing",
		Vector3.new(9, 4, 9),
		cframe * CFrame.new(0, 2, 0),
		Config.Keep.WellColor,
		Enum.Material.Cobblestone,
		parent
	)
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = cframe * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.pi / 2)

	block(
		"WellWater",
		Vector3.new(7.6, 0.4, 7.6),
		cframe * CFrame.new(0, 3.4, 0),
		Color3.fromRGB(28, 46, 62),
		Enum.Material.Glass,
		parent
	)

	-- Posts and a crossbeam over the top.
	for _, side in { -1, 1 } do
		block(
			"WellPost",
			Vector3.new(0.8, 8, 0.8),
			cframe * CFrame.new(side * 3.6, 8, 0),
			Config.Keep.WoodDarkColor,
			Enum.Material.Wood,
			parent
		)
	end
	block(
		"WellBeam",
		Vector3.new(9, 0.9, 0.9),
		cframe * CFrame.new(0, 12, 0),
		Config.Keep.WoodDarkColor,
		Enum.Material.Wood,
		parent
	)
end

-- Steps from the courtyard up to the top of the wall.
local function stairs(origin: CFrame, parent: Instance)
	local count = Config.Keep.StairCount
	local rise = Config.Castle.WallHeight / count
	local run = 3

	for index = 1, count do
		block(
			"Step",
			Vector3.new(Config.Keep.StairWidth, rise, run),
			origin * CFrame.new(0, rise * (index - 0.5) + 2, -run * (index - 0.5)),
			Config.Castle.StoneDarkColor,
			Config.Castle.Material,
			parent
		)
	end
end

-- Fills the courtyard. origin is the castle centre.
function Keep.build(origin: Vector3, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Keep"
	model.Parent = parent

	local base = CFrame.new(origin)
	local half = Config.Castle.Width / 2

	buildKeep(base * CFrame.new(0, 0, -8), model)
	well(base * CFrame.new(-20, 2, 16), model)

	-- Stairs against the left wall, climbing toward the back.
	stairs(base * CFrame.new(-half + 8, 0, half - 10) * CFrame.Angles(0, math.pi, 0), model)

	-- Props, spread deterministically so the courtyard looks the same each run.
	for index = 1, Config.Keep.BarrelCount do
		local angle = index * 2.1
		barrel(base * CFrame.new(math.cos(angle) * (18 + index), 2, 14 + math.sin(angle) * 8), model)
	end

	for index = 1, Config.Keep.CrateCount do
		local angle = index * 1.7
		crate(
			base
				* CFrame.new(math.sin(angle) * (16 + index * 1.5), 2, 10 + math.cos(angle) * 10)
				* CFrame.Angles(0, angle, 0),
			3 + (index % 3),
			model
		)
	end

	-- Torches around the courtyard edge, inside the walls.
	for index = 1, Config.Keep.TorchCount do
		local angle = (index / Config.Keep.TorchCount) * math.pi * 2
		torch(base * CFrame.new(math.cos(angle) * (half - 8), 2, math.sin(angle) * (half - 8)), model)
	end
end

return Keep

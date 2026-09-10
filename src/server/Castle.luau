--!strict
--[[
	Castle
	Builds a castle out of parts: four walls with battlements, a round tower
	at each corner with a cone roof, and a gatehouse in the near wall.

	Everything is anchored and built at run time from Config.Castle, so there
	is no model to import and every dimension is a number you can change.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Castle = {}

local function block(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Config.Castle.Material
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Battlements: alternating merlons along the top edge of a wall run.
local function battlement(from: Vector3, to: Vector3, height: number, parent: Instance)
	local span = (to - from)
	local length = span.Magnitude
	local direction = span.Unit
	local step = Config.Castle.MerlonWidth + Config.Castle.MerlonGap
	local count = math.max(math.floor(length / step), 1)

	for index = 0, count do
		local along = (index / count) * length
		local position = from + direction * along + Vector3.new(0, height, 0)

		block(
			"Merlon",
			Vector3.new(Config.Castle.MerlonWidth, Config.Castle.MerlonHeight, Config.Castle.WallThickness),
			CFrame.lookAt(position, position + direction) * CFrame.Angles(0, math.pi / 2, 0),
			Config.Castle.StoneDarkColor,
			parent
		)
	end
end

-- A cylinder part lies along its X axis, so anything round has to be stood
-- upright before it looks like a tower.
local function upright(part: Part, position: Vector3)
	part.Shape = Enum.PartType.Cylinder
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
end

local function tower(position: Vector3, parent: Instance)
	local radius = Config.Castle.TowerRadius
	local height = Config.Castle.TowerHeight

	local shaft = block(
		"Tower",
		Vector3.new(height, radius * 2, radius * 2),
		CFrame.new(position),
		Config.Castle.StoneColor,
		parent
	)
	upright(shaft, position + Vector3.new(0, height / 2, 0))

	--[[
		A stepped cone for the roof.

		Roblox has no cone primitive, and the uploaded cone meshes fail to
		load whenever Studio has no asset access. Three stacked cylinders,
		each narrower and shorter than the last, read as a turret cap from any
		distance and need nothing downloaded.
	]]
	local steps = 3
	local stepHeight = Config.Castle.RoofHeight / steps

	for index = 1, steps do
		local scale = 1 - (index - 1) / steps
		local cap = block(
			"TowerRoof",
			Vector3.new(stepHeight, radius * 2.3 * scale, radius * 2.3 * scale),
			CFrame.new(position),
			Config.Castle.RoofColor,
			parent
		)
		upright(cap, position + Vector3.new(0, height + stepHeight * (index - 0.5), 0))
	end

	local mastBase = position + Vector3.new(0, height + Config.Castle.RoofHeight, 0)

	local mast = block(
		"Banner",
		Vector3.new(0.4, 6, 0.4),
		CFrame.new(mastBase + Vector3.new(0, 3, 0)),
		Config.Castle.StoneDarkColor,
		parent
	)
	mast.Material = Enum.Material.Metal

	block(
		"Flag",
		Vector3.new(4, 2.6, 0.2),
		CFrame.new(mastBase + Vector3.new(2.2, 4.4, 0)),
		Config.Castle.BannerColor,
		parent
	)
end

--[[
	The near wall, split around a gate opening.

	Built as two wall segments with a lintel over the gap rather than one wall
	with a hole, because parts cannot have holes cut in them.
]]
local function gateWall(halfWidth: number, parent: Instance)
	local height = Config.Castle.WallHeight
	local thickness = Config.Castle.WallThickness
	local gateHalf = Config.Castle.GateWidth / 2
	local segment = halfWidth - gateHalf

	for _, side in { -1, 1 } do
		local centre = side * (gateHalf + segment / 2)
		block(
			"WallFront",
			Vector3.new(segment, height, thickness),
			CFrame.new(centre, height / 2, halfWidth),
			Config.Castle.StoneColor,
			parent
		)
	end

	-- Lintel: the span of wall above the gate.
	local lintelHeight = height - Config.Castle.GateHeight
	block(
		"GateLintel",
		Vector3.new(Config.Castle.GateWidth, lintelHeight, thickness),
		CFrame.new(0, Config.Castle.GateHeight + lintelHeight / 2, halfWidth),
		Config.Castle.StoneColor,
		parent
	)

	-- Gatehouse towers flanking the opening, so the entrance reads as one.
	for _, side in { -1, 1 } do
		block(
			"GatePier",
			Vector3.new(6, height + 8, thickness + 4),
			CFrame.new(side * (gateHalf + 3), (height + 8) / 2, halfWidth),
			Config.Castle.StoneDarkColor,
			parent
		)
	end
end

-- Builds the castle centred on origin, and returns where its gate is, so the
-- path knows what to lead to.
function Castle.build(origin: Vector3, parent: Instance): Vector3
	local model = Instance.new("Model")
	model.Name = "Castle"
	model.Parent = parent

	local half = Config.Castle.Width / 2
	local height = Config.Castle.WallHeight
	local thickness = Config.Castle.WallThickness

	-- Courtyard floor, raised slightly so the castle sits on a mound.
	block(
		"Courtyard",
		Vector3.new(Config.Castle.Width, 2, Config.Castle.Width),
		CFrame.new(origin + Vector3.new(0, 1, 0)),
		Config.Castle.StoneDarkColor,
		model
	)

	local function place(part: Part)
		part.CFrame = part.CFrame + origin
	end

	-- Back and side walls are solid runs; the front has the gate.
	local back = block(
		"WallBack",
		Vector3.new(Config.Castle.Width, height, thickness),
		CFrame.new(0, height / 2, -half),
		Config.Castle.StoneColor,
		model
	)
	place(back)

	for _, side in { -1, 1 } do
		local wall = block(
			"WallSide",
			Vector3.new(thickness, height, Config.Castle.Width),
			CFrame.new(side * half, height / 2, 0),
			Config.Castle.StoneColor,
			model
		)
		place(wall)
	end

	local front = Instance.new("Model")
	front.Name = "Gatehouse"
	front.Parent = model
	gateWall(half, front)
	for _, item in front:GetDescendants() do
		if item:IsA("BasePart") then
			item.CFrame = item.CFrame + origin
		end
	end

	-- Battlements around the top of all four walls.
	for _, run in
		{
			{ Vector3.new(-half, 0, -half), Vector3.new(half, 0, -half) },
			{ Vector3.new(-half, 0, half), Vector3.new(half, 0, half) },
			{ Vector3.new(-half, 0, -half), Vector3.new(-half, 0, half) },
			{ Vector3.new(half, 0, -half), Vector3.new(half, 0, half) },
		}
	do
		battlement(origin + run[1], origin + run[2], height + Config.Castle.MerlonHeight / 2, model)
	end

	-- A tower at each corner.
	for _, corner in
		{
			Vector3.new(-half, 0, -half),
			Vector3.new(half, 0, -half),
			Vector3.new(-half, 0, half),
			Vector3.new(half, 0, half),
		}
	do
		tower(origin + corner, model)
	end

	-- The gate mouth: where the path should end.
	return origin + Vector3.new(0, 0, half + 6)
end

return Castle

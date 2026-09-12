--[[
	CaveService
	A rock mound with a barred cave mouth, a tunnel, and a chamber behind it.

	The gate is shut. Standing near it raises a ProximityPrompt - Roblox's own
	"hold E" interaction - and holding it grinds the bars up into the lintel.
	A prompt is the right tool here rather than a custom screen: it appears
	only in range, shows on any input device including gamepad and touch, and
	needs nothing downloaded.

	Everything is parts rather than terrain, because GroundService clears
	terrain across the world in baseplate mode and would eat a terrain cave on
	the next run.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local SaveService = require(script.Parent.SaveService)

local CaveService = {}

-- Set while the gate is moving or open, so repeated triggers do not stack
-- tweens on top of each other.
local gateBusy = false

local function rock(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Rock
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

--[[
	The clear corridor in front of the mouth.

	Rock is placed by angle around the mound, which sooner or later drops a
	boulder over the entrance - that is what was blocking it. Rather than
	widening the excluded arc and hoping, every piece is tested against an
	actual corridor: a box running from just inside the mouth straight out
	past the foot of the hill. Anything overlapping it is skipped, whatever
	ring it came from.

	x and z are in the cave's local space: the mouth faces +z, the tunnel runs
	into -z.
]]
local function blocksMouth(x: number, z: number, size: Vector3): boolean
	local clearHalfWidth = Config.Cave.MouthWidth / 2 + Config.Cave.MouthClearance
	local insideMouth = -4

	--[[
		Half the diagonal, not half the width.

		Every boulder is rotated on all three axes, so its footprint is wider
		than its own X and Z. Testing against those let rotated slabs poke
		into the corridor and stand in the doorway - measuring the diagonal
		is pessimistic, and pessimistic is what a doorway needs.
	]]
	local extent = size.Magnitude / 2

	local overlapsWidth = math.abs(x) - extent < clearHalfWidth
	local overlapsDepth = z + extent > insideMouth

	return overlapsWidth and overlapsDepth
end

-- The furthest forward anything of this size may sit without reaching into
-- the corridor. Used to seat the crown behind the entrance rather than
-- dropping it and hoping.
local function clearDepth(size: Vector3): number
	return -4 - size.Magnitude / 2
end

--[[
	The mound, built from blocks only.

	Boulders are rectangular slabs, each rotated on all three axes and sized
	differently. Rotation is what sells it: an un-rotated block reads as a
	wall, while the same block tipped and turned reads as a slab of stone, and
	enough of them overlapping read as a hill.

	The variation is deterministic - driven by sin and cos of the index rather
	than math.random - so the cave looks the same every run instead of
	reshuffling itself each time you press Play.
]]
local function buildMound(origin: CFrame, parent: Instance)
	local radius = Config.Cave.MoundRadius
	local height = Config.Cave.MoundHeight

	local function palette(index: number): Color3
		if index % 3 == 0 then
			return Config.Cave.RockDarkColor
		elseif index % 5 == 0 then
			return Config.Cave.RockLightColor
		end
		return Config.Cave.RockColor
	end

	-- Places one slab unless it would stand in the entrance.
	local function slab(
		name: string,
		index: number,
		x: number,
		y: number,
		z: number,
		size: Vector3,
		tilt: Vector3
	)
		if blocksMouth(x, z, size) then
			return
		end

		rock(
			name,
			size,
			origin * CFrame.new(x, y, z) * CFrame.Angles(tilt.X, tilt.Y, tilt.Z),
			palette(index),
			parent
		)
	end

	-- Outer ring: the wide base of the hill.
	for index = 1, Config.Cave.BoulderCount do
		local angle = (index / Config.Cave.BoulderCount) * math.pi * 2
		local wobble = math.sin(index * 2.4)
		local distance = radius * (0.68 + wobble * 0.14)
		local size = height * (0.5 + math.cos(index * 1.7) * 0.2)

		slab(
			"Boulder",
			index,
			math.cos(angle) * distance,
			size * 0.3 - 5,
			math.sin(angle) * distance,
			Vector3.new(size * 1.6, size * 1.1, size * 1.4),
			Vector3.new(wobble * 0.4, angle, math.cos(index) * 0.35)
		)
	end

	-- Inner ring: pulled back and stacked higher, so the hill rises rather
	-- than staying flat-topped.
	for index = 1, Config.Cave.InnerCount do
		local angle = (index / Config.Cave.InnerCount) * math.pi * 2
		local wobble = math.cos(index * 3.1)
		local distance = radius * (0.36 + wobble * 0.1)
		local size = height * (0.58 + math.sin(index * 2.2) * 0.18)

		slab(
			"BoulderInner",
			index + 1,
			math.cos(angle) * distance,
			size * 0.55,
			math.sin(angle) * distance - 8,
			Vector3.new(size * 1.4, size * 1.2, size * 1.3),
			Vector3.new(wobble * 0.35, angle * 1.4, wobble * 0.3)
		)
	end

	--[[
		Crown, filling the top between the inner lumps.

		This was the piece standing in the doorway: it skipped the corridor
		test, and at 60-odd studs deep it reached well past the mouth however
		far back it was nudged. Its depth is now computed - seated just behind
		the clear corridor - so it roofs the mound and cannot lean over the
		entrance whatever size it is given.
	]]
	local capSize = Vector3.new(radius * 1.1, height * 0.8, radius * 0.9)
	rock(
		"MoundCap",
		capSize,
		origin * CFrame.new(0, height * 0.5, clearDepth(capSize)) * CFrame.Angles(0.12, 0.3, 0.06),
		Config.Cave.RockColor,
		parent
	)

	-- Rubble round the base, so the mound meets the ground in broken stone
	-- rather than a clean line.
	for index = 1, Config.Cave.RubbleCount do
		local angle = index * 2.399
		local distance = radius * (0.55 + math.sin(index * 1.3) * 0.45)
		local size = 3 + math.abs(math.cos(index * 1.9)) * 6

		slab(
			"Rubble",
			index + 2,
			math.cos(angle) * distance,
			size * 0.25 - 2,
			math.sin(angle) * distance,
			Vector3.new(size * 1.4, size, size * 1.2),
			Vector3.new(index * 0.4, angle, index * 0.27)
		)
	end
end

-- The mouth: two jambs and a lintel around the opening, plus the tunnel and
-- chamber walls behind it.
local function buildEntrance(origin: CFrame, parent: Instance)
	local width = Config.Cave.MouthWidth
	local height = Config.Cave.MouthHeight
	local tunnel = Config.Cave.TunnelLength
	local chamber = Config.Cave.ChamberSize

	for _, side in { -1, 1 } do
		rock(
			"Jamb",
			Vector3.new(6, height + 6, 8),
			origin * CFrame.new(side * (width / 2 + 3), (height + 6) / 2, 0),
			Config.Cave.RockDarkColor,
			parent
		)
	end

	rock(
		"Lintel",
		Vector3.new(width + 12, 6, 8),
		origin * CFrame.new(0, height + 3, 0),
		Config.Cave.RockDarkColor,
		parent
	)

	-- Tunnel: floor, ceiling and two walls, leaving the middle walkable.
	rock(
		"TunnelFloor",
		Vector3.new(width, 1, tunnel),
		origin * CFrame.new(0, -0.5, -tunnel / 2),
		Config.Cave.RockDarkColor,
		parent
	)
	rock(
		"TunnelRoof",
		Vector3.new(width + 12, 4, tunnel),
		origin * CFrame.new(0, height + 2, -tunnel / 2),
		Config.Cave.RockColor,
		parent
	)
	for _, side in { -1, 1 } do
		rock(
			"TunnelWall",
			Vector3.new(4, height, tunnel),
			origin * CFrame.new(side * (width / 2 + 2), height / 2, -tunnel / 2),
			Config.Cave.RockColor,
			parent
		)
	end

	-- Chamber: a room at the end of the tunnel.
	local centre = -tunnel - chamber.Z / 2

	rock(
		"ChamberFloor",
		Vector3.new(chamber.X, 2, chamber.Z),
		origin * CFrame.new(0, -1, centre),
		Config.Cave.RockDarkColor,
		parent
	)
	rock(
		"ChamberRoof",
		Vector3.new(chamber.X, 2, chamber.Z),
		origin * CFrame.new(0, chamber.Y, centre),
		Config.Cave.RockColor,
		parent
	)
	rock(
		"ChamberBack",
		Vector3.new(chamber.X, chamber.Y, 3),
		origin * CFrame.new(0, chamber.Y / 2, centre - chamber.Z / 2),
		Config.Cave.RockColor,
		parent
	)
	for _, side in { -1, 1 } do
		rock(
			"ChamberWall",
			Vector3.new(3, chamber.Y, chamber.Z),
			origin * CFrame.new(side * chamber.X / 2, chamber.Y / 2, centre),
			Config.Cave.RockColor,
			parent
		)
	end

	-- The wall the tunnel pierces, built either side of the opening.
	for _, side in { -1, 1 } do
		local segment = (chamber.X - width) / 2
		rock(
			"ChamberFront",
			Vector3.new(segment, chamber.Y, 3),
			origin * CFrame.new(side * (width / 2 + segment / 2), chamber.Y / 2, centre + chamber.Z / 2),
			Config.Cave.RockColor,
			parent
		)
	end

	-- Something to see once you are in.
	local glow = Instance.new("PointLight")
	glow.Color = Config.Cave.GlowColor
	glow.Brightness = 2.5
	glow.Range = 48
	glow.Shadows = true

	local crystal = rock(
		"Crystal",
		Vector3.new(4, 9, 4),
		origin * CFrame.new(0, 4, centre - chamber.Z / 4) * CFrame.Angles(0.2, 0.4, 0.1),
		Config.Cave.GlowColor,
		parent
	)
	crystal.Material = Enum.Material.Neon
	glow.Parent = crystal
end

--[[
	The iron gate.

	Every bar is anchored, and the whole grid is a Model moved with PivotTo.

	The first version welded unanchored bars to an anchored frame. That relies
	on physics holding the weld, and anything that disturbs it - a player
	walking into the bars, the weld failing to form before the parts settle -
	leaves the bars lying on the floor and the mouth wide open, which is
	exactly what happened. Anchored parts cannot be pushed anywhere; the only
	thing that moves them is this service.
]]
local function buildGate(origin: CFrame, parent: Instance): Model
	local width = Config.Cave.MouthWidth
	local height = Config.Cave.MouthHeight

	local gate = Instance.new("Model")
	gate.Name = "IronGate"
	gate.Parent = parent

	local function bar(name: string, size: Vector3, offset: CFrame): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = origin * offset
		part.Color = Config.Cave.BarColor
		part.Material = Enum.Material.Metal
		part.Reflectance = 0.1
		part.Anchored = true
		part.CanCollide = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = gate
		return part
	end

	-- The top rail doubles as the model's pivot: everything moves with it.
	local frame = bar("GateFrame", Vector3.new(width + 2, 1.6, 1.6), CFrame.new(0, height - 0.8, 0))
	gate.PrimaryPart = frame

	for index = 1, Config.Cave.BarCount do
		local offset = -width / 2 + (index - 0.5) * (width / Config.Cave.BarCount)
		bar(
			"Bar",
			Vector3.new(Config.Cave.BarThickness, height, Config.Cave.BarThickness),
			CFrame.new(offset, height / 2, 0)
		)
	end

	-- Crossbars, so it reads as a gate rather than a row of poles.
	for _, fraction in { 0.28, 0.7 } do
		bar("Crossbar", Vector3.new(width, 1.1, 1.1), CFrame.new(0, height * fraction, 0))
	end

	return gate
end

--[[
	Raises the gate, then drops it shut again.

	Moved by hand rather than with TweenService: a tween animates one
	instance, and this is a Model of anchored parts that has to move together.
	PivotTo does exactly that, so the loop just walks the pivot upward.
]]
local function slideGate(gate: Model, from: CFrame, to: CFrame, duration: number)
	local elapsed = 0

	while elapsed < duration and gate.Parent do
		elapsed += task.wait()
		local alpha = math.min(elapsed / duration, 1)
		-- Ease out, so it starts fast and settles rather than stopping dead.
		local eased = 1 - (1 - alpha) * (1 - alpha)
		gate:PivotTo(from:Lerp(to, eased))
	end

	if gate.Parent then
		gate:PivotTo(to)
	end
end

local function openGate(gate: Model, closed: CFrame)
	if gateBusy then
		return
	end
	gateBusy = true

	local open = closed * CFrame.new(0, Config.Cave.MouthHeight + 2, 0)
	slideGate(gate, closed, open, Config.Cave.OpenTime)

	if Config.Cave.CloseAfter <= 0 then
		return
	end

	task.wait(Config.Cave.CloseAfter)
	slideGate(gate, open, closed, Config.Cave.OpenTime)
	gateBusy = false
end

function CaveService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Cave"
	folder.Parent = workspace

	-- One CFrame for the whole cave: everything else is placed relative to it,
	-- so moving or turning the cave is a single Config change.
	local facing = Config.Cave.Facing.Unit
	local origin = CFrame.lookAt(Config.Cave.Position, Config.Cave.Position + facing)

	buildMound(origin, folder)
	buildEntrance(origin, folder)

	local gate = buildGate(origin, folder)
	local closedPivot = gate:GetPivot()

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterPrompt"
	prompt.ActionText = Config.Cave.PromptAction
	prompt.ObjectText = Config.Cave.PromptObject
	prompt.MaxActivationDistance = Config.Cave.PromptDistance
	prompt.HoldDuration = Config.Cave.HoldDuration
	prompt.RequiresLineOfSight = false
	prompt.Parent = gate.PrimaryPart

	prompt.Triggered:Connect(function(player)
		SaveService:Update(player, function(profile)
			profile.CaveOpened = true
		end)

		-- Opening yields, so it runs on its own thread rather than blocking
		-- the prompt from firing again.
		task.spawn(openGate, gate, closedPivot)
	end)

	print("[Cave] built, gate shut.")
end

return CaveService

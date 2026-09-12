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
	The mound.

	Three layers of boulders rather than one ring: an outer ring of large
	lumps, an inner ring stacked higher and pulled back, and small rubble
	scattered round the base. Overlapping lumps of different sizes and angles
	read as rock; a single dome reads as a bubble, and one even ring reads as
	a fence.

	The variation is deterministic - driven by sin and cos of the index rather
	than math.random - so the cave looks the same every run instead of
	reshuffling itself each time you press Play.
]]
local function buildMound(origin: CFrame, parent: Instance)
	local radius = Config.Cave.MoundRadius
	local height = Config.Cave.MoundHeight

	local function boulder(name: string, size: Vector3, cframe: CFrame, color: Color3)
		local part = rock(name, size, cframe, color, parent)
		part.Shape = Enum.PartType.Ball
		return part
	end

	local function palette(index: number): Color3
		if index % 3 == 0 then
			return Config.Cave.RockDarkColor
		elseif index % 5 == 0 then
			return Config.Cave.RockLightColor
		end
		return Config.Cave.RockColor
	end

	-- The arc left open for the mouth, in radians either side of the front.
	local function isMouth(angle: number): boolean
		return math.abs(angle - math.pi / 2) < 0.42
	end

	-- Outer ring: the wide base of the hill.
	for index = 1, Config.Cave.BoulderCount do
		local angle = (index / Config.Cave.BoulderCount) * math.pi * 2
		if not isMouth(angle) then
			local wobble = math.sin(index * 2.4)
			local distance = radius * (0.68 + wobble * 0.14)
			local size = height * (0.52 + math.cos(index * 1.7) * 0.2)

			boulder(
				"Boulder",
				Vector3.new(size * 1.7, size * 1.15, size * 1.5),
				origin
					* CFrame.new(math.cos(angle) * distance, size * 0.3 - 4, math.sin(angle) * distance)
					* CFrame.Angles(wobble * 0.35, angle, math.cos(index) * 0.25),
				palette(index)
			)
		end
	end

	-- Inner ring: pulled back and stacked higher, so the hill rises rather
	-- than staying flat-topped.
	for index = 1, Config.Cave.InnerCount do
		local angle = (index / Config.Cave.InnerCount) * math.pi * 2
		if not isMouth(angle) then
			local wobble = math.cos(index * 3.1)
			local distance = radius * (0.34 + wobble * 0.1)
			local size = height * (0.6 + math.sin(index * 2.2) * 0.18)

			boulder(
				"BoulderInner",
				Vector3.new(size * 1.5, size * 1.25, size * 1.4),
				origin
					* CFrame.new(math.cos(angle) * distance, size * 0.55, math.sin(angle) * distance - 6)
					* CFrame.Angles(wobble * 0.3, angle * 1.4, wobble * 0.2),
				palette(index + 1)
			)
		end
	end

	-- Crown, filling the top between the inner lumps.
	boulder(
		"MoundCap",
		Vector3.new(radius * 1.25, height * 1.05, radius * 1.2),
		origin * CFrame.new(0, height * 0.42, -12),
		Config.Cave.RockColor
	)

	-- Rubble round the base, spilling toward the mouth so the entrance looks
	-- worn rather than cut.
	for index = 1, Config.Cave.RubbleCount do
		local angle = index * 2.399
		local distance = radius * (0.55 + math.sin(index * 1.3) * 0.45)
		local size = 3 + math.abs(math.cos(index * 1.9)) * 6

		boulder(
			"Rubble",
			Vector3.new(size * 1.4, size, size * 1.2),
			origin
				* CFrame.new(math.cos(angle) * distance, size * 0.25 - 1.5, math.sin(angle) * distance)
				* CFrame.Angles(index * 0.4, angle, index * 0.27),
			palette(index + 2)
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

	prompt.Triggered:Connect(function()
		-- Opening yields, so it runs on its own thread rather than blocking
		-- the prompt from firing again.
		task.spawn(openGate, gate, closedPivot)
	end)

	print("[Cave] built, gate shut.")
end

return CaveService

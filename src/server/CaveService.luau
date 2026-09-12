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
local TweenService = game:GetService("TweenService")

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

	Boulders scattered around a ring, each a squashed ball at its own angle and
	size. A single dome would read as a bubble; overlapping lumps of different
	sizes read as rock.
]]
local function buildMound(origin: CFrame, parent: Instance)
	local radius = Config.Cave.MoundRadius

	for index = 1, Config.Cave.BoulderCount do
		local angle = (index / Config.Cave.BoulderCount) * math.pi * 2
		-- Deterministic variation: the same cave every run, but not uniform.
		local wobble = math.sin(index * 2.4)
		local distance = radius * (0.62 + wobble * 0.16)
		local size = Config.Cave.MoundHeight * (0.7 + math.cos(index * 1.7) * 0.25)

		-- The front of the mound is left open for the mouth.
		local isFront = math.abs(angle - math.pi / 2) < 0.5
		if not isFront then
			local boulder = rock(
				"Boulder",
				Vector3.new(size * 1.5, size, size * 1.4),
				origin
					* CFrame.new(math.cos(angle) * distance, size / 2 - 3, math.sin(angle) * distance)
					* CFrame.Angles(wobble * 0.3, angle, wobble * 0.2),
				if index % 3 == 0 then Config.Cave.RockDarkColor else Config.Cave.RockColor,
				parent
			)
			boulder.Shape = Enum.PartType.Ball
		end
	end

	-- A cap over the top so the mound is closed rather than a ring of rocks.
	local cap = rock(
		"MoundCap",
		Vector3.new(radius * 1.5, Config.Cave.MoundHeight, radius * 1.5),
		origin * CFrame.new(0, Config.Cave.MoundHeight * 0.45, -4),
		Config.Cave.RockColor,
		parent
	)
	cap.Shape = Enum.PartType.Ball
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

	Bars are welded to a single frame part, so the whole grid can be moved by
	tweening that one part rather than animating every bar in step.
]]
local function buildGate(origin: CFrame, parent: Instance): BasePart
	local width = Config.Cave.MouthWidth
	local height = Config.Cave.MouthHeight

	local frame = Instance.new("Part")
	frame.Name = "GateFrame"
	frame.Size = Vector3.new(width, 1.2, 1.2)
	frame.CFrame = origin * CFrame.new(0, height - 0.6, 0)
	frame.Color = Config.Cave.BarColor
	frame.Material = Enum.Material.Metal
	frame.Anchored = true
	frame.Parent = parent

	local function attach(part: BasePart)
		part.Color = Config.Cave.BarColor
		part.Material = Enum.Material.Metal
		part.Anchored = false
		part.CanCollide = true
		part.Massless = true
		part.Parent = parent

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = frame
		weld.Part1 = part
		weld.Parent = frame
	end

	for index = 1, Config.Cave.BarCount do
		local offset = -width / 2 + (index - 0.5) * (width / Config.Cave.BarCount)
		local bar = Instance.new("Part")
		bar.Name = "Bar"
		bar.Size = Vector3.new(Config.Cave.BarThickness, height, Config.Cave.BarThickness)
		bar.CFrame = origin * CFrame.new(offset, height / 2, 0)
		attach(bar)
	end

	-- Two crossbars, so it reads as a gate rather than a row of poles.
	for _, fraction in { 0.3, 0.72 } do
		local rail = Instance.new("Part")
		rail.Name = "Crossbar"
		rail.Size = Vector3.new(width, 1, 1)
		rail.CFrame = origin * CFrame.new(0, height * fraction, 0)
		attach(rail)
	end

	return frame
end

-- Raises the gate, then drops it again after CloseAfter seconds.
local function openGate(frame: BasePart, closedCFrame: CFrame)
	if gateBusy then
		return
	end
	gateBusy = true

	local lift = Config.Cave.MouthHeight + 2
	local info = TweenInfo.new(Config.Cave.OpenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	TweenService:Create(frame, info, { CFrame = closedCFrame * CFrame.new(0, lift, 0) }):Play()

	if Config.Cave.CloseAfter <= 0 then
		return
	end

	task.delay(Config.Cave.OpenTime + Config.Cave.CloseAfter, function()
		local shut = TweenService:Create(frame, info, { CFrame = closedCFrame })
		shut:Play()
		shut.Completed:Wait()
		gateBusy = false
	end)
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

	local frame = buildGate(origin, folder)
	local closedCFrame = frame.CFrame

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterPrompt"
	prompt.ActionText = Config.Cave.PromptAction
	prompt.ObjectText = Config.Cave.PromptObject
	prompt.MaxActivationDistance = Config.Cave.PromptDistance
	prompt.HoldDuration = Config.Cave.HoldDuration
	prompt.RequiresLineOfSight = false
	prompt.Parent = frame

	prompt.Triggered:Connect(function()
		openGate(frame, closedCFrame)
	end)

	print("[Cave] built, gate shut.")
end

return CaveService

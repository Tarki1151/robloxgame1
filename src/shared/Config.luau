--!strict
--[[
	Config
	Every tunable value for the game lives here, so balance and look changes
	never require touching gameplay code.
]]

local Config = {}

Config.Ground = {
	-- false: keep the baseplate solid and visible, painted grass green, and
	-- clear any terrain previously laid over it. true: terrain grass instead,
	-- with the baseplate hidden underneath so the two surfaces do not
	-- z-fight at the same height.
	UseTerrain = false,
	-- How far the grass reaches. The area is measured from the ground already
	-- in the place, so the grass covers all of it rather than leaving a
	-- square of baseplate showing around the edges. These are the bounds of
	-- that measurement.
	MinSize = 512,
	MaxSize = 2048,
	-- Studs of grass past the edge of the ground, so there is no visible seam.
	Margin = 64,
	-- How deep the soil goes below the surface.
	Depth = 16,
	-- Terrain is filled in chunks this wide, yielding between them. Filling a
	-- large area in one call freezes the server while it works.
	ChunkSize = 256,
	-- Waving grass blades on the surface. Turn off if it costs frames.
	Decoration = true,
	-- Grass colour. Terrain materials are tinted, not textured over.
	GrassColor = Color3.fromRGB(86, 122, 58),
	GroundColor = Color3.fromRGB(78, 66, 52),
	-- Used only when UseTerrain is false.
	FallbackColor = Color3.fromRGB(84, 118, 56),
	FallbackMaterial = Enum.Material.Grass,
	-- Anything flat, anchored and at least this wide counts as ground.
	MinWidth = 100,
}

--[[
	The castle on the horizon, the path to it, and the signpost.

	Everything is built from parts at run time, so there is no model to import
	and every dimension is a number you can change here.
]]
Config.Castle = {
	-- How far out it sits, and which way. Straight ahead from spawn.
	Distance = 340,
	Direction = Vector3.new(0, 0, -1),
	-- Overall footprint. Kept under 100 studs so GroundService does not
	-- mistake the courtyard floor for ground and paint it green.
	Width = 84,
	WallHeight = 26,
	WallThickness = 5,
	-- Corner towers.
	TowerRadius = 9,
	TowerHeight = 40,
	RoofHeight = 16,
	-- Battlements along the top of the walls.
	MerlonWidth = 4,
	MerlonHeight = 4,
	MerlonGap = 4,
	-- The gatehouse opening in the near wall.
	GateWidth = 16,
	GateHeight = 18,
	StoneColor = Color3.fromRGB(126, 122, 116),
	StoneDarkColor = Color3.fromRGB(98, 95, 90),
	RoofColor = Color3.fromRGB(94, 46, 52),
	BannerColor = Color3.fromRGB(150, 40, 48),
	Material = Enum.Material.Slate,
}

Config.Path = {
	-- Slabs from the spawn to the castle gate.
	Width = 12,
	SlabLength = 9,
	Gap = 1.5,
	Thickness = 1,
	-- Sunk slightly so the slabs sit in the grass rather than on top of it.
	Sink = 0.35,
	-- Each slab wanders a little, so the path is not a ruler line.
	Wander = 1.6,
	Color = Color3.fromRGB(142, 136, 126),
	EdgeColor = Color3.fromRGB(112, 107, 99),
	Material = Enum.Material.Cobblestone,
	-- Where the path starts, near the spawn.
	StartOffset = 24,
}

Config.Sign = {
	Text = "CASTLE",
	-- Placed beside the start of the path.
	Position = Vector3.new(14, 0, 6),
	PostHeight = 9,
	BoardSize = Vector3.new(14, 5, 0.6),
	ArrowLength = 6,
	PostColor = Color3.fromRGB(88, 62, 40),
	BoardColor = Color3.fromRGB(126, 92, 58),
	ArrowColor = Color3.fromRGB(232, 196, 96),
	TextColor = Color3.fromRGB(255, 246, 226),
}

--[[
	The cave, its iron gate, and the chamber behind it.

	Built from parts rather than terrain: GroundService clears terrain over
	the whole world when it is in baseplate mode, which would eat a terrain
	cave on the next run.
]]
Config.Cave = {
	-- Off to one side of the path to the castle.
	Position = Vector3.new(-190, 0, -140),
	-- Which way the mouth faces. Toward the spawn, so it is visible walking out.
	Facing = Vector3.new(0.35, 0, 1),
	-- The rock mound.
	MoundRadius = 62,
	MoundHeight = 48,
	-- Boulders in the outer ring, the inner ring, and scattered as rubble.
	BoulderCount = 26,
	InnerCount = 14,
	RubbleCount = 22,
	RockColor = Color3.fromRGB(74, 70, 68),
	RockDarkColor = Color3.fromRGB(52, 49, 48),
	RockLightColor = Color3.fromRGB(92, 88, 84),
	-- The entrance.
	MouthWidth = 20,
	MouthHeight = 18,
	-- The chamber behind it.
	ChamberSize = Vector3.new(76, 30, 76),
	TunnelLength = 30,
	GlowColor = Color3.fromRGB(120, 180, 255),
	-- Stalagmites and stalactites inside.
	SpikeCount = 18,
	-- Iron bars across the mouth.
	BarCount = 11,
	BarThickness = 1.1,
	BarColor = Color3.fromRGB(42, 44, 48),
	-- How long the gate takes to grind open.
	OpenTime = 1.8,
	-- Seconds the gate stays open before dropping shut again. 0 keeps it open.
	CloseAfter = 15,
	-- How close you must be for the prompt to appear.
	PromptDistance = 22,
	PromptAction = "Enter",
	PromptObject = "Cave",
	-- Held rather than tapped, so it is a deliberate choice.
	HoldDuration = 0.6,
}

-- What stands inside the castle walls.
Config.Keep = {
	-- The central building.
	Size = Vector3.new(34, 30, 30),
	RoofHeight = 8,
	DoorWidth = 8,
	DoorHeight = 12,
	-- Steps up to the wall walk.
	StairCount = 10,
	StairWidth = 8,
	-- Props scattered round the courtyard.
	BarrelCount = 7,
	CrateCount = 6,
	TorchCount = 8,
	WoodColor = Color3.fromRGB(94, 66, 42),
	WoodDarkColor = Color3.fromRGB(68, 48, 32),
	MetalColor = Color3.fromRGB(74, 74, 80),
	FlameColor = Color3.fromRGB(255, 164, 62),
	WellColor = Color3.fromRGB(108, 104, 98),
}

return Config

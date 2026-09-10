--!strict
--[[
	Config
	Every tunable value for the game lives here, so balance and look changes
	never require touching gameplay code.
]]

local Config = {}

Config.Ground = {
	-- Terrain grass rather than a green baseplate: terrain renders actual
	-- grass blades, takes footstep sounds, and can be sculpted later.
	-- Set false to recolour the existing baseplate instead.
	UseTerrain = true,
	-- Studs across, and how deep the soil goes below the surface.
	Size = 512,
	Depth = 20,
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

return Config

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

return Config

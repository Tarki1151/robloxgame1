--!strict
--[[
	Config
	Every tunable value for the game lives here, so balance and look changes
	never require touching gameplay code.
]]

local Config = {}

-- The ground. The stock Studio baseplate is a bright light grey, which washes
-- out anything dark placed on it.
Config.Ground = {
	Color = Color3.fromRGB(32, 34, 38),
	Material = Enum.Material.Slate,
	-- Anything flat, anchored and at least this wide counts as ground.
	MinWidth = 100,
}

return Config

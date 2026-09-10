--!strict
--[[
	Config
	Every tunable value for the game lives here, so balance and look changes
	never require touching gameplay code.
]]

local Config = {}

-- The avatar is forced to look identical for every player: a pitch black
-- classic noob. Nothing is read from the player's own Roblox avatar.
Config.Avatar = {
	BodyColor = Color3.fromRGB(10, 10, 12),
	-- Slight sheen so the silhouette still reads against a dark sky.
	Material = Enum.Material.SmoothPlastic,
	Reflectance = 0.05,
	-- Strip hats, hair, shirts, pants, faces. A noob has none of it.
	RemoveAccessories = true,
	RemoveClothing = true,
	RemoveFace = true,
}

Config.Fire = {
	-- Body flames.
	Color = Color3.fromRGB(255, 138, 40),
	SecondaryColor = Color3.fromRGB(255, 226, 130),
	-- Particles per second on the torso; limbs get a fraction of this.
	TorsoRate = 26,
	LimbRate = 12,
	Size = 2.6,
	Lifetime = NumberRange.new(0.35, 0.75),
	Speed = NumberRange.new(3, 7),
	-- Point light so the flames actually light the ground.
	LightBrightness = 3,
	LightRange = 18,
}

Config.Wings = {
	-- Three pairs, mirrored left and right.
	Pairs = 3,
	Length = 7.5,
	Width = 2.6,
	Thickness = 0.22,
	-- Vertical spacing between pairs, and how far each pair sweeps back.
	Spread = 1.5,
	Sweep = 0.35,
	-- Flap cycles per second, and how far the wings swing (radians).
	FlapSpeed = 2.4,
	FlapAmount = 0.42,
	-- Each pair lags slightly behind the one above it, so the flap ripples.
	PairDelay = 0.28,
	Color = Color3.fromRGB(255, 110, 30),
	Transparency = 0.25,
}

Config.Sword = {
	Name = "Flame Sword",
	BladeLength = 5.5,
	BladeWidth = 0.55,
	BladeColor = Color3.fromRGB(255, 90, 20),
	HiltColor = Color3.fromRGB(28, 24, 26),
	-- Seconds between swings.
	Cooldown = 0.55,
	-- How long the slash pose takes to play out.
	SwingDuration = 0.35,
}

-- The procedural animation pack. These drive Motor6D joints directly, so
-- no uploaded animation assets are involved.
Config.Pose = {
	-- How far the visible body is lifted off the ground. The collision box
	-- stays put, so walking still behaves normally.
	HoverHeight = 3.2,
	-- Vertical bob: how far, and how many cycles per second.
	BobAmount = 0.45,
	BobSpeed = 1.1,
	-- Idle float: limbs hang, arms drift.
	IdleArmSwing = 0.18,
	IdleLegSwing = 0.12,
	IdleSpeed = 1.4,
	-- Flight pose: entered while airborne. Body leans forward, legs trail.
	FlightLean = 0.45,
	FlightLegAngle = 0.55,
	-- How fast poses blend into each other (higher = snappier).
	BlendSpeed = 8,
}

return Config

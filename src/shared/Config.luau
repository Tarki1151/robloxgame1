--!strict
--[[
	Config
	Every tunable value lives here, so balance and look changes never require
	touching gameplay code.
]]

local Config = {}

Config.Player = {
	MaxHealth = 100,
	-- Players keep their own Roblox avatar. Nothing about their appearance
	-- is touched.
	WalkSpeed = 16,
}

-- The classic linked-sword handed to every player on spawn.
Config.Sword = {
	Name = "Classic Sword",
	Damage = 20,
	-- Seconds between swings.
	Cooldown = 0.6,
	-- How long the blade deals damage after a swing starts.
	HitWindow = 0.35,
	-- Same target cannot be hit twice inside this window.
	HitDebounce = 0.5,
	BladeColor = Color3.fromRGB(163, 162, 165),
	GripColor = Color3.fromRGB(70, 70, 75),
}

-- The burning noob, now an NPC rather than the player.
Config.Npc = {
	Name = "Burning Noob",
	MaxHealth = 200,
	WalkSpeed = 14,
	-- Melee: damage per hit and seconds between hits.
	Damage = 10,
	AttackCooldown = 5,
	-- How close it must be to land a hit, and how far it will notice a player.
	AttackRange = 7,
	AggroRange = 90,
	-- Seconds before a new one spawns after it dies.
	RespawnDelay = 6,
	-- Where it spawns, relative to the world origin.
	SpawnPosition = Vector3.new(0, 6, -28),
	BodyColor = Color3.fromRGB(10, 10, 12),
	Material = Enum.Material.SmoothPlastic,
}

-- The special: every Interval seconds the NPC launches a flame at its target.
-- Independent of the melee cooldown, so it can throw while walking.
Config.Special = {
	Interval = 15,
	Damage = 15,
	-- Studs per second, and how close it must get to count as a hit.
	Speed = 60,
	HitRadius = 4,
	-- Give up after this long so a stray flame never lives forever.
	Lifetime = 6,
	Size = 2.4,
	Color = Color3.fromRGB(255, 120, 30),
	-- Windup before the flame leaves its hand, so the swing reads first.
	Windup = 0.4,
}

Config.Fire = {
	Color = Color3.fromRGB(255, 138, 40),
	SecondaryColor = Color3.fromRGB(255, 226, 130),
	TorsoRate = 26,
	LimbRate = 12,
	Size = 2.6,
	Lifetime = NumberRange.new(0.35, 0.75),
	Speed = NumberRange.new(3, 7),
	LightBrightness = 3,
	LightRange = 18,
}

Config.Wings = {
	-- Three pairs, mirrored left and right.
	Pairs = 3,
	Length = 7.5,
	Width = 2.6,
	Thickness = 0.22,
	Spread = 1.5,
	Sweep = 0.35,
	FlapSpeed = 2.4,
	FlapAmount = 0.42,
	PairDelay = 0.28,
	Color = Color3.fromRGB(255, 110, 30),
	Transparency = 0.25,
}

Config.FlameSword = {
	BladeLength = 5.5,
	BladeWidth = 0.55,
	BladeColor = Color3.fromRGB(255, 90, 20),
	HiltColor = Color3.fromRGB(28, 24, 26),
}

-- The NPC's procedural animation set. These drive Motor6D joints directly,
-- so no uploaded animation assets are involved.
Config.Pose = {
	-- How far the visible body is lifted off the ground. The collision box
	-- stays put, so walking still behaves normally.
	HoverHeight = 2.4,
	BobAmount = 0.35,
	BobSpeed = 1.1,
	IdleArmSwing = 0.18,
	IdleLegSwing = 0.12,
	IdleSpeed = 1.4,
	-- Chasing a player: leans forward, legs trail.
	ChaseLean = 0.3,
	ChaseLegAngle = 0.4,
	SwingDuration = 0.45,
	BlendSpeed = 8,
}

Config.Ui = {
	-- Player health bar.
	BarSize = UDim2.new(0, 260, 0, 26),
	BarOffset = UDim2.new(0, 20, 0, -46),
	Background = Color3.fromRGB(22, 22, 26),
	HealthHigh = Color3.fromRGB(86, 200, 96),
	HealthLow = Color3.fromRGB(214, 64, 58),
	Text = Color3.fromRGB(240, 240, 245),
	-- Overhead bar on the NPC.
	NpcBarSize = UDim2.fromScale(1, 0.32),
	NpcBarHeight = 4.5,
	NpcBarDistance = 140,
}

return Config

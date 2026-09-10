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

-- Behaviour shared by every weapon. Per-weapon numbers live in Config.Weapons.
Config.Sword = {
	-- Seconds between swings.
	Cooldown = 0.6,
	-- How long the blade deals damage after a swing starts.
	HitWindow = 0.35,
	-- The same target cannot be hit twice inside this window.
	HitDebounce = 0.5,
}

--[[
	The weapon roster.

	Add a row and it appears in the CRAFT menu on its own - nothing else needs
	touching. Cost is paid in embers, earned by killing beasts.

	  Name    shown in the shop and on the tool
	  Damage  per hit
	  Cost    embers to craft; 0 means you start with it
	  Reach   blade length in studs
	  Colors  blade and grip

	Set Glow = true for a neon blade.
]]
local function weapon(
	name: string,
	damage: number,
	cost: number,
	reach: number,
	blade: Color3,
	grip: Color3,
	glow: boolean?
)
	return {
		Name = name,
		Damage = damage,
		Cost = cost,
		Reach = reach,
		BladeColor = blade,
		GripColor = grip,
		Glow = glow or false,
	}
end

Config.Weapons = {
	weapon("Classic Sword", 20, 0, 4.4, Color3.fromRGB(163, 162, 165), Color3.fromRGB(70, 70, 75)),
	weapon("Iron Cleaver", 34, 60, 5, Color3.fromRGB(140, 142, 150), Color3.fromRGB(58, 44, 36)),
	weapon("Ember Blade", 55, 220, 5.4, Color3.fromRGB(255, 128, 48), Color3.fromRGB(48, 30, 24), true),
	weapon("Frostbrand", 88, 700, 5.6, Color3.fromRGB(120, 214, 255), Color3.fromRGB(34, 48, 60), true),
	weapon("Voidedge", 140, 2200, 6, Color3.fromRGB(168, 96, 255), Color3.fromRGB(24, 18, 34), true),
	-- Add your own here: weapon("Name", damage, cost, reach, bladeColor, gripColor, glow)
}

Config.Craft = {
	CurrencyName = "Embers",
	-- Embers earned per beast killed. Scaled by the beast's own health, so
	-- later beasts are worth grinding.
	RewardPerKill = 25,
	RewardHealthScale = 0.05,
	-- Everyone starts owning weapon 1.
	StarterWeapon = 1,
}

-- Shared behaviour for every beast. Per-beast numbers live in Config.Beasts.
Config.Npc = {
	-- Where a beast spawns, relative to the world origin.
	SpawnPosition = Vector3.new(0, 6, -28),
	-- How close it must be to land a melee hit, and how far it notices you.
	AttackRange = 7,
	AggroRange = 120,
	-- Seconds before the same beast returns after being killed.
	RespawnDelay = 6,
	Material = Enum.Material.SmoothPlastic,
}

-- The special: a launched flame. Damage and interval come from the beast.
Config.Special = {
	-- Studs per second, and how close it must get to count as a hit.
	Speed = 60,
	HitRadius = 4,
	-- Give up after this long so a stray flame never lives forever.
	Lifetime = 6,
	Size = 2.4,
	-- Windup before the flame leaves its hand, so the swing reads first.
	Windup = 0.4,
}

--[[
	The roster. Twenty beasts, picked from the FIGHT BEAST menu.

	Beast 1 is Ashburn, hand-tuned. The rest scale up from it: more health,
	more damage, faster attacks, and their own palette. They share one body
	and one behaviour, so adding a beast is one row here rather than a new
	model - change a row and that beast changes.
]]
local function beast(
	name: string,
	health: number,
	damage: number,
	special: number,
	interval: number,
	cooldown: number,
	speed: number,
	scale: number,
	body: Color3,
	flame: Color3,
	wing: Color3
)
	return {
		Name = name,
		MaxHealth = health,
		Damage = damage,
		SpecialDamage = special,
		SpecialInterval = interval,
		AttackCooldown = cooldown,
		WalkSpeed = speed,
		-- Body parts are multiplied by this. Above ~1.6 the rig starts
		-- clipping the ground, so the hover height compensates.
		Scale = scale,
		BodyColor = body,
		FlameColor = flame,
		WingColor = wing,
	}
end

Config.Beasts = {
	beast(
		"Ashburn",
		200,
		10,
		15,
		15,
		5,
		14,
		1,
		Color3.fromRGB(10, 10, 12),
		Color3.fromRGB(255, 138, 40),
		Color3.fromRGB(255, 178, 96)
	),
	beast(
		"Cinderfang",
		320,
		13,
		19,
		14,
		4.6,
		15,
		1.05,
		Color3.fromRGB(24, 12, 12),
		Color3.fromRGB(255, 110, 48),
		Color3.fromRGB(255, 160, 90)
	),
	beast(
		"Emberclaw",
		460,
		16,
		24,
		13,
		4.4,
		15,
		1.1,
		Color3.fromRGB(32, 14, 10),
		Color3.fromRGB(255, 92, 36),
		Color3.fromRGB(255, 150, 80)
	),
	beast(
		"Sootwing",
		620,
		19,
		29,
		13,
		4.2,
		16,
		1.15,
		Color3.fromRGB(18, 18, 22),
		Color3.fromRGB(220, 120, 70),
		Color3.fromRGB(230, 170, 120)
	),
	beast(
		"Pyrelord",
		820,
		23,
		35,
		12,
		4,
		16,
		1.2,
		Color3.fromRGB(38, 10, 8),
		Color3.fromRGB(255, 70, 24),
		Color3.fromRGB(255, 130, 60)
	),
	beast(
		"Scorchmaw",
		1050,
		27,
		42,
		12,
		3.8,
		17,
		1.25,
		Color3.fromRGB(28, 8, 18),
		Color3.fromRGB(255, 60, 90),
		Color3.fromRGB(255, 120, 150)
	),
	beast(
		"Blazehorn",
		1320,
		32,
		50,
		11,
		3.6,
		17,
		1.3,
		Color3.fromRGB(20, 6, 28),
		Color3.fromRGB(240, 60, 160),
		Color3.fromRGB(255, 130, 200)
	),
	beast(
		"Infernus",
		1650,
		38,
		59,
		11,
		3.4,
		18,
		1.35,
		Color3.fromRGB(30, 6, 6),
		Color3.fromRGB(255, 40, 20),
		Color3.fromRGB(255, 110, 70)
	),
	beast(
		"Charbringer",
		2050,
		45,
		70,
		10,
		3.2,
		18,
		1.4,
		Color3.fromRGB(14, 14, 16),
		Color3.fromRGB(200, 90, 255),
		Color3.fromRGB(220, 150, 255)
	),
	beast(
		"Moltenshade",
		2500,
		53,
		82,
		10,
		3,
		19,
		1.45,
		Color3.fromRGB(10, 20, 26),
		Color3.fromRGB(90, 200, 255),
		Color3.fromRGB(150, 220, 255)
	),
	beast(
		"Hellplume",
		3050,
		62,
		96,
		9,
		2.9,
		19,
		1.5,
		Color3.fromRGB(26, 6, 10),
		Color3.fromRGB(255, 80, 40),
		Color3.fromRGB(255, 140, 90)
	),
	beast(
		"Ruinwing",
		3700,
		72,
		112,
		9,
		2.8,
		20,
		1.55,
		Color3.fromRGB(8, 8, 10),
		Color3.fromRGB(150, 60, 255),
		Color3.fromRGB(190, 120, 255)
	),
	beast(
		"Cataclyst",
		4450,
		84,
		130,
		8,
		2.7,
		20,
		1.6,
		Color3.fromRGB(22, 4, 24),
		Color3.fromRGB(255, 50, 200),
		Color3.fromRGB(255, 120, 220)
	),
	beast(
		"Voidsear",
		5300,
		97,
		151,
		8,
		2.6,
		21,
		1.65,
		Color3.fromRGB(4, 4, 8),
		Color3.fromRGB(120, 40, 255),
		Color3.fromRGB(170, 110, 255)
	),
	beast(
		"Doomforge",
		6300,
		112,
		175,
		7,
		2.5,
		21,
		1.7,
		Color3.fromRGB(28, 16, 4),
		Color3.fromRGB(255, 170, 30),
		Color3.fromRGB(255, 210, 110)
	),
	beast(
		"Starscorch",
		7450,
		129,
		202,
		7,
		2.4,
		22,
		1.75,
		Color3.fromRGB(6, 10, 24),
		Color3.fromRGB(80, 160, 255),
		Color3.fromRGB(160, 210, 255)
	),
	beast(
		"Wrathmoth",
		8800,
		148,
		233,
		6,
		2.3,
		22,
		1.8,
		Color3.fromRGB(20, 20, 6),
		Color3.fromRGB(230, 255, 60),
		Color3.fromRGB(245, 255, 150)
	),
	beast(
		"Nightbrand",
		10400,
		170,
		268,
		6,
		2.2,
		23,
		1.85,
		Color3.fromRGB(2, 2, 4),
		Color3.fromRGB(255, 30, 60),
		Color3.fromRGB(255, 100, 120)
	),
	beast(
		"Endflame",
		12300,
		195,
		308,
		5,
		2.1,
		23,
		1.9,
		Color3.fromRGB(16, 0, 0),
		Color3.fromRGB(255, 20, 10),
		Color3.fromRGB(255, 90, 50)
	),
	beast(
		"Ashsovereign",
		15000,
		224,
		354,
		5,
		2,
		24,
		2,
		Color3.fromRGB(0, 0, 0),
		Color3.fromRGB(255, 240, 210),
		Color3.fromRGB(255, 250, 235)
	),
}

-- The ground. The stock Studio baseplate is a bright grey that washes out a
-- black enemy, so it gets recoloured rather than left alone.
Config.Arena = {
	FloorColor = Color3.fromRGB(38, 36, 42),
	FloorMaterial = Enum.Material.Slate,
	SpawnColor = Color3.fromRGB(58, 56, 64),
	-- Only used when the place has no ground of its own.
	Size = 400,
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

--[[
	Angel wings, built from layered feathers rather than one flat plank.

	Each wing is three rows of feathers on two bones (an inner "arm" and an
	outer "hand"), the way a real bird wing folds. Feathers taper toward the
	tip and fan out along the bone, so the silhouette reads as a wing from any
	angle instead of only from the side.
]]
Config.Wings = {
	-- Three wings per side, six in total.
	Pairs = 3,
	-- Feathers per row, and rows per wing. 3 rows x 9 feathers x 6 wings is
	-- 162 parts; raising either is the first thing to cut if it ever slows.
	FeathersPerRow = 9,
	Rows = 3,
	-- Longest feather at the base of the wing, shortest at the tip.
	FeatherLength = 5.4,
	TipScale = 0.42,
	FeatherWidth = 0.9,
	FeatherThickness = 0.12,
	-- How far the wing sweeps back, and how much each row droops below the
	-- one in front of it.
	Sweep = 0.5,
	RowDrop = 0.32,
	RowOffset = 0.55,
	-- Vertical spacing between the three wings on each side.
	Spread = 1.6,
	Sweep2 = 0.28,
	-- Flap cycles per second and swing in radians.
	FlapSpeed = 1.6,
	FlapAmount = 0.34,
	-- Feathers further out lag behind the shoulder, so the flap ripples down
	-- the wing instead of moving as one rigid board.
	FeatherLag = 0.16,
	PairDelay = 0.3,
	-- Feather colour is the beast's WingColor; this is how much white is
	-- mixed into the outer feathers.
	TipLighten = 0.45,
	Transparency = 0.08,
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

--[[
	Hit feel. Every one of these is cosmetic - damage is decided on the server
	regardless of whether any of this plays.
]]
Config.Vfx = {
	-- Classic Roblox sword sounds.
	SlashSound = "rbxassetid://12222216",
	HitSound = "rbxassetid://12222225",
	FlameSound = "rbxassetid://1836147015",
	-- Blade trail while a swing is live.
	TrailLifetime = 0.32,
	TrailWidth = 1.1,
	TrailColor = Color3.fromRGB(255, 255, 255),
	-- The arc that sweeps out of the blade on a swing.
	SlashArcSize = Vector3.new(11, 0.35, 3.4),
	SlashArcLifetime = 0.18,
	-- Sparks where a hit lands.
	SparkCount = 26,
	SparkSpeed = NumberRange.new(14, 32),
	SparkColor = Color3.fromRGB(255, 214, 140),
	-- Camera kick when you take damage: studs of shake and how fast it decays.
	ShakeMagnitude = 1.6,
	ShakeDecay = 5.5,
	-- How far a hit shoves the target.
	Knockback = 22,
}

Config.Ui = {
	-- Player health bar.
	BarSize = UDim2.new(0, 260, 0, 26),
	BarOffset = UDim2.new(0, 20, 0, -46),
	Background = Color3.fromRGB(22, 22, 26),
	HealthHigh = Color3.fromRGB(86, 200, 96),
	HealthLow = Color3.fromRGB(214, 64, 58),
	Text = Color3.fromRGB(240, 240, 245),
	-- Overhead bar on the beast.
	NpcBarSize = UDim2.fromScale(1, 0.32),
	NpcBarHeight = 4.5,
	NpcBarDistance = 220,
	-- Shop tile colour for a weapon you cannot afford yet.
	Locked = Color3.fromRGB(92, 88, 96),
	Owned = Color3.fromRGB(120, 200, 130),
	-- FIGHT BEAST button and its menu.
	Accent = Color3.fromRGB(255, 108, 32),
	AccentDeep = Color3.fromRGB(168, 38, 12),
	Panel = Color3.fromRGB(16, 15, 18),
	PanelEdge = Color3.fromRGB(58, 52, 58),
	Muted = Color3.fromRGB(150, 146, 152),
	-- Menu grid.
	Columns = 5,
	TileHeight = 78,
}

return Config

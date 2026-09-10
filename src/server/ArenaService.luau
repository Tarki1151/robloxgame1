--[[
	ArenaService
	Owns the ground the fight happens on.

	Two jobs. It darkens the stock Studio baseplate, which is a bright grey
	that washes out a black burning enemy, and it guarantees there is ground
	at all - without it, a beast spawned at server start can fall through an
	empty world before anything is loaded.

	This runs before NpcService so the floor always exists first.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local ArenaService = {}

-- Anything flat, anchored and this wide counts as existing ground.
local GROUND_MIN_WIDTH = 100

local function darken(part: BasePart)
	part.Color = Config.Arena.FloorColor
	part.Material = Config.Arena.FloorMaterial
	part.Reflectance = 0
end

local function findGround(): BasePart?
	for _, item in workspace:GetDescendants() do
		if
			item:IsA("BasePart")
			and item.Anchored
			and item.Size.X >= GROUND_MIN_WIDTH
			and item.Size.Y <= 20
		then
			return item
		end
	end
	return nil
end

local function build(): BasePart
	local folder = Instance.new("Folder")
	folder.Name = "Arena"
	folder.Parent = workspace

	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Size = Vector3.new(Config.Arena.Size, 4, Config.Arena.Size)
	floor.Position = Vector3.new(0, -2, 0)
	floor.Anchored = true
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.BottomSurface = Enum.SurfaceType.Smooth
	floor.Parent = folder
	darken(floor)

	return floor
end

function ArenaService:Start()
	local ground = findGround()

	if ground then
		-- Reuse whatever the place already has rather than stacking a second
		-- floor on top of it, which would z-fight.
		darken(ground)
	else
		ground = build()
	end

	if not workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
		local spawnLocation = Instance.new("SpawnLocation")
		spawnLocation.Name = "SpawnPad"
		spawnLocation.Size = Vector3.new(12, 1, 12)
		spawnLocation.Position = Vector3.new(0, 0.5, 12)
		spawnLocation.Anchored = true
		spawnLocation.Material = Enum.Material.Slate
		spawnLocation.Color = Config.Arena.SpawnColor
		spawnLocation.Parent = workspace
	end

	print("[Arena] ground ready.")
end

return ArenaService

--[[
	GroundService
	Lays the ground the world sits on.

	By default this is real terrain grass, not a green baseplate: terrain
	renders grass blades, gives proper footstep sounds, and can be sculpted
	into hills later without replacing anything here.

	The stock baseplate is hidden rather than deleted - made invisible and
	non-collidable - so the terrain becomes the surface you stand on while the
	original part is still there if you want it back.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local GroundService = {}

local function isGround(item: Instance): boolean
	return item:IsA("BasePart")
		and item.Anchored
		and item.Size.X >= Config.Ground.MinWidth
		and item.Size.Z >= Config.Ground.MinWidth
		and item.Size.Y <= 24
end

local function eachGroundPart(handle: (BasePart) -> ()): number
	local count = 0
	for _, item in workspace:GetDescendants() do
		if isGround(item) then
			handle(item :: BasePart)
			count += 1
		end
	end
	return count
end

local function hideBaseplate(part: BasePart)
	part.Transparency = 1
	part.CanCollide = false
	-- The grid texture would show through the grass otherwise.
	for _, child in part:GetChildren() do
		if child:IsA("Texture") or child:IsA("Decal") or child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
end

local function paintBaseplate(part: BasePart)
	part.Color = Config.Ground.FallbackColor
	part.Material = Config.Ground.FallbackMaterial
	part.Reflectance = 0
	-- Undo the hiding, in case terrain was used on a previous run.
	part.Transparency = 0
	part.CanCollide = true
	for _, child in part:GetChildren() do
		if child:IsA("Texture") or child:IsA("Decal") or child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
end

-- How far the existing ground reaches, so the grass can cover all of it.
-- Without this the grass is a fixed square sitting in the middle of a larger
-- baseplate, with grey showing all around it.
local function measureGround(): number
	local reach = 0

	for _, item in workspace:GetDescendants() do
		if isGround(item) then
			local part = item :: BasePart
			-- Half-extents plus however far the part sits from the origin.
			reach = math.max(
				reach,
				math.abs(part.Position.X) + part.Size.X / 2,
				math.abs(part.Position.Z) + part.Size.Z / 2
			)
		end
	end

	local size = reach * 2 + Config.Ground.Margin * 2
	return math.clamp(size, Config.Ground.MinSize, Config.Ground.MaxSize)
end

local function fillGrass(size: number)
	local terrain = workspace.Terrain

	terrain.Decoration = Config.Ground.Decoration
	terrain:SetMaterialColor(Enum.Material.Grass, Config.Ground.GrassColor)
	terrain:SetMaterialColor(Enum.Material.Ground, Config.Ground.GroundColor)

	local depth = Config.Ground.Depth
	local chunk = Config.Ground.ChunkSize
	local half = size / 2

	--[[
		Filled in chunks, yielding between each row.

		A single FillBlock over a large area blocks the server while it writes
		every voxel, stalling the whole game for as long as it takes. In chunks
		the server keeps running and the grass appears progressively.

		The block's top sits at y = 0, so spawns and parts placed at ground
		level land on the surface rather than inside it.
	]]
	for x = -half, half - 1, chunk do
		for z = -half, half - 1, chunk do
			local width = math.min(chunk, half - x)
			local length = math.min(chunk, half - z)

			terrain:FillBlock(
				CFrame.new(x + width / 2, -depth / 2, z + length / 2),
				Vector3.new(width, depth, length),
				Enum.Material.Grass
			)
		end
		task.wait()
	end
end

-- Removes terrain this service laid, so switching back to a plain baseplate
-- does not leave grass floating over it.
local function clearTerrain(): boolean
	local terrain = workspace.Terrain
	if terrain:CountCells() == 0 then
		return false
	end

	local half = Config.Ground.MaxSize / 2
	local region = Region3.new(
		Vector3.new(-half, -Config.Ground.Depth * 4, -half),
		Vector3.new(half, Config.Ground.Depth * 4, half)
	):ExpandToGrid(4)

	terrain:FillRegion(region, 4, Enum.Material.Air)
	return true
end

function GroundService:Start()
	if Config.Ground.UseTerrain then
		local size = measureGround()
		local hidden = eachGroundPart(hideBaseplate)
		fillGrass(size)
		print(string.format("[Ground] %d studs of grass laid, %d baseplates hidden.", size, hidden))
	else
		-- Terrain from an earlier run would sit at the same height as the
		-- baseplate and flicker against it, so it goes.
		local cleared = clearTerrain()
		local painted = eachGroundPart(paintBaseplate)
		print(
			string.format(
				"[Ground] %d ground parts painted grass, terrain %s.",
				painted,
				if cleared then "cleared" else "none"
			)
		)
	end
end

return GroundService

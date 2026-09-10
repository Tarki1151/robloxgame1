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
	for _, child in part:GetChildren() do
		if child:IsA("Texture") or child:IsA("Decal") or child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
end

local function fillGrass()
	local terrain = workspace.Terrain

	terrain.Decoration = Config.Ground.Decoration
	terrain:SetMaterialColor(Enum.Material.Grass, Config.Ground.GrassColor)
	terrain:SetMaterialColor(Enum.Material.Ground, Config.Ground.GroundColor)

	-- The block's top sits at y = 0, so spawns and parts placed at ground
	-- level still land on the surface rather than inside it.
	local size = Config.Ground.Size
	local depth = Config.Ground.Depth

	terrain:FillBlock(CFrame.new(0, -depth / 2, 0), Vector3.new(size, depth, size), Enum.Material.Grass)
end

function GroundService:Start()
	if Config.Ground.UseTerrain then
		fillGrass()
		local hidden = eachGroundPart(hideBaseplate)
		print(string.format("[Ground] grass terrain laid, %d baseplates hidden.", hidden))
	else
		local painted = eachGroundPart(paintBaseplate)
		print(string.format("[Ground] %d ground parts painted grass.", painted))
	end
end

return GroundService

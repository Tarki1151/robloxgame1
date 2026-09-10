--[[
	GroundService
	Darkens the ground.

	The stock Studio baseplate is a bright light grey. Recolouring it is not
	enough on its own: it also carries a light grid Texture, and on some
	templates a SurfaceAppearance, which sit on top of the colour and keep it
	looking bright whatever colour is underneath. Those are removed too.

	Every large flat anchored part is treated as ground, not just the first,
	since a place can have its floor split into several pieces.
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

local function darken(part: BasePart)
	part.Color = Config.Ground.Color
	part.Material = Config.Ground.Material
	part.Reflectance = 0

	for _, child in part:GetChildren() do
		if child:IsA("Texture") or child:IsA("Decal") or child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
end

function GroundService:Start()
	local count = 0

	for _, item in workspace:GetDescendants() do
		if isGround(item) then
			darken(item :: BasePart)
			count += 1
		end
	end

	-- A place built on terrain has no ground part to recolour; the count says
	-- so rather than leaving you wondering why nothing changed.
	print(string.format("[Ground] %d ground parts darkened.", count))
end

return GroundService

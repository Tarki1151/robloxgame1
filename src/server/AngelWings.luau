--!strict
--[[
	AngelWings
	Builds feathered wings out of many small parts.

	A wing is not a shape you can weld in one piece and have read as a wing.
	This builds it the way a bird is put together:

	  - two bones per wing: an inner one from the shoulder, and an outer one
	    continuing from its tip at a sharper sweep
	  - Config.Wings.Rows rows of feathers along those bones, each row dropping
	    and trailing behind the row in front of it
	  - feathers taper from long at the shoulder to short at the tip

	Every feather gets its own Weld to the torso, and its rest offset is handed
	back so PoseService can flap it. Feathers further out flap with more delay,
	which is what makes it look like a wing beating rather than a board tilting.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local AngelWings = {}

export type Feather = {
	weld: Weld,
	rest: CFrame,
	-- 0 at the shoulder, 1 at the wing tip. Drives flap lag.
	span: number,
	-- Which wing on the body, counted from the top.
	wing: number,
	-- -1 for left, 1 for right.
	side: number,
}

local function makeFeather(length: number, color: Color3, container: Instance): BasePart
	local feather = Instance.new("Part")
	feather.Name = "Feather"
	feather.Size = Vector3.new(length, Config.Wings.FeatherWidth, Config.Wings.FeatherThickness)
	feather.Color = color
	feather.Material = Enum.Material.SmoothPlastic
	feather.Transparency = Config.Wings.Transparency
	feather.CanCollide = false
	feather.CanQuery = false
	feather.CanTouch = false
	feather.Massless = true
	feather.CastShadow = false
	feather.TopSurface = Enum.SurfaceType.Smooth
	feather.BottomSurface = Enum.SurfaceType.Smooth

	-- A sphere mesh squashed along the quill gives a rounded, tapered feather
	-- instead of a rectangular slab.
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 1, 1)
	mesh.Parent = feather

	feather.Parent = container
	return feather
end

--[[
	One wing.

	side is -1 for left, 1 for right. wingIndex counts wings down the body, so
	each sits lower and sweeps a little further back than the one above it.
]]
local function buildWing(
	torso: BasePart,
	container: Instance,
	side: number,
	wingIndex: number,
	color: Color3,
	scale: number
): { Feather }
	local feathers: { Feather } = {}

	local rows = Config.Wings.Rows
	local perRow = Config.Wings.FeathersPerRow

	-- Where this wing meets the back.
	local shoulderHeight = (Config.Wings.Pairs - 1) * Config.Wings.Spread / 2
		- (wingIndex - 1) * Config.Wings.Spread
	local shoulder = CFrame.new(side * 0.9 * scale, shoulderHeight * scale, 0.55 * scale)
		* CFrame.Angles(0, side * -Config.Wings.Sweep2 * wingIndex, 0)

	for row = 1, rows do
		-- Back rows sit lower and further behind, like coverts under primaries.
		local rowDrop = -(row - 1) * Config.Wings.RowDrop * scale
		local rowBack = (row - 1) * Config.Wings.RowOffset * scale

		for index = 1, perRow do
			-- 0 at the shoulder, 1 at the tip.
			local span = (index - 1) / (perRow - 1)

			-- Feathers shorten toward the tip.
			local length = Config.Wings.FeatherLength
				* scale
				* (1 - span * (1 - Config.Wings.TipScale))
				-- Outer rows are slightly shorter than the leading row.
				* (1 - (row - 1) * 0.12)

			-- The outer half of the wing sweeps back harder: the second bone.
			local sweep = if span < 0.5
				then span * Config.Wings.Sweep
				else Config.Wings.Sweep * (0.5 + (span - 0.5) * 2.1)

			-- Feathers fan along the bone, each one further out and back.
			local along = span * Config.Wings.FeatherLength * 1.55 * scale
			local offset = shoulder
				* CFrame.Angles(0, side * -sweep, 0)
				* CFrame.new(side * (along + length / 2), rowDrop - span * 0.7 * scale, rowBack)
				-- Roll each feather slightly so the row is not perfectly flat.
				* CFrame.Angles(side * (0.12 + span * 0.35), 0, 0)

			-- Outer feathers are lighter, the way flight feathers catch light.
			local tint = color:Lerp(Color3.new(1, 1, 1), span * Config.Wings.TipLighten)
			local feather = makeFeather(length, tint, container)

			local weld = Instance.new("Weld")
			weld.Name = "FeatherWeld"
			weld.Part0 = torso
			weld.Part1 = feather
			weld.C0 = offset
			weld.Parent = torso

			table.insert(feathers, {
				weld = weld,
				rest = offset,
				span = span,
				wing = wingIndex,
				side = side,
			})
		end
	end

	return feathers
end

-- Builds every wing on the body and returns one flat list of feathers.
function AngelWings.build(torso: BasePart, container: Instance, color: Color3, scale: number): { Feather }
	local all: { Feather } = {}

	for wingIndex = 1, Config.Wings.Pairs do
		for _, side in { -1, 1 } do
			for _, feather in buildWing(torso, container, side, wingIndex, color, scale) do
				table.insert(all, feather)
			end
		end
	end

	return all
end

return AngelWings

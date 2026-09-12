--!strict
--[[
	SwordModel
	Builds the classic sword as a real shape rather than a single slab.

	Parts, from the bottom up: a pommel, a wrapped grip, a crossguard, then a
	blade in three sections - a straight ricasso, a tapering middle, and a
	wedge point - with a dark fuller groove down the centre of the flat.

	The Handle is the grip, not the blade. Roblox welds the Handle to the hand,
	so whatever you want held has to be the Handle; the blade hangs off it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local SwordModel = {}

local function piece(
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	reflectance: number,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Reflectance = reflectance
	part.CanCollide = false
	part.CanQuery = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

--[[
	Welds a part to the handle at a fixed offset.

	A Weld with an explicit C0 rather than a WeldConstraint: the offset has to
	survive the Handle being teleported into the hand on equip, and a
	WeldConstraint captures whatever offset happens to exist when it activates.
]]
local function weldTo(handle: BasePart, part: BasePart, offset: CFrame)
	part.CFrame = handle.CFrame * offset

	local weld = Instance.new("Weld")
	weld.Name = part.Name .. "Weld"
	weld.Part0 = handle
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = handle
end

function SwordModel.build(): Tool
	local tool = Instance.new("Tool")
	tool.Name = Config.Sword.Name
	tool.CanBeDropped = false
	-- Held point-forward, blade running away from the fist.
	tool.Grip = CFrame.new(0, 0, 0) * CFrame.Angles(math.pi / 2, 0, math.pi / 2)

	-- The grip is the Handle: wrapped leather, slightly waisted.
	local handle = piece(
		"Handle",
		Vector3.new(Config.Sword.GripWidth, Config.Sword.GripLength, Config.Sword.GripWidth),
		Config.Sword.GripColor,
		Enum.Material.Fabric,
		0,
		tool
	)
	handle.CanCollide = false

	-- Pommel, counterweighting the blade.
	weldTo(
		handle,
		piece(
			"Pommel",
			Vector3.new(Config.Sword.PommelSize, Config.Sword.PommelSize * 0.7, Config.Sword.PommelSize),
			Config.Sword.GuardColor,
			Enum.Material.Metal,
			0.2,
			tool
		),
		CFrame.new(0, -Config.Sword.GripLength / 2 - 0.25, 0)
	)

	-- Crossguard, plus a short block either side so it is not a plain bar.
	local guardY = Config.Sword.GripLength / 2 + Config.Sword.GuardThickness / 2

	weldTo(
		handle,
		piece(
			"Guard",
			Vector3.new(
				Config.Sword.GuardWidth,
				Config.Sword.GuardThickness,
				Config.Sword.GuardThickness * 1.6
			),
			Config.Sword.GuardColor,
			Enum.Material.Metal,
			0.25,
			tool
		),
		CFrame.new(0, guardY, 0)
	)

	for _, side in { -1, 1 } do
		weldTo(
			handle,
			piece(
				"GuardTip",
				Vector3.new(0.5, 0.5, 0.5),
				Config.Sword.GuardColor,
				Enum.Material.Metal,
				0.25,
				tool
			),
			CFrame.new(side * Config.Sword.GuardWidth / 2, guardY, 0)
		)
	end

	--[[
		The blade, in three sections.

		A single box the length of the blade looks like a ruler. Splitting it
		lets the width fall from guard to point, which is what makes it read as
		a weapon: wide and heavy at the hand, thin at the tip.
	]]
	local bladeBase = guardY + Config.Sword.GuardThickness / 2
	local sectionLength = Config.Sword.BladeLength / 3
	local width = Config.Sword.BladeWidth
	local tipWidth = width * Config.Sword.TipTaper

	for index = 1, 3 do
		-- Width at the middle of this section, falling toward the point.
		local along = (index - 0.5) / 3
		local sectionWidth = width + (tipWidth - width) * along

		weldTo(
			handle,
			piece(
				"Blade" .. index,
				Vector3.new(sectionWidth, sectionLength, Config.Sword.BladeThickness),
				Config.Sword.SteelColor,
				Enum.Material.Metal,
				Config.Sword.SteelReflectance,
				tool
			),
			CFrame.new(0, bladeBase + sectionLength * (index - 0.5), 0)
		)

		-- The fuller: a dark groove down the flat of each section, set just
		-- proud of the surface so it does not z-fight with the blade.
		weldTo(
			handle,
			piece(
				"Fuller" .. index,
				Vector3.new(Config.Sword.FullerWidth, sectionLength * 0.94, Config.Sword.FullerDepth),
				Config.Sword.SteelDarkColor,
				Enum.Material.Metal,
				0.1,
				tool
			),
			CFrame.new(0, bladeBase + sectionLength * (index - 0.5), Config.Sword.BladeThickness / 2)
		)
	end

	-- The point: a wedge, so the blade ends in an edge rather than a flat end.
	local tip = Instance.new("WedgePart")
	tip.Name = "Tip"
	tip.Size = Vector3.new(Config.Sword.BladeThickness, 1.1, tipWidth)
	tip.Color = Config.Sword.SteelColor
	tip.Material = Enum.Material.Metal
	tip.Reflectance = Config.Sword.SteelReflectance
	tip.CanCollide = false
	tip.CanQuery = false
	tip.Massless = true
	tip.Parent = tool

	weldTo(
		handle,
		tip,
		CFrame.new(0, bladeBase + Config.Sword.BladeLength + 0.55, 0)
			* CFrame.Angles(0, 0, math.pi / 2)
			* CFrame.Angles(math.pi / 2, 0, 0)
	)

	--[[
		The trail, drawn between the edge and the back of the blade.

		Disabled until a swing starts, so the sword does not smear while you
		walk around with it.
	]]
	local edge = Instance.new("Attachment")
	edge.Name = "TrailEdge"
	edge.Position = Vector3.new(0, bladeBase + Config.Sword.BladeLength, 0)
	edge.Parent = handle

	local back = Instance.new("Attachment")
	back.Name = "TrailBack"
	back.Position = Vector3.new(0, bladeBase, 0)
	back.Parent = handle

	local trail = Instance.new("Trail")
	trail.Name = "SlashTrail"
	trail.Attachment0 = edge
	trail.Attachment1 = back
	trail.Lifetime = Config.Sword.TrailLifetime
	trail.MinLength = 0.2
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Color = ColorSequence.new(Config.Sword.TrailColor)
	trail.LightEmission = 0.6
	trail.FaceCamera = true
	trail.Enabled = false
	trail.Parent = handle

	return tool
end

return SwordModel

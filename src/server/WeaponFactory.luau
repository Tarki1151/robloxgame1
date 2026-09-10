--!strict
--[[
	WeaponFactory
	Builds a weapon Tool from a row of Config.Weapons.

	Every weapon is the same shape - a long blade, a crossguard, a trail and
	two sounds - differing only in reach, colour and whether the blade glows.
	Keeping construction here means adding a weapon stays a one-line change in
	Config, with no new model and no new code.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local WeaponFactory = {}

function WeaponFactory.build(weapon): Tool
	local tool = Instance.new("Tool")
	tool.Name = weapon.Name
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, 0, -1.5) * CFrame.Angles(math.pi / 2, 0, math.pi / 2)
	-- The damage travels with the tool, so the hit code never has to look the
	-- weapon up again.
	tool:SetAttribute("Damage", weapon.Damage)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.8, weapon.Reach, 0.8)
	handle.Color = weapon.BladeColor
	handle.Material = if weapon.Glow then Enum.Material.Neon else Enum.Material.Metal
	handle.Reflectance = if weapon.Glow then 0 else 0.15
	handle.CanCollide = false
	handle.Parent = tool

	local guard = Instance.new("Part")
	guard.Name = "Guard"
	guard.Size = Vector3.new(2, 0.35, 0.35)
	guard.Color = weapon.GripColor
	guard.Material = Enum.Material.Metal
	guard.CanCollide = false
	guard.CanQuery = false
	guard.Massless = true
	guard.Parent = tool

	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = guard
	weld.C0 = CFrame.new(0, -weapon.Reach / 2 + 0.5, 0)
	weld.Parent = handle

	-- A Trail needs two attachments to stretch between: tip and base of the
	-- blade. It stays disabled until a swing starts, so the weapon does not
	-- smear while you walk around.
	local tip = Instance.new("Attachment")
	tip.Name = "TrailTip"
	tip.Position = Vector3.new(0, weapon.Reach / 2, 0)
	tip.Parent = handle

	local base = Instance.new("Attachment")
	base.Name = "TrailBase"
	base.Position = Vector3.new(0, -weapon.Reach / 4, 0)
	base.Parent = handle

	local trail = Instance.new("Trail")
	trail.Name = "SlashTrail"
	trail.Attachment0 = tip
	trail.Attachment1 = base
	trail.Lifetime = Config.Vfx.TrailLifetime
	trail.MinLength = 0.1
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Color = ColorSequence.new(if weapon.Glow then weapon.BladeColor else Config.Vfx.TrailColor)
	trail.LightEmission = 0.8
	trail.FaceCamera = true
	trail.Enabled = false
	trail.Parent = handle

	if weapon.Glow then
		local light = Instance.new("PointLight")
		light.Color = weapon.BladeColor
		light.Brightness = 2
		light.Range = 12
		light.Parent = handle
	end

	local slashSound = Instance.new("Sound")
	slashSound.Name = "Slash"
	slashSound.SoundId = Config.Vfx.SlashSound
	slashSound.Volume = 0.7
	slashSound.Parent = handle

	local hitSound = Instance.new("Sound")
	hitSound.Name = "Hit"
	hitSound.SoundId = Config.Vfx.HitSound
	hitSound.Volume = 0.8
	hitSound.Parent = handle

	return tool
end

return WeaponFactory

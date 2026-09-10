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

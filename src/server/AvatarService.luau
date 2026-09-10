--[[
	AvatarService
	Rebuilds every player's character into the same figure: a pitch black
	classic noob, burning, with six fire wings and a flame sword.

	Nothing here reads the player's own Roblox avatar - accessories, clothing
	and the face are stripped on every spawn, so everyone looks identical.

	This service only handles how the character LOOKS. Movement and posing
	live in PoseService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local AvatarService = {}

-- Set by PoseService. Called when the player swings the sword, so the swing
-- pose lives with the rest of the animation code.
AvatarService.OnSwing = nil :: ((Player) -> ())?

local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"

-- Wing welds are handed to PoseService so it can flap them.
local wings: { [Model]: { Weld } } = {}

-- True for anything that belongs to the player's own avatar rather than the
-- noob we are forcing: hats, hair, clothing, the face decal.
local function isAppearanceItem(item: Instance): boolean
	if Config.Avatar.RemoveAccessories and item:IsA("Accessory") then
		return true
	end
	if
		Config.Avatar.RemoveClothing
		and (item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic"))
	then
		return true
	end
	return Config.Avatar.RemoveFace and item:IsA("Decal")
end

local function blacken(character: Model)
	for _, item in character:GetDescendants() do
		if isAppearanceItem(item) then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Color = Config.Avatar.BodyColor
			item.Material = Config.Avatar.Material
			item.Reflectance = Config.Avatar.Reflectance
		end
	end
end

local function makeFire(parent: BasePart, rate: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "BodyFire"
	emitter.Texture = FIRE_TEXTURE
	emitter.Rate = rate
	emitter.Lifetime = Config.Fire.Lifetime
	emitter.Speed = Config.Fire.Speed
	emitter.SpreadAngle = Vector2.new(18, 18)
	emitter.LightEmission = 0.85
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, Config.Fire.Size * 0.4),
		NumberSequenceKeypoint.new(0.4, Config.Fire.Size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Config.Fire.SecondaryColor, Config.Fire.Color)
	-- Flames rise regardless of which way the limb is facing.
	emitter.Acceleration = Vector3.new(0, 12, 0)
	emitter.Parent = parent
end

local function ignite(character: Model)
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") then
			local isTorso = part.Name == "Torso" or part.Name == "UpperTorso"
			makeFire(part, if isTorso then Config.Fire.TorsoRate else Config.Fire.LimbRate)
		end
	end

	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	if torso and torso:IsA("BasePart") then
		local light = Instance.new("PointLight")
		light.Name = "FireLight"
		light.Color = Config.Fire.Color
		light.Brightness = Config.Fire.LightBrightness
		light.Range = Config.Fire.LightRange
		light.Parent = torso
	end
end

--[[
	One wing. Welded to the torso rather than parented loosely, so it follows
	the body exactly; PoseService flaps it by rewriting the weld's C0.

	side is -1 for left, 1 for right. index counts pairs from the top down.
]]
local function makeWing(torso: BasePart, side: number, index: number): Weld
	local wing = Instance.new("Part")
	wing.Name = string.format("Wing%s%d", if side < 0 then "Left" else "Right", index)
	wing.Size = Vector3.new(Config.Wings.Length, Config.Wings.Width, Config.Wings.Thickness)
	wing.Color = Config.Wings.Color
	wing.Material = Enum.Material.Neon
	wing.Transparency = Config.Wings.Transparency
	wing.CanCollide = false
	wing.CanQuery = false
	wing.CanTouch = false
	wing.Massless = true
	wing.CastShadow = false
	wing.Parent = torso.Parent

	makeFire(wing, Config.Fire.LimbRate)

	-- Pairs stack downward and sweep further back as they go.
	local height = (Config.Wings.Pairs - 1) * Config.Wings.Spread / 2 - (index - 1) * Config.Wings.Spread
	local offset = CFrame.new(side * Config.Wings.Length / 2, height, 0.6)
		* CFrame.Angles(0, side * -Config.Wings.Sweep * index, 0)

	local weld = Instance.new("Weld")
	weld.Name = wing.Name .. "Weld"
	weld.Part0 = torso
	weld.Part1 = wing
	weld.C0 = offset
	weld.Parent = torso

	return weld
end

local function attachWings(character: Model)
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	if not torso or not torso:IsA("BasePart") then
		return
	end

	local welds: { Weld } = {}
	for index = 1, Config.Wings.Pairs do
		table.insert(welds, makeWing(torso, -1, index))
		table.insert(welds, makeWing(torso, 1, index))
	end

	wings[character] = welds
end

local function makeSword(): Tool
	local tool = Instance.new("Tool")
	tool.Name = Config.Sword.Name
	tool.CanBeDropped = false
	tool.Grip = CFrame.Angles(0, math.rad(90), 0)

	-- Handle is the hilt; the blade is welded on and reaches along -Y so the
	-- sword points away from the hand.
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 1.4, 0.4)
	handle.Color = Config.Sword.HiltColor
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Parent = tool

	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = Vector3.new(Config.Sword.BladeWidth, Config.Sword.BladeLength, 0.18)
	blade.Color = Config.Sword.BladeColor
	blade.Material = Enum.Material.Neon
	blade.CanCollide = false
	blade.CanQuery = false
	blade.Massless = true
	blade.CFrame = handle.CFrame
	blade.Parent = tool

	makeFire(blade, Config.Fire.TorsoRate)

	-- Fixed C0 instead of a WeldConstraint: the offset must survive the
	-- Handle being teleported into the hand when the tool is equipped.
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = blade
	weld.C0 = CFrame.new(0, Config.Sword.BladeLength / 2 + 0.5, 0)
	weld.Parent = handle

	return tool
end

function AvatarService:GetWings(character: Model): { Weld }?
	return wings[character]
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
		or character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end

	-- The stock Animate script would fight the procedural poses.
	local animate = character:FindFirstChild("Animate")
	if animate then
		animate.Enabled = false
	end

	blacken(character)
	-- CharacterAppearanceLoaded can drop accessories in a frame late.
	character.DescendantAdded:Connect(function(item)
		if isAppearanceItem(item) then
			task.defer(blacken, character)
		end
	end)

	ignite(character)
	attachWings(character)

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		local sword = makeSword()

		local lastSwing = 0
		sword.Activated:Connect(function()
			local now = os.clock()
			if now - lastSwing < Config.Sword.Cooldown then
				return
			end
			lastSwing = now

			local onSwing = AvatarService.OnSwing
			if onSwing then
				onSwing(player)
			end
		end)

		sword.Parent = backpack
		humanoid:EquipTool(sword)
	end

	character.Destroying:Connect(function()
		wings[character] = nil
	end)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(onCharacterAdded, player, character)
	end)

	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function AvatarService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return AvatarService

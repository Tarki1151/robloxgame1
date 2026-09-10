--[[
	SwordService
	Gives every player their equipped weapon and resolves its hits.

	Damage is server-side. The client only triggers Tool.Activated; the server
	decides whether anything was actually hit, so a modified client cannot
	claim kills.

	Hit detection is the classic approach: while a swing is live, anything the
	blade touches takes damage once, with a per-target debounce so a single
	swing cannot tick repeatedly on the same enemy.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local CraftService = require(script.Parent.CraftService)
local WeaponFactory = require(script.Parent.WeaponFactory)

local SwordService = {}

-- Sparks and a flash where a blow lands.
local function impact(position: Vector3, color: Color3)
	local origin = Instance.new("Part")
	origin.Name = "Impact"
	origin.Size = Vector3.new(0.2, 0.2, 0.2)
	origin.Position = position
	origin.Transparency = 1
	origin.Anchored = true
	origin.CanCollide = false
	origin.CanQuery = false
	origin.CanTouch = false
	origin.Parent = workspace

	local attachment = Instance.new("Attachment")
	attachment.Parent = origin

	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(color)
	sparks.Lifetime = NumberRange.new(0.2, 0.45)
	sparks.Speed = Config.Vfx.SparkSpeed
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.LightEmission = 1
	sparks.Rate = 0
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Parent = attachment
	sparks:Emit(Config.Vfx.SparkCount)

	local flash = Instance.new("PointLight")
	flash.Color = color
	flash.Brightness = 6
	flash.Range = 14
	flash.Parent = origin

	Debris:AddItem(origin, 0.6)
end

-- The arc that sweeps out of the blade, sold as a thin curved slab that
-- stretches and fades. Purely cosmetic, and it never touches anything.
local function slashArc(handle: BasePart)
	local arc = Instance.new("Part")
	arc.Name = "SlashArc"
	arc.Size = Config.Vfx.SlashArcSize
	arc.CFrame = handle.CFrame * CFrame.new(0, 1.4, -1.2) * CFrame.Angles(0, 0, math.rad(35))
	arc.Color = Config.Vfx.TrailColor
	arc.Material = Enum.Material.Neon
	arc.Transparency = 0.35
	arc.Anchored = true
	arc.CanCollide = false
	arc.CanQuery = false
	arc.CanTouch = false
	arc.CastShadow = false
	arc.Parent = workspace

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 0.12, 0.6)
	mesh.Parent = arc

	task.spawn(function()
		local elapsed = 0
		while elapsed < Config.Vfx.SlashArcLifetime and arc.Parent do
			elapsed += task.wait()
			local progress = elapsed / Config.Vfx.SlashArcLifetime
			arc.Transparency = 0.35 + progress * 0.65
			mesh.Scale = Vector3.new(1 + progress * 0.7, 0.12, 0.6)
		end
		arc:Destroy()
	end)
end

-- Removes whatever weapon the player is holding, so equipping a new one
-- never leaves the old one in the backpack.
local function clearWeapons(player: Player)
	local containers = { player:FindFirstChildOfClass("Backpack"), player.Character }
	for _, container in containers do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("Damage") then
					child:Destroy()
				end
			end
		end
	end
end

local function equip(player: Player, weaponIndex: number?)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not backpack or not humanoid then
		return
	end

	local index = weaponIndex or CraftService:GetEquipped(player)
	local weapon = Config.Weapons[index]
	if not weapon then
		return
	end

	clearWeapons(player)

	local tool = WeaponFactory.build(weapon)
	local handle = tool:FindFirstChild("Handle") :: BasePart

	local lastSwing = 0
	local swingUntil = 0
	-- Per-swing record of who has already been hit.
	local struck: { [Humanoid]: number } = {}

	handle.Touched:Connect(function(hit)
		if os.clock() > swingUntil then
			return
		end

		local hitCharacter = hit:FindFirstAncestorOfClass("Model")
		if not hitCharacter or hitCharacter == character then
			return
		end

		local victim = hitCharacter:FindFirstChildOfClass("Humanoid")
		if not victim or victim.Health <= 0 then
			return
		end

		local now = os.clock()
		if now - (struck[victim] or 0) < Config.Sword.HitDebounce then
			return
		end
		struck[victim] = now

		-- Damage rides on the tool, set when it was built.
		local damage = tool:GetAttribute("Damage") or 0
		victim:TakeDamage(damage)

		impact(hit.Position, Config.Vfx.SparkColor)

		local hitSound = handle:FindFirstChild("Hit")
		if hitSound and hitSound:IsA("Sound") then
			hitSound:Play()
		end

		-- Shove the target away from the swing. Anchored things ignore this,
		-- which is what we want: only characters get knocked back.
		local victimRoot = hitCharacter:FindFirstChild("HumanoidRootPart")
		if victimRoot and victimRoot:IsA("BasePart") and not victimRoot.Anchored then
			local away = (victimRoot.Position - handle.Position)
			if away.Magnitude > 0.1 then
				victimRoot.AssemblyLinearVelocity += away.Unit * Config.Vfx.Knockback
			end
		end

		Remotes.event("Hit"):FireClient(player, "landed", hit.Position)
	end)

	tool.Activated:Connect(function()
		local now = os.clock()
		if now - lastSwing < Config.Sword.Cooldown then
			return
		end
		lastSwing = now
		swingUntil = now + Config.Sword.HitWindow
		table.clear(struck)

		local trail = handle:FindFirstChild("SlashTrail")
		if trail and trail:IsA("Trail") then
			trail.Enabled = true
			task.delay(Config.Sword.HitWindow, function()
				trail.Enabled = false
			end)
		end

		local slashSound = handle:FindFirstChild("Slash")
		if slashSound and slashSound:IsA("Sound") then
			slashSound:Play()
		end

		slashArc(handle)
	end)

	tool.Parent = backpack
	humanoid:EquipTool(tool)
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
		or character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end

	-- Diagnostic: nothing here changes a player's appearance, so if an avatar
	-- looks wrong this line says whether the place is forcing R6.
	print(string.format("[Player] %s spawned as %s.", player.Name, humanoid.RigType.Name))

	humanoid.MaxHealth = Config.Player.MaxHealth
	humanoid.Health = Config.Player.MaxHealth
	humanoid.WalkSpeed = Config.Player.WalkSpeed

	equip(player)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(onCharacterAdded, player, character)
	end)

	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function SwordService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	-- CraftService calls back rather than requiring this service, which would
	-- be a require cycle.
	CraftService.OnEquip = function(player: Player, index: number)
		equip(player, index)
	end
end

return SwordService

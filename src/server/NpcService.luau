--[[
	NpcService
	Spawns the burning noob and runs its behaviour.

	It is a normal R6 character with a Humanoid, so it walks with pathing,
	takes damage from swords and dies like a player would. Everything about it
	is server-side; clients are only told about it through replication.

	Behaviour is deliberately simple: find the closest living player inside
	AggroRange, walk at them, and hit for Config.Npc.Damage whenever they are
	inside AttackRange and the cooldown has elapsed.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Remotes = require(Shared.Remotes)

local AngelWings = require(script.Parent.AngelWings)
local NpcRig = require(script.Parent.NpcRig)

local NpcService = {}

local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"

export type Npc = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	torso: BasePart,
	-- The beast row this was built from, so behaviour reads its own numbers.
	beast: any,
	wings: { AngelWings.Feather },
	lastAttack: number,
	lastSpecial: number,
	-- Set when it swings, read by PoseService to play the slash.
	swingUntil: number,
}

local active: { [Model]: Npc } = {}
local folder: Folder

local function makeFire(parent: BasePart, rate: number, color: Color3)
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
	emitter.Color = ColorSequence.new(Config.Fire.SecondaryColor, color)
	-- Flames rise regardless of which way the limb is facing.
	emitter.Acceleration = Vector3.new(0, 12, 0)
	emitter.Parent = parent
end

-- The beast's flame sword. Cosmetic: damage is dealt by the attack check, not
-- by the blade touching anything, so it cannot hit through walls by accident.
local function attachSword(character: Model, rightArm: BasePart, scale: number)
	local blade = Instance.new("Part")
	blade.Name = "FlameBlade"
	blade.Size = Vector3.new(Config.FlameSword.BladeWidth, Config.FlameSword.BladeLength, 0.18)
	blade.Color = Config.FlameSword.BladeColor
	blade.Material = Enum.Material.Neon
	blade.CanCollide = false
	blade.CanQuery = false
	blade.CanTouch = false
	blade.Massless = true
	blade.Parent = character

	makeFire(blade, Config.Fire.TorsoRate, Config.FlameSword.BladeColor)

	local hilt = Instance.new("Part")
	hilt.Name = "FlameHilt"
	hilt.Size = Vector3.new(0.4, 1.2, 0.4) * scale
	hilt.Color = Config.FlameSword.HiltColor
	hilt.Material = Enum.Material.Metal
	hilt.CanCollide = false
	hilt.CanQuery = false
	hilt.CanTouch = false
	hilt.Massless = true
	hilt.Parent = character

	-- Fixed C0 offsets: the sword hangs below the hand, blade pointing down.
	local hiltWeld = Instance.new("Weld")
	hiltWeld.Part0 = rightArm
	hiltWeld.Part1 = hilt
	hiltWeld.C0 = CFrame.new(0, -1.1 * scale, 0)
	hiltWeld.Parent = rightArm

	local bladeWeld = Instance.new("Weld")
	bladeWeld.Part0 = hilt
	bladeWeld.Part1 = blade
	bladeWeld.C0 = CFrame.new(0, (-Config.FlameSword.BladeLength / 2 - 0.4) * scale, 0)
	bladeWeld.Parent = hilt
end

-- Overhead name and health bar, the way most Roblox enemies show theirs.
local function attachHealthBar(humanoid: Humanoid, head: BasePart, name: string)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = UDim2.fromScale(9, 1.4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, Config.Ui.NpcBarHeight, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = Config.Ui.NpcBarDistance
	gui.Parent = head

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.5)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Text = name
	title.TextColor3 = Config.Ui.Text
	title.TextStrokeTransparency = 0.4
	title.Parent = gui

	local track = Instance.new("Frame")
	track.Size = Config.Ui.NpcBarSize
	track.Position = UDim2.fromScale(0, 0.58)
	track.BackgroundColor3 = Config.Ui.Background
	track.BorderSizePixel = 0
	track.Parent = gui

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Config.Ui.HealthHigh
	fill.BorderSizePixel = 0
	fill.Parent = track

	local function refresh()
		local ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
		fill.Size = UDim2.fromScale(ratio, 1)
		fill.BackgroundColor3 = Config.Ui.HealthLow:Lerp(Config.Ui.HealthHigh, ratio)
	end

	humanoid.HealthChanged:Connect(refresh)
	refresh()
end

-- Index of the beast currently selected from the menu.
local currentIndex = 1

local function spawnNpc(index: number): Npc
	local beast = Config.Beasts[math.clamp(index, 1, #Config.Beasts)]
	local scale = beast.Scale

	local character = NpcRig.build(beast.Name, beast.BodyColor, Config.Npc.Material, scale)

	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.MaxHealth = beast.MaxHealth
	humanoid.Health = beast.MaxHealth
	humanoid.WalkSpeed = beast.WalkSpeed
	-- Keep the name plate we build ourselves, not Roblox's default one.
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local torso = character:FindFirstChild("Torso") :: BasePart
	local head = character:FindFirstChild("Head") :: BasePart
	local rightArm = character:FindFirstChild("Right Arm") :: BasePart

	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part ~= root then
			local isTorso = part.Name == "Torso"
			makeFire(part, if isTorso then Config.Fire.TorsoRate else Config.Fire.LimbRate, beast.FlameColor)
		end
	end

	local light = Instance.new("PointLight")
	light.Name = "FireLight"
	light.Color = beast.FlameColor
	light.Brightness = Config.Fire.LightBrightness
	light.Range = Config.Fire.LightRange * scale
	light.Parent = torso

	local wings = AngelWings.build(torso, character, beast.WingColor, scale)

	attachSword(character, rightArm, scale)
	attachHealthBar(humanoid, head, beast.Name)

	character.Parent = folder
	character:PivotTo(CFrame.new(Config.Npc.SpawnPosition))

	local npc: Npc = {
		character = character,
		humanoid = humanoid,
		root = root,
		torso = torso,
		beast = beast,
		wings = wings,
		lastAttack = 0,
		-- Counted from spawn, so it does not open with the special.
		lastSpecial = os.clock(),
		swingUntil = 0,
	}

	active[character] = npc

	humanoid.Died:Connect(function()
		active[character] = nil
		-- Only bring this beast back if the player has not since picked
		-- another one from the menu.
		local diedAs = index
		task.delay(Config.Npc.RespawnDelay, function()
			character:Destroy()
			if diedAs == currentIndex then
				spawnNpc(diedAs)
			end
		end)
	end)

	Remotes.event("BeastChanged"):FireAllClients(index, beast.Name, beast.MaxHealth)

	return npc
end

-- Swaps in a different beast: the current one is removed immediately.
local function selectBeast(index: number)
	index = math.clamp(math.floor(index), 1, #Config.Beasts)
	currentIndex = index

	for character in active do
		active[character] = nil
		character:Destroy()
	end

	spawnNpc(index)
end

--[[
	The special attack: a flame launched at the target.

	The projectile is anchored and stepped by hand rather than thrown with
	physics. Physics would let it bounce, spin or get shoved by a player
	standing in the way; a stepped position is predictable and cheap, and the
	hit test is a plain distance check against every player each step.
]]
local function launchFlame(npc: Npc, targetRoot: BasePart)
	local scale = npc.beast.Scale
	local origin = npc.torso.Position + npc.torso.CFrame.LookVector * 3 * scale + Vector3.new(0, 1, 0)

	local flame = Instance.new("Part")
	flame.Name = "Flame"
	flame.Shape = Enum.PartType.Ball
	flame.Size = Vector3.new(Config.Special.Size, Config.Special.Size, Config.Special.Size) * scale
	flame.Color = npc.beast.FlameColor
	flame.Material = Enum.Material.Neon
	flame.Anchored = true
	flame.CanCollide = false
	flame.CanQuery = false
	flame.CanTouch = false
	flame.CastShadow = false
	flame.Position = origin
	flame.Parent = folder

	makeFire(flame, Config.Fire.TorsoRate * 2, npc.beast.FlameColor)

	local light = Instance.new("PointLight")
	light.Color = npc.beast.FlameColor
	light.Brightness = 4
	light.Range = 20
	light.Parent = flame

	local sound = Instance.new("Sound")
	sound.SoundId = Config.Vfx.FlameSound
	sound.Volume = 0.6
	sound.RollOffMaxDistance = 160
	sound.Parent = flame
	sound:Play()

	-- Aimed where the target stood at launch, so it can be dodged by moving.
	local direction = targetRoot.Position - origin
	if direction.Magnitude < 0.1 then
		flame:Destroy()
		return
	end
	direction = direction.Unit

	task.spawn(function()
		local elapsed = 0

		while elapsed < Config.Special.Lifetime and flame.Parent do
			local deltaTime = task.wait()
			elapsed += deltaTime
			flame.Position += direction * Config.Special.Speed * deltaTime

			for _, player in Players:GetPlayers() do
				local character = player.Character
				local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
				local root = if character then character:FindFirstChild("HumanoidRootPart") else nil

				if
					humanoid
					and humanoid.Health > 0
					and root
					and root:IsA("BasePart")
					and (root.Position - flame.Position).Magnitude <= Config.Special.HitRadius * scale
				then
					humanoid:TakeDamage(npc.beast.SpecialDamage)
					Remotes.event("Hit"):FireClient(player, "flame", flame.Position)
					flame:Destroy()
					return
				end
			end
		end

		flame:Destroy()
	end)
end

-- Closest living player within AggroRange, or nil if nobody qualifies.
local function findTarget(from: Vector3): (Humanoid?, BasePart?)
	local bestHumanoid: Humanoid? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = Config.Npc.AggroRange

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil

		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			local distance = (root.Position - from).Magnitude
			if distance < bestDistance then
				bestHumanoid = humanoid
				bestRoot = root
				bestDistance = distance
			end
		end
	end

	return bestHumanoid, bestRoot
end

local function think(npc: Npc)
	if npc.humanoid.Health <= 0 then
		return
	end

	local targetHumanoid, targetRoot = findTarget(npc.root.Position)
	if not targetHumanoid or not targetRoot then
		return
	end

	local distance = (targetRoot.Position - npc.root.Position).Magnitude
	local now = os.clock()

	-- The special fires on its own timer, at any range inside aggro, so it
	-- can punish a player who backs off and waits out the melee.
	if now - npc.lastSpecial >= npc.beast.SpecialInterval then
		npc.lastSpecial = now
		npc.swingUntil = now + Config.Pose.SwingDuration

		task.delay(Config.Special.Windup, function()
			if npc.humanoid.Health > 0 and targetRoot.Parent then
				launchFlame(npc, targetRoot)
			end
		end)
		return
	end

	if distance > Config.Npc.AttackRange then
		npc.humanoid:MoveTo(targetRoot.Position)
		return
	end

	-- In range: stop and swing.
	npc.humanoid:MoveTo(npc.root.Position)

	if now - npc.lastAttack < npc.beast.AttackCooldown then
		return
	end
	npc.lastAttack = now
	npc.swingUntil = now + Config.Pose.SwingDuration

	targetHumanoid:TakeDamage(npc.beast.Damage)

	local victim = Players:GetPlayerFromCharacter(targetHumanoid.Parent)
	if victim then
		Remotes.event("Hit"):FireClient(victim, "melee", npc.root.Position)
	end
end

function NpcService:GetNpcs(): { [Model]: Npc }
	return active
end

function NpcService:Start()
	folder = Instance.new("Folder")
	folder.Name = "Npcs"
	folder.Parent = workspace

	spawnNpc(currentIndex)

	Remotes.event("SelectBeast").OnServerEvent:Connect(function(_player, index)
		-- The client sends a menu index and nothing else; anything that is not
		-- a number in range is ignored rather than trusted.
		if typeof(index) == "number" then
			selectBeast(index)
		end
	end)

	-- Thinking every frame is wasteful for walk-at-the-player behaviour, and
	-- MoveTo only needs re-issuing a few times a second.
	task.spawn(function()
		while true do
			for _, npc in active do
				if npc.character.Parent then
					think(npc)
				end
			end
			task.wait(0.25)
		end
	end)
end

return NpcService

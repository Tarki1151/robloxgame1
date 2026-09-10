--[[
	SwordService
	Gives every player a classic linked sword on spawn and resolves its hits.

	Damage is server-side. The client only triggers Tool.Activated; the server
	decides whether anything was actually hit, so a modified client cannot
	claim kills.

	Hit detection is the classic approach: while a swing is live, anything the
	blade touches takes damage once, with a per-target debounce so a single
	swing cannot tick repeatedly on the same enemy.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local SwordService = {}

local function makeSword(): Tool
	local tool = Instance.new("Tool")
	tool.Name = Config.Sword.Name
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, 0, -1.5) * CFrame.Angles(math.pi / 2, 0, math.pi / 2)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.8, 4.4, 0.8)
	handle.Color = Config.Sword.BladeColor
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Parent = tool

	-- The classic sword is one long handle plus a crossguard.
	local guard = Instance.new("Part")
	guard.Name = "Guard"
	guard.Size = Vector3.new(2, 0.35, 0.35)
	guard.Color = Config.Sword.GripColor
	guard.Material = Enum.Material.Metal
	guard.CanCollide = false
	guard.CanQuery = false
	guard.Massless = true
	guard.Parent = tool

	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = guard
	weld.C0 = CFrame.new(0, -1.7, 0)
	weld.Parent = handle

	return tool
end

local function equip(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not backpack or not humanoid then
		return
	end

	local tool = makeSword()
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

		victim:TakeDamage(Config.Sword.Damage)
	end)

	tool.Activated:Connect(function()
		local now = os.clock()
		if now - lastSwing < Config.Sword.Cooldown then
			return
		end
		lastSwing = now
		swingUntil = now + Config.Sword.HitWindow
		table.clear(struck)
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
end

return SwordService

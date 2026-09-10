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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CraftService = require(script.Parent.CraftService)
local WeaponFactory = require(script.Parent.WeaponFactory)

local SwordService = {}

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

		local hitSound = handle:FindFirstChild("Hit")
		if hitSound and hitSound:IsA("Sound") then
			hitSound:Play()
		end
	end)

	tool.Activated:Connect(function()
		local now = os.clock()
		if now - lastSwing < Config.Sword.Cooldown then
			return
		end
		lastSwing = now
		swingUntil = now + Config.Sword.HitWindow
		table.clear(struck)

		local slashSound = handle:FindFirstChild("Slash")
		if slashSound and slashSound:IsA("Sound") then
			slashSound:Play()
		end
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

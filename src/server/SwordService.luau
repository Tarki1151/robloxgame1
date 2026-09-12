--[[
	SwordService
	The classic sword on its pedestal in the castle courtyard.

	Taking it is a ProximityPrompt, same as the cave gate: in range only,
	works on every input device, nothing downloaded. The sword is built from
	parts so there is no model to import.

	Damage is resolved on the server. The client only fires Tool.Activated;
	what was hit and for how much is decided here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local SwordService = {}

local function buildSword(): Tool
	local tool = Instance.new("Tool")
	tool.Name = Config.Sword.Name
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, 0, -1.5) * CFrame.Angles(math.pi / 2, 0, math.pi / 2)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.8, Config.Sword.Reach, 0.8)
	handle.Color = Config.Sword.BladeColor
	handle.Material = Enum.Material.Metal
	handle.Reflectance = 0.15
	handle.CanCollide = false
	handle.Parent = tool

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
	weld.C0 = CFrame.new(0, -Config.Sword.Reach / 2 + 0.5, 0)
	weld.Parent = handle

	return tool
end

-- Hit resolution: anything the blade touches during a swing takes damage
-- once, with a per-target debounce so one swing cannot tick repeatedly.
local function arm(tool: Tool, owner: Player)
	local handle = tool:FindFirstChild("Handle") :: BasePart
	local lastSwing = 0
	local swingUntil = 0
	local struck: { [Humanoid]: number } = {}

	handle.Touched:Connect(function(hit)
		if os.clock() > swingUntil then
			return
		end

		local character = hit:FindFirstAncestorOfClass("Model")
		if not character or character == owner.Character then
			return
		end

		local victim = character:FindFirstChildOfClass("Humanoid")
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
end

-- The pedestal, with the sword standing point-down in it.
local function buildPedestal(position: Vector3, parent: Instance): BasePart
	local model = Instance.new("Model")
	model.Name = "SwordPedestal"
	model.Parent = parent

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(8, 2, 8)
	base.Position = position + Vector3.new(0, 3, 0)
	base.Color = Config.Sword.PedestalColor
	base.Material = Enum.Material.Cobblestone
	base.Anchored = true
	base.Parent = model

	local column = Instance.new("Part")
	column.Name = "Column"
	column.Size = Vector3.new(4.5, 5, 4.5)
	column.Position = position + Vector3.new(0, 6.5, 0)
	column.Color = Config.Sword.PedestalColor
	column.Material = Enum.Material.Cobblestone
	column.Anchored = true
	column.Parent = model

	-- The display sword: a second, static copy. Handing out the real Tool
	-- would leave the pedestal empty for everyone else.
	local blade = Instance.new("Part")
	blade.Name = "DisplayBlade"
	blade.Size = Vector3.new(0.8, Config.Sword.Reach, 0.8)
	blade.Position = position + Vector3.new(0, 11, 0)
	blade.Color = Config.Sword.BladeColor
	blade.Material = Enum.Material.Metal
	blade.Reflectance = 0.2
	blade.Anchored = true
	blade.CanCollide = false
	blade.Parent = model

	local guard = Instance.new("Part")
	guard.Name = "DisplayGuard"
	guard.Size = Vector3.new(2.4, 0.4, 0.4)
	guard.Position = position + Vector3.new(0, 11 - Config.Sword.Reach / 2 + 0.5, 0)
	guard.Color = Config.Sword.GripColor
	guard.Material = Enum.Material.Metal
	guard.Anchored = true
	guard.CanCollide = false
	guard.Parent = model

	local glow = Instance.new("PointLight")
	glow.Color = Config.Sword.GlowColor
	glow.Brightness = 2
	glow.Range = 20
	glow.Parent = blade

	return column
end

function SwordService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Pickups"
	folder.Parent = workspace

	local castleOrigin = Config.Castle.Direction.Unit * Config.Castle.Distance
	local position = castleOrigin + Config.Sword.PedestalOffset

	local column = buildPedestal(position, folder)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TakeSword"
	prompt.ActionText = Config.Sword.PromptAction
	prompt.ObjectText = Config.Sword.Name
	prompt.MaxActivationDistance = Config.Sword.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = column

	prompt.Triggered:Connect(function(player)
		local backpack = player:FindFirstChildOfClass("Backpack")
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not backpack or not humanoid then
			return
		end

		-- One each: taking it twice would just clutter the backpack.
		if
			backpack:FindFirstChild(Config.Sword.Name)
			or (character and character:FindFirstChild(Config.Sword.Name))
		then
			return
		end

		local tool = buildSword()
		arm(tool, player)
		tool.Parent = backpack
		humanoid:EquipTool(tool)

		Remotes.event("SwordTaken"):FireClient(player)
	end)

	print("[Sword] pedestal placed in the courtyard.")
end

return SwordService

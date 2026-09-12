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

local SaveService = require(script.Parent.SaveService)
local SwingPose = require(script.Parent.SwingPose)
local SwordModel = require(script.Parent.SwordModel)

local SwordService = {}

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

		local character = owner.Character
		if character then
			local trail = handle:FindFirstChild("SlashTrail")
			SwingPose.play(character, if trail and trail:IsA("Trail") then trail else nil)
		end
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

	--[[
		The display sword: a static copy standing point-down in the stone.

		Built by the same code as the real one, so the pedestal always shows
		exactly the sword you are about to receive rather than a lookalike
		that drifts out of date as the real one changes.

		The parts are positioned by hand rather than by moving the Handle and
		letting the welds follow. Welds are solved by the physics step, and
		these parts are anchored immediately - they would freeze where they
		were built, scattered around the origin, before any weld ran. Since
		every part was welded to a Handle sitting at the identity CFrame, each
		part's own CFrame is exactly its offset from the grip, so placing the
		sword is one multiply per part.
	]]
	local display = SwordModel.build()
	local standing = CFrame.new(position + Vector3.new(0, 10.5, 0)) * CFrame.Angles(0, 0, math.pi)

	local displayHandle: BasePart? = nil

	for _, item in display:GetChildren() do
		if item:IsA("BasePart") then
			item.CFrame = standing * item.CFrame
			item.Anchored = true
			item.CanCollide = false

			-- The welds have done their job; keeping them on anchored parts
			-- only invites the physics solver to argue with the placement.
			for _, child in item:GetChildren() do
				if child:IsA("Weld") or child:IsA("WeldConstraint") then
					child:Destroy()
				end
			end

			if item.Name == "Handle" then
				displayHandle = item
			end

			item.Parent = model
		end
	end

	display:Destroy()

	local glow = Instance.new("PointLight")
	glow.Color = Config.Sword.GlowColor
	glow.Brightness = 2
	glow.Range = 20
	glow.Parent = displayHandle or column

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

	-- Hands a player the sword. Used by the prompt, and when a slot that
	-- already has it is loaded.
	local function give(player: Player): boolean
		local backpack = player:FindFirstChildOfClass("Backpack")
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not backpack or not character or not humanoid then
			return false
		end

		-- One each: taking it twice would just clutter the backpack.
		if backpack:FindFirstChild(Config.Sword.Name) or character:FindFirstChild(Config.Sword.Name) then
			return false
		end

		local tool = SwordModel.build()
		arm(tool, player)
		tool.Parent = backpack
		humanoid:EquipTool(tool)
		return true
	end

	prompt.Triggered:Connect(function(player)
		if not give(player) then
			return
		end

		SaveService:Update(player, function(profile)
			profile.SwordTaken = true
		end)

		Remotes.event("SwordTaken"):FireClient(player)
	end)

	--[[
		Loading a slot that already has the sword hands it straight back, so
		continuing a run does not mean walking to the pedestal again.

		Deferred: the slot can be chosen before the character exists, and
		there is nothing to hand a sword to until it does.
	]]
	SaveService.SlotLoaded = function(player: Player, profile)
		if not profile.SwordTaken then
			return
		end

		task.defer(function()
			if give(player) then
				Remotes.event("SwordTaken"):FireClient(player)
			end
		end)
	end

	print("[Sword] pedestal placed in the courtyard.")
end

return SwordService

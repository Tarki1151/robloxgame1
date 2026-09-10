--[[
	WorldService
	Toplama alanlarini ve satis padlerini yonetir.

	Parcalar CollectionService etiketiyle bulunur, isimle degil. Kendi haritani
	yaptiginda ilgili parcaya Studio'dan "CollectZone" / "SellPad" etiketini ver
	(Studio: View > Tag Editor) ve Config.World.CreatePlaceholders = false yap.

	Hic etiketli parca yoksa oyunun bos bir yerde bile oynanabilir olmasi icin
	placeholder bir zemin, spawn, toplama alani ve satis padi olusturur.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local EconomyService = require(script.Parent.EconomyService)

local WorldService = {}

local notifyRemote = Remotes.event("Notify")
local sellDebounce: { [Player]: number } = {}
local boundPads: { [Instance]: boolean } = {}

local function ensureFolder(): Folder
	local folder = workspace:FindFirstChild("GameWorld")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "GameWorld"
		folder.Parent = workspace
	end
	return folder :: Folder
end

local function label(parent: BasePart, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(12, 3)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 250

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextScaled = true
	textLabel.Text = text
	textLabel.TextColor3 = color
	textLabel.TextStrokeTransparency = 0.4
	textLabel.Parent = gui

	gui.Parent = parent
end

local function createPart(
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	parent: Instance
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Parent = parent
	return part
end

local function onSellTouched(hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local now = os.clock()
	if now - (sellDebounce[player] or 0) < Config.Sell.Debounce then
		return
	end
	sellDebounce[player] = now

	local earned = EconomyService:Sell(player)
	if earned > 0 then
		notifyRemote:FireClient(player, string.format("+%s", Format.money(earned)), "success")
	end
end

local function bindSellPad(pad: Instance)
	if boundPads[pad] or not pad:IsA("BasePart") then
		return
	end
	boundPads[pad] = true

	pad.Touched:Connect(onSellTouched)

	pad.Destroying:Connect(function()
		boundPads[pad] = nil
	end)
end

-- Verilen noktanin herhangi bir toplama alaninin icinde olup olmadigini
-- dondurur. Dondurulmus parcalari da destekleyen tam OBB testi.
function WorldService:IsInCollectZone(position: Vector3): boolean
	local zones = CollectionService:GetTagged(Config.World.CollectZoneTag)
	if #zones == 0 then
		-- Alan tanimli degilse toplamayi engellemeyelim.
		return true
	end

	local padding = Config.Collect.ZonePadding

	for _, zone in zones do
		if zone:IsA("BasePart") then
			local offset = zone.CFrame:PointToObjectSpace(position)
			local half = zone.Size / 2
			if
				math.abs(offset.X) <= half.X + padding
				and math.abs(offset.Y) <= half.Y + padding * 2
				and math.abs(offset.Z) <= half.Z + padding
			then
				return true
			end
		end
	end

	return false
end

local function createPlaceholders()
	local folder = ensureFolder()

	-- Zemin: sadece sahnede hic zemin yoksa.
	local hasGround = false
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Anchored and descendant.Size.X >= 100 then
			hasGround = true
			break
		end
	end
	if not hasGround then
		local baseplate = createPart(
			"Baseplate",
			Vector3.new(512, 4, 512),
			Vector3.new(0, -2, 0),
			Color3.fromRGB(91, 154, 76),
			folder
		)
		baseplate.Material = Enum.Material.Grass
	end

	if not workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
		local spawnLocation = Instance.new("SpawnLocation")
		spawnLocation.Name = "SpawnPad"
		spawnLocation.Size = Vector3.new(24, 1, 24)
		spawnLocation.Position = Vector3.new(0, 0.5, 0)
		spawnLocation.Anchored = true
		spawnLocation.Material = Enum.Material.SmoothPlastic
		spawnLocation.Color = Color3.fromRGB(220, 220, 220)
		spawnLocation.Parent = folder
	end

	if #CollectionService:GetTagged(Config.World.CollectZoneTag) == 0 then
		local zone = createPart(
			"CollectZone",
			Vector3.new(80, 1, 80),
			Vector3.new(0, 0.5, -70),
			Color3.fromRGB(122, 100, 200),
			folder
		)
		label(zone, "TOPLAMA ALANI", Color3.fromRGB(200, 180, 255))
		CollectionService:AddTag(zone, Config.World.CollectZoneTag)
	end

	if #CollectionService:GetTagged(Config.World.SellPadTag) == 0 then
		local pad = createPart(
			"SellPad",
			Vector3.new(20, 1, 20),
			Vector3.new(0, 0.5, 45),
			Color3.fromRGB(76, 190, 110),
			folder
		)
		label(pad, "SAT", Color3.fromRGB(180, 255, 200))
		CollectionService:AddTag(pad, Config.World.SellPadTag)
	end
end

function WorldService:Start()
	if Config.World.CreatePlaceholders then
		createPlaceholders()
	end

	for _, pad in CollectionService:GetTagged(Config.World.SellPadTag) do
		bindSellPad(pad)
	end
	CollectionService:GetInstanceAddedSignal(Config.World.SellPadTag):Connect(bindSellPad)

	Players.PlayerRemoving:Connect(function(player)
		sellDebounce[player] = nil
	end)
end

return WorldService

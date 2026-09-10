--[[
	ToolVisualService
	Profildeki ToolIndex'i karakterin elinde gorunen bir Tool'a cevirir.

	Model kaynagi:
	  1. ServerStorage/<Config.ToolVisual.FolderName> icinde araci adiyla
	     (veya Config girdisindeki Model alaniyla) eslesen bir Tool varsa
	     onun kopyasi kullanilir.
	  2. Yoksa ve Config.ToolVisual.CreatePlaceholders acikssa sunucu basit bir
	     kazma modeli uretir. Boylece bos bir sahnede de elde bir sey gorunur.

	Gorsel katman otoriter degildir: hicbir kazanc hesabi buraya bagli degil.
	Servis calismasa bile oyun aynen calisir, arac sadece gorunmez.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local DataService = require(script.Parent.DataService)

local ToolVisualService = {}

-- Bizim urettigimiz Tool'lari oyuncunun kendi esyalarindan ayirt etmek icin.
local OWNED_ATTRIBUTE = "SimulatorTool"

local equipped: { [Player]: { index: number, tool: Tool } } = {}

local function toolIndexOf(profile): number
	return math.clamp(math.floor(profile.ToolIndex), 1, #Config.Tools)
end

local function findTemplate(entry): Tool?
	local folder = ServerStorage:FindFirstChild(Config.ToolVisual.FolderName)
	if not folder then
		return nil
	end

	local template = folder:FindFirstChild(entry.Model or entry.Name)
	if not template then
		return nil
	end

	if not template:IsA("Tool") then
		warn(
			string.format(
				"[ToolVisualService] '%s' bir Tool degil (%s), placeholder kullanilacak.",
				template.Name,
				template.ClassName
			)
		)
		return nil
	end

	return template
end

local function makePart(name: string, size: Vector3, color: Color3, material: Enum.Material): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Model bulunamadiginda kullanilan basit kazma: sap + baslik.
local function buildPlaceholder(entry): Tool
	local tool = Instance.new("Tool")
	tool.Name = entry.Name
	-- Kendi modelini koydugunda onun Grip'ine dokunmuyoruz; bu sadece
	-- placeholder'in ele duzgun oturmasi icin.
	tool.Grip = Config.ToolVisual.PlaceholderGrip

	local handle =
		makePart("Handle", Vector3.new(0.35, 3.2, 0.35), Color3.fromRGB(105, 74, 48), Enum.Material.Wood)
	handle.Parent = tool

	local head = makePart(
		"Head",
		Vector3.new(2.2, 0.45, 0.5),
		entry.Color or Color3.fromRGB(170, 170, 175),
		Enum.Material.Metal
	)
	head.CFrame = handle.CFrame * CFrame.new(0, 1.4, 0)
	head.Parent = tool

	-- WeldConstraint degil Weld: ofset sabit C0 ile tanimlanir, boylece Tool
	-- ele takilip Handle isinlandiginda baslik yerinden kaymaz.
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = head
	weld.C0 = CFrame.new(0, 1.4, 0)
	weld.Parent = handle

	return tool
end

local function buildTool(entry): Tool?
	local template = findTemplate(entry)
	if template then
		return template:Clone()
	end

	if not Config.ToolVisual.CreatePlaceholders then
		return nil
	end

	return buildPlaceholder(entry)
end

-- Bizim daha once verdigimiz Tool'lari temizler, oyuncunun digerlerine dokunmaz.
local function clearOwnedTools(player: Player)
	local containers = { player:FindFirstChildOfClass("Backpack"), player.Character }
	for _, container in containers do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute(OWNED_ATTRIBUTE) then
					child:Destroy()
				end
			end
		end
	end
end

local function apply(player: Player)
	local profile = DataService:Get(player)
	if not profile then
		return
	end

	local character = player.Character
	if not character or not character.Parent then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local index = toolIndexOf(profile)

	-- ProfileChanged her toplamada atesler; ayni arac zaten elindeyse cikalim.
	local current = equipped[player]
	if current and current.index == index and current.tool.Parent then
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	local entry = Config.Tools[index]
	local tool = buildTool(entry)
	if not tool then
		equipped[player] = nil
		return
	end

	clearOwnedTools(player)

	tool:SetAttribute(OWNED_ATTRIBUTE, true)
	tool.CanBeDropped = false
	tool.Parent = backpack

	equipped[player] = { index = index, tool = tool }

	humanoid:EquipTool(tool)
end

local function onCharacterAdded(player: Player, character: Model)
	-- Yeni karakter, yeni Tool: onbellegi dusur ve Humanoid hazir olunca kur.
	equipped[player] = nil

	-- Humanoid karakterle ayni anda gelmeyebilir; kisa sure bekle.
	if not character:FindFirstChildOfClass("Humanoid") then
		character:WaitForChild("Humanoid", 10)
	end

	apply(player)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(onCharacterAdded, player, character)
	end)

	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function ToolVisualService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	-- Satin alma sonrasi ToolIndex degisince el otomatik guncellensin.
	DataService.ProfileAdded:Connect(function(player)
		apply(player)
	end)
	DataService.ProfileChanged:Connect(function(player)
		apply(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		equipped[player] = nil
	end)
end

return ToolVisualService

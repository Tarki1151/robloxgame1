--[[
	CollectService
	Toplama eyleminin sunucu tarafi. Client sadece "toplamak istiyorum" der;
	kazanc miktarina, hizina ve gecerliligine daima sunucu karar verir.

	Dogrulamalar:
	  1. Cooldown  - exploit ile saniyede yuzlerce istek atilmasini engeller.
	  2. Konum     - oyuncunun gercekten toplama alaninda olmasi gerekir.
	  3. Kapasite  - canta doluysa kazanc yok.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local WorldService = require(script.Parent.WorldService)

local CollectService = {}

local lastCollect: { [Player]: number } = {}

local function getRootPosition(player: Player): Vector3?
	local character = player.Character
	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return root.Position
end

local function onCollectRequest(player: Player)
	local now = os.clock()
	-- Cooldown'un biraz altini tolere ediyoruz (ag gecikmesi payi).
	if now - (lastCollect[player] or 0) < Config.Collect.Cooldown * 0.9 then
		return
	end

	local profile = DataService:Get(player)
	if not profile then
		return
	end

	local position = getRootPosition(player)
	if not position or not WorldService:IsInCollectZone(position) then
		return
	end

	lastCollect[player] = now

	local tool = EconomyService:GetTool(profile)
	EconomyService:AddResources(player, tool.Power)
end

function CollectService:Start()
	Remotes.event("Collect").OnServerEvent:Connect(onCollectRequest)

	Players.PlayerRemoving:Connect(function(player)
		lastCollect[player] = nil
	end)
end

return CollectService

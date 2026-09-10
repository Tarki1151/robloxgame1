--[[
	LeaderstatsService
	Roblox'un yerlesik oyuncu listesi tablosu. Profil degistikce senkronlanir.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local DataService = require(script.Parent.DataService)

local LeaderstatsService = {}

local stats: { [Player]: { Coins: IntValue, Rebirths: IntValue } } = {}

local function onProfileAdded(player: Player, profile: any)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	local coins = Instance.new("IntValue")
	coins.Name = Config.Currency.Name
	coins.Value = profile.Coins
	coins.Parent = folder

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = profile.Rebirths
	rebirths.Parent = folder

	stats[player] = { Coins = coins, Rebirths = rebirths }
	folder.Parent = player
end

local function onProfileChanged(player: Player, profile: any)
	local entry = stats[player]
	if not entry then
		return
	end
	entry.Coins.Value = math.floor(profile.Coins)
	entry.Rebirths.Value = profile.Rebirths
end

function LeaderstatsService:Start()
	DataService.ProfileAdded:Connect(onProfileAdded)
	DataService.ProfileChanged:Connect(onProfileChanged)
	DataService.ProfileRemoving:Connect(function(player)
		stats[player] = nil
	end)
end

return LeaderstatsService

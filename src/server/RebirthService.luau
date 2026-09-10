--[[
	RebirthService
	Ilerlemeyi sifirlayip kalici bir kazanc carpani veren dongu.
	Simulator turunun uzun vadeli motivasyon motoru budur.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local RebirthService = {}

local notifyRemote = Remotes.event("Notify")

local function onRebirthRequest(player: Player)
	local profile = DataService:Get(player)
	if not profile then
		return
	end

	if profile.Rebirths >= Config.Rebirth.MaxRebirths then
		notifyRemote:FireClient(player, "Maksimum rebirth seviyesindesin.", "info")
		return
	end

	local cost = EconomyService:GetRebirthCost(profile)
	if profile.Coins < cost then
		notifyRemote:FireClient(player, "Rebirth icin " .. Format.money(cost) .. " gerekli.", "error")
		return
	end

	DataService:Update(player, function(data)
		data.Coins = 0
		data.Backpack = 0
		data.ToolIndex = 1
		data.BackpackIndex = 1
		data.Rebirths += 1
	end)

	local updated = DataService:Get(player)
	notifyRemote:FireClient(
		player,
		string.format("Rebirth %d! Kazanc carpani x%.1f", updated.Rebirths, EconomyService:GetMultiplier(updated)),
		"success"
	)
end

function RebirthService:Start()
	Remotes.event("Rebirth").OnServerEvent:Connect(onRebirthRequest)
end

return RebirthService

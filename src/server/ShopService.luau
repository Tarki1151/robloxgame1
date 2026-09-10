--[[
	ShopService
	Arac ve sirt cantasi yukseltmeleri. Client'tan gelen index degeri asla
	dogrudan profile yazilmaz; once dogrulanir.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local ShopService = {}

local notifyRemote = Remotes.event("Notify")

-- Ortak satin alma akisi: hem araclar hem cantalar ayni kurallara uyar.
local function purchase(
	player: Player,
	requestedIndex: any,
	list: { any },
	currentField: string,
	noun: string
)
	if typeof(requestedIndex) ~= "number" then
		return
	end

	local index = math.floor(requestedIndex)
	local profile = DataService:Get(player)
	if not profile then
		return
	end

	if index < 1 or index > #list then
		return
	end

	if index <= profile[currentField] then
		notifyRemote:FireClient(player, "Bu " .. noun .. " zaten sende.", "info")
		return
	end

	local entry = list[index]
	if not EconomyService:TrySpend(player, entry.Price) then
		notifyRemote:FireClient(player, "Yeterli paran yok.", "error")
		return
	end

	DataService:Update(player, function(data)
		data[currentField] = index
	end)

	notifyRemote:FireClient(player, entry.Name .. " alindi!", "success")
end

function ShopService:Start()
	Remotes.event("BuyTool").OnServerEvent:Connect(function(player, index)
		purchase(player, index, Config.Tools, "ToolIndex", "arac")
	end)

	Remotes.event("BuyBackpack").OnServerEvent:Connect(function(player, index)
		purchase(player, index, Config.Backpacks, "BackpackIndex", "canta")
	end)
end

return ShopService

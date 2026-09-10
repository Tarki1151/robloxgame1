--[[
	EconomyService
	Para, sirt cantasi doluluğu ve satis mantigi. Tum sayisal kurallar burada;
	baska hicbir servis profile dogrudan para yazmaz.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local DataService = require(script.Parent.DataService)

local EconomyService = {}

local function clampIndex(index: number, list: { any }): number
	return math.clamp(math.floor(index), 1, #list)
end

function EconomyService:GetTool(profile)
	return Config.Tools[clampIndex(profile.ToolIndex, Config.Tools)]
end

function EconomyService:GetBackpack(profile)
	return Config.Backpacks[clampIndex(profile.BackpackIndex, Config.Backpacks)]
end

function EconomyService:GetCapacity(profile): number
	return self:GetBackpack(profile).Capacity
end

-- Rebirth sayisina bagli satis carpani.
function EconomyService:GetMultiplier(profile): number
	return 1 + profile.Rebirths * Config.Rebirth.EarningsBonusPerRebirth
end

function EconomyService:GetRebirthCost(profile): number
	return math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostMultiplier ^ profile.Rebirths)
end

-- Sirt cantasina kaynak ekler, kapasiteyi asmaz. Gercekte eklenen miktari doner.
function EconomyService:AddResources(player: Player, amount: number): number
	local profile = DataService:Get(player)
	if not profile or amount <= 0 then
		return 0
	end

	local capacity = self:GetCapacity(profile)
	local added = math.min(amount, capacity - profile.Backpack)
	if added <= 0 then
		return 0
	end

	DataService:Update(player, function(data)
		data.Backpack += added
	end)

	return added
end

-- Sirt cantasini bosaltip paraya cevirir. Kazanilan parayi doner.
function EconomyService:Sell(player: Player): number
	local profile = DataService:Get(player)
	if not profile or profile.Backpack <= 0 then
		return 0
	end

	local earned = 0

	DataService:Update(player, function(data)
		earned = math.floor(data.Backpack * EconomyService:GetMultiplier(data))
		data.Coins += earned
		data.TotalCollected += data.Backpack
		data.Backpack = 0
	end)

	return earned
end

-- Yeterli para varsa dusurur. Basarili olursa true doner.
function EconomyService:TrySpend(player: Player, cost: number): boolean
	local profile = DataService:Get(player)
	if not profile or cost < 0 or profile.Coins < cost then
		return false
	end

	DataService:Update(player, function(data)
		data.Coins -= cost
	end)

	return true
end

return EconomyService

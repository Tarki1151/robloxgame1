--[[
	NetworkService
	Profil her degistiginde ilgili oyuncuya sadelestirilmis bir durum
	fotografi (snapshot) gonderir. Client hicbir zaman ham profili gormez.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local NetworkService = {}

local stateRemote = Remotes.event("StateChanged")

local function buildSnapshot(profile: any)
	local rebirthCost = EconomyService:GetRebirthCost(profile)

	return {
		Coins = profile.Coins,
		Backpack = profile.Backpack,
		Capacity = EconomyService:GetCapacity(profile),
		Rebirths = profile.Rebirths,
		ToolIndex = profile.ToolIndex,
		BackpackIndex = profile.BackpackIndex,
		Multiplier = EconomyService:GetMultiplier(profile),
		RebirthCost = rebirthCost,
		CanRebirth = profile.Coins >= rebirthCost and profile.Rebirths < Config.Rebirth.MaxRebirths,
	}
end

function NetworkService:Start()
	DataService.ProfileChanged:Connect(function(player: Player, profile: any)
		if player.Parent then
			stateRemote:FireClient(player, buildSnapshot(profile))
		end
	end)
end

return NetworkService

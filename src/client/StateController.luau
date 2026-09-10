--[[
	StateController
	Sunucudan gelen durum fotografini tutar ve degisimi yayinlar.
	Tum arayuz parcalari veriyi buradan okur; hicbiri remote'a dogrudan baglanmaz.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local StateController = {}

StateController.Changed = Signal.new()

local state = {
	Coins = 0,
	Backpack = 0,
	Capacity = 0,
	Rebirths = 0,
	ToolIndex = 1,
	BackpackIndex = 1,
	Multiplier = 1,
	RebirthCost = 0,
	CanRebirth = false,
}

function StateController:Get()
	return state
end

function StateController:Start()
	Remotes.event("StateChanged").OnClientEvent:Connect(function(snapshot)
		if typeof(snapshot) ~= "table" then
			return
		end
		state = snapshot
		self.Changed:Fire(state)
	end)
end

return StateController

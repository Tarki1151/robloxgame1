--[[
	CraftService
	Embers, weapon ownership, and crafting.

	Everything is decided here: the client sends an index and nothing else, and
	the server checks that the weapon exists, that it is not already owned, and
	that the player can afford it. A modified client can ask for anything and
	still get nothing.

	State is in memory only. This place has no DataStore, so progress lasts for
	the session - kill beasts, craft, fight, and it resets on rejoin. Saving is
	a DataService away if you want it to persist.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local CraftService = {}

type Wallet = {
	embers: number,
	-- Weapon index -> true for everything crafted so far.
	owned: { [number]: boolean },
	equipped: number,
}

local wallets: { [Player]: Wallet } = {}

-- Set by WeaponService, so crafting can hand over the new weapon at once.
CraftService.OnEquip = nil :: ((Player, number) -> ())?

local function push(player: Player)
	local wallet = wallets[player]
	if not wallet then
		return
	end

	-- Sent as a plain list of indices: table keys do not survive the trip to
	-- the client intact when they are sparse.
	local owned: { number } = {}
	for index in wallet.owned do
		table.insert(owned, index)
	end
	table.sort(owned)

	Remotes.event("WalletChanged"):FireClient(player, wallet.embers, owned, wallet.equipped)
end

function CraftService:Get(player: Player): Wallet?
	return wallets[player]
end

function CraftService:GetEquipped(player: Player): number
	local wallet = wallets[player]
	return if wallet then wallet.equipped else Config.Craft.StarterWeapon
end

function CraftService:Award(player: Player, amount: number)
	local wallet = wallets[player]
	if not wallet or amount <= 0 then
		return
	end

	wallet.embers += math.floor(amount)
	push(player)
end

local function craft(player: Player, index: any)
	if typeof(index) ~= "number" then
		return
	end

	index = math.floor(index)
	local weapon = Config.Weapons[index]
	local wallet = wallets[player]
	if not weapon or not wallet or wallet.owned[index] then
		return
	end

	if wallet.embers < weapon.Cost then
		return
	end

	wallet.embers -= weapon.Cost
	wallet.owned[index] = true
	wallet.equipped = index
	push(player)

	local onEquip = CraftService.OnEquip
	if onEquip then
		onEquip(player, index)
	end
end

local function equip(player: Player, index: any)
	if typeof(index) ~= "number" then
		return
	end

	index = math.floor(index)
	local wallet = wallets[player]
	-- Owning it is the whole check: you cannot equip what you never crafted.
	if not wallet or not wallet.owned[index] then
		return
	end

	wallet.equipped = index
	push(player)

	local onEquip = CraftService.OnEquip
	if onEquip then
		onEquip(player, index)
	end
end

local function onPlayerAdded(player: Player)
	wallets[player] = {
		embers = 0,
		owned = { [Config.Craft.StarterWeapon] = true },
		equipped = Config.Craft.StarterWeapon,
	}
	push(player)
end

function CraftService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		wallets[player] = nil
	end)

	Remotes.event("CraftWeapon").OnServerEvent:Connect(craft)
	Remotes.event("EquipWeapon").OnServerEvent:Connect(equip)
end

return CraftService

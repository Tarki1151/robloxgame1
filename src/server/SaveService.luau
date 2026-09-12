--[[
	SaveService
	Five save slots per player, held in a DataStore.

	Each slot is an independent run. A player picks one before playing; every
	change to progress goes through Update(), which marks the slot dirty, and
	the slot is written on a timer, when a player leaves, and when the server
	shuts down.

	Two things this is careful about, both learned the hard way:

	  - GetDataStore is called inside a pcall, not at module scope. In Studio
	    without API access it throws, and a throw at module scope takes down
	    every service that loads after it.
	  - When the store is unreachable, play continues against an in-memory
	    profile. You lose saving, not the game, and the Output says so once
	    rather than on every write.

	No session locking. One server per player is the assumption here; two
	servers writing the same slot would need a lock, which is a bigger piece
	of work than this game currently justifies.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local SaveService = {}

type Session = {
	-- Which slot is being played, or nil while the menu is up.
	slot: number?,
	-- Every slot the player has, indexed 1..SlotCount. Missing means empty.
	slots: { [number]: any },
	dirty: boolean,
	-- Set when this player's data could not be reached, so play continues
	-- without saving instead of stalling.
	offline: boolean,
	joinedAt: number,
}

local sessions: { [Player]: Session } = {}
local store: DataStore? = nil
local storeWarned = false

-- Set by other services that need to react when a slot is loaded.
SaveService.SlotLoaded = nil :: ((Player, any) -> ())?

local function key(userId: number): string
	return "Player_" .. tostring(userId)
end

local function openStore(): DataStore?
	if store then
		return store
	end

	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Save.StoreName)
	end)

	if ok then
		store = result
		return store
	end

	if not storeWarned then
		storeWarned = true
		warn(
			"[Save] DataStore unavailable, progress will not persist: "
				.. tostring(result)
				.. " (publish the place and enable Studio Access to API Services)"
		)
	end

	return nil
end

--[[
	Fills a loaded profile out against the defaults.

	Fields the save does not have are taken from DefaultProfile, and fields it
	has that are no longer in the schema are dropped. This is what lets a new
	field be added without invalidating anyone's slot.
]]
local function reconcile(saved: any): any
	local profile = {}

	for field, default in Config.Save.DefaultProfile do
		local value = if typeof(saved) == "table" then saved[field] else nil
		profile[field] = if typeof(value) == typeof(default) then value else default
	end

	return profile
end

local function blankProfile(): any
	local profile = reconcile(nil)
	profile.CreatedAt = os.time()
	profile.SavedAt = os.time()
	return profile
end

-- What the client needs to draw the slot list: enough to tell runs apart,
-- without shipping the whole profile.
local function summarise(session: Session): { any }
	local list = {}

	for index = 1, Config.Save.SlotCount do
		local profile = session.slots[index]

		if profile then
			local done = 0
			for _, field in { "ReachedCastle", "SwordTaken", "CaveOpened", "TutorialDone" } do
				if profile[field] then
					done += 1
				end
			end

			table.insert(list, {
				slot = index,
				used = true,
				steps = done,
				total = 4,
				playSeconds = math.floor(profile.PlaySeconds),
				savedAt = profile.SavedAt,
				active = session.slot == index,
			})
		else
			table.insert(list, { slot = index, used = false, active = false })
		end
	end

	return list
end

local function push(player: Player)
	local session = sessions[player]
	if session then
		Remotes.event("SlotsChanged"):FireClient(player, summarise(session), session.offline)
	end
end

local function load(player: Player): ({ [number]: any }, boolean)
	local dataStore = openStore()
	if not dataStore then
		return {}, true
	end

	for attempt = 1, Config.Save.LoadRetries do
		local ok, result = pcall(function()
			return dataStore:GetAsync(key(player.UserId))
		end)

		if ok then
			local slots: { [number]: any } = {}
			if typeof(result) == "table" then
				for index = 1, Config.Save.SlotCount do
					-- Keys come back as strings from JSON, so both are tried.
					local saved = result[index] or result[tostring(index)]
					if typeof(saved) == "table" then
						slots[index] = reconcile(saved)
					end
				end
			end
			return slots, false
		end

		warn(string.format("[Save] load failed for %s (try %d): %s", player.Name, attempt, tostring(result)))
		task.wait(Config.Save.RetryDelay * attempt)
	end

	return {}, true
end

-- Writes every slot the player has. Returns whether it reached the store.
local function persist(player: Player): boolean
	local session = sessions[player]
	if not session or session.offline then
		return false
	end

	local dataStore = openStore()
	if not dataStore then
		return false
	end

	-- Serialised with string keys: a table with gaps is not an array, and a
	-- sparse array does not survive the round trip intact.
	local payload = {}
	for index, profile in session.slots do
		payload[tostring(index)] = profile
	end

	local ok, err = pcall(function()
		dataStore:SetAsync(key(player.UserId), payload)
	end)

	if not ok then
		warn(string.format("[Save] write failed for %s: %s", player.Name, tostring(err)))
		return false
	end

	session.dirty = false
	return true
end

-- Where the player is standing, folded into the active profile.
local function capture(player: Player)
	local session = sessions[player]
	local profile = if session and session.slot then session.slots[session.slot] else nil
	if not profile then
		return
	end

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		profile.PositionX = root.Position.X
		profile.PositionY = root.Position.Y
		profile.PositionZ = root.Position.Z
	end

	local now = os.clock()
	profile.PlaySeconds += now - session.joinedAt
	session.joinedAt = now
	profile.SavedAt = os.time()
end

function SaveService:Get(player: Player): any
	local session = sessions[player]
	if not session or not session.slot then
		return nil
	end
	return session.slots[session.slot]
end

--[[
	The one way progress changes.

	  SaveService:Update(player, function(profile)
	      profile.SwordTaken = true
	  end)

	Marks the slot dirty so the next autosave picks it up, rather than writing
	immediately - DataStore requests are rate limited, and progress here
	changes in bursts.
]]
function SaveService:Update(player: Player, mutator: (any) -> ()): boolean
	local profile = self:Get(player)
	if not profile then
		return false
	end

	mutator(profile)

	local session = sessions[player]
	if session then
		session.dirty = true
	end

	return true
end

local function activate(player: Player, index: number)
	local session = sessions[player]
	if not session then
		return
	end

	local profile = session.slots[index]
	if not profile then
		return
	end

	session.slot = index
	session.joinedAt = os.clock()
	push(player)

	local onLoaded = SaveService.SlotLoaded
	if onLoaded then
		onLoaded(player, profile)
	end

	-- Put the player back where they left off.
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		root.CFrame = CFrame.new(Vector3.new(profile.PositionX, profile.PositionY + 3, profile.PositionZ))
	end
end

local function onSelect(player: Player, index: any)
	if typeof(index) ~= "number" then
		return
	end

	index = math.floor(index)
	local session = sessions[player]
	if not session or index < 1 or index > Config.Save.SlotCount then
		return
	end

	-- Selecting an empty slot does nothing: creating is a separate, explicit
	-- action, so a stray click cannot start a run over the top of nothing.
	if not session.slots[index] then
		return
	end

	activate(player, index)
end

local function onCreate(player: Player, index: any)
	if typeof(index) ~= "number" then
		return
	end

	index = math.floor(index)
	local session = sessions[player]
	if not session or index < 1 or index > Config.Save.SlotCount then
		return
	end

	-- Only into an empty slot. Overwriting a run is a delete followed by a
	-- create, so it takes two deliberate actions.
	if session.slots[index] then
		return
	end

	session.slots[index] = blankProfile()
	session.dirty = true
	activate(player, index)
	persist(player)

	Remotes.event("SaveNotice"):FireClient(player, string.format("New game started in slot %d.", index))
end

local function onDelete(player: Player, index: any)
	if typeof(index) ~= "number" then
		return
	end

	index = math.floor(index)
	local session = sessions[player]
	if not session or not session.slots[index] then
		return
	end

	session.slots[index] = nil
	if session.slot == index then
		session.slot = nil
	end
	session.dirty = true
	persist(player)
	push(player)

	Remotes.event("SaveNotice"):FireClient(player, string.format("Slot %d erased.", index))
end

local function onSaveNow(player: Player)
	local session = sessions[player]
	if not session or not session.slot then
		return
	end

	capture(player)

	if session.offline then
		Remotes.event("SaveNotice"):FireClient(player, "Cannot save: data store unreachable.")
		return
	end

	local saved = persist(player)
	push(player)
	Remotes.event("SaveNotice")
		:FireClient(player, if saved then "Progress saved." else "Save failed, will retry.")
end

local function onPlayerAdded(player: Player)
	local slots, offline = load(player)

	sessions[player] = {
		slot = nil,
		slots = slots,
		dirty = false,
		offline = offline,
		joinedAt = os.clock(),
	}

	push(player)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session then
		return
	end

	if session.slot then
		capture(player)
		persist(player)
	end

	sessions[player] = nil
end

function SaveService:Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(onPlayerRemoving)

	Remotes.event("SelectSlot").OnServerEvent:Connect(onSelect)
	Remotes.event("CreateSlot").OnServerEvent:Connect(onCreate)
	Remotes.event("DeleteSlot").OnServerEvent:Connect(onDelete)
	Remotes.event("SaveNow").OnServerEvent:Connect(onSaveNow)

	-- Autosave: only slots that actually changed are written, so an idle
	-- player costs no requests.
	task.spawn(function()
		while true do
			task.wait(Config.Save.AutosaveInterval)

			for player, session in sessions do
				if session.slot and session.dirty and not session.offline then
					capture(player)
					task.spawn(persist, player)
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end

		for player, session in sessions do
			if session.slot then
				capture(player)
				task.spawn(persist, player)
			end
		end

		-- A moment for those writes to land before the server goes away.
		task.wait(3)
	end)

	print(string.format("[Save] ready, %d slots per player.", Config.Save.SlotCount))
end

return SaveService

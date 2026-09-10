--[[
	DataService
	DataStore uzerinde oturum kilitli (session locked) veri kalicilik katmani.

	- Oturum kilidi: ayni oyuncunun iki sunucuda ayni anda yuklenmesini ve
	  ilerlemenin ezilmesini engeller.
	- Reconcile: Config.DefaultProfile'a yeni alan ekledigin anda eski kayitlar
	  otomatik olarak tamamlanir.
	- Mock mod: Studio'da "Enable Studio Access to API Services" kapaliysa
	  veya DataStore erisilemezse oyun cokmez, bellek ici profille calisir.

	Tum yazma islemleri DataService:Update() uzerinden gecer; boylece tek bir
	noktadan ProfileChanged sinyali yayilir ve arayuz kendini gunceller.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)

local DataService = {}

DataService.ProfileAdded = Signal.new()
DataService.ProfileChanged = Signal.new()
DataService.ProfileRemoving = Signal.new()

local store = DataStoreService:GetDataStore(Config.Data.StoreName)
local sessionId = if game.JobId ~= "" then game.JobId else "studio-" .. tostring(os.time())

local profiles: { [Player]: any } = {}
local mocked: { [Player]: boolean } = {}
local releasing: { [Player]: boolean } = {}

local function keyFor(userId: number): string
	return "Player_" .. tostring(userId)
end

-- Kaydedilmis veriyi varsayilan sema ile hizalar: eksik alanlari doldurur,
-- tipi bozulmus veya artik kullanilmayan alanlari atar.
local function reconcile(saved: any)
	local profile = {}
	for key, default in Config.DefaultProfile do
		local value = if typeof(saved) == "table" then saved[key] else nil
		if typeof(value) == typeof(default) then
			profile[key] = value
		else
			profile[key] = default
		end
	end
	return profile
end

local function lockIsForeign(lock: any): boolean
	if typeof(lock) ~= "table" then
		return false
	end
	if lock.id == sessionId then
		return false
	end
	return os.time() - (tonumber(lock.time) or 0) < Config.Data.SessionLockTimeout
end

-- Kilidi alir ve profili dondurur. Kilit baska bir sunucudaysa nil doner.
local function acquire(userId: number)
	local key = keyFor(userId)

	for attempt = 1, Config.Data.LoadRetries do
		local success, result = pcall(function()
			return store:UpdateAsync(key, function(saved)
				if lockIsForeign(if typeof(saved) == "table" then saved.__session else nil) then
					-- nil dondurmek UpdateAsync'i iptal eder: veriye dokunmayiz.
					return nil
				end
				local payload = if typeof(saved) == "table" then saved else {}
				payload.__session = { id = sessionId, time = os.time() }
				return payload
			end)
		end)

		if success and result ~= nil then
			return reconcile(result)
		end

		if not success then
			warn(
				string.format(
					"[DataService] %d icin yukleme hatasi (deneme %d): %s",
					userId,
					attempt,
					tostring(result)
				)
			)
		end

		task.wait(Config.Data.RetryDelay * attempt)
	end

	return nil
end

-- releaseLock true ise kilit birakilir (oyuncu sunucudan ayrilirken).
local function persist(userId: number, profile: any, releaseLock: boolean): boolean
	local key = keyFor(userId)

	local success, err = pcall(function()
		store:UpdateAsync(key, function(saved)
			if lockIsForeign(if typeof(saved) == "table" then saved.__session else nil) then
				-- Kilidi kaybetmisiz; baskasinin verisinin uzerine yazma.
				return nil
			end
			local payload = table.clone(profile)
			payload.__session = if releaseLock then nil else { id = sessionId, time = os.time() }
			return payload
		end)
	end)

	if not success then
		warn(string.format("[DataService] %d icin kaydetme hatasi: %s", userId, tostring(err)))
	end

	return success
end

function DataService:Get(player: Player)
	return profiles[player]
end

--[[
	Profili guvenli sekilde degistirir.
	  DataService:Update(player, function(profile)
	      profile.Coins += 100
	  end)
	Degisiklik sonrasi ProfileChanged otomatik atesler.
]]
function DataService:Update(player: Player, mutator: (any) -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end

	mutator(profile)
	self.ProfileChanged:Fire(player, profile)
	return true
end

function DataService:Save(player: Player): boolean
	local profile = profiles[player]
	if not profile or mocked[player] then
		return false
	end
	return persist(player.UserId, profile, false)
end

local function onPlayerAdded(player: Player)
	local profile = acquire(player.UserId)

	if not player.Parent then
		-- Yukleme sirasinda cikmis.
		if profile then
			persist(player.UserId, profile, true)
		end
		return
	end

	if not profile then
		warn(
			string.format(
				"[DataService] %s icin veri kilidi alinamadi, gecici profil kullaniliyor.",
				player.Name
			)
		)
		profile = reconcile(nil)
		mocked[player] = true
	end

	profile.LastSeen = os.time()
	profiles[player] = profile

	DataService.ProfileAdded:Fire(player, profile)
	DataService.ProfileChanged:Fire(player, profile)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end

	releasing[player] = true
	DataService.ProfileRemoving:Fire(player, profile)

	profile.LastSeen = os.time()
	if not mocked[player] then
		persist(player.UserId, profile, true)
	end

	profiles[player] = nil
	mocked[player] = nil
	releasing[player] = nil
end

function DataService:Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Servis baslamadan once katilmis oyuncular (Studio'da sik olur).
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Otomatik kayit: hem veriyi yazar hem oturum kilidini tazeler.
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveInterval)
			for player, profile in profiles do
				if not mocked[player] and not releasing[player] then
					task.spawn(persist, player.UserId, profile, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		for player in profiles do
			task.spawn(onPlayerRemoving, player)
		end
		-- Bekleyen yazmalarin tamamlanmasi icin kisa pay.
		task.wait(3)
	end)
end

return DataService

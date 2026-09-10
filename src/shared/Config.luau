--!strict
--[[
	Config
	Oyunun tum ayarlanabilir degerleri burada. Denge (balance) degisikligi
	yapmak icin baska hicbir dosyaya dokunman gerekmez.
]]

local Config = {}

Config.Currency = {
	Name = "Coins",
	Symbol = "$",
}

Config.Data = {
	-- Canli oyuna cikmadan once bu ismi degistirirsen tum ilerleme sifirlanir.
	-- Veri semasini bozacak bir degisiklik yaparsan "_v2", "_v3" diye artir.
	StoreName = "PlayerData_v1",
	AutosaveInterval = 120,
	-- Bir oturum kilidinin "olu" sayilmasi icin gecmesi gereken sure (saniye).
	SessionLockTimeout = 1800,
	LoadRetries = 5,
	RetryDelay = 2,
}

Config.Collect = {
	-- Sunucunun kabul ettigi minimum toplama araligi. Client bunun altina inerse
	-- istek sessizce dusurulur (basit anti-exploit).
	Cooldown = 0.35,
	-- Toplama alani sinir kontrolunde tolerans (stud). Lag payi.
	ZonePadding = 8,
}

Config.Sell = {
	-- Satis padine ard arda degmelerde bekleme suresi.
	Debounce = 0.5,
}

Config.World = {
	-- true ise sunucu, sahnede hic yoksa placeholder baseplate/spawn/alan olusturur.
	-- Kendi haritani yaptiginda parcalari CollectionService ile etiketle ve
	-- bu degeri false yapabilirsin.
	CreatePlaceholders = true,
	CollectZoneTag = "CollectZone",
	SellPadTag = "SellPad",
}

-- Toplama araclari. Power = her toplama vurusunda kazanilan kaynak.
-- Color: ServerStorage'da model yoksa uretilen placeholder'in baslik rengi.
-- Model (istege bagli): ServerStorage/ToolModels icindeki Tool'un adi.
-- Yazmazsan Name ile aranir.
Config.Tools = {
	{ Name = "Rusty Pickaxe", Price = 0, Power = 1, Color = Color3.fromRGB(140, 105, 85) },
	{ Name = "Iron Pickaxe", Price = 150, Power = 3, Color = Color3.fromRGB(170, 175, 180) },
	{ Name = "Steel Drill", Price = 900, Power = 8, Color = Color3.fromRGB(120, 130, 145) },
	{ Name = "Gold Drill", Price = 5_000, Power = 20, Color = Color3.fromRGB(226, 182, 62) },
	{ Name = "Diamond Drill", Price = 28_000, Power = 55, Color = Color3.fromRGB(120, 220, 232) },
	{ Name = "Plasma Cutter", Price = 160_000, Power = 150, Color = Color3.fromRGB(236, 96, 160) },
	{ Name = "Quantum Ripper", Price = 950_000, Power = 420, Color = Color3.fromRGB(150, 110, 255) },
}

Config.ToolVisual = {
	-- Kendi Tool modellerini buraya koy: ServerStorage/ToolModels/<arac adi>
	FolderName = "ToolModels",
	-- Model bulunamazsa sunucu basit bir kazma uretsin mi?
	-- Tum araclarin kendi modeli varsa false yapabilirsin.
	CreatePlaceholders = true,
	-- Sadece placeholder icin: aracin elde durus acisi.
	PlaceholderGrip = CFrame.Angles(0, math.rad(90), math.rad(-20)),
}

-- Sirt cantalari. Capacity = satmadan once tasinabilecek maksimum kaynak.
Config.Backpacks = {
	{ Name = "Starter Bag", Price = 0, Capacity = 25 },
	{ Name = "Leather Bag", Price = 100, Capacity = 75 },
	{ Name = "Reinforced Pack", Price = 750, Capacity = 250 },
	{ Name = "Alloy Crate", Price = 4_500, Capacity = 900 },
	{ Name = "Void Satchel", Price = 30_000, Capacity = 3_500 },
	{ Name = "Singularity Vault", Price = 220_000, Capacity = 15_000 },
}

Config.Rebirth = {
	BaseCost = 25_000,
	CostMultiplier = 3.5,
	-- Her rebirth satis gelirine +%50 ekler.
	EarningsBonusPerRebirth = 0.5,
	MaxRebirths = 100,
}

-- Yeni oyuncunun baslangic verisi. Buraya alan ekleyince eski kayitlar
-- otomatik olarak bu varsayilanla tamamlanir (bkz. DataService reconcile).
Config.DefaultProfile = {
	Version = 1,
	Coins = 0,
	Backpack = 0,
	Rebirths = 0,
	ToolIndex = 1,
	BackpackIndex = 1,
	TotalCollected = 0,
	LastSeen = 0,
}

return Config

--[[
	Server bootstrap
	Servisleri sabit bir sirayla baslatir. Sira onemli:
	veriye bagli servisler DataService'ten, dunyaya bagli olanlar
	WorldService'ten sonra gelmeli.

	Yeni bir servis eklemek icin: src/server/ altina ModuleScript koy,
	icine :Start() metodu yaz ve asagidaki listeye ekle.
]]

local SERVICES = {
	"DataService",
	"EconomyService",
	"WorldService",
	"NetworkService",
	"LeaderstatsService",
	"ToolVisualService",
	"BirdService",
	"CollectService",
	"ShopService",
	"RebirthService",
}

local startedAt = os.clock()

for _, name in SERVICES do
	local module = script:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then
		warn(string.format("[Server] '%s' servisi bulunamadi, atlaniyor.", name))
		continue
	end

	local service = require(module)
	if typeof(service) == "table" and typeof(service.Start) == "function" then
		local success, err = pcall(function()
			service:Start()
		end)
		if not success then
			warn(string.format("[Server] '%s' baslatilamadi: %s", name, tostring(err)))
		end
	end
end

print(string.format("[Server] %d servis %.0f ms icinde hazir.", #SERVICES, (os.clock() - startedAt) * 1000))

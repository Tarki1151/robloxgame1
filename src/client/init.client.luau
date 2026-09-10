--[[
	Client bootstrap
	Kontrolcüleri sabit sirayla baslatir. StateController once gelmeli:
	digerleri onun tuttugu duruma baglanir.
]]

local CONTROLLERS = {
	"StateController",
	"HudController",
	"ShopController",
	"CollectController",
}

for _, name in CONTROLLERS do
	local module = script:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then
		warn(string.format("[Client] '%s' kontrolcusu bulunamadi, atlaniyor.", name))
		continue
	end

	local controller = require(module)
	if typeof(controller) == "table" and typeof(controller.Start) == "function" then
		local success, err = pcall(function()
			controller:Start()
		end)
		if not success then
			warn(string.format("[Client] '%s' baslatilamadi: %s", name, tostring(err)))
		end
	end
end

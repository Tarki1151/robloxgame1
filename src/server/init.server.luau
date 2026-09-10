--[[
	Server bootstrap
	Starts services in a fixed order. AvatarService builds the character;
	PoseService poses it, so it must come second.

	To add a service: drop a ModuleScript with a :Start() method into
	src/server/ and add its name to the list below.
]]

local SERVICES = {
	"AvatarService",
	"PoseService",
}

for _, name in SERVICES do
	local module = script:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then
		warn(string.format("[Server] service '%s' not found, skipping.", name))
		continue
	end

	-- require() is wrapped too, not just Start(). A module that throws while
	-- loading (a service calling DataStoreService at module scope in Studio,
	-- say) would otherwise kill this whole loop and leave every later service
	-- unstarted, with no obvious sign beyond one red line.
	local loaded, service = pcall(require, module)
	if not loaded then
		warn(string.format("[Server] '%s' failed to load: %s", name, tostring(service)))
		continue
	end

	if typeof(service) == "table" and typeof(service.Start) == "function" then
		local success, err = pcall(function()
			service:Start()
		end)
		if not success then
			warn(string.format("[Server] '%s' failed to start: %s", name, tostring(err)))
		end
	end
end

print(string.format("[Server] %d services ready.", #SERVICES))

--[[
	Server bootstrap.
	Empty on purpose: services get required and started from here.

	require() is wrapped as well as Start(), so a module that throws while
	loading warns and is skipped instead of taking the whole server down.
]]

local SERVICES = {
	"GroundService",
	"WorldService",
}

for _, name in SERVICES do
	local module = script:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then
		warn(string.format("[Server] service '%s' not found, skipping.", name))
		continue
	end

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

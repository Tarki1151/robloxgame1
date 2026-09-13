--[[
	Client bootstrap.
	Empty on purpose: controllers get required and started from here.
]]

local CONTROLLERS = {}

for _, name in CONTROLLERS do
	local module = script:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then
		warn(string.format("[Client] controller '%s' not found, skipping.", name))
		continue
	end

	local loaded, controller = pcall(require, module)
	if not loaded then
		warn(string.format("[Client] '%s' failed to load: %s", name, tostring(controller)))
		continue
	end

	if typeof(controller) == "table" and typeof(controller.Start) == "function" then
		local success, err = pcall(function()
			controller:Start()
		end)
		if not success then
			warn(string.format("[Client] '%s' failed to start: %s", name, tostring(err)))
		end
	end
end

print(string.format("[Client] %d controllers ready.", #CONTROLLERS))

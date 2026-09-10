--[[
	ImpactController
	Camera kick and a damage flash when something hits you.

	Screen shake has to be client-side: it is a camera effect, and the camera
	only exists here. The server just says "you were hit"; how that feels is
	decided locally.

	The shake is applied to the camera's CFrame after Roblox has positioned it,
	which is what RenderStepped's Camera priority is for - do it earlier and
	the camera controller overwrites it in the same frame.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local ImpactController = {}

local player = Players.LocalPlayer

-- Current shake strength, decaying toward zero every frame.
local trauma = 0

local function flash(gui: ScreenGui)
	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Config.Ui.HealthLow
	overlay.BackgroundTransparency = 0.55
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 10
	overlay.Parent = gui

	local tween = TweenService:Create(overlay, TweenInfo.new(0.45), { BackgroundTransparency = 1 })
	tween.Completed:Connect(function()
		overlay:Destroy()
	end)
	tween:Play()
end

function ImpactController:Start()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ImpactHud"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = player:WaitForChild("PlayerGui")

	Remotes.event("Hit").OnClientEvent:Connect(function(kind)
		if kind == "landed" then
			-- Your own hit landing: a small kick, no red screen.
			trauma = math.min(trauma + 0.35, 1)
			return
		end

		trauma = 1
		flash(screenGui)
	end)

	RunService:BindToRenderStep("ImpactShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if trauma <= 0 then
			return
		end

		trauma = math.max(trauma - dt * Config.Vfx.ShakeDecay, 0)

		local camera = workspace.CurrentCamera
		if not camera then
			return
		end

		-- Squared falloff: the shake dies off sharply rather than lingering.
		local strength = trauma * trauma * Config.Vfx.ShakeMagnitude
		local offset = Vector3.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)

		camera.CFrame = camera.CFrame
			* CFrame.new(offset)
			* CFrame.Angles(0, 0, (math.random() - 0.5) * strength * 0.05)
	end)
end

return ImpactController

--[[
	HealthController
	The player's own health bar.

	Reads Humanoid.Health directly rather than waiting on a remote: your own
	health already replicates to you, so no server round trip is needed.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local HealthController = {}

local player = Players.LocalPlayer

local function build(): (Frame, TextLabel)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HealthHud"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = Config.Ui.BarSize
	-- Anchored to the bottom left, above the default chat and backpack.
	track.AnchorPoint = Vector2.new(0, 1)
	track.Position = UDim2.new(0, 20, 1, -20) + Config.Ui.BarOffset
	track.BackgroundColor3 = Config.Ui.Background
	track.BorderSizePixel = 0
	track.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Config.Ui.HealthHigh
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	local label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Config.Ui.Text
	label.TextStrokeTransparency = 0.5
	label.Text = ""
	label.Parent = track

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = label

	return fill, label
end

function HealthController:Start()
	local fill, label = build()

	local function watch(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") then
			return
		end

		local function refresh()
			local ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
			-- Tweened so chip damage reads as a movement, not a jump.
			TweenService:Create(fill, TweenInfo.new(0.2), {
				Size = UDim2.fromScale(ratio, 1),
				BackgroundColor3 = Config.Ui.HealthLow:Lerp(Config.Ui.HealthHigh, ratio),
			}):Play()

			label.Text = string.format("%d / %d", math.ceil(humanoid.Health), humanoid.MaxHealth)
		end

		humanoid.HealthChanged:Connect(refresh)
		humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(refresh)
		refresh()
	end

	player.CharacterAdded:Connect(watch)
	if player.Character then
		watch(player.Character)
	end
end

return HealthController

--[[
	TutorialController
	Walks a new player from spawn to the castle and the sword on its pedestal.

	Steps are checked on the client. Distance to a point is something the
	client already knows every frame, so asking the server would be a round
	trip to learn what is on screen in front of you. The one exception is
	taking the sword, which only the server can confirm - it says so over the
	SwordTaken remote.

	A step is a row in the list below: a title, a hint, and either a position
	to reach or a remote to wait for.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local TutorialController = {}

local player = Players.LocalPlayer

type Step = {
	title: string,
	hint: string,
	-- Reached by walking here, or nil when the server decides.
	target: Vector3?,
}

local castleOrigin = Config.Castle.Direction.Unit * Config.Castle.Distance

local STEPS: { Step } = {
	{
		title = "Hold Shift to run",
		hint = "Follow the stone path. Let go and you slow to a walk.",
		target = Config.Castle.Direction.Unit * (Config.Path.StartOffset + 40),
	},
	{
		title = "Head for the castle",
		hint = "The sign points the way. Keep to the path.",
		target = castleOrigin + Vector3.new(0, 0, Config.Castle.Width / 2 + 10),
	},
	{
		title = "Go through the gate",
		hint = "Into the courtyard.",
		target = castleOrigin,
	},
	{
		title = "Take the sword",
		hint = "It stands on a pedestal. Hold E to pick it up.",
		-- No target: the server confirms this one.
		target = nil,
	},
}

local index = 1
local finished = false

local function rootPosition(): Vector3?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function build(): (Frame, TextLabel, TextLabel, Frame)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Tutorial"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 420, 0, 88)
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 24)
	panel.BackgroundColor3 = Config.Tutorial.PanelColor
	panel.BackgroundTransparency = 0.1
	panel.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Config.Tutorial.AccentColor
	stroke.Thickness = 1.5
	stroke.Transparency = 0.4
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -28, 0, 30)
	title.Position = UDim2.new(0, 14, 0, 12)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Config.Tutorial.TextColor
	title.Text = ""
	title.Parent = panel

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, -28, 0, 20)
	hint.Position = UDim2.new(0, 14, 0, 42)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 13
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextTruncate = Enum.TextTruncate.AtEnd
	hint.TextColor3 = Config.Tutorial.MutedColor
	hint.Text = ""
	hint.Parent = panel

	-- Progress bar along the bottom edge.
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, -28, 0, 4)
	track.Position = UDim2.new(0, 14, 1, -14)
	track.BackgroundColor3 = Config.Tutorial.MutedColor
	track.BackgroundTransparency = 0.7
	track.BorderSizePixel = 0
	track.Parent = panel

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Config.Tutorial.AccentColor
	fill.BorderSizePixel = 0
	fill.Parent = track

	return panel, title, hint, fill
end

function TutorialController:Start()
	if not Config.Tutorial.Enabled then
		return
	end

	local panel, title, hint, fill = build()

	local function show(step: Step)
		title.Text = string.format("%d/%d  %s", index, #STEPS, step.title)
		hint.Text = step.hint

		TweenService:Create(fill, TweenInfo.new(0.3), {
			Size = UDim2.fromScale((index - 1) / #STEPS, 1),
		}):Play()
	end

	local function finish()
		finished = true
		title.Text = "Ready."
		hint.Text = "The cave to the west is still barred."
		TweenService:Create(fill, TweenInfo.new(0.3), { Size = UDim2.fromScale(1, 1) }):Play()

		task.delay(Config.Tutorial.FinishLinger, function()
			local fade = TweenService:Create(panel, TweenInfo.new(0.6), {
				BackgroundTransparency = 1,
			})
			fade:Play()
			fade.Completed:Wait()
			panel:Destroy()
		end)
	end

	local function advance()
		index += 1
		if index > #STEPS then
			finish()
		else
			show(STEPS[index])
		end
	end

	show(STEPS[index])

	-- The final step is the server's to confirm.
	Remotes.event("SwordTaken").OnClientEvent:Connect(function()
		if not finished and index == #STEPS then
			advance()
		end
	end)

	RunService.Heartbeat:Connect(function()
		if finished then
			return
		end

		local step = STEPS[index]
		if not step or not step.target then
			return
		end

		local position = rootPosition()
		if not position then
			return
		end

		-- Flat distance: standing on the wall above the target still counts.
		local delta = (position - step.target) * Vector3.new(1, 0, 1)
		if delta.Magnitude <= Config.Tutorial.ArriveDistance then
			advance()
		end
	end)
end

return TutorialController

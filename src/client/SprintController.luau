--[[
	SprintController
	Hold Shift to run at double speed; let go and you drop back to walking.

	Speed is set on the client rather than asked of the server. Your own
	character is simulated locally, so a server round trip would put a visible
	delay on every press and release. The tradeoff is that a modified client
	could set any speed it likes - fine here, and the thing to change first if
	this ever becomes competitive.

	Bound through ContextActionService rather than UserInputService so the
	binding is named, is easy to remove, and gets a button on touch devices
	for free.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local SprintController = {}

local ACTION_NAME = "Sprint"

local player = Players.LocalPlayer
local humanoid: Humanoid? = nil
local sprinting = false

local function walkSpeed(): number
	return Config.Player.WalkSpeed
end

local function sprintSpeed(): number
	return Config.Player.WalkSpeed * Config.Player.SprintMultiplier
end

local function onAction(_name: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		sprinting = true
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		sprinting = false
	end

	return Enum.ContextActionResult.Pass
end

--[[
	Eased rather than snapped.

	Setting WalkSpeed straight to double looks like a teleport, and dropping it
	straight back looks like hitting a wall. Moving toward the target a little
	each frame gives it weight without any animation work.
]]
local function step(deltaTime: number)
	local character = player.Character
	if not humanoid or not humanoid.Parent or (character and humanoid.Parent ~= character) then
		humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	end

	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local target = if sprinting then sprintSpeed() else walkSpeed()
	local alpha = math.min(deltaTime / Config.Player.SprintRamp, 1)

	humanoid.WalkSpeed += (target - humanoid.WalkSpeed) * alpha
end

function SprintController:Start()
	ContextActionService:BindAction(
		ACTION_NAME,
		onAction,
		true, -- give touch devices a button
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.RightShift,
		Enum.KeyCode.ButtonL3
	)
	ContextActionService:SetTitle(ACTION_NAME, "RUN")

	-- Releasing Shift while the window is unfocused would otherwise leave you
	-- sprinting forever, since the key-up never arrives.
	player.Idled:Connect(function()
		sprinting = false
	end)

	RunService.RenderStepped:Connect(step)
end

return SprintController

--[[
	CollectController
	Girdi katmani. Basili tutunca surekli ates eder; hedefi ve kazanci client
	hesaplamaz, sadece sunucuya "ates ettim" sinyali gonderir.

	Masaustu: sol tik. Mobil: ekrana dokunma. Konsol: ButtonR2.
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local CollectController = {}

local ACTION_NAME = "SimulatorCollect"

local collectRemote = Remotes.event("Collect")
local holding = false
local lastSent = 0

local function tick()
	if not holding then
		return
	end

	local now = os.clock()
	if now - lastSent < Config.Collect.Cooldown then
		return
	end

	lastSent = now
	collectRemote:FireServer()
end

local function onAction(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		holding = true
		-- Ilk vurus aninda hissedilsin diye beklemeden gonder.
		lastSent = 0
		tick()
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		holding = false
	end

	return Enum.ContextActionResult.Pass
end

function CollectController:Start()
	ContextActionService:BindAction(
		ACTION_NAME,
		onAction,
		true, -- mobilde dokunma butonu olustur
		Enum.UserInputType.MouseButton1,
		Enum.UserInputType.Touch,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:SetTitle(ACTION_NAME, "ATES")

	RunService.Heartbeat:Connect(tick)
end

return CollectController

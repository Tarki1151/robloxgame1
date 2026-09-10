--[[
	HudController
	Sol ustte para/canta/carpan gostergesi, altta buton cubugu ve
	sag ustte kisa bildirim baloncuklari.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local Create = require(script.Parent.Create)
local StateController = require(script.Parent.StateController)
local Theme = require(script.Parent.Theme)

local HudController = {}

-- ShopController bu sinyali dinleyip panelini acar/kapatir.
HudController.ShopToggled = Signal.new()

local player = Players.LocalPlayer
local labels = {}
local notificationHolder: Frame

-- Etiket satiri olusturur; (satir, deger etiketi) doner.
local function statRow(name: string, order: number)
	local row = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	})

	Create("TextLabel", {
		Name = "Title",
		Size = UDim2.fromScale(0.45, 1),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = name,
		TextSize = 15,
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local value = Create("TextLabel", {
		Name = "Value",
		Size = UDim2.fromScale(0.55, 1),
		Position = UDim2.fromScale(0.45, 0),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = "0",
		TextSize = 16,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})

	return row, value
end

local function button(text: string, color: Color3, order: number, onClick: () -> ()): TextButton
	local instance = Create("TextButton", {
		Size = UDim2.new(0, 130, 0, 42),
		BackgroundColor3 = color,
		AutoButtonColor = true,
		BorderSizePixel = 0,
		Font = Theme.FontBold,
		Text = text,
		TextSize = 16,
		TextColor3 = Theme.Text,
		LayoutOrder = order,
	}, {
		Create("UICorner", { CornerRadius = Theme.Corner }),
	})

	instance.Activated:Connect(onClick)
	return instance
end

local function notify(message: string, kind: string?)
	if not notificationHolder then
		return
	end

	local color = Theme.Info
	if kind == "success" then
		color = Theme.Success
	elseif kind == "error" then
		color = Theme.Error
	end

	local toast = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Font = Theme.FontBold,
		Text = message,
		TextSize = 15,
		TextColor3 = Theme.Text,
		Parent = notificationHolder,
	}, {
		Create("UICorner", { CornerRadius = Theme.Corner }),
	})

	task.delay(2, function()
		local tween = TweenService:Create(toast, TweenInfo.new(0.4), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		})
		tween.Completed:Connect(function()
			toast:Destroy()
		end)
		tween:Play()
	end)
end

local function render()
	local state = StateController:Get()

	labels.Coins.Text = Format.money(state.Coins)
	labels.Backpack.Text =
		string.format("%s / %s", Format.abbreviate(state.Backpack), Format.abbreviate(state.Capacity))
	labels.Multiplier.Text = string.format("x%.1f", state.Multiplier)
	labels.Rebirths.Text = tostring(state.Rebirths)

	labels.Backpack.TextColor3 = if state.Capacity > 0 and state.Backpack >= state.Capacity
		then Theme.Error
		else Theme.Text

	labels.RebirthButton.Text = "REBIRTH " .. Format.money(state.RebirthCost)
	labels.RebirthButton.BackgroundColor3 = if state.CanRebirth then Theme.Accent else Theme.SurfaceAlt
end

function HudController:Start()
	local screenGui = Create("ScreenGui", {
		Name = "SimulatorHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Sol ust: istatistik paneli
	local panel = Create("Frame", {
		Name = "Stats",
		Size = UDim2.new(0, 240, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 16, 0, 16),
		BackgroundColor3 = Theme.Surface,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Parent = screenGui,
	}, {
		Create("UICorner", { CornerRadius = Theme.Corner }),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
		}),
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
	})

	local coinsRow, coinsValue = statRow(Config.Currency.Name, 1)
	local backpackRow, backpackValue = statRow("Canta", 2)
	local multiplierRow, multiplierValue = statRow("Carpan", 3)
	local rebirthRow, rebirthValue = statRow("Rebirth", 4)

	coinsRow.Parent = panel
	backpackRow.Parent = panel
	multiplierRow.Parent = panel
	rebirthRow.Parent = panel

	labels.Coins = coinsValue
	labels.Backpack = backpackValue
	labels.Multiplier = multiplierValue
	labels.Rebirths = rebirthValue

	-- Sol alt: butonlar
	local bar = Create("Frame", {
		Name = "Buttons",
		Size = UDim2.new(0, 280, 0, 42),
		Position = UDim2.new(0, 16, 1, -58),
		BackgroundTransparency = 1,
		Parent = screenGui,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		}),
	})

	button("MAGAZA", Theme.SurfaceAlt, 1, function()
		HudController.ShopToggled:Fire()
	end).Parent = bar

	local rebirthButton = button("REBIRTH", Theme.SurfaceAlt, 2, function()
		Remotes.event("Rebirth"):FireServer()
	end)
	rebirthButton.Size = UDim2.new(0, 150, 0, 42)
	rebirthButton.Parent = bar
	labels.RebirthButton = rebirthButton

	-- Sag ust: bildirimler
	notificationHolder = Create("Frame", {
		Name = "Notifications",
		Size = UDim2.new(0, 260, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(1, -276, 0, 16),
		BackgroundTransparency = 1,
		Parent = screenGui,
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 6),
		}),
	})

	StateController.Changed:Connect(render)
	Remotes.event("Notify").OnClientEvent:Connect(notify)

	render()
end

return HudController

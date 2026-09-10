--[[
	ShopController
	The CRAFT button, the forge panel, and the ember counter.

	Tiles reflect what the server says you own and can afford. Clicking one
	sends an index and nothing else - the server decides whether anything
	happens, so the worst a tampered client can do is ask.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local ShopController = {}

local player = Players.LocalPlayer

local QUICK = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- What the server last told us. The panel is redrawn from this, never from
-- anything the client decides on its own.
local embers = 0
local owned: { [number]: boolean } = {}
local equipped = 1

local function corner(parent: Instance, radius: number)
	local instance = Instance.new("UICorner")
	instance.CornerRadius = UDim.new(0, radius)
	instance.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local instance = Instance.new("UIStroke")
	instance.Color = color
	instance.Thickness = thickness
	instance.Parent = parent
	return instance
end

local function abbreviate(value: number): string
	if value >= 1000 then
		return string.format("%.10g K", math.floor(value / 100) / 10)
	end
	return tostring(math.floor(value))
end

function ShopController:Start()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ForgeMenu"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = player:WaitForChild("PlayerGui")

	-- Ember counter, top right.
	local counter = Instance.new("TextLabel")
	counter.Name = "Embers"
	counter.Size = UDim2.new(0, 190, 0, 40)
	counter.AnchorPoint = Vector2.new(1, 0)
	counter.Position = UDim2.new(1, -20, 0, 20)
	counter.BackgroundColor3 = Config.Ui.Panel
	counter.Font = Enum.Font.GothamBold
	counter.TextSize = 18
	counter.TextColor3 = Config.Ui.Accent
	counter.Text = "0 Embers"
	counter.Parent = screenGui
	corner(counter, 10)
	stroke(counter, Config.Ui.PanelEdge, 1)

	-- CRAFT button, sitting to the left of FIGHT BEAST.
	local button = Instance.new("TextButton")
	button.Name = "Craft"
	button.Size = UDim2.new(0, 150, 0, 58)
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(0.5, -142, 1, -28)
	button.BackgroundColor3 = Config.Ui.Panel
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBlack
	button.Text = "CRAFT"
	button.TextSize = 20
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Parent = screenGui
	corner(button, 12)
	stroke(button, Config.Ui.Accent, 1.5)

	button.MouseEnter:Connect(function()
		TweenService:Create(button, QUICK, { Size = UDim2.new(0, 162, 0, 62) }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, QUICK, { Size = UDim2.new(0, 150, 0, 58) }):Play()
	end)

	-- Panel.
	local panel = Instance.new("Frame")
	panel.Name = "Forge"
	panel.Size = UDim2.new(0, 640, 0, 460)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundColor3 = Config.Ui.Panel
	panel.Visible = false
	panel.Parent = screenGui
	corner(panel, 16)
	stroke(panel, Config.Ui.PanelEdge, 1.5)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -32, 0, 44)
	title.Position = UDim2.new(0, 16, 0, 14)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 26
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "FORGE"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = panel

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, -32, 0, 20)
	subtitle.Position = UDim2.new(0, 16, 0, 54)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextSize = 14
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Text = "Kill beasts to earn embers. Craft a weapon to equip it."
	subtitle.TextColor3 = Config.Ui.Muted
	subtitle.Parent = panel

	local close = Instance.new("TextButton")
	close.Size = UDim2.new(0, 36, 0, 36)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -16, 0, 16)
	close.BackgroundColor3 = Config.Ui.PanelEdge
	close.Font = Enum.Font.GothamBold
	close.Text = "X"
	close.TextSize = 18
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Parent = panel
	corner(close, 10)
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -32, 1, -104)
	list.Position = UDim2.new(0, 16, 0, 86)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = Config.Ui.Accent
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	-- One row per weapon, plus the closure that repaints it.
	local refreshers: { () -> () } = {}

	for index, weapon in Config.Weapons do
		local row = Instance.new("Frame")
		row.Name = string.format("Weapon%02d", index)
		row.LayoutOrder = index
		row.Size = UDim2.new(1, -8, 0, 66)
		row.BackgroundColor3 = Config.Ui.Panel:Lerp(Color3.new(1, 1, 1), 0.06)
		row.Parent = list
		corner(row, 10)
		local edge = stroke(row, Config.Ui.PanelEdge, 1)

		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.new(0, 6, 1, -20)
		swatch.Position = UDim2.new(0, 12, 0, 10)
		swatch.BackgroundColor3 = weapon.BladeColor
		swatch.BorderSizePixel = 0
		swatch.Parent = row
		corner(swatch, 3)

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -200, 0, 22)
		name.Position = UDim2.new(0, 30, 0, 12)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBold
		name.TextSize = 16
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = weapon.Name
		name.TextColor3 = Color3.new(1, 1, 1)
		name.Parent = row

		local stats = Instance.new("TextLabel")
		stats.Size = UDim2.new(1, -200, 0, 18)
		stats.Position = UDim2.new(0, 30, 0, 34)
		stats.BackgroundTransparency = 1
		stats.Font = Enum.Font.Gotham
		stats.TextSize = 13
		stats.TextXAlignment = Enum.TextXAlignment.Left
		stats.Text = string.format("%d damage  -  %.1f reach", weapon.Damage, weapon.Reach)
		stats.TextColor3 = Config.Ui.Muted
		stats.Parent = row

		local action = Instance.new("TextButton")
		action.Size = UDim2.new(0, 140, 0, 38)
		action.AnchorPoint = Vector2.new(1, 0.5)
		action.Position = UDim2.new(1, -14, 0.5, 0)
		action.BackgroundColor3 = Config.Ui.Accent
		action.AutoButtonColor = false
		action.Font = Enum.Font.GothamBold
		action.TextSize = 14
		action.TextColor3 = Color3.new(1, 1, 1)
		action.Parent = row
		corner(action, 8)

		action.Activated:Connect(function()
			if owned[index] then
				Remotes.event("EquipWeapon"):FireServer(index)
			else
				Remotes.event("CraftWeapon"):FireServer(index)
			end
		end)

		table.insert(refreshers, function()
			if equipped == index then
				action.Text = "EQUIPPED"
				action.BackgroundColor3 = Config.Ui.Owned
				edge.Color = Config.Ui.Owned
			elseif owned[index] then
				action.Text = "EQUIP"
				action.BackgroundColor3 = Config.Ui.PanelEdge
				edge.Color = Config.Ui.PanelEdge
			elseif embers >= weapon.Cost then
				action.Text = string.format("CRAFT  %s", abbreviate(weapon.Cost))
				action.BackgroundColor3 = Config.Ui.Accent
				edge.Color = Config.Ui.Accent
			else
				action.Text = string.format("%s EMBERS", abbreviate(weapon.Cost))
				action.BackgroundColor3 = Config.Ui.Panel
				edge.Color = Config.Ui.Locked
			end
		end)
	end

	local function refresh()
		counter.Text = string.format("%s %s", abbreviate(embers), Config.Craft.CurrencyName)
		for _, refresher in refreshers do
			refresher()
		end
	end

	button.Activated:Connect(function()
		panel.Visible = not panel.Visible
		refresh()
	end)

	Remotes.event("WalletChanged").OnClientEvent:Connect(function(newEmbers, ownedList, newEquipped)
		embers = newEmbers
		equipped = newEquipped

		table.clear(owned)
		for _, index in ownedList do
			owned[index] = true
		end

		refresh()
	end)

	refresh()
end

return ShopController

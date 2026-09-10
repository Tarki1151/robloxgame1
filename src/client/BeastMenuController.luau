--[[
	BeastMenuController
	The FIGHT BEAST button and the roster it opens.

	The menu is a grid of twenty tiles, one per beast, showing its number,
	name and health. Picking one asks the server to swap the beast in; the
	client never spawns anything itself, it only sends the index.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local BeastMenuController = {}

local player = Players.LocalPlayer

local QUICK = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function corner(parent: Instance, radius: number)
	local instance = Instance.new("UICorner")
	instance.CornerRadius = UDim.new(0, radius)
	instance.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local instance = Instance.new("UIStroke")
	instance.Color = color
	instance.Thickness = thickness
	instance.Parent = parent
	return instance
end

-- Shortens 15000 to "15K" so the tiles stay readable.
local function abbreviate(value: number): string
	if value >= 1000 then
		return string.format("%.10g K", value / 1000)
	end
	return tostring(value)
end

local function buildButton(parent: ScreenGui): TextButton
	local button = Instance.new("TextButton")
	button.Name = "FightBeast"
	button.Size = UDim2.new(0, 260, 0, 58)
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -28)
	button.BackgroundColor3 = Config.Ui.Accent
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBlack
	button.Text = "FIGHT BEAST"
	button.TextSize = 24
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Parent = parent

	corner(button, 12)
	stroke(button, Color3.new(1, 1, 1), 1.5).Transparency = 0.7

	-- Hot core at the bottom, so the button looks lit from underneath.
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Config.Ui.Accent, Config.Ui.AccentDeep)
	gradient.Rotation = 90
	gradient.Parent = button

	local glow = Instance.new("UIStroke")
	glow.Color = Config.Ui.Accent
	glow.Thickness = 3
	glow.Transparency = 0.55
	glow.Parent = button

	-- The button breathes so it reads as the thing to press.
	task.spawn(function()
		while button.Parent do
			TweenService:Create(glow, TweenInfo.new(1.1), { Transparency = 0.15 }):Play()
			task.wait(1.1)
			TweenService:Create(glow, TweenInfo.new(1.1), { Transparency = 0.6 }):Play()
			task.wait(1.1)
		end
	end)

	button.MouseEnter:Connect(function()
		TweenService:Create(button, QUICK, { Size = UDim2.new(0, 276, 0, 62) }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, QUICK, { Size = UDim2.new(0, 260, 0, 58) }):Play()
	end)

	return button
end

local function buildPanel(parent: ScreenGui): (Frame, ScrollingFrame, TextLabel)
	local panel = Instance.new("Frame")
	panel.Name = "Roster"
	panel.Size = UDim2.new(0, 720, 0, 460)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundColor3 = Config.Ui.Panel
	panel.Visible = false
	panel.Parent = parent

	corner(panel, 16)
	stroke(panel, Config.Ui.PanelEdge, 1.5)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -32, 0, 44)
	title.Position = UDim2.new(0, 16, 0, 14)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 26
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "CHOOSE YOUR BEAST"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = panel

	local current = Instance.new("TextLabel")
	current.Name = "Current"
	current.Size = UDim2.new(1, -32, 0, 20)
	current.Position = UDim2.new(0, 16, 0, 54)
	current.BackgroundTransparency = 1
	current.Font = Enum.Font.Gotham
	current.TextSize = 14
	current.TextXAlignment = Enum.TextXAlignment.Left
	current.Text = ""
	current.TextColor3 = Config.Ui.Muted
	current.Parent = panel

	local close = Instance.new("TextButton")
	close.Name = "Close"
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

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.Size = UDim2.new(1, -32, 1, -104)
	grid.Position = UDim2.new(0, 16, 0, 86)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 4
	grid.ScrollBarImageColor3 = Config.Ui.Accent
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.Parent = panel

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / Config.Ui.Columns, -8, 0, Config.Ui.TileHeight)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	return panel, grid, current
end

local function buildTile(index: number, beast, grid: ScrollingFrame): TextButton
	local tile = Instance.new("TextButton")
	tile.Name = string.format("Beast%02d", index)
	tile.LayoutOrder = index
	tile.BackgroundColor3 = Config.Ui.Panel:Lerp(Color3.new(1, 1, 1), 0.06)
	tile.AutoButtonColor = false
	tile.Text = ""
	tile.Parent = grid

	corner(tile, 10)
	local edge = stroke(tile, Config.Ui.PanelEdge, 1)

	local number = Instance.new("TextLabel")
	number.Size = UDim2.new(1, -12, 0, 26)
	number.Position = UDim2.new(0, 8, 0, 6)
	number.BackgroundTransparency = 1
	number.Font = Enum.Font.GothamBlack
	number.TextSize = 22
	number.TextXAlignment = Enum.TextXAlignment.Left
	number.Text = tostring(index)
	number.TextColor3 = beast.FlameColor
	number.Parent = tile

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -12, 0, 18)
	name.Position = UDim2.new(0, 8, 0, 30)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 13
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Text = beast.Name
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Parent = tile

	local health = Instance.new("TextLabel")
	health.Size = UDim2.new(1, -12, 0, 16)
	health.Position = UDim2.new(0, 8, 0, 50)
	health.BackgroundTransparency = 1
	health.Font = Enum.Font.Gotham
	health.TextSize = 12
	health.TextXAlignment = Enum.TextXAlignment.Left
	health.Text = string.format("%s HP  -  %d dmg", abbreviate(beast.MaxHealth), beast.Damage)
	health.TextColor3 = Config.Ui.Muted
	health.Parent = tile

	tile.MouseEnter:Connect(function()
		TweenService:Create(edge, QUICK, { Color = beast.FlameColor, Thickness = 2 }):Play()
	end)
	tile.MouseLeave:Connect(function()
		TweenService:Create(edge, QUICK, { Color = Config.Ui.PanelEdge, Thickness = 1 }):Play()
	end)

	return tile
end

function BeastMenuController:Start()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BeastMenu"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local button = buildButton(screenGui)
	local panel, grid, current = buildPanel(screenGui)

	for index, beast in Config.Beasts do
		local tile = buildTile(index, beast, grid)
		tile.Activated:Connect(function()
			Remotes.event("SelectBeast"):FireServer(index)
			panel.Visible = false
		end)
	end

	button.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)

	-- Ask what is currently being fought: the spawn announcement may have gone
	-- out before this client was listening.
	Remotes.event("SelectBeast"):FireServer()

	Remotes.event("BeastChanged").OnClientEvent:Connect(function(index, name, health)
		current.Text = string.format("Now fighting: %d. %s  -  %s HP", index, name, abbreviate(health))
	end)
end

return BeastMenuController

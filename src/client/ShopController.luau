--[[
	ShopController
	Arac ve canta yukseltmelerini listeleyen panel. Satin alma kararini
	sunucu verir; buradaki "alinabilir mi" kontrolu sadece gorseldir.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Create = require(script.Parent.Create)
local HudController = require(script.Parent.HudController)
local StateController = require(script.Parent.StateController)
local Theme = require(script.Parent.Theme)

local ShopController = {}

local player = Players.LocalPlayer
local frame: Frame
local rows: { [string]: { [number]: { Container: Frame, Status: TextLabel, Button: TextButton } } } = {
	Tools = {},
	Backpacks = {},
}

local function makeRow(index: number, entry: any, detail: string, remoteName: string, parent: Instance)
	local container = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = Theme.SurfaceAlt,
		BorderSizePixel = 0,
		LayoutOrder = index,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = Theme.Corner }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
	})

	Create("TextLabel", {
		Size = UDim2.new(0.55, 0, 0, 20),
		Position = UDim2.new(0, 0, 0, 8),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = entry.Name,
		TextSize = 15,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = container,
	})

	local status = Create("TextLabel", {
		Size = UDim2.new(0.55, 0, 0, 18),
		Position = UDim2.new(0, 0, 0, 28),
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = detail,
		TextSize = 13,
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = container,
	})

	local buyButton = Create("TextButton", {
		Size = UDim2.new(0, 110, 0, 34),
		Position = UDim2.new(1, -110, 0.5, -17),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Font = Theme.FontBold,
		Text = Format.money(entry.Price),
		TextSize = 14,
		TextColor3 = Theme.Text,
		Parent = container,
	}, {
		Create("UICorner", { CornerRadius = Theme.Corner }),
	})

	buyButton.Activated:Connect(function()
		Remotes.event(remoteName):FireServer(index)
	end)

	return { Container = container, Status = status, Button = buyButton }
end

local function refresh()
	local state = StateController:Get()

	local function apply(list: { any }, currentIndex: number, group: string)
		for index, entry in list do
			local row = rows[group][index]
			if not row then
				continue
			end

			if index <= currentIndex then
				row.Button.Text = if index == currentIndex then "KULLANIMDA" else "SAHIP"
				row.Button.BackgroundColor3 = Theme.Surface
				row.Button.AutoButtonColor = false
			elseif state.Coins >= entry.Price then
				row.Button.Text = Format.money(entry.Price)
				row.Button.BackgroundColor3 = Theme.Accent
				row.Button.AutoButtonColor = true
			else
				row.Button.Text = Format.money(entry.Price)
				row.Button.BackgroundColor3 = Theme.SurfaceAlt
				row.Button.AutoButtonColor = true
			end
		end
	end

	apply(Config.Tools, state.ToolIndex, "Tools")
	apply(Config.Backpacks, state.BackpackIndex, "Backpacks")
end

local function section(title: string, order: number, parent: Instance): Frame
	Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = title,
		TextSize = 16,
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Parent = parent,
	})

	return Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order + 1,
		Parent = parent,
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
end

function ShopController:Start()
	local screenGui = Create("ScreenGui", {
		Name = "SimulatorShop",
		ResetOnSpawn = false,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	frame = Create("Frame", {
		Name = "Panel",
		Size = UDim2.new(0, 420, 0, 460),
		Position = UDim2.new(0.5, -210, 0.5, -230),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Parent = screenGui,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 12) }),
	})

	Create("TextLabel", {
		Size = UDim2.new(1, -60, 0, 48),
		Position = UDim2.new(0, 18, 0, 0),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		Text = "MAGAZA",
		TextSize = 20,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})

	local closeButton = Create("TextButton", {
		Size = UDim2.new(0, 34, 0, 34),
		Position = UDim2.new(1, -46, 0, 8),
		BackgroundColor3 = Theme.SurfaceAlt,
		BorderSizePixel = 0,
		Font = Theme.FontBold,
		Text = "X",
		TextSize = 16,
		TextColor3 = Theme.Text,
		Parent = frame,
	}, {
		Create("UICorner", { CornerRadius = Theme.Corner }),
	})

	local scroll = Create("ScrollingFrame", {
		Size = UDim2.new(1, -24, 1, -60),
		Position = UDim2.new(0, 12, 0, 52),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.Accent,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = frame,
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Create("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 12) }),
	})

	local toolsHolder = section("ARACLAR", 1, scroll)
	for index, entry in Config.Tools do
		rows.Tools[index] =
			makeRow(index, entry, "Guc: " .. Format.abbreviate(entry.Power), "BuyTool", toolsHolder)
	end

	local backpacksHolder = section("CANTALAR", 3, scroll)
	for index, entry in Config.Backpacks do
		rows.Backpacks[index] = makeRow(
			index,
			entry,
			"Kapasite: " .. Format.abbreviate(entry.Capacity),
			"BuyBackpack",
			backpacksHolder
		)
	end

	closeButton.Activated:Connect(function()
		screenGui.Enabled = false
	end)

	HudController.ShopToggled:Connect(function()
		screenGui.Enabled = not screenGui.Enabled
	end)

	StateController.Changed:Connect(refresh)
	refresh()
end

return ShopController

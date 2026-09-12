--[[
	SaveSlotController
	The save slot menu: five runs, pick one or start a new one.

	Everything shown here comes from the server. The client never decides what
	a slot contains, whether one can be created, or whether a save succeeded -
	it sends a slot number and redraws whatever comes back.

	The menu opens on join and stays up until a slot is chosen, because until
	then there is nowhere for progress to go.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local SaveSlotController = {}

local player = Players.LocalPlayer
local QUICK = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Slot number the user is being asked to confirm something about, and what.
local pending: { slot: number, action: string }? = nil

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

-- 3725 seconds reads as "1h 2m"; 45 reads as "45s".
local function duration(seconds: number): string
	if seconds >= 3600 then
		return string.format("%dh %dm", seconds // 3600, (seconds % 3600) // 60)
	elseif seconds >= 60 then
		return string.format("%dm", seconds // 60)
	end
	return string.format("%ds", seconds)
end

local function savedAgo(savedAt: number): string
	if savedAt <= 0 then
		return "never saved"
	end
	return "saved " .. duration(math.max(os.time() - savedAt, 0)) .. " ago"
end

function SaveSlotController:Start()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SaveSlots"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 20
	screenGui.Parent = player:WaitForChild("PlayerGui")

	-- Dim behind the menu, so the world reads as paused even though it is not.
	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.Visible = false
	shade.Parent = screenGui

	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0, 520, 0, 520)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundColor3 = Config.SaveUi.Panel
	panel.Parent = shade
	corner(panel, 16)
	stroke(panel, Config.SaveUi.PanelEdge, 1.5)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -32, 0, 34)
	title.Position = UDim2.new(0, 16, 0, 16)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 24
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "SAVE SLOTS"
	title.TextColor3 = Config.SaveUi.Text
	title.Parent = panel

	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, -32, 0, 18)
	status.Position = UDim2.new(0, 16, 0, 48)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.TextSize = 13
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Text = "Choose a slot to continue, or an empty one to start a new game."
	status.TextColor3 = Config.SaveUi.Muted
	status.Parent = panel

	local list = Instance.new("Frame")
	list.Size = UDim2.new(1, -32, 1, -140)
	list.Position = UDim2.new(0, 16, 0, 78)
	list.BackgroundTransparency = 1
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	-- Confirmation strip along the bottom, used for both creating and erasing.
	local confirm = Instance.new("Frame")
	confirm.Size = UDim2.new(1, -32, 0, 44)
	confirm.Position = UDim2.new(0, 16, 1, -56)
	confirm.BackgroundTransparency = 1
	confirm.Visible = false
	confirm.Parent = panel

	local confirmText = Instance.new("TextLabel")
	confirmText.Size = UDim2.new(1, -220, 1, 0)
	confirmText.BackgroundTransparency = 1
	confirmText.Font = Enum.Font.GothamBold
	confirmText.TextSize = 14
	confirmText.TextXAlignment = Enum.TextXAlignment.Left
	confirmText.TextColor3 = Config.SaveUi.Text
	confirmText.Text = ""
	confirmText.Parent = confirm

	local function actionButton(text: string, colour: Color3, offset: number): TextButton
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(0, 100, 0, 36)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, offset, 0.5, 0)
		button.BackgroundColor3 = colour
		button.AutoButtonColor = false
		button.Font = Enum.Font.GothamBold
		button.TextSize = 14
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Text = text
		button.Parent = confirm
		corner(button, 8)
		return button
	end

	local yes = actionButton("CONFIRM", Config.SaveUi.Accent, 0)
	local no = actionButton("CANCEL", Config.SaveUi.PanelEdge, -108)

	local function closeConfirm()
		pending = nil
		confirm.Visible = false
	end

	local function ask(slot: number, action: string, message: string)
		pending = { slot = slot, action = action }
		confirmText.Text = message
		yes.BackgroundColor3 = if action == "delete" then Config.SaveUi.Danger else Config.SaveUi.Accent
		confirm.Visible = true
	end

	yes.Activated:Connect(function()
		if not pending then
			return
		end

		if pending.action == "create" then
			Remotes.event("CreateSlot"):FireServer(pending.slot)
		elseif pending.action == "delete" then
			Remotes.event("DeleteSlot"):FireServer(pending.slot)
		end

		closeConfirm()
	end)

	no.Activated:Connect(closeConfirm)

	local function draw(slots: { any }, offline: boolean)
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		status.Text = if offline
			then "Data store unreachable - you can play, but nothing will be saved."
			else "Choose a slot to continue, or an empty one to start a new game."
		status.TextColor3 = if offline then Config.SaveUi.Danger else Config.SaveUi.Muted

		for _, slot in slots do
			local row = Instance.new("TextButton")
			row.Name = string.format("Slot%d", slot.slot)
			row.LayoutOrder = slot.slot
			row.Size = UDim2.new(1, 0, 0, Config.SaveUi.SlotHeight)
			row.BackgroundColor3 = Config.SaveUi.Panel:Lerp(Color3.new(1, 1, 1), 0.06)
			row.AutoButtonColor = false
			row.Text = ""
			row.Parent = list
			corner(row, 10)

			local edge = stroke(
				row,
				if slot.active then Config.SaveUi.Accent else Config.SaveUi.PanelEdge,
				if slot.active then 2 else 1
			)

			local number = Instance.new("TextLabel")
			number.Size = UDim2.new(0, 40, 1, 0)
			number.Position = UDim2.new(0, 14, 0, 0)
			number.BackgroundTransparency = 1
			number.Font = Enum.Font.GothamBlack
			number.TextSize = 22
			number.Text = tostring(slot.slot)
			number.TextColor3 = if slot.used then Config.SaveUi.Accent else Config.SaveUi.Muted
			number.Parent = row

			local heading = Instance.new("TextLabel")
			heading.Size = UDim2.new(1, -200, 0, 22)
			heading.Position = UDim2.new(0, 58, 0, 14)
			heading.BackgroundTransparency = 1
			heading.Font = Enum.Font.GothamBold
			heading.TextSize = 16
			heading.TextXAlignment = Enum.TextXAlignment.Left
			heading.TextColor3 = Config.SaveUi.Text
			heading.Text = if slot.used then "Saved run" else "Empty slot"
			heading.Parent = row

			local detail = Instance.new("TextLabel")
			detail.Size = UDim2.new(1, -200, 0, 18)
			detail.Position = UDim2.new(0, 58, 0, 36)
			detail.BackgroundTransparency = 1
			detail.Font = Enum.Font.Gotham
			detail.TextSize = 13
			detail.TextXAlignment = Enum.TextXAlignment.Left
			detail.TextColor3 = Config.SaveUi.Muted
			detail.Text = if slot.used
				then string.format(
					"%d/%d done  -  %s played  -  %s",
					slot.steps,
					slot.total,
					duration(slot.playSeconds),
					savedAgo(slot.savedAt)
				)
				else "Start a new game here"
			detail.Parent = row

			local action = Instance.new("TextButton")
			action.Size = UDim2.new(0, 110, 0, 34)
			action.AnchorPoint = Vector2.new(1, 0.5)
			action.Position = UDim2.new(1, -14, 0.5, 0)
			action.BackgroundColor3 = Config.SaveUi.Accent
			action.AutoButtonColor = false
			action.Font = Enum.Font.GothamBold
			action.TextSize = 13
			action.TextColor3 = Color3.new(1, 1, 1)
			action.Text = if slot.active then "PLAYING" elseif slot.used then "CONTINUE" else "NEW GAME"
			action.Parent = row
			corner(action, 8)

			if slot.active then
				action.BackgroundColor3 = Config.SaveUi.PanelEdge
			end

			action.Activated:Connect(function()
				if slot.active then
					shade.Visible = false
				elseif slot.used then
					Remotes.event("SelectSlot"):FireServer(slot.slot)
					shade.Visible = false
				else
					-- Creating is confirmed rather than immediate, so a stray
					-- click cannot start a run you did not mean to.
					ask(slot.slot, "create", string.format("Start a new game in slot %d?", slot.slot))
				end
			end)

			-- Erase, only on slots that hold something.
			if slot.used then
				local erase = Instance.new("TextButton")
				erase.Size = UDim2.new(0, 26, 0, 26)
				erase.AnchorPoint = Vector2.new(1, 0.5)
				erase.Position = UDim2.new(1, -132, 0.5, 0)
				erase.BackgroundColor3 = Config.SaveUi.Panel
				erase.AutoButtonColor = false
				erase.Font = Enum.Font.GothamBold
				erase.TextSize = 13
				erase.TextColor3 = Config.SaveUi.Danger
				erase.Text = "X"
				erase.Parent = row
				corner(erase, 6)
				stroke(erase, Config.SaveUi.Danger, 1).Transparency = 0.5

				erase.Activated:Connect(function()
					ask(
						slot.slot,
						"delete",
						string.format("Erase slot %d? This cannot be undone.", slot.slot)
					)
				end)
			end

			row.MouseEnter:Connect(function()
				TweenService:Create(edge, QUICK, { Thickness = 2 }):Play()
			end)
			row.MouseLeave:Connect(function()
				TweenService:Create(edge, QUICK, {
					Thickness = if slot.active then 2 else 1,
				}):Play()
			end)
		end
	end

	-- A button to reopen the menu, and one to save on the spot.
	local function cornerButton(text: string, offset: number, onClick: () -> ()): TextButton
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(0, 96, 0, 32)
		button.AnchorPoint = Vector2.new(1, 1)
		button.Position = UDim2.new(1, -20, 1, offset)
		button.BackgroundColor3 = Config.SaveUi.Panel
		button.AutoButtonColor = false
		button.Font = Enum.Font.GothamBold
		button.TextSize = 13
		button.TextColor3 = Config.SaveUi.Text
		button.Text = text
		button.Parent = screenGui
		corner(button, 8)
		stroke(button, Config.SaveUi.PanelEdge, 1)
		button.Activated:Connect(onClick)
		return button
	end

	cornerButton("SLOTS", -20, function()
		shade.Visible = not shade.Visible
	end)

	cornerButton("SAVE", -60, function()
		Remotes.event("SaveNow"):FireServer()
	end)

	local notice = Instance.new("TextLabel")
	notice.Size = UDim2.new(0, 320, 0, 28)
	notice.AnchorPoint = Vector2.new(0.5, 1)
	notice.Position = UDim2.new(0.5, 0, 1, -20)
	notice.BackgroundTransparency = 1
	notice.Font = Enum.Font.GothamBold
	notice.TextSize = 14
	notice.TextColor3 = Config.SaveUi.Accent
	notice.Text = ""
	notice.Parent = screenGui

	Remotes.event("SaveNotice").OnClientEvent:Connect(function(message)
		notice.Text = message
		task.delay(3, function()
			if notice.Text == message then
				notice.Text = ""
			end
		end)
	end)

	Remotes.event("SlotsChanged").OnClientEvent:Connect(function(slots, offline)
		draw(slots, offline)

		-- Opened on join and left up until a slot is active, since until then
		-- there is nowhere for progress to go.
		local anyActive = false
		for _, slot in slots do
			anyActive = anyActive or slot.active
		end
		if not anyActive then
			shade.Visible = true
		end
	end)
end

return SaveSlotController

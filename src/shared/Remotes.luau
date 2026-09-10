--[[
	Remotes
	Tum RemoteEvent'leri tek yerde tanimlar. Sunucu tarafinda olusturur,
	client tarafinda bekler. Elle Instance aramak yerine Remotes.event("Ad").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local EVENTS = {
	-- Client -> Sunucu
	"Collect",
	"BuyTool",
	"BuyBackpack",
	"Rebirth",
	-- Sunucu -> Client
	"StateChanged",
	"Notify",
}

local folder: Folder

if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end

	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local Remotes = {}

function Remotes.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes

--[[
	WorldService
	Places the castle, lays the path to its gate, and plants the signpost.

	Order matters: the castle is built first because it reports where its gate
	is, and the path and the sign are both aimed at that point rather than at
	a position written down twice.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Castle = require(script.Parent.Castle)

local WorldService = {}

local function slab(cframe: CFrame, size: Vector3, color: Color3, parent: Instance)
	local part = Instance.new("Part")
	part.Name = "PathSlab"
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Config.Path.Material
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
end

--[[
	Cobbles from the spawn to the castle gate.

	Laid as separate slabs rather than one long part so the path can bend, and
	each is nudged sideways by a small random amount - a perfectly straight
	line of stone reads as a runway, not a road.
]]
local function layPath(from: Vector3, to: Vector3, parent: Instance)
	local span = to - from
	local distance = span.Magnitude
	local direction = span.Unit
	-- Sideways vector, for the wander and for the kerb stones.
	local across = direction:Cross(Vector3.new(0, 1, 0)).Unit

	local step = Config.Path.SlabLength + Config.Path.Gap
	local count = math.floor(distance / step)

	for index = 0, count do
		local along = index * step
		-- Smooth wander rather than random jitter: neighbouring slabs stay in
		-- line with each other, and the path curves gently.
		local wander = math.sin(index * 0.35) * Config.Path.Wander
		local position = from + direction * along + across * wander

		local facing = CFrame.lookAt(
			Vector3.new(position.X, -Config.Path.Sink, position.Z),
			Vector3.new(position.X, -Config.Path.Sink, position.Z) + direction
		)

		slab(
			facing,
			Vector3.new(Config.Path.Width, Config.Path.Thickness, Config.Path.SlabLength),
			Config.Path.Color,
			parent
		)

		-- Kerb stones down both sides.
		for _, side in { -1, 1 } do
			slab(
				facing * CFrame.new(side * (Config.Path.Width / 2 + 1), 0.2, 0),
				Vector3.new(1.6, Config.Path.Thickness + 0.6, Config.Path.SlabLength * 0.8),
				Config.Path.EdgeColor,
				parent
			)
		end
	end
end

--[[
	The signpost: a post, a board reading CASTLE, and an arrow.

	The arrow is a real part rather than a drawing on the board, and it is
	rotated to point at the castle, so it stays correct if the castle moves.
]]
local function plantSign(position: Vector3, target: Vector3, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "CastleSign"
	model.Parent = parent

	local toCastle = (target - position) * Vector3.new(1, 0, 1)
	local heading = if toCastle.Magnitude > 0.1 then toCastle.Unit else Vector3.new(0, 0, -1)

	local post = Instance.new("Part")
	post.Name = "Post"
	post.Size = Vector3.new(1, Config.Sign.PostHeight, 1)
	post.CFrame = CFrame.new(position + Vector3.new(0, Config.Sign.PostHeight / 2, 0))
	post.Color = Config.Sign.PostColor
	post.Material = Enum.Material.Wood
	post.Anchored = true
	post.Parent = model

	-- The board faces back down the path, so it is readable on the way out.
	local boardCentre = position + Vector3.new(0, Config.Sign.PostHeight, 0)
	local board = Instance.new("Part")
	board.Name = "Board"
	board.Size = Config.Sign.BoardSize
	board.CFrame = CFrame.lookAt(boardCentre, boardCentre - heading)
	board.Color = Config.Sign.BoardColor
	board.Material = Enum.Material.WoodPlanks
	board.Anchored = true
	board.Parent = model

	-- Text on both faces, so the sign is not blank from behind.
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local surface = Instance.new("SurfaceGui")
		surface.Name = "Label" .. face.Name
		surface.Face = face
		surface.CanvasSize = Vector2.new(400, 140)
		surface.Parent = board

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.Text = Config.Sign.Text
		label.TextColor3 = Config.Sign.TextColor
		label.Parent = surface
	end

	--[[
		The arrow, built from a shaft and a wedge head.

		Rotated to point along the heading to the castle. A wedge's slope runs
		along its own -Z, so pointing it is a matter of aiming that axis at the
		target rather than adding a rotation by hand.
	]]
	local arrowCentre = boardCentre + Vector3.new(0, Config.Sign.BoardSize.Y / 2 + 1.6, 0)
	local aim = CFrame.lookAt(arrowCentre, arrowCentre + heading)

	local shaft = Instance.new("Part")
	shaft.Name = "ArrowShaft"
	shaft.Size = Vector3.new(0.8, 0.8, Config.Sign.ArrowLength)
	shaft.CFrame = aim
	shaft.Color = Config.Sign.ArrowColor
	shaft.Material = Enum.Material.Neon
	shaft.Anchored = true
	shaft.Parent = model

	local head = Instance.new("WedgePart")
	head.Name = "ArrowHead"
	head.Size = Vector3.new(0.8, 3, 3)
	-- Sitting at the far end of the shaft, tipped onto its side so the point
	-- lies flat and reads as an arrowhead from the front.
	head.CFrame = aim
		* CFrame.new(0, 0, -(Config.Sign.ArrowLength / 2 + 1.5))
		* CFrame.Angles(0, 0, math.pi / 2)
		* CFrame.Angles(math.pi / 2, 0, 0)
	head.Color = Config.Sign.ArrowColor
	head.Material = Enum.Material.Neon
	head.Anchored = true
	head.Parent = model
end

function WorldService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "World"
	folder.Parent = workspace

	local origin = Config.Castle.Direction.Unit * Config.Castle.Distance
	local gate = Castle.build(origin, folder)

	local pathStart = Config.Castle.Direction.Unit * Config.Path.StartOffset
	layPath(pathStart, gate, folder)
	plantSign(Config.Sign.Position, gate, folder)

	print(
		string.format("[World] castle at %d studs, path and sign placed.", math.floor(Config.Castle.Distance))
	)
end

return WorldService

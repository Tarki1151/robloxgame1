--[[
	BirdService
	Av alaninin uzerinde ucusan kuslari yonetir.

	Kuslar tamamen sunucuda hareket eder (govde Anchored, her Heartbeat'te
	konumu sunucu yazar). Client hicbir kus verisi gondermez; sadece "ates
	ettim" der, hangi kusun vuruldugunu CollectService secer.

	Vurulan kus dusup yok olur ve Config.Birds.RespawnDelay sonra yerine
	yenisi dogar; havadaki kus sayisi sabit kalir.
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local BirdService = {}

type Bird = {
	model: Model,
	body: BasePart,
	leftWeld: Weld,
	rightWeld: Weld,
	-- Merkez etrafindaki dairesel ucus parametreleri.
	angle: number,
	radius: number,
	height: number,
	speed: number,
	bobPhase: number,
	flapPhase: number,
}

local birds: { Bird } = {}
local center = Vector3.new(0, 0, 0)
local folder: Folder

local function randomBetween(min: number, max: number): number
	return min + math.random() * (max - min)
end

-- Av alanlarinin ortalama merkezi. Alan yoksa dunyanin sifir noktasi.
local function resolveCenter(): Vector3
	local zones = CollectionService:GetTagged(Config.World.CollectZoneTag)
	local sum = Vector3.new(0, 0, 0)
	local count = 0

	for _, zone in zones do
		if zone:IsA("BasePart") then
			sum += zone.Position
			count += 1
		end
	end

	if count == 0 then
		return Vector3.new(0, 0, 0)
	end

	return sum / count
end

local function makeWing(name: string, color: Color3, body: BasePart, offset: CFrame): Weld
	local wing = Instance.new("Part")
	wing.Name = name
	wing.Size = Vector3.new(1.8, 0.15, 0.9)
	wing.Color = color
	wing.Material = Enum.Material.SmoothPlastic
	wing.CanCollide = false
	wing.CanQuery = false
	wing.CanTouch = false
	wing.Massless = true
	wing.TopSurface = Enum.SurfaceType.Smooth
	wing.BottomSurface = Enum.SurfaceType.Smooth
	wing.CFrame = body.CFrame * offset
	wing.Parent = body.Parent

	-- Govde Anchored; Weld ile bagli kanatlar onu takip eder. Cirpma
	-- animasyonu C0'i degistirerek yapilir.
	local weld = Instance.new("Weld")
	weld.Part0 = body
	weld.Part1 = wing
	weld.C0 = offset
	weld.Parent = body

	return weld
end

local function spawnBird(): Bird
	local color = Config.Birds.Colors[math.random(1, #Config.Birds.Colors)]

	local model = Instance.new("Model")
	model.Name = "Bird"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Config.Birds.Size
	body.Color = color
	body.Material = Enum.Material.SmoothPlastic
	body.Shape = Enum.PartType.Block
	body.Anchored = true
	body.CanCollide = false
	-- Nisan alma raycast'i kusu gormeli, bu yuzden CanQuery acik kalir.
	body.CanTouch = false
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Parent = model

	model.PrimaryPart = body
	model.Parent = folder

	local leftWeld = makeWing("WingLeft", color, body, CFrame.new(-1, 0.1, 0))
	local rightWeld = makeWing("WingRight", color, body, CFrame.new(1, 0.1, 0))

	CollectionService:AddTag(body, Config.Birds.Tag)

	local bird: Bird = {
		model = model,
		body = body,
		leftWeld = leftWeld,
		rightWeld = rightWeld,
		angle = math.random() * math.pi * 2,
		radius = randomBetween(Config.Birds.Radius * 0.45, Config.Birds.Radius),
		height = randomBetween(Config.Birds.MinHeight, Config.Birds.MaxHeight),
		speed = randomBetween(Config.Birds.MinSpeed, Config.Birds.MaxSpeed),
		bobPhase = math.random() * math.pi * 2,
		flapPhase = math.random() * math.pi * 2,
	}

	return bird
end

local function positionOf(bird: Bird, now: number): CFrame
	local x = center.X + math.cos(bird.angle) * bird.radius
	local z = center.Z + math.sin(bird.angle) * bird.radius
	-- Hafif alcalip yukselme, hepsi ayni duzlemde ucmasin diye.
	local y = center.Y + bird.height + math.sin(now * 1.2 + bird.bobPhase) * 2.5

	local position = Vector3.new(x, y, z)
	-- Tur yonu: yaricapa dik olan teget.
	local heading = Vector3.new(-math.sin(bird.angle), 0, math.cos(bird.angle))

	return CFrame.lookAt(position, position + heading)
end

local function step(deltaTime: number)
	local now = os.clock()

	for _, bird in birds do
		if bird.body.Parent then
			-- Acisal hiz = cizgisel hiz / yaricap.
			bird.angle += (bird.speed / bird.radius) * deltaTime
			bird.body.CFrame = positionOf(bird, now)

			local flap = math.sin(now * Config.Birds.FlapSpeed + bird.flapPhase) * 0.7
			bird.leftWeld.C0 = CFrame.new(-1, 0.1, 0) * CFrame.Angles(0, 0, flap)
			bird.rightWeld.C0 = CFrame.new(1, 0.1, 0) * CFrame.Angles(0, 0, -flap)
		end
	end
end

-- Vurulan kusu dusurur ve gecikmeli olarak yerine yenisini koyar.
function BirdService:Kill(body: BasePart)
	for index, bird in birds do
		if bird.body == body then
			table.remove(birds, index)

			CollectionService:RemoveTag(body, Config.Birds.Tag)
			body.CanQuery = false
			body.Anchored = false
			body.AssemblyLinearVelocity = Vector3.new(0, -8, 0)
			body.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
			Debris:AddItem(bird.model, 3)

			task.delay(Config.Birds.RespawnDelay, function()
				table.insert(birds, spawnBird())
			end)

			return true
		end
	end

	return false
end

function BirdService:GetBirds(): { Bird }
	return birds
end

function BirdService:Start()
	folder = Instance.new("Folder")
	folder.Name = "Birds"
	folder.Parent = workspace

	center = resolveCenter()

	for _ = 1, Config.Birds.Count do
		table.insert(birds, spawnBird())
	end

	RunService.Heartbeat:Connect(step)
end

return BirdService

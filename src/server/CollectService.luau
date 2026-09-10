--[[
	CollectService
	Ates etme eyleminin sunucu tarafi. Client sadece "ates ettim" der;
	hangi kusun vuruldugu, kazancin ne oldugu ve atisin gecerli olup olmadigi
	daima sunucuda belirlenir. Client hicbir hedef bilgisi gondermez.

	Dogrulamalar:
	  1. Cooldown  - exploit ile saniyede yuzlerce atis yapilmasini engeller.
	  2. Konum     - oyuncunun gercekten av alaninda olmasi gerekir.
	  3. Nisan     - menzil ve nisan konisi icinde bir kus olmali.
	  4. Kapasite  - canta doluysa kazanc yok.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local BirdService = require(script.Parent.BirdService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local WorldService = require(script.Parent.WorldService)

local CollectService = {}

local lastCollect: { [Player]: number } = {}

local function getRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return root
end

-- Namlu ucu: elde tufek varsa Handle'in onu, yoksa govdenin biraz onu.
local function getMuzzle(player: Player, root: BasePart): Vector3
	local character = player.Character
	local tool = if character then character:FindFirstChildOfClass("Tool") else nil
	local handle = if tool then tool:FindFirstChild("Handle") else nil

	if handle and handle:IsA("BasePart") then
		return handle.CFrame.Position + handle.CFrame.LookVector * (handle.Size.Z / 2)
	end

	return root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 1, 0)
end

--[[
	Nisan konisindeki en iyi hedefi secer.

	Karakter kameranin baktigi yone donduğu icin yatay yon HumanoidRootPart'tan
	okunur; dikey aci serbest birakilir (kuslar yukarida ucar, oyuncunun havaya
	nisan alabilmesi gerekmez). Skor = yatay hizalanma; esitlikte yakin olan.
]]
local function pickTarget(muzzle: Vector3, look: Vector3): BasePart?
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.01 then
		return nil
	end
	flatLook = flatLook.Unit

	local best: BasePart? = nil
	local bestScore = Config.Collect.AimTolerance
	local bestDistance = math.huge

	for _, bird in BirdService:GetBirds() do
		local body = bird.body
		if body.Parent then
			local delta = body.Position - muzzle
			local distance = delta.Magnitude

			if distance <= Config.Collect.Range and distance > 0.1 then
				local flatDelta = Vector3.new(delta.X, 0, delta.Z)
				if flatDelta.Magnitude > 0.01 then
					local score = flatDelta.Unit:Dot(flatLook)
					if score > bestScore or (score >= bestScore and distance < bestDistance) then
						best = body
						bestScore = score
						bestDistance = distance
					end
				end
			end
		end
	end

	return best
end

-- Kisa omurlu iz efekti. Tamamen kozmetik; oyun mantigina dokunmaz.
local function tracer(from: Vector3, to: Vector3, color: Color3)
	local delta = to - from
	local beam = Instance.new("Part")
	beam.Name = "Tracer"
	beam.Size = Vector3.new(0.12, 0.12, delta.Magnitude)
	beam.CFrame = CFrame.lookAt(from + delta / 2, to)
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Transparency = 0.35
	beam.Parent = workspace

	Debris:AddItem(beam, 0.08)
end

local function onCollectRequest(player: Player)
	local now = os.clock()
	-- Cooldown'un biraz altini tolere ediyoruz (ag gecikmesi payi).
	if now - (lastCollect[player] or 0) < Config.Collect.Cooldown * 0.9 then
		return
	end

	local profile = DataService:Get(player)
	if not profile then
		return
	end

	local root = getRoot(player)
	if not root or not WorldService:IsInCollectZone(root.Position) then
		return
	end

	lastCollect[player] = now

	local muzzle = getMuzzle(player, root)
	local target = pickTarget(muzzle, root.CFrame.LookVector)

	local tool = EconomyService:GetTool(profile)
	tracer(muzzle, if target then target.Position else muzzle + root.CFrame.LookVector * 60, tool.Color)

	if not target then
		return
	end

	if BirdService:Kill(target) then
		EconomyService:AddResources(player, tool.Power)
	end
end

function CollectService:Start()
	Remotes.event("Collect").OnServerEvent:Connect(onCollectRequest)

	Players.PlayerRemoving:Connect(function(player)
		lastCollect[player] = nil
	end)
end

return CollectService

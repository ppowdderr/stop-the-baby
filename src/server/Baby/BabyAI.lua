--!strict
-- The Baby: mood, growth, behaviors (wander/destroy/wants/fridge/swallow/escape/sleepwalk/refuse/gift), carry, soothe.
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local NightTable = require(Shared:WaitForChild("NightTable"))
local ToyCatalog = require(Shared:WaitForChild("ToyCatalog"))
local BabyRig = require(script.Parent.BabyRig)
local ChoreService = require(script.Parent.Parent.Services.ChoreService)
local InventoryService = require(script.Parent.Parent.Services.InventoryService)
local EconomyService = require(script.Parent.Parent.Services.EconomyService)
local DataService = require(script.Parent.Parent.Services.DataService)

local BabyAI = {}
BabyAI.MoodChanged = Signal.new() :: Signal.Signal<number, string>
BabyAI.StartedCrying = Signal.new() :: Signal.Signal<()>
BabyAI.StoppedCrying = Signal.new() :: Signal.Signal<()>

local rng = Random.new()

local model: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local info: NightTable.NightInfo = NightTable.get(1)

local moodIndex = 1 -- 1 Happy .. 4 Crying
local decayTimer = 0
local immunityUntil = 0
local cryingSince: number? = nil
local frozen = false -- e.g. sleepwalking / between rounds
local refuseNext = false
local want: string? = nil -- "Toy" | "Snack"
local active = false
local currentBehavior = "Idle"

function BabyAI.behavior(): string
	return currentBehavior
end
local behaviorThread: thread? = nil

local carriers: { [Player]: boolean } = {}
local carryWeld: WeldConstraint? = nil
local carriedBy: Player? = nil

local BABY_LINES = {
	Happy = { "hehe", "goo goo", "BABA!", "*giggles*" },
	Grumpy = { "hmph.", "no.", "NO.", "*pouts*" },
	Fussy = { "WAAH?", "I WANT", "*sniff*", "MOMMY?" },
	Crying = { "WAAAAAAAH", "WAAAAAH!!", "MOMMYYYY" },
}

-- Speech bubbles, FX and behavior are replicated as attributes; BabyAnimator (client) renders them.
local function say(text: string, seconds: number?)
	local m = model
	if not m then
		return
	end
	m:SetAttribute("Say", text)
	m:SetAttribute("SayFor", seconds or 2.5)
	m:SetAttribute("SaySeq", (m:GetAttribute("SaySeq") :: number? or 0) + 1)
end

local function fx(name: string)
	local m = model
	if not m then
		return
	end
	m:SetAttribute("Fx", name)
	m:SetAttribute("FxSeq", (m:GetAttribute("FxSeq") :: number? or 0) + 1)
end

local function setBehavior(name: string)
	currentBehavior = name
	if model then
		model:SetAttribute("Behavior", name)
	end
end

local function toastAll(text: string, kind: string?)
	Net.event("Toast"):FireAllClients(text, kind or "info")
end

local function clip(id: string)
	Net.event("ClipMoment"):FireAllClients(id)
end

local function stageName(): string
	return Config.Mood.Stages[moodIndex]
end

local function broadcastMood()
	local cryingFor = if cryingSince then os.clock() - cryingSince else 0
	Net.event("BabyMood")
		:FireAllClients(moodIndex, stageName(), cryingFor, want, math.max(0, immunityUntil - os.clock()))
	if model then
		model:SetAttribute("Mood", stageName())
	end
end

local function setMood(newIndex: number)
	newIndex = math.clamp(newIndex, 1, #Config.Mood.Stages)
	if newIndex == moodIndex then
		return
	end
	local wasCrying = moodIndex == 4
	moodIndex = newIndex
	decayTimer = 0
	if moodIndex == 4 and not wasCrying then
		cryingSince = os.clock()
		fx("tantrum")
		clip("baby_cry")
		BabyAI.StartedCrying:Fire()
	elseif moodIndex < 4 and wasCrying then
		cryingSince = nil
		BabyAI.StoppedCrying:Fire()
	end
	local lines = BABY_LINES[stageName()]
	say(lines[rng:NextInteger(1, #lines)])
	BabyAI.MoodChanged:Fire(moodIndex, stageName())
	broadcastMood()
end

-- Public getters -------------------------------------------------------------
function BabyAI.getModel(): Model?
	return model
end
function BabyAI.moodIndex(): number
	return moodIndex
end
function BabyAI.isCrying(): boolean
	return moodIndex == 4
end
function BabyAI.cryingFor(): number
	return if cryingSince then os.clock() - cryingSince else 0
end
function BabyAI.isCalm(): boolean
	return moodIndex <= 2
end
function BabyAI.isCarried(): boolean
	return carriedBy ~= nil
end

-- Map helpers ------------------------------------------------------------------
local function mapFolder(name: string): Folder?
	local map = workspace:FindFirstChild("Map")
	local f = map and map:FindFirstChild(name)
	return if f and f:IsA("Folder") then f else nil
end

local function randomWaypoint(): Vector3?
	local wps = mapFolder("Waypoints")
	if not wps then
		return nil
	end
	local list = {}
	for _, wp in wps:GetChildren() do
		if wp:IsA("BasePart") and table.find(info.areas, wp:GetAttribute("Area") or "LivingRoom") then
			table.insert(list, wp)
		end
	end
	if #list == 0 then
		return nil
	end
	return list[rng:NextInteger(1, #list)].Position
end

local function stationPos(name: string): Vector3?
	local st = mapFolder("Stations")
	local p = st and st:FindFirstChild(name)
	if p and p:IsA("BasePart") then
		return p.Position
	end
	return nil
end

local function nearestPlayer(maxDist: number): (Player?, number)
	local r = root
	if not r then
		return nil, math.huge
	end
	local best, bestDist = nil, maxDist
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp and not carriers[plr] then
			local d = (hrp.Position - r.Position).Magnitude
			if d < bestDist then
				best, bestDist = plr, d
			end
		end
	end
	return best, bestDist
end

-- Movement ---------------------------------------------------------------------
local function moveTo(target: Vector3, timeout: number): boolean
	local h, r = humanoid, root
	if not h or not r then
		return false
	end
	local path = PathfindingService:CreatePath({
		AgentRadius = 2 * info.scale,
		AgentHeight = 5 * info.scale,
		AgentCanJump = NightTable.has(info, "StairClimb"),
	})
	local ok = pcall(path.ComputeAsync, path, r.Position, target)
	local deadline = os.clock() + timeout
	if ok and path.Status == Enum.PathStatus.Success then
		for _, wp in path:GetWaypoints() do
			if not active or carriedBy or frozen then
				return false
			end
			h:MoveTo(wp.Position)
			local reached = h.MoveToFinished:Wait()
			if not reached and os.clock() > deadline then
				return false
			end
			if os.clock() > deadline then
				return false
			end
		end
		return true
	end
	-- Fallback: straight line
	h:MoveTo(target)
	return h.MoveToFinished:Wait()
end

-- Behaviors ----------------------------------------------------------------------
local function knockProps()
	local r = root
	local props = mapFolder("Props")
	if not r or not props then
		return
	end
	local reach = 4 * info.scale
	for _, prop in props:GetChildren() do
		if prop:IsA("BasePart") and (prop.Position - r.Position).Magnitude < reach and prop.Anchored then
			prop.Anchored = false
			prop:ApplyImpulse(
				(prop.Position - r.Position).Unit * prop.AssemblyMass * 40 + Vector3.new(0, prop.AssemblyMass * 30, 0)
			)
			prop:SetAttribute("Knocked", true)
		end
	end
end

local function bWander()
	setBehavior("Wander")
	local target = randomWaypoint()
	if target then
		moveTo(target, 12)
	end
	task.wait(rng:NextNumber(0.5, 2))
end

local function bDestroy()
	setBehavior("Wander")
	local target = randomWaypoint()
	if target and moveTo(target, 12) then
		setBehavior("Destroy")
		say("SMASH!")
		fx("smash")
		task.wait(0.45)
		knockProps()
		local messed = ChoreService.messUp()
		if messed then
			toastAll("Baby ruined: " .. messed .. "!", "warn")
			clip("baby_mess")
		end
	end
	task.wait(1)
end

local function bWant(kind: string)
	setBehavior("Want")
	want = kind
	say(if kind == "Snack" then "HUNGWY!" else "TOY! TOY!", 4)
	broadcastMood()
	local deadline = os.clock() + rng:NextNumber(Config.Baby.WantChangeInterval.min, Config.Baby.WantChangeInterval.max)
	while want and os.clock() < deadline and active do
		task.wait(1)
	end
	if want then
		want = nil
		if NightTable.has(info, "Tantrum") then
			say("HMPH!", 2)
			setMood(moodIndex + 1)
		end
		broadcastMood()
	end
end

local function bFridgeRaid()
	setBehavior("Wander")
	local fridge = stationPos("Fridge")
	if fridge and moveTo(fridge, 20) then
		setBehavior("Eat")
		say("NOM NOM NOM", 4)
		fx("chew")
		clip("fridge_raid")
		toastAll("Baby is eating EVERYTHING in the fridge!", "warn")
		task.wait(4)
		setMood(1) -- full baby is a happy baby...
		local messed = ChoreService.messUp()
		if messed then
			toastAll("...and ruined: " .. messed, "warn")
		end
	end
end

local function bSwallow()
	setBehavior("Wander")
	local victim, dist = nearestPlayer(6 * info.scale)
	local r = root
	if not victim or not r or dist > 6 * info.scale or rng:NextNumber() > Config.Baby.SwallowChance * 4 then
		return
	end
	local char = victim.Character
	if not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then
		return
	end
	setBehavior("Swallow")
	say("OM.", 3)
	fx("swallow")
	clip("baby_swallow")
	toastAll(victim.Name .. " got SWALLOWED by Baby!", "warn")
	local profile = DataService.get(victim)
	if profile then
		profile.stats.swallowed += 1
		DataService.recordFirst(profile, "swallowed")
	end
	hum.PlatformStand = true
	local weld = Instance.new("WeldConstraint")
	hrp.CFrame = r.CFrame * CFrame.new(0, 0, 0)
	weld.Part0 = r
	weld.Part1 = hrp
	weld.Parent = hrp
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 0.6
		end
	end
	task.wait(5)
	say("BURP!", 2)
	fx("burp")
	weld:Destroy()
	if hum.Parent then
		hum.PlatformStand = false
		hrp.CFrame = r.CFrame * CFrame.new(0, 2, -6 * info.scale)
		hrp:ApplyImpulse(r.CFrame.LookVector * hrp.AssemblyMass * 60 + Vector3.new(0, hrp.AssemblyMass * 40, 0))
		for _, d in char:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				d.Transparency = 0
			end
		end
	end
end

local function bEscape()
	setBehavior("Escape")
	local door = stationPos("FrontDoor")
	if door and moveTo(door, 20) then
		say("BYE BYE!", 3)
		fx("squeal")
		clip("baby_escape")
		toastAll("BABY IS ESCAPING! Carry it back inside!", "warn")
		local outside = stationPos("Outside")
		if outside then
			moveTo(outside, 20)
		end
		task.wait(6)
	end
end

local function bSleepwalk()
	setBehavior("Sleepwalk")
	frozen = true
	say("zzz...", 6)
	fx("snore")
	toastAll("Baby is sleepwalking — don't wake it!", "info")
	local h = humanoid
	local prev = if h then h.WalkSpeed else 8
	if h then
		h.WalkSpeed = prev * 0.5
	end
	for _ = 1, 3 do
		local t = randomWaypoint()
		if t then
			moveTo(t, 10)
		end
	end
	if h then
		h.WalkSpeed = prev
	end
	frozen = false
end

local function bGift()
	local plr = nearestPlayer(12 * info.scale)
	if not plr then
		return
	end
	setBehavior("Gift")
	say("FOR YOU!", 3)
	fx("gift")
	local rec = InventoryService.rollItem(plr, info.night * Config.NightRollLegendaryBonusPerNight)
	if rec then
		local def = ToyCatalog.get(rec.id)
		toastAll(
			("Baby gave %s a %s!"):format(plr.Name, ToyCatalog.displayName(rec.id, rec.mutation)),
			if def then def.rarity else "info"
		)
		clip("baby_gift")
	end
	task.wait(2)
end

local function pickBehavior(): () -> ()
	local roll = rng:NextNumber()
	local has = function(b: string)
		return NightTable.has(info, b)
	end
	if has("Sleepwalk") and roll < 0.05 then
		return bSleepwalk
	end
	if has("Escape") and moodIndex >= 3 and roll < 0.18 then
		return bEscape
	end
	if has("FridgeRaid") and roll < 0.14 then
		return bFridgeRaid
	end
	if has("Swallow") and moodIndex >= 3 and roll < 0.35 then
		return bSwallow
	end
	if rng:NextNumber() < Config.Baby.GiftChance then
		return bGift
	end
	if want == nil and roll < 0.45 then
		if has("WantSnack") and rng:NextNumber() < 0.5 then
			return function()
				bWant("Snack")
			end
		end
		return function()
			bWant("Toy")
		end
	end
	if roll < 0.75 then
		return bDestroy
	end
	return bWander
end

-- Main loops ----------------------------------------------------------------------
local function behaviorLoop()
	while active do
		if carriedBy or frozen then
			task.wait(0.5)
			continue
		end
		local behavior = pickBehavior()
		behavior()
		setBehavior("Idle")
		task.wait(rng:NextNumber(Config.Baby.DestroyInterval.min, Config.Baby.DestroyInterval.max) * 0.3)
	end
	setBehavior("Idle")
end

local function moodLoop()
	while active do
		local dt = task.wait(1)
		if frozen or carriedBy then
			-- carrying calms slightly over time
			if carriedBy then
				decayTimer -= 0.5 * dt
				if decayTimer < -20 and moodIndex > 1 then
					setMood(moodIndex - 1)
				end
			end
			continue
		end
		if os.clock() < immunityUntil then
			broadcastMood()
			continue
		end
		decayTimer += dt
		local interval = info.decayInterval * (if want then Config.Mood.WantDecayMultiplier else 1)
		if decayTimer >= interval then
			setMood(moodIndex + 1)
		end
		broadcastMood()
	end
end

-- Soothe / interactions ---------------------------------------------------------------
function BabyAI.soothe(player: Player, stages: number, immunity: number, def: ToyCatalog.ItemDef): boolean
	if not active then
		return false
	end
	local r = root
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not r or not hrp or (hrp.Position - r.Position).Magnitude > 10 * info.scale + 6 then
		Net.event("Toast"):FireClient(player, "Get closer to Baby!", "error")
		return false
	end
	if refuseNext then
		refuseNext = false
		say("NO!!", 2)
		Net.event("Toast"):FireClient(player, "Baby refused it!", "error")
		return true
	end
	local bonus = 0
	if want and want == def.kind then
		bonus = 1
		want = nil
		say("YAY!!", 2)
	elseif want and want ~= def.kind then
		say("not THAT.", 2)
		stages = math.max(0, stages - 1)
	else
		say("hehe", 2)
	end
	setMood(moodIndex - stages - bonus)
	immunityUntil = os.clock() + immunity
	decayTimer = 0
	EconomyService.addCoins(player, Config.Economy.SootheReward, true)
	fx("soothe")
	if NightTable.has(info, "Refuse") and rng:NextNumber() < 0.2 then
		refuseNext = true
	end
	broadcastMood()
	return true
end

local function stopCarry()
	if carryWeld then
		carryWeld:Destroy()
		carryWeld = nil
	end
	local prev = carriedBy
	carriedBy = nil
	if prev then
		local char = prev.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = 18
			hum.JumpPower = 50
		end
	end
	if model then
		model:SetAttribute("Carried", false)
	end
	local h = humanoid
	if h then
		h.PlatformStand = false
	end
end

local function updateCarry()
	local needed = Config.Baby.CarryPlayersNeeded(info.night)
	local count = 0
	local first: Player? = nil
	for plr in carriers do
		if plr.Parent then
			count += 1
			first = first or plr
		else
			carriers[plr] = nil
		end
	end
	if count >= needed and first and not carriedBy then
		local char = first.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local r = root
		if hrp and r and (hrp.Position - r.Position).Magnitude <= 10 * info.scale + 6 then
			carriedBy = first
			local h = humanoid
			if h then
				h.PlatformStand = true
			end
			r.CFrame = hrp.CFrame * CFrame.new(0, 1.5 + info.scale * 1.5, -info.scale * 2.5)
			local w = Instance.new("WeldConstraint")
			w.Part0 = hrp
			w.Part1 = r
			w.Parent = r
			carryWeld = w
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = math.max(6, 18 - info.scale * 1.2)
				hum.JumpPower = 0
			end
			if model then
				model:SetAttribute("Carried", true)
			end
			say("WHEEE", 2)
			fx("squeal")
			clip("baby_carry")
			if count > 1 then
				toastAll(("%d babysitters are carrying Baby!"):format(count), "info")
			end
		end
	elseif carriedBy and (count < needed or not carriers[carriedBy]) then
		stopCarry()
	end
end

function BabyAI.setCarry(player: Player, start: boolean)
	if not active then
		return
	end
	if start then
		local needed = Config.Baby.CarryPlayersNeeded(info.night)
		local r = root
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not r or not hrp or (hrp.Position - r.Position).Magnitude > 10 * info.scale + 6 then
			return
		end
		carriers[player] = true
		local count = 0
		for _ in carriers do
			count += 1
		end
		if count < needed then
			toastAll(("Baby is too heavy! %d/%d babysitters lifting..."):format(count, needed), "info")
		end
	else
		carriers[player] = nil
	end
	updateCarry()
end

function BabyAI.isAtCrib(): boolean
	local crib = stationPos("Crib")
	local r = root
	return crib ~= nil and r ~= nil and (crib - r.Position).Magnitude <= 10 + info.scale * 2
end

-- Lifecycle --------------------------------------------------------------------------
function BabyAI.spawn(night: number)
	BabyAI.despawn()
	info = NightTable.get(night)
	local m = BabyRig.build(info.scale)
	local spawnPos = stationPos("BabySpawn") or Vector3.new(0, 10, 0)
	m:PivotTo(CFrame.new(spawnPos + Vector3.new(0, info.scale * 3, 0)))
	m.Parent = workspace
	model = m
	humanoid = m:FindFirstChildOfClass("Humanoid")
	root = m.PrimaryPart
	if humanoid then
		humanoid.WalkSpeed = info.walkSpeed
	end
	moodIndex = 1
	decayTimer = 0
	immunityUntil = 0
	cryingSince = nil
	want = nil
	frozen = false
	refuseNext = false
	table.clear(carriers)
	carriedBy = nil
	broadcastMood()
end

function BabyAI.activate()
	if active then
		return
	end
	active = true
	immunityUntil = os.clock() + Config.Mood.OpeningGrace
	behaviorThread = task.spawn(behaviorLoop)
	task.spawn(moodLoop)
	task.spawn(function()
		while active do
			task.wait(0.5)
			updateCarry()
		end
	end)
end

function BabyAI.deactivate()
	active = false
	frozen = true
	if behaviorThread then
		pcall(task.cancel, behaviorThread)
		behaviorThread = nil
	end
	stopCarry()
	local h = humanoid
	local r = root
	if h and r then
		h:MoveTo(r.Position)
	end
end

function BabyAI.setSpeedMultiplier(mult: number)
	local h = humanoid
	if h then
		h.WalkSpeed = info.walkSpeed * mult
	end
end

function BabyAI.calmForBed()
	setMood(1)
	frozen = true
	setBehavior("Sleep")
	say("zzz", 5)
	fx("snore")
end

function BabyAI.despawn()
	BabyAI.deactivate()
	if model then
		model:Destroy()
	end
	model, humanoid, root = nil, nil, nil
end

function BabyAI.start()
	Net.event("UseItem").OnServerEvent:Connect(function(player, uid)
		if not Net.allow(player, "UseItem", 3) or type(uid) ~= "string" then
			return
		end
		local profile = DataService.get(player)
		if not profile or not active then
			return
		end
		local rec = InventoryService.find(profile, uid)
		if not rec then
			return
		end
		local def = ToyCatalog.get(rec.id)
		if not def then
			return
		end
		-- Check range before consuming snacks
		local r = root
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not r or not hrp or (hrp.Position - r.Position).Magnitude > 10 * info.scale + 6 then
			Net.event("Toast"):FireClient(player, "Get closer to Baby!", "error")
			return
		end
		local stages, immunity, d = InventoryService.consume(player, uid)
		if stages and immunity and d then
			BabyAI.soothe(player, stages, immunity, d)
		end
	end)
	Net.event("CarryBaby").OnServerEvent:Connect(function(player, start)
		if Net.allow(player, "Carry", 4) then
			BabyAI.setCarry(player, start == true)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		carriers[player] = nil
		if carriedBy == player then
			stopCarry()
		end
	end)
end

return BabyAI

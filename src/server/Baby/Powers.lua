--!strict
-- Baby Power scripts. Each power is a loop with the same shape: TELL (1-2 s of readable warning)
-- -> EFFECT -> (opening). Powers only talk to the Baby through the Ctx handed in by BabyAI, so
-- new powers are additive: add a def to PowerCatalog and a runner here.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local PowerCatalog = require(Shared:WaitForChild("PowerCatalog"))

export type Ctx = {
	model: () -> Model?,
	root: () -> BasePart?,
	humanoid: () -> Humanoid?,
	scale: () -> number,
	busy: () -> boolean, -- carried / frozen / tucking / dazed: powers hold their fire
	moodIndex: () -> number,
	say: (text: string, seconds: number?) -> (),
	fx: (name: string) -> (),
	setBehavior: (name: string) -> (),
	clip: (id: string) -> (),
	toastAll: (text: string, kind: string?) -> (),
	knockProps: (reachMult: number) -> (),
	knockback: (player: Player, from: Vector3, strength: number) -> boolean,
	playersWithin: (radius: number) -> { Player },
	setDazed: (seconds: number) -> (),
	setPowerSpeed: (mult: number) -> (),
	messUp: () -> string?,
	shake: (center: Vector3, radius: number, strength: number) -> (),
}

local Powers = {}

local rng = Random.new()
local running = false
local threads: { thread } = {}
local ctx: Ctx? = nil
local levels: { [string]: number } = {}

-- Sticky state (shared with Soap Gun / Hiccups) ---------------------------------------------------
type StuckPlayer = { weld: WeldConstraint, until_: number, humanoid: Humanoid }
local stuckPlayers: { [Player]: StuckPlayer } = {}
local stuckProps: { [BasePart]: WeldConstraint } = {}
local slipperyUntil = 0

local function tellDelay(): number
	return 1.5
end

local function attr(c: Ctx, name: string, value: string | boolean)
	local m = c.model()
	if m then
		m:SetAttribute(name, value)
	end
end

local function releasePlayer(plr: Player, shove: boolean)
	local s = stuckPlayers[plr]
	if not s then
		return
	end
	stuckPlayers[plr] = nil
	if s.weld.Parent then
		s.weld:Destroy()
	end
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if s.humanoid.Parent then
		s.humanoid.PlatformStand = false
	end
	local c = ctx
	local r = c and c.root()
	if shove and hrp and r then
		local dir = (hrp.Position - r.Position)
		dir = Vector3.new(dir.X, 0, dir.Z)
		if dir.Magnitude < 0.5 then
			dir = r.CFrame.LookVector
		end
		hrp.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 3, 0))
		hrp:ApplyImpulse(dir.Unit * hrp.AssemblyMass * 45 + Vector3.new(0, hrp.AssemblyMass * 35, 0))
	end
end

local function releaseProp(prop: BasePart, weld: WeldConstraint)
	stuckProps[prop] = nil
	if weld.Parent then
		weld:Destroy()
	end
	if prop.Parent then
		prop.CanCollide = true
		prop.Massless = false
		prop.Anchored = false
		prop:SetAttribute("Stuck", false)
		prop:ApplyImpulse(Vector3.new(rng:NextNumber(-1, 1), 1.5, rng:NextNumber(-1, 1)) * prop.AssemblyMass * 25)
	end
end

function Powers.unstickAll(): number
	local n = 0
	for plr in stuckPlayers do
		releasePlayer(plr, true)
		n += 1
	end
	for prop, weld in stuckProps do
		releaseProp(prop, weld)
		n += 1
	end
	return n
end

function Powers.setSlippery(seconds: number)
	slipperyUntil = os.clock() + seconds
	local m = ctx and ctx.model()
	if m then
		m:SetAttribute("Slippery", true)
		task.delay(seconds, function()
			if m.Parent and os.clock() >= slipperyUntil - 0.05 then
				m:SetAttribute("Slippery", false)
			end
		end)
	end
end

function Powers.isStuck(plr: Player): boolean
	return stuckPlayers[plr] ~= nil
end

function Powers.junkCount(): number
	local n = 0
	for _ in stuckProps do
		n += 1
	end
	return n
end

function Powers.has(id: string): boolean
	return levels[id] ~= nil
end

function Powers.level(id: string): number
	return levels[id] or 0
end

-- Runners -------------------------------------------------------------------------------------------
local runners: { [string]: (c: Ctx, level: number) -> () } = {}

-- HICCUPS: puff (tell) -> bounce -> slam shockwave -> dazed opening.
runners.Hiccups = function(c: Ctx, level: number)
	local def = PowerCatalog.get("Hiccups")
	if not def then
		return
	end
	task.wait(rng:NextNumber(4, 7))
	while running do
		local interval = PowerCatalog.interval(def, level)
		task.wait(rng:NextNumber(interval * 0.8, interval * 1.2))
		if not running or c.busy() then
			continue
		end
		local r, h = c.root(), c.humanoid()
		if not r or not h then
			continue
		end
		c.say("hic... hic...", tellDelay())
		c.fx("tell_hiccup")
		attr(c, "Tell", "Hiccups")
		task.wait(tellDelay())
		attr(c, "Tell", "")
		if not running or c.busy() then
			continue
		end
		h:MoveTo(r.Position)
		c.setBehavior("Hiccup")
		c.say("HIC!!", 1.2)
		c.fx("hop")
		r.AssemblyLinearVelocity = Vector3.new(0, 38 + level * 6, 0)
		-- Wait for the landing (velocity turned downward and the humanoid found a floor again).
		local deadline = os.clock() + 2.5
		task.wait(0.35)
		while os.clock() < deadline and (h.FloorMaterial == Enum.Material.Air or r.AssemblyLinearVelocity.Y > 1) do
			task.wait(0.05)
		end
		if not running then
			break
		end
		local radius = 9 + 3 * level + c.scale() * 1.8 + Powers.junkCount() * 0.8
		c.fx("slam")
		c.shake(r.Position, radius * 2.5, 1)
		c.knockProps(2.6)
		local hit = 0
		for _, plr in c.playersWithin(radius) do
			if c.knockback(plr, r.Position, 55 + level * 8) then
				hit += 1
			end
		end
		if hit > 0 then
			c.clip("baby_slam")
		end
		c.setDazed(Config.Powers.DazedSeconds)
	end
end

-- SUGAR RUSH: vibrate (tell) -> speed burst; while zooming, touching Baby bowls you over.
runners.SugarRush = function(c: Ctx, level: number)
	local def = PowerCatalog.get("SugarRush")
	if not def then
		return
	end
	local speed = Config.Powers.SugarSpeed[math.clamp(level, 1, #Config.Powers.SugarSpeed)]
	local zooming = false
	local lastHit: { [Player]: number } = {}
	local r = c.root()
	local conn = r
		and r.Touched:Connect(function(hit)
			if not zooming then
				return
			end
			local plr = Players:GetPlayerFromCharacter(hit.Parent)
			local rr = c.root()
			if not plr or not rr or (lastHit[plr] or 0) > os.clock() - 1.5 then
				return
			end
			lastHit[plr] = os.clock()
			if c.knockback(plr, rr.Position, 50) then
				c.say("BONK", 1)
				c.fx("bonk")
				c.clip("baby_bonk")
			end
		end)
	task.wait(rng:NextNumber(3, 6))
	while running do
		local interval = PowerCatalog.interval(def, level)
		task.wait(rng:NextNumber(interval * 0.8, interval * 1.2))
		if not running or c.busy() then
			continue
		end
		c.say("...", tellDelay())
		c.fx("tell_zoom")
		attr(c, "Tell", "SugarRush")
		task.wait(tellDelay())
		attr(c, "Tell", "")
		if not running or c.busy() then
			continue
		end
		zooming = true
		c.setBehavior("Zoom")
		c.say("ZOOOOM!!", 2)
		c.fx("zoom")
		c.setPowerSpeed(speed)
		attr(c, "Zooming", true)
		local deadline = os.clock() + 5 + level * 1.5
		while running and os.clock() < deadline do
			task.wait(0.4)
			if not c.busy() then
				c.knockProps(1.4)
			end
		end
		zooming = false
		c.setPowerSpeed(1)
		local m = c.model()
		if m then
			m:SetAttribute("Zooming", false)
		end
		if running and not c.busy() then
			c.setBehavior("Idle")
		end
	end
	if conn then
		conn:Disconnect()
	end
end

-- STICKY: furniture within reach glues onto Baby (junk-ball); babysitters who touch it get stuck.
runners.Sticky = function(c: Ctx, level: number)
	local maxProps = Config.Powers.MaxStuckProps[math.clamp(level, 1, #Config.Powers.MaxStuckProps)]
	local stuckFor = Config.Powers.StuckSeconds[math.clamp(level, 1, #Config.Powers.StuckSeconds)]
	local r = c.root()
	local m = c.model()
	if m then
		m:SetAttribute("Sticky", true)
	end
	local conn = r
		and r.Touched:Connect(function(hit)
			if not running or os.clock() < slipperyUntil or c.busy() then
				return
			end
			local plr = Players:GetPlayerFromCharacter(hit.Parent)
			local rr = c.root()
			if not plr or not rr or stuckPlayers[plr] then
				return
			end
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hrp or not hum or hum.PlatformStand then
				return
			end
			hum.PlatformStand = true
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			hrp.CFrame = rr.CFrame
				* CFrame.new(side * c.scale() * 1.25, c.scale() * 0.6, 0)
				* CFrame.Angles(0, math.rad(90 * side), math.rad(180))
			local w = Instance.new("WeldConstraint")
			w.Name = "StickyWeld"
			w.Part0 = rr
			w.Part1 = hrp
			w.Parent = hrp
			stuckPlayers[plr] = { weld = w, until_ = os.clock() + stuckFor, humanoid = hum }
			c.say("MINE.", 2)
			c.fx("stick")
			c.clip("baby_stuck")
			c.toastAll(("%s is STUCK to Baby! Soap Gun, or wait %ds"):format(plr.Name, stuckFor), "warn")
		end)
	task.wait(1)
	while running do
		task.wait(1)
		-- Timed release
		for plr, s in stuckPlayers do
			if os.clock() >= s.until_ or not plr.Parent or not s.humanoid.Parent then
				releasePlayer(plr, true)
				if plr.Parent then
					c.fx("unstick")
				end
			end
		end
		if c.busy() or os.clock() < slipperyUntil then
			continue
		end
		local rr = c.root()
		local map = workspace:FindFirstChild("Map")
		local props = map and map:FindFirstChild("Props")
		if not rr or not props then
			continue
		end
		if rng:NextNumber() < 0.25 then
			c.say("*drool*", 1.5)
		end
		local reach = 2.6 * c.scale()
		for _, prop in props:GetChildren() do
			if Powers.junkCount() >= maxProps then
				break
			end
			if prop:IsA("BasePart") and not stuckProps[prop] and (prop.Position - rr.Position).Magnitude < reach then
				local angle = rng:NextNumber(0, math.pi * 2)
				local offset = CFrame.new(
					math.cos(angle) * c.scale() * 1.3,
					rng:NextNumber(-0.4, 1.2) * c.scale(),
					math.sin(angle) * c.scale() * 1.3
				) * CFrame.Angles(rng:NextNumber(0, 2), rng:NextNumber(0, 2), rng:NextNumber(0, 2))
				prop.Anchored = false
				prop.CanCollide = false
				prop.Massless = true
				prop.CFrame = rr.CFrame * offset
				local w = Instance.new("WeldConstraint")
				w.Name = "StickyWeld"
				w.Part0 = rr
				w.Part1 = prop
				w.Parent = prop
				stuckProps[prop] = w
				prop:SetAttribute("Knocked", true)
				prop:SetAttribute("Stuck", true)
				c.fx("stick")
				if Powers.junkCount() == maxProps then
					c.say("JUNK BALL!!", 2)
					c.clip("junk_ball")
				end
			end
		end
	end
	if conn then
		conn:Disconnect()
	end
	if m and m.Parent then
		m:SetAttribute("Sticky", false)
	end
end

-- LOUD: when fussy+, inhale (tell) -> SCREAM: shatters a window (chore undone) + blows players back.
runners.Loud = function(c: Ctx, level: number)
	local def = PowerCatalog.get("Loud")
	if not def then
		return
	end
	task.wait(rng:NextNumber(5, 9))
	while running do
		local interval = PowerCatalog.interval(def, level)
		task.wait(rng:NextNumber(interval * 0.8, interval * 1.2))
		if not running or c.busy() or c.moodIndex() < 3 then
			continue
		end
		local r = c.root()
		if not r then
			continue
		end
		c.say("*inhaaaale*", tellDelay())
		c.fx("tell_loud")
		attr(c, "Tell", "Loud")
		task.wait(tellDelay())
		attr(c, "Tell", "")
		if not running or c.busy() then
			continue
		end
		c.setBehavior("Scream")
		c.say("WAAAAAAAAAAA!!!", 2.5)
		c.fx("scream")
		local radius = 12 + 4 * level + c.scale() * 2
		c.shake(r.Position, radius * 3, 0.8)
		for _, plr in c.playersWithin(radius) do
			c.knockback(plr, r.Position, 40 + level * 6)
		end
		local messed = c.messUp()
		if messed then
			c.toastAll(("Baby's scream shattered the windows — %s is undone!"):format(messed), "warn")
		end
		c.clip("baby_scream")
		task.wait(2)
		if running and not c.busy() then
			c.setBehavior("Idle")
		end
	end
end

-- Lifecycle -------------------------------------------------------------------------------------------
function Powers.start(c: Ctx, picks: { { id: string, level: number } })
	Powers.stop()
	ctx = c
	running = true
	levels = {}
	slipperyUntil = 0
	local ids = {}
	for _, p in picks do
		levels[p.id] = p.level
		table.insert(ids, p.id)
		local runner = runners[p.id]
		if runner then
			table.insert(
				threads,
				task.spawn(function()
					runner(c, p.level)
				end)
			)
		end
	end
	local m = c.model()
	if m then
		m:SetAttribute("Powers", table.concat(ids, ","))
	end
end

function Powers.stop()
	running = false
	for _, t in threads do
		pcall(task.cancel, t)
	end
	table.clear(threads)
	Powers.unstickAll()
	local m = ctx and ctx.model()
	if m and m.Parent then
		m:SetAttribute("Zooming", false)
		m:SetAttribute("Sticky", false)
		m:SetAttribute("Tell", "")
	end
	ctx = nil
	levels = {}
end

Players.PlayerRemoving:Connect(function(plr)
	releasePlayer(plr, false)
end)

return Powers

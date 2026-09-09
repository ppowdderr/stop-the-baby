--!strict
-- Picks the night's chores, runs hold-to-complete progress, validates distance to stations.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local ChoreCatalog = require(Shared:WaitForChild("ChoreCatalog"))
local NightTable = require(Shared:WaitForChild("NightTable"))
local EconomyService = require(script.Parent.EconomyService)

export type ActiveChore = {
	id: string,
	def: ChoreCatalog.ChoreDef,
	progress: number, -- 0..1
	done: boolean,
	worker: Player?,
	messedUp: boolean, -- baby undid it
}

local ChoreService = {}
ChoreService.AllDone = Signal.new() :: Signal.Signal<()>
ChoreService.ChoreCompleted = Signal.new() :: Signal.Signal<Player, string>

local active: { [string]: ActiveChore } = {}
local order: { string } = {}
local rng = Random.new()
local running = false
local bedtimeUnlocked = false

local STATION_RANGE = 14

local function stationPart(name: string): BasePart?
	local map = workspace:FindFirstChild("Map")
	local stations = map and map:FindFirstChild("Stations")
	local st = stations and stations:FindFirstChild(name)
	if st and st:IsA("BasePart") then
		return st
	elseif st and st:IsA("Model") then
		return st.PrimaryPart or st:FindFirstChildWhichIsA("BasePart")
	end
	return nil
end

local function playerNear(player: Player, part: BasePart): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	return (root.Position - part.Position).Magnitude <= STATION_RANGE * math.max(1, part.Size.Magnitude / 8)
end

local function dto()
	local list = {}
	for _, id in order do
		local c = active[id]
		table.insert(list, {
			id = c.id,
			name = c.def.name,
			station = c.def.station,
			verb = c.def.verb,
			progress = c.progress,
			done = c.done,
			worker = if c.worker then c.worker.Name else nil,
			messedUp = c.messedUp,
			isBedtime = c.id == ChoreCatalog.Bedtime.id,
		})
	end
	return list
end

function ChoreService.broadcast()
	Net.event("ChoreList"):FireAllClients(dto())
end

function ChoreService.remaining(): number
	local n = 0
	for _, c in active do
		if not c.done and c.id ~= ChoreCatalog.Bedtime.id then
			n += 1
		end
	end
	return n
end

function ChoreService.isBedtimeDone(): boolean
	local b = active[ChoreCatalog.Bedtime.id]
	return b ~= nil and b.done
end

function ChoreService.completionFraction(): number
	local total, done = 0, 0
	for _, c in active do
		total += 1
		if c.done then
			done += 1
		end
	end
	return if total == 0 then 0 else done / total
end

function ChoreService.setup(night: number)
	active = {}
	order = {}
	bedtimeUnlocked = false
	local info = NightTable.get(night)
	local pool = ChoreCatalog.available(night, info.areas)
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	for i = 1, math.min(info.choreCount, #pool) do
		local def = pool[i]
		active[def.id] = { id = def.id, def = def, progress = 0, done = false, worker = nil, messedUp = false }
		table.insert(order, def.id)
	end
	local bt = ChoreCatalog.Bedtime
	active[bt.id] = { id = bt.id, def = bt, progress = 0, done = false, worker = nil, messedUp = false }
	table.insert(order, bt.id)
	running = true
	ChoreService.broadcast()
end

function ChoreService.stop()
	running = false
	for _, c in active do
		c.worker = nil
	end
end

function ChoreService.unlockBedtime()
	bedtimeUnlocked = true
	Net.event("Toast"):FireAllClients("BEDTIME! Get Baby to the crib!", "warn")
	ChoreService.broadcast()
end

-- Baby "undoes" a random completed chore (Destroy behavior)
function ChoreService.messUp(): string?
	local candidates = {}
	for id, c in active do
		if c.done and id ~= ChoreCatalog.Bedtime.id then
			table.insert(candidates, c)
		end
	end
	if #candidates == 0 then
		return nil
	end
	local c = candidates[rng:NextInteger(1, #candidates)]
	c.done = false
	c.progress = 0
	c.messedUp = true
	ChoreService.broadcast()
	return c.def.name
end

local function tryStart(player: Player, choreId: string, canBedtime: () -> boolean)
	if not running then
		return
	end
	local c = active[choreId]
	if not c or c.done or (c.worker and c.worker ~= player) then
		return
	end
	if c.id == ChoreCatalog.Bedtime.id and (not bedtimeUnlocked or not canBedtime()) then
		Net.event("Toast"):FireClient(player, "Not bedtime yet — and Baby must be calm!", "error")
		return
	end
	for _, other in active do
		if other.worker == player then
			other.worker = nil
		end
	end
	local part = stationPart(c.def.station)
	if part and not playerNear(player, part) then
		return
	end
	c.worker = player
	ChoreService.broadcast()
end

local function stopWorking(player: Player, choreId: string?)
	for id, c in active do
		if c.worker == player and (choreId == nil or id == choreId) then
			c.worker = nil
		end
	end
	ChoreService.broadcast()
end

function ChoreService.start(canBedtime: () -> boolean)
	Net.event("StartChore").OnServerEvent:Connect(function(player, choreId)
		if Net.allow(player, "Chore", 6) and type(choreId) == "string" then
			tryStart(player, choreId, canBedtime)
		end
	end)
	Net.event("StopChore").OnServerEvent:Connect(function(player, choreId)
		if Net.allow(player, "Chore", 6) then
			stopWorking(player, if type(choreId) == "string" then choreId else nil)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		stopWorking(player)
	end)

	-- Progress tick
	task.spawn(function()
		while true do
			local dt = task.wait(0.25)
			if not running then
				continue
			end
			local changed = false
			for _, c in active do
				local w = c.worker
				if w and not c.done then
					local part = stationPart(c.def.station)
					if not w.Parent or (part and not playerNear(w, part)) then
						c.worker = nil
						changed = true
						continue
					end
					c.progress = math.min(1, c.progress + dt / c.def.holdTime)
					changed = true
					if c.progress >= 1 then
						c.done = true
						c.messedUp = false
						c.worker = nil
						EconomyService.addCoins(w, Config.Economy.ChoreReward, true)
						ChoreService.ChoreCompleted:Fire(w, c.id)
						if ChoreService.remaining() == 0 and not bedtimeUnlocked then
							ChoreService.unlockBedtime()
						end
						if ChoreService.isBedtimeDone() then
							ChoreService.AllDone:Fire()
						end
					end
				end
			end
			if changed then
				ChoreService.broadcast()
			end
		end
	end)
end

return ChoreService

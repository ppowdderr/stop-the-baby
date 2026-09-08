--!strict
-- Player persistence with session locking (UpdateAsync), retries, autosave and BindToClose flush.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signal = require(Shared:WaitForChild("Signal"))

export type ItemRecord = {
	uid: string,
	id: string,
	mutation: string?,
	favorite: boolean?,
	obtained: number,
}

export type Profile = {
	version: number,
	coins: number,
	stars: number,
	highestNight: number,
	rebirths: number,
	inventory: { ItemRecord },
	nursery: { [string]: string }, -- slotIndex (as string) -> uid
	nurserySlots: number,
	redeemedCodes: { [string]: boolean },
	lastSeen: number,
	lastGroupGift: number,
	babyBook: { [string]: number }, -- firstId -> unix time
	stats: { nightsPlayed: number, nightsFailed: number, toysUsed: number, boxesOpened: number, swallowed: number },
	passes: { [string]: boolean },
	luckBoostUntil: number,
}

local DATASTORE_NAME = "StopTheBaby_v1"
local LOCK_TTL = 90 -- seconds a session lock is considered live
local AUTOSAVE_INTERVAL = 60

local DataService = {}
DataService.ProfileLoaded = Signal.new() :: Signal.Signal<Player, Profile>
DataService.ProfileReleased = Signal.new() :: Signal.Signal<Player, Profile>

local store = DataStoreService:GetDataStore(DATASTORE_NAME)
local profiles: { [Player]: Profile } = {}
local locked: { [Player]: boolean } = {}
local sessionId = game.JobId ~= "" and game.JobId or ("studio-" .. tostring(math.random(1, 1e9)))

local function defaultProfile(): Profile
	return {
		version = 1,
		coins = 0,
		stars = 0,
		highestNight = 0,
		rebirths = 0,
		inventory = {},
		nursery = {},
		nurserySlots = 6,
		redeemedCodes = {},
		lastSeen = os.time(),
		lastGroupGift = 0,
		babyBook = {},
		stats = { nightsPlayed = 0, nightsFailed = 0, toysUsed = 0, boxesOpened = 0, swallowed = 0 },
		passes = {},
		luckBoostUntil = 0,
	}
end

local function reconcile(p: any): Profile
	local d = defaultProfile()
	for k, v in d :: any do
		if p[k] == nil then
			p[k] = v
		end
	end
	for k, v in d.stats :: any do
		if p.stats[k] == nil then
			p.stats[k] = v
		end
	end
	return p :: Profile
end

local function key(userId: number): string
	return "u_" .. tostring(userId)
end

local function retry<T>(attempts: number, fn: () -> T): (boolean, T?)
	local ok, res
	for i = 1, attempts do
		ok, res = pcall(fn)
		if ok then
			return true, res
		end
		warn("[DataService] attempt", i, "failed:", res)
		task.wait(1.5 * i)
	end
	return false, nil
end

-- Attempts to acquire a lock and load. Returns profile or nil (kick) on failure.
local function load(player: Player): Profile?
	local userId = player.UserId
	local result: Profile? = nil
	local lockedByOther = false
	local ok = retry(3, function()
		store:UpdateAsync(key(userId), function(old)
			old = old or {}
			local lock = old.lock
			if lock and lock.session ~= sessionId and (os.time() - (lock.time or 0)) < LOCK_TTL then
				lockedByOther = true
				return nil -- abort, don't write
			end
			local data = reconcile(old.data or defaultProfile())
			result = data
			return { data = data, lock = { session = sessionId, time = os.time() } }
		end)
		return true
	end)
	if not ok then
		return nil
	end
	if lockedByOther then
		return nil
	end
	return result
end

local function save(player: Player, release: boolean)
	local profile = profiles[player]
	if not profile or not locked[player] then
		return
	end
	profile.lastSeen = os.time()
	local snapshot = table.clone(profile)
	retry(3, function()
		store:UpdateAsync(key(player.UserId), function(old)
			old = old or {}
			local lock = old.lock
			if lock and lock.session ~= sessionId and (os.time() - (lock.time or 0)) < LOCK_TTL then
				return nil -- someone else owns it now; don't clobber
			end
			return {
				data = snapshot,
				lock = if release then nil else { session = sessionId, time = os.time() },
			}
		end)
		return true
	end)
end

function DataService.get(player: Player): Profile?
	return profiles[player]
end

-- Yields until the profile is available (or the player leaves).
function DataService.waitFor(player: Player): Profile?
	while player.Parent and not profiles[player] do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.recordFirst(profile: Profile, firstId: string): boolean
	if profile.babyBook[firstId] then
		return false
	end
	profile.babyBook[firstId] = os.time()
	return true
end

local function onPlayerAdded(player: Player)
	local profile = load(player)
	if not profile then
		if RunService:IsStudio() then
			warn("[DataService] Studio fallback profile for", player.Name)
			profile = defaultProfile()
			locked[player] = false
		else
			player:Kick("Your data is still saving from another server. Please rejoin in a minute.")
			return
		end
	else
		locked[player] = true
	end
	profiles[player] = profile
	DataService.ProfileLoaded:Fire(player, profile)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		DataService.ProfileReleased:Fire(player, profile)
		save(player, true)
	end
	profiles[player] = nil
	locked[player] = nil
end

function DataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				save(player, false)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				save(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
end

return DataService

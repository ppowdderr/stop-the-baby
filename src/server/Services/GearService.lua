--!strict
-- Gear ownership, 4-slot loadout, per-night charges, use validation, fusion, and the physical
-- drop pickups the Baby leaves behind (coins or gear). Effects themselves live in BabyAI, which
-- registers a use handler here so this file never has to know about the Baby.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local GearCatalog = require(Shared:WaitForChild("GearCatalog"))
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local GearService = {}

local rng = Random.new()
local MAX_GEAR = 120

type UseHandler = (player: Player, rec: DataService.GearRecord, def: GearCatalog.GearDef) -> boolean
local useHandler: UseHandler? = nil

-- Per-night state
local charges: { [Player]: { [string]: number } } = {}
local nightPowers: { string } = {}
local nightDropMult = 1
local nightNumber = 1
local nightActive = false
local pickupsFolder: Folder? = nil

local function toast(player: Player, text: string, kind: string?)
	Net.event("Toast"):FireClient(player, text, kind or "info")
end

local function toastAll(text: string, kind: string?)
	Net.event("Toast"):FireAllClients(text, kind or "info")
end

function GearService.setUseHandler(handler: UseHandler)
	useHandler = handler
end

-- Replication --------------------------------------------------------------------------------
function GearService.replicate(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	Net.event("GearChanged"):FireClient(player, profile.gear, profile.loadout)
end

local function replicateCharges(player: Player)
	Net.event("GearState"):FireClient(player, charges[player] or {})
end

function GearService.find(profile: DataService.Profile, uid: string): (DataService.GearRecord?, number?)
	for i, rec in profile.gear do
		if rec.uid == uid then
			return rec, i
		end
	end
	return nil, nil
end

-- Granting -----------------------------------------------------------------------------------
function GearService.grant(player: Player, gearId: string, tier: string, silent: boolean?): DataService.GearRecord?
	local profile = DataService.get(player)
	local def = GearCatalog.get(gearId)
	if not profile or not def then
		return nil
	end
	if #profile.gear >= MAX_GEAR then
		toast(player, "Gear bag full! Fuse some gear.", "error")
		return nil
	end
	local rec: DataService.GearRecord = {
		uid = HttpService:GenerateGUID(false),
		id = gearId,
		tier = tier,
		obtained = os.time(),
	}
	table.insert(profile.gear, rec)
	profile.stats.gearFound += 1
	DataService.recordFirst(profile, "gear_" .. gearId)
	-- Auto-equip into the first free slot so a new piece is usable the very next night.
	local equipped = false
	for slot = 1, GearCatalog.MaxLoadout do
		if profile.loadout[tostring(slot)] == nil then
			profile.loadout[tostring(slot)] = rec.uid
			equipped = true
			break
		end
	end
	if not silent then
		toast(
			player,
			("%s NEW GEAR: %s%s"):format(
				def.emoji,
				GearCatalog.displayName(gearId, tier),
				if equipped then " (equipped)" else ""
			),
			tier
		)
	end
	GearService.replicate(player)
	return rec
end

-- Rolls a gear tier: TierOdds shifted toward Rare+ by night, with an optional floor.
function GearService.rollTier(night: number, minTier: string?): string
	local odds = table.clone(Config.Drops.TierOdds)
	local shift = math.min(30, night * Config.Drops.TierBonusPerNight)
	odds[1] = math.max(5, odds[1] - shift)
	odds[3] += shift * 0.6
	odds[4] += shift * 0.3
	odds[5] += shift * 0.1
	local total = 0
	for _, w in odds do
		total += w
	end
	local roll = rng:NextNumber() * total
	local tier = GearCatalog.Tiers[1]
	for i, w in odds do
		roll -= w
		if roll <= 0 then
			tier = GearCatalog.Tiers[i]
			break
		end
	end
	if minTier and GearCatalog.tierIndex(tier) < GearCatalog.tierIndex(minTier) then
		tier = minTier
	end
	return tier
end

-- Picks which gear drops: biased toward counters for tonight's powers so grinding a power
-- farms its own answer.
function GearService.rollGearId(powerIds: { string }): string
	local counters = GearCatalog.countersFor(powerIds)
	if #counters > 0 and rng:NextNumber() < Config.Drops.CounterBias then
		return counters[rng:NextInteger(1, #counters)].id
	end
	return GearCatalog.List[rng:NextInteger(1, #GearCatalog.List)].id
end

function GearService.rollGear(
	player: Player,
	night: number,
	minTier: string?,
	silent: boolean?
): DataService.GearRecord?
	local id = GearService.rollGearId(nightPowers)
	local tier = GearService.rollTier(night, minTier)
	if GearCatalog.tierIndex(tier) >= GearCatalog.tierIndex("Epic") then
		Net.event("ClipMoment"):FireClient(player, "gear_drop")
	end
	return GearService.grant(player, id, tier, silent)
end

-- Loadout ------------------------------------------------------------------------------------
function GearService.equip(player: Player, slot: number, uid: string?)
	local profile = DataService.get(player)
	if not profile or slot < 1 or slot > GearCatalog.MaxLoadout then
		return
	end
	if uid ~= nil then
		local rec = GearService.find(profile, uid)
		if not rec then
			return
		end
		for s, other in profile.loadout do
			if other == uid then
				profile.loadout[s] = nil
			end
		end
	end
	profile.loadout[tostring(slot)] = uid
	GearService.replicate(player)
end

function GearService.loadout(player: Player): { DataService.GearRecord }
	local profile = DataService.get(player)
	local out = {}
	if not profile then
		return out
	end
	for slot = 1, GearCatalog.MaxLoadout do
		local uid = profile.loadout[tostring(slot)]
		local rec = if uid then GearService.find(profile, uid) else nil
		if rec then
			table.insert(out, rec)
		end
	end
	return out
end

-- Best equipped tier index (0 = none) of a passive/active gear for one player.
function GearService.tierOf(player: Player, gearId: string): number
	local best = 0
	for _, rec in GearService.loadout(player) do
		if rec.id == gearId then
			best = math.max(best, GearCatalog.tierIndex(rec.tier))
		end
	end
	return best
end

-- Whether a player is protected by Ear Muffs: their own, or a teammate's Rare+ pair within its shield radius.
function GearService.protected(player: Player): boolean
	if GearService.tierOf(player, "EarMuffs") > 0 then
		return true
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local def = GearCatalog.get("EarMuffs")
	if not def then
		return false
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local t = GearService.tierOf(other, "EarMuffs")
			local radius = if t > 0 then def.power[t] else 0
			local oChar = other.Character
			local oRoot = oChar and oChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			if radius > 0 and oRoot and (oRoot.Position - root.Position).Magnitude <= radius then
				return true
			end
		end
	end
	return false
end

-- Team-wide mood-decay multiplier from the best Baby Monitor in the server (1 = none).
function GearService.moodDecayMultiplier(): number
	local def = GearCatalog.get("BabyMonitor")
	if not def then
		return 1
	end
	local best = 0
	for _, plr in Players:GetPlayers() do
		best = math.max(best, GearService.tierOf(plr, "BabyMonitor"))
	end
	if best == 0 then
		return 1
	end
	return 1 - def.power[best] / 100
end

-- Charges -------------------------------------------------------------------------------------
local function loadCharges(plr: Player)
	local c = {}
	for _, rec in GearService.loadout(plr) do
		local def = GearCatalog.get(rec.id)
		if def and def.kind == "Active" then
			c[rec.uid] = GearCatalog.charges(def, rec.tier)
		end
	end
	charges[plr] = c
	replicateCharges(plr)
end

function GearService.beginNight(night: number, powerIds: { string }, dropMult: number)
	nightNumber = night
	nightPowers = powerIds
	nightDropMult = dropMult
	nightActive = true
	charges = {}
	for _, plr in Players:GetPlayers() do
		loadCharges(plr)
	end
end

function GearService.endNight()
	nightActive = false
	charges = {}
	for _, plr in Players:GetPlayers() do
		replicateCharges(plr)
	end
	GearService.clearPickups()
end

local function use(player: Player, uid: string)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local rec = GearService.find(profile, uid)
	local def = rec and GearCatalog.get(rec.id)
	if not rec or not def or def.kind ~= "Active" then
		return
	end
	local c = charges[player]
	if not c or (c[uid] or 0) <= 0 then
		toast(player, ("%s is out of charges tonight."):format(def.name), "error")
		return
	end
	local handler = useHandler
	if not handler or not handler(player, rec, def) then
		return
	end
	c[uid] -= 1
	replicateCharges(player)
end

-- Fusion: 3 identical pieces -> 1 of the next tier ---------------------------------------------
function GearService.fuse(player: Player, gearId: string, tier: string)
	local profile = DataService.get(player)
	local def = GearCatalog.get(gearId)
	local ti = GearCatalog.tierIndex(tier)
	if not profile or not def or ti >= #GearCatalog.Tiers then
		return
	end
	local matches = {}
	for i, rec in profile.gear do
		if rec.id == gearId and rec.tier == tier then
			table.insert(matches, i)
		end
	end
	if #matches < GearCatalog.FuseCount then
		toast(
			player,
			("Need %d %s to fuse."):format(GearCatalog.FuseCount, GearCatalog.displayName(gearId, tier)),
			"error"
		)
		return
	end
	-- Remove from the end so earlier indices stay valid; free any loadout slots they held.
	for k = GearCatalog.FuseCount, 1, -1 do
		local idx = matches[k]
		local rec = profile.gear[idx]
		for s, other in profile.loadout do
			if other == rec.uid then
				profile.loadout[s] = nil
			end
		end
		table.remove(profile.gear, idx)
	end
	local nextTier = GearCatalog.Tiers[ti + 1]
	GearService.grant(player, gearId, nextTier)
	Net.event("ClipMoment"):FireClient(player, "gear_fuse")
end

-- Physical pickups ------------------------------------------------------------------------------
local function folder(): Folder
	local f = pickupsFolder
	if f and f.Parent then
		return f
	end
	f = Instance.new("Folder")
	f.Name = "Pickups"
	f.Parent = workspace
	pickupsFolder = f
	return f
end

function GearService.clearPickups()
	local f = pickupsFolder
	if f then
		f:ClearAllChildren()
	end
end

local function claim(player: Player, kind: string)
	if kind == "Coins" then
		local amount = rng:NextInteger(Config.Drops.CoinsRange.min, Config.Drops.CoinsRange.max)
		amount = math.floor(amount * nightDropMult)
		EconomyService.addCoins(player, amount, true)
	else
		local rec = GearService.rollGear(player, nightNumber, nil, true)
		if rec then
			local def = GearCatalog.get(rec.id)
			local name = GearCatalog.displayName(rec.id, rec.tier)
			if GearCatalog.tierIndex(rec.tier) >= GearCatalog.tierIndex("Rare") then
				toastAll(("%s found %s %s!"):format(player.Name, def and def.emoji or "", name), rec.tier)
			else
				toast(player, ("%s Found: %s"):format(def and def.emoji or "", name), rec.tier)
			end
		end
	end
end

-- Spawns a bouncing pickup box anyone can touch. `kind` = "Coins" | "Gear".
function GearService.spawnPickup(position: Vector3, kind: string)
	local box = Instance.new("Part")
	box.Name = kind .. "Pickup"
	box.Size = Vector3.new(1.6, 1.6, 1.6)
	box.Shape = Enum.PartType.Block
	box.Material = Enum.Material.SmoothPlastic
	box.Color = if kind == "Gear" then Color3.fromRGB(255, 120, 200) else Color3.fromRGB(255, 205, 60)
	box.CanCollide = false
	box.Anchored = true
	box.CastShadow = false
	box.CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-2, 2), 2, rng:NextNumber(-2, 2)))
	local light = Instance.new("PointLight")
	light.Color = box.Color
	light.Range = 8
	light.Brightness = 1.5
	light.Parent = box
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 44)
	gui.StudsOffset = Vector3.new(0, 1.8, 0)
	gui.AlwaysOnTop = true
	gui.Parent = box
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = if kind == "Gear" then "🎁 GEAR!" else "🪙"
	label.Parent = gui

	local taken = false
	box.Touched:Connect(function(hit)
		if taken then
			return
		end
		local plr = Players:GetPlayerFromCharacter(hit.Parent)
		if not plr then
			return
		end
		taken = true
		box:Destroy()
		claim(plr, kind)
	end)
	box.Parent = folder()
	TweenService:Create(
		box,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = box.CFrame * CFrame.new(0, 1, 0) * CFrame.Angles(0, math.rad(90), 0) }
	):Play()
	task.delay(Config.Drops.PickupLifetime, function()
		if box.Parent then
			box:Destroy()
		end
	end)
end

-- Drop hooks used by the Baby ---------------------------------------------------------------------
function GearService.onPropSmashed(position: Vector3)
	local mult = nightDropMult
	if rng:NextNumber() < Config.Drops.PropGearChance * mult then
		GearService.spawnPickup(position, "Gear")
	elseif rng:NextNumber() < Config.Drops.PropCoinChance * mult then
		GearService.spawnPickup(position, "Coins")
	end
end

-- Returns true when the snack produced a burp drop.
function GearService.onSnackFed(position: Vector3): boolean
	if rng:NextNumber() >= Config.Drops.BurpChance then
		return false
	end
	local gear = rng:NextNumber() < math.min(0.9, Config.Drops.BurpGearChance * nightDropMult)
	GearService.spawnPickup(position, if gear then "Gear" else "Coins")
	return true
end

function GearService.start()
	DataService.ProfileLoaded:Connect(function(player)
		GearService.replicate(player)
		if nightActive then
			loadCharges(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		charges[player] = nil
	end)
	Net.event("UseGear").OnServerEvent:Connect(function(player, uid)
		if Net.allow(player, "UseGear", 4) and type(uid) == "string" then
			use(player, uid)
		end
	end)
	Net.event("EquipGear").OnServerEvent:Connect(function(player, slot, uid)
		if Net.allow(player, "EquipGear", 6) and type(slot) == "number" and (uid == nil or type(uid) == "string") then
			GearService.equip(player, math.floor(slot), uid)
		end
	end)
	Net.event("FuseGear").OnServerEvent:Connect(function(player, gearId, tier)
		if Net.allow(player, "FuseGear", 3) and type(gearId) == "string" and type(tier) == "string" then
			GearService.fuse(player, gearId, tier)
		end
	end)
end

-- Rarity colors are shared with gear tiers; exposed for toasts.
GearService.tierColor = function(tier: string): Color3
	return Rarity.Colors[tier :: Rarity.RarityName] or Rarity.Colors.Common
end

return GearService

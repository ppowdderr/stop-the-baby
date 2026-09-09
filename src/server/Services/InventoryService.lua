--!strict
-- Toy/snack inventory, Toy Box RNG (server-side), mutations, selling, nursery slots, replication.
local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local ToyCatalog = require(Shared:WaitForChild("ToyCatalog"))
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local InventoryService = {}

local rng = Random.new()
local MAX_INVENTORY = 200

local function toast(player: Player, text: string, kind: string?)
	Net.event("Toast"):FireClient(player, text, kind or "info")
end

function InventoryService.replicate(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	Net.event("InventoryChanged"):FireClient(player, {
		inventory = profile.inventory,
		coins = profile.coins,
		stars = profile.stars,
		highestNight = profile.highestNight,
		rebirths = profile.rebirths,
		nursery = profile.nursery,
		nurserySlots = profile.nurserySlots,
		canRebirth = EconomyService.canRebirth(profile),
	})
end

function InventoryService.find(profile: DataService.Profile, uid: string): (DataService.ItemRecord?, number?)
	for i, rec in profile.inventory do
		if rec.uid == uid then
			return rec, i
		end
	end
	return nil, nil
end

local function rollMutation(eventOk: boolean): string?
	if rng:NextNumber() > Config.MutationChance then
		return nil
	end
	local pool = {}
	for _, m in ToyCatalog.Mutations do
		if not m.eventOnly or eventOk then
			table.insert(pool, m)
		end
	end
	return pool[rng:NextInteger(1, #pool)].id
end

-- Grants a specific item. Returns the record.
function InventoryService.grant(
	player: Player,
	itemId: string,
	mutationId: string?,
	silent: boolean?
): DataService.ItemRecord?
	local profile = DataService.get(player)
	local def = ToyCatalog.get(itemId)
	if not profile or not def then
		return nil
	end
	if #profile.inventory >= MAX_INVENTORY then
		toast(player, "Toy chest full! Sell some toys.", "error")
		return nil
	end
	local rec: DataService.ItemRecord = {
		uid = HttpService:GenerateGUID(false),
		id = itemId,
		mutation = mutationId,
		obtained = os.time(),
	}
	table.insert(profile.inventory, rec)
	local firstKey = "first_" .. def.rarity
	if DataService.recordFirst(profile, firstKey) and Rarity.index(def.rarity) >= Rarity.index("Rare") then
		Net.event("ClipMoment"):FireClient(player, "first_" .. def.rarity)
	end
	if mutationId then
		DataService.recordFirst(profile, "mutation_" .. mutationId)
	end
	if not silent then
		local name = ToyCatalog.displayName(itemId, mutationId)
		toast(player, ("You got: %s %s (%s)"):format(def.emoji, name, def.rarity), def.rarity)
	end
	InventoryService.replicate(player)
	return rec
end

-- Rolls a random item. legendaryBonus in % points; lucky players get a reroll on Common.
function InventoryService.rollItem(
	player: Player,
	legendaryBonus: number?,
	kind: ToyCatalog.ItemKind?
): DataService.ItemRecord?
	local rarity = Rarity.roll(rng, legendaryBonus)
	if rarity == "Common" and EconomyService.hasLuck(player) then
		rarity = Rarity.roll(rng, legendaryBonus)
	end
	local pool = ToyCatalog.itemsOfRarity(rarity, kind)
	if #pool == 0 then
		pool = ToyCatalog.itemsOfRarity(rarity)
	end
	local def = pool[rng:NextInteger(1, #pool)]
	return InventoryService.grant(player, def.id, rollMutation(false))
end

function InventoryService.openToyBoxes(player: Player, count: number, free: boolean)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	count = math.clamp(math.floor(count), 1, 10)
	if not free then
		if not EconomyService.spendCoins(player, Config.Economy.ToyBoxCost * count) then
			toast(player, "Not enough Diaper Coins.", "error")
			return
		end
	end
	profile.stats.boxesOpened += count
	for _ = 1, count do
		InventoryService.rollItem(player, 0)
	end
end

function InventoryService.sell(player: Player, uid: string)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local rec, idx = InventoryService.find(profile, uid)
	if not rec or not idx then
		return
	end
	if rec.favorite then
		toast(player, "Un-favorite it first!", "error")
		return
	end
	for slot, slotUid in profile.nursery do
		if slotUid == uid then
			profile.nursery[slot] = nil
		end
	end
	local def = ToyCatalog.get(rec.id)
	local value = if def then Rarity.SellValue[def.rarity] else 0
	if rec.mutation then
		local m = ToyCatalog.getMutation(rec.mutation)
		if m then
			value = math.floor(value * m.valueMult)
		end
	end
	table.remove(profile.inventory, idx)
	EconomyService.addCoins(player, value, false)
	toast(player, ("Sold for %d Diaper Coins"):format(value), "coins")
	InventoryService.replicate(player)
end

-- Consumes an item and returns its soothe effect (stages, immunity) or nil.
function InventoryService.consume(player: Player, uid: string): (number?, number?, ToyCatalog.ItemDef?)
	local profile = DataService.get(player)
	if not profile then
		return nil
	end
	local rec, idx = InventoryService.find(profile, uid)
	if not rec or not idx then
		return nil
	end
	local def = ToyCatalog.get(rec.id)
	if not def then
		return nil
	end
	local soothe = Rarity.Soothe[def.rarity]
	local stages, immunity = soothe.stages, soothe.immunity
	if rec.mutation then
		local m = ToyCatalog.getMutation(rec.mutation)
		if m then
			stages = math.floor(stages * m.sootheMult + 0.5)
			immunity += m.immunityAdd
		end
	end
	-- Toys are reusable; snacks are eaten. Mythic+ toys never break.
	if def.kind == "Snack" then
		table.remove(profile.inventory, idx)
		for slot, slotUid in profile.nursery do
			if slotUid == uid then
				profile.nursery[slot] = nil
			end
		end
	end
	profile.stats.toysUsed += 1
	InventoryService.replicate(player)
	return stages, immunity, def
end

function InventoryService.setNurserySlot(player: Player, slotIndex: number, uid: string?)
	local profile = DataService.get(player)
	if not profile or type(slotIndex) ~= "number" then
		return
	end
	slotIndex = math.floor(slotIndex)
	if slotIndex < 1 or slotIndex > profile.nurserySlots then
		return
	end
	if uid == nil then
		profile.nursery[tostring(slotIndex)] = nil
	else
		local rec = InventoryService.find(profile, uid)
		if not rec then
			return
		end
		for slot, slotUid in profile.nursery do
			if slotUid == uid then
				profile.nursery[slot] = nil
			end
		end
		profile.nursery[tostring(slotIndex)] = uid
	end
	InventoryService.replicate(player)
end

function InventoryService.start()
	-- New players get a starter rattle and cracker.
	DataService.ProfileLoaded:Connect(function(player, profile)
		if #profile.inventory == 0 and profile.stats.nightsPlayed == 0 then
			InventoryService.grant(player, "rattle", nil, true)
			InventoryService.grant(player, "cracker", nil, true)
		end
		InventoryService.replicate(player)
	end)
	EconomyService.Changed:Connect(InventoryService.replicate)
	EconomyService.PendingToyBoxes:Connect(function(player, count)
		InventoryService.openToyBoxes(player, count, true)
	end)

	Net.event("BuyToyBox").OnServerEvent:Connect(function(player, count)
		if Net.allow(player, "BuyToyBox", 2) and type(count) == "number" then
			InventoryService.openToyBoxes(player, count, false)
		end
	end)
	Net.event("SellItem").OnServerEvent:Connect(function(player, uid)
		if Net.allow(player, "SellItem", 5) and type(uid) == "string" then
			InventoryService.sell(player, uid)
		end
	end)
	Net.event("ToggleFavorite").OnServerEvent:Connect(function(player, uid)
		local profile = DataService.get(player)
		if not profile or type(uid) ~= "string" or not Net.allow(player, "Fav", 5) then
			return
		end
		local rec = InventoryService.find(profile, uid)
		if rec then
			rec.favorite = not rec.favorite
			InventoryService.replicate(player)
		end
	end)
	Net.event("SetNurserySlot").OnServerEvent:Connect(function(player, slotIndex, uid)
		if Net.allow(player, "Nursery", 5) and (uid == nil or type(uid) == "string") then
			InventoryService.setNurserySlot(player, slotIndex, uid)
		end
	end)
	Net.func("GetProfile").OnServerInvoke = function(player)
		local profile = DataService.waitFor(player)
		if not profile then
			return nil
		end
		return {
			inventory = profile.inventory,
			coins = profile.coins,
			stars = profile.stars,
			highestNight = profile.highestNight,
			rebirths = profile.rebirths,
			nursery = profile.nursery,
			nurserySlots = profile.nurserySlots,
			babyBook = profile.babyBook,
			stats = profile.stats,
			canRebirth = EconomyService.canRebirth(profile),
		}
	end
end

return InventoryService

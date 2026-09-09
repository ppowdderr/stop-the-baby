--!strict
-- Server-authoritative currency, codes, group gift, offline income, rebirth, and purchases.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))
local DataService = require(script.Parent.DataService)

local EconomyService = {}
EconomyService.Changed = Signal.new() :: Signal.Signal<Player>

local function toast(player: Player, text: string, kind: string?)
	Net.event("Toast"):FireClient(player, text, kind or "info")
end

function EconomyService.multiplier(player: Player): number
	local profile = DataService.get(player)
	if not profile then
		return 1
	end
	local mult = 1 + profile.rebirths * Config.Rebirth.MultiplierPerRebirth
	if profile.passes.X2Coins then
		mult *= 2
	end
	return mult
end

function EconomyService.addCoins(player: Player, amount: number, applyMultiplier: boolean?)
	local profile = DataService.get(player)
	if not profile or amount <= 0 then
		return
	end
	local final = if applyMultiplier then math.floor(amount * EconomyService.multiplier(player) + 0.5) else amount
	profile.coins += final
	EconomyService.Changed:Fire(player)
end

function EconomyService.spendCoins(player: Player, amount: number): boolean
	local profile = DataService.get(player)
	if not profile or amount < 0 or profile.coins < amount then
		return false
	end
	profile.coins -= amount
	EconomyService.Changed:Fire(player)
	return true
end

function EconomyService.addStars(player: Player, amount: number)
	local profile = DataService.get(player)
	if not profile or amount <= 0 then
		return
	end
	profile.stars += amount
	EconomyService.Changed:Fire(player)
end

function EconomyService.hasLuck(player: Player): boolean
	local profile = DataService.get(player)
	if not profile then
		return false
	end
	return profile.passes.LuckyNanny == true or profile.luckBoostUntil > os.time()
end

-- Offline Diaper Coins from the Nursery (capped)
local function grantOfflineIncome(player: Player, profile: DataService.Profile)
	local nurseryCount = 0
	for _ in profile.nursery do
		nurseryCount += 1
	end
	if nurseryCount == 0 or profile.lastSeen == 0 then
		return
	end
	local hours = math.min(Config.Economy.OfflineCapHours, (os.time() - profile.lastSeen) / 3600)
	local earned = math.floor(hours * Config.Economy.OfflineCoinsPerHour * nurseryCount)
	if earned > 0 then
		profile.coins += earned
		toast(player, ("Your Nursery earned %d Diaper Coins while you were away!"):format(earned), "coins")
	end
end

local function grantGroupGift(player: Player, profile: DataService.Profile)
	if Config.GroupId == 0 then
		return
	end
	if os.time() - profile.lastGroupGift < 20 * 3600 then
		return
	end
	local ok, inGroup = pcall(function()
		return player:IsInGroup(Config.GroupId)
	end)
	if ok and inGroup then
		profile.lastGroupGift = os.time()
		profile.coins += 200
		toast(player, "Grandma's Gift: +200 Diaper Coins for being in the group!", "coins")
	end
end

function EconomyService.redeemCode(player: Player, code: string): boolean
	local profile = DataService.get(player)
	if not profile or type(code) ~= "string" then
		return false
	end
	local upper = string.upper(string.sub(code, 1, 24))
	local reward = Config.Codes[upper]
	if not reward then
		toast(player, "Invalid code.", "error")
		return false
	end
	if profile.redeemedCodes[upper] then
		toast(player, "Code already redeemed.", "error")
		return false
	end
	profile.redeemedCodes[upper] = true
	if reward.type == "Coins" then
		profile.coins += reward.amount
		toast(player, ("Code redeemed: +%d Diaper Coins!"):format(reward.amount), "coins")
	elseif reward.type == "ToyBox" then
		EconomyService.PendingToyBoxes:Fire(player, reward.amount)
		toast(player, ("Code redeemed: %d free Toy Box!"):format(reward.amount), "coins")
	end
	EconomyService.Changed:Fire(player)
	return true
end
EconomyService.PendingToyBoxes = Signal.new() :: Signal.Signal<Player, number>

function EconomyService.canRebirth(profile: DataService.Profile): boolean
	local needed = Config.Rebirth.NightsRequired[math.min(profile.rebirths + 1, #Config.Rebirth.NightsRequired)]
	return profile.highestNight >= needed
end

function EconomyService.rebirth(player: Player): boolean
	local profile = DataService.get(player)
	if not profile or not EconomyService.canRebirth(profile) then
		return false
	end
	profile.rebirths += 1
	profile.highestNight = 0
	profile.coins = 0
	DataService.recordFirst(profile, "rebirth_" .. profile.rebirths)
	toast(
		player,
		("NEW FAMILY! Rebirth %d — permanent x%.2f coins"):format(profile.rebirths, EconomyService.multiplier(player)),
		"star"
	)
	EconomyService.Changed:Fire(player)
	return true
end

-- Robux purchases (dev products & gamepasses)
local productHandlers: { [number]: (Player, DataService.Profile) -> boolean } = {}

local function registerProducts()
	local P = Config.Products
	if P.StarterPack.productId ~= 0 then
		productHandlers[P.StarterPack.productId] = function(player, profile)
			profile.coins += 1000
			EconomyService.PendingToyBoxes:Fire(player, 3)
			return true
		end
	end
	if P.ToyBox10.productId ~= 0 then
		productHandlers[P.ToyBox10.productId] = function(player, _profile)
			EconomyService.PendingToyBoxes:Fire(player, 10)
			return true
		end
	end
	if P.NurseryShelf.productId ~= 0 then
		productHandlers[P.NurseryShelf.productId] = function(_player, profile)
			profile.nurserySlots += 3
			return true
		end
	end
end

local function refreshPasses(player: Player, profile: DataService.Profile)
	for name, def in Config.Products :: any do
		if def.gamepassId and def.gamepassId ~= 0 then
			local ok, owns =
				pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, def.gamepassId)
			if ok and owns then
				profile.passes[name] = true
			end
		end
	end
end

function EconomyService.start()
	registerProducts()

	DataService.ProfileLoaded:Connect(function(player, profile)
		grantOfflineIncome(player, profile)
		grantGroupGift(player, profile)
		refreshPasses(player, profile)
		EconomyService.Changed:Fire(player)
	end)

	Net.event("RedeemCode").OnServerEvent:Connect(function(player, code)
		if Net.allow(player, "RedeemCode", 1) then
			EconomyService.redeemCode(player, code)
		end
	end)
	Net.event("Rebirth").OnServerEvent:Connect(function(player)
		if Net.allow(player, "Rebirth", 1) then
			EconomyService.rebirth(player)
		end
	end)

	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local profile = DataService.get(player)
		if not profile then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local handler = productHandlers[receipt.ProductId]
		if not handler then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, granted = pcall(handler, player, profile)
		if ok and granted then
			EconomyService.Changed:Fire(player)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local profile = DataService.get(player)
		if not profile then
			return
		end
		for name, def in Config.Products :: any do
			if def.gamepassId == passId then
				profile.passes[name] = true
				EconomyService.Changed:Fire(player)
			end
		end
	end)
end

return EconomyService

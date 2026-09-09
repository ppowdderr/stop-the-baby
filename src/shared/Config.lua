--!strict
-- All tunable gameplay numbers live here (see docs/SPEC.md §10.3).

local Config = {}

Config.MaxPlayers = 4
Config.FinalNight = 99

-- Round timing (seconds)
Config.BriefingTime = 12
Config.NightBaseTime = 300 -- 5 min at Night 1
Config.NightTimePerNight = 3 -- +3s per night, capped
Config.NightMaxTime = 480
Config.BedtimeWindow = 60 -- last N seconds of the night = bedtime
Config.MomCheckTime = 8
Config.ResultsTime = 10

-- Mood
Config.Mood = {
	Stages = { "Happy", "Grumpy", "Fussy", "Crying" },
	BaseDecayInterval = 45, -- seconds per stage at Night 1
	MinDecayInterval = 20,
	DecayIntervalPerNight = 0.7, -- shrinks per night
	CryToPanicSeconds = 20, -- crying this long summons Mom
	PanicSeconds = 30,
	PanicSpeedMultiplier = 2.0,
}

-- Baby growth: scale multiplier per night
Config.Baby = {
	BaseScale = 2.5,
	ScalePerNight = 0.09,
	MaxScale = 14,
	BaseWalkSpeed = 8,
	WalkSpeedPerNight = 0.15,
	MaxWalkSpeed = 24,
	WantChangeInterval = { min = 30, max = 60 },
	DestroyInterval = { min = 12, max = 25 },
	GiftChance = 0.06, -- per destroy tick, hands a player a toy
	CarryPlayersNeeded = function(night: number): number
		return if night < 30 then 1 else 2
	end,
	SwallowChance = 0.08, -- when a player is within reach while Fussy+
}

-- Chores
Config.Chores = {
	BaseCount = 3,
	ExtraEveryNights = 8,
	MaxCount = 7,
	HoldTimeRange = { min = 8, max = 20 },
}

-- Economy
Config.Economy = {
	NightRewardBase = 100,
	NightRewardExponent = 1.1,
	ChoreReward = 15,
	SootheReward = 5,
	OfflineCoinsPerHour = 60,
	OfflineCapHours = 12,
	ToyBoxCost = 250,
	StarThresholds = { 0.5, 0.75, 0.95 }, -- score fraction for 1/2/3 stars
}

-- Rebirth
Config.Rebirth = {
	NightsRequired = { 25, 50, 75, 99 },
	MultiplierPerRebirth = 0.25,
}

-- Rarity odds for a Toy Box (must sum to 100). Secret is event-only.
Config.RarityOdds = {
	{ rarity = "Common", weight = 60 },
	{ rarity = "Uncommon", weight = 25 },
	{ rarity = "Rare", weight = 10 },
	{ rarity = "Epic", weight = 4 },
	{ rarity = "Legendary", weight = 0.9 },
	{ rarity = "Mythic", weight = 0.1 },
}
Config.NightRollLegendaryBonusPerNight = 0.2 -- +0.2% Legendary per night on the night-completion roll

Config.MutationChance = 0.18

Config.Codes = {
	BIGBABY = { type = "ToyBox", amount = 1 },
	MOMISHOME = { type = "Coins", amount = 500 },
}

Config.GroupId = 0 -- set to your Roblox group id for the daily Grandma's Gift

Config.Products = {
	-- Developer products / gamepasses: fill ids after creating them in Creator Hub.
	StarterPack = { productId = 0, price = 99 },
	X2Coins = { gamepassId = 0, price = 249 },
	LuckyNanny = { gamepassId = 0, price = 299 },
	ToyBox10 = { productId = 0, price = 149 },
	NurseryShelf = { productId = 0, price = 99 },
}

return Config

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
	BaseDecayInterval = 55, -- seconds per stage at Night 1
	MinDecayInterval = 22,
	DecayIntervalPerNight = 1.1, -- shrinks per night (hits the floor around Night 30)
	WantDecayMultiplier = 0.75, -- decay speed-up while an unmet want is active
	OpeningGrace = 15, -- no mood decay for the first seconds of a night
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

-- Chores are the clock, not the game: few, quick, and undone by the Baby.
Config.Chores = {
	BaseCount = 2,
	ExtraEveryNights = 12,
	MaxCount = 4,
	HoldTimeRange = { min = 8, max = 20 },
}

-- Baby Powers / Gear / bosses (see PowerCatalog, GearCatalog, NightGen)
Config.Powers = {
	-- Nights 1-2 are scripted so every new player meets the two funniest powers first.
	Scripted = { [1] = { "Hiccups" }, [2] = { "SugarRush" } } :: { [number]: { string } },
	CountSteps = {
		{ night = 1, count = 1 },
		{ night = 5, count = 2 },
		{ night = 15, count = 3 },
		{ night = 30, count = 4 },
	},
	LevelSteps = { { night = 1, level = 1 }, { night = 12, level = 2 }, { night = 30, level = 3 } },
	BossEvery = 10,
	BossSegments = 3, -- Calm Bar segments (solo servers use fewer, see BabyAI)
	BossDuration = 240, -- fixed clock: Mom's headlights arrive at the end no matter what
	DazedSeconds = 3.5, -- opening after a slam where toys/cannon count against the Calm Bar
	KnockbackSeconds = 1.6, -- how long a shockwave keeps you on the floor
	StuckSeconds = { 8, 10, 12 }, -- per power level, until a stuck player wiggles free
	MaxStuckProps = { 4, 7, 10 },
	SugarSpeed = { 1.7, 2.1, 2.5 },
}

-- Drops (gear/coins pickups the Baby leaves behind)
Config.Drops = {
	PropCoinChance = 0.14, -- per smashed prop
	PropGearChance = 0.035,
	BurpChance = 0.45, -- per snack fed
	BurpGearChance = 0.5, -- burp drop is gear (else coins)
	PickupLifetime = 20,
	CoinsRange = { min = 15, max = 45 },
	CounterBias = 0.65, -- chance a gear drop counters one of tonight's powers
	TierOdds = { 52, 28, 13, 5.5, 1.5 }, -- Common..Legendary (percent)
	TierBonusPerNight = 0.25, -- shifts weight from Common toward Rare+ per night
	BossMinTier = "Rare",
	FirstNightGear = "PacifierCannon", -- first-ever night always pays out this piece
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
	Daily = { BaseCoins = 100, CoinsPerStreakDay = 50, MaxStreak = 7, ToyBoxEveryDays = 3 },
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

-- First session (see docs/PUBLISHING.md for the full onboarding flow)
Config.Onboarding = {
	FirstPullMinRarity = "Rare", -- a player's first night always pays out at least this rarity
	CoachEnabled = true, -- step-by-step coach shown to players with 0 nights played
	LikePromptAfterNights = 1, -- show the Like/Favorite + group card after this many nights survived
}

-- Publishing ids. Everything below is 0 (disabled) until the experience exists in Creator Hub;
-- fill them in from Creator Hub > your experience > Monetization / Associated Items.
Config.GroupId = 0 -- Roblox group id for the daily Grandma's Gift (0 = feature hidden)

Config.Products = {
	-- Developer products / gamepasses: fill ids after creating them in Creator Hub.
	StarterPack = { productId = 0, price = 99 },
	X2Coins = { gamepassId = 0, price = 249 },
	LuckyNanny = { gamepassId = 0, price = 299 },
	ToyBox10 = { productId = 0, price = 149 },
	NurseryShelf = { productId = 0, price = 99 },
}

-- Returns true once real ids have been filled in (used to hide the shop's Robux buttons in unpublished builds).
function Config.productsConfigured(): boolean
	for _, p in Config.Products :: { [string]: { productId: number?, gamepassId: number? } } do
		if (p.productId or 0) > 0 or (p.gamepassId or 0) > 0 then
			return true
		end
	end
	return false
end

return Config

--!strict
-- Builds tonight's Baby from parts: which Powers (and how strong), which Variant, and whether
-- it's a boss night. Everything is derived from the night number + a server seed, so the same
-- plan can be shown in the briefing and used by the Baby.
local Config = require(script.Parent.Config)
local PowerCatalog = require(script.Parent.PowerCatalog)

export type PowerPick = { id: string, level: number }

export type VariantDef = {
	id: string,
	name: string,
	rarity: string, -- Rarity name (drives color + announcement)
	weight: number,
	extraPower: boolean,
	dropMult: number,
	coinMult: number,
	tint: Color3?,
	glow: Color3?,
}

export type Plan = {
	night: number,
	powers: { PowerPick },
	variant: VariantDef,
	isBoss: boolean,
	title: string, -- "BABY" on normal nights, generated on boss nights
	bossSegments: number,
	duration: number,
	choreCount: number,
}

local NightGen = {}

NightGen.Variants = {
	{ id = "Normal", name = "Baby", rarity = "Common", weight = 78, extraPower = false, dropMult = 1, coinMult = 1 },
	{
		id = "Glow",
		name = "Glow Baby",
		rarity = "Rare",
		weight = 13,
		extraPower = false,
		dropMult = 2,
		coinMult = 1.5,
		tint = Color3.fromRGB(190, 255, 245),
		glow = Color3.fromRGB(120, 255, 230),
	},
	{
		id = "Golden",
		name = "GOLDEN BABY",
		rarity = "Legendary",
		weight = 6,
		extraPower = true,
		dropMult = 4,
		coinMult = 5,
		tint = Color3.fromRGB(255, 205, 60),
		glow = Color3.fromRGB(255, 190, 40),
	},
	{
		id = "Shadow",
		name = "SHADOW BABY",
		rarity = "Mythic",
		weight = 3,
		extraPower = true,
		dropMult = 8,
		coinMult = 10,
		tint = Color3.fromRGB(70, 50, 110),
		glow = Color3.fromRGB(170, 60, 255),
	},
} :: { VariantDef }

local function variantById(id: string): VariantDef
	for _, v in NightGen.Variants do
		if v.id == id then
			return v
		end
	end
	return NightGen.Variants[1]
end

NightGen.variantById = variantById

function NightGen.isBossNight(night: number): boolean
	return night % Config.Powers.BossEvery == 0
end

-- How many powers stack on a normal night.
function NightGen.powerCount(night: number): number
	local count = 1
	for _, step in Config.Powers.CountSteps do
		if night >= step.night then
			count = step.count
		end
	end
	return count
end

function NightGen.powerLevel(night: number): number
	local level = 1
	for _, step in Config.Powers.LevelSteps do
		if night >= step.night then
			level = step.level
		end
	end
	return level
end

local function pickVariant(rng: Random, night: number, isBoss: boolean): VariantDef
	-- Rare babies get more common as nights go on; bosses are never plain.
	local lateBonus = math.min(20, math.floor(night / 5))
	local total = 0
	local weights: { number } = {}
	for i, v in NightGen.Variants do
		local w = v.weight
		if i == 1 then
			w = if isBoss then 0 else math.max(30, w - lateBonus)
		elseif i == 2 then
			w += math.floor(lateBonus / 2)
		else
			w += math.floor(lateBonus / 4)
		end
		weights[i] = w
		total += w
	end
	local roll = rng:NextNumber() * total
	for i, v in NightGen.Variants do
		roll -= weights[i]
		if roll <= 0 then
			return v
		end
	end
	return NightGen.Variants[1]
end

local function title(picks: { PowerPick }, isBoss: boolean): string
	if not isBoss then
		return "BABY"
	end
	local words = {}
	for _, p in picks do
		local def = PowerCatalog.get(p.id)
		if def then
			table.insert(words, def.adjective)
		end
	end
	return "THE " .. table.concat(words, " ") .. " TITAN"
end

function NightGen.plan(night: number, seed: number): Plan
	local rng = Random.new(seed)
	local isBoss = NightGen.isBossNight(night)
	local variant = pickVariant(rng, night, isBoss)
	local level = math.min(3, NightGen.powerLevel(night) + (if isBoss then 1 else 0))

	local picks: { PowerPick } = {}
	local scripted = Config.Powers.Scripted[night]
	if scripted then
		for _, id in scripted do
			table.insert(picks, { id = id, level = level })
		end
	else
		local pool = PowerCatalog.available(night)
		for i = #pool, 2, -1 do
			local j = rng:NextInteger(1, i)
			pool[i], pool[j] = pool[j], pool[i]
		end
		local count = NightGen.powerCount(night) + (if isBoss then 1 else 0) + (if variant.extraPower then 1 else 0)
		for i = 1, math.min(count, #pool) do
			table.insert(picks, { id = pool[i].id, level = level })
		end
	end

	local players = Config.Powers.BossSegments
	local choreCount = if isBoss
		then 0
		else math.min(
			Config.Chores.MaxCount,
			Config.Chores.BaseCount + math.floor((night - 1) / Config.Chores.ExtraEveryNights)
		)
	return {
		night = night,
		powers = picks,
		variant = variant,
		isBoss = isBoss,
		title = title(picks, isBoss),
		bossSegments = players,
		duration = if isBoss
			then Config.Powers.BossDuration
			else math.min(Config.NightMaxTime, Config.NightBaseTime + (night - 1) * Config.NightTimePerNight),
		choreCount = choreCount,
	}
end

-- Plain-data copy safe to send to clients.
function NightGen.dto(plan: Plan)
	local powers = {}
	for _, p in plan.powers do
		local def = PowerCatalog.get(p.id)
		if def then
			table.insert(powers, {
				id = p.id,
				level = p.level,
				name = def.name,
				emoji = def.emoji,
				tell = def.tell,
				effect = def.effect,
				counterGear = def.counterGear,
			})
		end
	end
	return {
		night = plan.night,
		powers = powers,
		variant = plan.variant.id,
		variantName = plan.variant.name,
		variantRarity = plan.variant.rarity,
		isBoss = plan.isBoss,
		title = plan.title,
		bossSegments = plan.bossSegments,
		duration = plan.duration,
		choreCount = plan.choreCount,
	}
end

function NightGen.hasPower(plan: Plan, id: string): boolean
	for _, p in plan.powers do
		if p.id == id then
			return true
		end
	end
	return false
end

function NightGen.level(plan: Plan, id: string): number
	for _, p in plan.powers do
		if p.id == id then
			return p.level
		end
	end
	return 0
end

return NightGen

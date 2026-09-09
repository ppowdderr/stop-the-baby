--!strict
-- Gear: drops that change how you play. Each piece counters a Baby Power (or works on anything).
-- Tier = rarity (Common..Legendary); higher tiers get more charges / longer effects, never a
-- different rule. Actives are used from the gear bar; passives work while equipped.

export type GearKind = "Active" | "Passive"

export type GearDef = {
	id: string,
	name: string,
	emoji: string,
	kind: GearKind,
	counters: string?, -- PowerCatalog id, nil = universal
	desc: string,
	range: number, -- studs from Baby needed to use an active
	charges: { number }, -- per tier, actives only (per night)
	power: { number }, -- per tier: seconds / percent / studs depending on the gear
	powerLabel: string,
}

local GearCatalog = {}

GearCatalog.MaxLoadout = 4
GearCatalog.Tiers = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
GearCatalog.FuseCount = 3

GearCatalog.List = {
	{
		id = "PacifierCannon",
		name = "Pacifier Cannon",
		emoji = "🔫",
		kind = "Active",
		counters = nil,
		desc = "Shoots a pacifier into Baby's mouth from across the room: calms it one stage",
		range = 70,
		charges = { 2, 3, 4, 5, 6 },
		power = { 3, 4, 6, 8, 10 },
		powerLabel = "s immunity",
	},
	{
		id = "BubbleTrap",
		name = "Bubble Trap",
		emoji = "🫧",
		kind = "Active",
		counters = "SugarRush",
		desc = "Traps Baby in a giant bubble: it can't move and every toy counts as an opening",
		range = 34,
		charges = { 1, 2, 2, 3, 4 },
		power = { 5, 6, 8, 10, 12 },
		powerLabel = "s frozen",
	},
	{
		id = "SoapGun",
		name = "Soap Gun",
		emoji = "🧼",
		kind = "Active",
		counters = "Sticky",
		desc = "Un-sticks everyone and everything from Baby and makes it too slippery to grab",
		range = 34,
		charges = { 2, 2, 3, 4, 5 },
		power = { 8, 10, 13, 16, 20 },
		powerLabel = "s slippery",
	},
	{
		id = "EarMuffs",
		name = "Ear Muffs",
		emoji = "🎧",
		kind = "Passive",
		counters = "Hiccups",
		desc = "You don't get knocked over by slams or screams. Rare+: protects teammates near you",
		range = 0,
		charges = { 0, 0, 0, 0, 0 },
		power = { 0, 0, 14, 22, 32 },
		powerLabel = " stud shield",
	},
	{
		id = "BabyMonitor",
		name = "Baby Monitor",
		emoji = "📟",
		kind = "Passive",
		counters = "Loud",
		desc = "Baby's mood drops slower for the whole team (best monitor counts)",
		range = 0,
		charges = { 0, 0, 0, 0, 0 },
		power = { 12, 18, 25, 32, 40 },
		powerLabel = "% slower mood",
	},
} :: { GearDef }

local byId: { [string]: GearDef } = {}
for _, g in GearCatalog.List do
	byId[g.id] = g
end

function GearCatalog.get(id: string): GearDef?
	return byId[id]
end

function GearCatalog.tierIndex(tier: string): number
	local i = table.find(GearCatalog.Tiers, tier)
	return i or 1
end

function GearCatalog.charges(def: GearDef, tier: string): number
	return def.charges[GearCatalog.tierIndex(tier)]
end

function GearCatalog.power(def: GearDef, tier: string): number
	return def.power[GearCatalog.tierIndex(tier)]
end

function GearCatalog.displayName(id: string, tier: string): string
	local def = byId[id]
	if not def then
		return id
	end
	return ("%s %s"):format(tier, def.name)
end

-- Gear that counters any of the given power ids (used to bias drops toward tonight's Baby).
function GearCatalog.countersFor(powerIds: { string }): { GearDef }
	local out = {}
	for _, g in GearCatalog.List do
		if g.counters and table.find(powerIds, g.counters) then
			table.insert(out, g)
		end
	end
	return out
end

return GearCatalog

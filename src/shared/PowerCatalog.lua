--!strict
-- Baby Powers: the Baby is assembled each night from stackable powers. Every power is one
-- readable rule — a tell the players can see coming, an effect, and a gear counter.
-- Adding a power here (plus its script in server/Baby/Powers) multiplies against every existing one.

export type PowerDef = {
	id: string,
	name: string,
	adjective: string, -- used to auto-title bosses: "THE STICKY HICCUPING TITAN"
	emoji: string,
	tell: string, -- what players see 1-2 s before the effect
	effect: string, -- one-line rule shown in the briefing
	counterGear: string, -- GearCatalog id that counters it
	minNight: number,
	-- Per-level tuning (level 1..3; bosses run one level higher, capped at 3)
	interval: { number }, -- seconds between activations
}

local PowerCatalog = {}

PowerCatalog.List = {
	{
		id = "Hiccups",
		name = "Hiccups",
		adjective = "HICCUPING",
		emoji = "💨",
		tell = "Cheeks puff up",
		effect = "HIC! Baby bounces and SLAMS — the shockwave sends you flying",
		counterGear = "EarMuffs",
		minNight = 1,
		interval = { 11, 8, 6 },
	},
	{
		id = "SugarRush",
		name = "Sugar Rush",
		adjective = "ZOOMY",
		emoji = "⚡",
		tell = "Eyes go wide, starts vibrating",
		effect = "Baby ZOOMS around the house and bowls over anyone in the way",
		counterGear = "BubbleTrap",
		minNight = 2,
		interval = { 14, 10, 8 },
	},
	{
		id = "Sticky",
		name = "Sticky",
		adjective = "STICKY",
		emoji = "🍯",
		tell = "Drooling green goo",
		effect = "Furniture — and babysitters — STICK to Baby. It grows a junk-ball",
		counterGear = "SoapGun",
		minNight = 3,
		interval = { 1, 1, 1 },
	},
	{
		id = "Loud",
		name = "Loud",
		adjective = "LOUD",
		emoji = "📢",
		tell = "Takes a huge breath in",
		effect = "When fussy, Baby SCREAMS: windows shatter (new chores) and you get blown back",
		counterGear = "BabyMonitor",
		minNight = 4,
		interval = { 16, 12, 9 },
	},
} :: { PowerDef }

local byId: { [string]: PowerDef } = {}
for _, p in PowerCatalog.List do
	byId[p.id] = p
end

function PowerCatalog.get(id: string): PowerDef?
	return byId[id]
end

function PowerCatalog.available(night: number): { PowerDef }
	local out = {}
	for _, p in PowerCatalog.List do
		if p.minNight <= night then
			table.insert(out, p)
		end
	end
	return out
end

function PowerCatalog.interval(def: PowerDef, level: number): number
	return def.interval[math.clamp(level, 1, #def.interval)]
end

return PowerCatalog

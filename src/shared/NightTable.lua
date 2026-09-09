--!strict
-- Per-night escalation: which baby behaviors, chores and areas are active.
local Config = require(script.Parent.Config)

export type NightInfo = {
	night: number,
	scale: number,
	walkSpeed: number,
	decayInterval: number,
	choreCount: number,
	duration: number,
	behaviors: { string },
	areas: { string },
	momLine: string,
	special: string?,
}

local NightTable = {}

local behaviorUnlocks: { { night: number, id: string } } = {
	{ night = 1, id = "Wander" },
	{ night = 1, id = "Destroy" },
	{ night = 1, id = "WantToy" },
	{ night = 2, id = "WantSnack" },
	{ night = 3, id = "FridgeRaid" },
	{ night = 5, id = "Swallow" },
	{ night = 8, id = "StairClimb" },
	{ night = 12, id = "Escape" },
	{ night = 18, id = "Sleepwalk" },
	{ night = 25, id = "Refuse" },
	{ night = 35, id = "SecondBaby" },
	{ night = 45, id = "ChewFurniture" },
	{ night = 60, id = "FirstSteps" },
	{ night = 99, id = "Birthday" },
}

local areaUnlocks: { { night: number, id: string } } = {
	{ night = 1, id = "Kitchen" },
	{ night = 1, id = "LivingRoom" },
	{ night = 8, id = "Upstairs" },
	{ night = 15, id = "Basement" },
	{ night = 25, id = "Backyard" },
	{ night = 40, id = "Neighbor" },
	{ night = 70, id = "Street" },
}

local momLines = {
	"Be good. Don't let the baby cry. Don't touch the fridge.",
	"The baby has been... growing. Just keep it happy, okay?",
	"If I see ONE thing broken, you are all grounded.",
	"Bedtime is at bedtime. Not after. Not before. Bedtime.",
	"The neighbors called. Again. Keep the baby INSIDE.",
	"I'm not saying it's your fault. I'm saying it's ALWAYS your fault.",
	"I left snacks. The snacks are for the BABY.",
	"Don't let the baby near my phone. It knows my password.",
}

local specials: { [number]: string } = {
	[10] = "Baby's first word: 'NO'",
	[20] = "Sleepover night: two babies",
	[30] = "Blackout: flashlight night",
	[50] = "Baby learns to open doors",
	[75] = "Grandma visits (she helps... a little)",
	[99] = "BIRTHDAY FINALE",
}

function NightTable.get(night: number): NightInfo
	local n = math.clamp(night, 1, Config.FinalNight)
	local behaviors = {}
	for _, b in behaviorUnlocks do
		if b.night <= n then
			table.insert(behaviors, b.id)
		end
	end
	local areas = {}
	for _, a in areaUnlocks do
		if a.night <= n then
			table.insert(areas, a.id)
		end
	end
	local choreCount =
		math.min(Config.Chores.MaxCount, Config.Chores.BaseCount + math.floor((n - 1) / Config.Chores.ExtraEveryNights))
	return {
		night = n,
		scale = math.min(Config.Baby.MaxScale, Config.Baby.BaseScale + (n - 1) * Config.Baby.ScalePerNight),
		walkSpeed = math.min(
			Config.Baby.MaxWalkSpeed,
			Config.Baby.BaseWalkSpeed + (n - 1) * Config.Baby.WalkSpeedPerNight
		),
		decayInterval = math.max(
			Config.Mood.MinDecayInterval,
			Config.Mood.BaseDecayInterval - (n - 1) * Config.Mood.DecayIntervalPerNight
		),
		choreCount = choreCount,
		duration = math.min(Config.NightMaxTime, Config.NightBaseTime + (n - 1) * Config.NightTimePerNight),
		behaviors = behaviors,
		areas = areas,
		momLine = momLines[((n - 1) % #momLines) + 1],
		special = specials[n],
	}
end

function NightTable.has(info: NightInfo, behavior: string): boolean
	return table.find(info.behaviors, behavior) ~= nil
end

return NightTable

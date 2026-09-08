--!strict
-- Chores are hold-to-complete interactions at named map stations.
export type ChoreDef = {
	id: string,
	name: string,
	station: string, -- name of the Model/Part in Workspace.Map.Stations
	area: string,
	holdTime: number,
	minNight: number,
	verb: string,
	requiresItemKind: string?, -- e.g. "Snack" for feeding chores
}

local ChoreCatalog = {}

ChoreCatalog.Chores = {
	{
		id = "dishes",
		name = "Wash the dishes",
		station = "Sink",
		area = "Kitchen",
		holdTime = 10,
		minNight = 1,
		verb = "Scrub",
	},
	{
		id = "trash",
		name = "Take out the trash",
		station = "TrashCan",
		area = "Kitchen",
		holdTime = 8,
		minNight = 1,
		verb = "Bag",
	},
	{
		id = "toys",
		name = "Pick up the toys",
		station = "ToyBin",
		area = "LivingRoom",
		holdTime = 12,
		minNight = 1,
		verb = "Tidy",
	},
	{
		id = "vacuum",
		name = "Vacuum the rug",
		station = "Rug",
		area = "LivingRoom",
		holdTime = 14,
		minNight = 1,
		verb = "Vacuum",
	},
	{
		id = "bottle",
		name = "Warm the bottle",
		station = "Microwave",
		area = "Kitchen",
		holdTime = 8,
		minNight = 2,
		verb = "Warm",
	},
	{
		id = "laundry",
		name = "Fold the laundry",
		station = "Laundry",
		area = "LivingRoom",
		holdTime = 15,
		minNight = 3,
		verb = "Fold",
	},
	{
		id = "windows",
		name = "Clean the windows",
		station = "Window",
		area = "LivingRoom",
		holdTime = 12,
		minNight = 4,
		verb = "Wipe",
	},
	{
		id = "bath",
		name = "Run the bath",
		station = "Bathtub",
		area = "Upstairs",
		holdTime = 12,
		minNight = 8,
		verb = "Fill",
	},
	{
		id = "bed",
		name = "Make Mom's bed",
		station = "MomBed",
		area = "Upstairs",
		holdTime = 10,
		minNight = 8,
		verb = "Tuck",
	},
	{
		id = "fuse",
		name = "Fix the fuse box",
		station = "FuseBox",
		area = "Basement",
		holdTime = 16,
		minNight = 15,
		verb = "Fix",
	},
	{
		id = "boiler",
		name = "Restart the boiler",
		station = "Boiler",
		area = "Basement",
		holdTime = 14,
		minNight = 15,
		verb = "Kick",
	},
	{
		id = "lawn",
		name = "Mow the lawn",
		station = "Lawn",
		area = "Backyard",
		holdTime = 20,
		minNight = 25,
		verb = "Mow",
	},
	{
		id = "fence",
		name = "Fix the fence",
		station = "Fence",
		area = "Backyard",
		holdTime = 14,
		minNight = 25,
		verb = "Hammer",
	},
}

-- Always-present final chore
ChoreCatalog.Bedtime = {
	id = "bedtime",
	name = "Put Baby to bed",
	station = "Crib",
	area = "LivingRoom",
	holdTime = 6,
	minNight = 1,
	verb = "Tuck in",
}

local byId: { [string]: ChoreDef } = {}
for _, c in ChoreCatalog.Chores do
	byId[c.id] = c
end
byId[ChoreCatalog.Bedtime.id] = ChoreCatalog.Bedtime

function ChoreCatalog.get(id: string): ChoreDef?
	return byId[id]
end

function ChoreCatalog.available(night: number, areas: { string }): { ChoreDef }
	local out = {}
	for _, c in ChoreCatalog.Chores do
		if c.minNight <= night and table.find(areas, c.area) then
			table.insert(out, c)
		end
	end
	return out
end

return ChoreCatalog

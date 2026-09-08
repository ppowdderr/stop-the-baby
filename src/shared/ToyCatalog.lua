--!strict
-- Toys soothe Baby, snacks feed Baby. Mutations modify both.
local Rarity = require(script.Parent.Rarity)

export type ItemKind = "Toy" | "Snack"
export type ItemDef = {
	id: string,
	name: string,
	kind: ItemKind,
	rarity: Rarity.RarityName,
	emoji: string,
	color: Color3,
	sound: string?, -- rbxassetid, optional
}

export type MutationDef = {
	id: string,
	name: string,
	sootheMult: number,
	immunityAdd: number,
	valueMult: number,
	scale: number,
	eventOnly: boolean?,
}

local ToyCatalog = {}

local function item(
	id: string,
	name: string,
	kind: ItemKind,
	rarity: Rarity.RarityName,
	emoji: string,
	r: number,
	g: number,
	b: number
): ItemDef
	return { id = id, name = name, kind = kind, rarity = rarity, emoji = emoji, color = Color3.fromRGB(r, g, b) }
end

ToyCatalog.Items = {
	-- Common
	item("rattle", "Rattle", "Toy", "Common", "🔔", 255, 220, 120),
	item("sock_puppet", "Sock Puppet", "Toy", "Common", "🧦", 200, 120, 120),
	item("cardboard_box", "Cardboard Box", "Toy", "Common", "📦", 190, 150, 100),
	item("wooden_spoon", "Wooden Spoon", "Toy", "Common", "🥄", 170, 120, 70),
	item("cracker", "Cracker", "Snack", "Common", "🍘", 230, 200, 140),
	item("banana", "Banana", "Snack", "Common", "🍌", 250, 230, 80),
	item("juice_box", "Juice Box", "Snack", "Common", "🧃", 240, 120, 90),
	-- Uncommon
	item("rubber_duck", "Rubber Duck", "Toy", "Uncommon", "🦆", 255, 230, 50),
	item("teddy", "Teddy Bear", "Toy", "Uncommon", "🧸", 170, 110, 60),
	item("bouncy_ball", "Bouncy Ball", "Toy", "Uncommon", "🏀", 250, 100, 60),
	item("toy_car", "Toy Car", "Toy", "Uncommon", "🚗", 220, 40, 40),
	item("pudding", "Pudding Cup", "Snack", "Uncommon", "🍮", 240, 190, 120),
	item("apple_slices", "Apple Slices", "Snack", "Uncommon", "🍎", 220, 60, 60),
	-- Rare
	item("dino_plush", "Dino Plush", "Toy", "Rare", "🦖", 80, 190, 100),
	item("music_box", "Music Box", "Toy", "Rare", "🎵", 160, 100, 220),
	item("bubble_wand", "Bubble Wand", "Toy", "Rare", "🫧", 120, 200, 255),
	item("mega_lollipop", "Mega Lollipop", "Snack", "Rare", "🍭", 255, 110, 200),
	item("pizza_slice", "Pizza Slice", "Snack", "Rare", "🍕", 240, 160, 60),
	-- Epic
	item("robot_dog", "Robot Dog", "Toy", "Epic", "🤖", 150, 170, 200),
	item("glow_stars", "Glow Stars Mobile", "Toy", "Epic", "🌟", 255, 240, 120),
	item("rocking_horse", "Rocking Horse", "Toy", "Epic", "🐴", 170, 100, 60),
	item("birthday_cake", "Birthday Cake", "Snack", "Epic", "🎂", 255, 200, 220),
	-- Legendary
	item("golden_pacifier", "Golden Pacifier", "Toy", "Legendary", "👑", 255, 200, 40),
	item("unicorn_plush", "Unicorn Plush", "Toy", "Legendary", "🦄", 240, 170, 255),
	item("dad_joke_book", "Dad Joke Book", "Toy", "Legendary", "📖", 120, 80, 200),
	item("infinite_bottle", "Infinite Bottle", "Snack", "Legendary", "🍼", 230, 240, 255),
	-- Mythic
	item("moms_phone", "Mom's Phone", "Toy", "Mythic", "📱", 40, 40, 50),
	item("the_remote", "THE Remote", "Toy", "Mythic", "📺", 60, 60, 70),
	-- Secret (event only)
	item("mom_keys", "Mom's Keys", "Toy", "Secret", "🔑", 255, 255, 255),
}

ToyCatalog.Mutations = {
	{ id = "giant", name = "Giant", sootheMult = 1.5, immunityAdd = 5, valueMult = 3, scale = 1.8 },
	{ id = "tiny", name = "Tiny", sootheMult = 0.9, immunityAdd = 10, valueMult = 2, scale = 0.5 },
	{ id = "glowing", name = "Glowing", sootheMult = 1.3, immunityAdd = 4, valueMult = 4, scale = 1 },
	{ id = "squeaky", name = "Squeaky", sootheMult = 1.4, immunityAdd = 0, valueMult = 3, scale = 1 },
	{ id = "rainbow", name = "Rainbow", sootheMult = 1.8, immunityAdd = 8, valueMult = 8, scale = 1.1 },
	{ id = "golden", name = "Golden", sootheMult = 2.0, immunityAdd = 10, valueMult = 12, scale = 1.1 },
	{ id = "sticky", name = "Sticky", sootheMult = 1.2, immunityAdd = 12, valueMult = 3, scale = 1 },
	{
		id = "haunted",
		name = "Haunted",
		sootheMult = 2.5,
		immunityAdd = 15,
		valueMult = 20,
		scale = 1.2,
		eventOnly = true,
	},
	{
		id = "frozen",
		name = "Frozen",
		sootheMult = 2.2,
		immunityAdd = 20,
		valueMult = 18,
		scale = 1.1,
		eventOnly = true,
	},
}

local byId: { [string]: ItemDef } = {}
for _, def in ToyCatalog.Items do
	byId[def.id] = def
end
local mutById: { [string]: MutationDef } = {}
for _, def in ToyCatalog.Mutations do
	mutById[def.id] = def
end

function ToyCatalog.get(id: string): ItemDef?
	return byId[id]
end

function ToyCatalog.getMutation(id: string): MutationDef?
	return mutById[id]
end

function ToyCatalog.itemsOfRarity(rarity: Rarity.RarityName, kind: ItemKind?): { ItemDef }
	local out = {}
	for _, def in ToyCatalog.Items do
		if def.rarity == rarity and (kind == nil or def.kind == kind) then
			table.insert(out, def)
		end
	end
	return out
end

-- Display name like "Rainbow Teddy Bear"
function ToyCatalog.displayName(itemId: string, mutationId: string?): string
	local def = byId[itemId]
	local name = if def then def.name else itemId
	if mutationId and mutById[mutationId] then
		return mutById[mutationId].name .. " " .. name
	end
	return name
end

return ToyCatalog

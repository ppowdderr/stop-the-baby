--!strict
local Config = require(script.Parent.Config)

export type RarityName = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"

local Rarity = {}

Rarity.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Rarity.Colors = {
	Common = Color3.fromRGB(190, 190, 190),
	Uncommon = Color3.fromRGB(110, 210, 110),
	Rare = Color3.fromRGB(80, 150, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 170, 40),
	Mythic = Color3.fromRGB(255, 70, 110),
	Secret = Color3.fromRGB(30, 30, 40),
}

-- Soothe: how many mood stages a toy of this rarity restores, plus immunity seconds
Rarity.Soothe = {
	Common = { stages = 1, immunity = 0 },
	Uncommon = { stages = 1, immunity = 5 },
	Rare = { stages = 2, immunity = 8 },
	Epic = { stages = 2, immunity = 14 },
	Legendary = { stages = 3, immunity = 20 },
	Mythic = { stages = 4, immunity = 30 },
	Secret = { stages = 4, immunity = 45 },
}

Rarity.SellValue = {
	Common = 10,
	Uncommon = 30,
	Rare = 120,
	Epic = 500,
	Legendary = 2500,
	Mythic = 15000,
	Secret = 100000,
}

function Rarity.index(name: RarityName): number
	for i, r in Rarity.Order do
		if r == name then
			return i
		end
	end
	return 1
end

-- Rolls a rarity. `legendaryBonus` is added (in percent points) to Legendary and taken from Common.
function Rarity.roll(rng: Random, legendaryBonus: number?): RarityName
	local bonus = legendaryBonus or 0
	local total = 0
	local weights = {}
	for _, entry in Config.RarityOdds do
		local w = entry.weight
		if entry.rarity == "Legendary" then
			w += bonus
		elseif entry.rarity == "Common" then
			w = math.max(1, w - bonus)
		end
		table.insert(weights, { rarity = entry.rarity, weight = w })
		total += w
	end
	local pick = rng:NextNumber() * total
	local acc = 0
	for _, entry in weights do
		acc += entry.weight
		if pick <= acc then
			return entry.rarity :: RarityName
		end
	end
	return "Common"
end

return Rarity

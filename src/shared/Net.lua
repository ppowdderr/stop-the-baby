--!strict
-- Lazily creates/gets RemoteEvents & RemoteFunctions under ReplicatedStorage.Remotes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.Events = {
	-- server -> client
	"RoundState", -- (state: string, payload: table)
	"BabyMood", -- (stageIndex: number, stageName: string, cryingFor: number)
	"ChoreList", -- (chores: {ChoreDTO})
	"Toast", -- (text: string, kind: string)
	"InventoryChanged", -- (inventory: {ItemDTO}, coins, stars)
	"Cutscene", -- (id: string, data: table)
	"Panic", -- (active: boolean, secondsLeft: number)
	"ClipMoment", -- (id: string)
	"GearChanged", -- (gear: {GearDTO}, loadout: {uid})
	"GearState", -- (charges: {[uid]: number}) per-night charges left
	"BossState", -- (segments: number, total: number, dazed: boolean, title: string)
	"Shake", -- (strength: number, seconds: number) camera shake for nearby players
	-- client -> server
	"UseGear", -- (uid: string)
	"EquipGear", -- (slot: number, uid: string?)
	"FuseGear", -- (gearId: string, tier: string) 3 -> 1 of the next tier
	"UseItem", -- (uid: string)
	"Interact", -- (targetName: string)
	"StartChore", -- (choreId: string)
	"StopChore", -- (choreId: string)
	"CarryBaby", -- (start: boolean)
	"BuyToyBox", -- (count: number)
	"RedeemCode", -- (code: string)
	"SellItem", -- (uid: string)
	"ToggleFavorite", -- (uid: string)
	"SetNurserySlot", -- (slotIndex: number, uid: string?)
	"RequestStart", -- (night: number) vote to start the given night
	"Rebirth", -- () start a New Family (requires Night threshold)
}

Net.Functions = {
	"GetProfile", -- () -> ProfileDTO
	"GetNursery", -- (userId) -> NurseryDTO
}

local folder: Folder

local function getFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local f = ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
		if not f then
			f = Instance.new("Folder")
			f.Name = "Remotes"
			f.Parent = ReplicatedStorage
			for _, name in Net.Events do
				local ev = Instance.new("RemoteEvent")
				ev.Name = name
				ev.Parent = f
			end
			for _, name in Net.Functions do
				local fn = Instance.new("RemoteFunction")
				fn.Name = name
				fn.Parent = f
			end
		end
		folder = f :: Folder
	else
		folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	return folder
end

function Net.event(name: string): RemoteEvent
	local f = getFolder()
	local ev = if RunService:IsServer() then f:FindFirstChild(name) else f:WaitForChild(name)
	assert(ev and ev:IsA("RemoteEvent"), "Unknown remote event " .. name)
	return ev :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	local f = getFolder()
	local fn = if RunService:IsServer() then f:FindFirstChild(name) else f:WaitForChild(name)
	assert(fn and fn:IsA("RemoteFunction"), "Unknown remote function " .. name)
	return fn :: RemoteFunction
end

-- Server-side helper: per-player rate limiter (calls per second)
local buckets: { [Player]: { [string]: { count: number, reset: number } } } = {}
function Net.allow(player: Player, key: string, perSecond: number): boolean
	local now = os.clock()
	local pb = buckets[player]
	if not pb then
		pb = {}
		buckets[player] = pb
	end
	local b = pb[key]
	if not b or now >= b.reset then
		pb[key] = { count = 1, reset = now + 1 }
		return true
	end
	b.count += 1
	return b.count <= perSecond
end

function Net.clearPlayer(player: Player)
	buckets[player] = nil
end

return Net

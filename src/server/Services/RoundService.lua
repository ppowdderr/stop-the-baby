--!strict
-- Night state machine: Lobby -> Briefing -> Night -> (Panic) -> MomCheck -> Results -> next night / fail.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local NightTable = require(Shared:WaitForChild("NightTable"))
local NightGen = require(Shared:WaitForChild("NightGen"))
local ToyCatalog = require(Shared:WaitForChild("ToyCatalog"))
local GearCatalog = require(Shared:WaitForChild("GearCatalog"))
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local ChoreService = require(script.Parent.ChoreService)
local GearService = require(script.Parent.GearService)
local BabyAI = require(script.Parent.Parent.Baby.BabyAI)

export type State = "Lobby" | "Briefing" | "Night" | "Panic" | "MomCheck" | "Results" | "Failed"

local RoundService = {}

local state: State = "Lobby"
local night = 1
local nightEndsAt = 0
local panicEndsAt = 0
local votes: { [Player]: boolean } = {}
local nightDamage = 0 -- knocked props count at Mom check
local plan: NightGen.Plan = NightGen.plan(1, 1)
local bossWon = false
local rng = Random.new()

local function setState(newState: State, payload: { [string]: any }?)
	state = newState
	local p = payload or {}
	p.night = night
	p.state = newState
	p.serverTime = workspace:GetServerTimeNow()
	Net.event("RoundState"):FireAllClients(newState, p)
end

local function toastAll(text: string, kind: string?)
	Net.event("Toast"):FireAllClients(text, kind or "info")
end

local function cutscene(id: string, data: { [string]: any }?)
	Net.event("Cutscene"):FireAllClients(id, data or {})
end

local function countKnockedProps(): number
	local map = workspace:FindFirstChild("Map")
	local props = map and map:FindFirstChild("Props")
	if not props then
		return 0
	end
	local n = 0
	for _, prop in props:GetChildren() do
		if prop:GetAttribute("Knocked") then
			n += 1
		end
	end
	return n
end

local function resetProps()
	local map = workspace:FindFirstChild("Map")
	local props = map and map:FindFirstChild("Props")
	if not props then
		return
	end
	for _, prop in props:GetChildren() do
		if prop:IsA("BasePart") then
			local weld = prop:FindFirstChild("StickyWeld")
			if weld then
				weld:Destroy()
			end
			local home = prop:GetAttribute("HomeCFrame")
			if typeof(home) == "CFrame" then
				prop.CFrame = home
			end
			prop.Anchored = true
			prop.CanCollide = true
			prop.Massless = false
			prop.AssemblyLinearVelocity = Vector3.zero
			prop:SetAttribute("Knocked", false)
			prop:SetAttribute("Stuck", false)
		end
	end
end

-- Players "hide damage" by touching knocked props (handled in map builder via ProximityPrompt -> Interact remote)
local function fixProp(player: Player, propName: string)
	local map = workspace:FindFirstChild("Map")
	local props = map and map:FindFirstChild("Props")
	local prop = props and props:FindFirstChild(propName)
	if not prop or not prop:IsA("BasePart") or not prop:GetAttribute("Knocked") then
		return
	end
	if prop:GetAttribute("Stuck") then
		Net.event("Toast"):FireClient(player, "It's stuck to Baby! Soap Gun it off first.", "error")
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp or (hrp.Position - prop.Position).Magnitude > 14 then
		return
	end
	local home = prop:GetAttribute("HomeCFrame")
	if typeof(home) == "CFrame" then
		prop.CFrame = home
	end
	prop.Anchored = true
	prop:SetAttribute("Knocked", false)
	EconomyService.addCoins(player, 5, true)
end

local function highestNightAmongPlayers(): number
	local best = 0
	for _, plr in Players:GetPlayers() do
		local profile = DataService.get(plr)
		if profile then
			best = math.max(best, profile.highestNight)
		end
	end
	return best
end

local function resultsFor(success: boolean)
	local info = NightTable.get(night)
	local fraction = ChoreService.completionFraction()
	if plan.isBoss then
		local total = math.max(1, plan.bossSegments)
		fraction = if success then 1 else (total - BabyAI.bossSegmentsLeft()) / total
	end
	local damagePenalty = math.min(0.3, nightDamage * 0.03)
	local score = math.clamp(fraction - damagePenalty + (if success then 0.2 else 0), 0, 1)
	local stars = 0
	for _, t in Config.Economy.StarThresholds do
		if score >= t then
			stars += 1
		end
	end
	local coins = math.floor(
		Config.Economy.NightRewardBase
			* (night ^ Config.Economy.NightRewardExponent)
			* (if success then 1 else 0.3)
			* (if success then plan.variant.coinMult else 1)
			* (if plan.isBoss and success then 2 else 1)
	)
	local common: { [string]: any } = {
		success = success,
		stars = stars,
		coins = coins,
		score = score,
		damage = nightDamage,
		special = info.special,
		finale = success and night == Config.FinalNight,
		reason = if success then nil elseif plan.isBoss then "boss" elseif BabyAI.isCrying() then "crying" else "chores",
		isBoss = plan.isBoss,
		title = plan.title,
		variant = plan.variant.id,
		variantName = plan.variant.name,
		variantRarity = plan.variant.rarity,
	}
	state = "Results"
	for _, plr in Players:GetPlayers() do
		local payload: { [string]: any } = table.clone(common)
		local profile = DataService.get(plr)
		if profile then
			local firstNight = profile.stats.nightsPlayed == 0
			profile.stats.nightsPlayed += 1
			if success then
				profile.highestNight = math.max(profile.highestNight, night)
				DataService.recordFirst(profile, "night_" .. night)
				if plan.variant.id ~= "Normal" then
					DataService.recordFirst(profile, "variant_" .. plan.variant.id)
				end
				EconomyService.addStars(plr, stars)
			end
			-- Gear payout: bosses always drop Rare+; a first-ever night hands out the Pacifier Cannon so
			-- the gear bar exists from night two onward.
			local gearRec: DataService.GearRecord? = nil
			if firstNight then
				gearRec = GearService.grant(plr, Config.Drops.FirstNightGear, "Common", true)
			elseif success and plan.isBoss then
				profile.stats.bossesBeaten += 1
				DataService.recordFirst(profile, "boss_" .. night)
				gearRec = GearService.rollGear(plr, night, Config.Drops.BossMinTier, true)
			end
			if gearRec then
				local gdef = GearCatalog.get(gearRec.id)
				payload.gearReward = {
					name = GearCatalog.displayName(gearRec.id, gearRec.tier),
					emoji = if gdef then gdef.emoji else "🎁",
					tier = gearRec.tier,
					desc = if gdef then gdef.desc else "",
				}
			end
			if success or firstNight then
				-- Night completion roll (bonus Legendary odds by night). A player's very first
				-- night always pays out at least a Rare so the first pull lands inside 10 minutes.
				local rec = InventoryService.rollItem(
					plr,
					night * Config.NightRollLegendaryBonusPerNight,
					nil,
					if firstNight then Config.Onboarding.FirstPullMinRarity :: any else nil
				)
				local def = rec and ToyCatalog.get(rec.id)
				if rec and def then
					payload.reward = {
						name = ToyCatalog.displayName(rec.id, rec.mutation),
						emoji = def.emoji,
						rarity = def.rarity,
						mutation = rec.mutation,
					}
				end
			end
			if not success then
				profile.stats.nightsFailed += 1
			end
			EconomyService.addCoins(plr, coins, true)
			payload.firstNight = firstNight
			payload.nightsPlayed = profile.stats.nightsPlayed
		end
		payload.night = night
		payload.state = "Results"
		payload.serverTime = workspace:GetServerTimeNow()
		Net.event("RoundState"):FireClient(plr, "Results", payload)
	end
end

local function runNight()
	local info = NightTable.get(night)
	plan = NightGen.plan(night, rng:NextInteger(1, 2 ^ 30))
	bossWon = false
	resetProps()
	BabyAI.spawn(night, plan)
	ChoreService.setup(night, plan.choreCount, not plan.isBoss)
	votes = {}

	-- Briefing: Mom's line + tonight's Baby (powers, variant, boss) so the lobby loadout choice matters.
	local dto = NightGen.dto(plan)
	local briefTime = Config.BriefingTime + (if plan.isBoss then 4 else 0)
	setState("Briefing", {
		momLine = info.momLine,
		special = info.special,
		seconds = briefTime,
		chores = plan.choreCount,
		plan = dto,
	})
	cutscene("mom_leaves", { line = info.momLine, plan = dto })
	if plan.variant.rarity ~= "Common" then
		task.delay(2, function()
			toastAll(
				("✨ A %s spawned! %gx drops, %gx coins!"):format(
					plan.variant.name,
					plan.variant.dropMult,
					plan.variant.coinMult
				),
				plan.variant.rarity
			)
			Net.event("ClipMoment"):FireAllClients("variant_spawn")
		end)
	end
	task.wait(briefTime)

	-- Night
	BabyAI.activate()
	nightEndsAt = workspace:GetServerTimeNow() + plan.duration
	setState("Night", { endsAt = nightEndsAt, duration = plan.duration, plan = dto })
	if plan.isBoss then
		toastAll(
			("BOSS NIGHT: %s! Calm it %d times before Mom's headlights."):format(plan.title, BabyAI.bossSegmentsLeft()),
			"panic"
		)
		Net.event("ClipMoment"):FireAllClients("boss_start")
	elseif info.special then
		toastAll("Tonight: " .. info.special, "star")
	end

	local bedtimeAnnounced = false
	local lastSpeedToast = 0
	local success: boolean? = nil
	while success == nil do
		task.wait(0.25)
		local now = workspace:GetServerTimeNow()
		if #Players:GetPlayers() == 0 then
			success = false
			break
		end
		if plan.isBoss then
			-- Fixed clock: crying doesn't summon Mom, it makes her drive faster.
			if bossWon then
				success = true
			elseif BabyAI.isCrying() then
				nightEndsAt -= 0.25
				if now - lastSpeedToast > 12 then
					lastSpeedToast = now
					toastAll("Mom hears the crying from the car — she's speeding up!", "warn")
				end
				if math.floor(now * 4) % 8 == 0 then
					setState("Night", { endsAt = nightEndsAt, duration = plan.duration, plan = dto })
				end
			end
			if success == nil and now >= nightEndsAt then
				success = bossWon
			end
		elseif state == "Night" then
			if BabyAI.isCrying() and BabyAI.cryingFor() >= Config.Mood.CryToPanicSeconds then
				panicEndsAt = now + Config.Mood.PanicSeconds
				setState("Panic", { endsAt = panicEndsAt })
				Net.event("Panic"):FireAllClients(true, Config.Mood.PanicSeconds)
				Net.event("ClipMoment"):FireAllClients("panic_mode")
				BabyAI.setSpeedMultiplier(Config.Mood.PanicSpeedMultiplier)
				toastAll("PANIC MODE! Mom's headlights are in the driveway! CALM THE BABY!", "panic")
			elseif not bedtimeAnnounced and now >= nightEndsAt - Config.BedtimeWindow then
				bedtimeAnnounced = true
				if ChoreService.remaining() > 0 then
					toastAll("Mom's on her way home — finish up and get Baby to bed!", "warn")
				end
			elseif ChoreService.isBedtimeDone() then
				success = true
			elseif now >= nightEndsAt then
				-- Time's up: Mom arrives. Pass if Baby isn't crying and the chores are done (bedtime optional).
				success = not BabyAI.isCrying() and ChoreService.remaining() == 0
			end
		elseif state == "Panic" then
			if not BabyAI.isCrying() then
				setState("Night", { endsAt = nightEndsAt, duration = plan.duration, plan = dto })
				Net.event("Panic"):FireAllClients(false, 0)
				BabyAI.setSpeedMultiplier(1)
				toastAll("Phew! Mom drove past... this time.", "info")
				-- Panic drains the clock a little
				nightEndsAt = math.max(now + 20, nightEndsAt - 30)
			elseif now >= panicEndsAt then
				Net.event("Panic"):FireAllClients(false, 0)
				success = false
			end
		end
	end

	-- Mom check
	BabyAI.deactivate()
	ChoreService.stop()
	nightDamage = countKnockedProps()
	setState("MomCheck", { damage = nightDamage, success = success })
	if success then
		BabyAI.calmForBed()
		cutscene("mom_check_pass", { damage = nightDamage, night = night, isBoss = plan.isBoss, title = plan.title })
		if plan.isBoss then
			Net.event("ClipMoment"):FireAllClients("boss_beaten")
		end
	else
		cutscene("mom_check_fail", {
			damage = nightDamage,
			night = night,
			reason = if plan.isBoss then "boss" elseif BabyAI.isCrying() then "crying" else "chores",
		})
		Net.event("ClipMoment"):FireAllClients("mom_fail")
	end
	task.wait(Config.MomCheckTime)

	resultsFor(success == true)
	task.wait(Config.ResultsTime)

	if success then
		if night >= Config.FinalNight then
			cutscene("birthday_finale", {})
			toastAll("NIGHT 99 COMPLETE! Baby's birthday! You can now Rebirth (New Family).", "star")
			task.wait(15)
			night = 1
		else
			night += 1
		end
	else
		night = math.max(1, night - 1) -- gentle fail: retry from one night back; collection is kept
	end
	BabyAI.despawn()
	RoundService.toLobby()
end

function RoundService.toLobby()
	votes = {}
	setState("Lobby", { nextNight = night, votes = 0, needed = math.max(1, math.ceil(#Players:GetPlayers() / 2)) })
end

local function checkVotes()
	local count = 0
	for plr in votes do
		if plr.Parent then
			count += 1
		else
			votes[plr] = nil
		end
	end
	local needed = math.max(1, math.ceil(#Players:GetPlayers() / 2))
	setState("Lobby", { nextNight = night, votes = count, needed = needed })
	if count >= needed then
		task.spawn(runNight)
	end
end

function RoundService.state(): State
	return state
end

function RoundService.night(): number
	return night
end

function RoundService.start()
	ChoreService.start(function()
		return BabyAI.isCalm() and BabyAI.isAtCrib()
	end, BabyAI.setTucking)
	BabyAI.start()
	BabyAI.BossBeaten:Connect(function()
		bossWon = true
	end)

	Net.event("RequestStart").OnServerEvent:Connect(function(player, requestedNight)
		if state ~= "Lobby" or not Net.allow(player, "Start", 2) then
			return
		end
		-- Host may pick any night up to the party's highest cleared + 1
		if type(requestedNight) == "number" then
			local maxNight = math.min(Config.FinalNight, highestNightAmongPlayers() + 1)
			night = math.clamp(math.floor(requestedNight), 1, maxNight)
		end
		votes[player] = true
		checkVotes()
	end)

	Net.event("Interact").OnServerEvent:Connect(function(player, targetName)
		if Net.allow(player, "Interact", 6) and type(targetName) == "string" then
			fixProp(player, targetName)
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local parent = prompt.Parent
		if parent and parent:GetAttribute("Prop") then
			fixProp(player, parent.Name)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			DataService.waitFor(player)
			if state == "Lobby" then
				checkVotes()
			else
				Net.event("RoundState"):FireClient(player, state, {
					night = night,
					endsAt = nightEndsAt,
					duration = plan.duration,
					plan = NightGen.dto(plan),
					state = state,
					serverTime = workspace:GetServerTimeNow(),
				})
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		votes[player] = nil
		if state == "Lobby" then
			checkVotes()
		end
	end)

	-- First night starts at the party's best night + 1 (or 1)
	task.defer(function()
		task.wait(2)
		night = math.clamp(highestNightAmongPlayers() + 1, 1, Config.FinalNight)
		RoundService.toLobby()
	end)
end

return RoundService

--!strict
-- Night counter + timer, Baby mood meter, chore list, toasts, lobby panel, results panel, panic overlay.
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local GearCatalog = require(Shared:WaitForChild("GearCatalog"))
local UI = require(script.Parent.UI)

local HUD = {}

local screen = UI.screen("HUD", 1)

-- Top bar: night + timer -------------------------------------------------------
local top = UI.frame(screen, "Top", UDim2.fromOffset(320, 64), UDim2.new(0.5, -160, 0, 12))
UI.corner(top, 16)
UI.stroke(top)
local nightLabel = UI.label(top, "Night", "NIGHT 1", UDim2.new(0.5, 0, 1, 0), UDim2.new(), nil, UI.Colors.Yellow)
local timerLabel = UI.label(top, "Timer", "--:--", UDim2.new(0.5, 0, 1, 0), UDim2.fromScale(0.5, 0))
UI.padding(top, 6)

-- Mood meter ----------------------------------------------------------------------
local moodPanel = UI.frame(screen, "Mood", UDim2.fromOffset(280, 90), UDim2.new(0.5, -140, 0, 84))
UI.corner(moodPanel, 14)
UI.stroke(moodPanel)
UI.padding(moodPanel, 8)
local moodTitle = UI.label(moodPanel, "Title", "👶 BABY: HAPPY", UDim2.new(1, 0, 0, 30))
local _, moodFill = UI.bar(moodPanel, "Bar", UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 36), UI.Colors.Green)
local wantLabel = UI.label(moodPanel, "Want", "", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 60), 16, UI.Colors.Sub)

local moodColors = {
	Happy = UI.Colors.Green,
	Grumpy = UI.Colors.Yellow,
	Fussy = Color3.fromRGB(255, 150, 60),
	Crying = UI.Colors.Red,
}

-- Tonight's powers strip (under the mood meter): lights up while the Baby is telegraphing ---------
local powerStrip = UI.frame(screen, "Powers", UDim2.fromOffset(280, 34), UDim2.new(0.5, -140, 0, 180), nil, 1)
UI.list(powerStrip, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center)
local powerChips: { [string]: TextLabel } = {}

-- Client-safe mirror of NightGen.dto.
type PowerDto = {
	id: string,
	level: number?,
	name: string?,
	emoji: string?,
	tell: string?,
	effect: string?,
	counterGear: string?,
}
type PlanDto = {
	night: number,
	powers: { PowerDto }?,
	variant: string?,
	variantName: string?,
	variantRarity: string?,
	isBoss: boolean?,
	title: string?,
	bossSegments: number?,
	duration: number?,
	choreCount: number?,
}
type GearRewardDto = { name: string?, emoji: string?, tier: string?, desc: string? }

local function setPowerStrip(plan: PlanDto?)
	for _, c in powerChips do
		c:Destroy()
	end
	powerChips = {}
	if not plan or not plan.powers then
		return
	end
	for _, p in plan.powers do
		local chip = UI.label(
			powerStrip,
			p.id,
			("%s %s%s"):format(p.emoji or "", string.upper(p.name or p.id), string.rep("+", (p.level or 1) - 1)),
			UDim2.fromOffset(0, 30),
			nil,
			15
		)
		chip.AutomaticSize = Enum.AutomaticSize.X
		chip.BackgroundTransparency = 0.15
		chip.BackgroundColor3 = UI.Colors.Panel
		UI.corner(chip, 10)
		UI.stroke(chip)
		UI.padding(chip, 6)
		powerChips[p.id] = chip
	end
end

-- The server sets Baby.Tell = <powerId> for the 1-2 s before an effect fires.
local function watchBabyTell(model: Instance)
	local function update()
		local tell = (model:GetAttribute("Tell") :: string?) or ""
		for id, chip in powerChips do
			local on = id == tell
			chip.BackgroundColor3 = if on then UI.Colors.Red else UI.Colors.Panel
			if on then
				UI.pop(chip)
			end
		end
	end
	model:GetAttributeChangedSignal("Tell"):Connect(update)
	update()
end
workspace.ChildAdded:Connect(function(child)
	if child.Name == "Baby" then
		watchBabyTell(child)
	end
end)
do
	local baby = workspace:FindFirstChild("Baby")
	if baby then
		watchBabyTell(baby)
	end
end

-- Boss Calm Bar: replaces the mood story on boss nights ----------------------------------------
local bossPanel = UI.frame(screen, "Boss", UDim2.fromOffset(340, 74), UDim2.new(0.5, -170, 0, 222))
bossPanel.Visible = false
UI.corner(bossPanel, 14)
UI.stroke(bossPanel, UI.Colors.Red, 3)
UI.padding(bossPanel, 8)
local bossTitle = UI.label(bossPanel, "Title", "", UDim2.new(1, 0, 0, 24), nil, 18, UI.Colors.Red)
local bossSegRow = UI.frame(bossPanel, "Segs", UDim2.new(1, 0, 0, 16), UDim2.fromOffset(0, 28), nil, 1)
UI.list(bossSegRow, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center)
local bossHint = UI.label(bossPanel, "Hint", "", UDim2.new(1, 0, 0, 16), UDim2.fromOffset(0, 46), 14, UI.Colors.Sub)
local bossSegs: { Frame } = {}

Net.event("BossState").OnClientEvent:Connect(function(left: number, total: number, dazed: boolean, title: string)
	bossPanel.Visible = total > 0
	bossTitle.Text = title or "BOSS BABY"
	if #bossSegs ~= total then
		for _, s in bossSegs do
			s:Destroy()
		end
		bossSegs = {}
		for i = 1, total do
			local s =
				UI.frame(bossSegRow, "Seg" .. i, UDim2.fromOffset(math.floor(300 / total), 14), nil, UI.Colors.Red)
			UI.corner(s, 6)
			bossSegs[i] = s
		end
	end
	for i, s in bossSegs do
		s.BackgroundColor3 = if i <= left then UI.Colors.Red else UI.Colors.Green
	end
	if left == 0 then
		bossHint.Text = "😴 Baby is OUT. You did it!"
		bossHint.TextColor3 = UI.Colors.Green
	elseif dazed then
		bossHint.Text = "⭐ OPENING! Shove a toy in its mouth NOW!"
		bossHint.TextColor3 = UI.Colors.Yellow
		UI.pop(bossPanel)
	else
		bossHint.Text = ("Calm it %d more time%s — wait for a slam or Bubble Trap it"):format(
			left,
			if left == 1 then "" else "s"
		)
		bossHint.TextColor3 = UI.Colors.Sub
	end
end)

Net.event("BabyMood").OnClientEvent
	:Connect(function(stageIndex: number, stageName: string, cryingFor: number, want: string?, immunity: number)
		local total = #Config.Mood.Stages
		local frac = 1 - (stageIndex - 1) / (total - 1)
		moodTitle.Text = "👶 BABY: "
			.. string.upper(stageName)
			.. (if immunity > 0 then (" 🛡️%d"):format(math.ceil(immunity)) else "")
		UI.tween(moodFill, {
			Size = UDim2.fromScale(math.max(0.03, frac), 1),
			BackgroundColor3 = moodColors[stageName] or UI.Colors.Green,
		}, 0.3)
		if want then
			wantLabel.Text = if want == "Snack" then "Baby wants a SNACK 🍌" else "Baby wants a TOY 🧸"
		elseif stageName == "Crying" then
			wantLabel.Text = ("CRYING for %ds — Mom at %ds!"):format(
				math.floor(cryingFor),
				Config.Mood.CryToPanicSeconds
			)
		else
			wantLabel.Text = ""
		end
		if stageName == "Crying" then
			moodPanel.BackgroundColor3 = Color3.fromRGB(120, 30, 40)
		else
			moodPanel.BackgroundColor3 = UI.Colors.Panel
		end
	end)

-- Chore list ------------------------------------------------------------------------
local chorePanel = UI.frame(
	screen,
	"Chores",
	UDim2.fromOffset(260, 40),
	if UI.Touch then UDim2.new(0, 12, 0, 70) else UDim2.new(0, 12, 0.5, -120)
)
chorePanel.AutomaticSize = Enum.AutomaticSize.Y
UI.corner(chorePanel, 14)
UI.stroke(chorePanel)
UI.padding(chorePanel, 8)
UI.list(chorePanel, nil, 4)
local choreTitle = UI.label(chorePanel, "Title", "📋 CHORES", UDim2.new(1, 0, 0, 26))
choreTitle.LayoutOrder = 0

local choreRows: { [string]: Frame } = {}

local function ensureRow(id: string, order: number): Frame
	local row = choreRows[id]
	if row then
		row.LayoutOrder = order
		return row
	end
	row = UI.frame(chorePanel, id, UDim2.new(1, 0, 0, 30), UDim2.new(), UI.Colors.PanelLight)
	row.LayoutOrder = order
	UI.corner(row, 8)
	local name = UI.label(row, "Name", "", UDim2.new(1, -8, 0, 18), UDim2.fromOffset(6, 0), 15)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local _, fill = UI.bar(row, "Bar", UDim2.new(1, -12, 0, 6), UDim2.new(0, 6, 1, -9), UI.Colors.Blue)
	fill.Size = UDim2.fromScale(0, 1)
	choreRows[id] = row
	return row
end

local doneChores: { [string]: boolean } = {}
Net.event("ChoreList").OnClientEvent:Connect(function(chores)
	local seen = {}
	for i, c in chores do
		seen[c.id] = true
		if c.done and not doneChores[c.id] then
			Sounds.play("Ding")
		elseif c.messedUp and doneChores[c.id] then
			Sounds.play("SlideWhistle")
		end
		doneChores[c.id] = c.done == true
		local row = ensureRow(c.id, i)
		local name = row:FindFirstChild("Name") :: TextLabel
		local fill = (row:FindFirstChild("Bar") :: Frame):FindFirstChild("Fill") :: Frame
		local prefix = if c.done then "✅ " elseif c.messedUp then "💥 " elseif c.isBedtime then "🌙 " else "▫️ "
		local worker = if c.worker and not c.done then (" (" .. c.worker .. ")") else ""
		name.Text = prefix .. c.name .. worker
		name.TextColor3 = if c.done then UI.Colors.Green elseif c.messedUp then UI.Colors.Red else UI.Colors.Text
		UI.tween(fill, { Size = UDim2.fromScale(if c.done then 1 else c.progress, 1) }, 0.2)
		row.BackgroundTransparency = if c.done then 0.5 else 0
	end
	for id, row in choreRows do
		if not seen[id] then
			row:Destroy()
			choreRows[id] = nil
			doneChores[id] = nil
		end
	end
end)

-- Toasts -----------------------------------------------------------------------------
local toastHolder = UI.frame(screen, "Toasts", UDim2.fromOffset(420, 200), UDim2.new(0.5, -210, 0, 190), nil, 1)
UI.list(toastHolder, nil, 4, Enum.HorizontalAlignment.Center)

local toastColors: { [string]: Color3 } = {
	info = UI.Colors.Panel,
	warn = Color3.fromRGB(200, 120, 30),
	error = UI.Colors.Red,
	coins = Color3.fromRGB(60, 140, 80),
	star = Color3.fromRGB(190, 120, 30),
	panic = Color3.fromRGB(160, 20, 30),
}

function HUD.toast(text: string, kind: string?)
	local color = toastColors[kind or "info"] or Rarity.Colors[kind :: any] or UI.Colors.Panel
	local t = UI.label(toastHolder, "Toast", text, UDim2.new(1, 0, 0, 34), nil, 20)
	t.BackgroundTransparency = 0.1
	t.BackgroundColor3 = color
	t.TextWrapped = true
	UI.corner(t, 10)
	UI.stroke(t)
	UI.pop(t)
	if kind == "coins" or kind == "star" then
		Sounds.play("Ding", nil, 0.5)
	elseif kind == "error" or kind == "panic" then
		Sounds.play("RecordScratch", nil, 0.6)
	elseif kind and Rarity.Colors[kind :: any] then
		Sounds.play("DeskBell")
	end
	task.delay(4, function()
		UI.tween(t, { TextTransparency = 1, BackgroundTransparency = 1 }, 0.4).Completed:Wait()
		t:Destroy()
	end)
end
Net.event("Toast").OnClientEvent:Connect(HUD.toast)

-- Lobby panel --------------------------------------------------------------------------
local lobby = UI.frame(screen, "Lobby", UDim2.fromOffset(360, 230), UDim2.new(0.5, -180, 0.5, -115))
UI.corner(lobby, 18)
UI.stroke(lobby, UI.Colors.Accent, 3)
UI.padding(lobby, 12)
UI.label(lobby, "Title", "STOP THE BABY 👶", UDim2.new(1, 0, 0, 44), nil, nil, UI.Colors.Yellow)
local lobbyNight = UI.label(lobby, "Night", "Next: NIGHT 1", UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, 48))
local lobbyVotes =
	UI.label(lobby, "Votes", "0/1 ready", UDim2.new(1, 0, 0, 24), UDim2.fromOffset(0, 80), 18, UI.Colors.Sub)
local minusBtn =
	UI.button(lobby, "Minus", "◀", UDim2.fromOffset(44, 44), UDim2.new(0, 10, 1, -60), UI.Colors.PanelLight)
local plusBtn =
	UI.button(lobby, "Plus", "▶", UDim2.fromOffset(44, 44), UDim2.new(1, -54, 1, -60), UI.Colors.PanelLight)
local readyBtn =
	UI.button(lobby, "Ready", "READY!", UDim2.fromOffset(200, 54), UDim2.new(0.5, -100, 1, -66), UI.Colors.Green)

local selectedNight = 1
local lobbyNextNight = 1
minusBtn.MouseButton1Click:Connect(function()
	selectedNight = math.max(1, selectedNight - 1)
	lobbyNight.Text = "Next: NIGHT " .. selectedNight
end)
plusBtn.MouseButton1Click:Connect(function()
	selectedNight = math.min(lobbyNextNight, selectedNight + 1)
	lobbyNight.Text = "Next: NIGHT " .. selectedNight
end)
readyBtn.MouseButton1Click:Connect(function()
	Net.event("RequestStart"):FireServer(selectedNight)
	readyBtn.Text = "WAITING..."
end)

-- Briefing card: tonight's Baby (powers -> tell -> counter), variant, boss, chores -------------
local brief = UI.frame(screen, "Briefing", UDim2.fromOffset(400, 250), UDim2.new(0.5, 180, 0.5, -200))
brief.Visible = false
UI.corner(brief, 18)
local briefStroke = UI.stroke(brief, UI.Colors.Accent, 3)
UI.padding(brief, 12)
local briefTitle = UI.label(brief, "Title", "TONIGHT'S BABY", UDim2.new(1, 0, 0, 30), nil, 22, UI.Colors.Yellow)
local briefVariant = UI.label(brief, "Variant", "", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 30), 16, UI.Colors.Sub)
local briefList = UI.frame(brief, "List", UDim2.new(1, 0, 1, -84), UDim2.fromOffset(0, 56), nil, 1)
UI.list(briefList, Enum.FillDirection.Vertical, 6)
local briefFoot = UI.label(brief, "Foot", "", UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 1, -22), 15, UI.Colors.Sub)
briefFoot.TextWrapped = true

local function showBriefing(plan: PlanDto?, chores: number)
	for _, c in briefList:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	if not plan then
		brief.Visible = false
		return
	end
	local isBoss = plan.isBoss == true
	briefTitle.Text = if isBoss then ("💀 BOSS: %s"):format(plan.title or "BOSS BABY") else "TONIGHT'S BABY"
	briefTitle.TextColor3 = if isBoss then UI.Colors.Red else UI.Colors.Yellow
	briefStroke.Color = if isBoss then UI.Colors.Red else UI.Colors.Accent
	local rarity = plan.variantRarity or "Common"
	if rarity ~= "Common" then
		briefVariant.Text = ("✨ %s %s — rarer Baby, bigger drops"):format(
			string.upper(rarity),
			plan.variantName or "Baby"
		)
		briefVariant.TextColor3 = Rarity.Colors[rarity :: Rarity.RarityName] or UI.Colors.Sub
	else
		briefVariant.Text = "A regular Baby. Regular is relative."
		briefVariant.TextColor3 = UI.Colors.Sub
	end
	local n = 0
	for _, p in (plan.powers or {}) :: { PowerDto } do
		n += 1
		local row = UI.frame(briefList, "P" .. n, UDim2.new(1, 0, 0, 52), nil, UI.Colors.PanelLight)
		row.LayoutOrder = n
		UI.corner(row, 10)
		UI.padding(row, 6)
		local counter = GearCatalog.get(p.counterGear or "")
		UI.label(
			row,
			"Name",
			("%s %s%s"):format(p.emoji or "", string.upper(p.name or p.id), string.rep("+", (p.level or 1) - 1)),
			UDim2.new(0.55, 0, 0, 20),
			nil,
			17
		).TextXAlignment =
			Enum.TextXAlignment.Left
		local ctr = UI.label(
			row,
			"Counter",
			if counter then ("Counter: %s %s"):format(counter.emoji, counter.name) else "",
			UDim2.new(0.45, 0, 0, 20),
			UDim2.fromScale(0.55, 0),
			13,
			UI.Colors.Green
		)
		ctr.TextXAlignment = Enum.TextXAlignment.Right
		local tell = UI.label(
			row,
			"Tell",
			("👀 %s → %s"):format(p.tell or "", p.effect or ""),
			UDim2.new(1, 0, 0, 20),
			UDim2.fromOffset(0, 22),
			13,
			UI.Colors.Sub
		)
		tell.TextXAlignment = Enum.TextXAlignment.Left
		tell.TextTruncate = Enum.TextTruncate.AtEnd
	end
	brief.Size = UDim2.fromOffset(400, 110 + n * 58)
	brief.Position = UDim2.new(0.5, 180, 0.5, -(110 + n * 58) / 2)
	briefFoot.Text = if isBoss
		then ("Calm Bar x%d. Mom's on a fixed clock — crying makes her drive faster."):format(plan.bossSegments or 3)
		else ("%d chore%s tonight. Chores are the clock; the Baby is the problem."):format(
			chores,
			if chores == 1 then "" else "s"
		)
	brief.Visible = true
	UI.pop(brief)
end

-- Results panel -------------------------------------------------------------------------
local results = UI.frame(screen, "Results", UDim2.fromOffset(420, 410), UDim2.new(0.5, -210, 0.5, -205))
results.Visible = false
UI.corner(results, 18)
UI.stroke(results, UI.Colors.Yellow, 3)
UI.padding(results, 12)
local resTitle = UI.label(results, "Title", "", UDim2.new(1, 0, 0, 48))
local resStars = UI.label(results, "Stars", "", UDim2.new(1, 0, 0, 44), UDim2.fromOffset(0, 52), nil, UI.Colors.Yellow)
local resBody = UI.label(results, "Body", "", UDim2.new(1, 0, 0, 52), UDim2.fromOffset(0, 100), 20, UI.Colors.Sub)
resBody.TextWrapped = true
-- New toy card (rarity-colored) revealed a beat after the panel
local resToy = UI.frame(results, "Toy", UDim2.new(1, 0, 0, 78), UDim2.fromOffset(0, 156), UI.Colors.PanelLight)
UI.corner(resToy, 14)
local resToyStroke = UI.stroke(resToy, UI.Colors.Blue, 3)
local resToyTag = UI.label(resToy, "Tag", "NEW TOY!", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 4), 16, UI.Colors.Sub)
local resToyName = UI.label(resToy, "Name", "", UDim2.new(1, 0, 0, 48), UDim2.fromOffset(0, 26), 26)
-- Gear card (drops that change how you play), below the toy card
local resGear = UI.frame(results, "Gear", UDim2.new(1, 0, 0, 78), UDim2.fromOffset(0, 240), UI.Colors.PanelLight)
UI.corner(resGear, 14)
local resGearStroke = UI.stroke(resGear, UI.Colors.Green, 3)
local resGearTag =
	UI.label(resGear, "Tag", "NEW GEAR!", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 4), 16, UI.Colors.Sub)
local resGearName = UI.label(resGear, "Name", "", UDim2.new(1, 0, 0, 48), UDim2.fromOffset(0, 26), 26)
local resTip = UI.label(results, "Tip", "", UDim2.new(1, 0, 0, 60), UDim2.fromOffset(0, 324), 17, UI.Colors.Sub)
resTip.TextWrapped = true

local function revealGear(reward: GearRewardDto?)
	resGear.Visible = false
	if not reward then
		return
	end
	local tier = reward.tier or "Common"
	local color = Rarity.Colors[tier :: Rarity.RarityName] or UI.Colors.Green
	resGearStroke.Color = color
	resGearName.TextColor3 = color
	resGearName.Text = ("%s %s"):format(reward.emoji or "🧰", reward.name or "Gear")
	resGearTag.Text = if reward.desc and reward.desc ~= "" then "NEW GEAR — " .. reward.desc else "NEW GEAR!"
	resGearTag.TextTruncate = Enum.TextTruncate.AtEnd
	task.delay(1.6, function()
		if results.Visible then
			resGear.Visible = true
			UI.pop(resGear)
			Sounds.play("DeskBell")
		end
	end)
end

local function revealToy(reward)
	resToy.Visible = false
	if not reward then
		return
	end
	local color = Rarity.Colors[reward.rarity :: any] or UI.Colors.Blue
	resToyStroke.Color = color
	resToyName.TextColor3 = color
	resToyName.Text = ("%s %s"):format(reward.emoji or "", reward.name or "")
	resToyTag.Text = if reward.mutation
		then ("NEW %s TOY — %s MUTATION!"):format(string.upper(reward.rarity), string.upper(reward.mutation))
		else ("NEW %s TOY!"):format(string.upper(reward.rarity))
	task.delay(0.9, function()
		if results.Visible then
			resToy.Visible = true
			UI.pop(resToy)
			Sounds.play(if Rarity.index(reward.rarity) >= Rarity.index("Epic") then "DeskBell" else "Ding")
		end
	end)
end

local failTips = {
	crying = "Tip: when Baby cries, get close and press 1/2 to give a toy — or hold E to CARRY Baby to the crib.",
	chores = "Tip: finish every chore on the list, then put Baby to bed before Mom's car pulls in.",
}

-- Like / Favorite + group card (shown once after the first survived night) ---------------------
local likeCard = UI.frame(screen, "LikeCard", UDim2.fromOffset(340, 120), UDim2.new(0.5, 230, 1, -230))
likeCard.Visible = false
UI.corner(likeCard, 16)
UI.stroke(likeCard, UI.Colors.Accent, 3)
UI.padding(likeCard, 10)
local likeText = UI.label(likeCard, "Text", "", UDim2.new(1, 0, 0, 70), nil, 18)
likeText.TextWrapped = true
local likeOk =
	UI.button(likeCard, "Ok", "OKAY!", UDim2.fromOffset(140, 34), UDim2.new(0.5, -70, 1, -36), UI.Colors.Green)
likeOk.MouseButton1Click:Connect(function()
	likeCard.Visible = false
end)
local likeShown = false

local function showLikeCard()
	if likeShown then
		return
	end
	likeShown = true
	likeText.Text = "Having fun? 👍 Like & ⭐ Favorite Stop the Baby so your friends can find it!"
		.. (if Config.GroupId ~= 0 then "\nJoin our group for Grandma's daily gift 🎁" else "")
	likeCard.Visible = true
	UI.pop(likeCard)
end

-- Panic overlay -----------------------------------------------------------------------------
local panic = UI.frame(screen, "Panic", UDim2.fromScale(1, 1), UDim2.new(), UI.Colors.Red, 1)
panic.Visible = false
panic.ZIndex = 0
local panicText = UI.label(
	panic,
	"Text",
	"🚨 PANIC MODE 🚨",
	UDim2.new(1, 0, 0, 90),
	UDim2.new(0, 0, 0.18, 0),
	nil,
	UI.Colors.Red
)
local panicSub =
	UI.label(panic, "Sub", "MOM'S HEADLIGHTS! CALM THE BABY!", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0.18, 90), 26)
local panicTimer =
	UI.label(panic, "Timer", "30", UDim2.new(1, 0, 0, 120), UDim2.new(0, 0, 0.18, 130), nil, UI.Colors.Text)
local panicEndsAt = 0

Net.event("Panic").OnClientEvent:Connect(function(active: boolean, seconds: number)
	panic.Visible = active
	panicEndsAt = workspace:GetServerTimeNow() + seconds
	if active then
		UI.pop(panicText)
		Sounds.play("CarHorn")
		task.delay(0.7, function()
			if panic.Visible then
				Sounds.play("CarHorn", nil, 0.8)
			end
		end)
	end
end)

-- Round state ---------------------------------------------------------------------------------
local endsAt = 0
local state = "Lobby"

Net.event("RoundState").OnClientEvent:Connect(function(newState: string, payload)
	state = newState
	nightLabel.Text = "NIGHT " .. tostring(payload.night)
	lobby.Visible = newState == "Lobby"
	results.Visible = newState == "Results"
	chorePanel.Visible = newState == "Night" or newState == "Panic"
	moodPanel.Visible = newState ~= "Lobby" and newState ~= "Results"
	powerStrip.Visible = moodPanel.Visible
	if newState == "Lobby" or newState == "Results" then
		bossPanel.Visible = false
	end
	if payload.plan then
		setPowerStrip(payload.plan)
	end
	brief.Visible = newState == "Briefing"
	if newState == "Lobby" then
		lobbyNextNight = payload.nextNight or 1
		selectedNight = lobbyNextNight
		lobbyNight.Text = "Next: NIGHT " .. selectedNight
		lobbyVotes.Text = ("%d/%d ready"):format(payload.votes or 0, payload.needed or 1)
		readyBtn.Text = "READY!"
		panic.Visible = false
	elseif newState == "Briefing" then
		showBriefing(payload.plan, payload.chores or 0)
	elseif newState == "Night" then
		endsAt = payload.endsAt or 0
	elseif newState == "Results" then
		local stars = payload.stars or 0
		Sounds.play(if payload.success then "DeskBell" else "DoorSlam")
		resTitle.Text = if payload.success then "NIGHT SURVIVED! 🎉" else "MOM CAME HOME. 😬"
		resTitle.TextColor3 = if payload.success then UI.Colors.Green else UI.Colors.Red
		resStars.Text = string.rep("⭐", stars) .. string.rep("☆", 3 - stars)
		resBody.Text = ("+%d Diaper Coins • %d things broken%s"):format(
			payload.coins or 0,
			payload.damage or 0,
			if payload.finale then "\n🎂 NIGHT 99 — BIRTHDAY! REBIRTH UNLOCKED" else ""
		)
		revealToy(payload.reward)
		revealGear(payload.gearReward)
		if payload.success then
			local nextNight = (payload.night or 1) + 1
			resTip.Text = if payload.firstNight
				then "Every night = new loot. Gear counters Baby's powers — check the briefing and bring the right kit."
				elseif
					nextNight % 10 == 0
				then ("Next: Night %d — BOSS NIGHT. Bring counters for its powers."):format(nextNight)
				else ("Next: Night %d — Baby gets a new power soon. Gear up."):format(nextNight)
		else
			resTip.Text = failTips[payload.reason or ""] or failTips.chores
		end
		UI.pop(results)
		if payload.success and (payload.nightsPlayed or 0) >= Config.Onboarding.LikePromptAfterNights then
			task.delay(Config.ResultsTime + 2, showLikeCard)
		end
	end
end)

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	if state == "Night" or state == "Panic" then
		local left = math.max(0, endsAt - now)
		timerLabel.Text = ("%d:%02d"):format(math.floor(left / 60), math.floor(left % 60))
		timerLabel.TextColor3 = if left < Config.BedtimeWindow then UI.Colors.Yellow else UI.Colors.Text
	elseif state == "Briefing" then
		timerLabel.Text = "Mom leaving..."
	else
		timerLabel.Text = "--:--"
	end
	if panic.Visible then
		local left = math.max(0, panicEndsAt - now)
		panicTimer.Text = tostring(math.ceil(left))
		panic.BackgroundTransparency = 0.75 + 0.15 * math.sin(os.clock() * 8)
		panicSub.TextTransparency = 0.2 + 0.2 * math.sin(os.clock() * 8)
	end
end)

function HUD.state(): string
	return state
end

return HUD

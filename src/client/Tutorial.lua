--!strict
-- First-session coach: short, event-driven prompts that walk a brand-new player through
-- the loop (ready -> chore -> mood -> soothe -> crying -> bedtime). Only shown to players
-- with zero nights played; every prompt fires at most once and auto-hides.
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local UI = require(script.Parent.UI)
local HUD = require(script.Parent.HUD)

local Tutorial = {}

local touch = UserInputService.TouchEnabled
local hold = if touch then "hold the HOLD button" else "hold E"
local slot = if touch then "tap a hotbar slot" else "press 1 or 2"

type Step = { id: string, text: string, seconds: number }
local STEPS: { Step } = {
	{ id = "ready", text = "You're the babysitter tonight! Press READY to start Night 1.", seconds = 12 },
	{
		id = "briefing",
		text = "Mom's leaving YOU in charge. Keep Baby happy and finish the chores before she's back!",
		seconds = 10,
	},
	{ id = "chore", text = ("Walk to a chore on the 📋 list and %s to do it."):format(hold), seconds = 12 },
	{ id = "chore_done", text = "Chore done = 🪙 coins! Now keep an eye on Baby's mood bar up top.", seconds = 9 },
	{
		id = "grumpy",
		text = ("Baby's getting grumpy! Stand near Baby and %s to give a toy or snack."):format(slot),
		seconds = 10,
	},
	{
		id = "crying",
		text = ("CRYING! If Mom hears this you LOSE. Give a toy — or %s on Baby to CARRY it to the crib."):format(
			hold
		),
		seconds = 10,
	},
	{ id = "bedtime", text = "All chores done! Carry Baby to the crib and put it to bed 🌙", seconds = 10 },
}

local stepById: { [string]: Step } = {}
for _, s in STEPS do
	stepById[s.id] = s
end

local screen = UI.screen("Coach", 4)
local card = UI.frame(
	screen,
	"Card",
	UDim2.fromOffset(300, 112),
	if UI.Touch then UDim2.new(1, -312, 0, 170) else UDim2.new(1, -312, 1, -300)
)
card.Visible = false
UI.corner(card, 16)
UI.stroke(card, UI.Colors.Blue, 3)
UI.padding(card, 10)
UI.label(card, "Title", "👶 COACH", UDim2.new(1, 0, 0, 22), nil, 16, UI.Colors.Blue).TextXAlignment =
	Enum.TextXAlignment.Left
local body = UI.label(card, "Body", "", UDim2.new(1, 0, 1, -26), UDim2.fromOffset(0, 26), 17)
body.TextWrapped = true
body.TextYAlignment = Enum.TextYAlignment.Top

local enabled = false
local shown: { [string]: boolean } = {}
local showSeq = 0

local function show(id: string)
	local step = stepById[id]
	if not enabled or not step or shown[id] then
		return
	end
	shown[id] = true
	showSeq += 1
	local seq = showSeq
	body.Text = step.text
	card.Visible = true
	UI.pop(card)
	Sounds.play("Ding", nil, 0.4)
	task.delay(step.seconds, function()
		if showSeq == seq then
			card.Visible = false
		end
	end)
end

local function hide()
	showSeq += 1
	card.Visible = false
end

-- Triggers ------------------------------------------------------------------------------
Net.event("RoundState").OnClientEvent:Connect(function(state: string, payload)
	if state == "Lobby" then
		show("ready")
	elseif state == "Briefing" then
		show("briefing")
	elseif state == "Night" then
		if not shown.chore then
			task.delay(1.5, show, "chore")
		end
	elseif state == "Results" or state == "MomCheck" then
		hide()
		if payload and (payload.nightsPlayed or 0) >= 1 then
			enabled = false -- coach retires after the first night
		end
	end
end)

Net.event("ChoreList").OnClientEvent:Connect(function(chores)
	local anyDone, allRegularDone = false, true
	for _, c in chores do
		if c.isBedtime then
			continue
		end
		if c.done then
			anyDone = true
		else
			allRegularDone = false
		end
	end
	if anyDone then
		show("chore_done")
	end
	if allRegularDone and #chores > 0 then
		show("bedtime")
	end
end)

Net.event("BabyMood").OnClientEvent:Connect(function(stageIndex: number, stageName: string, _, want: string?)
	if stageName == "Crying" then
		show("crying")
	elseif stageIndex >= 2 or want then
		show("grumpy")
	end
end)

-- Enable only for players with zero nights played ------------------------------------------
task.spawn(function()
	if not Config.Onboarding.CoachEnabled then
		return
	end
	local ok, profile = pcall(function()
		return Net.func("GetProfile"):InvokeServer()
	end)
	if ok and profile and profile.stats and (profile.stats.nightsPlayed or 0) == 0 then
		enabled = true
		if HUD.state() == "Lobby" then
			show("ready")
		end
	end
end)

function Tutorial.isActive(): boolean
	return enabled
end

return Tutorial

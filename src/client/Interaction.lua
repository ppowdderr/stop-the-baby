--!strict
-- Context action: hold E / tap-and-hold button near a chore station to work; near Baby to carry.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local ChoreCatalog = require(Shared:WaitForChild("ChoreCatalog"))
local UI = require(script.Parent.UI)

local Interaction = {}

local player = Players.LocalPlayer
local screen = UI.screen("Interact", 2)

local prompt = UI.frame(screen, "Prompt", UDim2.fromOffset(300, 56), UDim2.new(0.5, -150, 0.72, 0))
prompt.Visible = false
UI.corner(prompt, 14)
UI.stroke(prompt, UI.Colors.Yellow, 2)
local promptText = UI.label(prompt, "Text", "", UDim2.fromScale(1, 1), nil, 22)

-- Big mobile action button (bottom-right)
local actionBtn =
	UI.button(screen, "Action", "HOLD", UDim2.fromOffset(110, 110), UDim2.new(1, -140, 1, -260), UI.Colors.Yellow)
actionBtn.Visible = UserInputService.TouchEnabled

type Target = { kind: "Chore", id: string, name: string, verb: string } | { kind: "Carry" } | nil

local chores: { [string]: { station: string, name: string, verb: string, done: boolean } } = {}
local holding = false
local current: Target = nil
local currentKey = ""
local inRound = false

Net.event("ChoreList").OnClientEvent:Connect(function(list)
	chores = {}
	for _, c in list do
		local def = ChoreCatalog.get(c.id)
		if def and not c.done then
			chores[c.id] = { station = def.station, name = c.name, verb = def.verb, done = c.done }
		end
	end
end)

Net.event("RoundState").OnClientEvent:Connect(function(state)
	inRound = state == "Night" or state == "Panic"
	if not inRound and holding then
		holding = false
		Net.event("StopChore"):FireServer()
		Net.event("CarryBaby"):FireServer(false)
	end
end)

local function keyOf(t: Target): string
	if t == nil then
		return ""
	elseif t.kind == "Chore" then
		return "chore:" .. t.id
	else
		return "carry"
	end
end

local function findTarget(): Target
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local map = workspace:FindFirstChild("Map")
	local stations = map and map:FindFirstChild("Stations")
	if not hrp or not stations or not inRound then
		return nil
	end
	local best: Target = nil
	local bestDist = math.huge
	for id, c in chores do
		local st = stations:FindFirstChild(c.station)
		if st and st:IsA("BasePart") then
			local d = (st.Position - hrp.Position).Magnitude
			local range = 12 * math.max(1, st.Size.Magnitude / 8)
			if d <= range and d < bestDist then
				bestDist = d
				best = { kind = "Chore", id = id, name = c.name, verb = c.verb }
			end
		end
	end
	local baby = workspace:FindFirstChild("Baby")
	local babyRoot = baby and baby:FindFirstChild("HumanoidRootPart") :: BasePart?
	if babyRoot then
		local scale = (baby :: Model):GetAttribute("Scale") or 2
		local d = (babyRoot.Position - hrp.Position).Magnitude
		if d <= 10 * scale + 6 and (best == nil or d < bestDist * 0.8) then
			best = { kind = "Carry" }
		end
	end
	return best
end

local function startHold()
	if holding or current == nil then
		return
	end
	holding = true
	if current.kind == "Chore" then
		Net.event("StartChore"):FireServer(current.id)
	else
		Net.event("CarryBaby"):FireServer(true)
	end
	actionBtn.Text = "..."
end

local function stopHold()
	if not holding then
		return
	end
	holding = false
	Net.event("StopChore"):FireServer()
	Net.event("CarryBaby"):FireServer(false)
	actionBtn.Text = "HOLD"
end

ContextActionService:BindAction("Interact", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		startHold()
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		stopHold()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonX)

actionBtn.MouseButton1Down:Connect(startHold)
actionBtn.MouseButton1Up:Connect(stopHold)
actionBtn.MouseLeave:Connect(stopHold)

RunService.Heartbeat:Connect(function()
	local t = findTarget()
	local k = keyOf(t)
	if k ~= currentKey then
		if holding then
			stopHold()
		end
		current = t
		currentKey = k
	end
	prompt.Visible = t ~= nil
	actionBtn.Visible = UserInputService.TouchEnabled and t ~= nil
	if t then
		local keyHint = if UserInputService.TouchEnabled then "" else "[E] "
		if t.kind == "Chore" then
			promptText.Text = keyHint .. "Hold to " .. t.verb .. " — " .. t.name
		else
			local baby = workspace:FindFirstChild("Baby")
			local carried = baby and baby:GetAttribute("Carried")
			promptText.Text = keyHint .. (if carried then "Carrying Baby (release to drop)" else "Hold to CARRY Baby")
		end
	end
end)

return Interaction

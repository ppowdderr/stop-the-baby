--!strict
-- Gear bar (4 loadout slots, Z/X/C/V or tap) + Gear Bag panel (equip / unequip / fuse 3->1).
-- Gear is separate from the toy hotbar: toys are consumables, gear is your kit against Baby's powers.
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local GearCatalog = require(Shared:WaitForChild("GearCatalog"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local UI = require(script.Parent.UI)

local Gear = {}

local screen = UI.screen("Gear", 3)

type GearRecord = { uid: string, id: string, tier: string, obtained: number }
local owned: { GearRecord } = {}
local loadout: { [string]: string } = {}
local charges: { [string]: number } = {}
local inRound = false
local selectedSlot = 1

local SLOTS = GearCatalog.MaxLoadout
local KEYS = { Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C, Enum.KeyCode.V }
local KEY_NAMES = { "Z", "X", "C", "V" }

local function tierColor(tier: string): Color3
	return Rarity.Colors[tier :: Rarity.RarityName] or UI.Colors.Panel
end

local function findRecord(uid: string?): GearRecord?
	if not uid then
		return nil
	end
	for _, rec in owned do
		if rec.uid == uid then
			return rec
		end
	end
	return nil
end

local function slotRecord(slot: number): GearRecord?
	return findRecord(loadout[tostring(slot)])
end

-- Gear bar ---------------------------------------------------------------------------------
-- Desktop: right of the toy hotbar. Touch: stacked above it (the action button owns the right side).
local bar = UI.frame(
	screen,
	"GearBar",
	UDim2.fromOffset(SLOTS * 66, 70),
	if UI.Touch then UDim2.new(0.5, -8 * 33, 1, -166) else UDim2.new(0.5, 8 * 33 + 10, 1, -90),
	nil,
	1
)
UI.list(bar, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left)
local slotBtns: { TextButton } = {}
local slotCharges: { TextLabel } = {}
local slotStrokes: { UIStroke } = {}

local function refreshBar()
	for i = 1, SLOTS do
		local b = slotBtns[i]
		local rec = slotRecord(i)
		local def = rec and GearCatalog.get(rec.id)
		if rec and def then
			b.Text = def.emoji
			b.BackgroundColor3 = tierColor(rec.tier)
			slotStrokes[i].Color = if def.kind == "Passive" then UI.Colors.Green else Color3.new(1, 1, 1)
			if def.kind == "Active" then
				local c = charges[rec.uid]
				slotCharges[i].Text = if c ~= nil
					then ("x%d"):format(c)
					else ("x%d"):format(GearCatalog.charges(def, rec.tier))
				slotCharges[i].TextColor3 = if c == 0 then UI.Colors.Red else UI.Colors.Text
				b.TextTransparency = if c == 0 then 0.6 else 0
			else
				slotCharges[i].Text = "ON"
				slotCharges[i].TextColor3 = UI.Colors.Green
				b.TextTransparency = 0
			end
		else
			b.Text = "+"
			b.TextTransparency = 0.5
			b.BackgroundColor3 = UI.Colors.Panel
			slotStrokes[i].Color = UI.Colors.PanelLight
			slotCharges[i].Text = ""
		end
	end
end

local panel: Frame
local refreshPanel: () -> ()

local function openPanel(slot: number?)
	if slot then
		selectedSlot = slot
	end
	refreshPanel()
	panel.Visible = true
	UI.pop(panel)
end

local function useSlot(i: number)
	local rec = slotRecord(i)
	local def = rec and GearCatalog.get(rec.id)
	if not rec or not def then
		openPanel(i)
		return
	end
	if def.kind == "Passive" then
		Sounds.play("Ding", nil, 0.4)
		UI.pop(slotBtns[i])
		return
	end
	if not inRound then
		openPanel(i)
		return
	end
	if (charges[rec.uid] or 0) <= 0 then
		Sounds.play("RecordScratch", nil, 0.4)
		return
	end
	Net.event("UseGear"):FireServer(rec.uid)
	UI.pop(slotBtns[i])
end

for i = 1, SLOTS do
	local b = UI.button(bar, "Slot" .. i, "+", UDim2.fromOffset(60, 60), nil, UI.Colors.Panel)
	b.LayoutOrder = i
	b.TextSize = 28
	b.TextScaled = false
	slotStrokes[i] = b:FindFirstChildOfClass("UIStroke") :: UIStroke
	local key = UI.label(b, "Key", KEY_NAMES[i], UDim2.fromOffset(16, 16), UDim2.fromOffset(3, 1), 12, UI.Colors.Sub)
	key.Visible = not UI.Touch
	slotCharges[i] = UI.label(b, "Charges", "", UDim2.fromOffset(30, 16), UDim2.new(1, -32, 1, -17), 12)
	slotCharges[i].TextXAlignment = Enum.TextXAlignment.Right
	b.MouseButton1Click:Connect(function()
		useSlot(i)
	end)
	slotBtns[i] = b
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local slot = table.find(KEYS, input.KeyCode)
	if slot then
		useSlot(slot)
	elseif input.KeyCode == Enum.KeyCode.G then
		if panel.Visible then
			panel.Visible = false
		else
			openPanel(nil)
		end
	end
end)

-- Gear Bag panel ---------------------------------------------------------------------------------
local openBtn = UI.button(
	screen,
	"Open",
	"🧰 GEAR",
	UDim2.fromOffset(120, 44),
	if UI.Touch then UDim2.new(1, -150, 1, -396) else UDim2.new(1, -132, 0, 164),
	UI.Colors.Green
)
openBtn.MouseButton1Click:Connect(function()
	if panel.Visible then
		panel.Visible = false
	else
		openPanel(nil)
	end
end)

panel = UI.frame(screen, "Panel", UDim2.fromOffset(640, 440), UDim2.new(0.5, -320, 0.5, -220))
panel.Visible = false
UI.corner(panel, 18)
UI.stroke(panel, UI.Colors.Green, 3)
UI.padding(panel, 12)
UI.label(panel, "Title", "🧰 GEAR BAG", UDim2.new(1, -60, 0, 36))
local closeBtn = UI.button(panel, "Close", "✕", UDim2.fromOffset(40, 40), UDim2.new(1, -40, 0, 0), UI.Colors.Red)
closeBtn.MouseButton1Click:Connect(function()
	panel.Visible = false
end)

-- Loadout row: tap a slot to pick where the next EQUIP goes.
local loadRow = UI.frame(panel, "Loadout", UDim2.new(1, 0, 0, 70), UDim2.fromOffset(0, 42), nil, 1)
UI.list(loadRow, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
local loadBtns: { TextButton } = {}
local loadStrokes: { UIStroke } = {}
for i = 1, SLOTS do
	local b = UI.button(loadRow, "L" .. i, "+", UDim2.fromOffset(64, 64), nil, UI.Colors.Panel)
	b.LayoutOrder = i
	b.TextSize = 30
	b.TextScaled = false
	loadStrokes[i] = b:FindFirstChildOfClass("UIStroke") :: UIStroke
	UI.label(b, "Num", tostring(i), UDim2.fromOffset(16, 16), UDim2.fromOffset(3, 1), 12, UI.Colors.Sub)
	b.MouseButton1Click:Connect(function()
		if selectedSlot == i and slotRecord(i) then
			Net.event("EquipGear"):FireServer(i, nil)
		end
		selectedSlot = i
		refreshPanel()
	end)
	loadBtns[i] = b
end
local loadHint = UI.label(panel, "Hint", "", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 114), 14, UI.Colors.Sub)
loadHint.TextTruncate = Enum.TextTruncate.AtEnd

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "List"
scroll.Size = UDim2.new(1, 0, 1, -140)
scroll.Position = UDim2.fromOffset(0, 138)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 6
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.Parent = panel
UI.list(scroll, Enum.FillDirection.Vertical, 6)

type Stack = { id: string, tier: string, recs: { GearRecord } }

local function stacks(): { Stack }
	local byKey: { [string]: Stack } = {}
	local out: { Stack } = {}
	for _, rec in owned do
		local key = rec.id .. "|" .. rec.tier
		local existing = byKey[key]
		if existing then
			table.insert(existing.recs, rec)
		else
			local s: Stack = { id = rec.id, tier = rec.tier, recs = { rec } }
			byKey[key] = s
			table.insert(out, s)
		end
	end
	table.sort(out, function(a, b)
		local ta, tb = GearCatalog.tierIndex(a.tier), GearCatalog.tierIndex(b.tier)
		if ta ~= tb then
			return ta > tb
		end
		return a.id < b.id
	end)
	return out
end

local function equippedUid(recs: { GearRecord }): string?
	for _, rec in recs do
		for _, uid in loadout do
			if uid == rec.uid then
				return uid
			end
		end
	end
	return nil
end

local function unequippedUid(recs: { GearRecord }): string?
	for _, rec in recs do
		local used = false
		for _, uid in loadout do
			if uid == rec.uid then
				used = true
			end
		end
		if not used then
			return rec.uid
		end
	end
	return nil
end

refreshPanel = function()
	for i = 1, SLOTS do
		local b = loadBtns[i]
		local rec = slotRecord(i)
		local def = rec and GearCatalog.get(rec.id)
		if rec and def then
			b.Text = def.emoji
			b.BackgroundColor3 = tierColor(rec.tier)
		else
			b.Text = "+"
			b.BackgroundColor3 = UI.Colors.Panel
		end
		loadStrokes[i].Color = if i == selectedSlot then UI.Colors.Yellow else UI.Colors.PanelLight
		loadStrokes[i].Thickness = if i == selectedSlot then 3 else 2
	end
	local sel = slotRecord(selectedSlot)
	local selDef = sel and GearCatalog.get(sel.id)
	loadHint.Text = if sel and selDef
		then ("Slot %d: %s %s — %s. Tap the slot again to unequip."):format(
			selectedSlot,
			sel.tier,
			selDef.name,
			selDef.desc
		)
		else ("Slot %d is empty — pick gear below to EQUIP it here."):format(selectedSlot)

	for _, c in scroll:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local list = stacks()
	if #list == 0 then
		local empty = UI.frame(scroll, "Empty", UDim2.new(1, -8, 0, 60), nil, UI.Colors.PanelLight)
		UI.corner(empty, 10)
		UI.label(
			empty,
			"Text",
			"No gear yet. Feed Baby a snack (it burps loot), catch what flies out of smashed furniture, or beat a boss.",
			UDim2.fromScale(1, 1),
			nil,
			15,
			UI.Colors.Sub
		).TextWrapped =
			true
		return
	end
	for order, s in list do
		local def = GearCatalog.get(s.id)
		if not def then
			continue
		end
		local row = UI.frame(scroll, s.id .. s.tier, UDim2.new(1, -8, 0, 84), nil, UI.Colors.PanelLight)
		row.LayoutOrder = order
		UI.corner(row, 10)
		UI.stroke(row, tierColor(s.tier), 2)
		UI.padding(row, 6)
		local icon = UI.label(row, "Icon", def.emoji, UDim2.fromOffset(44, 72), nil, 30)
		icon.TextScaled = false
		local name = UI.label(
			row,
			"Name",
			("%s %s  x%d"):format(s.tier, def.name, #s.recs),
			UDim2.new(1, -240, 0, 22),
			UDim2.fromOffset(50, 0),
			17,
			tierColor(s.tier)
		)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local power = GearCatalog.power(def, s.tier)
		local sub = UI.label(
			row,
			"Desc",
			(
				if def.kind == "Active"
					then ("%d charges/night · %d%s · "):format(
						GearCatalog.charges(def, s.tier),
						power,
						def.powerLabel
					)
					else ("Passive · %d%s · "):format(power, def.powerLabel)
			) .. def.desc,
			UDim2.new(1, -240, 0, 50),
			UDim2.fromOffset(50, 22),
			12,
			UI.Colors.Sub
		)
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.TextWrapped = true
		sub.TextYAlignment = Enum.TextYAlignment.Top

		local eq = equippedUid(s.recs)
		local free = unequippedUid(s.recs)
		local equipBtn = UI.button(
			row,
			"Equip",
			if free then "EQUIP" elseif eq then "EQUIPPED" else "",
			UDim2.fromOffset(88, 36),
			UDim2.new(1, -184, 0.5, -18),
			if free then UI.Colors.Green else UI.Colors.Panel
		)
		equipBtn.TextSize = 15
		equipBtn.TextScaled = false
		equipBtn.MouseButton1Click:Connect(function()
			if free then
				Net.event("EquipGear"):FireServer(selectedSlot, free)
			end
		end)
		local canFuse = #s.recs >= GearCatalog.FuseCount and GearCatalog.tierIndex(s.tier) < #GearCatalog.Tiers
		local fuseBtn = UI.button(
			row,
			"Fuse",
			("FUSE %d→1"):format(GearCatalog.FuseCount),
			UDim2.fromOffset(88, 36),
			UDim2.new(1, -92, 0.5, -18),
			if canFuse then UI.Colors.Yellow else UI.Colors.Panel
		)
		fuseBtn.TextSize = 15
		fuseBtn.TextScaled = false
		fuseBtn.TextTransparency = if canFuse then 0 else 0.5
		fuseBtn.MouseButton1Click:Connect(function()
			if canFuse then
				Net.event("FuseGear"):FireServer(s.id, s.tier)
			end
		end)
	end
end

-- Replication -------------------------------------------------------------------------------
Net.event("GearChanged").OnClientEvent:Connect(function(gear, newLoadout)
	owned = gear or {}
	loadout = newLoadout or {}
	refreshBar()
	if panel.Visible then
		refreshPanel()
	end
end)

Net.event("GearState").OnClientEvent:Connect(function(newCharges)
	charges = newCharges or {}
	refreshBar()
end)

Net.event("RoundState").OnClientEvent:Connect(function(state: string)
	inRound = state == "Night" or state == "Panic"
	if state == "Briefing" or state == "Night" then
		panel.Visible = false
	end
end)

refreshBar()

return Gear

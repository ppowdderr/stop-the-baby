--!strict
-- Hotbar (tap/1-9 to use a toy or snack on Baby) + Toy Chest / Shop / Nursery panel.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local ToyCatalog = require(Shared:WaitForChild("ToyCatalog"))
local UI = require(script.Parent.UI)
local HUD = require(script.Parent.HUD)

local Inventory = {}

local player = Players.LocalPlayer
local screen = UI.screen("Inventory", 3)

type ItemDTO = { uid: string, id: string, mutation: string?, favorite: boolean? }
local items: { ItemDTO } = {}
local coins, stars, nurserySlots, canRebirth = 0, 0, 6, false
local nursery: { [string]: string } = {}

-- Currency display -------------------------------------------------------------------
local currency = UI.frame(screen, "Currency", UDim2.fromOffset(220, 40), UDim2.new(1, -232, 0, 12))
UI.corner(currency, 12)
UI.stroke(currency)
local coinLabel = UI.label(currency, "Coins", "🪙 0", UDim2.new(0.6, 0, 1, 0), nil, 20, UI.Colors.Yellow)
local starLabel = UI.label(currency, "Stars", "⭐ 0", UDim2.new(0.4, 0, 1, 0), UDim2.fromScale(0.6, 0), 20)

-- Hotbar ------------------------------------------------------------------------------
local HOTBAR = 8
local hotbar =
	UI.frame(screen, "Hotbar", UDim2.fromOffset(HOTBAR * 66, 70), UDim2.new(0.5, -HOTBAR * 33, 1, -90), nil, 1)
UI.list(hotbar, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center)
local slots: { TextButton } = {}

local function sortedItems(): { ItemDTO }
	local list = table.clone(items)
	table.sort(list, function(a, b)
		if (a.favorite or false) ~= (b.favorite or false) then
			return a.favorite == true
		end
		local da, db = ToyCatalog.get(a.id), ToyCatalog.get(b.id)
		local ra = if da then Rarity.index(da.rarity) else 0
		local rb = if db then Rarity.index(db.rarity) else 0
		if ra ~= rb then
			return ra > rb
		end
		return a.uid < b.uid
	end)
	return list
end

local function useSlot(i: number)
	local list = sortedItems()
	local rec = list[i]
	if rec then
		Net.event("UseItem"):FireServer(rec.uid)
		UI.pop(slots[i])
	end
end

for i = 1, HOTBAR do
	local b = UI.button(hotbar, "Slot" .. i, "", UDim2.fromOffset(60, 60), nil, UI.Colors.Panel)
	b.LayoutOrder = i
	b.TextSize = 28
	b.TextScaled = false
	local num = UI.label(b, "Num", tostring(i), UDim2.fromOffset(16, 16), UDim2.fromOffset(3, 1), 12, UI.Colors.Sub)
	num.Visible = not UserInputService.TouchEnabled
	b.MouseButton1Click:Connect(function()
		useSlot(i)
	end)
	slots[i] = b
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local n = input.KeyCode.Value - Enum.KeyCode.Zero.Value
	if n >= 1 and n <= HOTBAR then
		useSlot(n)
	end
end)

local function refreshHotbar()
	local list = sortedItems()
	for i, b in slots do
		local rec = list[i]
		local stroke = b:FindFirstChildOfClass("UIStroke")
		if rec then
			local def = ToyCatalog.get(rec.id)
			b.Text = if def then def.emoji else "?"
			b.BackgroundColor3 = if def then Rarity.Colors[def.rarity] else UI.Colors.Panel
			if stroke then
				stroke.Color = if rec.mutation then UI.Colors.Yellow else Color3.new(0, 0, 0)
				stroke.Thickness = if rec.mutation then 3 else 2
			end
		else
			b.Text = ""
			b.BackgroundColor3 = UI.Colors.Panel
			if stroke then
				stroke.Color = Color3.new(0, 0, 0)
			end
		end
	end
end

-- Toy Chest panel -----------------------------------------------------------------------
local openBtn =
	UI.button(screen, "Open", "🧸 TOYS", UDim2.fromOffset(120, 44), UDim2.new(1, -132, 0, 60), UI.Colors.Blue)
local shopBtn =
	UI.button(screen, "Shop", "🎁 SHOP", UDim2.fromOffset(120, 44), UDim2.new(1, -132, 0, 112), UI.Colors.Accent)

local panel = UI.frame(screen, "Panel", UDim2.fromOffset(560, 400), UDim2.new(0.5, -280, 0.5, -200))
panel.Visible = false
UI.corner(panel, 18)
UI.stroke(panel, UI.Colors.Blue, 3)
UI.padding(panel, 12)
local panelTitle = UI.label(panel, "Title", "TOY CHEST", UDim2.new(1, -60, 0, 36))
local closeBtn = UI.button(panel, "Close", "✕", UDim2.fromOffset(40, 40), UDim2.new(1, -40, 0, 0), UI.Colors.Red)
closeBtn.MouseButton1Click:Connect(function()
	panel.Visible = false
end)

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Grid"
scroll.Size = UDim2.new(1, 0, 1, -100)
scroll.Position = UDim2.fromOffset(0, 44)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 6
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.Parent = panel
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(96, 110)
grid.CellPadding = UDim2.fromOffset(8, 8)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = scroll

local footer = UI.frame(panel, "Footer", UDim2.new(1, 0, 0, 48), UDim2.new(0, 0, 1, -48), nil, 1)
UI.list(footer, Enum.FillDirection.Horizontal, 8)
local buyBtn = UI.button(
	footer,
	"Buy",
	("Toy Box 🪙%d"):format(Config.Economy.ToyBoxCost),
	UDim2.fromOffset(170, 44),
	nil,
	UI.Colors.Green
)
local buy10Btn = UI.button(
	footer,
	"Buy10",
	("x10 🪙%d"):format(Config.Economy.ToyBoxCost * 10),
	UDim2.fromOffset(120, 44),
	nil,
	UI.Colors.Green
)
local codeBox = Instance.new("TextBox")
codeBox.PlaceholderText = "Enter code..."
codeBox.Text = ""
codeBox.Size = UDim2.fromOffset(130, 44)
codeBox.Font = UI.Font
codeBox.TextSize = 18
codeBox.TextColor3 = UI.Colors.Text
codeBox.BackgroundColor3 = UI.Colors.PanelLight
codeBox.ClearTextOnFocus = false
codeBox.Parent = footer
UI.corner(codeBox, 10)
local rebirthBtn = UI.button(footer, "Rebirth", "REBIRTH", UDim2.fromOffset(100, 44), nil, UI.Colors.Yellow)
rebirthBtn.Visible = false

buyBtn.MouseButton1Click:Connect(function()
	Net.event("BuyToyBox"):FireServer(1)
end)
buy10Btn.MouseButton1Click:Connect(function()
	Net.event("BuyToyBox"):FireServer(10)
end)
codeBox.FocusLost:Connect(function(enter)
	if enter and codeBox.Text ~= "" then
		Net.event("RedeemCode"):FireServer(codeBox.Text)
		codeBox.Text = ""
	end
end)

local selectedUid: string? = nil
local detail = UI.frame(panel, "Detail", UDim2.fromOffset(200, 130), UDim2.new(1, -200, 0, 44), UI.Colors.PanelLight)
detail.Visible = false
UI.corner(detail, 12)
UI.padding(detail, 8)
UI.list(detail, nil, 4)
local detailName = UI.label(detail, "Name", "", UDim2.new(1, 0, 0, 40), nil, 16)
detailName.TextWrapped = true
local favBtn = UI.button(detail, "Fav", "⭐ Favorite", UDim2.new(1, 0, 0, 30), nil, UI.Colors.Blue)
local sellBtn = UI.button(detail, "Sell", "Sell", UDim2.new(1, 0, 0, 30), nil, UI.Colors.Red)
favBtn.MouseButton1Click:Connect(function()
	if selectedUid then
		Net.event("ToggleFavorite"):FireServer(selectedUid)
	end
end)
sellBtn.MouseButton1Click:Connect(function()
	if selectedUid then
		Net.event("SellItem"):FireServer(selectedUid)
		selectedUid = nil
		detail.Visible = false
	end
end)

local function refreshGrid()
	for _, c in scroll:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for i, rec in sortedItems() do
		local def = ToyCatalog.get(rec.id)
		local cell = UI.button(
			scroll,
			rec.uid,
			"",
			UDim2.fromOffset(96, 110),
			nil,
			if def then Rarity.Colors[def.rarity] else UI.Colors.Panel
		)
		cell.LayoutOrder = i
		cell.TextScaled = false
		cell.Text = ""
		UI.label(cell, "Emoji", if def then def.emoji else "?", UDim2.new(1, 0, 0, 44), UDim2.fromOffset(0, 6), 32)
		local nm = UI.label(
			cell,
			"Name",
			ToyCatalog.displayName(rec.id, rec.mutation),
			UDim2.new(1, -6, 0, 40),
			UDim2.fromOffset(3, 52),
			13
		)
		nm.TextWrapped = true
		if rec.favorite then
			UI.label(cell, "Fav", "⭐", UDim2.fromOffset(20, 20), UDim2.fromOffset(2, 2), 16)
		end
		if def then
			UI.label(cell, "Rarity", def.rarity, UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 1, -16), 11, UI.Colors.Text)
		end
		cell.MouseButton1Click:Connect(function()
			selectedUid = rec.uid
			detail.Visible = true
			local soothe = if def then Rarity.Soothe[def.rarity] else nil
			detailName.Text = ToyCatalog.displayName(rec.id, rec.mutation)
				.. (if def then ("\n%s • soothes %d"):format(def.rarity, if soothe then soothe.stages else 0) else "")
			favBtn.Text = if rec.favorite then "★ Unfavorite" else "☆ Favorite"
			local value = if def then Rarity.SellValue[def.rarity] else 0
			if rec.mutation then
				local m = ToyCatalog.getMutation(rec.mutation)
				if m then
					value = math.floor(value * m.valueMult)
				end
			end
			sellBtn.Text = ("Sell 🪙%d"):format(value)
		end)
	end
end

openBtn.MouseButton1Click:Connect(function()
	panel.Visible = not panel.Visible
	panelTitle.Text = ("TOY CHEST (%d)"):format(#items)
	if panel.Visible then
		refreshGrid()
		UI.pop(panel)
	end
end)

-- Shop panel (Robux) -------------------------------------------------------------------
local shop = UI.frame(screen, "ShopPanel", UDim2.fromOffset(420, 330), UDim2.new(0.5, -210, 0.5, -165))
shop.Visible = false
UI.corner(shop, 18)
UI.stroke(shop, UI.Colors.Accent, 3)
UI.padding(shop, 12)
UI.label(shop, "Title", "🎁 SHOP", UDim2.new(1, -60, 0, 36))
local shopClose = UI.button(shop, "Close", "✕", UDim2.fromOffset(40, 40), UDim2.new(1, -40, 0, 0), UI.Colors.Red)
shopClose.MouseButton1Click:Connect(function()
	shop.Visible = false
end)
local shopList = UI.frame(shop, "List", UDim2.new(1, 0, 1, -50), UDim2.fromOffset(0, 46), nil, 1)
UI.list(shopList, nil, 8)
UI.label(
	shopList,
	"Note",
	"We sell speed & style — never the ability to stop the baby crying.",
	UDim2.new(1, 0, 0, 30),
	nil,
	14,
	UI.Colors.Sub
).TextWrapped =
	true

local shopEntries = {
	{ key = "StarterPack", text = "Starter Pack: 1000 coins + 3 Toy Boxes", kind = "product" },
	{ key = "X2Coins", text = "x2 Diaper Coins (forever)", kind = "pass" },
	{ key = "LuckyNanny", text = "Lucky Nanny: reroll Commons", kind = "pass" },
	{ key = "ToyBox10", text = "10 Toy Boxes", kind = "product" },
	{ key = "NurseryShelf", text = "+3 Nursery shelf slots", kind = "product" },
}
for i, e in shopEntries do
	local def = (Config.Products :: any)[e.key]
	local b = UI.button(
		shopList,
		e.key,
		("%s — R$%d"):format(e.text, def.price),
		UDim2.new(1, 0, 0, 44),
		nil,
		UI.Colors.PanelLight
	)
	b.LayoutOrder = i
	b.TextSize = 16
	b.TextScaled = false
	b.MouseButton1Click:Connect(function()
		if e.kind == "product" and def.productId ~= 0 then
			MarketplaceService:PromptProductPurchase(player, def.productId)
		elseif e.kind == "pass" and def.gamepassId ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, def.gamepassId)
		else
			HUD.toast("Product not configured yet (set ids in Config.Products).", "error")
		end
	end)
end
shopBtn.MouseButton1Click:Connect(function()
	shop.Visible = not shop.Visible
	if shop.Visible then
		UI.pop(shop)
	end
end)

rebirthBtn.MouseButton1Click:Connect(function()
	Net.event("Rebirth"):FireServer()
end)

-- Replication --------------------------------------------------------------------------
Net.event("InventoryChanged").OnClientEvent:Connect(function(data)
	items = data.inventory or {}
	coins = data.coins or 0
	stars = data.stars or 0
	nurserySlots = data.nurserySlots or 6
	nursery = data.nursery or {}
	canRebirth = data.canRebirth == true
	coinLabel.Text = ("🪙 %d"):format(coins)
	starLabel.Text = ("⭐ %d"):format(stars)
	rebirthBtn.Visible = canRebirth
	refreshHotbar()
	if panel.Visible then
		panelTitle.Text = ("TOY CHEST (%d)"):format(#items)
		refreshGrid()
	end
end)

function Inventory.nurserySlots(): number
	return nurserySlots
end
function Inventory.nursery(): { [string]: string }
	return nursery
end

return Inventory

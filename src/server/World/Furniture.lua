--!strict
-- Chunky "toy-box" furniture built from parts. Every builder returns ONE root BasePart that carries the
-- game contract (Station / Prop attributes live on it; ChoreService, Interaction, BabyAI and
-- RoundService only ever look at that root). Visual detail hangs off the root as welded children, so a
-- knocked prop tumbles as one assembly and `resetProps` snaps everything home by moving the root.
local Palette = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Palette"))

local Furniture = {}

export type Opts = {
	material: Enum.Material?,
	shape: Enum.PartType?,
	collide: boolean?,
	transparency: number?,
	shadow: boolean?,
	reflectance: number?,
}

local function style(p: BasePart, color: Color3, opts: Opts?)
	local o: Opts = opts or {}
	p.Color = color
	p.Material = o.material or Enum.Material.SmoothPlastic
	p.Transparency = o.transparency or 0
	p.Reflectance = o.reflectance or 0
	p.CastShadow = o.shadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
end

-- Anchored, free-standing part (walls, floors, static decor).
function Furniture.block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, opts: Opts?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = (opts and opts.shape) or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	style(p, color, opts)
	p.Anchored = true
	p.CanCollide = if opts and opts.collide ~= nil then opts.collide :: boolean else true
	p.Parent = parent
	return p
end

function Furniture.wedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	opts: Opts?
): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	style(p, color, opts)
	p.Anchored = true
	p.CanCollide = if opts and opts.collide ~= nil then opts.collide :: boolean else true
	p.Parent = parent
	return p
end

-- Detail part welded to a root. Never anchored: an anchored root pins it, an unanchored (knocked)
-- root drags it along. Massless + no collision so the root's box is the only thing physics cares about.
function Furniture.attach(root: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, opts: Opts?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = (opts and opts.shape) or Enum.PartType.Block
	p.Size = size
	p.CFrame = root.CFrame * offset
	style(p, color, opts)
	p.Anchored = false
	p.Massless = true
	p.CanCollide = if opts and opts.collide ~= nil then opts.collide :: boolean else false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = root
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
	return p
end

function Furniture.attachWedge(root: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, opts: Opts?)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = root.CFrame * offset
	style(p, color, opts)
	p.Anchored = false
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = root
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
	return p
end

-- Invisible collision/contract box that the detail parts hang off.
function Furniture.root(parent: Instance, name: string, size: Vector3, cf: CFrame, collide: boolean?): Part
	local p = Furniture.block(parent, name, size, cf, Color3.new(1, 1, 1), { transparency = 1, shadow = false })
	p.CanCollide = collide ~= false
	return p
end

local function light(parent: BasePart, color: Color3, brightness: number, range: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = parent
	return l
end

local function ball(root: BasePart, name: string, d: number, offset: CFrame, color: Color3, opts: Opts?): Part
	local o: Opts = if opts then table.clone(opts) else {}
	o.shape = Enum.PartType.Ball
	return Furniture.attach(root, name, Vector3.new(d, d, d), offset, color, o)
end

local function cyl(root: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, opts: Opts?): Part
	local o: Opts = if opts then table.clone(opts) else {}
	o.shape = Enum.PartType.Cylinder
	return Furniture.attach(root, name, size, offset, color, o)
end

-- Rotations that make a Cylinder stand upright (its axis is X by default) or lie along Z.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0)

local WOOD: Opts = { material = Enum.Material.Wood }
local FABRIC: Opts = { material = Enum.Material.Fabric }
local METAL: Opts = { material = Enum.Material.Metal }
local NEON: Opts = { material = Enum.Material.Neon, shadow = false }

--------------------------------------------------------------------------------------------------
-- Living room props (knockable)
--------------------------------------------------------------------------------------------------

function Furniture.couch(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "Couch", Vector3.new(16, 4, 6), cf)
	Furniture.attach(r, "Seat", Vector3.new(16, 2, 6), CFrame.new(0, -1, 0), Palette.CouchBlue, FABRIC)
	Furniture.attach(r, "Back", Vector3.new(16, 3, 1.6), CFrame.new(0, 0.5, 2.2), Palette.CouchBlueDark, FABRIC)
	for _, sx in { -1, 1 } do
		Furniture.attach(r, "Arm", Vector3.new(1.8, 3, 6), CFrame.new(sx * 7.1, 0, 0), Palette.CouchBlueDark, FABRIC)
		ball(r, "ArmCap", 1.8, CFrame.new(sx * 7.1, 1.5, -1.2), Palette.CouchBlueDark, FABRIC)
	end
	for i = -1, 1 do
		Furniture.attach(
			r,
			"Cushion",
			Vector3.new(3.6, 0.9, 3.8),
			CFrame.new(i * 4.1, 0.4, -0.6),
			Palette.Cushion,
			FABRIC
		)
	end
	for _, sx in { -1, 1 } do
		Furniture.attach(
			r,
			"Pillow",
			Vector3.new(2.4, 2.2, 0.8),
			CFrame.new(sx * 4.6, 1.6, 1.2) * CFrame.Angles(0, 0, math.rad(sx * 12)),
			Palette.AccentClean,
			FABRIC
		)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			cyl(
				r,
				"Foot",
				Vector3.new(0.5, 0.7, 0.7),
				CFrame.new(sx * 7, -2.3, sz * 2.4) * UPRIGHT,
				Palette.WoodDark,
				WOOD
			)
		end
	end
	return r
end

function Furniture.armchair(parent: Instance, name: string, cf: CFrame): Part
	local r = Furniture.root(parent, name, Vector3.new(6, 5, 6), cf)
	Furniture.attach(r, "Seat", Vector3.new(6, 2, 6), CFrame.new(0, -1.5, 0), Palette.AccentClean, FABRIC)
	Furniture.attach(r, "Back", Vector3.new(6, 3.4, 1.4), CFrame.new(0, 0.6, 2.3), Palette.AccentClean, FABRIC)
	for _, sx in { -1, 1 } do
		Furniture.attach(r, "Arm", Vector3.new(1.2, 2.6, 5), CFrame.new(sx * 2.4, -0.4, -0.3), Palette.Cushion, FABRIC)
	end
	Furniture.attach(r, "Cushion", Vector3.new(3.4, 0.7, 3.6), CFrame.new(0, -0.2, -0.7), Palette.Cushion, FABRIC)
	return r
end

function Furniture.coffeeTable(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "CoffeeTable", Vector3.new(10, 2.6, 5), cf)
	Furniture.attach(r, "Top", Vector3.new(10, 0.6, 5), CFrame.new(0, 1, 0), Palette.WoodLight, WOOD)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			cyl(
				r,
				"Leg",
				Vector3.new(2, 0.8, 0.8),
				CFrame.new(sx * 4.2, -0.3, sz * 1.8) * UPRIGHT,
				Palette.WoodMid,
				WOOD
			)
		end
	end
	-- a sippy cup and a picture book
	cyl(r, "Cup", Vector3.new(1, 0.9, 0.9), CFrame.new(2.5, 1.8, 0.8) * UPRIGHT, Palette.AccentToys)
	Furniture.attach(
		r,
		"Book",
		Vector3.new(2.2, 0.3, 1.8),
		CFrame.new(-2.2, 1.45, -0.3) * CFrame.Angles(0, math.rad(15), 0),
		Palette.AccentSleep
	)
	return r
end

function Furniture.diningTable(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "Table", Vector3.new(14, 5, 8), cf)
	Furniture.attach(r, "Top", Vector3.new(14, 0.7, 8), CFrame.new(0, 2.15, 0), Palette.WoodLight, WOOD)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Furniture.attach(
				r,
				"Leg",
				Vector3.new(0.9, 4.3, 0.9),
				CFrame.new(sx * 6.2, -0.35, sz * 3.2),
				Palette.WoodMid,
				WOOD
			)
		end
	end
	-- bowl of fruit
	cyl(r, "Bowl", Vector3.new(0.6, 3, 3), CFrame.new(0, 2.8, 0) * UPRIGHT, Palette.Ceramic)
	ball(r, "Apple", 0.9, CFrame.new(-0.5, 3.4, 0.3), Color3.fromRGB(230, 60, 70))
	ball(r, "Orange", 0.9, CFrame.new(0.6, 3.4, -0.3), Color3.fromRGB(255, 150, 40))
	ball(r, "Lime", 0.8, CFrame.new(0.1, 3.35, 0.8), Palette.Leaf)
	return r
end

function Furniture.chair(parent: Instance, name: string, cf: CFrame): Part
	local r = Furniture.root(parent, name, Vector3.new(4, 5, 4), cf)
	Furniture.attach(r, "Seat", Vector3.new(4, 0.6, 4), CFrame.new(0, -0.7, 0), Palette.WoodLight, WOOD)
	Furniture.attach(r, "Back", Vector3.new(4, 2.8, 0.5), CFrame.new(0, 1.1, 1.75), Palette.WoodLight, WOOD)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Furniture.attach(
				r,
				"Leg",
				Vector3.new(0.5, 1.8, 0.5),
				CFrame.new(sx * 1.6, -1.6, sz * 1.6),
				Palette.WoodMid,
				WOOD
			)
		end
	end
	Furniture.attach(r, "Pad", Vector3.new(3.2, 0.4, 3.2), CFrame.new(0, -0.2, -0.1), Palette.AccentKitchen, FABRIC)
	return r
end

function Furniture.stool(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "Stool", Vector3.new(3, 3, 3), cf)
	cyl(r, "Seat", Vector3.new(0.6, 3, 3), CFrame.new(0, 1.2, 0) * UPRIGHT, Color3.fromRGB(230, 80, 90))
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3
		Furniture.attach(
			r,
			"Leg",
			Vector3.new(0.45, 2.4, 0.45),
			CFrame.new(math.cos(a) * 1, -0.3, math.sin(a) * 1),
			Palette.WoodMid,
			WOOD
		)
	end
	return r
end

function Furniture.tv(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "TV", Vector3.new(12, 7, 1), cf)
	Furniture.attach(r, "Bezel", Vector3.new(12, 7, 0.8), CFrame.new(), Palette.Screen)
	local screen =
		Furniture.attach(r, "Screen", Vector3.new(11, 6, 0.3), CFrame.new(0, 0.15, -0.35), Palette.ScreenGlow, NEON)
	light(screen, Palette.ScreenGlow, 0.5, 18)
	-- cartoon on the screen
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Parent = screen
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Text = "📺 BABY CHANNEL"
	t.Parent = gui
	Furniture.attach(r, "Stand", Vector3.new(4, 0.5, 2.2), CFrame.new(0, -3.7, 0.4), Palette.MetalDark)
	return r
end

function Furniture.bookshelf(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "Bookshelf", Vector3.new(10, 12, 3), cf)
	-- hollow carcass: two sides, top, bottom, back
	for _, sx in { -1, 1 } do
		Furniture.attach(r, "Side", Vector3.new(0.3, 12, 3), CFrame.new(sx * 4.85, 0, 0), Palette.WoodMid, WOOD)
	end
	Furniture.attach(r, "Top", Vector3.new(10, 0.3, 3), CFrame.new(0, 5.85, 0), Palette.WoodMid, WOOD)
	Furniture.attach(r, "Bottom", Vector3.new(10, 0.3, 3), CFrame.new(0, -5.85, 0), Palette.WoodMid, WOOD)
	Furniture.attach(r, "Back", Vector3.new(10, 12, 0.2), CFrame.new(0, 0, 1.4), Palette.WoodMid, WOOD)
	local rng = Random.new(7)
	local colors = {
		Palette.AccentToys,
		Palette.AccentClean,
		Palette.AccentKitchen,
		Palette.AccentSleep,
		Palette.AccentUtility,
		Palette.AccentYard,
	}
	for row = 0, 3 do
		local y = -4.2 + row * 2.8
		Furniture.attach(r, "Shelf", Vector3.new(9.4, 0.3, 2.6), CFrame.new(0, y - 1.35, -0.2), Palette.WoodLight, WOOD)
		Furniture.attach(r, "Backboard", Vector3.new(9.4, 2.6, 0.2), CFrame.new(0, y, 1.25), Palette.WallCream)
		local x = -4.3
		while x < 3.6 do
			local w = rng:NextNumber(0.5, 1.1)
			local h = rng:NextNumber(1.6, 2.3)
			Furniture.attach(
				r,
				"Book",
				Vector3.new(w, h, 1.8),
				CFrame.new(x + w / 2, y - 1.2 + h / 2, -0.3),
				colors[rng:NextInteger(1, #colors)]
			)
			x += w + 0.08
			if rng:NextNumber() < 0.2 then
				x += 0.9 -- gap for a toy
			end
		end
	end
	ball(r, "Globe", 1.6, CFrame.new(2.6, 6.9, -0.2), Palette.AccentToys)
	Furniture.attach(r, "Bear", Vector3.new(1.2, 1.4, 1), CFrame.new(-3, 6.8, -0.2), Palette.WoodLight)
	return r
end

function Furniture.floorLamp(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "Lamp", Vector3.new(2, 8, 2), cf)
	cyl(r, "Base", Vector3.new(0.4, 2.4, 2.4), CFrame.new(0, -3.8, 0) * UPRIGHT, Palette.MetalDark, METAL)
	cyl(r, "Pole", Vector3.new(6.5, 0.35, 0.35), CFrame.new(0, -0.4, 0) * UPRIGHT, Palette.Metal, METAL)
	local shade = cyl(
		r,
		"Shade",
		Vector3.new(2.6, 3.6, 3.6),
		CFrame.new(0, 2.6, 0) * UPRIGHT,
		Palette.LampShade,
		{ material = Enum.Material.Fabric, transparency = 0.1 }
	)
	local bulb = ball(r, "Bulb", 1, CFrame.new(0, 2.4, 0), Palette.Bulb, NEON)
	light(bulb, Color3.fromRGB(255, 226, 180), 0.9, 30)
	shade.CastShadow = false
	return r
end

function Furniture.vase(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "Vase", Vector3.new(2, 3, 2), cf)
	cyl(
		r,
		"Body",
		Vector3.new(2.6, 1.8, 1.8),
		CFrame.new(0, -0.2, 0) * UPRIGHT,
		Palette.AccentToys,
		{ reflectance = 0.15 }
	)
	cyl(r, "Neck", Vector3.new(0.8, 1, 1), CFrame.new(0, 1.5, 0) * UPRIGHT, Palette.AccentToys, { reflectance = 0.15 })
	for i, c in { Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 220, 90), Color3.fromRGB(180, 140, 255) } do
		local a = i * 2.1
		cyl(
			r,
			"Stem",
			Vector3.new(1.8, 0.14, 0.14),
			CFrame.new(math.cos(a) * 0.25, 2.6, math.sin(a) * 0.25) * UPRIGHT,
			Palette.LeafDark
		)
		ball(r, "Flower", 0.9, CFrame.new(math.cos(a) * 0.5, 3.5, math.sin(a) * 0.5), c)
	end
	return r
end

function Furniture.plant(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "Plant", Vector3.new(3, 6, 3), cf)
	cyl(r, "Pot", Vector3.new(2.4, 2.8, 2.8), CFrame.new(0, -1.8, 0) * UPRIGHT, Palette.Terracotta)
	cyl(r, "Rim", Vector3.new(0.5, 3.2, 3.2), CFrame.new(0, -0.75, 0) * UPRIGHT, Palette.Terracotta)
	cyl(r, "Soil", Vector3.new(0.2, 2.6, 2.6), CFrame.new(0, -0.55, 0) * UPRIGHT, Color3.fromRGB(90, 62, 44))
	cyl(r, "Trunk", Vector3.new(2.2, 0.5, 0.5), CFrame.new(0, 0.6, 0) * UPRIGHT, Palette.Bark)
	ball(r, "Leaves", 3, CFrame.new(0, 2, 0), Palette.Leaf)
	ball(r, "Leaves", 2.2, CFrame.new(1, 1.4, 0.6), Palette.LeafDark)
	ball(r, "Leaves", 2, CFrame.new(-0.9, 1.6, -0.6), Palette.LeafDark)
	ball(r, "Leaves", 1.6, CFrame.new(0.2, 2.9, -0.4), Palette.Leaf)
	return r
end

function Furniture.toyBlocks(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "ToyBlocks", Vector3.new(3, 3.6, 3), cf)
	Furniture.attach(
		r,
		"Block",
		Vector3.new(1.6, 1.6, 1.6),
		CFrame.new(-0.6, -1, 0.3) * CFrame.Angles(0, math.rad(10), 0),
		Palette.AccentClean
	)
	Furniture.attach(
		r,
		"Block",
		Vector3.new(1.6, 1.6, 1.6),
		CFrame.new(1, -1, -0.5) * CFrame.Angles(0, math.rad(-20), 0),
		Palette.AccentToys
	)
	Furniture.attach(
		r,
		"Block",
		Vector3.new(1.4, 1.4, 1.4),
		CFrame.new(0.2, 0.5, -0.1) * CFrame.Angles(0, math.rad(35), 0),
		Palette.Cushion
	)
	ball(r, "Ball", 1.2, CFrame.new(-0.9, 0.5, -1), Palette.AccentKitchen)
	return r
end

--------------------------------------------------------------------------------------------------
-- Chore stations (anchored). Root sizes match the original greybox so interaction ranges are unchanged.
--------------------------------------------------------------------------------------------------

function Furniture.crib(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "Crib", Vector3.new(14, 6, 10), cf)
	Furniture.attach(r, "Mattress", Vector3.new(13, 1, 9), CFrame.new(0, -1.9, 0), Palette.Ceramic, FABRIC)
	Furniture.attach(r, "Sheet", Vector3.new(13.1, 0.3, 5), CFrame.new(0, -1.35, 1.5), Palette.AccentSleep, FABRIC)
	Furniture.attach(
		r,
		"Pillow",
		Vector3.new(4.5, 0.9, 2.6),
		CFrame.new(0, -1.05, -2.8) * CFrame.Angles(0, math.rad(6), 0),
		Palette.Ceramic,
		FABRIC
	)
	Furniture.attach(r, "Base", Vector3.new(13.4, 0.6, 9.4), CFrame.new(0, -2.6, 0), Palette.WoodLight, WOOD)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Furniture.attach(
				r,
				"Post",
				Vector3.new(0.9, 6, 0.9),
				CFrame.new(sx * 6.6, 0, sz * 4.6),
				Palette.WoodLight,
				WOOD
			)
			ball(r, "Knob", 1.3, CFrame.new(sx * 6.6, 3.4, sz * 4.6), Palette.AccentSleep)
		end
	end
	-- side rails: bars along X on the long sides, along Z on the short sides
	for _, sz in { -1, 1 } do
		Furniture.attach(r, "Rail", Vector3.new(13, 0.5, 0.5), CFrame.new(0, 2.4, sz * 4.6), Palette.WoodLight, WOOD)
		for x = -5.5, 5.5, 1.1 do
			Furniture.attach(
				r,
				"Bar",
				Vector3.new(0.3, 4.4, 0.3),
				CFrame.new(x, 0.1, sz * 4.6),
				Palette.Ceramic,
				{ shadow = false }
			)
		end
	end
	for _, sx in { -1, 1 } do
		Furniture.attach(r, "Rail", Vector3.new(0.5, 0.5, 9), CFrame.new(sx * 6.6, 2.4, 0), Palette.WoodLight, WOOD)
		for z = -3.5, 3.5, 1.1 do
			Furniture.attach(
				r,
				"Bar",
				Vector3.new(0.3, 4.4, 0.3),
				CFrame.new(sx * 6.6, 0.1, z),
				Palette.Ceramic,
				{ shadow = false }
			)
		end
	end
	-- mobile: arm + hanging star/moon/cloud
	cyl(
		r,
		"MobileArm",
		Vector3.new(6, 0.25, 0.25),
		CFrame.new(3.6, 6.2, -4.6) * CFrame.Angles(0, 0, math.rad(60)),
		Palette.Metal,
		METAL
	)
	cyl(r, "MobileBar", Vector3.new(5, 0.2, 0.2), CFrame.new(0.9, 7.6, -4.6), Palette.Metal, METAL)
	local star = ball(r, "Star", 1, CFrame.new(-1.2, 6.4, -4.6), Palette.Cushion, NEON)
	light(star, Palette.Cushion, 0.4, 10)
	ball(r, "Moon", 0.9, CFrame.new(0.9, 6.2, -4.6), Palette.AccentSleep, NEON)
	ball(r, "Cloud", 1.1, CFrame.new(3, 6.5, -4.6), Palette.Ceramic)
	return r
end

function Furniture.toyBin(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "ToyBin", Vector3.new(6, 4, 6), cf)
	Furniture.attach(r, "Box", Vector3.new(6, 3.4, 6), CFrame.new(0, -0.3, 0), Palette.AccentToys)
	Furniture.attach(r, "Lip", Vector3.new(6.4, 0.5, 6.4), CFrame.new(0, 1.55, 0), Palette.Ceramic)
	Furniture.attach(r, "Stripe", Vector3.new(6.05, 0.7, 6.05), CFrame.new(0, -1.2, 0), Palette.Ceramic)
	ball(r, "Ball", 1.6, CFrame.new(-1.4, 2.2, -0.8), Color3.fromRGB(240, 70, 80))
	ball(r, "Ball", 1.2, CFrame.new(1.2, 2, 1.2), Palette.AccentKitchen)
	Furniture.attach(
		r,
		"Block",
		Vector3.new(1.5, 1.5, 1.5),
		CFrame.new(1.4, 2.2, -1.2) * CFrame.Angles(0, math.rad(30), math.rad(15)),
		Palette.Cushion
	)
	Furniture.attach(
		r,
		"Bear",
		Vector3.new(1.4, 1.8, 1.2),
		CFrame.new(-0.6, 2.4, 1.6) * CFrame.Angles(math.rad(-20), 0, 0),
		Palette.WoodLight
	)
	return r
end

function Furniture.rug(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "Rug", Vector3.new(24, 0.3, 16), cf, false)
	Furniture.attach(
		r,
		"Border",
		Vector3.new(24, 0.3, 16),
		CFrame.new(),
		Palette.AccentClean,
		{ material = Enum.Material.Fabric, collide = false }
	)
	Furniture.attach(
		r,
		"Field",
		Vector3.new(21, 0.32, 13),
		CFrame.new(0, 0.02, 0),
		Color3.fromRGB(255, 220, 232),
		FABRIC
	)
	for i, c in { Palette.AccentToys, Palette.Cushion, Palette.AccentKitchen } do
		cyl(
			r,
			"Dot",
			Vector3.new(0.34, 3.2, 3.2),
			CFrame.new((i - 2) * 6, 0.03, (i % 2) * 3 - 1.5) * UPRIGHT,
			c,
			FABRIC
		)
	end
	for _, sx in { -1, 1 } do
		Furniture.attach(
			r,
			"Fringe",
			Vector3.new(0.6, 0.2, 15.6),
			CFrame.new(sx * 12.3, -0.05, 0),
			Palette.Ceramic,
			FABRIC
		)
	end
	return r
end

function Furniture.laundry(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "Laundry", Vector3.new(6, 4, 6), cf)
	cyl(
		r,
		"Basket",
		Vector3.new(3.6, 5.6, 5.6),
		CFrame.new(0, -0.2, 0) * UPRIGHT,
		Palette.WoodLight,
		{ material = Enum.Material.Fabric }
	)
	cyl(r, "Rim", Vector3.new(0.4, 6, 6), CFrame.new(0, 1.6, 0) * UPRIGHT, Palette.WoodMid, WOOD)
	ball(r, "Sock", 2.2, CFrame.new(0.6, 2.2, 0.4), Palette.Ceramic, FABRIC)
	ball(r, "Onesie", 2, CFrame.new(-1.2, 2, -0.6), Palette.Baby, FABRIC)
	ball(r, "Bib", 1.5, CFrame.new(0.3, 2.9, -1.3), Palette.AccentClean, FABRIC)
	Furniture.attach(
		r,
		"Sleeve",
		Vector3.new(0.7, 2.4, 0.7),
		CFrame.new(2.4, 1.6, 1.2) * CFrame.Angles(0, 0, math.rad(-40)),
		Palette.AccentToys,
		FABRIC
	)
	return r
end

-- Window set into a wall opening. `depth` is the wall thickness; the root is the glass pane.
function Furniture.window(parent: Instance, name: string, size: Vector3, cf: CFrame, curtains: boolean): Part
	local r = Furniture.block(
		parent,
		name,
		Vector3.new(size.X, size.Y, 0.3),
		cf,
		Palette.Glass,
		{ material = Enum.Material.Glass, transparency = 0.45, reflectance = 0.1, shadow = false }
	)
	local fw = 0.8
	for _, sx in { -1, 1 } do
		Furniture.attach(
			r,
			"Frame",
			Vector3.new(fw, size.Y + fw * 2, size.Z + 0.4),
			CFrame.new(sx * (size.X / 2 + fw / 2), 0, 0),
			Palette.Trim
		)
	end
	for _, sy in { -1, 1 } do
		Furniture.attach(
			r,
			"Frame",
			Vector3.new(size.X, fw, size.Z + 0.4),
			CFrame.new(0, sy * (size.Y / 2 + fw / 2), 0),
			Palette.Trim
		)
	end
	Furniture.attach(r, "Mullion", Vector3.new(0.35, size.Y, 0.5), CFrame.new(), Palette.Trim, { shadow = false })
	Furniture.attach(
		r,
		"Mullion",
		Vector3.new(size.X, 0.35, 0.5),
		CFrame.new(0, size.Y * 0.1, 0),
		Palette.Trim,
		{ shadow = false }
	)
	Furniture.attach(
		r,
		"Sill",
		Vector3.new(size.X + 2.4, 0.5, 1.6),
		CFrame.new(0, -size.Y / 2 - fw - 0.25, -1.2),
		Palette.Trim
	)
	if curtains then
		for _, sx in { -1, 1 } do
			Furniture.attach(
				r,
				"Curtain",
				Vector3.new(size.X * 0.22, size.Y + 2.5, 0.5),
				CFrame.new(sx * (size.X / 2 - size.X * 0.06), 0.4, -1.8),
				Palette.Curtain,
				FABRIC
			)
		end
		cyl(r, "Rod", Vector3.new(size.X + 3, 0.3, 0.3), CFrame.new(0, size.Y / 2 + 1.6, -1.9), Palette.WoodDark, WOOD)
	end
	return r
end

function Furniture.sinkCounter(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "Sink", Vector3.new(8, 5, 5), cf)
	Furniture.attach(r, "Cabinet", Vector3.new(8, 4.2, 5), CFrame.new(0, -0.4, 0), Palette.AccentKitchen)
	Furniture.attach(
		r,
		"Counter",
		Vector3.new(8.4, 0.5, 5.4),
		CFrame.new(0, 1.95, 0),
		Palette.Ceramic,
		{ material = Enum.Material.Marble }
	)
	Furniture.attach(r, "Basin", Vector3.new(4.6, 0.6, 3), CFrame.new(0, 1.95, -0.2), Palette.Metal, METAL)
	for _, sx in { -1, 1 } do
		Furniture.attach(
			r,
			"Door",
			Vector3.new(3.4, 3.2, 0.2),
			CFrame.new(sx * 1.9, -0.6, -2.55),
			Color3.fromRGB(150, 236, 180)
		)
		cyl(
			r,
			"Handle",
			Vector3.new(1.2, 0.25, 0.25),
			CFrame.new(sx * 0.6, -0.4, -2.75) * UPRIGHT,
			Palette.Metal,
			METAL
		)
	end
	cyl(r, "Tap", Vector3.new(2.4, 0.4, 0.4), CFrame.new(0, 3.2, 1.2) * UPRIGHT, Palette.Metal, METAL)
	cyl(r, "Spout", Vector3.new(1.8, 0.4, 0.4), CFrame.new(0, 4.3, 0.4) * ALONG_Z, Palette.Metal, METAL)
	ball(r, "Bubble", 0.9, CFrame.new(-1.4, 2.6, -0.2), Palette.Ceramic, { transparency = 0.3, shadow = false })
	ball(r, "Bubble", 0.6, CFrame.new(1.1, 2.5, 0.3), Palette.Ceramic, { transparency = 0.3, shadow = false })
	Furniture.attach(
		r,
		"Plate",
		Vector3.new(1.6, 0.15, 1.6),
		CFrame.new(2.6, 2.3, -0.4) * CFrame.Angles(0, 0, math.rad(75)),
		Palette.Ceramic
	)
	return r
end

function Furniture.microwave(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "Microwave", Vector3.new(5, 3, 4), cf)
	Furniture.attach(r, "Body", Vector3.new(5, 3, 4), CFrame.new(), Palette.Metal, METAL)
	local door = Furniture.attach(r, "Door", Vector3.new(3.2, 2.2, 0.2), CFrame.new(-0.6, 0, -2.05), Palette.Screen)
	light(door, Color3.fromRGB(255, 200, 120), 0.3, 8)
	Furniture.attach(r, "Panel", Vector3.new(1.2, 2.4, 0.15), CFrame.new(1.7, 0, -2.05), Palette.MetalDark)
	for i = 0, 2 do
		Furniture.attach(
			r,
			"Button",
			Vector3.new(0.5, 0.35, 0.1),
			CFrame.new(1.7, 0.7 - i * 0.6, -2.15),
			Palette.AccentKitchen,
			NEON
		)
	end
	return r
end

function Furniture.fridge(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "Fridge", Vector3.new(7, 12, 6), cf)
	Furniture.attach(r, "Body", Vector3.new(7, 12, 6), CFrame.new(), Palette.AccentKitchen)
	Furniture.attach(r, "DoorTop", Vector3.new(6.6, 3.8, 0.3), CFrame.new(0, 3.9, -3.05), Color3.fromRGB(150, 236, 180))
	Furniture.attach(
		r,
		"DoorBottom",
		Vector3.new(6.6, 7.6, 0.3),
		CFrame.new(0, -2, -3.05),
		Color3.fromRGB(150, 236, 180)
	)
	for _, y in { 3.9, 0.2 } do
		cyl(r, "Handle", Vector3.new(2.6, 0.35, 0.35), CFrame.new(2.6, y, -3.35) * UPRIGHT, Palette.Metal, METAL)
	end
	Furniture.attach(r, "Seam", Vector3.new(6.8, 0.25, 0.4), CFrame.new(0, 1.9, -3.05), Palette.MetalDark)
	-- magnets + a crayon drawing of the Baby
	local magnets = { Palette.AccentClean, Palette.Cushion, Palette.AccentToys, Palette.AccentSleep }
	for i, c in magnets do
		Furniture.attach(r, "Magnet", Vector3.new(0.6, 0.6, 0.15), CFrame.new(-2.2 + (i - 1) * 0.9, 5, -3.28), c)
	end
	local drawing = Furniture.attach(
		r,
		"Drawing",
		Vector3.new(3, 3, 0.1),
		CFrame.new(-0.8, -0.2, -3.28) * CFrame.Angles(0, 0, math.rad(-6)),
		Palette.Ceramic
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.8
	gui.Parent = drawing
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.TextScaled = true
	t.Font = Enum.Font.Cartoon
	t.TextColor3 = Palette.MetalDark
	t.Text = "👶\nME"
	t.Parent = gui
	return r
end

function Furniture.trashCan(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "TrashCan", Vector3.new(4, 5, 4), cf)
	cyl(r, "Bin", Vector3.new(4.4, 3.8, 3.8), CFrame.new(0, -0.3, 0) * UPRIGHT, Palette.Metal, METAL)
	cyl(r, "Lid", Vector3.new(0.5, 4.1, 4.1), CFrame.new(0, 2.15, 0) * UPRIGHT, Palette.MetalDark, METAL)
	ball(r, "Knob", 0.7, CFrame.new(0, 2.6, 0), Palette.MetalDark, METAL)
	Furniture.attach(r, "Pedal", Vector3.new(1.4, 0.3, 1), CFrame.new(0, -2.3, -2.2), Palette.MetalDark, METAL)
	Furniture.attach(
		r,
		"Bag",
		Vector3.new(1.2, 0.8, 0.2),
		CFrame.new(1.4, 2.2, -1.2) * CFrame.Angles(math.rad(30), 0, 0),
		Palette.Ceramic
	)
	Furniture.attach(
		r,
		"Banana",
		Vector3.new(0.3, 1.6, 0.3),
		CFrame.new(-1.4, 2.6, 0.6) * CFrame.Angles(0, 0, math.rad(35)),
		Palette.Cushion
	)
	return r
end

function Furniture.bathtub(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "Bathtub", Vector3.new(10, 4, 6), cf)
	Furniture.attach(r, "Tub", Vector3.new(10, 3.2, 6), CFrame.new(0, -0.4, 0), Palette.Ceramic)
	Furniture.attach(r, "Rim", Vector3.new(10.6, 0.6, 6.6), CFrame.new(0, 1.4, 0), Palette.Ceramic)
	Furniture.attach(
		r,
		"Water",
		Vector3.new(8.6, 0.3, 4.8),
		CFrame.new(0, 1.35, 0),
		Palette.WallSky,
		{ transparency = 0.25, shadow = false }
	)
	for _, p in
		{
			Vector3.new(-2.6, 1.9, 1),
			Vector3.new(1.8, 1.8, -1.2),
			Vector3.new(3.4, 1.9, 1.4),
			Vector3.new(-0.4, 2, 0.2),
		}
	do
		ball(r, "Bubble", 1 + (p.X % 1) * 0.6, CFrame.new(p), Palette.Ceramic, { transparency = 0.25, shadow = false })
	end
	ball(r, "Duck", 1.4, CFrame.new(0.6, 2.1, 1), Palette.Cushion)
	ball(r, "DuckHead", 0.9, CFrame.new(1.1, 2.9, 1), Palette.Cushion)
	Furniture.attach(r, "Beak", Vector3.new(0.5, 0.25, 0.5), CFrame.new(1.7, 2.85, 1), Color3.fromRGB(255, 130, 40))
	cyl(r, "Tap", Vector3.new(2, 0.5, 0.5), CFrame.new(-4.4, 2.6, 0) * UPRIGHT, Palette.Metal, METAL)
	cyl(r, "Spout", Vector3.new(1.4, 0.5, 0.5), CFrame.new(-3.7, 3.4, 0), Palette.Metal, METAL)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			ball(r, "Foot", 1.2, CFrame.new(sx * 4.2, -2, sz * 2.4), Palette.Metal, METAL)
		end
	end
	return r
end

function Furniture.bed(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "MomBed", Vector3.new(12, 4, 14), cf)
	Furniture.attach(r, "Frame", Vector3.new(12.4, 1.4, 14.4), CFrame.new(0, -1.3, 0), Palette.WoodMid, WOOD)
	Furniture.attach(r, "Mattress", Vector3.new(12, 1.4, 14), CFrame.new(0, 0.1, 0), Palette.Ceramic, FABRIC)
	Furniture.attach(r, "Blanket", Vector3.new(12.2, 0.7, 9), CFrame.new(0, 1.1, 2.2), Palette.AccentSleep, FABRIC)
	Furniture.attach(
		r,
		"BlanketFold",
		Vector3.new(12.2, 0.4, 2),
		CFrame.new(0, 1.55, -2.1),
		Color3.fromRGB(225, 200, 255),
		FABRIC
	)
	for _, sx in { -1, 1 } do
		Furniture.attach(r, "Pillow", Vector3.new(4.6, 1.2, 3), CFrame.new(sx * 2.9, 1.3, -5), Palette.Ceramic, FABRIC)
	end
	Furniture.attach(r, "Headboard", Vector3.new(12.4, 5, 0.8), CFrame.new(0, 1, -7.4), Palette.WoodMid, WOOD)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Furniture.attach(
				r,
				"Leg",
				Vector3.new(0.9, 1.4, 0.9),
				CFrame.new(sx * 5.6, -2.6, sz * 6.6),
				Palette.WoodDark,
				WOOD
			)
		end
	end
	return r
end

function Furniture.fuseBox(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "FuseBox", Vector3.new(3, 4, 1), cf)
	Furniture.attach(r, "Box", Vector3.new(3, 4, 1), CFrame.new(), Palette.MetalDark, METAL)
	Furniture.attach(r, "Door", Vector3.new(2.6, 3.6, 0.2), CFrame.new(0, 0, -0.55), Palette.Metal, METAL)
	for row = 0, 2 do
		for col = 0, 1 do
			local on = (row + col) % 2 == 0
			Furniture.attach(
				r,
				"Switch",
				Vector3.new(0.6, 0.5, 0.2),
				CFrame.new(-0.6 + col * 1.2, 1 - row * 0.9, -0.75),
				if on then Palette.AccentKitchen else Palette.Mom,
				NEON
			)
		end
	end
	Furniture.attach(r, "Warning", Vector3.new(1.2, 0.5, 0.05), CFrame.new(0, -1.5, -0.7), Palette.AccentUtility)
	return r
end

function Furniture.boiler(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "Boiler", Vector3.new(6, 8, 6), cf)
	cyl(r, "Tank", Vector3.new(7, 5.6, 5.6), CFrame.new(0, -0.3, 0) * UPRIGHT, Palette.Metal, METAL)
	ball(r, "Dome", 5.6, CFrame.new(0, 3.2, 0), Palette.Metal, METAL)
	Furniture.attach(r, "Band", Vector3.new(6.2, 0.6, 6.2), CFrame.new(0, 1.2, 0), Palette.AccentUtility)
	Furniture.attach(r, "Band", Vector3.new(6.2, 0.6, 6.2), CFrame.new(0, -2.4, 0), Palette.AccentUtility)
	cyl(r, "Pipe", Vector3.new(6, 0.7, 0.7), CFrame.new(2.4, 5.5, 0) * UPRIGHT, Palette.MetalDark, METAL)
	cyl(r, "Pipe", Vector3.new(4, 0.7, 0.7), CFrame.new(-2.2, 2, -2.8) * ALONG_Z, Palette.MetalDark, METAL)
	local gauge = cyl(r, "Gauge", Vector3.new(0.3, 1.6, 1.6), CFrame.new(0, 0.6, -3.05) * ALONG_Z, Palette.Ceramic)
	Furniture.attach(
		gauge,
		"Needle",
		Vector3.new(0.1, 0.7, 0.08),
		CFrame.new(0.2, 0.2, 0) * CFrame.Angles(0, 0, math.rad(-35)),
		Palette.Mom
	)
	local fire = Furniture.attach(
		r,
		"Fire",
		Vector3.new(2, 1.2, 0.2),
		CFrame.new(0, -3.4, -3.05),
		Color3.fromRGB(255, 140, 40),
		NEON
	)
	light(fire, Color3.fromRGB(255, 140, 40), 0.6, 12)
	return r
end

function Furniture.lawn(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "Lawn", Vector3.new(30, 0.2, 20), cf, false)
	Furniture.attach(
		r,
		"Patch",
		Vector3.new(30, 0.3, 20),
		CFrame.new(),
		Palette.GrassDark,
		{ material = Enum.Material.Grass }
	)
	local rng = Random.new(3)
	for _ = 1, 14 do
		local x, z = rng:NextNumber(-13, 13), rng:NextNumber(-8, 8)
		Furniture.attachWedge(
			r,
			"Tuft",
			Vector3.new(0.8, 1.6, 0.8),
			CFrame.new(x, 0.9, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
			Palette.Leaf,
			{ shadow = false }
		)
	end
	for i, c in { Palette.AccentClean, Palette.Cushion, Palette.Ceramic } do
		ball(r, "Flower", 0.7, CFrame.new(-10 + i * 5, 0.9, 7), c, { shadow = false })
	end
	return r
end

function Furniture.fence(parent: Instance, name: string, length: number, cf: CFrame, gapAt: number?): Part
	local r = Furniture.root(parent, name, Vector3.new(length, 6, 1), cf)
	for _, y in { -0.8, 1.4 } do
		Furniture.attach(r, "Rail", Vector3.new(length, 0.5, 0.35), CFrame.new(0, y, 0), Palette.Fence)
	end
	local x = -length / 2 + 0.6
	while x <= length / 2 - 0.6 do
		if not (gapAt and math.abs(x - gapAt) < 4) then
			Furniture.attach(r, "Picket", Vector3.new(1, 5.2, 0.5), CFrame.new(x, -0.2, 0), Palette.Fence)
			Furniture.attachWedge(
				r,
				"PicketTip",
				Vector3.new(1, 0.7, 0.5),
				CFrame.new(x, 2.75, 0) * CFrame.Angles(0, 0, 0),
				Palette.Fence
			)
		end
		x += 1.8
	end
	return r
end

function Furniture.frontDoor(parent: Instance, cf: CFrame, width: number, height: number): Part
	-- door frame around the wall opening + door swung open against the inside wall (players walk through)
	local r = Furniture.root(parent, "DoorFrame", Vector3.new(width + 1.6, height + 0.8, 2.6), cf, false)
	for _, sx in { -1, 1 } do
		Furniture.attach(
			r,
			"Jamb",
			Vector3.new(0.8, height + 0.8, 2.6),
			CFrame.new(sx * (width / 2 + 0.4), 0, 0),
			Palette.Trim
		)
	end
	Furniture.attach(r, "Header", Vector3.new(width + 1.6, 0.8, 2.6), CFrame.new(0, height / 2 + 0.4, 0), Palette.Trim)
	local door = Furniture.attach(
		r,
		"Door",
		Vector3.new(0.5, height - 0.4, width * 0.48),
		CFrame.new(-width / 2 + 0.25, -0.2, -width * 0.24 - 1.3),
		Palette.Door
	)
	Furniture.attach(
		door,
		"Panel",
		Vector3.new(0.2, height * 0.32, width * 0.3),
		CFrame.new(-0.3, -height * 0.18, 0),
		Color3.fromRGB(70, 130, 200)
	)
	Furniture.attach(
		door,
		"Glass",
		Vector3.new(0.2, height * 0.22, width * 0.3),
		CFrame.new(-0.3, height * 0.22, 0),
		Palette.Glass,
		{ transparency = 0.3 }
	)
	ball(door, "Knob", 0.7, CFrame.new(-0.5, -0.2, width * 0.17), Palette.Cushion)
	return r
end

--------------------------------------------------------------------------------------------------
-- Outdoors / set dressing
--------------------------------------------------------------------------------------------------

function Furniture.tree(parent: Instance, cf: CFrame, height: number): Part
	local r = Furniture.root(parent, "Tree", Vector3.new(2, height, 2), cf * CFrame.new(0, height / 2, 0))
	cyl(r, "Trunk", Vector3.new(height * 0.6, 2, 2), CFrame.new(0, -height * 0.2, 0) * UPRIGHT, Palette.Bark, WOOD)
	ball(r, "Leaves", height * 0.7, CFrame.new(0, height * 0.28, 0), Palette.Leaf)
	ball(r, "Leaves", height * 0.5, CFrame.new(height * 0.2, height * 0.16, height * 0.1), Palette.LeafDark)
	ball(r, "Leaves", height * 0.5, CFrame.new(-height * 0.18, height * 0.2, -height * 0.12), Palette.LeafDark)
	ball(r, "Leaves", height * 0.42, CFrame.new(0.2, height * 0.5, -0.4), Palette.Leaf)
	return r
end

function Furniture.bush(parent: Instance, cf: CFrame, size: number): Part
	local r =
		Furniture.root(parent, "Bush", Vector3.new(size, size * 0.7, size), cf * CFrame.new(0, size * 0.35, 0), false)
	ball(r, "Leaves", size * 0.8, CFrame.new(0, 0, 0), Palette.Leaf)
	ball(r, "Leaves", size * 0.6, CFrame.new(size * 0.35, -size * 0.05, size * 0.1), Palette.LeafDark)
	ball(r, "Leaves", size * 0.55, CFrame.new(-size * 0.35, -size * 0.08, -size * 0.1), Palette.LeafDark)
	ball(
		r,
		"Flower",
		size * 0.18,
		CFrame.new(size * 0.15, size * 0.35, -size * 0.25),
		Palette.AccentClean,
		{ shadow = false }
	)
	return r
end

function Furniture.streetLamp(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "StreetLamp", Vector3.new(1.2, 18, 1.2), cf * CFrame.new(0, 9, 0))
	cyl(r, "Pole", Vector3.new(17, 0.8, 0.8), CFrame.new(0, -0.5, 0) * UPRIGHT, Palette.MetalDark, METAL)
	cyl(r, "Base", Vector3.new(1, 2, 2), CFrame.new(0, -8.5, 0) * UPRIGHT, Palette.MetalDark, METAL)
	cyl(r, "Arm", Vector3.new(4, 0.6, 0.6), CFrame.new(1.8, 8.2, 0), Palette.MetalDark, METAL)
	local head =
		Furniture.attach(r, "Head", Vector3.new(2.6, 0.8, 1.6), CFrame.new(3.6, 8, 0), Palette.MetalDark, METAL)
	local bulb = Furniture.attach(r, "Bulb", Vector3.new(2, 0.3, 1.2), CFrame.new(3.6, 7.5, 0), Palette.Bulb, NEON)
	local l = light(bulb, Color3.fromRGB(255, 225, 170), 1.2, 44)
	l.Shadows = true
	head.CastShadow = false
	return r
end

function Furniture.mailbox(parent: Instance, cf: CFrame): Part
	local r = Furniture.root(parent, "Mailbox", Vector3.new(1.4, 5, 2.6), cf * CFrame.new(0, 2.5, 0))
	Furniture.attach(r, "Post", Vector3.new(0.6, 3.4, 0.6), CFrame.new(0, -0.8, 0), Palette.WoodMid, WOOD)
	Furniture.attach(r, "Box", Vector3.new(1.4, 1.4, 2.6), CFrame.new(0, 1.6, 0), Palette.AccentToys)
	cyl(r, "BoxTop", Vector3.new(2.6, 1.4, 1.4), CFrame.new(0, 2.3, 0) * ALONG_Z, Palette.AccentToys)
	Furniture.attach(r, "Flag", Vector3.new(0.1, 1.2, 0.5), CFrame.new(0.75, 2.6, -0.6), Palette.Mom)
	return r
end

function Furniture.momCar(parent: Instance, cf: CFrame): Part
	-- Root keeps the old name/size; the client Panic FX drives `Headlight` inside it.
	local r = Furniture.root(parent, "MomCar", Vector3.new(10, 6, 18), cf)
	Furniture.attach(r, "Body", Vector3.new(10, 2.8, 18), CFrame.new(0, -1.2, 0), Palette.Mom)
	Furniture.attach(r, "Cabin", Vector3.new(8.6, 2.8, 9), CFrame.new(0, 1.5, 0.8), Palette.Mom)
	Furniture.attachWedge(
		r,
		"Hood",
		Vector3.new(8.6, 2.8, 4),
		CFrame.new(0, 1.5, -5.7) * CFrame.Angles(0, math.rad(180), 0),
		Palette.Mom
	)
	Furniture.attachWedge(r, "Trunk", Vector3.new(8.6, 2.8, 3), CFrame.new(0, 1.5, 6.8), Palette.Mom)
	Furniture.attach(
		r,
		"Windshield",
		Vector3.new(8, 2.2, 0.3),
		CFrame.new(0, 1.6, -3.6) * CFrame.Angles(math.rad(-30), 0, 0),
		Palette.Glass,
		{ transparency = 0.35, reflectance = 0.2 }
	)
	for _, sx in { -1, 1 } do
		Furniture.attach(
			r,
			"SideGlass",
			Vector3.new(0.3, 1.8, 7),
			CFrame.new(sx * 4.35, 1.7, 0.8),
			Palette.Glass,
			{ transparency = 0.35 }
		)
		for _, z in { -5.5, 5.5 } do
			cyl(r, "Wheel", Vector3.new(1.2, 3, 3), CFrame.new(sx * 5.1, -2.2, z), Palette.Screen)
			cyl(r, "Hub", Vector3.new(1.3, 1.4, 1.4), CFrame.new(sx * 5.1, -2.2, z), Palette.Metal, METAL)
		end
		local lamp =
			Furniture.attach(r, "Lamp", Vector3.new(2, 1.2, 0.3), CFrame.new(sx * 3.2, -0.8, -9.05), Palette.Bulb, NEON)
		lamp.Transparency = 0.15
		Furniture.attach(
			r,
			"TailLamp",
			Vector3.new(2, 0.8, 0.3),
			CFrame.new(sx * 3.2, -0.8, 9.05),
			Color3.fromRGB(255, 60, 60),
			NEON
		)
	end
	Furniture.attach(r, "Bumper", Vector3.new(10.4, 0.8, 0.6), CFrame.new(0, -2.2, -9.1), Palette.Metal, METAL)
	local plate = Furniture.attach(r, "Plate", Vector3.new(3, 1, 0.1), CFrame.new(0, -1.6, -9.15), Palette.Ceramic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = plate
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = Palette.MetalDark
	t.Text = "MOM 1"
	t.Parent = gui
	local headlight = Instance.new("SpotLight")
	headlight.Name = "Headlight"
	headlight.Brightness = 0
	headlight.Range = 120
	headlight.Angle = 60
	headlight.Face = Enum.NormalId.Front
	headlight.Parent = r
	return r
end

-- Framed picture on a wall (SurfaceGui text/emoji as the "art").
function Furniture.picture(parent: Instance, cf: CFrame, size: Vector2, frameColor: Color3, text: string, bg: Color3?)
	local frame = Furniture.block(
		parent,
		"Picture",
		Vector3.new(size.X + 0.8, size.Y + 0.8, 0.4),
		cf,
		frameColor,
		{ collide = false }
	)
	local canvas = Furniture.attach(
		frame,
		"Canvas",
		Vector3.new(size.X, size.Y, 0.2),
		CFrame.new(0, 0, -0.15),
		bg or Palette.Ceramic
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.7
	gui.Parent = canvas
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(0.9, 0.9)
	t.Position = UDim2.fromScale(0.05, 0.05)
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = Palette.MetalDark
	t.Text = text
	t.Parent = gui
	return frame
end

-- Clock face points along the CFrame's -X; pass a rotated cf for walls that run along X.
function Furniture.wallClock(parent: Instance, cf: CFrame)
	local face = Furniture.block(
		parent,
		"Clock",
		Vector3.new(0.3, 3, 3),
		cf,
		Palette.Ceramic,
		{ shape = Enum.PartType.Cylinder, collide = false }
	)
	Furniture.attach(
		face,
		"Rim",
		Vector3.new(0.2, 3.4, 3.4),
		CFrame.new(0.1, 0, 0),
		Palette.AccentClean,
		{ shape = Enum.PartType.Cylinder }
	)
	Furniture.attach(
		face,
		"Hour",
		Vector3.new(0.1, 0.9, 0.16),
		CFrame.new(-0.2, 0.35, 0.1) * CFrame.Angles(math.rad(30), 0, 0),
		Palette.MetalDark
	)
	Furniture.attach(
		face,
		"Minute",
		Vector3.new(0.1, 1.3, 0.12),
		CFrame.new(-0.2, 0.5, -0.2) * CFrame.Angles(math.rad(-60), 0, 0),
		Palette.MetalDark
	)
	return face
end

return Furniture

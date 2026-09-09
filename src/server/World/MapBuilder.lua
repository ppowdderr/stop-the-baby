--!strict
-- The house, generated at runtime from parts so the game is playable straight from Rojo sync.
-- Everything is under Workspace.Map: Geometry (static), Stations (named interaction roots),
-- Props (knockable roots), Waypoints. Only the Station/Prop root parts + names are a contract with
-- the rest of the game; the dressing is free to change (see docs/ART_DIRECTION.md).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Palette = require(Shared:WaitForChild("Palette"))
local Furniture = require(script.Parent.Furniture)

local MapBuilder = {}

local H = 22 -- wall height
local FLOOR_TOP = 1

type Opening = { c: number, w: number, y0: number, y1: number }
type Room = { wall: Color3, stripe: Color3 }

local function label(p: BasePart, text: string)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(6, 1.5)
	bb.StudsOffset = Vector3.new(0, p.Size.Y / 2 + 2, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 60
	bb.Parent = p
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.2
	t.Text = text
	t.Parent = bb
end

local function markStation(p: BasePart, area: string, display: string?)
	p:SetAttribute("Area", area)
	p:SetAttribute("Station", true)
	if display then
		label(p, display)
	end
end

local function markProp(p: BasePart)
	p:SetAttribute("HomeCFrame", p.CFrame)
	p:SetAttribute("Knocked", false)
	p:SetAttribute("Prop", true)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Fix"
	prompt.ObjectText = p.Name
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = p
	p:GetAttributeChangedSignal("Knocked"):Connect(function()
		prompt.Enabled = p:GetAttribute("Knocked") == true
	end)
end

local function waypoint(parent: Instance, area: string, pos: Vector3)
	local p = Furniture.block(parent, "WP_" .. area, Vector3.new(1, 1, 1), CFrame.new(pos), Color3.new(1, 1, 1), {
		transparency = 1,
		collide = false,
		shadow = false,
	})
	p.CanQuery = false
	p:SetAttribute("Area", area)
end

-- Wall along one axis with openings, wallpaper panel, wainscot, baseboard, chair rail, crown, stripes.
-- `along` is the axis the wall runs on, `fixed` its coordinate on the other axis, `inward` (+1/-1)
-- which side of the wall is the room. `room2` dresses the far side too (interior dividers).
local function wall(
	geo: Folder,
	name: string,
	along: "X" | "Z",
	fixed: number,
	a0: number,
	a1: number,
	inward: number,
	room: Room,
	room2: Room?,
	openings: { Opening }
)
	local function box(
		aC: number,
		aL: number,
		yC: number,
		yL: number,
		fC: number,
		t: number,
		color: Color3,
		opts: Furniture.Opts?
	)
		local size = if along == "X" then Vector3.new(aL, yL, t) else Vector3.new(t, yL, aL)
		local pos = if along == "X" then Vector3.new(aC, yC, fC) else Vector3.new(fC, yC, aC)
		return Furniture.block(geo, name, size, CFrame.new(pos), color, opts)
	end

	table.sort(openings, function(p, q)
		return p.c < q.c
	end)

	-- Full-height spans between openings + above/below each opening.
	local function spans(
		fC: number,
		t: number,
		color: Color3,
		yBottom: number,
		yTop: number,
		opts: Furniture.Opts?,
		floorOnly: boolean
	)
		local x = a0
		for _, o in openings do
			local l, r = o.c - o.w / 2, o.c + o.w / 2
			if floorOnly and o.y0 > yBottom then
				continue -- band sits below the opening; run straight through
			end
			if l > x then
				box((x + l) / 2, l - x, (yBottom + yTop) / 2, yTop - yBottom, fC, t, color, opts)
			end
			if not floorOnly then
				if o.y1 < yTop then
					box(o.c, o.w, (o.y1 + yTop) / 2, yTop - o.y1, fC, t, color, opts)
				end
				if o.y0 > yBottom then
					box(o.c, o.w, (yBottom + o.y0) / 2, o.y0 - yBottom, fC, t, color, opts)
				end
			end
			x = r
		end
		if a1 > x then
			box((x + a1) / 2, a1 - x, (yBottom + yTop) / 2, yTop - yBottom, fC, t, color, opts)
		end
	end

	local exterior = if room2 then Palette.Wainscot else Palette.Siding
	spans(fixed, 2, exterior, 0, H, nil, false)

	local function dress(side: number, r: Room)
		local f = function(d: number)
			return fixed + side * d
		end
		spans(f(1.15), 0.3, r.wall, 0, H, { collide = false }, false)
		spans(f(1.55), 0.5, Palette.Wainscot, FLOOR_TOP, 6.5, { collide = false }, true)
		spans(f(1.65), 0.7, Palette.Baseboard, FLOOR_TOP, FLOOR_TOP + 0.8, { collide = false }, true)
		spans(f(1.65), 0.7, Palette.Trim, 6.5, 6.9, { collide = false }, true)
		spans(f(1.6), 0.6, Palette.Trim, H - 0.8, H, { collide = false }, true)
		-- wallpaper stripes
		local a = a0 + 3
		while a < a1 - 1 do
			local blocked = false
			for _, o in openings do
				if a > o.c - o.w / 2 - 0.6 and a < o.c + o.w / 2 + 0.6 then
					blocked = true
				end
			end
			if not blocked then
				box(
					a,
					1.2,
					(6.9 + H - 0.8) / 2,
					H - 0.8 - 6.9,
					f(1.4),
					0.2,
					r.stripe,
					{ collide = false, shadow = false }
				)
			end
			a += 6
		end
	end
	dress(inward, room)
	if room2 then
		dress(-inward, room2)
	end
end

local function pendant(geo: Folder, pos: Vector3, shade: Color3)
	local cord = Furniture.block(
		geo,
		"Cord",
		Vector3.new(0.2, 3, 0.2),
		CFrame.new(pos + Vector3.new(0, 1.5, 0)),
		Palette.MetalDark,
		{ collide = false, shadow = false }
	)
	Furniture.attach(
		cord,
		"Shade",
		Vector3.new(2.4, 4.6, 4.6),
		CFrame.new(0, -2.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		shade,
		{ shape = Enum.PartType.Cylinder }
	)
	local bulb = Furniture.attach(
		cord,
		"Bulb",
		Vector3.new(1.4, 1.4, 1.4),
		CFrame.new(0, -3.4, 0),
		Palette.Bulb,
		{ material = Enum.Material.Neon, shadow = false, shape = Enum.PartType.Ball }
	)
	local pl = Instance.new("PointLight")
	pl.Brightness = 1.1
	pl.Range = 48
	pl.Color = Color3.fromRGB(255, 228, 185)
	pl.Shadows = false
	pl.Parent = bulb
end

local function counter(geo: Folder, cf: CFrame, width: number, doors: number)
	local base =
		Furniture.block(geo, "Counter", Vector3.new(width, 4.2, 4), cf * CFrame.new(0, 2.1, 0), Palette.AccentKitchen)
	Furniture.attach(
		base,
		"Top",
		Vector3.new(width + 0.4, 0.5, 4.4),
		CFrame.new(0, 2.35, -0.1),
		Palette.Ceramic,
		{ material = Enum.Material.Marble }
	)
	Furniture.attach(base, "Kick", Vector3.new(width, 0.6, 0.3), CFrame.new(0, -1.85, -2.05), Palette.MetalDark)
	local dw = (width - 0.6) / doors
	for i = 1, doors do
		local x = -width / 2 + 0.3 + dw * (i - 0.5)
		Furniture.attach(
			base,
			"Door",
			Vector3.new(dw - 0.4, 3.2, 0.2),
			CFrame.new(x, 0.1, -2.05),
			Color3.fromRGB(150, 236, 180)
		)
		Furniture.attach(
			base,
			"Handle",
			Vector3.new(0.25, 1, 0.25),
			CFrame.new(x + dw / 2 - 0.7, 0.4, -2.25),
			Palette.Metal,
			{ material = Enum.Material.Metal, shape = Enum.PartType.Cylinder }
		)
	end
	return base
end

local function upperCabinet(geo: Folder, cf: CFrame, width: number, doors: number)
	local box =
		Furniture.block(geo, "UpperCabinet", Vector3.new(width, 5, 3), cf, Palette.AccentKitchen, { collide = false })
	local dw = (width - 0.6) / doors
	for i = 1, doors do
		local x = -width / 2 + 0.3 + dw * (i - 0.5)
		Furniture.attach(
			box,
			"Door",
			Vector3.new(dw - 0.4, 4.4, 0.2),
			CFrame.new(x, 0, -1.55),
			Color3.fromRGB(150, 236, 180)
		)
		Furniture.attach(
			box,
			"Handle",
			Vector3.new(0.25, 1, 0.25),
			CFrame.new(x + dw / 2 - 0.7, -1.4, -1.75),
			Palette.Metal,
			{ material = Enum.Material.Metal, shape = Enum.PartType.Cylinder }
		)
	end
end

local function stove(geo: Folder, cf: CFrame)
	local base = Furniture.block(geo, "Stove", Vector3.new(7, 4.2, 4), cf * CFrame.new(0, 2.1, 0), Palette.Ceramic)
	Furniture.attach(
		base,
		"Top",
		Vector3.new(7.2, 0.4, 4.2),
		CFrame.new(0, 2.3, 0),
		Palette.MetalDark,
		{ material = Enum.Material.Metal }
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Furniture.attach(
				base,
				"Burner",
				Vector3.new(0.15, 1.8, 1.8),
				CFrame.new(sx * 1.7, 2.55, sz * 1) * CFrame.Angles(0, 0, math.rad(90)),
				Palette.Screen,
				{ shape = Enum.PartType.Cylinder }
			)
		end
	end
	local oven =
		Furniture.attach(base, "OvenDoor", Vector3.new(6, 2.6, 0.2), CFrame.new(0, -0.5, -2.05), Palette.Screen)
	Furniture.attach(
		oven,
		"Glass",
		Vector3.new(4.6, 1.6, 0.1),
		CFrame.new(0, 0, -0.1),
		Color3.fromRGB(255, 190, 110),
		{ material = Enum.Material.Neon, shadow = false }
	)
	Furniture.attach(
		base,
		"Handle",
		Vector3.new(6, 0.35, 0.35),
		CFrame.new(0, 1.2, -2.3),
		Palette.Metal,
		{ material = Enum.Material.Metal, shape = Enum.PartType.Cylinder }
	)
	for i = -1, 1 do
		Furniture.attach(base, "Knob", Vector3.new(0.5, 0.5, 0.3), CFrame.new(i * 1.4, 1.75, -2.15), Palette.Mom)
	end
	-- range hood
	Furniture.block(
		geo,
		"Hood",
		Vector3.new(7, 1.4, 4),
		cf * CFrame.new(0, 11, 0),
		Palette.Metal,
		{ material = Enum.Material.Metal, collide = false }
	)
	Furniture.wedge(
		geo,
		"HoodSlope",
		Vector3.new(7, 1.6, 2.6),
		cf * CFrame.new(0, 12.5, 0.7) * CFrame.Angles(0, math.rad(180), 0),
		Palette.Metal,
		{ material = Enum.Material.Metal, collide = false }
	)
end

local function neighborHouse(geo: Folder, cf: CFrame, siding: Color3)
	local body = Furniture.block(geo, "Neighbor", Vector3.new(60, 20, 50), cf * CFrame.new(0, 10, 0), siding)
	Furniture.wedge(geo, "NeighborRoof", Vector3.new(64, 12, 27), cf * CFrame.new(0, 26, -13.5), Palette.Roof)
	Furniture.wedge(
		geo,
		"NeighborRoof",
		Vector3.new(64, 12, 27),
		cf * CFrame.new(0, 26, 13.5) * CFrame.Angles(0, math.rad(180), 0),
		Palette.Roof
	)
	for _, x in { -18, 0, 18 } do
		local w = Furniture.attach(
			body,
			"Window",
			Vector3.new(7, 7, 0.4),
			CFrame.new(x, 2, -25.1),
			Color3.fromRGB(255, 220, 150),
			{ material = Enum.Material.Neon, shadow = false }
		)
		Furniture.attach(w, "Cross", Vector3.new(0.5, 7, 0.2), CFrame.new(0, 0, -0.2), Palette.Trim)
		Furniture.attach(w, "Cross", Vector3.new(7, 0.5, 0.2), CFrame.new(0, 0, -0.2), Palette.Trim)
	end
	Furniture.attach(body, "Door", Vector3.new(6, 10, 0.4), CFrame.new(-8, -5, -25.1), Palette.WoodDark)
end

function MapBuilder.build(): Folder
	local existing = workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "Map"
	local geo = Instance.new("Folder")
	geo.Name = "Geometry"
	geo.Parent = map
	local stations = Instance.new("Folder")
	stations.Name = "Stations"
	stations.Parent = map
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = map
	local wps = Instance.new("Folder")
	wps.Name = "Waypoints"
	wps.Parent = map

	local living = Palette.Rooms.LivingRoom
	local kitchen = Palette.Rooms.Kitchen

	----------------------------------------------------------------------------------------------
	-- Ground, street, yard
	----------------------------------------------------------------------------------------------
	Furniture.block(
		geo,
		"Grass",
		Vector3.new(400, 1, 400),
		CFrame.new(0, -0.5, 0),
		Palette.Grass,
		{ material = Enum.Material.Grass }
	)
	local rngG = Random.new(11)
	for _ = 1, 16 do
		local x, z = rngG:NextNumber(-190, 190), rngG:NextNumber(-190, 95)
		if math.abs(x) > 75 or z < -55 then
			Furniture.block(
				geo,
				"GrassPatch",
				Vector3.new(0.12, rngG:NextNumber(14, 30), rngG:NextNumber(14, 30)),
				CFrame.new(x, 0.02, z) * CFrame.Angles(0, 0, math.rad(90)),
				Palette.GrassDark,
				{ material = Enum.Material.Grass, shape = Enum.PartType.Cylinder, collide = false, shadow = false }
			)
		end
	end
	Furniture.block(
		geo,
		"Road",
		Vector3.new(400, 0.2, 24),
		CFrame.new(0, 0.1, 120),
		Palette.Road,
		{ material = Enum.Material.Asphalt }
	)
	for x = -196, 196, 14 do
		Furniture.block(
			geo,
			"RoadLine",
			Vector3.new(7, 0.22, 0.8),
			CFrame.new(x, 0.11, 120),
			Palette.RoadLine,
			{ collide = false, shadow = false }
		)
	end
	Furniture.block(
		geo,
		"Sidewalk",
		Vector3.new(400, 0.3, 8),
		CFrame.new(0, 0.15, 104),
		Palette.Sidewalk,
		{ material = Enum.Material.Concrete }
	)
	Furniture.block(
		geo,
		"Curb",
		Vector3.new(400, 0.5, 1),
		CFrame.new(0, 0.25, 108.5),
		Palette.Sidewalk,
		{ material = Enum.Material.Concrete }
	)
	Furniture.block(
		geo,
		"Driveway",
		Vector3.new(16, 0.2, 60),
		CFrame.new(40, 0.1, 80),
		Palette.Sidewalk,
		{ material = Enum.Material.Concrete }
	)
	Furniture.block(
		geo,
		"Path",
		Vector3.new(8, 0.25, 52),
		CFrame.new(0, 0.12, 76),
		Palette.Path,
		{ material = Enum.Material.Concrete }
	)

	-- porch
	Furniture.block(
		geo,
		"Porch",
		Vector3.new(26, 1, 10),
		CFrame.new(0, 0.5, 45),
		Palette.WoodLight,
		{ material = Enum.Material.WoodPlanks }
	)
	Furniture.block(
		geo,
		"PorchStep",
		Vector3.new(12, 0.5, 2),
		CFrame.new(0, 0.25, 51),
		Palette.WoodLight,
		{ material = Enum.Material.WoodPlanks }
	)
	for _, sx in { -1, 1 } do
		Furniture.block(geo, "PorchColumn", Vector3.new(1.4, 15, 1.4), CFrame.new(sx * 11.5, 8.5, 48.5), Palette.Trim)
	end
	local porchRoof = Furniture.block(geo, "PorchRoof", Vector3.new(28, 1, 12), CFrame.new(0, 16.5, 46), Palette.Roof)
	Furniture.attach(porchRoof, "Fascia", Vector3.new(28.4, 1.2, 0.6), CFrame.new(0, -0.2, 6.2), Palette.RoofTrim)
	local porchLight = Furniture.block(
		geo,
		"PorchLight",
		Vector3.new(1.4, 1.4, 1.4),
		CFrame.new(10, 13, 40.9),
		Palette.Bulb,
		{ material = Enum.Material.Neon, collide = false, shadow = false, shape = Enum.PartType.Ball }
	)
	do
		local pl = Instance.new("PointLight")
		pl.Brightness = 1
		pl.Range = 30
		pl.Color = Color3.fromRGB(255, 220, 170)
		pl.Parent = porchLight
	end
	local mat = Furniture.block(
		geo,
		"Doormat",
		Vector3.new(8, 0.15, 4),
		CFrame.new(0, 1.07, 44),
		Palette.AccentClean,
		{ material = Enum.Material.Fabric, collide = false }
	)
	do
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = mat
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.TextScaled = true
		t.Font = Enum.Font.FredokaOne
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Text = "SHHH... BABY"
		t.Parent = gui
	end

	----------------------------------------------------------------------------------------------
	-- Floors
	----------------------------------------------------------------------------------------------
	for i = 0, 17 do
		local x = -60 + 2 + i * 3.9
		Furniture.block(
			geo,
			"Plank",
			Vector3.new(3.9, 1, 80),
			CFrame.new(x - 0.05, 0.5, 0),
			if i % 2 == 0 then Palette.FloorWood else Palette.FloorWoodDark,
			{ material = Enum.Material.WoodPlanks }
		)
	end
	for ix = 0, 4 do
		for iz = 0, 7 do
			local x, z = 10 + 5 + ix * 10, -40 + 5 + iz * 10
			Furniture.block(
				geo,
				"Tile",
				Vector3.new(10, 1, 10),
				CFrame.new(x, 0.5, z),
				if (ix + iz) % 2 == 0 then Palette.FloorTile else Palette.FloorTileAlt,
				{ material = Enum.Material.SmoothPlastic }
			)
		end
	end
	Furniture.block(
		geo,
		"Threshold",
		Vector3.new(1.2, 1.05, 36),
		CFrame.new(10, 0.52, 22),
		Palette.WoodDark,
		{ material = Enum.Material.Wood }
	)

	----------------------------------------------------------------------------------------------
	-- Walls (openings: windows + front door)
	----------------------------------------------------------------------------------------------
	wall(geo, "WallN", "X", -40, -60, 10, 1, living, nil, { { c = -30, w = 14, y0 = 7, y1 = 17 } })
	wall(geo, "WallN", "X", -40, 10, 60, 1, kitchen, nil, { { c = 40, w = 10, y0 = 8, y1 = 16 } })
	wall(
		geo,
		"WallS",
		"X",
		40,
		-60,
		10,
		-1,
		living,
		nil,
		{ { c = 0, w = 16, y0 = 0, y1 = 14 }, { c = -38, w = 12, y0 = 7, y1 = 17 } }
	)
	wall(geo, "WallS", "X", 40, 10, 60, -1, kitchen, nil, { { c = 38, w = 12, y0 = 7, y1 = 17 } })
	wall(geo, "WallW", "Z", -60, -40, 40, 1, living, nil, { { c = -5, w = 10, y0 = 8, y1 = 16 } })
	wall(geo, "WallE", "Z", 60, -40, 40, -1, kitchen, nil, { { c = 22, w = 10, y0 = 8, y1 = 16 } })
	wall(geo, "Divider", "Z", 10, -40, 4, -1, living, kitchen, {})
	-- exterior corner boards
	for _, c in { Vector3.new(-60, 0, -40), Vector3.new(60, 0, -40), Vector3.new(-60, 0, 40), Vector3.new(60, 0, 40) } do
		Furniture.block(
			geo,
			"CornerBoard",
			Vector3.new(2.6, H, 2.6),
			CFrame.new(c.X, H / 2, c.Z),
			Palette.Trim,
			{ collide = false }
		)
	end
	Furniture.block(
		geo,
		"Ceiling",
		Vector3.new(120, 1, 80),
		CFrame.new(0, H + 0.5, 0),
		Palette.Ceiling,
		{ collide = false }
	)

	-- windows (frames + glass + curtains). Local -Z must face the room.
	local function win(
		parent: Instance,
		name: string,
		w: number,
		h: number,
		pos: Vector3,
		yaw: number,
		curtains: boolean
	): Part
		return Furniture.window(
			parent,
			name,
			Vector3.new(w, h, 2),
			CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw), 0),
			curtains
		)
	end
	local windowStation = win(stations, "Window", 14, 10, Vector3.new(-30, 12, -40), 180, true)
	markStation(windowStation, "LivingRoom", "🪟 Window")
	win(geo, "WindowKitchenN", 10, 8, Vector3.new(40, 12, -40), 180, false)
	win(geo, "WindowLivingS", 12, 10, Vector3.new(-38, 12, 40), 0, true)
	win(geo, "WindowKitchenS", 12, 10, Vector3.new(38, 12, 40), 0, false)
	win(geo, "WindowW", 10, 8, Vector3.new(-60, 12, -5), -90, true)
	win(geo, "WindowE", 10, 8, Vector3.new(60, 12, 22), 90, false)
	Furniture.frontDoor(geo, CFrame.new(0, 7, 40), 16, 14)

	----------------------------------------------------------------------------------------------
	-- Roof
	----------------------------------------------------------------------------------------------
	Furniture.wedge(
		geo,
		"RoofN",
		Vector3.new(128, 14, 44),
		CFrame.new(0, H + 8, -22),
		Palette.Roof,
		{ collide = false }
	)
	Furniture.wedge(
		geo,
		"RoofS",
		Vector3.new(128, 14, 44),
		CFrame.new(0, H + 8, 22) * CFrame.Angles(0, math.rad(180), 0),
		Palette.Roof,
		{ collide = false }
	)
	for _, sx in { -1, 1 } do
		Furniture.wedge(
			geo,
			"Gable",
			Vector3.new(2, 13, 40),
			CFrame.new(sx * 60, H + 7.5, -20),
			Palette.Siding,
			{ collide = false }
		)
		Furniture.wedge(
			geo,
			"Gable",
			Vector3.new(2, 13, 40),
			CFrame.new(sx * 60, H + 7.5, 20) * CFrame.Angles(0, math.rad(180), 0),
			Palette.Siding,
			{ collide = false }
		)
	end
	Furniture.block(
		geo,
		"Ridge",
		Vector3.new(130, 1.2, 2.4),
		CFrame.new(0, H + 15.4, 0),
		Palette.RoofTrim,
		{ collide = false }
	)
	Furniture.block(
		geo,
		"Chimney",
		Vector3.new(6, 12, 6),
		CFrame.new(40, H + 14, -14),
		Color3.fromRGB(190, 110, 90),
		{ material = Enum.Material.Brick, collide = false }
	)
	Furniture.block(
		geo,
		"ChimneyCap",
		Vector3.new(7, 1, 7),
		CFrame.new(40, H + 20.5, -14),
		Palette.MetalDark,
		{ collide = false }
	)

	----------------------------------------------------------------------------------------------
	-- Ceiling lights
	----------------------------------------------------------------------------------------------
	pendant(geo, Vector3.new(-42, H - 3, -18), Palette.LampShade)
	pendant(geo, Vector3.new(-20, H - 3, 16), Palette.LampShade)
	pendant(geo, Vector3.new(25, H - 3, -18), Palette.AccentKitchen)
	pendant(geo, Vector3.new(45, H - 3, 16), Palette.AccentKitchen)

	----------------------------------------------------------------------------------------------
	-- Spawns
	----------------------------------------------------------------------------------------------
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlayerSpawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(-10, 1.5, 28)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = geo

	local babySpawn = Furniture.block(
		stations,
		"BabySpawn",
		Vector3.new(6, 0.2, 6),
		CFrame.new(-30, 1.1, -10),
		Palette.Baby,
		{ transparency = 1, collide = false, shadow = false }
	)
	markStation(babySpawn, "LivingRoom")

	----------------------------------------------------------------------------------------------
	-- Living room: stations
	----------------------------------------------------------------------------------------------
	markStation(Furniture.crib(stations, CFrame.new(-50, 4, -30)), "LivingRoom", "🛏️ CRIB")
	markStation(Furniture.toyBin(stations, CFrame.new(-52, 3, 10)), "LivingRoom", "🧸 Toy Bin")
	markStation(Furniture.rug(stations, CFrame.new(-25, 1.15, 5)), "LivingRoom", "🧹 Rug")
	markStation(Furniture.laundry(stations, CFrame.new(-52, 3, 30)), "LivingRoom", "🧺 Laundry")
	local doorMat = Furniture.block(
		stations,
		"FrontDoor",
		Vector3.new(14, 0.2, 4),
		CFrame.new(0, 1.1, 44),
		Palette.Door,
		{ transparency = 1, collide = false, shadow = false }
	)
	markStation(doorMat, "LivingRoom", "🚪 Front Door")
	-- later-night stations, parked in the house until Upstairs/Basement exist
	markStation(Furniture.bathtub(stations, CFrame.new(-50, 3, -10)), "Upstairs", "🛁 Bath")
	markStation(Furniture.bed(stations, CFrame.new(-10, 3, -30)), "Upstairs", "🛌 Mom's Bed")

	-- Living room: set dressing
	local tvStand = Furniture.block(
		geo,
		"TVStand",
		Vector3.new(16, 3, 4),
		CFrame.new(-25, 2.5, -36.5),
		Palette.WoodMid,
		{ material = Enum.Material.Wood }
	)
	Furniture.attach(tvStand, "Drawer", Vector3.new(6.5, 1.6, 0.2), CFrame.new(-4, 0, -2.05), Palette.WoodLight)
	Furniture.attach(tvStand, "Drawer", Vector3.new(6.5, 1.6, 0.2), CFrame.new(4, 0, -2.05), Palette.WoodLight)
	Furniture.block(
		geo,
		"Console",
		Vector3.new(6, 3.6, 2.5),
		CFrame.new(-40, 2.8, 37.4),
		Palette.WoodLight,
		{ material = Enum.Material.Wood }
	)
	Furniture.picture(
		geo,
		CFrame.new(-45, 14, -38.3) * CFrame.Angles(0, math.rad(180), 0),
		Vector2.new(5, 4),
		Palette.AccentSleep,
		"👶",
		Color3.fromRGB(255, 240, 220)
	)
	Furniture.picture(
		geo,
		CFrame.new(-14, 15.5, -38.3) * CFrame.Angles(0, math.rad(180), 0),
		Vector2.new(4, 5),
		Palette.WoodDark,
		"🏠",
		Palette.WallSky
	)
	Furniture.picture(geo, CFrame.new(-20, 14, 38.3), Vector2.new(6, 4), Palette.Cushion, "😴 zzz", Palette.WallPeach)
	Furniture.wallClock(geo, CFrame.new(8.55, 15, -22))

	-- Living room: knockable props
	markProp(Furniture.couch(props, CFrame.new(-25, 3, 20)))
	markProp(Furniture.armchair(props, "Armchair", CFrame.new(-6, 2.5, 12) * CFrame.Angles(0, math.rad(-40), 0)))
	markProp(Furniture.coffeeTable(props, CFrame.new(-25, 2.5, 6)))
	markProp(Furniture.tv(props, CFrame.new(-25, 7.6, -36.5)))
	markProp(Furniture.bookshelf(props, CFrame.new(-5, 7, -36)))
	markProp(Furniture.floorLamp(props, CFrame.new(-37, 5, 26)))
	markProp(Furniture.vase(props, CFrame.new(-40, 6.1, 37.4)))
	markProp(Furniture.plant(props, CFrame.new(6, 4, 34)))
	markProp(Furniture.toyBlocks(props, CFrame.new(-40, 2.8, -6)))

	----------------------------------------------------------------------------------------------
	-- Kitchen: stations (fronts must face the room: -Z local -> yaw 180 on the north wall, 90 on the east)
	----------------------------------------------------------------------------------------------
	markStation(
		Furniture.sinkCounter(stations, CFrame.new(48, 3.5, -37) * CFrame.Angles(0, math.rad(180), 0)),
		"Kitchen",
		"🍽️ Sink"
	)
	markStation(
		Furniture.microwave(stations, CFrame.new(56.5, 6.1, -15) * CFrame.Angles(0, math.rad(90), 0)),
		"Kitchen",
		"🍼 Microwave"
	)
	markStation(
		Furniture.fridge(stations, CFrame.new(56.5, 7, 0) * CFrame.Angles(0, math.rad(90), 0)),
		"Kitchen",
		"🧊 Fridge"
	)
	markStation(
		Furniture.trashCan(stations, CFrame.new(57, 3.5, 30) * CFrame.Angles(0, math.rad(90), 0)),
		"Kitchen",
		"🗑️ Trash"
	)
	markStation(
		Furniture.fuseBox(stations, CFrame.new(59, 8, 15) * CFrame.Angles(0, math.rad(90), 0)),
		"Basement",
		"⚡ Fuse Box"
	)
	markStation(
		Furniture.boiler(stations, CFrame.new(50, 5, 34) * CFrame.Angles(0, math.rad(180), 0)),
		"Basement",
		"🔥 Boiler"
	)

	-- Kitchen: set dressing
	counter(geo, CFrame.new(29, FLOOR_TOP, -38) * CFrame.Angles(0, math.rad(180), 0), 30, 4) -- x 14..44
	stove(geo, CFrame.new(22, FLOOR_TOP, -38) * CFrame.Angles(0, math.rad(180), 0))
	counter(geo, CFrame.new(56, FLOOR_TOP, -38) * CFrame.Angles(0, math.rad(180), 0), 6, 1) -- x 53..59
	upperCabinet(geo, CFrame.new(24, 15, -38.5) * CFrame.Angles(0, math.rad(180), 0), 20, 3) -- x 14..34 (window at 35..45)
	upperCabinet(geo, CFrame.new(52, 15, -38.5) * CFrame.Angles(0, math.rad(180), 0), 12, 2) -- x 46..58
	counter(geo, CFrame.new(58, FLOOR_TOP, -15) * CFrame.Angles(0, math.rad(90), 0), 14, 2) -- east wall, under the microwave
	Furniture.picture(
		geo,
		CFrame.new(28, 15, 38.3),
		Vector2.new(5, 4),
		Palette.AccentKitchen,
		"🍼 🍎",
		Palette.Ceramic
	)
	Furniture.wallClock(geo, CFrame.new(11.45, 15, -22) * CFrame.Angles(0, math.rad(180), 0))

	-- Kitchen: knockable props
	markProp(Furniture.diningTable(props, CFrame.new(34, 3.5, 20)))
	markProp(Furniture.chair(props, "Chair1", CFrame.new(28, 2.5, 12) * CFrame.Angles(0, math.rad(180), 0)))
	markProp(Furniture.chair(props, "Chair2", CFrame.new(40, 2.5, 12) * CFrame.Angles(0, math.rad(180), 0)))
	markProp(Furniture.chair(props, "Chair3", CFrame.new(34, 2.5, 28)))
	markProp(Furniture.stool(props, CFrame.new(20, 2.5, -25)))

	----------------------------------------------------------------------------------------------
	-- Yard: stations + dressing
	----------------------------------------------------------------------------------------------
	local outside = Furniture.block(
		stations,
		"Outside",
		Vector3.new(6, 0.2, 6),
		CFrame.new(0, 0.1, 70),
		Palette.Grass,
		{ transparency = 1, collide = false, shadow = false }
	)
	markStation(outside, "Backyard")
	markStation(Furniture.lawn(stations, CFrame.new(-40, 0.1, 60)), "Backyard", "🌱 Lawn")
	markStation(Furniture.fence(stations, "Fence", 60, CFrame.new(-30, 3, 75)), "Backyard", "🪚 Fence")
	Furniture.fence(geo, "FenceW", 35, CFrame.new(-60, 3, 57.5) * CFrame.Angles(0, math.rad(90), 0))
	Furniture.fence(geo, "FenceE", 35, CFrame.new(60, 3, 57.5) * CFrame.Angles(0, math.rad(90), 0))
	Furniture.fence(geo, "FenceBackW", 90, CFrame.new(-105, 3, 40) * CFrame.Angles(0, math.rad(90), 0))
	Furniture.fence(geo, "FenceBackE", 90, CFrame.new(105, 3, 40) * CFrame.Angles(0, math.rad(90), 0))

	Furniture.mailbox(geo, CFrame.new(12, 0, 100) * CFrame.Angles(0, math.rad(180), 0))
	for _, x in { -50, -24, 22, 54 } do
		Furniture.bush(geo, CFrame.new(x, 0, 45), 6)
	end
	for _, t in
		{
			{ -80, 60, 26 },
			{ 90, 68, 30 },
			{ -96, -20, 34 },
			{ 96, -30, 30 },
			{ -40, -72, 36 },
			{ 60, -80, 32 },
			{ -140, 80, 28 },
			{ 150, 78, 30 },
		}
	do
		Furniture.tree(geo, CFrame.new(t[1], 0, t[2]), t[3])
	end
	Furniture.streetLamp(geo, CFrame.new(-30, 0, 100))
	Furniture.streetLamp(geo, CFrame.new(75, 0, 100) * CFrame.Angles(0, math.rad(180), 0))
	neighborHouse(geo, CFrame.new(-165, 0, 0), Palette.WallSky)
	neighborHouse(geo, CFrame.new(165, 0, 0), Palette.WallPeach)

	----------------------------------------------------------------------------------------------
	-- Baby waypoints
	----------------------------------------------------------------------------------------------
	for _, pos in
		{
			Vector3.new(-45, 3, -22),
			Vector3.new(-45, 3, 20),
			Vector3.new(-25, 3, -8),
			Vector3.new(-12, 3, -22),
			Vector3.new(-12, 3, 24),
			Vector3.new(-38, 3, 0),
			Vector3.new(0, 3, 10),
			Vector3.new(-20, 3, 30),
		}
	do
		waypoint(wps, "LivingRoom", pos)
	end
	for _, pos in
		{
			Vector3.new(30, 3, -28),
			Vector3.new(48, 3, -20),
			Vector3.new(30, 3, 32),
			Vector3.new(50, 3, 16),
			Vector3.new(44, 3, 0),
			Vector3.new(18, 3, 20),
		}
	do
		waypoint(wps, "Kitchen", pos)
	end
	waypoint(wps, "Backyard", Vector3.new(0, 2, 60))
	waypoint(wps, "Backyard", Vector3.new(-40, 2, 60))
	waypoint(wps, "Backyard", Vector3.new(-20, 2, 68))

	-- Mom's car (client Panic FX drives Headlight inside it)
	Furniture.momCar(geo, CFrame.new(40, 3.2, 150))

	map.Parent = workspace
	return map
end

return MapBuilder

--!strict
-- Greybox house generated at runtime so the game is playable straight from Rojo sync.
-- Everything is under Workspace.Map: Geometry, Stations (named interaction points), Props (knockable), Waypoints.
-- Replace with hand-built art later; keep Station/Waypoint names and Area attributes.
local MapBuilder = {}

local WALL = Color3.fromRGB(235, 225, 205)
local FLOOR = Color3.fromRGB(180, 140, 100)
local KITCHEN_FLOOR = Color3.fromRGB(220, 220, 225)
local GRASS = Color3.fromRGB(95, 170, 80)
local ROAD = Color3.fromRGB(70, 70, 75)

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

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

local function station(
	parent: Instance,
	name: string,
	area: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	display: string?
): Part
	local p = part(parent, name, size, cf, color)
	p:SetAttribute("Area", area)
	p:SetAttribute("Station", true)
	if display then
		label(p, display)
	end
	return p
end

local function prop(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = part(parent, name, size, cf, color)
	p:SetAttribute("HomeCFrame", cf)
	p:SetAttribute("Knocked", false)
	p:SetAttribute("Prop", true)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Fix"
	prompt.ObjectText = name
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = p
	p:GetAttributeChangedSignal("Knocked"):Connect(function()
		prompt.Enabled = p:GetAttribute("Knocked") == true
	end)
	return p
end

local function waypoint(parent: Instance, area: string, pos: Vector3): Part
	local p = part(parent, "WP_" .. area, Vector3.new(1, 1, 1), CFrame.new(pos), Color3.new(1, 1, 1))
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p:SetAttribute("Area", area)
	return p
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

	-- Ground & street
	part(geo, "Grass", Vector3.new(400, 1, 400), CFrame.new(0, -0.5, 0), GRASS, Enum.Material.Grass)
	part(geo, "Road", Vector3.new(400, 0.2, 24), CFrame.new(0, 0.1, 120), ROAD, Enum.Material.Asphalt)
	part(
		geo,
		"Driveway",
		Vector3.new(16, 0.2, 60),
		CFrame.new(40, 0.1, 80),
		Color3.fromRGB(150, 150, 150),
		Enum.Material.Concrete
	)

	-- House shell: 120 x 80 footprint, 24 tall. Living room (west) + Kitchen (east), front door south.
	local H = 22
	part(geo, "FloorLiving", Vector3.new(70, 1, 80), CFrame.new(-25, 0.5, 0), FLOOR, Enum.Material.WoodPlanks)
	part(geo, "FloorKitchen", Vector3.new(50, 1, 80), CFrame.new(35, 0.5, 0), KITCHEN_FLOOR, Enum.Material.Marble)
	part(geo, "WallN", Vector3.new(120, H, 2), CFrame.new(0, H / 2, -40), WALL)
	part(geo, "WallS_L", Vector3.new(52, H, 2), CFrame.new(-34, H / 2, 40), WALL)
	part(geo, "WallS_R", Vector3.new(52, H, 2), CFrame.new(34, H / 2, 40), WALL)
	part(geo, "WallS_Top", Vector3.new(16, H - 14, 2), CFrame.new(0, 14 + (H - 14) / 2, 40), WALL)
	part(geo, "WallW", Vector3.new(2, H, 80), CFrame.new(-60, H / 2, 0), WALL)
	part(geo, "WallE", Vector3.new(2, H, 80), CFrame.new(60, H / 2, 0), WALL)
	part(geo, "Divider", Vector3.new(2, H, 44), CFrame.new(10, H / 2, -18), WALL) -- leaves a 36-wide opening to kitchen
	local ceiling = part(geo, "Ceiling", Vector3.new(120, 1, 80), CFrame.new(0, H + 0.5, 0), WALL)
	ceiling.Transparency = 0.6
	ceiling.CanCollide = false
	for i, pos in
		{
			Vector3.new(-42, H - 1, -18),
			Vector3.new(-20, H - 1, 16),
			Vector3.new(25, H - 1, -18),
			Vector3.new(45, H - 1, 16),
		}
	do
		local lamp = part(
			geo,
			"CeilingLamp" .. i,
			Vector3.new(5, 0.6, 5),
			CFrame.new(pos),
			Color3.fromRGB(255, 245, 205),
			Enum.Material.Neon
		)
		lamp.CanCollide = false
		local pl = Instance.new("PointLight")
		pl.Brightness = 1.1
		pl.Range = 48
		pl.Color = Color3.fromRGB(255, 228, 185)
		pl.Shadows = false
		pl.Parent = lamp
	end

	-- Spawns
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

	local babySpawn = station(
		stations,
		"BabySpawn",
		"LivingRoom",
		Vector3.new(6, 0.2, 6),
		CFrame.new(-30, 1.1, -10),
		Color3.fromRGB(255, 200, 220)
	)
	babySpawn.Transparency = 1
	babySpawn.CanCollide = false

	-- Stations (chores)
	station(
		stations,
		"Crib",
		"LivingRoom",
		Vector3.new(14, 6, 10),
		CFrame.new(-50, 4, -30),
		Color3.fromRGB(255, 180, 200),
		"🛏️ CRIB"
	)
	station(
		stations,
		"ToyBin",
		"LivingRoom",
		Vector3.new(6, 4, 6),
		CFrame.new(-52, 3, 10),
		Color3.fromRGB(90, 160, 255),
		"🧸 Toy Bin"
	)
	local rug = station(
		stations,
		"Rug",
		"LivingRoom",
		Vector3.new(24, 0.3, 16),
		CFrame.new(-25, 1.15, 5),
		Color3.fromRGB(170, 60, 60),
		"🧹 Rug"
	)
	rug.Material = Enum.Material.Fabric
	station(
		stations,
		"Laundry",
		"LivingRoom",
		Vector3.new(6, 4, 6),
		CFrame.new(-52, 3, 30),
		Color3.fromRGB(240, 240, 250),
		"🧺 Laundry"
	)
	station(
		stations,
		"Window",
		"LivingRoom",
		Vector3.new(14, 10, 0.5),
		CFrame.new(-30, 12, -38.6),
		Color3.fromRGB(180, 220, 255),
		"🪟 Window"
	)
	station(
		stations,
		"Sink",
		"Kitchen",
		Vector3.new(8, 5, 5),
		CFrame.new(50, 3.5, -30),
		Color3.fromRGB(200, 200, 210),
		"🍽️ Sink"
	)
	station(
		stations,
		"Microwave",
		"Kitchen",
		Vector3.new(5, 3, 4),
		CFrame.new(55, 7.5, -15),
		Color3.fromRGB(60, 60, 65),
		"🍼 Microwave"
	)
	station(
		stations,
		"Fridge",
		"Kitchen",
		Vector3.new(7, 12, 6),
		CFrame.new(55, 7, 0),
		Color3.fromRGB(230, 230, 235),
		"🧊 Fridge"
	)
	station(
		stations,
		"TrashCan",
		"Kitchen",
		Vector3.new(4, 5, 4),
		CFrame.new(55, 3.5, 30),
		Color3.fromRGB(80, 110, 80),
		"🗑️ Trash"
	)
	station(
		stations,
		"FrontDoor",
		"LivingRoom",
		Vector3.new(14, 0.2, 4),
		CFrame.new(0, 1.1, 44),
		Color3.fromRGB(120, 80, 50),
		"🚪 Front Door"
	)
	local outside = station(stations, "Outside", "Backyard", Vector3.new(6, 0.2, 6), CFrame.new(0, 0.1, 70), GRASS)
	outside.Transparency = 1
	-- Later-night stations (placeholders in-house until Upstairs/Basement/Backyard are built)
	station(
		stations,
		"Bathtub",
		"Upstairs",
		Vector3.new(10, 4, 6),
		CFrame.new(-50, 3, -10),
		Color3.fromRGB(220, 240, 255),
		"🛁 Bath"
	)
	station(
		stations,
		"MomBed",
		"Upstairs",
		Vector3.new(12, 4, 14),
		CFrame.new(-10, 3, -30),
		Color3.fromRGB(200, 120, 160),
		"🛌 Mom's Bed"
	)
	station(
		stations,
		"FuseBox",
		"Basement",
		Vector3.new(3, 4, 1),
		CFrame.new(58.5, 8, 15),
		Color3.fromRGB(90, 90, 95),
		"⚡ Fuse Box"
	)
	station(
		stations,
		"Boiler",
		"Basement",
		Vector3.new(6, 8, 6),
		CFrame.new(40, 4.5, -34),
		Color3.fromRGB(120, 90, 80),
		"🔥 Boiler"
	)
	station(
		stations,
		"Lawn",
		"Backyard",
		Vector3.new(30, 0.2, 20),
		CFrame.new(-40, 0.1, 60),
		Color3.fromRGB(70, 150, 60),
		"🌱 Lawn"
	)
	station(
		stations,
		"Fence",
		"Backyard",
		Vector3.new(60, 6, 1),
		CFrame.new(-30, 3, 75),
		Color3.fromRGB(190, 160, 120),
		"🪚 Fence"
	)

	-- Knockable props
	prop(props, "Lamp", Vector3.new(2, 8, 2), CFrame.new(-12, 5, -20), Color3.fromRGB(255, 240, 180))
	prop(props, "Vase", Vector3.new(2, 3, 2), CFrame.new(-40, 2.5, 34), Color3.fromRGB(100, 140, 220))
	prop(props, "Chair1", Vector3.new(4, 5, 4), CFrame.new(28, 3.5, 10), Color3.fromRGB(150, 100, 60))
	prop(props, "Chair2", Vector3.new(4, 5, 4), CFrame.new(40, 3.5, 10), Color3.fromRGB(150, 100, 60))
	prop(props, "Table", Vector3.new(14, 1, 8), CFrame.new(34, 4.5, 20), Color3.fromRGB(130, 90, 50))
	prop(props, "TV", Vector3.new(12, 7, 1), CFrame.new(-25, 6, -36), Color3.fromRGB(30, 30, 35))
	prop(props, "Bookshelf", Vector3.new(10, 12, 3), CFrame.new(-5, 7, -36), Color3.fromRGB(110, 70, 40))
	prop(props, "Plant", Vector3.new(3, 6, 3), CFrame.new(5, 4, 30), Color3.fromRGB(60, 140, 60))
	prop(props, "Couch", Vector3.new(16, 4, 6), CFrame.new(-25, 3, 20), Color3.fromRGB(80, 90, 160))
	prop(props, "Stool", Vector3.new(3, 3, 3), CFrame.new(20, 2.5, -25), Color3.fromRGB(200, 60, 60))

	-- Waypoints
	for _, pos in
		{
			Vector3.new(-45, 3, -25),
			Vector3.new(-45, 3, 25),
			Vector3.new(-25, 3, 0),
			Vector3.new(-10, 3, -25),
			Vector3.new(-10, 3, 25),
			Vector3.new(-40, 3, 0),
			Vector3.new(0, 3, 10),
		}
	do
		waypoint(wps, "LivingRoom", pos)
	end
	for _, pos in
		{
			Vector3.new(30, 3, -25),
			Vector3.new(50, 3, -10),
			Vector3.new(30, 3, 30),
			Vector3.new(50, 3, 20),
			Vector3.new(40, 3, 0),
		}
	do
		waypoint(wps, "Kitchen", pos)
	end
	waypoint(wps, "Backyard", Vector3.new(0, 2, 60))
	waypoint(wps, "Backyard", Vector3.new(-40, 2, 60))

	-- Mom's car (used by client Panic FX)
	local car = part(geo, "MomCar", Vector3.new(10, 6, 18), CFrame.new(40, 3.2, 150), Color3.fromRGB(180, 40, 40))
	local light = Instance.new("SpotLight")
	light.Name = "Headlight"
	light.Brightness = 0
	light.Range = 120
	light.Angle = 60
	light.Face = Enum.NormalId.Front
	light.Parent = car

	map.Parent = workspace
	return map
end

return MapBuilder

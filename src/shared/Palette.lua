--!strict
-- Art-direction palette (see docs/ART_DIRECTION.md). Rule of thumb: the house is soft pastel and
-- low-contrast, chore stations get one saturated accent each, the Baby is the most saturated thing
-- on screen, and red is reserved for PANIC / Mom.
local Palette = {}

-- House shell
Palette.WallCream = Color3.fromRGB(250, 240, 222)
Palette.WallMint = Color3.fromRGB(196, 232, 214)
Palette.WallPeach = Color3.fromRGB(252, 214, 186)
Palette.WallSky = Color3.fromRGB(206, 226, 246)
Palette.Wainscot = Color3.fromRGB(255, 252, 245)
Palette.Trim = Color3.fromRGB(255, 255, 255)
Palette.Baseboard = Color3.fromRGB(120, 86, 62)
Palette.FloorWood = Color3.fromRGB(214, 166, 112)
Palette.FloorWoodDark = Color3.fromRGB(184, 136, 88)
Palette.FloorTile = Color3.fromRGB(236, 240, 244)
Palette.FloorTileAlt = Color3.fromRGB(190, 214, 232)
Palette.Ceiling = Color3.fromRGB(255, 250, 240)
Palette.Roof = Color3.fromRGB(214, 84, 84)
Palette.RoofTrim = Color3.fromRGB(255, 255, 255)
Palette.Siding = Color3.fromRGB(255, 226, 150)
Palette.Door = Color3.fromRGB(88, 152, 220)
Palette.Glass = Color3.fromRGB(190, 230, 255)
Palette.Curtain = Color3.fromRGB(255, 160, 190)

-- Furniture
Palette.WoodLight = Color3.fromRGB(226, 186, 130)
Palette.WoodMid = Color3.fromRGB(176, 122, 74)
Palette.WoodDark = Color3.fromRGB(108, 72, 44)
Palette.CouchBlue = Color3.fromRGB(96, 132, 214)
Palette.CouchBlueDark = Color3.fromRGB(70, 100, 176)
Palette.Cushion = Color3.fromRGB(255, 208, 92)
Palette.Metal = Color3.fromRGB(200, 208, 216)
Palette.MetalDark = Color3.fromRGB(96, 104, 116)
Palette.Screen = Color3.fromRGB(28, 30, 44)
Palette.ScreenGlow = Color3.fromRGB(120, 200, 255)
Palette.Ceramic = Color3.fromRGB(255, 255, 255)
Palette.Leaf = Color3.fromRGB(92, 190, 104)
Palette.LeafDark = Color3.fromRGB(56, 140, 74)
Palette.Terracotta = Color3.fromRGB(216, 120, 80)
Palette.LampShade = Color3.fromRGB(255, 236, 170)
Palette.Bulb = Color3.fromRGB(255, 244, 210)

-- Station accents (one per chore family; keep saturated, never red)
Palette.AccentSleep = Color3.fromRGB(196, 150, 255) -- crib, bed
Palette.AccentToys = Color3.fromRGB(80, 170, 255) -- toy bin
Palette.AccentClean = Color3.fromRGB(255, 130, 170) -- rug, laundry, window
Palette.AccentKitchen = Color3.fromRGB(110, 220, 150) -- sink, microwave, fridge, trash
Palette.AccentUtility = Color3.fromRGB(255, 190, 70) -- fuse box, boiler
Palette.AccentYard = Color3.fromRGB(150, 210, 80) -- lawn, fence

-- Outside
Palette.Grass = Color3.fromRGB(118, 196, 96)
Palette.GrassDark = Color3.fromRGB(88, 160, 78)
Palette.Path = Color3.fromRGB(226, 214, 196)
Palette.Road = Color3.fromRGB(78, 80, 96)
Palette.RoadLine = Color3.fromRGB(255, 220, 90)
Palette.Sidewalk = Color3.fromRGB(196, 196, 204)
Palette.Bark = Color3.fromRGB(122, 84, 56)
Palette.Fence = Color3.fromRGB(255, 255, 255)
Palette.NightSky = Color3.fromRGB(40, 44, 92)

-- Reserved
Palette.Mom = Color3.fromRGB(214, 48, 64) -- Mom's car / headlights / PANIC only
Palette.Baby = Color3.fromRGB(255, 232, 120) -- onesie yellow: the mascot colour

-- Wallpaper stripes per room
Palette.Rooms = {
	LivingRoom = { wall = Palette.WallMint, stripe = Color3.fromRGB(216, 242, 228) },
	Kitchen = { wall = Palette.WallSky, stripe = Color3.fromRGB(226, 238, 250) },
	Nursery = { wall = Palette.WallPeach, stripe = Color3.fromRGB(255, 228, 206) },
}

return Palette

--!strict
-- Procedural Baby rig: chunky toddler built from parts, Motor6D joints (animated client-side in
-- BabyAnimator), and a SurfaceGui face the client drives per mood. Everything scales with `scale`.
local BabyRig = {}

BabyRig.Colors = {
	Skin = Color3.fromRGB(255, 214, 180),
	SkinDark = Color3.fromRGB(235, 180, 145),
	Onesie = Color3.fromRGB(255, 232, 120),
	OnesieTrim = Color3.fromRGB(255, 255, 255),
	Diaper = Color3.fromRGB(250, 250, 250),
	DiaperTab = Color3.fromRGB(80, 170, 255),
	Sock = Color3.fromRGB(80, 170, 255),
	SockSole = Color3.fromRGB(255, 255, 255),
	Dot = Color3.fromRGB(255, 255, 255),
	Outline = Color3.fromRGB(70, 40, 40),
	Hair = Color3.fromRGB(240, 170, 60),
	Paci = Color3.fromRGB(80, 170, 255),
	PaciNub = Color3.fromRGB(255, 240, 200),
	Eye = Color3.fromRGB(255, 255, 255),
	Pupil = Color3.fromRGB(40, 30, 30),
	Brow = Color3.fromRGB(190, 120, 50),
	Mouth = Color3.fromRGB(150, 40, 60),
	Tongue = Color3.fromRGB(255, 120, 140),
	Blush = Color3.fromRGB(255, 130, 150),
	Tear = Color3.fromRGB(120, 190, 255),
}

-- Base (scale 1) dimensions.
BabyRig.Base = {
	torso = Vector3.new(2.4, 2.0, 1.5),
	head = Vector3.new(2.9, 2.6, 2.6),
	arm = Vector3.new(0.9, 1.5, 0.9),
	hand = 0.95,
	leg = Vector3.new(1.0, 1.1, 1.0),
	sock = Vector3.new(1.2, 0.6, 1.5),
	diaper = Vector3.new(2.6, 0.9, 1.7),
}
local B = BabyRig.Base

local function part(name: string, size: Vector3, color: Color3, parent: Instance, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Shape = shape or Enum.PartType.Block
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.Parent = parent
	return p
end

local function weld(a: BasePart, b: BasePart, offset: CFrame)
	b.CFrame = a.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Name = "Weld_" .. b.Name
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function motor(name: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame): Motor6D
	p1.CFrame = p0.CFrame * c0 * c1:Inverse()
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = c0
	m.C1 = c1
	m.Parent = p0
	return m
end

-- Face: a fixed 390x360 canvas stretched over the head's front. Client animates the children.
local function oval(parent: Instance, name: string, size: Vector2, pos: Vector2, color: Color3, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(size.X, size.Y)
	f.Position = UDim2.fromOffset(pos.X, pos.Y)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = z
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
	f.Parent = parent
	return f
end

local function buildFace(head: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Face"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(390, 360)
	gui.LightInfluence = 0.6
	gui.AlwaysOnTop = false
	gui.ClipsDescendants = true
	gui.Adornee = head
	gui.Parent = head

	local C = BabyRig.Colors
	-- Cheeks
	oval(gui, "BlushL", Vector2.new(70, 38), Vector2.new(70, 235), C.Blush, 1).BackgroundTransparency = 0.45
	oval(gui, "BlushR", Vector2.new(70, 38), Vector2.new(320, 235), C.Blush, 1).BackgroundTransparency = 0.45
	-- Eyes (whites), pupils, highlights, lids
	for _, side in { { "L", 120 }, { "R", 270 } } do
		local s, x = side[1] :: string, side[2] :: number
		local eye = oval(gui, "Eye" .. s, Vector2.new(104, 120), Vector2.new(x, 132), C.Eye, 2)
		eye.ClipsDescendants = true
		local pupil = oval(eye, "Pupil", Vector2.new(54, 60), Vector2.new(52, 64), C.Pupil, 3)
		oval(pupil, "Shine", Vector2.new(18, 18), Vector2.new(17, 16), Color3.new(1, 1, 1), 4)
		oval(pupil, "Shine2", Vector2.new(8, 8), Vector2.new(38, 42), Color3.new(1, 1, 1), 4)
		local lid = Instance.new("Frame")
		lid.Name = "Lid"
		lid.AnchorPoint = Vector2.new(0.5, 0)
		lid.Position = UDim2.fromScale(0.5, -0.02)
		lid.Size = UDim2.fromScale(1.1, 0)
		lid.BackgroundColor3 = C.Skin
		lid.BorderSizePixel = 0
		lid.ZIndex = 5
		lid.Parent = eye
		-- Brow
		local brow = Instance.new("Frame")
		brow.Name = "Brow" .. s
		brow.AnchorPoint = Vector2.new(0.5, 0.5)
		brow.Size = UDim2.fromOffset(84, 16)
		brow.Position = UDim2.fromOffset(x, 56)
		brow.BackgroundColor3 = C.Brow
		brow.BorderSizePixel = 0
		brow.ZIndex = 6
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(1, 0)
		bc.Parent = brow
		brow.Parent = gui
		-- Tear (client animates)
		local tear = oval(gui, "Tear" .. s, Vector2.new(22, 34), Vector2.new(x, 200), C.Tear, 7)
		tear.Visible = false
	end
	-- Mouth: ellipse + skin cover (cover top half => smile) + tongue
	local mouth = oval(gui, "Mouth", Vector2.new(120, 60), Vector2.new(195, 268), C.Mouth, 2)
	mouth.ClipsDescendants = true
	local cover = Instance.new("Frame")
	cover.Name = "Cover"
	cover.AnchorPoint = Vector2.new(0.5, 1)
	cover.Position = UDim2.fromScale(0.5, 0.5)
	cover.Size = UDim2.fromScale(1.2, 0.6)
	cover.BackgroundColor3 = C.Skin
	cover.BorderSizePixel = 0
	cover.ZIndex = 3
	cover.Parent = mouth
	local tongue = oval(mouth, "Tongue", Vector2.new(60, 36), Vector2.new(60, 52), C.Tongue, 3)
	tongue.Visible = false
	-- Freckles
	for i, p in { Vector2.new(48, 258), Vector2.new(62, 248), Vector2.new(335, 250), Vector2.new(350, 262) } do
		oval(gui, "Freckle" .. i, Vector2.new(9, 9), p, C.SkinDark, 1)
	end
end

function BabyRig.build(scale: number): Model
	local C = BabyRig.Colors
	local model = Instance.new("Model")
	model.Name = "Baby"

	local root = part("HumanoidRootPart", B.torso * scale, C.Skin, model)
	root.Transparency = 1
	root.CanCollide = true
	root.CanQuery = true
	root.CanTouch = true
	root.Massless = false
	root.CastShadow = false
	-- Every part below is placed relative to the root, so it must sit at its final rest height first
	-- (welds/motors are inert until the model is in Workspace and would not carry the parts along).
	local hipHeight = (B.leg.Y + B.sock.Y - 0.15) * scale
	root.CFrame = CFrame.new(0, hipHeight + root.Size.Y / 2, 0)

	-- Torso (onesie) hangs off the root via a Motor6D so the client can bob/lean the whole body.
	local torso = part("Torso", B.torso * scale, C.Onesie, model)
	motor("RootJoint", root, torso, CFrame.new(), CFrame.new())

	-- Onesie details: collar
	local collar = part("Collar", Vector3.new(B.torso.X * 0.55, 0.22, B.torso.Z * 0.9) * scale, C.OnesieTrim, model)
	weld(torso, collar, CFrame.new(0, B.torso.Y / 2 * scale - 0.11 * scale, 0.06 * scale))

	-- Polka-dot onesie + a duck patch on the tummy (the mascot's signature print)
	for i, d in
		{
			{ -0.7, 0.55, -1 },
			{ 0.75, 0.6, -1 },
			{ -0.85, -0.35, -1 },
			{ 0.85, -0.4, -1 },
			{ -0.5, 0.2, 1 },
			{ 0.6, -0.1, 1 },
			{ 0.05, 0.65, 1 },
			{ -0.1, -0.6, 1 },
		}
	do
		local dot = part("Dot" .. i, Vector3.new(0.06, 0.3, 0.3) * scale, C.Dot, model, Enum.PartType.Cylinder)
		weld(
			torso,
			dot,
			CFrame.new(d[1] * scale, d[2] * scale, d[3] * (B.torso.Z / 2 + 0.02) * scale)
				* CFrame.Angles(0, math.rad(90), 0)
		)
	end
	local patch = part("Patch", Vector3.new(0.9, 0.9, 0.08) * scale, C.OnesieTrim, model)
	weld(torso, patch, CFrame.new(0, 0.25 * scale, -(B.torso.Z / 2 + 0.03) * scale))
	do
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(100, 100)
		gui.LightInfluence = 0.7
		gui.Parent = patch
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		local t = Instance.new("TextLabel")
		t.BackgroundColor3 = C.OnesieTrim
		t.Size = UDim2.fromScale(1, 1)
		t.TextScaled = true
		t.Text = "🦆"
		corner.Parent = t
		t.Parent = gui
	end

	local diaper = part("Diaper", B.diaper * scale, C.Diaper, model)
	weld(torso, diaper, CFrame.new(0, (-B.torso.Y / 2 + B.diaper.Y / 2 - 0.1) * scale, 0))
	for _, sx in { -1, 1 } do
		local tab = part("DiaperTab", Vector3.new(0.3, 0.35, 0.9) * scale, C.DiaperTab, model)
		weld(diaper, tab, CFrame.new(sx * (B.diaper.X / 2 - 0.05) * scale, 0.15 * scale, -0.1 * scale))
	end

	-- Head
	local head = part("Head", B.head * scale, C.Skin, model)
	motor(
		"Neck",
		torso,
		head,
		CFrame.new(0, B.torso.Y / 2 * scale, 0),
		CFrame.new(0, -B.head.Y / 2 * scale + 0.08 * scale, 0)
	)
	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Brightness = 0.35
	glow.Range = math.min(60, 5 * scale)
	glow.Color = Color3.fromRGB(255, 235, 210)
	glow.Shadows = false
	glow.Parent = head
	buildFace(head)

	-- Ears + chubby 3D cheeks (the silhouette read at thumbnail size)
	for _, sx in { -1, 1 } do
		local ear = part(
			if sx < 0 then "EarL" else "EarR",
			Vector3.new(0.6, 0.75, 0.6) * scale,
			C.Skin,
			model,
			Enum.PartType.Ball
		)
		weld(head, ear, CFrame.new(sx * (B.head.X / 2) * scale, -0.1 * scale, 0))
		local cheek = part(
			if sx < 0 then "CheekL" else "CheekR",
			Vector3.new(1.05, 0.9, 0.9) * scale,
			C.Skin,
			model,
			Enum.PartType.Ball
		)
		weld(
			head,
			cheek,
			CFrame.new(
				sx * (B.head.X / 2 - 0.2) * scale,
				-(B.head.Y / 2 - 0.55) * scale,
				-(B.head.Z / 2 - 0.45) * scale
			)
		)
	end
	-- Chin roll
	local chin = part("Chin", Vector3.new(B.head.X * 0.7, 0.5, 0.9) * scale, C.Skin, model, Enum.PartType.Ball)
	weld(head, chin, CFrame.new(0, -(B.head.Y / 2 - 0.05) * scale, -(B.head.Z / 2 - 0.6) * scale))

	-- Hair: single curl (stub + ball) on top-front
	local stub = part("HairStub", Vector3.new(0.28, 0.6, 0.28) * scale, C.Hair, model, Enum.PartType.Cylinder)
	weld(
		head,
		stub,
		CFrame.new(0.1 * scale, (B.head.Y / 2 + 0.25) * scale, -0.2 * scale) * CFrame.Angles(0, 0, math.rad(75))
	)
	local curl = part("HairCurl", Vector3.new(0.55, 0.55, 0.55) * scale, C.Hair, model, Enum.PartType.Ball)
	weld(head, curl, CFrame.new(0.35 * scale, (B.head.Y / 2 + 0.45) * scale, -0.25 * scale))

	-- Pacifier: ring + nub in front of the mouth (client hides it while crying)
	local paciY = -0.6 * scale
	local ring = part("Pacifier", Vector3.new(0.22, 0.9, 0.9) * scale, C.Paci, model, Enum.PartType.Cylinder)
	weld(head, ring, CFrame.new(0, paciY, -(B.head.Z / 2 + 0.12) * scale) * CFrame.Angles(0, math.rad(90), 0))
	local nub = part("PacifierNub", Vector3.new(0.5, 0.5, 0.5) * scale, C.PaciNub, model, Enum.PartType.Ball)
	weld(head, nub, CFrame.new(0, paciY, -(B.head.Z / 2 + 0.35) * scale))

	-- Arms + hands (shoulder pivot at top of arm)
	for _, sx in { -1, 1 } do
		local side = if sx < 0 then "L" else "R"
		local arm = part("Arm" .. side, B.arm * scale, C.Skin, model)
		-- motor first so the arm is at its rest pose before anything is welded onto it
		motor(
			"Shoulder" .. side,
			torso,
			arm,
			CFrame.new(sx * (B.torso.X / 2 + B.arm.X / 2 + 0.02) * scale, (B.torso.Y / 2 - 0.25) * scale, 0),
			CFrame.new(0, (B.arm.Y / 2 - 0.15) * scale, 0)
		)
		local sleeve = part("Sleeve" .. side, Vector3.new(B.arm.X + 0.16, 0.6, B.arm.Z + 0.16) * scale, C.Onesie, model)
		weld(arm, sleeve, CFrame.new(0, (B.arm.Y / 2 - 0.3) * scale, 0))
		local hand =
			part("Hand" .. side, Vector3.new(B.hand, B.hand, B.hand) * scale, C.Skin, model, Enum.PartType.Ball)
		weld(arm, hand, CFrame.new(0, -B.arm.Y / 2 * scale, 0))
	end

	-- Legs + socks (hip pivot at top of leg)
	for _, sx in { -1, 1 } do
		local side = if sx < 0 then "L" else "R"
		local leg = part("Leg" .. side, B.leg * scale, C.Skin, model)
		motor(
			"Hip" .. side,
			torso,
			leg,
			CFrame.new(sx * (B.torso.X / 4 + 0.05) * scale, -B.torso.Y / 2 * scale, 0),
			CFrame.new(0, (B.leg.Y / 2 - 0.1) * scale, 0)
		)
		-- Bootie: blue body, round toe, white sole + strap button
		local sock = part("Sock" .. side, B.sock * scale, C.Sock, model)
		weld(leg, sock, CFrame.new(0, -(B.leg.Y / 2 + B.sock.Y / 2 - 0.05) * scale, -0.15 * scale))
		local toe =
			part("Toe" .. side, Vector3.new(B.sock.X, B.sock.Y, B.sock.Y) * scale, C.Sock, model, Enum.PartType.Ball)
		weld(sock, toe, CFrame.new(0, 0, -(B.sock.Z / 2 - 0.1) * scale))
		local sole = part("Sole" .. side, Vector3.new(B.sock.X + 0.08, 0.14, B.sock.Z + 0.1) * scale, C.SockSole, model)
		weld(sock, sole, CFrame.new(0, -(B.sock.Y / 2 - 0.02) * scale, 0))
		local strap = part("Strap" .. side, Vector3.new(B.sock.X + 0.1, 0.16, 0.3) * scale, C.SockSole, model)
		weld(sock, strap, CFrame.new(0, (B.sock.Y / 2 - 0.05) * scale, 0.1 * scale))
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.HipHeight = hipHeight
	humanoid.MaxHealth = 1e9
	humanoid.Health = 1e9
	humanoid.DisplayName = "BABY"
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.AutoRotate = true
	humanoid.Parent = model

	-- Cartoon outline: keeps the Baby readable against the pastel house and in clips.
	local outline = Instance.new("Highlight")
	outline.Name = "Outline"
	outline.FillTransparency = 1
	outline.OutlineColor = C.Outline
	outline.OutlineTransparency = 0.15
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = model

	model.PrimaryPart = root
	model:SetAttribute("Scale", scale)
	model:SetAttribute("Mood", "Happy")
	model:SetAttribute("Behavior", "Idle")
	model:SetAttribute("Carried", false)
	model:SetAttribute("Say", "")
	model:SetAttribute("SaySeq", 0)
	model:SetAttribute("SayFor", 2.5)
	model:SetAttribute("FxSeq", 0)
	model:SetAttribute("Fx", "")
	return model
end

return BabyRig

--!strict
-- Procedural blocky baby rig (placeholder art). Replace with a real rig later: keep part names + attributes.
local BabyRig = {}

local SKIN = Color3.fromRGB(255, 205, 170)
local DIAPER = Color3.fromRGB(245, 245, 245)
local HAIR = Color3.fromRGB(230, 170, 60)

local function part(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.Parent = parent
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

-- Base (scale 1) dimensions; everything is multiplied by `scale`.
local BASE = {
	torso = Vector3.new(2.2, 2.0, 1.3),
	head = Vector3.new(2.4, 2.2, 2.2),
	limb = Vector3.new(0.8, 1.4, 0.8),
	diaper = Vector3.new(2.4, 0.9, 1.5),
}

function BabyRig.build(scale: number): Model
	local model = Instance.new("Model")
	model.Name = "Baby"

	local root = part("HumanoidRootPart", BASE.torso * scale, SKIN, model)
	root.Transparency = 1
	root.CanCollide = true

	local torso = part("Torso", BASE.torso * scale, SKIN, model)
	torso.CFrame = root.CFrame
	weld(root, torso)

	local diaper = part("Diaper", BASE.diaper * scale, DIAPER, model)
	diaper.CFrame = root.CFrame * CFrame.new(0, -BASE.torso.Y * scale / 2 + BASE.diaper.Y * scale / 2 - 0.05 * scale, 0)
	weld(root, diaper)

	local head = part("Head", BASE.head * scale, SKIN, model)
	head.CFrame = root.CFrame * CFrame.new(0, (BASE.torso.Y / 2 + BASE.head.Y / 2) * scale, 0)
	weld(root, head)

	local hair = part("Hair", Vector3.new(0.5, 0.7, 0.5) * scale, HAIR, model)
	hair.CFrame = head.CFrame
		* CFrame.new(0, BASE.head.Y * scale / 2 + 0.3 * scale, 0)
		* CFrame.Angles(0, 0, math.rad(20))
	weld(head, hair)

	local face = Instance.new("Decal")
	face.Name = "Face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head

	-- Pacifier
	local paci = part("Pacifier", Vector3.new(0.6, 0.6, 0.3) * scale, Color3.fromRGB(80, 170, 255), model)
	paci.Shape = Enum.PartType.Cylinder
	paci.CFrame = head.CFrame
		* CFrame.new(0, -0.5 * scale, -BASE.head.Z * scale / 2 - 0.1 * scale)
		* CFrame.Angles(0, math.rad(90), 0)
	weld(head, paci)

	local limbOffsets: { { name: string, offset: Vector3 } } = {
		{ name = "LeftArm", offset = Vector3.new(-(BASE.torso.X / 2 + BASE.limb.X / 2), 0.2, 0) },
		{ name = "RightArm", offset = Vector3.new(BASE.torso.X / 2 + BASE.limb.X / 2, 0.2, 0) },
		{ name = "LeftLeg", offset = Vector3.new(-BASE.torso.X / 4, -(BASE.torso.Y / 2 + BASE.limb.Y / 2), 0) },
		{ name = "RightLeg", offset = Vector3.new(BASE.torso.X / 4, -(BASE.torso.Y / 2 + BASE.limb.Y / 2), 0) },
	}
	for _, entry in limbOffsets do
		local limb = part(entry.name, BASE.limb * scale, SKIN, model)
		limb.CFrame = root.CFrame * CFrame.new(entry.offset * scale)
		weld(root, limb)
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.HipHeight = (BASE.limb.Y + 0.1) * scale
	humanoid.MaxHealth = 1e9
	humanoid.Health = 1e9
	humanoid.DisplayName = "BABY"
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 200
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model

	-- Speech bubble
	local bb = Instance.new("BillboardGui")
	bb.Name = "Speech"
	bb.Size = UDim2.fromScale(6, 2)
	bb.StudsOffsetWorldSpace = Vector3.new(0, BASE.head.Y * scale / 2 + 2, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = head
	bb.Parent = head
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = ""
	label.Parent = bb

	local cry = Instance.new("Sound")
	cry.Name = "Cry"
	cry.SoundId = "" -- set to a licensed cry loop before publish
	cry.Looped = true
	cry.Volume = 0
	cry.RollOffMaxDistance = 250
	cry.Parent = head

	local giggle = Instance.new("Sound")
	giggle.Name = "Giggle"
	giggle.SoundId = "" -- set to a giggle SFX before publish
	giggle.Volume = 0.6
	giggle.Parent = head

	root.CFrame = CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	model.PrimaryPart = root
	model:SetAttribute("Scale", scale)
	return model
end

function BabyRig.setMoodFace(model: Model, stage: string)
	local head = model:FindFirstChild("Head")
	local face = head and head:FindFirstChild("Face") :: Decal?
	if not face then
		return
	end
	local textures = {
		Happy = "rbxasset://textures/face.png",
		Grumpy = "rbxassetid://20418518", -- placeholders; swap for custom faces
		Fussy = "rbxassetid://8560915",
		Crying = "rbxassetid://20418658",
	}
	face.Texture = textures[stage] or textures.Happy
end

return BabyRig

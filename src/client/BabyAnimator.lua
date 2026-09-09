--!strict
-- Client-side Baby presentation: procedural Motor6D animation (waddle / tantrum / behaviors), animated
-- SurfaceGui face, speech bubble, particles, voice + footstep audio, giant-step camera shake.
-- Driven entirely by replicated state (velocity + model attributes Mood/Behavior/Carried/Say/Fx).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sounds = require(Shared:WaitForChild("Sounds"))
local UI = require(script.Parent.UI)

local BabyAnimator = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local rng = Random.new()

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

type Face = {
	eyeL: Frame,
	eyeR: Frame,
	pupilL: Frame,
	pupilR: Frame,
	lidL: Frame,
	lidR: Frame,
	browL: Frame,
	browR: Frame,
	mouth: Frame,
	cover: Frame,
	tongue: Frame,
	tearL: Frame,
	tearR: Frame,
	blushL: Frame,
	blushR: Frame,
}

type Rig = {
	model: Model,
	root: BasePart,
	torso: BasePart,
	head: BasePart,
	scale: number,
	rootJ: Motor6D,
	neck: Motor6D,
	shL: Motor6D,
	shR: Motor6D,
	hipL: Motor6D,
	hipR: Motor6D,
	face: Face,
	paci: { BasePart },
	socks: { BasePart },
	tears: { ParticleEmitter },
	steam: ParticleEmitter,
	hearts: ParticleEmitter,
	dust: { ParticleEmitter },
	cry: Sound,
	bubble: BillboardGui,
	bubbleFrame: Frame,
	bubbleText: TextLabel,
	-- state
	pose: { [string]: CFrame },
	phase: number,
	lastSin: number,
	t: number,
	behaviorT: number,
	behavior: string,
	mood: string,
	carried: boolean,
	blinkAt: number,
	blinkT: number,
	nextBabble: number,
	mouthSize: Vector2,
	conns: { RBXScriptConnection },
}

local rig: Rig? = nil
local shake = 0

-- Helpers ------------------------------------------------------------------------------------
local function wait(parent: Instance, name: string): Instance
	local inst = parent:WaitForChild(name, 8)
	if not inst then
		error(("BabyAnimator: missing %s in %s"):format(name, parent:GetFullName()))
	end
	return inst
end

local function emitter(parent: Instance, texture: string, color: Color3, size: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new(size)
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.LightEmission = 0.3
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.6, 1.0)
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Parent = parent
	return e
end

local function attachment(part: BasePart, offset: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Position = offset
	a.Parent = part
	return a
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function ang(rx: number, ry: number, rz: number): CFrame
	return CFrame.Angles(rx, ry, rz)
end

-- Speech bubble ---------------------------------------------------------------------------------
local function buildBubble(head: BasePart, scale: number): (BillboardGui, Frame, TextLabel)
	local bb = Instance.new("BillboardGui")
	bb.Name = "BabySpeech"
	bb.Adornee = head
	bb.Size = UDim2.fromOffset(260, 84)
	bb.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y / 2 + 1.0 * scale + 0.5, 0)
	bb.MaxDistance = 220
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Enabled = false
	bb.Parent = player:WaitForChild("PlayerGui")

	local frame = UI.frame(bb, "Bubble", UDim2.new(1, 0, 1, -14), UDim2.new(), Color3.new(1, 1, 1))
	UI.corner(frame, 18)
	UI.stroke(frame, Color3.fromRGB(30, 25, 40), 3)
	UI.padding(frame, 8)
	local text = UI.label(frame, "Text", "", UDim2.fromScale(1, 1), nil, nil, Color3.fromRGB(30, 25, 40))
	text.TextStrokeTransparency = 1
	text.TextWrapped = true
	local tail = UI.frame(bb, "Tail", UDim2.fromOffset(18, 18), UDim2.new(0.5, -9, 1, -22), Color3.new(1, 1, 1))
	tail.Rotation = 45
	UI.stroke(tail, Color3.fromRGB(30, 25, 40), 3)
	tail.ZIndex = 0
	return bb, frame, text
end

-- Setup --------------------------------------------------------------------------------------------
local function teardown()
	local r = rig
	if not r then
		return
	end
	rig = nil
	for _, c in r.conns do
		c:Disconnect()
	end
	r.bubble:Destroy()
	r.cry:Destroy()
end

local function bind(model: Model)
	teardown()
	local scale = (model:GetAttribute("Scale") :: number?) or 2.5
	local root = wait(model, "HumanoidRootPart") :: BasePart
	local torso = wait(model, "Torso") :: BasePart
	local head = wait(model, "Head") :: BasePart
	local gui = wait(head, "Face") :: SurfaceGui
	local function f(name: string): Frame
		return wait(gui, name) :: Frame
	end
	local eyeL, eyeR, mouth = f("EyeL"), f("EyeR"), f("Mouth")
	local face: Face = {
		eyeL = eyeL,
		eyeR = eyeR,
		pupilL = wait(eyeL, "Pupil") :: Frame,
		pupilR = wait(eyeR, "Pupil") :: Frame,
		lidL = wait(eyeL, "Lid") :: Frame,
		lidR = wait(eyeR, "Lid") :: Frame,
		browL = f("BrowL"),
		browR = f("BrowR"),
		mouth = mouth,
		cover = wait(mouth, "Cover") :: Frame,
		tongue = wait(mouth, "Tongue") :: Frame,
		tearL = f("TearL"),
		tearR = f("TearR"),
		blushL = f("BlushL"),
		blushR = f("BlushR"),
	}

	local hz = head.Size.Z / 2
	local tearEmitters = {}
	for _, x in { -0.55, 0.55 } do
		local a = attachment(head, Vector3.new(x * scale, -0.1 * scale, -hz))
		local e = emitter(a, SPARKLE, Color3.fromRGB(120, 190, 255), 0.35 * scale)
		e.Acceleration = Vector3.new(0, -45, 0)
		e.Speed = NumberRange.new(3 * scale, 5 * scale)
		e.SpreadAngle = Vector2.new(20, 20)
		e.Lifetime = NumberRange.new(0.5, 0.8)
		table.insert(tearEmitters, e)
	end
	local topA = attachment(head, Vector3.new(0, head.Size.Y / 2, 0))
	local steam = emitter(topA, SMOKE, Color3.fromRGB(230, 230, 230), 0.8 * scale)
	steam.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5 * scale),
		NumberSequenceKeypoint.new(1, 1.6 * scale),
	})
	steam.Speed = NumberRange.new(2 * scale, 3 * scale)
	steam.Lifetime = NumberRange.new(0.7, 1.1)
	local hearts = emitter(topA, SPARKLE, Color3.fromRGB(255, 120, 170), 0.6 * scale)
	hearts.Speed = NumberRange.new(4 * scale, 7 * scale)
	hearts.SpreadAngle = Vector2.new(60, 60)
	hearts.Lifetime = NumberRange.new(0.8, 1.3)
	hearts.Acceleration = Vector3.new(0, 4, 0)

	local socks = { wait(model, "SockL") :: BasePart, wait(model, "SockR") :: BasePart }
	local dust = {}
	for _, sock in socks do
		local a = attachment(sock, Vector3.new(0, -sock.Size.Y / 2, 0))
		local e = emitter(a, SMOKE, Color3.fromRGB(200, 185, 160), 1.2 * scale)
		e.Speed = NumberRange.new(4, 9)
		e.SpreadAngle = Vector2.new(80, 80)
		e.Lifetime = NumberRange.new(0.4, 0.8)
		table.insert(dust, e)
	end

	local cry = Sounds.loop("Cry", head)
	cry.Volume = 0
	local bubble, bubbleFrame, bubbleText = buildBubble(head, scale)

	local r: Rig = {
		model = model,
		root = root,
		torso = torso,
		head = head,
		scale = scale,
		rootJ = wait(root, "RootJoint") :: Motor6D,
		neck = wait(torso, "Neck") :: Motor6D,
		shL = wait(torso, "ShoulderL") :: Motor6D,
		shR = wait(torso, "ShoulderR") :: Motor6D,
		hipL = wait(torso, "HipL") :: Motor6D,
		hipR = wait(torso, "HipR") :: Motor6D,
		face = face,
		paci = { wait(model, "Pacifier") :: BasePart, wait(model, "PacifierNub") :: BasePart },
		socks = socks,
		tears = tearEmitters,
		steam = steam,
		hearts = hearts,
		dust = dust,
		cry = cry,
		bubble = bubble,
		bubbleFrame = bubbleFrame,
		bubbleText = bubbleText,
		pose = {},
		phase = 0,
		lastSin = 0,
		t = 0,
		behaviorT = 0,
		behavior = (model:GetAttribute("Behavior") :: string?) or "Idle",
		mood = (model:GetAttribute("Mood") :: string?) or "Happy",
		carried = model:GetAttribute("Carried") == true,
		blinkAt = os.clock() + rng:NextNumber(2, 5),
		blinkT = -1,
		nextBabble = os.clock() + rng:NextNumber(4, 9),
		mouthSize = Vector2.new(120, 60),
		conns = {},
	}
	rig = r

	local function onMood()
		local prev = r.mood
		r.mood = (model:GetAttribute("Mood") :: string?) or "Happy"
		if r.mood == prev then
			return
		end
		if r.mood == "Crying" then
			r.cry:Play()
			TweenService:Create(r.cry, TweenInfo.new(0.5), { Volume = 1 }):Play()
			Sounds.play("CryBurst", head)
		else
			if prev == "Crying" then
				TweenService:Create(r.cry, TweenInfo.new(0.6), { Volume = 0 }):Play()
				task.delay(0.6, function()
					if r.mood ~= "Crying" then
						r.cry:Stop()
					end
				end)
			end
			if r.mood == "Grumpy" then
				Sounds.play("Pout", head)
			elseif r.mood == "Fussy" then
				Sounds.play("Whine", head)
			elseif r.mood == "Happy" and prev ~= "Happy" then
				Sounds.play("Giggle", head)
			end
		end
	end
	local function onBehavior()
		r.behavior = (model:GetAttribute("Behavior") :: string?) or "Idle"
		r.behaviorT = 0
	end
	local function onSay()
		local text = (model:GetAttribute("Say") :: string?) or ""
		local seq = model:GetAttribute("SaySeq")
		if text == "" then
			r.bubble.Enabled = false
			return
		end
		r.bubbleText.Text = text
		r.bubble.Enabled = true
		UI.pop(r.bubbleFrame)
		task.delay((model:GetAttribute("SayFor") :: number?) or 2.5, function()
			if rig == r and model:GetAttribute("SaySeq") == seq then
				r.bubble.Enabled = false
			end
		end)
	end
	local function popPacifier()
		local paciModel = Instance.new("Model")
		for _, p in r.paci do
			local c = p:Clone()
			c.CanCollide = true
			c.Massless = false
			c.Parent = paciModel
			for _, w in c:GetChildren() do
				if w:IsA("WeldConstraint") then
					w:Destroy()
				end
			end
		end
		local parts = paciModel:GetChildren()
		if #parts == 2 then
			local w = Instance.new("WeldConstraint")
			w.Part0 = parts[1] :: BasePart
			w.Part1 = parts[2] :: BasePart
			w.Parent = parts[1]
		end
		paciModel.Parent = workspace
		for _, p in parts do
			if p:IsA("BasePart") then
				p.AssemblyLinearVelocity = r.head.CFrame.LookVector * 30 + Vector3.new(0, 25, 0)
				p.AssemblyAngularVelocity = Vector3.new(10, 5, 8)
			end
		end
		Sounds.play("Squeak", r.head)
		task.delay(4, function()
			paciModel:Destroy()
		end)
	end
	local function onFx()
		local name = (model:GetAttribute("Fx") :: string?) or ""
		if name == "soothe" then
			r.hearts:Emit(24)
			Sounds.play("Giggle", head)
			TweenService:Create(face.blushL, TweenInfo.new(0.2), { BackgroundTransparency = 0.1 }):Play()
			TweenService:Create(face.blushR, TweenInfo.new(0.2), { BackgroundTransparency = 0.1 }):Play()
		elseif name == "tantrum" then
			popPacifier()
		elseif name == "smash" then
			Sounds.play("Whoosh", head)
		elseif name == "chew" then
			local s = Sounds.play("Chew", head)
			task.delay(3.5, function()
				s:Destroy()
			end)
		elseif name == "swallow" then
			Sounds.play("Whoosh", head)
			Sounds.play("Squeal", head, 0.7)
		elseif name == "burp" then
			Sounds.play("Burp", head)
		elseif name == "squeal" then
			Sounds.play("Squeal", head)
		elseif name == "snore" then
			Sounds.play("Snore", head)
		elseif name == "gift" then
			Sounds.play("Squeak", head)
			r.hearts:Emit(12)
		-- Power tells + payoffs (see server Baby/Powers.lua)
		elseif name == "tell_hiccup" then
			Sounds.play("Squeak", head, 0.8)
			TweenService:Create(face.blushL, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
			TweenService:Create(face.blushR, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
		elseif name == "hop" then
			Sounds.play("SlideWhistle", head, 0.7)
		elseif name == "slam" then
			Sounds.play("Thud", head)
			Sounds.play("Stomp", head)
			for _, d in r.dust do
				d:Emit(40)
			end
		elseif name == "bonk" then
			Sounds.play("Squeak", head, 0.9)
		elseif name == "tell_zoom" then
			Sounds.play("Squeal", head, 0.6)
		elseif name == "zoom" then
			Sounds.play("Whoosh", head, 1.2)
			Sounds.play("Squeal", head, 0.4)
		elseif name == "stick" then
			Sounds.play("Chew", head, 0.5)
		elseif name == "unstick" then
			Sounds.play("SlideWhistle", head, 0.5)
		elseif name == "tell_loud" then
			Sounds.play("Whine", head)
		elseif name == "scream" then
			Sounds.play("CryBurst", head)
			Sounds.play("GlassBreak", head, 0.5)
			r.tears[1]:Emit(30)
			r.tears[2]:Emit(30)
		elseif name == "bubble" then
			Sounds.play("Ding", head)
			r.hearts:Emit(10)
		elseif name == "soap" then
			Sounds.play("Squeak", head)
			r.steam:Emit(30)
		elseif name == "pacifier" then
			Sounds.play("Squeak", head, 0.8)
			r.hearts:Emit(8)
		end
	end

	table.insert(r.conns, model:GetAttributeChangedSignal("Mood"):Connect(onMood))
	table.insert(r.conns, model:GetAttributeChangedSignal("Behavior"):Connect(onBehavior))
	table.insert(r.conns, model:GetAttributeChangedSignal("SaySeq"):Connect(onSay))
	table.insert(r.conns, model:GetAttributeChangedSignal("FxSeq"):Connect(onFx))
	table.insert(
		r.conns,
		model:GetAttributeChangedSignal("Carried"):Connect(function()
			r.carried = model:GetAttribute("Carried") == true
		end)
	)
	table.insert(
		r.conns,
		model.AncestryChanged:Connect(function(_, parent)
			if parent == nil and rig == r then
				teardown()
			end
		end)
	)
	if r.mood == "Crying" then
		r.cry.Volume = 1
		r.cry:Play()
	end
end

-- Per-frame animation -----------------------------------------------------------------------------------
local function targetPose(r: Rig, dt: number): { [string]: CFrame }
	local s = r.scale
	local t = r.t
	local vel = r.root.AssemblyLinearVelocity
	local hs = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local moving = hs > 0.6 and not r.carried
	local walk = if moving then math.clamp(hs / (4 * s), 0, 1.6) else 0

	-- Walk cycle + footfalls
	if moving then
		r.phase += dt * (hs / s) * 2.4
	end
	local sw = math.sin(r.phase)
	if moving and ((r.lastSin > 0 and sw <= 0) or (r.lastSin < 0 and sw >= 0)) then
		BabyAnimator.footfall(r, if sw <= 0 then 1 else 2)
	end
	r.lastSin = sw

	local P: { [string]: CFrame } = {}
	local breathe = math.sin(t * 2.2) * 0.02 * s
	local bob = if moving then math.abs(math.cos(r.phase)) * 0.10 * s * walk else breathe
	local roll = sw * 0.14 * walk
	local lean = if moving then -0.08 * walk else 0

	P.root = CFrame.new(0, bob, 0) * ang(lean, 0, roll)
	P.neck = ang(math.sin(t * 0.7) * 0.03, 0, math.sin(t * 0.9) * 0.05)
	P.shL = ang(-sw * 0.55 * walk + math.sin(t * 1.5) * 0.05, 0, -0.22 - 0.15 * walk)
	P.shR = ang(sw * 0.55 * walk + math.sin(t * 1.5 + 1) * 0.05, 0, 0.22 + 0.15 * walk)
	P.hipL = ang(sw * 0.7 * walk, 0, -0.05)
	P.hipR = ang(-sw * 0.7 * walk, 0, 0.05)

	local mood, beh = r.mood, r.behavior

	-- Mood layer (only when not overridden by a strong behavior)
	if mood == "Grumpy" then
		P.shL = ang(1.25, 0.5, -0.35)
		P.shR = ang(1.25, -0.5, 0.35)
		P.neck = P.neck * ang(0.14, 0, 0)
	elseif mood == "Fussy" then
		local flap = math.sin(t * 6)
		P.shL = ang(0.3 + flap * 0.15, 0, -0.7 - flap * 0.35)
		P.shR = ang(0.3 - flap * 0.15, 0, 0.7 + flap * 0.35)
		P.neck = P.neck * ang(0.05, math.sin(t * 5) * 0.16, 0)
		if not moving then
			local st = math.sin(t * 7)
			P.hipL = ang(math.max(0, st) * 0.45, 0, -0.05)
			P.hipR = ang(math.max(0, -st) * 0.45, 0, 0.05)
			P.root = CFrame.new(0, math.abs(st) * 0.05 * s, 0)
		end
	elseif mood == "Crying" then
		local fl = math.sin(t * 14)
		P.shL = ang(-2.5 + fl * 0.5, 0, -0.45 - fl * 0.25)
		P.shR = ang(-2.5 - fl * 0.5, 0, 0.45 - fl * 0.25)
		P.neck = ang(-0.4 + math.sin(t * 16) * 0.05, math.sin(t * 9) * 0.1, 0)
		local st = math.sin(t * 10)
		if not moving then
			P.hipL = ang(math.max(0, st) * 0.8, 0, -0.1)
			P.hipR = ang(math.max(0, -st) * 0.8, 0, 0.1)
		end
		P.root = CFrame.new(0, math.abs(st) * 0.12 * s + bob, 0) * ang(-0.1, 0, roll)
	end

	-- Behavior layer
	local bt = r.behaviorT
	if beh == "Destroy" then
		local k = math.clamp(bt / 0.45, 0, 1)
		local slam = if bt < 0.45 then -2.8 * k else 1.1
		P.shL = ang(slam, 0, -0.3)
		P.shR = ang(slam, 0, 0.3)
		P.root = P.root * ang(if bt < 0.45 then -0.1 else 0.35, 0, 0)
		P.neck = ang(if bt < 0.45 then -0.2 else 0.3, 0, 0)
	elseif beh == "Eat" then
		local ch = math.sin(t * 8)
		P.shL = ang(-2.1 + ch * 0.25, 0.9, 0)
		P.shR = ang(-2.1 - ch * 0.25, -0.9, 0)
		P.neck = ang(0.12 + ch * 0.06, 0, 0)
	elseif beh == "Sleepwalk" or beh == "Sleep" then
		P.shL = ang(-1.5, 0, 0)
		P.shR = ang(-1.5, 0, 0)
		P.neck = ang(0.45, math.sin(t * 0.8) * 0.15, 0)
		P.root = P.root * ang(0.1, 0, math.sin(t * 1.2) * 0.08)
	elseif beh == "Yawn" then
		local rub = math.sin(t * 5) * 0.2
		P.shL = ang(-2.4 + rub, 0.5, -0.4)
		P.shR = ang(-2.4 - rub, -0.5, 0.4)
		P.neck = ang(0.35 + math.sin(t * 1.5) * 0.1, 0, math.sin(t * 0.9) * 0.12)
	elseif beh == "Gift" then
		P.shL = ang(-1.4, 0.35, -0.1)
		P.shR = ang(-1.4, -0.35, 0.1)
		P.neck = ang(0.1, 0, 0.25)
	elseif beh == "Swallow" then
		P.neck = ang(-0.55, 0, 0)
		P.shL = ang(-0.6, 0, -1.0)
		P.shR = ang(-0.6, 0, 1.0)
	elseif beh == "Escape" and moving then
		local wave = math.sin(t * 12)
		P.shL = ang(-2.9, 0, -0.5 + wave * 0.35)
		P.shR = ang(-2.9, 0, 0.5 + wave * 0.35)
	elseif beh == "Hiccup" then
		local k = math.clamp(bt / 0.6, 0, 1)
		P.shL = ang(-2.6 * k, 0, -0.6)
		P.shR = ang(-2.6 * k, 0, 0.6)
		P.neck = ang(-0.35 * k, 0, 0)
		P.root = P.root * ang(-0.15 * k, 0, 0)
	elseif beh == "Zoom" then
		P.shL = ang(1.2, 0, -0.2)
		P.shR = ang(1.2, 0, 0.2)
		P.neck = ang(-0.3, 0, 0)
		P.root = P.root * ang(0.35, 0, 0)
	elseif beh == "Scream" then
		local sh = math.sin(t * 30) * 0.06
		P.shL = ang(-2.8, 0, -0.9)
		P.shR = ang(-2.8, 0, 0.9)
		P.neck = ang(-0.5 + sh, sh, 0)
	elseif beh == "Dazed" then
		local wob = math.sin(t * 2.2)
		P.shL = ang(-0.3, 0, -0.9)
		P.shR = ang(-0.3, 0, 0.9)
		P.neck = ang(0.25, wob * 0.5, math.cos(t * 1.7) * 0.3)
		P.root = CFrame.new(0, -0.35 * s, 0) * ang(0.15, 0, wob * 0.12)
	elseif beh == "Bubbled" then
		local fl = math.sin(t * 1.5)
		P.shL = ang(-1.2 + fl * 0.2, 0.3, -0.9)
		P.shR = ang(-1.2 - fl * 0.2, -0.3, 0.9)
		P.hipL = ang(0.8 + fl * 0.2, 0, -0.3)
		P.hipR = ang(0.8 - fl * 0.2, 0, 0.3)
		P.neck = ang(0.1, fl * 0.3, 0)
		P.root = CFrame.new(0, 0.6 * s + fl * 0.2 * s, 0) * ang(0, t * 0.6, 0.1)
	end

	if r.carried then
		local kick = math.sin(t * 8)
		P.root = CFrame.new()
		P.shL = ang(-0.4 + kick * 0.2, 0, -1.3)
		P.shR = ang(-0.4 - kick * 0.2, 0, 1.3)
		P.hipL = ang(0.6 + kick * 0.6, 0, -0.15)
		P.hipR = ang(0.6 - kick * 0.6, 0, 0.15)
		P.neck = ang(-0.1, math.sin(t * 3) * 0.3, 0)
	end

	-- Head look-at (local player) unless behavior/mood locks the neck
	if mood ~= "Crying" and beh ~= "Sleep" and beh ~= "Sleepwalk" and beh ~= "Eat" and beh ~= "Destroy" then
		local char = player.Character
		local targ = char and char:FindFirstChild("Head") :: BasePart?
		if targ then
			local local_ = r.torso.CFrame:PointToObjectSpace(targ.Position)
			local dist = local_.Magnitude
			if dist < 70 * s then
				local horiz = math.sqrt(local_.X ^ 2 + local_.Z ^ 2)
				local yaw = math.clamp(-math.atan2(local_.X, -local_.Z), -1.0, 1.0)
				local pitch = math.clamp(math.atan2(local_.Y - r.torso.Size.Y / 2, horiz), -0.4, 0.5)
				P.neck = P.neck * ang(pitch, yaw, 0)
			end
		end
	end
	return P
end

local function applyPose(r: Rig, P: { [string]: CFrame }, dt: number)
	local alpha = 1 - math.exp(-dt * 12)
	local joints: { [string]: Motor6D } = {
		root = r.rootJ,
		neck = r.neck,
		shL = r.shL,
		shR = r.shR,
		hipL = r.hipL,
		hipR = r.hipR,
	}
	for key, joint in joints do
		local cur = r.pose[key] or CFrame.new()
		local nxt = cur:Lerp(P[key] or CFrame.new(), alpha)
		r.pose[key] = nxt
		joint.Transform = nxt
	end
end

local function animateFace(r: Rig, dt: number)
	local F = r.face
	local t = r.t
	local mood, beh = r.mood, r.behavior
	local now = os.clock()

	-- Blink
	local lid = 0
	if now >= r.blinkAt then
		r.blinkT = 0
		r.blinkAt = now + rng:NextNumber(2, 5.5)
	end
	if r.blinkT >= 0 then
		r.blinkT += dt
		lid = math.sin(math.clamp(r.blinkT / 0.16, 0, 1) * math.pi)
		if r.blinkT > 0.16 then
			r.blinkT = -1
		end
	end
	local base = if beh == "Sleep" or beh == "Sleepwalk"
		then 1
		elseif mood == "Crying" then 0.4
		elseif mood == "Fussy" then 0.18
		elseif mood == "Grumpy" then 0.3
		else 0
	lid = math.max(lid, base)
	F.lidL.Size = UDim2.fromScale(1.1, lid * 1.05)
	F.lidR.Size = UDim2.fromScale(1.1, lid * 1.05)

	-- Pupils track local player
	local px, py = 0, 0
	local char = player.Character
	local targ = char and char:FindFirstChild("Head") :: BasePart?
	if targ and mood ~= "Crying" then
		local l = r.head.CFrame:PointToObjectSpace(targ.Position)
		local horiz = math.max(1, math.sqrt(l.X ^ 2 + l.Z ^ 2))
		px = math.clamp(-l.X / horiz, -1, 1) * 18
		py = math.clamp(-l.Y / horiz, -1, 1) * 14
	end
	if mood == "Crying" then
		px, py = math.sin(t * 20) * 4, 10
	end
	F.pupilL.Position = UDim2.fromOffset(48 + px, 60 + py)
	F.pupilR.Position = UDim2.fromOffset(48 + px, 60 + py)

	-- Brows
	local browY, browRot = 56, 0
	if mood == "Grumpy" then
		browY, browRot = 72, 22
	elseif mood == "Fussy" then
		browY, browRot = 50, -16 + math.sin(t * 5) * 4
	elseif mood == "Crying" then
		browY, browRot = 60, -28 + math.sin(t * 14) * 5
	end
	F.browL.Position = UDim2.fromOffset(120, browY)
	F.browR.Position = UDim2.fromOffset(270, browY)
	F.browL.Rotation = browRot
	F.browR.Rotation = -browRot

	-- Mouth
	local target = Vector2.new(120, 60)
	local coverVisible, frown, tongue = true, false, false
	if mood == "Grumpy" then
		target = Vector2.new(96, 44)
		frown = true
	elseif mood == "Fussy" then
		target = Vector2.new(46 + math.sin(t * 6) * 4, 52)
		coverVisible = false
	elseif mood == "Crying" then
		target = Vector2.new(140 + math.sin(t * 12) * 10, 130 + math.sin(t * 12) * 12)
		coverVisible = false
		tongue = true
	end
	if beh == "Eat" then
		target = Vector2.new(80, 30 + math.abs(math.sin(t * 8)) * 40)
		coverVisible = false
	elseif beh == "Swallow" then
		target = Vector2.new(210, 180)
		coverVisible = false
		tongue = true
	elseif beh == "Sleep" or beh == "Sleepwalk" then
		target = Vector2.new(50, 18)
		coverVisible = false
	end
	r.mouthSize = r.mouthSize:Lerp(target, 1 - math.exp(-dt * 14))
	F.mouth.Size = UDim2.fromOffset(r.mouthSize.X, r.mouthSize.Y)
	F.mouth.Position = UDim2.fromOffset(195, if mood == "Crying" then 250 else 268)
	F.cover.Visible = coverVisible
	if frown then
		F.cover.AnchorPoint = Vector2.new(0.5, 0)
	else
		F.cover.AnchorPoint = Vector2.new(0.5, 1)
	end
	F.tongue.Visible = tongue

	-- Tears (2D + 3D), blush, steam, pacifier
	local crying = mood == "Crying"
	for i, tear in { F.tearL, F.tearR } do
		tear.Visible = crying
		if crying then
			local k = (t * 1.6 + i * 0.5) % 1
			tear.Position = UDim2.fromOffset(if i == 1 then 100 else 290, 185 + k * 150)
			tear.BackgroundTransparency = k * 0.6
		end
	end
	for _, e in r.tears do
		e.Rate = if crying then 12 else 0
	end
	r.steam.Rate = if mood == "Grumpy" then 3 elseif mood == "Fussy" then 7 else 0
	r.steam.Color =
		ColorSequence.new(if mood == "Fussy" then Color3.fromRGB(255, 120, 120) else Color3.fromRGB(230, 230, 230))
	r.hearts.Rate = if mood == "Happy" and beh ~= "Sleep" then 0.6 else 0
	local blushTarget = if mood == "Happy" then 0.45 else 0.85
	local bl = F.blushL.BackgroundTransparency
	if math.abs(bl - blushTarget) > 0.01 then
		bl = lerp(bl, blushTarget, 1 - math.exp(-dt * 2))
		F.blushL.BackgroundTransparency = bl
		F.blushR.BackgroundTransparency = bl
	end
	local paciHidden = crying or beh == "Eat" or beh == "Swallow"
	for _, p in r.paci do
		p.Transparency = if paciHidden then 1 else 0
	end

	-- Idle babble
	if mood == "Happy" and not crying and beh ~= "Sleep" and beh ~= "Sleepwalk" and now >= r.nextBabble then
		r.nextBabble = now + rng:NextNumber(7, 14)
		Sounds.play("Babble", r.head, 0.8)
	end
end

function BabyAnimator.footfall(r: Rig, side: number)
	local s = r.scale
	local sock = r.socks[side]
	local vol = math.clamp((s - 1.5) / 9, 0.12, 1)
	Sounds.play("Stomp", sock, vol)
	if s >= 4 then
		r.dust[side]:Emit(math.floor(3 + s * 0.6))
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		local dist = (hrp.Position - sock.Position).Magnitude
		local mag = math.clamp((s - 3) / 11, 0, 1) * math.clamp(1 - dist / (60 + s * 6), 0, 1)
		shake = math.min(1.2, shake + mag * 0.9)
	end
end

RunService.Stepped:Connect(function(_, dt)
	local r = rig
	if not r or not r.model.Parent then
		return
	end
	r.t += dt
	r.behaviorT += dt
	local P = targetPose(r, dt)
	applyPose(r, P, dt)
	animateFace(r, dt)
end)

-- Runs after the default camera scripts so the offset is not overwritten.
RunService:BindToRenderStep("BabyShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shake > 0.001 then
		if camera.CameraType == Enum.CameraType.Custom then
			local m = shake * 0.6
			camera.CFrame = camera.CFrame
				* CFrame.new(rng:NextNumber(-m, m), rng:NextNumber(-m, m), 0)
				* CFrame.Angles(0, 0, rng:NextNumber(-m, m) * 0.02)
		end
		shake *= math.exp(-dt * 7)
	end
end)

-- Prop crash sounds (Baby knocks props -> server flips the Knocked attribute)
local function watchProp(prop: Instance)
	if not prop:IsA("BasePart") then
		return
	end
	prop:GetAttributeChangedSignal("Knocked"):Connect(function()
		if prop:GetAttribute("Knocked") then
			local n = prop.Name
			if n == "Vase" or n == "Lamp" or n == "Plate" or n:find("Glass") then
				Sounds.play("GlassBreak", prop)
			else
				Sounds.play("WoodCrash", prop)
			end
		end
	end)
end
task.spawn(function()
	local map = workspace:WaitForChild("Map", 30)
	local props = map and map:WaitForChild("Props", 30)
	if props then
		for _, p in props:GetChildren() do
			watchProp(p)
		end
		props.ChildAdded:Connect(watchProp)
	end
end)

-- Bind whenever a Baby appears
local function tryBind(inst: Instance)
	if inst.Name == "Baby" and inst:IsA("Model") then
		task.spawn(function()
			local ok, err = pcall(bind, inst)
			if not ok then
				warn(err)
			end
		end)
	end
end
workspace.ChildAdded:Connect(tryBind)
for _, c in workspace:GetChildren() do
	tryBind(c)
end

return BabyAnimator

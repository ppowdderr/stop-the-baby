--!strict
-- Mom leaves / Mom check / birthday cutscenes, Panic headlights + camera shake, clip-moment flash.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local UI = require(script.Parent.UI)

local Cutscenes = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local screen = UI.screen("Cutscenes", 5)

-- Letterbox + subtitle
local topBar = UI.frame(screen, "TopBar", UDim2.new(1, 0, 0, 0), UDim2.new(), Color3.new(0, 0, 0))
local botBar = UI.frame(screen, "BotBar", UDim2.new(1, 0, 0, 0), UDim2.new(0, 0, 1, 0), Color3.new(0, 0, 0))
botBar.AnchorPoint = Vector2.new(0, 1)
local subtitle = UI.label(screen, "Subtitle", "", UDim2.new(0.8, 0, 0, 60), UDim2.new(0.1, 0, 1, -140), 26)
subtitle.TextWrapped = true
subtitle.Visible = false
local speaker =
	UI.label(screen, "Speaker", "", UDim2.new(0.8, 0, 0, 30), UDim2.new(0.1, 0, 1, -170), 20, UI.Colors.Accent)
speaker.Visible = false

-- Clip flash
local clipFlash =
	UI.frame(screen, "Clip", UDim2.fromOffset(220, 48), UDim2.new(1, -240, 1, -160), Color3.fromRGB(200, 30, 60))
clipFlash.Visible = false
UI.corner(clipFlash, 12)
UI.stroke(clipFlash, Color3.new(1, 1, 1), 2)
UI.label(clipFlash, "Text", "🎬 CLIP THAT!", UDim2.fromScale(1, 1), nil, 22)

local clipNames: { [string]: string } = {
	baby_cry = "🎬 CLIP THAT! (WAAAH)",
	baby_swallow = "🎬 CLIP THAT! (SWALLOWED)",
	panic_mode = "🎬 CLIP THAT! (PANIC MODE)",
	baby_escape = "🎬 CLIP THAT! (ESCAPE)",
	baby_gift = "🎬 CLIP THAT! (RARE GIFT)",
	mom_fail = "🎬 CLIP THAT! (MOM'S HOME)",
	fridge_raid = "🎬 CLIP THAT! (FRIDGE)",
	baby_carry = "🎬 CLIP THAT! (LIFT)",
	baby_mess = "🎬 CLIP THAT! (CHAOS)",
}

Net.event("ClipMoment").OnClientEvent:Connect(function(id: string)
	(clipFlash:FindFirstChild("Text") :: TextLabel).Text = clipNames[id] or "🎬 CLIP THAT!"
	clipFlash.Visible = true
	UI.pop(clipFlash)
	task.delay(3, function()
		clipFlash.Visible = false
	end)
end)

local function letterbox(on: boolean)
	local h = if on then 70 else 0
	UI.tween(topBar, { Size = UDim2.new(1, 0, 0, h) }, 0.4)
	UI.tween(botBar, { Size = UDim2.new(1, 0, 0, h) }, 0.4)
end

local function say(who: string, text: string, seconds: number)
	speaker.Text = who
	subtitle.Text = text
	speaker.Visible = true
	subtitle.Visible = true
	task.wait(seconds)
	speaker.Visible = false
	subtitle.Visible = false
end

local function momCar(): BasePart?
	local map = workspace:FindFirstChild("Map")
	local geo = map and map:FindFirstChild("Geometry")
	local car = geo and geo:FindFirstChild("MomCar")
	return if car and car:IsA("BasePart") then car else nil
end

local function focusCamera(cf: CFrame, seconds: number)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = cf
	task.wait(seconds)
	camera.CameraType = Enum.CameraType.Custom
end

local function babyCF(): CFrame
	local baby = workspace:FindFirstChild("Baby")
	local head = baby and baby:FindFirstChild("Head") :: BasePart?
	if head then
		return CFrame.lookAt(head.Position + Vector3.new(14, 6, 18), head.Position)
	end
	return CFrame.new(0, 20, 60, 1, 0, 0, 0, 1, 0, 0, 0, 1)
end

-- Cutscenes ------------------------------------------------------------------------------
local handlers: { [string]: (data: any) -> () } = {}

handlers.mom_leaves = function(data)
	letterbox(true)
	local car = momCar()
	if car then
		task.spawn(focusCamera, CFrame.lookAt(car.Position + Vector3.new(-25, 8, -20), car.Position), 5)
	end
	say("MOM", data.line or "Be good.", 4)
	task.spawn(focusCamera, babyCF(), 3)
	say("BABY", "hehe.", 2.5)
	letterbox(false)
end

handlers.mom_check_pass = function(data)
	letterbox(true)
	task.spawn(focusCamera, babyCF(), 5)
	say("MOM", "...Baby's asleep? Nothing's broken?", 2.5)
	say(
		"MOM",
		if (data.damage or 0) > 0
			then ("...why is the %s on the floor. Whatever. Good job."):format("lamp")
			else "Wow. Okay. Good job, babysitters.",
		3
	)
	letterbox(false)
end

handlers.mom_check_fail = function(data)
	letterbox(true)
	local car = momCar()
	if car then
		local light = car:FindFirstChild("Headlight") :: SpotLight?
		if light then
			light.Brightness = 20
		end
		task.spawn(focusCamera, CFrame.lookAt(Vector3.new(0, 12, 55), car.Position), 3)
		Sounds.play("DoorSlam", car)
	end
	say("MOM", "I'm home—", 1.2)
	task.spawn(focusCamera, babyCF(), 4)
	if data.reason == "crying" then
		say("MOM", "WHY IS THE BABY CRYING.", 2.5)
	else
		say("MOM", "What did you DO to my house.", 2.5)
	end
	say("MOM", "You. Are. All. GROUNDED.", 2.5)
	letterbox(false)
	local car2 = momCar()
	local light = car2 and car2:FindFirstChild("Headlight") :: SpotLight?
	if light then
		light.Brightness = 0
	end
end

handlers.birthday_finale = function()
	letterbox(true)
	task.spawn(focusCamera, babyCF(), 10)
	say("EVERYONE", "🎂 HAPPY BIRTHDAY, BABY! 🎂", 4)
	say("BABY", "...mama?", 3)
	say("MOM", "You did it. 99 nights. I'm... impressed. Now go home.", 3)
	letterbox(false)
end

Net.event("Cutscene").OnClientEvent:Connect(function(id: string, data)
	local h = handlers[id]
	if h then
		task.spawn(h, data or {})
	end
end)

-- Panic FX: headlights sweep + camera shake + red ambient ----------------------------------------
local panicActive = false
local baseAmbient = Lighting.OutdoorAmbient
Net.event("Panic").OnClientEvent:Connect(function(active: boolean)
	panicActive = active
	local car = momCar()
	local light = car and car:FindFirstChild("Headlight") :: SpotLight?
	if light then
		light.Brightness = if active then 30 else 0
	end
	TweenService:Create(
		Lighting,
		TweenInfo.new(0.6),
		{ OutdoorAmbient = if active then Color3.fromRGB(140, 40, 50) else baseAmbient }
	):Play()
	if car then
		if active then
			Sounds.play("CarHorn", car)
		end
		local target = if active then CFrame.new(40, 3.2, 95) else CFrame.new(40, 3.2, 150)
		TweenService:Create(car, TweenInfo.new(if active then 3 else 1), { CFrame = target }):Play()
	end
end)

RunService.RenderStepped:Connect(function()
	if panicActive and camera.CameraType == Enum.CameraType.Custom then
		local shake = 0.25
		camera.CFrame = camera.CFrame
			* CFrame.new(math.random() * shake - shake / 2, math.random() * shake - shake / 2, 0)
	end
end)

-- Reset camera when character respawns (in case a cutscene was interrupted)
player.CharacterAdded:Connect(function()
	camera.CameraType = Enum.CameraType.Custom
end)

return Cutscenes

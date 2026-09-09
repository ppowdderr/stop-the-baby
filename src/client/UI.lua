--!strict
-- Tiny declarative UI helpers so all UI is code (no .rbxm assets needed).
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UI = {}

UI.Font = Enum.Font.FredokaOne
UI.Touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
UI.Colors = {
	Panel = Color3.fromRGB(40, 36, 60),
	PanelLight = Color3.fromRGB(62, 56, 92),
	Accent = Color3.fromRGB(255, 120, 170),
	Yellow = Color3.fromRGB(255, 210, 80),
	Green = Color3.fromRGB(110, 220, 120),
	Red = Color3.fromRGB(240, 80, 80),
	Blue = Color3.fromRGB(90, 170, 255),
	Text = Color3.fromRGB(255, 255, 255),
	Sub = Color3.fromRGB(200, 200, 220),
}

function UI.corner(inst: GuiObject, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = inst
	return c
end

function UI.stroke(inst: GuiObject, color: Color3?, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.new(0, 0, 0)
	s.Thickness = thickness or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

function UI.padding(inst: GuiObject, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = inst
	return p
end

function UI.list(inst: GuiObject, dir: Enum.FillDirection?, pad: number?, align: Enum.HorizontalAlignment?)
	local l = Instance.new("UIListLayout")
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, pad or 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.HorizontalAlignment = align or Enum.HorizontalAlignment.Left
	l.Parent = inst
	return l
end

function UI.frame(
	parent: Instance,
	name: string,
	size: UDim2,
	pos: UDim2?,
	color: Color3?,
	transparency: number?
): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos or UDim2.new()
	f.BackgroundColor3 = color or UI.Colors.Panel
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

function UI.label(
	parent: Instance,
	name: string,
	text: string,
	size: UDim2,
	pos: UDim2?,
	textSize: number?,
	color: Color3?
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = text
	l.Size = size
	l.Position = pos or UDim2.new()
	l.BackgroundTransparency = 1
	l.Font = UI.Font
	l.TextColor3 = color or UI.Colors.Text
	l.TextStrokeTransparency = 0.5
	if textSize then
		l.TextSize = textSize
	else
		l.TextScaled = true
	end
	l.Parent = parent
	return l
end

function UI.button(parent: Instance, name: string, text: string, size: UDim2, pos: UDim2?, color: Color3?): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Size = size
	b.Position = pos or UDim2.new()
	b.BackgroundColor3 = color or UI.Colors.Accent
	b.Font = UI.Font
	b.TextColor3 = UI.Colors.Text
	b.TextScaled = true
	b.TextStrokeTransparency = 0.5
	b.AutoButtonColor = true
	b.BorderSizePixel = 0
	b.Parent = parent
	UI.corner(b, 10)
	UI.stroke(b, Color3.new(0, 0, 0), 2)
	if not UI.Touch then
		b.MouseEnter:Connect(function()
			TweenService:Create(b, TweenInfo.new(0.1), { Size = size + UDim2.fromOffset(4, 4) }):Play()
		end)
		b.MouseLeave:Connect(function()
			TweenService:Create(b, TweenInfo.new(0.1), { Size = size }):Play()
		end)
	end
	return b
end

function UI.bar(parent: Instance, name: string, size: UDim2, pos: UDim2, color: Color3): (Frame, Frame)
	local bg = UI.frame(parent, name, size, pos, Color3.fromRGB(20, 20, 30))
	UI.corner(bg, 8)
	UI.stroke(bg)
	local fill = UI.frame(bg, "Fill", UDim2.fromScale(1, 1), UDim2.new(), color)
	UI.corner(fill, 8)
	return bg, fill
end

function UI.tween(inst: Instance, props: { [string]: any }, t: number?, style: Enum.EasingStyle?)
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(t or 0.25, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

function UI.pop(inst: GuiObject)
	local target = inst.Size
	inst.Size = UDim2.new(target.X.Scale * 0.6, target.X.Offset * 0.6, target.Y.Scale * 0.6, target.Y.Offset * 0.6)
	TweenService:Create(inst, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = target })
		:Play()
end

-- Layouts are authored for a ~1280x720 desktop viewport; a per-screen UIScale shrinks them on
-- phones/tablets (never below MIN_SCALE so text and tap targets stay legible).
local REF_W, REF_H, MIN_SCALE = 1280, 720, 0.62

function UI.viewportScale(): number
	local cam = workspace.CurrentCamera
	local v = if cam then cam.ViewportSize else Vector2.new(REF_W, REF_H)
	return math.clamp(math.min(v.X / REF_W, v.Y / REF_H), MIN_SCALE, 1)
end

local scalers: { UIScale } = {}
local function refreshScale()
	local s = UI.viewportScale()
	for _, u in scalers do
		u.Scale = s
	end
end

function UI.screen(name: string, order: number?): ScreenGui
	local sg = Instance.new("ScreenGui")
	sg.Name = name
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder = order or 0
	local scale = Instance.new("UIScale")
	scale.Scale = UI.viewportScale()
	scale.Parent = sg
	table.insert(scalers, scale)
	sg.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	return sg
end

do
	local function watch(cam: Camera?)
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScale)
			refreshScale()
		end
	end
	watch(workspace.CurrentCamera)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		watch(workspace.CurrentCamera)
	end)
end

return UI

--!strict
-- Client bootstrap.
local StarterGui = game:GetService("StarterGui")

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

require(script.HUD)
require(script.Music)
require(script.Inventory)
require(script.Interaction)
require(script.Cutscenes)
require(script.BabyAnimator)
require(script.Tutorial)

print("[StopTheBaby] client ready")

--!strict
-- Client bootstrap.
local StarterGui = game:GetService("StarterGui")

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

require(script.HUD)
require(script.Inventory)
require(script.Interaction)
require(script.Cutscenes)

print("[StopTheBaby] client ready")

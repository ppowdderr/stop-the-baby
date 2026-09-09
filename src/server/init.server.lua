--!strict
-- Server bootstrap. Order matters: remotes -> data -> economy -> inventory -> map -> round loop.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local DataService = require(script.Services.DataService)
local EconomyService = require(script.Services.EconomyService)
local InventoryService = require(script.Services.InventoryService)
local GearService = require(script.Services.GearService)
local RoundService = require(script.Services.RoundService)
local MapBuilder = require(script.World.MapBuilder)

Net.event("RoundState") -- forces remote folder creation before any client asks

MapBuilder.build()
DataService.start()
EconomyService.start()
InventoryService.start()
GearService.start()
RoundService.start()

Players.PlayerRemoving:Connect(Net.clearPlayer)

print("[StopTheBaby] server ready")

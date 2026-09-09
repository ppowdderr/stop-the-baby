--!strict
-- Music director: one bed at a time (lobby playlist / night loop / panic chase), crossfaded on
-- round-state changes; night intensity follows the Baby's mood; results play a win/fail sting.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Sounds = require(Shared.Sounds)

local FADE_OUT = 0.9
local FADE_IN = 1.4
local PLAYLIST_GAP = 1.5

local group = Instance.new("SoundGroup")
group.Name = "Music"
group.Volume = 1
group.Parent = SoundService

type Track = { sound: Sound, key: string, base: number, playlist: boolean, gen: number }

local current: Track? = nil
local generation = 0
local intensity = 1 -- 0.7..1.15 multiplier applied on top of the catalog volume

local moodIntensity: { [string]: { volume: number, speed: number } } = {
	Happy = { volume = 0.75, speed = 1.0 },
	Grumpy = { volume = 0.9, speed = 1.0 },
	Fussy = { volume = 1.0, speed = 1.04 },
	Crying = { volume = 1.15, speed = 1.08 },
}

local function fadeOut(track: Track)
	local s = track.sound
	local tw = TweenService:Create(s, TweenInfo.new(FADE_OUT, Enum.EasingStyle.Sine), { Volume = 0 })
	tw:Play()
	tw.Completed:Once(function()
		s:Destroy()
	end)
end

local function startPlaylist(track: Track)
	local def = Sounds.Catalog[track.key]
	local lastId = ""
	local function next()
		if track.gen ~= generation then
			return
		end
		local id = "rbxassetid://" .. tostring(def.ids[math.random(1, #def.ids)])
		if #def.ids > 1 and id == lastId then
			next()
			return
		end
		lastId = id
		local s = track.sound
		s.SoundId = id
		s.Volume = 0
		s:Play()
		TweenService:Create(s, TweenInfo.new(FADE_IN, Enum.EasingStyle.Sine), { Volume = track.base * intensity })
			:Play()
	end
	track.sound.Ended:Connect(function()
		task.delay(PLAYLIST_GAP, next)
	end)
	next()
end

local function play(key: string?)
	if current and current.key == key then
		return
	end
	generation += 1
	if current then
		fadeOut(current)
		current = nil
	end
	if not key then
		return
	end
	local def = Sounds.Catalog[key]
	local s = Instance.new("Sound")
	s.Name = key
	s.SoundGroup = group
	s.Looped = def.looped == true
	s.Parent = SoundService
	local track: Track = { sound = s, key = key, base = def.volume, playlist = not s.Looped, gen = generation }
	current = track
	if track.playlist then
		startPlaylist(track)
	else
		s.SoundId = "rbxassetid://" .. tostring(def.ids[math.random(1, #def.ids)])
		s.Volume = 0
		s:Play()
		TweenService:Create(s, TweenInfo.new(FADE_IN, Enum.EasingStyle.Sine), { Volume = track.base * intensity })
			:Play()
	end
end

local function applyIntensity(volumeMul: number, speed: number)
	intensity = volumeMul
	local track = current
	if not track or track.key ~= "MusicNight" then
		return
	end
	TweenService:Create(track.sound, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {
		Volume = track.base * intensity,
		PlaybackSpeed = speed,
	}):Play()
end

local function sting(key: string)
	local s = Sounds.play(key, SoundService)
	s.SoundGroup = group
end

Net.event("RoundState").OnClientEvent:Connect(function(state: string, payload)
	if state == "Lobby" then
		intensity = 1
		play("MusicLobby")
	elseif state == "Briefing" then
		intensity = 0.6
		play("MusicNight")
	elseif state == "Night" then
		play("MusicNight")
	elseif state == "Panic" then
		play("MusicPanic")
	elseif state == "MomCheck" then
		play(nil)
	elseif state == "Results" then
		play(nil)
		sting(if payload and payload.success then "MusicWin" else "MusicFail")
	end
end)

Net.event("Panic").OnClientEvent:Connect(function(active: boolean)
	if active then
		play("MusicPanic")
	elseif current and current.key == "MusicPanic" then
		play("MusicNight")
	end
end)

Net.event("BabyMood").OnClientEvent:Connect(function(_stageIndex: number, stageName: string)
	local m = moodIntensity[stageName]
	if m then
		applyIntensity(m.volume, m.speed)
	end
end)

return {}

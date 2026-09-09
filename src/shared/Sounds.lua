--!strict
-- Sound catalog. All ids are free "Pro Sound Effects" library assets distributed by Roblox
-- (creator ProSoundEffects, id 7462895450), usable in any experience. Swap for custom audio anytime.
local Sounds = {}

export type Def = { ids: { number }, volume: number, pitch: { number }?, looped: boolean?, maxDist: number? }

export type Key = string

Sounds.Catalog = {
	-- Baby voice
	Cry = { ids = { 9113234666 }, volume = 1.0, looped = true, maxDist = 300 },
	CryBurst = { ids = { 9113234662, 9113234654 }, volume = 0.9, maxDist = 250 },
	Whine = { ids = { 9113234847, 9113234304 }, volume = 0.8, maxDist = 200 },
	Pout = { ids = { 9113240389, 9113240365, 9113240372, 9113240534, 9113240546 }, volume = 0.8, maxDist = 200 },
	Giggle = { ids = { 9125368273, 9125368281, 9125368444, 9125367935, 9125368121 }, volume = 0.9, maxDist = 200 },
	Babble = { ids = { 9113238454, 9113238539, 9113238692, 9113238455 }, volume = 0.7, maxDist = 150 },
	Squeal = { ids = { 9125368661 }, volume = 0.9, maxDist = 250 },
	Burp = { ids = { 9120003161, 9120003207 }, volume = 0.9, pitch = { 1.2, 1.5 }, maxDist = 200 },
	Chew = { ids = { 9113138415 }, volume = 0.7, pitch = { 1.1, 1.3 }, maxDist = 120 },
	Snore = { ids = { 9113861808 }, volume = 0.7, pitch = { 1.3, 1.5 }, maxDist = 120 },
	-- Baby body
	Stomp = { ids = { 9114080709, 9114078861, 9114079130 }, volume = 0.6, pitch = { 0.9, 1.15 }, maxDist = 300 },
	Thud = { ids = { 9113480915, 9113481039 }, volume = 0.8, maxDist = 150 },
	Whoosh = { ids = { 9114158497 }, volume = 0.6, pitch = { 0.9, 1.2 }, maxDist = 150 },
	-- House
	GlassBreak = { ids = { 9114590297 }, volume = 0.8, maxDist = 200 },
	WoodCrash = { ids = { 9113768847, 9113769197, 9113481218 }, volume = 0.8, maxDist = 200 },
	DoorSlam = { ids = { 9114153270, 9114153397 }, volume = 0.9, maxDist = 300 },
	Vacuum = { ids = { 9120360676 }, volume = 0.35, looped = true, maxDist = 80 },
	Dishes = { ids = { 9117657689, 9117656325 }, volume = 0.5, maxDist = 80 },
	Squeak = { ids = { 9120222027, 9120222115 }, volume = 0.7, pitch = { 0.9, 1.3 }, maxDist = 120 },
	-- Mom
	CarHorn = { ids = { 9114402205, 9114402335, 9114402340 }, volume = 1.0, maxDist = 600 },
	-- UI (2D)
	Ding = { ids = { 9126073001 }, volume = 0.6, pitch = { 0.95, 1.1 } },
	SlideWhistle = { ids = { 9119197913 }, volume = 0.6 },
	RecordScratch = { ids = { 9118086936, 9118088194 }, volume = 0.7 },
	DeskBell = { ids = { 9125485591 }, volume = 0.6 },
	MusicBox = { ids = { 9117044359 }, volume = 0.18, looped = true },
} :: { [Key]: Def }

local rng = Random.new()

local function configure(sound: Sound, def: Def, volumeMul: number?)
	sound.SoundId = "rbxassetid://" .. tostring(def.ids[rng:NextInteger(1, #def.ids)])
	sound.Volume = def.volume * (volumeMul or 1)
	sound.Looped = def.looped == true
	local pitch = def.pitch
	sound.PlaybackSpeed = if pitch then rng:NextNumber(pitch[1], pitch[2]) else 1
	if def.maxDist then
		sound.RollOffMaxDistance = def.maxDist
		sound.RollOffMinDistance = 10
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
	end
end

-- Fire-and-forget one-shot. `parent` = a BasePart for 3D audio, or SoundService/nil for 2D.
function Sounds.play(key: Key, parent: Instance?, volumeMul: number?): Sound
	local def = assert(Sounds.Catalog[key], "unknown sound " .. key)
	local s = Instance.new("Sound")
	s.Name = key
	configure(s, def, volumeMul)
	s.Parent = parent or game:GetService("SoundService")
	s:Play()
	if not s.Looped then
		s.Ended:Once(function()
			s:Destroy()
		end)
		task.delay(30, function()
			if s.Parent then
				s:Destroy()
			end
		end)
	end
	return s
end

-- Persistent loop you start/stop yourself.
function Sounds.loop(key: Key, parent: Instance, volumeMul: number?): Sound
	local def = assert(Sounds.Catalog[key], "unknown sound " .. key)
	local s = Instance.new("Sound")
	s.Name = key
	configure(s, def, volumeMul)
	s.Looped = true
	s.Parent = parent
	return s
end

return Sounds

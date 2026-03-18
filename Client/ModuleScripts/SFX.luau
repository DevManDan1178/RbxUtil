local SFX = {}

local ClientSFXFolder = --[[REFERENCE FOLDER FOR CLIENT SOUND EFFECTS]] or Instance.new("Folder", game.StarterGui)
ClientSFXFolder.Name = "SoundEffects"

--[[Gets (or creates) the sound objeect for the sound effect in the parent folder]]
function getSoundSingular(sfx : Sound, parentFolder : Folder) : Sound
	local sfxClone : Sound = ClientSFXFolder:FindFirstChild(sfx.SoundId) 
	if sfxClone then
		return sfxClone
	end
	sfxClone = sfx:Clone()
	sfxClone.Name = sfx.SoundId
	sfxClone.Parent = ClientSFXFolder
	return sfxClone
end

--[[Plays the sound. If the sound is already playing, it will replay instead of layering]]
function SFX.PlaySFXSingular(sfx : Sound, playbackSpeed : number?, multplyVolume : number?)
	local sfxClone = getSoundSingular(sfx, ClientSFXFolder)
	sfxClone.PlaybackSpeed = playbackSpeed or sfx.PlaybackSpeed
	sfxClone.Volume = multplyVolume and sfx.Volume * multplyVolume or sfx.Volume
	sfxClone:Play()
end



local SFXFolderSuffix = "_FLDR"
--[[
  Plays a sound effect (same sound effects can be layered with different playback speeds) with customizable playback speed and volume multiplier
  Use for constantly repeating sound effects at different playback speeds
  *Playing an already playing sound at a same playback speed will replay the sound and not layer it
  > Creates a folder for clones of that sound that can be replayed
]]
function SFX.PlaySFX(sfx : Sound, playbackSpeed : number?, multiplyVolume : number?)
	local soundIDFolder = ClientSFXFolder:FindFirstChild(sfx.SoundId .. SFXFolderSuffix) or Instance.new("Folder", ClientSFXFolder)
	soundIDFolder.Name = sfx.SoundId .. SFXFolderSuffix
	
	if typeof(playbackSpeed) ~= "number" then playbackSpeed = sfx.PlaybackSpeed end
	local sfxClone : Sound = soundIDFolder:FindFirstChild(tostring(playbackSpeed))
	if not sfxClone then
		sfxClone = sfx:Clone()
		sfxClone.Name = tostring(playbackSpeed)
		sfxClone.Parent = soundIDFolder
		sfxClone.PlaybackSpeed = playbackSpeed or sfx.PlaybackSpeed
	end
	
	sfxClone.Volume = multiplyVolume and sfx.Volume * multiplyVolume or sfx.Volume
	sfxClone:Play()
end


return SFX

## Active voice limit policy.
##
## Default max active voices:
## - Desktop: 16
## - PlayStation Vita homebrew: 12
## - Nintendo 3DS homebrew: 10

type
  VoiceOptions* = object
    maxActiveVoices*: cuint

const
  desktopDefaultMaxActiveVoices* = 16'u32
  vitaDefaultMaxActiveVoices* = 12'u32
  n3dsDefaultMaxActiveVoices* = 10'u32

proc platformDefaultMaxActiveVoices*(): cuint =
  when defined(playPlatformVita):
    vitaDefaultMaxActiveVoices
  elif defined(playPlatform3ds):
    n3dsDefaultMaxActiveVoices
  else:
    desktopDefaultMaxActiveVoices

proc voiceOptions*(maxActiveVoices = platformDefaultMaxActiveVoices()): VoiceOptions =
  VoiceOptions(maxActiveVoices: maxActiveVoices)

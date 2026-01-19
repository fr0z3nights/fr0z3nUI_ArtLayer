Put your .tga textures here.

In Lua, reference them like:
	Interface\\AddOns\\fr0z3nUI_ArtLayer\\media\\YourTexture.tga

Quick start (in-game):
	/fal widgets add texture test MyTexture.tga
	/fal widgets set test size 256 256
	/fal widgets set test pos CENTER 0 0

Conditions examples:
	/fal widgets cond test add faction Horde
	/fal widgets cond test add seen "Somechar-Somerealm" norealm
	/fal widgets cond test add mail

Tip: /fal widgets add texture <key> <YourTexture.tga>

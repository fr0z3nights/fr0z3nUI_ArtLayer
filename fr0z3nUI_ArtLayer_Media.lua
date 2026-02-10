---@diagnostic disable: undefined-global

-- Auto-generated-ish helper list for the UI texture picker.
--
-- WoW addons cannot enumerate files from disk at runtime, so if you add/remove
-- .tga files under the media folder, regenerate this list (see tools script).

local ADDON, ns = ...
ns = ns or {}

-- Entries are { label, value } where value is what gets written into the
-- Texture field (it can be a bare filename; the addon resolves it to media/).
ns.MediaTextures = {
  { "Alliance", "Alliance" },
  { "DNX", "DNX" },
  { "Horde", "Horde" },
  { "Horde_Crest11", "Horde_Crest11" },
  { "MailX", "MailX" },
  { "MailY", "MailY" },
  { "Ak", "PB05_Ak" },
  { "Anthea", "PB05_Anthea" },
  { "BurningSpirit", "PB05_BurningSpirit" },
  { "FlowingSpirit", "PB05_FlowingSpirit" },
  { "Hyuna", "PB05_Hyuna" },
  { "Mo'Ruk", "PB05_Mo'Ruk" },
  { "Nishi", "PB05_Nishi" },
  { "Shu", "PB05_Shu" },
  { "ThunderSpirit", "PB05_ThunderSpirit" },
  { "WhisperingSpirit", "PB05_WhisperingSpirit" },
  { "Zisshi", "PB05_Zisshi" },
  { "Ashlei", "PB06_Ashlei" },
  { "Brightblade", "PB06_Brightblade" },
  { "Gargra", "PB06_Gargra" },
  { "Taralune", "PB06_Taralune" },
  { "Tarr", "PB06_Tarr" },
  { "Vasharr", "PB06_Vasharr" },
  { "SL_Kyrian", "SL_Kyrian" },
  { "SL_Necrolords", "SL_Necrolords" },
  { "SL_NightFae", "SL_NightFae" },
  { "SL_Venthyr", "SL_Venthyr" },
  { "WoW1", "WoW1" },
  { "WoW2", "WoW2" },
  { "WoW3", "WoW3" },
  { "WoW4", "WoW4" },
  { "WoW5", "WoW5" },
  { "WoW6", "WoW6" },
  { "WoW7", "WoW7" },
  { "WoW8", "WoW8" },
}

std = "lua51"
max_line_length = 120
codes = true

-- Addon package locals passed via vararg in every file: _, _G
ignore = {
  "212/self", -- unused argument self (Ace3 methods)
  "431",      -- shadowing upvalue (common in Ace3)
}

-- WoW / Ace3 globals (core subset — extend as needed)
globals = {
  -- Addon table & lib access
  "LibStub",

  -- SavedVariables (names from TOC)
  "HeyListenDB",
}

read_globals = {
  -- Blizzard API (common subset; add more as you use them)
  "UnitName", "UnitClass", "UnitGUID", "UnitLevel", "UnitExists",
  "GetTime", "GetRealmName", "GetServerTime",
  "CreateFrame", "UIParent", "WorldFrame",
  "InCombatLockdown", "IsInGroup", "IsInRaid", "IsInInstance",
  "GetSpellInfo", "GetSpellCooldown", "GetItemInfo", "GetItemCooldown",
  "print", "DEFAULT_CHAT_FRAME", "ChatFrame1",
  "hooksecurefunc", "issecure", "securecall",
  "strsplit", "strjoin", "strtrim",
  "C_Timer", "C_ChatInfo", "PlaySoundFile",

  -- Event/Frame
  "GameTooltip", "GameFontNormal", "GameFontHuge", "GameFontHighlight",

  -- TBC-specific (partial)
  "GetContainerNumSlots", "GetContainerItemInfo", "GetContainerItemLink",
  "CastSpellByName", "UseContainerItem",
}

local ADDON_NAME, ns = ...

local HeyListen = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0", "AceConsole-3.0")
ns.Addon = HeyListen

local defaults = {
  global = {
    partner = nil,
    mute = false,
    position = nil, -- { point, relPoint, x, y }
    sounds = {
      readycheck = "Sound\\Interface\\ReadyCheck.ogg",
      whisper = "Sound\\Interface\\iTellMessage.ogg",
    },
  },
}

function HeyListen:OnInitialize()
  self.db = LibStub("AceDB-3.0"):New("HeyListenDB", defaults, true)
  self:RegisterChatCommand("heylisten", "HandleSlashCommand")
  self:RegisterChatCommand("hey", "HandleSlashCommand")
  self:RegisterChatCommand("hl", "HandleSlashCommand")

  ns.Pairing:Initialize(self)
  ns.Comm:Initialize(self)
  ns.Mirror:Initialize(self)
end

function HeyListen:OnEnable()
  local partner = ns.Pairing:GetPartner()
  if partner then
    self:Print("ready, mirroring to/from " .. partner)
  else
    self:Print("ready. Set partner with: /hey pair <Charname-Realm>")
  end
end

function HeyListen:OnDisable()
  self:UnregisterAllEvents()
end

local function help(self)
  self:Print("commands:")
  self:Print("  /hey pair <Charname-Realm>   set mirror partner (run on both accounts)")
  self:Print("  /hey unpair                  remove partner")
  self:Print("  /hey status                  show current partner & state")
  self:Print("  /hey mute                    toggle mute for received alerts")
  self:Print("  /hey test                    send a test signal to partner")
  self:Print("  /hey move                    toggle drag mode for the toast position")
end

local KNOWN_COMMANDS = {
  pair = true, unpair = true, status = true, mute = true, test = true, move = true, help = true,
}

local function tryPair(self, raw)
  local ok, normalized, err = ns.Pairing:SetPartner(raw)
  if ok then
    self:Print("partner set: " .. normalized)
  else
    self:Print("invalid: " .. (err or "unknown"))
  end
end

function HeyListen:HandleSlashCommand(input)
  input = (input or ""):trim()
  local cmd, rest = input:match("^(%S*)%s*(.-)$")
  local cmdLower = (cmd or ""):lower()

  -- If the first word looks like a Charname-Realm, treat the whole input as pair.
  if not KNOWN_COMMANDS[cmdLower] and cmd:find("%-") then
    tryPair(self, input)
    return
  end

  if cmdLower == "pair" then
    if rest == "" then
      self:Print("usage: /hey pair <Charname-Realm>  (or just /hey <Charname-Realm>)")
      return
    end
    tryPair(self, rest)
  elseif cmdLower == "unpair" then
    ns.Pairing:SetPartner(nil)
    self:Print("partner cleared")
  elseif cmdLower == "status" then
    local partner = ns.Pairing:GetPartner()
    self:Print("partner: " .. (partner or "<none>"))
    self:Print("mute: " .. tostring(self.db.global.mute))
  elseif cmdLower == "mute" then
    self.db.global.mute = not self.db.global.mute
    self:Print("mute: " .. tostring(self.db.global.mute))
  elseif cmdLower == "test" then
    ns.Comm:SendTest()
  elseif cmdLower == "move" then
    ns.Mirror:ToggleMoveMode()
  else
    help(self)
  end
end

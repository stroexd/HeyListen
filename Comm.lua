local ADDON_NAME, ns = ...
local Comm = {}
ns.Comm = Comm

local PREFIX = "HeyListen"
local CHUNK_SIZE = 200
local SEP = "\31" -- unit separator, safe vs whisper text

local addon
local inbox = {} -- [senderKey] = { parts = {}, total = N }

local function key(sender, msgID)
  return sender .. "/" .. msgID
end

local function send(payload)
  local partner = ns.Pairing:GetPartner()
  if not partner then
    return false, "no partner set"
  end
  local result = C_ChatInfo.SendAddonMessage(PREFIX, payload, "WHISPER", partner)
  return result, nil, partner
end

local function encode(parts)
  return table.concat(parts, SEP)
end

local function decode(payload)
  local out = {}
  for part in (payload .. SEP):gmatch("(.-)" .. SEP) do
    table.insert(out, part)
  end
  return out
end

function Comm:Initialize(parent)
  addon = parent

  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
  end

  addon:RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, message, channel, sender)
    if prefix ~= PREFIX then return end
    Comm:OnReceive(message, channel, sender)
  end)
end

function Comm:SendReadycheck(initiator)
  send(encode({ "RC", initiator or "?" }))
end

local nextWhisperID = 0
function Comm:SendWhisper(senderName, text)
  nextWhisperID = (nextWhisperID + 1) % 1000
  local id = tostring(nextWhisperID)
  local total = math.max(1, math.ceil(#text / CHUNK_SIZE))
  for i = 1, total do
    local chunk = text:sub((i - 1) * CHUNK_SIZE + 1, i * CHUNK_SIZE)
    send(encode({ "WSP", id, tostring(i), tostring(total), senderName, chunk }))
  end
end

function Comm:SendTest()
  local partner = ns.Pairing:GetPartner()
  if not partner then
    addon:Print("no partner set. Use: /hey <Charname-Realm>")
    return
  end
  local result = C_ChatInfo.SendAddonMessage(PREFIX, encode({ "TEST" }), "WHISPER", partner)
  if result == true or result == 0 then
    addon:Print("test sent to " .. partner .. " — wait for popup on the other side.")
  else
    addon:Print("send failed (result=" .. tostring(result) .. ") to " .. partner)
    addon:Print("checks: (1) partner online? (2) same realm? (3) name spelled exactly right?")
    addon:Print("hint: try a normal whisper:  /w " .. partner .. " ping")
  end
end

function Comm:OnReceive(message, channel, sender)
  -- Only accept from configured partner. Sender comes as "Name-Realm".
  local partner = ns.Pairing:GetPartner()
  if not partner or sender ~= partner then
    return
  end

  local parts = decode(message)
  local kind = parts[1]

  if kind == "RC" then
    ns.Mirror:OnReadycheck(parts[2] or "?", sender)
  elseif kind == "WSP" then
    local id, idx, total, fromName, chunk =
      parts[2], tonumber(parts[3]), tonumber(parts[4]), parts[5], parts[6]
    if not id or not idx or not total or not fromName then return end

    local k = key(sender, id)
    local entry = inbox[k]
    if not entry then
      entry = { parts = {}, total = total }
      inbox[k] = entry
    end
    entry.parts[idx] = chunk or ""
    local count = 0
    for _ in pairs(entry.parts) do count = count + 1 end
    if count >= entry.total then
      local full = table.concat(entry.parts, "", 1, entry.total)
      inbox[k] = nil
      ns.Mirror:OnWhisper(fromName, full, sender)
    end
  elseif kind == "TEST" then
    ns.Mirror:OnTest(sender)
  end
end

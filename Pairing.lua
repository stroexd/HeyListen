local ADDON_NAME, ns = ...
local Pairing = {}
ns.Pairing = Pairing

local addon

function Pairing:Initialize(parent)
  addon = parent
end

local function normalize(name)
  if not name or name == "" then
    return nil, "empty"
  end
  name = name:gsub("%s+", "")
  local char, realm = name:match("^([^%-]+)%-(.+)$")
  if not char or not realm then
    return nil, "expected format: Charname-Realm"
  end
  -- WoW's whisper API expects the realm part as written (spaces stripped).
  return char .. "-" .. realm
end

function Pairing:SetPartner(name)
  if name == nil then
    addon.db.global.partner = nil
    return true, nil
  end
  local normalized, err = normalize(name)
  if not normalized then
    return false, nil, err
  end
  addon.db.global.partner = normalized
  return true, normalized
end

function Pairing:GetPartner()
  return addon.db.global.partner
end

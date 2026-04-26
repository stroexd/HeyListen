-- Minimal WoW API stubs – only what Pairing.lua and Comm.lua actually touch.
C_ChatInfo = {
  SendAddonMessage = function() return true end,
  RegisterAddonMessagePrefix = function() end,
}

local SEP = "\31" -- must match Comm.lua's SEP

-- Builds a fresh, isolated set of modules for each test group.
local function loadAddon()
  local ns = {}

  -- Stub Mirror so Comm.OnReceive can route to it; we record every call.
  ns.Mirror = {
    calls = {},
    OnReadycheck = function(self, initiator, from)
      table.insert(self.calls, { "RC", initiator, from })
    end,
    OnWhisper = function(self, sender, text, from)
      table.insert(self.calls, { "WSP", sender, text, from })
    end,
    OnTest = function(self, from)
      table.insert(self.calls, { "TEST", from })
    end,
  }

  local addon = {
    db = { global = { partner = nil, mute = false, sounds = {} } },
    RegisterEvent = function() end,
    Print = function() end,
  }

  local function load(file)
    local chunk = assert(loadfile(file))
    chunk("HeyListen", ns)
  end

  load("Pairing.lua")
  ns.Pairing:Initialize(addon)

  load("Comm.lua")
  ns.Comm:Initialize(addon)

  return ns, addon
end

-- Helper: build a raw protocol message with the ASCII-31 separator.
local function msg(...)
  return table.concat({ ... }, SEP)
end

------------------------------------------------------------
-- Pairing / normalize
------------------------------------------------------------

describe("Pairing", function()
  local ns, addon

  before_each(function()
    ns, addon = loadAddon()
  end)

  it("accepts a valid Charname-Realm", function()
    local ok, name = ns.Pairing:SetPartner("Stroetroll-Nethergarde")
    assert.is_true(ok)
    assert.equals("Stroetroll-Nethergarde", name)
  end)

  it("strips all whitespace before parsing", function()
    local ok, name = ns.Pairing:SetPartner("  Stroe troll - Nether garde  ")
    assert.is_true(ok)
    assert.equals("Stroetroll-Nethergarde", name)
  end)

  it("rejects a name without a realm", function()
    local ok, _, err = ns.Pairing:SetPartner("Stroetroll")
    assert.is_false(ok)
    assert.is_string(err)
  end)

  it("rejects an empty string", function()
    local ok, _, err = ns.Pairing:SetPartner("")
    assert.is_false(ok)
    assert.is_string(err)
  end)

  it("clears the partner when nil is passed", function()
    ns.Pairing:SetPartner("Stroetroll-Nethergarde")
    ns.Pairing:SetPartner(nil)
    assert.is_nil(ns.Pairing:GetPartner())
  end)

  it("persists the partner so GetPartner returns it", function()
    ns.Pairing:SetPartner("Foo-BarRealm")
    assert.equals("Foo-BarRealm", ns.Pairing:GetPartner())
  end)
end)

------------------------------------------------------------
-- Comm – message routing and decode
------------------------------------------------------------

describe("Comm.OnReceive", function()
  local ns, addon

  before_each(function()
    ns, addon = loadAddon()
    addon.db.global.partner = "Partner-Realm"
  end)

  it("routes RC to Mirror:OnReadycheck with initiator", function()
    ns.Comm:OnReceive(msg("RC", "Initiator-Realm"), "WHISPER", "Partner-Realm")
    assert.equals(1, #ns.Mirror.calls)
    assert.equals("RC", ns.Mirror.calls[1][1])
    assert.equals("Initiator-Realm", ns.Mirror.calls[1][2])
  end)

  it("routes TEST to Mirror:OnTest", function()
    ns.Comm:OnReceive(msg("TEST"), "WHISPER", "Partner-Realm")
    assert.equals(1, #ns.Mirror.calls)
    assert.equals("TEST", ns.Mirror.calls[1][1])
  end)

  it("drops messages from unknown senders", function()
    ns.Comm:OnReceive(msg("RC", "Initiator"), "WHISPER", "Stranger-Realm")
    assert.equals(0, #ns.Mirror.calls)
  end)

  it("drops messages when no partner is configured", function()
    addon.db.global.partner = nil
    ns.Comm:OnReceive(msg("RC", "Initiator"), "WHISPER", "Partner-Realm")
    assert.equals(0, #ns.Mirror.calls)
  end)
end)

------------------------------------------------------------
-- Comm – whisper chunking / reassembly
------------------------------------------------------------

describe("Comm whisper reassembly", function()
  local ns, addon

  before_each(function()
    ns, addon = loadAddon()
    addon.db.global.partner = "Partner-Realm"
  end)

  it("delivers a single-chunk whisper immediately", function()
    ns.Comm:OnReceive(msg("WSP", "1", "1", "1", "Sender-Realm", "Hello world"), "WHISPER", "Partner-Realm")
    assert.equals(1, #ns.Mirror.calls)
    assert.equals("WSP", ns.Mirror.calls[1][1])
    assert.equals("Sender-Realm", ns.Mirror.calls[1][2])
    assert.equals("Hello world", ns.Mirror.calls[1][3])
  end)

  it("holds delivery until all chunks arrive (in order)", function()
    ns.Comm:OnReceive(msg("WSP", "42", "1", "2", "Sender-Realm", "Hello "), "WHISPER", "Partner-Realm")
    assert.equals(0, #ns.Mirror.calls)
    ns.Comm:OnReceive(msg("WSP", "42", "2", "2", "Sender-Realm", "world"), "WHISPER", "Partner-Realm")
    assert.equals(1, #ns.Mirror.calls)
    assert.equals("Hello world", ns.Mirror.calls[1][3])
  end)

  it("reassembles correctly when chunks arrive out of order", function()
    ns.Comm:OnReceive(msg("WSP", "99", "2", "2", "Sender-Realm", "world"), "WHISPER", "Partner-Realm")
    assert.equals(0, #ns.Mirror.calls)
    ns.Comm:OnReceive(msg("WSP", "99", "1", "2", "Sender-Realm", "Hello "), "WHISPER", "Partner-Realm")
    assert.equals(1, #ns.Mirror.calls)
    assert.equals("Hello world", ns.Mirror.calls[1][3])
  end)

  it("tracks two parallel whispers independently", function()
    ns.Comm:OnReceive(msg("WSP", "1", "1", "2", "Alice-Realm", "Hi "), "WHISPER", "Partner-Realm")
    ns.Comm:OnReceive(msg("WSP", "2", "1", "2", "Bob-Realm", "Hey "), "WHISPER", "Partner-Realm")
    assert.equals(0, #ns.Mirror.calls)

    ns.Comm:OnReceive(msg("WSP", "1", "2", "2", "Alice-Realm", "Alice"), "WHISPER", "Partner-Realm")
    assert.equals(1, #ns.Mirror.calls)
    assert.equals("Hi Alice", ns.Mirror.calls[1][3])

    ns.Comm:OnReceive(msg("WSP", "2", "2", "2", "Bob-Realm", "Bob"), "WHISPER", "Partner-Realm")
    assert.equals(2, #ns.Mirror.calls)
    assert.equals("Hey Bob", ns.Mirror.calls[2][3])
  end)

  it("clears the inbox after delivery so the same ID can be reused", function()
    ns.Comm:OnReceive(msg("WSP", "7", "1", "1", "Sender-Realm", "first"), "WHISPER", "Partner-Realm")
    assert.equals(1, #ns.Mirror.calls)
    -- After delivery the inbox entry is gone; same ID starts a fresh 2-part message.
    ns.Comm:OnReceive(msg("WSP", "7", "1", "2", "Sender-Realm", "Hello "), "WHISPER", "Partner-Realm")
    assert.equals(1, #ns.Mirror.calls) -- waiting for chunk 2
    ns.Comm:OnReceive(msg("WSP", "7", "2", "2", "Sender-Realm", "again"), "WHISPER", "Partner-Realm")
    assert.equals(2, #ns.Mirror.calls)
    assert.equals("Hello again", ns.Mirror.calls[2][3])
  end)
end)

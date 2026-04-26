local ADDON_NAME, ns = ...
local Mirror = {}
ns.Mirror = Mirror

local addon
local flashFrame, flashText, flashAnim
local toastAnchor
local toasts = {} -- list, [1] = newest
local MAX_TOASTS = 5
local TOAST_LIFETIME = 12

local WHISPER_PINK = { 1.0, 0.5, 1.0 }
local DIM_GRAY = { 0.65, 0.65, 0.65 }

local function stripRealm(name)
  if not name then return "?" end
  return (name:match("^([^%-]+)") or name)
end

local function selfShortName()
  local me = UnitName("player")
  return me or "?"
end

------------------------------------------------------------
-- Sender side: forward our local events to the partner
------------------------------------------------------------

function Mirror:Initialize(parent)
  addon = parent

  addon:RegisterEvent("READY_CHECK", function(_, initiator, _duration)
    ns.Comm:SendReadycheck(initiator or "?")
  end)

  addon:RegisterEvent("CHAT_MSG_WHISPER", function(_, text, sender)
    if not text or not sender then return end
    local partner = ns.Pairing:GetPartner()
    if partner and (sender == partner or sender == partner:match("^[^%-]+")) then
      return
    end
    ns.Comm:SendWhisper(sender, text)
  end)

  local okFlash, errFlash = pcall(function() self:BuildFlashFrame() end)
  if not okFlash then addon:Print("flash build failed: " .. tostring(errFlash)) end

  local okAnchor, errAnchor = pcall(function() self:BuildToastAnchor() end)
  if not okAnchor then addon:Print("anchor build failed: " .. tostring(errAnchor)) end
end

local function ensureAnchor()
  if not toastAnchor then
    local ok, err = pcall(function() Mirror:BuildToastAnchor() end)
    if not ok then
      addon:Print("anchor lazy-build failed: " .. tostring(err))
    end
  end
  return toastAnchor
end

------------------------------------------------------------
-- Sound helper
------------------------------------------------------------

local function playSound(kind)
  if addon.db.global.mute then return end
  local path = addon.db.global.sounds[kind]
  if path then
    PlaySoundFile(path, "Master")
  end
end

------------------------------------------------------------
-- Full-screen flash + warning text
------------------------------------------------------------

function Mirror:BuildFlashFrame()
  local f = CreateFrame("Frame", "HeyListenFlash", UIParent)
  f:SetAllPoints(UIParent)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:EnableMouse(false)
  f:Hide()

  local tex = f:CreateTexture(nil, "BACKGROUND")
  tex:SetAllPoints()
  tex:SetColorTexture(1, 0.1, 0.1, 0.45)

  local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  text:SetPoint("CENTER", 0, 100)
  text:SetTextColor(1, 0.9, 0.2)
  text:SetText("")
  flashText = text

  local ag = f:CreateAnimationGroup()
  local fadeIn = ag:CreateAnimation("Alpha")
  fadeIn:SetFromAlpha(0); fadeIn:SetToAlpha(1); fadeIn:SetDuration(0.15); fadeIn:SetOrder(1)
  local hold = ag:CreateAnimation("Alpha")
  hold:SetFromAlpha(1); hold:SetToAlpha(1); hold:SetDuration(1.2); hold:SetOrder(2)
  local fadeOut = ag:CreateAnimation("Alpha")
  fadeOut:SetFromAlpha(1); fadeOut:SetToAlpha(0); fadeOut:SetDuration(0.6); fadeOut:SetOrder(3)
  ag:SetScript("OnFinished", function() f:Hide() end)

  flashFrame = f
  flashAnim = ag
end

local function ensureFlash()
  if flashFrame then return flashFrame end
  local ok, err = pcall(function() Mirror:BuildFlashFrame() end)
  if not ok then
    addon:Print("flash lazy-build failed: " .. tostring(err))
  end
  return flashFrame
end

local function flash(message)
  if not ensureFlash() then return end
  flashText:SetText(message)
  flashFrame:SetAlpha(0)
  flashFrame:Show()
  flashAnim:Stop()
  flashAnim:Play()
end

------------------------------------------------------------
-- Toast anchor (movable)
------------------------------------------------------------

function Mirror:ApplyAnchorPosition()
  local p = addon.db.global.position
  toastAnchor:ClearAllPoints()
  if p and p.point then
    toastAnchor:SetPoint(p.point, UIParent, p.relPoint or p.point, p.x or 0, p.y or 0)
  else
    toastAnchor:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -120)
  end
end

function Mirror:BuildToastAnchor()
  local a = CreateFrame("Frame", "HeyListenToastAnchor", UIParent)
  a:SetSize(360, 1)
  a:SetClampedToScreen(true)
  toastAnchor = a
  Mirror:ApplyAnchorPosition()
end

local function restackToasts()
  for i, item in ipairs(toasts) do
    item:ClearAllPoints()
    if i == 1 then
      item:SetPoint("TOPRIGHT", toastAnchor, "TOPRIGHT", 0, 0)
    else
      item:SetPoint("TOPRIGHT", toasts[i - 1], "BOTTOMRIGHT", 0, -6)
    end
  end
end

------------------------------------------------------------
-- Move mode
------------------------------------------------------------

local moveMode = false

local function ensureMoveDecor()
  if toastAnchor.bg then return end
  local bg = toastAnchor:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.2, 0.4, 0.9, 0.6)
  toastAnchor.bg = bg

  local label = toastAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("CENTER")
  label:SetText("HeyListen toast anchor — drag me. /hey move to lock.")
  toastAnchor.label = label
end

function Mirror:EnterMoveMode()
  if moveMode then return end
  if not ensureAnchor() then return end
  moveMode = true
  ensureMoveDecor()
  toastAnchor:SetSize(360, 32)
  toastAnchor.bg:Show()
  toastAnchor.label:Show()
  toastAnchor:EnableMouse(true)
  toastAnchor:SetMovable(true)
  toastAnchor:RegisterForDrag("LeftButton")
  toastAnchor:SetScript("OnDragStart", function(self) self:StartMoving() end)
  toastAnchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    addon.db.global.position = { point = point, relPoint = relPoint, x = x, y = y }
  end)
  addon:Print("move mode ON. Drag the blue box. /hey move again to lock & save.")
end

function Mirror:ExitMoveMode()
  if not moveMode then return end
  moveMode = false
  if toastAnchor.bg then toastAnchor.bg:Hide() end
  if toastAnchor.label then toastAnchor.label:Hide() end
  toastAnchor:EnableMouse(false)
  toastAnchor:SetScript("OnDragStart", nil)
  toastAnchor:SetScript("OnDragStop", nil)
  toastAnchor:SetSize(360, 1)
  addon:Print("move mode OFF, position saved.")
end

function Mirror:ToggleMoveMode()
  if moveMode then Mirror:ExitMoveMode() else Mirror:EnterMoveMode() end
end

------------------------------------------------------------
-- Toast widget
------------------------------------------------------------

local function destroyToast(toast)
  toast:Hide()
  toast:SetParent(nil)
  for i, t in ipairs(toasts) do
    if t == toast then table.remove(toasts, i); break end
  end
  restackToasts()
end

local function newToast(senderText, recipientText, bodyText, senderColor)
  if not ensureAnchor() then return end
  local t = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  t:SetSize(360, 1)
  t:SetFrameStrata("HIGH")
  if t.SetBackdrop then
    t:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    t:SetBackdropColor(0, 0, 0, 0.85)
    t:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
  end

  -- Recipient (right side, dim, smaller weight): "→ Stroetroll"
  local recipient = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  recipient:SetPoint("TOPRIGHT", -10, -8)
  recipient:SetJustifyH("RIGHT")
  recipient:SetText(recipientText or "")
  recipient:SetTextColor(unpack(DIM_GRAY))

  -- Sender (left side, bold pink for whisper): "Andryusha"
  local sender = t:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sender:SetPoint("TOPLEFT", 10, -8)
  sender:SetPoint("RIGHT", recipient, "LEFT", -8, 0)
  sender:SetJustifyH("LEFT")
  sender:SetText(senderText or "?")
  if senderColor then
    sender:SetTextColor(unpack(senderColor))
  end

  -- Body
  local body = t:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  body:SetPoint("TOPLEFT", sender, "BOTTOMLEFT", 0, -4)
  body:SetPoint("RIGHT", t, "RIGHT", -10, 0)
  body:SetJustifyH("LEFT")
  body:SetWordWrap(true)
  body:SetText(bodyText or "")

  local h = 8 + math.max(sender:GetStringHeight(), recipient:GetStringHeight()) + 4 + body:GetStringHeight() + 10
  t:SetHeight(h)

  while #toasts >= MAX_TOASTS do
    destroyToast(toasts[#toasts])
  end
  table.insert(toasts, 1, t)
  restackToasts()
  t:Show()

  local elapsed = 0
  t:SetScript("OnUpdate", function(self, e)
    elapsed = elapsed + e
    if elapsed >= TOAST_LIFETIME then
      self:SetScript("OnUpdate", nil)
      destroyToast(self)
    elseif elapsed >= TOAST_LIFETIME - 1.5 then
      self:SetAlpha(math.max(0, (TOAST_LIFETIME - elapsed) / 1.5))
    end
  end)

  return t
end

------------------------------------------------------------
-- Public receive handlers (called by Comm)
------------------------------------------------------------

function Mirror:OnReadycheck(initiator, fromAccount)
  flash(("READY CHECK on %s\nfrom %s"):format(stripRealm(fromAccount), stripRealm(initiator)))
  playSound("readycheck")
end

function Mirror:OnWhisper(originalSender, text, fromAccount)
  newToast(
    stripRealm(originalSender),
    "→ " .. stripRealm(fromAccount),
    text,
    WHISPER_PINK
  )
  playSound("whisper")
end

function Mirror:OnTest(fromAccount)
  flash(("TEST signal from %s\n(this is what a ready check looks like)"):format(stripRealm(fromAccount)))
  newToast(
    "TEST",
    "→ " .. selfShortName(),
    "Signal from " .. stripRealm(fromAccount) .. ". Connection works.",
    { 0.5, 1, 0.5 }
  )
end

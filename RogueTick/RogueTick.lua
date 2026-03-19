-- =============================================
-- Rogue / Feral Druid: 4-Bank + Neon Glow Restored
-- =============================================

-- [[ БЛОК 1: НАСТРОЙКИ ]]
EnergyTickSettings = EnergyTickSettings or {
 soundID = 569595, delay = 0.4, width = 260, height = 22,
 x = 0, y = -150, locked = false,
 showEnergyText = false
}

local ET_History = {} 
local ET_MaxHistory = 10 

local f = CreateFrame("Frame", "ET_MainFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
f:SetSize(EnergyTickSettings.width, EnergyTickSettings.height)
f:SetPoint("CENTER", UIParent, "CENTER", EnergyTickSettings.x, EnergyTickSettings.y)
f:SetFrameStrata("TOOLTIP")
f:SetMovable(not EnergyTickSettings.locked); f:EnableMouse(not EnergyTickSettings.locked); f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", function(self)
 self:StopMovingOrSizing(); local _, _, _, x, y = self:GetPoint()
 EnergyTickSettings.x, EnergyTickSettings.y = x, y
end)
f:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1, insets = {left=1,right=1,top=1,bottom=1}})
f:SetBackdropColor(0, 0, 0, 1); f:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

-- [[ УРОВЕНЬ 1.5: ТЕКСТ ]]
local function MakeText(size, color)
 local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
 t:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE"); if color then t:SetTextColor(unpack(color)) end; return t
end
local txtEnergy = EnergyTickSettings.showEnergyText and MakeText(14, {1, 1, 1}) or nil
local txtCP = MakeText(18); local txtPct = MakeText(10, {0.6, 0.6, 0.6}); local txtMs = MakeText(9, {0.5, 0.5, 0.5})

-- [[ УРОВЕНЬ 2: ИДЕАЛЬНАЯ ЗОНА + НЕОН ]]
local IdealZone = CreateFrame("Frame", "ET_IdealZone", f, BackdropTemplateMixin and "BackdropTemplate" or nil)
IdealZone:SetSize(30, f:GetHeight() + 10); 
IdealZone:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1.5 });
IdealZone:SetFrameLevel(f:GetFrameLevel() + 2)

local IdealNeon = CreateFrame("Frame", nil, IdealZone, BackdropTemplateMixin and "BackdropTemplate" or nil)
IdealNeon:SetPoint("TOPLEFT", -1.2, 1.2); IdealNeon:SetPoint("BOTTOMRIGHT", 1.2, -1.2)
IdealNeon:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1.2 })
IdealNeon:Hide()

-- [[ УРОВЕНЬ 3: ЭНЕРГИЯ ]]
local EnergyBar = f:CreateTexture("ET_EnergyBar", "ARTWORK", nil, 1)
EnergyBar:SetColorTexture(0.8, 0.65, 0, 0.8)
EnergyBar:SetHeight(20); EnergyBar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)

-- [[ УРОВЕНЬ 4: БАНКИ КЛЯКС С КАЕМОЧКОЙ ]]
local banks = { Elite = {}, Master = {}, Basic = {}, Miss = {} }
local indices = { Elite = 1, Master = 1, Basic = 1, Miss = 1 }
local MAX_DOTS_PER_BANK = 10

local function CreateEliteDot(r, g, b)
    local d = CreateFrame("Frame", nil, f)
    d:SetSize(5, 5)
    local bg = d:CreateTexture(nil, "OVERLAY", nil, 6)
    bg:SetSize(5, 5); bg:SetPoint("CENTER"); bg:SetColorTexture(0, 0, 0, 1)
    local core = d:CreateTexture(nil, "OVERLAY", nil, 7)
    core:SetSize(3, 3); core:SetPoint("CENTER"); core:SetColorTexture(r, g, b, 1)
    d.core = core; d:Hide(); return d
end

for i=1, MAX_DOTS_PER_BANK do
    banks.Elite[i]  = CreateEliteDot(0.7, 0, 1)   -- Фиолетовый
    banks.Master[i] = CreateEliteDot(0, 1, 0.2)   -- Зеленый
    banks.Basic[i]  = CreateEliteDot(1, 0.7, 0)   -- Оранжевый
    banks.Miss[i]   = CreateEliteDot(1, 0.1, 0.1) -- Красный
end

-- [[ ЛОГИКА ]]
local okScore, totalAttempts = 0, 0
local function ClearDots()
    okScore, totalAttempts = 0, 0
    if txtPct then txtPct:SetText("") end
    if txtMs then txtMs:SetText("") end
    for name, bank in pairs(banks) do
        for _, dot in ipairs(bank) do dot:Hide() end
        indices[name] = 1
    end
end

local IdealLine = IdealZone:CreateTexture("ET_IdealLine", "OVERLAY", nil, 7)
IdealLine:SetSize(2, IdealZone:GetHeight() - 2); IdealLine:SetPoint("CENTER", IdealZone, "CENTER", 0, 0)
IdealLine:SetColorTexture(0.5, 0.3, 0, 0.4)

local TickPulse = f:CreateTexture("ET_TickPulse", "OVERLAY", nil, 7)
TickPulse:SetSize(2, 20); TickPulse:SetColorTexture(1, 1, 1, 1); TickPulse:SetPoint("TOP", EnergyBar, "TOP")

if txtEnergy then txtEnergy:SetPoint("RIGHT", f, "RIGHT", -6, 0) end
local lastE, lastT, triggered, visualE = 0, GetTime(), false, 0

f:RegisterEvent("UNIT_POWER_UPDATE"); f:RegisterEvent("UNIT_SPELLCAST_SENT"); f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:SetScript("OnEvent", function(self, ev, unit)
 if ev == "PLAYER_REGEN_DISABLED" then ClearDots()
 elseif ev == "UNIT_POWER_UPDATE" and unit == "player" then
    local c = UnitPower("player", 3); if c > lastE then lastT = GetTime(); triggered = false end; lastE = c
 elseif ev == "UNIT_SPELLCAST_SENT" and unit == "player" and UnitAffectingCombat("player") then
    local now = GetTime(); local _, _, _, worldLat = GetNetStats(); local latency = (worldLat or 0) / 1000
    local since = now - lastT
    local diff = 2 - since - latency
    local offsetMs = (diff - EnergyTickSettings.delay) * 1000
    
    if diff < 0.4 and diff > -0.1 and math.abs(offsetMs) < 120 then
        table.insert(ET_History, offsetMs)
        if #ET_History > ET_MaxHistory then table.remove(ET_History, 1) end
        local sum = 0; for _, v in ipairs(ET_History) do sum = sum + v end
        local avg = sum / #ET_History
        if math.abs(avg) > 5 then
            EnergyTickSettings.delay = math.max(0.05, math.min(0.6, EnergyTickSettings.delay + (avg/1000)*0.2))
        end
    end

    local halfWidth = IdealZone:GetWidth() / 2
    local markerX = (offsetMs / 120) * halfWidth
    local randomY = math.random(-7, 7)
    totalAttempts = totalAttempts + 1
    
    local bankKey = "Miss"
    local absX = math.abs(markerX)

    if absX <= halfWidth then
        if absX <= 4 then bankKey = "Elite"; okScore = okScore + 1.2
        elseif absX <= 10 then bankKey = "Master"; okScore = okScore + 1
        else bankKey = "Basic"; okScore = okScore + 0.5 end
    else bankKey = "Miss" end

    local idx = indices[bankKey]
    local d = banks[bankKey][idx]
    d:SetPoint("CENTER", IdealZone, "CENTER", -markerX, randomY); d:Show()
    indices[bankKey] = (idx % MAX_DOTS_PER_BANK) + 1

    local r, g, b = d.core:GetVertexColor()
    txtPct:SetTextColor(r, g, b)
    txtPct:SetText((totalAttempts > 0 and math.floor((okScore / totalAttempts) * 100) or 0).."%")
    txtMs:SetText(string.format("%+.0fms", offsetMs))
 end
end)

f:SetScript("OnUpdate", function(self, el)
 local now = GetTime(); local e, cp, maxE = UnitPower("player", 3), UnitPower("player", 4), UnitPowerMax("player", 3)
 local w = f:GetWidth() - 2; local _, _, _, worldLat = GetNetStats(); local latency = (worldLat or 0) / 1000
 visualE = visualE + (e - visualE) * math.min(1, el * 25)
 EnergyBar:SetWidth(math.max(1, w * (visualE / (maxE > 0 and maxE or 100))))
 local since = now - lastT
 local targetTime = 2 - EnergyTickSettings.delay - latency
 
 -- ВОЗВРАЩЕННАЯ ЛОГИКА СВЕЧЕНИЯ
 if e < 40 then IdealZone:SetBackdropBorderColor(0.7, 0.3, 0, 1); IdealNeon:Hide()
 elseif e >= 85 then
    local p = (math.sin(now * 12) + 1) / 2
    IdealZone:SetBackdropBorderColor(0.05, 0.3, 0.15, 1); IdealNeon:Show(); IdealNeon:SetBackdropBorderColor(0, 1, 0.5, 0.4 + (p * 0.5))
 elseif e >= 65 then IdealZone:SetBackdropBorderColor(0.2, 0.7, 0.3, 1); IdealNeon:Hide()
 elseif e >= 40 then IdealZone:SetBackdropBorderColor(0.8, 0.7, 0.3, 0.8); IdealNeon:Hide()
 end
 
 if txtEnergy then txtEnergy:SetText(e) end
 txtCP:SetPoint("BOTTOM", IdealZone, "TOP", 0, 4); txtCP:SetText(cp > 0 and cp or "")
 txtPct:SetPoint("TOP", IdealZone, "BOTTOM", 0, -2); txtMs:SetPoint("TOP", txtPct, "BOTTOM", 0, -1)
 IdealZone:SetPoint("CENTER", f, "LEFT", (w+2) * (targetTime / 2), 0)
 
 if since >= 2 then lastT = now - (since % 2); since = now - lastT; triggered = false end
 TickPulse:SetPoint("LEFT", f, "LEFT", (w+2) * (since / 2), 0)
 
 local diff = since - targetTime
 if diff < -0.3 then IdealLine:SetColorTexture(1, 0, 0, 0.2)
 elseif diff < 0 then local p = 1 - (math.abs(diff) / 0.3); IdealLine:SetColorTexture(1-p, p, 0, 0.3+(p*0.7))
 elseif diff < 0.10 then IdealLine:SetColorTexture(0, 1, 0.2, 1)
 else IdealLine:SetColorTexture(0.5, 0.3, 0, 0.4) end

 if (2 - since - latency) <= EnergyTickSettings.delay and not triggered then
  triggered = true; if UnitAffectingCombat("player") then PlaySound(EnergyTickSettings.soundID, "Ambience") end
 end
end)

local snd = CreateFrame("Frame", "ET_SND_Standalone", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
snd:SetSize(EnergyTickSettings.width, 10); snd:SetPoint("BOTTOM", f, "TOP", 0, 2)
snd:SetMovable(not EnergyTickSettings.locked); snd:EnableMouse(not EnergyTickSettings.locked); snd:RegisterForDrag("LeftButton")
snd:SetScript("OnDragStart", snd.StartMoving); snd:SetScript("OnDragStop", snd.StopMovingOrSizing)
snd:SetFrameStrata("MEDIUM"); snd:SetAlpha(0.6); snd:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" }); snd:SetBackdropColor(0, 0, 0, 0.5)
local sndMarker = snd:CreateTexture(nil, "OVERLAY"); sndMarker:SetSize(4, 8); sndMarker:SetColorTexture(0.9, 0.4, 0.2, 1)
snd:SetScript("OnUpdate", function(self)
 local now = GetTime(); local name, duration, expirationTime
 for i = 1, 40 do local n, _, _, _, d, e = UnitBuff("player", i); if n == "Slice and Dice" then name, duration, expirationTime = n, d, e; break end end
 local w = self:GetWidth() - 6; if name and expirationTime and expirationTime > 0 then
  local p = 1 - ((expirationTime - now) / (duration > 0 and duration or 30))
  sndMarker:Show(); sndMarker:SetPoint("LEFT", self, "LEFT", 1 + (w * p), 0)
 else sndMarker:Hide() end
end)

SLASH_ET1 = "/et"; SlashCmdList["ET"] = function(msg)
 if msg == "lock" then EnergyTickSettings.locked = not EnergyTickSettings.locked; f:SetMovable(not EnergyTickSettings.locked); f:EnableMouse(not EnergyTickSettings.locked); snd:SetMovable(not EnergyTickSettings.locked); snd:EnableMouse(not EnergyTickSettings.locked); print("ET: Locked")
 elseif msg == "reset" then snd:ClearAllPoints(); snd:SetPoint("BOTTOM", f, "TOP", 0, 2)
 else print("/et lock | /et reset") end
end

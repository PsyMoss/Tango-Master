-- =============================================
-- Блок: Unit Frames (Hybrid: Icons or Classic Bars)
-- =============================================

UF_Settings = UF_Settings or {
    width = 44, height = 22, locked = true,
    px = -100, py = -150, tx = 100, ty = -150,
    useIcons = false 
}

local isTesting = false
local MediaPath = "Interface\\AddOns\\RogueTick\\Media\\"

local DebuffColors = {
    ["Poison"]  = {r = 0,   g = 1,   b = 0},
    ["Curse"]   = {r = 0.8, g = 0,   b = 1},
    ["Disease"] = {r = 1,   g = 0.5, b = 0},
    ["Magic"]   = {r = 0,   g = 0.8, b = 1},
}

local function CreateHPBar(unitName, unitID, startX, startY)
    local f = CreateFrame("Frame", "ET_HP_"..unitName, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(UF_Settings.width, UF_Settings.height)
    f:SetPoint("CENTER", UIParent, "CENTER", startX, startY)
    f:SetFrameStrata("MEDIUM")
    
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if not UF_Settings.locked then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local _, _, _, x, y = self:GetPoint()
        if unitID == "player" then UF_Settings.px, UF_Settings.py = x, y else UF_Settings.tx, UF_Settings.ty = x, y end
    end)

    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    f:SetBackdropColor(0, 0, 0, 1)
    f:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)

    local hp = f:CreateTexture(nil, "ARTWORK")
    hp:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
    hp:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 2, 2)
    
    local icon = f:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints(f)

    f:SetScript("OnUpdate", function(self)
        local curPct, dType, stateColor = 1, nil, nil
        local iconFile = nil

        if isTesting then
            self:SetAlpha(1.0)
            if unitID == "player" then curPct, dType = 0.25, "Poison" else curPct, dType = 0.55, "Magic" end
        else
            if unitID == "target" and not UnitExists("target") then self:SetAlpha(0); return end
            
            if not UnitIsConnected(unitID) or UnitIsGhost(unitID) then
                stateColor = {0.25, 0.25, 0.25}
                iconFile = MediaPath.."icon_ghost"
            elseif UnitIsDead(unitID) then
                stateColor = {0.1, 0.1, 0.1}
                iconFile = MediaPath.."icon_dead"
            else
                local cur, max = UnitHealth(unitID), UnitHealthMax(unitID)
                curPct = (max > 0) and (cur / max) or 0
                
                if UF_Settings.useIcons then
                    local idx = math.ceil(curPct * 10); if idx < 1 then idx = 1 end
                    iconFile = MediaPath.."hp_"..idx
                end

                for i = 1, 40 do
                    local name, _, _, debType, _, _, caster = UnitDebuff(unitID, i)
                    if not name then break end
                    if debType and DebuffColors[debType] then
                        if unitID == "player" or caster == "player" then dType = debType; break end
                    end
                end
            end
            if not UnitAffectingCombat("player") and curPct >= 0.99 and not stateColor then self:SetAlpha(0.5) else self:SetAlpha(1.0) end
        end

        -- Визуализация
        if UF_Settings.useIcons then
            hp:Hide(); icon:Show()
            if iconFile then icon:SetTexture(iconFile) end
        else
            icon:Hide(); hp:Show()
            hp:SetWidth(math.max(1, (UF_Settings.width - 4) * curPct))
            if stateColor then
                hp:SetColorTexture(stateColor[1], stateColor[2], stateColor[3], 0.9)
            else
                local r, g, b
                if curPct > 0.7 then r, g, b = 0.35, 0.55, 0.15
                elseif curPct > 0.3 then r, g, b = 0.7, 0.45, 0.1
                else r, g, b = 0.65, 0.15, 0.15 end
                hp:SetColorTexture(r, g, b, 0.9)
            end
        end

        -- [[ ПЛАВНАЯ ВИБРАЦИЯ (АГОНИЯ) ]]
        if UF_Settings.locked then
            local anchorX = (unitID == "player") and UF_Settings.px or UF_Settings.tx
            local anchorY = (unitID == "player") and UF_Settings.py or UF_Settings.ty
            self:ClearAllPoints()

            if not stateColor and curPct < 0.35 and curPct > 0 then
                local t = GetTime()
                -- Сила пульсации растет при падении здоровья
                local power = (0.35 - curPct) * 25 
                
                -- Плавные волны через Sin/Cos
                local offsetX = math.sin(t * 18) * (power * 0.4)
                local offsetY = math.cos(t * 14) * (power * 0.3)
                
                -- Добавляем легкий высокочастотный "тремор"
                offsetX = offsetX + math.sin(t * 45) * 0.4
                
                self:SetPoint("CENTER", UIParent, "CENTER", anchorX + offsetX, anchorY + offsetY)
            else
                self:SetPoint("CENTER", UIParent, "CENTER", anchorX, anchorY)
            end
        end

        -- Каёмка дебаффа
        if dType and not stateColor then
            local c = DebuffColors[dType]
            local pulse = 0.6 + (math.sin(GetTime() * 8) * 0.4)
            self:SetBackdropBorderColor(c.r, c.g, c.b, pulse)
        else
            self:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)
        end
    end)
    return f
end

local HP_Player = CreateHPBar("Player", "player", UF_Settings.px, UF_Settings.py)
local HP_Target = CreateHPBar("Target", "target", UF_Settings.tx, UF_Settings.ty)

SLASH_RTH1 = "/rth"
SlashCmdList["RTH"] = function(msg)
    local cmd = msg:lower()
    if cmd == "mode" then
        UF_Settings.useIcons = not UF_Settings.useIcons
        print("|cffffff00RogueTick:|r Режим: "..(UF_Settings.useIcons and "ИКОНКИ" or "ПОЛОСКИ"))
    elseif cmd == "lock" then
        UF_Settings.locked = not UF_Settings.locked
        print("|cffffff00RogueTick:|r "..(UF_Settings.locked and "Заблокировано" or "Разблокировано"))
    elseif cmd == "test" then
        isTesting = true; C_Timer.After(5, function() isTesting = false end)
    end
end
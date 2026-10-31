--[[
    PallyMaster_Buffs
    Модуль назначения баффов: определение спеков, инспект, назначения, анонс.
--]]

local PM = _G.PallyMaster
local B = PM:NewModule("buffs")

-- ==================== LOCALE ====================
local L = {}
if GetLocale() == "ruRU" then
    L.title = "Назначение баффов паладинов"
    L.menuDirection = "Направление меню"; L.dirLeft = "Влево"; L.dirRight = "Вправо"
    L.menuAlpha = "Прозрачность меню"
    L.buffNameMode = "Название баффа в меню"
    L.bmIcon = "Иконка"; L.bmShort = "Сокращение"; L.bmFull = "Полное название"
    L.announceNameMode = "Название баффа в объявлении"; L.anShort = "Сокращение"; L.anFull = "Полное название"
    L.assign = "Назначить бафф"; L.unassign = "Снять все назначения"; L.announce = "Объявить"
    L.noPaladins = "Нет паладинов в группе"; L.allAssigned = "Все баффы назначены"
    L.assignedTo = "%s: %s"
    L.proto = "Прото-бафф"
    L.specUnknown = "Неизв."; L.specHoly = "Свет"; L.specProt = "Защита"; L.specRet = "Воздаяние"
    L.shortKings = "Каска"; L.shortMight = "Кулак"; L.shortWisdom = "Крест"
    L.shortProto = "Прото"
    L.secMenu = "Меню"; L.secNames = "Названия"
else
    L.title = "Paladin Buff Assign"
    L.menuDirection = "Menu direction"; L.dirLeft = "Left"; L.dirRight = "Right"
    L.menuAlpha = "Menu alpha"
    L.buffNameMode = "Buff name in menu"
    L.bmIcon = "Icon"; L.bmShort = "Short name"; L.bmFull = "Full name"
    L.announceNameMode = "Buff name in announce"; L.anShort = "Short name"; L.anFull = "Full name"
    L.assign = "Assign buff"; L.unassign = "Unassign all"; L.announce = "Announce"
    L.noPaladins = "No paladins in group"; L.allAssigned = "All buffs assigned"
    L.assignedTo = "%s: %s"
    L.proto = "Proto-buff"
    L.specUnknown = "Unknown"; L.specHoly = "Holy"; L.specProt = "Protection"; L.specRet = "Retribution"
    L.shortKings = "Kings"; L.shortMight = "Might"; L.shortWisdom = "Wisdom"
    L.shortProto = "Proto"
    L.secMenu = "Menu"; L.secNames = "Names"
end
B.L = L

-- ==================== BUFF DEFINITIONS ====================
local BUFF_POOL = {
    { key = "kings",  id = 20217, name = GetSpellInfo(20217) or "Blessing of Kings",  icon = "Interface\\Icons\\Spell_Magic_MageArmor",         short = L.shortKings },
    { key = "might",  id = 19838, name = GetSpellInfo(19838) or "Blessing of Might",  icon = "Interface\\Icons\\Spell_Holy_FistOfJustice",      short = L.shortMight },
    { key = "wisdom", id = 19742, name = GetSpellInfo(19742) or "Blessing of Wisdom", icon = "Interface\\Icons\\Spell_Holy_SealOfWisdom",       short = L.shortWisdom },
    { key = "proto",  id = 20911, name = L.proto,                                     icon = "Interface\\Icons\\Spell_nature_lightningshield", short = L.shortProto },
}
B.BUFF_POOL = BUFF_POOL
local BUFF_KEY_ORDER = { "kings", "might", "wisdom", "proto" }
local BUFF_DISPLAY, BUFF_SHORT = {}, {}
for _, b in ipairs(BUFF_POOL) do
    BUFF_DISPLAY[b.key] = b.name
    BUFF_SHORT[b.key] = b.short
end

-- ==================== SPEC DETECTION ====================
local LibGroupTalents = LibStub and LibStub("LibGroupTalents-1.0", true)
local LibTalentQuery  = LibStub and LibStub("LibTalentQuery-1.0", true)

local function GetTalentPoints(tab, isInspect, group)
    local ok, _, _, pointsSpent = pcall(GetTalentTabInfo, tab, isInspect, nil, group)
    if not ok then return 0 end
    return pointsSpent or 0
end

local function SpecFromPoints(x, y, z)
    if x == 0 and y == 0 and z == 0 then return nil end
    if x > y and x > z then return "Holy" end
    if y > x and y > z then return "Protection" end
    if z > x and z > y then return "Retribution" end
    if x > 0 then return "Holy" end
    if y > 0 then return "Protection" end
    if z > 0 then return "Retribution" end
    return nil
end

local function GetPlayerSpecViaTalents()
    local tg = GetActiveTalentGroup(false) or 1
    return SpecFromPoints(
        GetTalentPoints(1, false, tg),
        GetTalentPoints(2, false, tg),
        GetTalentPoints(3, false, tg)
    )
end

local function GetInspectedSpec()
    local activeGroup = 1
    if GetActiveTalentGroup then
        local ok, g = pcall(GetActiveTalentGroup, true)
        if ok and (g == 1 or g == 2) then activeGroup = g end
    end

    local h = GetTalentPoints(1, true, activeGroup)
    local p = GetTalentPoints(2, true, activeGroup)
    local r = GetTalentPoints(3, true, activeGroup)
    if (h + p + r) > 0 then
        return SpecFromPoints(h, p, r), { h, p, r }, activeGroup
    end

    for group = 1, 2 do
        if group ~= activeGroup then
            local gh = GetTalentPoints(1, true, group)
            local gp = GetTalentPoints(2, true, group)
            local gr = GetTalentPoints(3, true, group)
            if (gh + gp + gr) > 0 then
                return SpecFromPoints(gh, gp, gr), { gh, gp, gr }, group
            end
        end
    end

    return nil, nil, activeGroup
end

local SPEC_SPELLBOOK_NAMES = {
    ["Holy Shock"] = "Holy", ["Шок Света"] = "Holy", ["Святой шок"] = "Holy",
    ["Beacon of Light"] = "Holy", ["Маяк Света"] = "Holy",
    ["Avenger's Shield"] = "Protection", ["Щит мстителя"] = "Protection", ["Щит Мстителя"] = "Protection",
    ["Hammer of the Righteous"] = "Protection", ["Молот праведности"] = "Protection",
    ["Crusader Strike"] = "Retribution", ["Удар крестоносца"] = "Retribution", ["Удар Крестоносца"] = "Retribution",
    ["Divine Storm"] = "Retribution", ["Божественная буря"] = "Retribution",
}

local function ScanSpellbookForSpec()
    if IsSpellKnown and IsSpellKnown(35395) then return "Retribution" end
    if IsSpellKnown and IsSpellKnown(31935) then return "Protection" end
    if IsSpellKnown and IsSpellKnown(20473) then return "Holy" end
    local numTabs = GetNumSpellTabs and GetNumSpellTabs() or 0
    for tabIndex = 1, numTabs do
        local _, _, offset, numSpells = GetSpellTabInfo(tabIndex)
        if offset and numSpells then
            for i = offset + 1, offset + numSpells do
                local name = GetSpellBookItemName(i, BOOKTYPE_SPELL)
                if name and SPEC_SPELLBOOK_NAMES[name] then
                    return SPEC_SPELLBOOK_NAMES[name]
                end
            end
        end
    end
    return nil
end

-- Только спеко-эксклюзивные способности/таланты: по ним можно понять спек
-- по аурам. Обычные заклинания паладина (Праведный гнев есть у всех) сюда
-- попадать не должны — иначе спек «прыгает».
local SPEC_SPELL_NAMES = {
    ["Holy Shield"] = "Protection",
    ["Avenger's Shield"] = "Protection", ["Shield of Righteousness"] = "Protection",
    ["Hammer of the Righteous"] = "Protection",
    ["Holy Shock"] = "Holy", ["Beacon of Light"] = "Holy", ["Light's Grace"] = "Holy",
    ["Crusader Strike"] = "Retribution", ["Divine Storm"] = "Retribution",
    ["Repentance"] = "Retribution", ["Seal of Command"] = "Retribution",
}
SPEC_SPELL_NAMES["Святой щит"] = "Protection"
SPEC_SPELL_NAMES["Щит правосудия"] = "Protection"
SPEC_SPELL_NAMES["Молот праведности"] = "Protection"
SPEC_SPELL_NAMES["Молния Света"] = "Holy"
SPEC_SPELL_NAMES["Маяк Света"] = "Holy"
SPEC_SPELL_NAMES["Благодать Света"] = "Holy"
SPEC_SPELL_NAMES["Удар крестоносца"] = "Retribution"
SPEC_SPELL_NAMES["Божественная буря"] = "Retribution"
SPEC_SPELL_NAMES["Покаяние"] = "Retribution"
SPEC_SPELL_NAMES["Печать повеления"] = "Retribution"

local function ScanUnitForSpecAuras(unit)
    for i = 1, 40 do
        local name = UnitBuff(unit, i); if not name then break end
        if SPEC_SPELL_NAMES[name] then return SPEC_SPELL_NAMES[name] end
    end
    for i = 1, 40 do
        local name = UnitDebuff(unit, i); if not name then break end
        if SPEC_SPELL_NAMES[name] then return SPEC_SPELL_NAMES[name] end
    end
    return nil
end

local function SpecFromLibName(treeOrName)
    if not treeOrName then return nil end
    if type(treeOrName) == "number" then
        if treeOrName == 1 then return "Holy" end
        if treeOrName == 2 then return "Protection" end
        if treeOrName == 3 then return "Retribution" end
        return nil
    end
    local s = string.lower(tostring(treeOrName))
    if s == "holy" or s == "свет" then return "Holy" end
    if s == "protection" or s == "защита" then return "Protection" end
    if s == "retribution" or s == "воздаяние" then return "Retribution" end
    return nil
end

local function GetSpecFromLib(unit)
    if not LibGroupTalents then return nil end
    local ok, tree = pcall(function() return LibGroupTalents:GetUnitTalentSpec(unit) end)
    if not ok then return nil end
    return SpecFromLibName(tree)
end

-- Возвращает спек и источник данных:
--   talent    — инспект талантов (самый надёжный),
--   spellbook — книга заклинаний (только игрок),
--   lib       — LibGroupTalents,
--   aura      — эвристика по аурам.
local function GetSpecForUnit(unit)
    if unit == "player" then
        local spec = ScanSpellbookForSpec()
        if spec then return spec, "spellbook" end
        spec = GetPlayerSpecViaTalents()
        if spec then return spec, "talent" end
        spec = GetSpecFromLib(unit)
        if spec then return spec, "lib" end
        spec = ScanUnitForSpecAuras(unit)
        if spec then return spec, "aura" end
        return nil
    end
    local spec = GetSpecFromLib(unit)
    if spec then return spec, "lib" end
    spec = ScanUnitForSpecAuras(unit)
    if spec then return spec, "aura" end
    return nil
end

-- ==================== SETTINGS ====================
function B:GetDefaults()
    return {
        version         = 3,
        enabled         = true,
        hideInCombat    = false,
        groupOnly       = false,
        menuDirection   = "right",
        buffNameMode    = "icon",
        announceNameMode = "short",
        width           = 220,
        scale           = 1.0,
        spacing         = 4,
        iconSize        = 0,
        fontSize        = 12,
        barColor        = "spec",
        barAlpha        = 0.85,
        menuAlpha       = 0.90,
        locked          = true,
        point           = "CENTER",
        relPoint        = "CENTER",
        x               = 0,
        y               = 0,
        assignments     = {},
    }
end

-- ==================== STATE ====================
B.paladins = {}
B.assignments = {}
B.specCache = {}
B._debugInspect = false
B._lastRosterHash = nil
local inspectQueue = {}
local _currentInspect = nil

local REINSPECT_INTERVAL = 15
local MAX_ATTEMPTS = 10

-- ==================== INSPECT RANGE ====================
local function IsInspectable(unit)
    if not UnitExists(unit) then return false end
    if not UnitIsConnected(unit) then return false end
    if CanInspect then
        local ok, res = pcall(CanInspect, unit)
        if ok and res == false then return false end
    end
    if CheckInteractDistance then
        local ok, res = pcall(CheckInteractDistance, unit, 4)
        if ok and res == false then return false end
    end
    return true
end

-- ==================== SPEC CACHE ====================
-- В кэше храним не только спек, но и источник: значение из инспекта
-- не должно перетираться догадкой по аурам.
local function CacheSpec(unit, spec, source)
    if not spec then return end
    local guid = UnitGUID(unit)
    if guid then B.specCache[guid] = { spec = spec, source = source } end
end

local function GetCachedSpec(unit)
    local guid = UnitGUID(unit)
    local entry = guid and B.specCache[guid]
    if type(entry) == "table" then return entry.spec, entry.source end
    return entry, nil
end

-- ==================== ROSTER ====================
-- Насколько источнику можно доверять. Спек, полученный из талантов или книги
-- заклинаний, не должен затираться догадкой по аурам — иначе полоски мигают.
local SPEC_WEIGHT = { talent = 3, spellbook = 3, lib = 2, aura = 1 }

-- Единая точка изменения спека. Возвращает true, если спек реально изменился.
function B:SetSpec(name, spec, source)
    if not spec then return false end
    local p = B.paladins[name]
    if not p then return false end

    source = source or "aura"
    local w = SPEC_WEIGHT[source] or 1
    local oldW = SPEC_WEIGHT[p.specSource or ""] or 0

    if p.spec == spec then
        p.pendingSpec, p.pendingCount = nil, 0
        if w > oldW then p.specSource = source end
        return false
    end

    -- источник слабее уже известного — не трогаем спек
    if p.spec and w < oldW then return false end

    -- Источник того же уровня: смену принимаем только после двух подряд
    -- одинаковых показаний, чтобы эвристика не дёргала полоску. Данные
    -- инспекта и книги заклинаний авторитетны — применяем сразу.
    if p.spec and w == oldW and w < 3 then
        if p.pendingSpec == spec then
            p.pendingCount = (p.pendingCount or 0) + 1
        else
            p.pendingSpec, p.pendingCount = spec, 1
        end
        if (p.pendingCount or 0) < 2 then return false end
    end
    p.pendingSpec, p.pendingCount = nil, 0

    local changed = (p.spec ~= spec)
    p.spec = spec
    p.specSource = source
    CacheSpec(p.unit, spec, source)

    -- Назначение «Прото» меняем только по надёжным данным (инспект, книга,
    -- библиотека): догадка по аурам не должна снимать назначение.
    if w >= 2 then
        p.buffs = p.buffs or {}
        if spec ~= "Protection" then
            if B.assignments["proto"] == name then
                B.assignments["proto"] = nil
                p.buffs["proto"] = nil
                changed = true
            end
            if B.db and B.db.assignments and B.db.assignments["proto"] == name then
                B.db.assignments["proto"] = nil
                changed = true
            end
        elseif not B.assignments["proto"]
            and B.db and B.db.assignments and B.db.assignments["proto"] == name then
            p.buffs["proto"] = true
            B.assignments["proto"] = name
            changed = true
        end
    end
    return changed
end

function B:UpdateRoster()
    local units = PM:GetPaladinUnits()

    local parts = {}
    for _, unit in ipairs(units) do parts[#parts + 1] = UnitGUID(unit) or "?" end
    local hash = table.concat(parts, ";")

    local knownCount = 0
    for _ in pairs(B.paladins) do knownCount = knownCount + 1 end

    if hash == B._lastRosterHash and #units == knownCount then
        local allKnown = true
        for _, unit in ipairs(units) do
            local name = UnitName(unit)
            local p = name and B.paladins[name]
            if not p or not p.spec then allKnown = false; break end
        end
        if allKnown then return end
    end
    B._lastRosterHash = hash

    local seen = {}
    for _, unit in ipairs(units) do
        local name = UnitName(unit)
        if name then
            seen[name] = true
            local existing = B.paladins[name]
            if not existing then
                existing = { unit = unit, buffs = {} }
                B.paladins[name] = existing
            else
                existing.unit = unit
            end

            local spec, source = GetSpecForUnit(unit)
            if not spec then
                spec, source = GetCachedSpec(unit)
            end
            if spec then
                B:SetSpec(name, spec, source)
            end
            if existing.spec then
                CacheSpec(unit, existing.spec, existing.specSource)
            end
        end
    end

    for name in pairs(B.paladins) do
        if not seen[name] then B.paladins[name] = nil end
    end

    for _, p in pairs(B.paladins) do p.buffs = {} end
    wipe(B.assignments)
    local d = B.db
    if d then
        for buffKey, pname in pairs(d.assignments or {}) do
            local p = B.paladins[pname]
            if p then
                if buffKey == "proto" then
                    if p.spec == "Protection" then
                        p.buffs[buffKey] = true
                        B.assignments[buffKey] = pname
                    elseif p.spec then
                        d.assignments[buffKey] = nil
                    end
                else
                    p.buffs[buffKey] = true
                    B.assignments[buffKey] = pname
                end
            end
        end
    end

    local needed = {}
    for _, p in pairs(B.paladins) do
        if p.unit ~= "player" and not p.spec then needed[p.unit] = true end
    end
    for unit in pairs(inspectQueue) do
        if not needed[unit] and not inspectQueue[unit].recheck then
            inspectQueue[unit] = nil
        end
    end
    for unit in pairs(needed) do
        if not inspectQueue[unit] then inspectQueue[unit] = { attempts = 0 } end
    end

    self:RebuildBars()
    self:ApplyFrameSettings()
    self:UpdateAnnounceButton()
end

-- ==================== LIBGROUPTALENTS CALLBACK ====================
if LibGroupTalents then
    pcall(function()
        LibGroupTalents:RegisterCallback("LibGroupTalents_Update",
            function(owner, guid, unit, newSpec)
                local name = unit and UnitName(unit)
                if not name then
                    for pname, p in pairs(B.paladins) do
                        if UnitGUID(p.unit) == guid then name = pname; break end
                    end
                end
                if not name then return end
                local spec = SpecFromLibName(newSpec)
                if spec and B:SetSpec(name, spec, "lib") then
                    B:RebuildBars()
                end
            end)
    end)
end

-- ==================== PERIODIC RESCAN (только player) ====================
local specRescanT = 0
local specRescanFrame = CreateFrame("Frame")
specRescanFrame:SetScript("OnUpdate", function(self, el)
    if not B.db or not B.db.enabled then return end
    specRescanT = specRescanT + el
    if specRescanT < 5 then return end
    specRescanT = 0
    local changed = false
    for name, p in pairs(B.paladins) do
        if p.unit == "player" then
            local spec, source = ScanSpellbookForSpec(), "spellbook"
            if not spec then spec, source = GetPlayerSpecViaTalents(), "talent" end
            if spec and B:SetSpec(name, spec, source) then changed = true end
        end
    end
    if changed then B:RebuildBars() end
end)

-- ==================== DIRECT INSPECT FALLBACK ====================
local inspectFrame = CreateFrame("Frame")
inspectFrame:RegisterEvent("INSPECT_TALENT_READY")
pcall(function() inspectFrame:RegisterEvent("INSPECT_READY") end)

local function ResolveInspectedUnit(arg1)
    if type(arg1) == "string" and #arg1 > 0 then
        if arg1:match("^party%d") or arg1:match("^raid%d") or arg1 == "player" then
            return arg1
        end
        if #arg1 >= 10 then
            for _, p in pairs(B.paladins) do
                if UnitGUID(p.unit) == arg1 then return p.unit end
            end
            if GetNumRaidMembers and GetNumRaidMembers() > 0 then
                for i = 1, GetNumRaidMembers() do
                    local u = "raid" .. i
                    if UnitExists(u) and UnitGUID(u) == arg1 then return u end
                end
            elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then
                if UnitExists("player") and UnitGUID("player") == arg1 then return "player" end
                for i = 1, GetNumPartyMembers() do
                    local u = "party" .. i
                    if UnitExists(u) and UnitGUID(u) == arg1 then return u end
                end
            end
            return nil
        end
        return nil
    end
    if _currentInspect then return _currentInspect.unit end
    return nil
end

local function TryProcessInspectedUnit(unit)
    if not unit then return false end
    local name = UnitName(unit)
    if not name then return false end
    local spec, pts, group = GetInspectedSpec()
    local pal = B.paladins[name]

    if B._debugInspect then
        local ptxt = pts and (pts[1] .. "/" .. pts[2] .. "/" .. pts[3]) or "0/0/0"
        DEFAULT_CHAT_FRAME:AddMessage("|cff00AAFFPallyMaster inspect|r " .. name
            .. " pts=" .. ptxt .. " group=" .. tostring(group)
            .. " old=" .. tostring(pal and pal.spec))
    end

    if not spec then return false end

    if pal then
        local oldSpec = pal.spec
        local oldPoints = pal.lastPoints
        local pointsChanged = (not oldPoints)
            or oldPoints[1] ~= pts[1] or oldPoints[2] ~= pts[2] or oldPoints[3] ~= pts[3]

        pal.lastPoints = pts
        pal.lastInspect = GetTime()
        local specChanged = B:SetSpec(name, spec, "talent")

        if specChanged and B._debugInspect then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00PallyMaster spec CHANGE|r " .. name
                .. ": " .. tostring(oldSpec) .. " -> " .. spec)
        end

        if specChanged or pointsChanged then
            B:RebuildBars()
        end
    end

    inspectQueue[unit] = nil
    return true
end

inspectFrame:SetScript("OnEvent", function(self, event, arg1)
    local unit = ResolveInspectedUnit(arg1)
    if not unit then return end

    if not arg1 and _currentInspect and _currentInspect.unit == unit then
        if not IsInspectable(unit) then return end
    end

    local ok = TryProcessInspectedUnit(unit)

    if _currentInspect and _currentInspect.unit == unit then
        if ok then
            _currentInspect = nil
        else
            inspectQueue[unit] = nil
            _currentInspect = nil
        end
    end
end)

local inspectTimer = 0
inspectFrame:SetScript("OnUpdate", function(self, el)
    if not B.db or not B.db.enabled then return end

    if _currentInspect then
        local age = GetTime() - _currentInspect.requestedAt
        if age > 10 then
            inspectQueue[_currentInspect.unit] = nil
            _currentInspect = nil
        else
            return
        end
    end

    inspectTimer = inspectTimer + el
    if inspectTimer < 4.0 then return end
    inspectTimer = 0

    for unit, info in pairs(inspectQueue) do
        local name = UnitName(unit)
        local p = name and B.paladins[name]
        if not p then
            inspectQueue[unit] = nil
        elseif not info.recheck and p.spec then
            inspectQueue[unit] = nil
        elseif info.attempts >= MAX_ATTEMPTS then
            inspectQueue[unit] = nil
        elseif not IsInspectable(unit) then
            if B._debugInspect and not info._rangeLogged then
                DEFAULT_CHAT_FRAME:AddMessage("|cffFFAA00PallyMaster|r " .. tostring(name)
                    .. " out of inspect range, will retry when in range")
                info._rangeLogged = true
            end
        else
            info._rangeLogged = false
            info.attempts = info.attempts + 1
            _currentInspect = { unit = unit, requestedAt = GetTime() }
            if type(ClearInspectPlayer) == "function" then
                pcall(ClearInspectPlayer)
            end
            NotifyInspect(unit)
            return
        end
    end
end)

-- ==================== PERIODIC RE-INSPECT ====================
local reinspectTimer = 0
local reinspectFrame = CreateFrame("Frame")
reinspectFrame:SetScript("OnUpdate", function(self, el)
    if not B.db or not B.db.enabled then return end
    reinspectTimer = reinspectTimer + el
    if reinspectTimer < REINSPECT_INTERVAL then return end
    reinspectTimer = 0
    local now = GetTime()
    for name, p in pairs(B.paladins) do
        if p.unit ~= "player" then
            local lastT = p.lastInspect or 0
            if (now - lastT) > REINSPECT_INTERVAL then
                if not inspectQueue[p.unit] then
                    inspectQueue[p.unit] = { attempts = 0, recheck = true }
                end
            end
        end
    end
end)

-- ==================== ASSIGNMENT LOGIC ====================
function B:IsBuffAvailable(buffKey, paladinName)
    if buffKey == "proto" then
        local p = paladinName and B.paladins[paladinName]
        return (p and p.spec == "Protection") and true or false
    end
    return true
end

function B:GetAssignableBuffs(forPaladinName)
    local result = {}
    for _, buff in ipairs(BUFF_POOL) do
        if self:IsBuffAvailable(buff.key, forPaladinName) then
            local owner = B.assignments[buff.key]
            if not owner or owner == forPaladinName then result[#result + 1] = buff.key end
        end
    end
    return result
end

function B:HasBuff(paladinName, buffKey)
    local p = B.paladins[paladinName]
    return p and p.buffs[buffKey] == true
end

function B:AssignBuff(paladinName, buffKey)
    local p = B.paladins[paladinName]
    if not p or not self:IsBuffAvailable(buffKey, paladinName) then return end
    if p.buffs[buffKey] then
        B.assignments[buffKey] = nil; p.buffs[buffKey] = nil
        if B.db.assignments then B.db.assignments[buffKey] = nil end
        B:RebuildBars(); B:UpdateAnnounceButton(); return
    end
    local prevOwner = B.assignments[buffKey]
    if prevOwner and prevOwner ~= paladinName and B.paladins[prevOwner] then
        B.paladins[prevOwner].buffs[buffKey] = nil
    end
    p.buffs[buffKey] = true
    B.assignments[buffKey] = paladinName
    if B.db then
        B.db.assignments = B.db.assignments or {}
        B.db.assignments[buffKey] = paladinName
    end
    B:RebuildBars(); B:UpdateAnnounceButton()
end

function B:UnassignBuff(paladinName, buffKey)
    local p = B.paladins[paladinName]
    if not p or not p.buffs[buffKey] then return end
    B.assignments[buffKey] = nil; p.buffs[buffKey] = nil
    if B.db.assignments then B.db.assignments[buffKey] = nil end
    B:RebuildBars(); B:UpdateAnnounceButton()
end

function B:UnassignAllBuffs(paladinName)
    local p = B.paladins[paladinName]; if not p then return end
    for _, bk in ipairs(self:GetPaladinBuffs(paladinName)) do
        B.assignments[bk] = nil; p.buffs[bk] = nil
        if B.db.assignments then B.db.assignments[bk] = nil end
    end
    B:RebuildBars(); B:UpdateAnnounceButton()
end

function B:AnyBuffAssigned()
    for _, p in pairs(B.paladins) do
        if p.buffs and next(p.buffs) then return true end
    end
    return false
end

function B:GetAssignedPaladin(buffKey) return B.assignments[buffKey] end

function B:GetPaladinBuffs(paladinName)
    local p = B.paladins[paladinName]; if not p then return {} end
    local r = {}
    for k, v in pairs(p.buffs) do if v then r[#r + 1] = k end end
    return r
end

function B:FormatBuffName(buffKey, mode)
    if mode == "icon" then return "" end
    if mode == "short" then return BUFF_SHORT[buffKey] or buffKey end
    return BUFF_DISPLAY[buffKey] or buffKey
end

function B:GetBuffIcon(buffKey)
    for _, b in ipairs(BUFF_POOL) do if b.key == buffKey then return b.icon end end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function B:FormatBuffNameAnnounce(buffKey)
    local mode = B.db.announceNameMode or "short"
    if mode == "short" then return BUFF_SHORT[buffKey] or buffKey end
    return BUFF_DISPLAY[buffKey] or buffKey
end

function B:GetSpecName(spec)
    if spec == "Protection" then return L.specProt end
    if spec == "Holy" then return L.specHoly end
    if spec == "Retribution" then return L.specRet end
    return L.specUnknown
end

function B:GetSpecIcon(spec)
    if spec == "Holy" then return "Interface\\Icons\\Spell_Holy_HolyBolt" end
    if spec == "Protection" then return "Interface\\Icons\\Spell_Holy_DevotionAura" end
    if spec == "Retribution" then return "Interface\\Icons\\Spell_Holy_AuraOfLight" end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- ==================== ANNOUNCE ====================
local function IsPlayerRaidLeaderOrAssistant()
    if not GetNumRaidMembers or GetNumRaidMembers() == 0 then
        return false
    end
    if IsRaidLeader then
        local ok, res = pcall(IsRaidLeader)
        if ok and (res == 1 or res == true) then return true end
    end
    if IsRaidOfficer then
        local ok, res = pcall(IsRaidOfficer)
        if ok and (res == 1 or res == true) then return true end
    end
    local myName = UnitName("player")
    if myName and GetRaidRosterInfo then
        for i = 1, GetNumRaidMembers() do
            local name, rank = GetRaidRosterInfo(i)
            if name == myName and rank and rank >= 1 then
                return true
            end
        end
    end
    if UnitIsGroupLeader then
        local ok, res = pcall(UnitIsGroupLeader, "player")
        if ok and (res == 1 or res == true) then return true end
    end
    if UnitIsGroupAssistant then
        local ok, res = pcall(UnitIsGroupAssistant, "player")
        if ok and (res == 1 or res == true) then return true end
    end
    return false
end

-- Одиночный | в тексте — escape-префикс WoW, из-за него SendChatMessage
-- бросает "Invalid escape code". Заменяем на '!', если встретился.
local function SanitizeLine(s)
    if not s then return s end
    return (s:gsub("|([^cCrHh])", "!%1"))
end

local function ChatPrefix()
    return "|cffFF7D0A" .. PM.ADDON .. "|r"
end

function B:BuildAnnounceLines()
    local entries = {}
    for name in pairs(B.paladins) do
        local buffs = {}
        for _, buffKey in ipairs(BUFF_KEY_ORDER) do
            if self:IsBuffAvailable(buffKey, name) and B.assignments[buffKey] == name then
                buffs[#buffs + 1] = B:FormatBuffNameAnnounce(buffKey)
            end
        end
        if #buffs > 0 then
            entries[#entries + 1] = { name = name, text = table.concat(buffs, ", ") }
        end
    end
    table.sort(entries, function(a, b) return a.name < b.name end)
    local lines = {}
    for _, entry in ipairs(entries) do
        local line = string.format(L.assignedTo, entry.name, entry.text)
        lines[#lines + 1] = SanitizeLine(line)
    end
    return lines
end

-- ==================== ANNOUNCE MESSAGE ====================
-- Объявление уходит одним сообщением: строки склеиваются через "; ".
-- Несколько SendChatMessage подряд клиент съедает антифлудом (в рейде
-- проходит 2-3, остальные пропадают), поэтому шлём один SendChatMessage.
-- Лимит чата — 255 байт, кириллица занимает 2 байта на символ. Держимся
-- 240 байт: в обычном рейде все паладины влезают, а если нет — остаток
-- уйдёт следующим сообщением (редкий случай, страховка от обрезки).
local MAX_CHAT_BYTES = 240
local LINE_SEPARATOR = "; "

local function PackAnnounce(lines)
    local chunks = { "" }
    for _, line in ipairs(lines) do
        if #line > MAX_CHAT_BYTES then
            local cut = line:sub(1, MAX_CHAT_BYTES - 3)
            local sp = cut:match("^.*()%s")
            if sp and sp > 1 then cut = cut:sub(1, sp - 1) end
            line = cut .. "..."
        end
        local cur = chunks[#chunks]
        local candidate = (cur == "") and line or (cur .. LINE_SEPARATOR .. line)
        if #candidate <= MAX_CHAT_BYTES then
            chunks[#chunks] = candidate
        else
            chunks[#chunks + 1] = line
        end
    end
    if chunks[#chunks] == "" then table.remove(chunks) end
    return chunks
end

-- Очередь нужна только для остатка, который не влез в лимит чата.
local sendQueue = {}
local sendElapsed = 0
local SEND_INTERVAL = { RAID_WARNING = 2.0, RAID = 1.0, PARTY = 1.0 }

local sendFrame = CreateFrame("Frame")
sendFrame:SetScript("OnUpdate", function(_, el)
    if #sendQueue == 0 then return end
    sendElapsed = sendElapsed + el
    local msg = sendQueue[1]
    if sendElapsed < msg.delay then return end
    sendElapsed = 0
    table.remove(sendQueue, 1)
    SendChatMessage(msg.text, msg.channel)
end)

function B:Announce()
    if not self:AnyBuffAssigned() then return end

    local lines = self:BuildAnnounceLines()
    if #lines == 0 then return end

    local chunks = PackAnnounce(lines)

    -- Новый анонс отменяет недоотправленный остаток предыдущего.
    wipe(sendQueue)
    sendElapsed = 0

    local inRaid  = (GetNumRaidMembers()  > 0) or UnitExists("raid1")
    local inParty = (GetNumPartyMembers() > 0) or UnitExists("party1")

    -- Вне группы — только локальный чат.
    if not inRaid and not inParty then
        for _, chunk in ipairs(chunks) do
            DEFAULT_CHAT_FRAME:AddMessage(ChatPrefix() .. ": " .. chunk)
        end
        return
    end

    -- Авто: в рейде RW для лидера/помощника, иначе RAID/PARTY.
    local channel
    if inRaid then
        channel = IsPlayerRaidLeaderOrAssistant() and "RAID_WARNING" or "RAID"
    else
        channel = "PARTY"
    end

    -- Основное объявление — сразу и одним сообщением.
    SendChatMessage(chunks[1], channel)
    for i = 2, #chunks do
        sendQueue[#sendQueue + 1] = {
            text = chunks[i],
            channel = channel,
            delay = SEND_INTERVAL[channel] or 1.0,
        }
    end
end

function B:AnnounceTest()
    local lines = self:BuildAnnounceLines()
    if #lines == 0 then
        DEFAULT_CHAT_FRAME:AddMessage(ChatPrefix() .. " announcetest: buffs not assigned")
        return
    end
    local chunks = PackAnnounce(lines)
    local inRaid  = (GetNumRaidMembers()  > 0) or UnitExists("raid1")
    local inParty = (GetNumPartyMembers() > 0) or UnitExists("party1")
    local canRW = IsPlayerRaidLeaderOrAssistant()

    DEFAULT_CHAT_FRAME:AddMessage(ChatPrefix() .. " announcetest:")
    DEFAULT_CHAT_FRAME:AddMessage("  inRaid=" .. tostring(inRaid)
        .. " inParty=" .. tostring(inParty)
        .. " canRW=" .. tostring(canRW)
        .. " entries=" .. #lines
        .. " messages=" .. #chunks)

    local plan
    if inRaid then
        if canRW then plan = "RAID_WARNING, one message"
        else plan = "RAID, one message" end
    elseif inParty then
        plan = "PARTY, one message"
    else
        plan = "local chat"
    end
    DEFAULT_CHAT_FRAME:AddMessage("  channel: " .. plan)

    for i, chunk in ipairs(chunks) do
        DEFAULT_CHAT_FRAME:AddMessage("  [" .. i .. "] (" .. #chunk .. "b) " .. chunk)
    end
end

function B:WhoAmI()
    local inRaid = (GetNumRaidMembers() or 0) > 0
    local inParty = (GetNumPartyMembers() or 0) > 0
    local isLeader, isOfficer = false, false
    if IsRaidLeader then
        local ok, res = pcall(IsRaidLeader)
        if ok and (res == 1 or res == true) then isLeader = true end
    end
    if IsRaidOfficer then
        local ok, res = pcall(IsRaidOfficer)
        if ok and (res == 1 or res == true) then isOfficer = true end
    end
    local rank = 0
    local myName = UnitName("player")
    if inRaid and GetRaidRosterInfo and myName then
        for i = 1, GetNumRaidMembers() do
            local n, r = GetRaidRosterInfo(i)
            if n == myName then rank = r or 0; break end
        end
    end
    local canRW = IsPlayerRaidLeaderOrAssistant()
    local willUse = "local chat"
    if inRaid then
        willUse = canRW and "RAID_WARNING (/rw)" or "RAID (/raid)"
    elseif inParty then
        willUse = "PARTY"
    end
    DEFAULT_CHAT_FRAME:AddMessage(ChatPrefix() .. " whoami:")
    DEFAULT_CHAT_FRAME:AddMessage("  raid=" .. tostring(inRaid)
        .. " party=" .. tostring(inParty)
        .. " IsRaidLeader=" .. tostring(isLeader)
        .. " IsRaidOfficer=" .. tostring(isOfficer)
        .. " rosterRank=" .. tostring(rank))
    DEFAULT_CHAT_FRAME:AddMessage("  Can use RAID_WARNING: " .. tostring(canRW))
    DEFAULT_CHAT_FRAME:AddMessage("  Next announce channel: " .. willUse)
end

function B:ResetSpecCache()
    wipe(B.specCache)
    B._lastRosterHash = nil
    _currentInspect = nil
    if type(ClearInspectPlayer) == "function" then
        pcall(ClearInspectPlayer)
    end
    for _, p in pairs(B.paladins) do
        if p.unit ~= "player" then
            p.spec = nil
            p.specSource = nil
            p.pendingSpec, p.pendingCount = nil, 0
            p.lastInspect = nil
            p.lastPoints = nil
            inspectQueue[p.unit] = { attempts = 0, recheck = true }
        end
    end
    B:RebuildBars()
    PM:Print("spec cache cleared, re-inspecting")
end

function B:PrintDebug()
    local f = DEFAULT_CHAT_FRAME.AddMessage
    f(DEFAULT_CHAT_FRAME, ChatPrefix() .. " debug:")
    f(DEFAULT_CHAT_FRAME, "  LibStub: " .. (LibStub and "OK" or "MISSING"))
    f(DEFAULT_CHAT_FRAME, "  LibTalentQuery-1.0: " .. (LibTalentQuery and "OK" or "MISSING"))
    f(DEFAULT_CHAT_FRAME, "  LibGroupTalents-1.0: " .. (LibGroupTalents and "OK" or "MISSING"))
    local qcount = 0
    for _ in pairs(inspectQueue) do qcount = qcount + 1 end
    local ccache = 0
    for _ in pairs(B.specCache) do ccache = ccache + 1 end
    f(DEFAULT_CHAT_FRAME, "  inspect queue: " .. qcount
        .. "  current: " .. (_currentInspect and _currentInspect.unit or "nil")
        .. "  specCache: " .. ccache)
    for name, p in pairs(B.paladins) do
        f(DEFAULT_CHAT_FRAME, "  " .. name .. " (" .. tostring(p.unit) .. ") -> "
            .. tostring(p.spec) .. " [" .. tostring(p.specSource) .. "]")
    end
end

-- ==================== REFRESH / INIT ====================
function B:Refresh(force)
    if not self.db then return end
    if force then
        self._lastRosterHash = nil
        self:UpdateRoster()
        return
    end
    self:ApplyFrameSettings()
    self:RebuildBars()
    self:UpdateAnnounceButton()
end

function B:Reset()
    self.db = PM:ResetSection("buffs", self:GetDefaults(), { "assignments" })
    self:Refresh(true)
end

function B:Init()
    self.db = PM:InitSection("buffs", self:GetDefaults(), { "point", "relPoint", "x", "y", "assignments" })
    self:CreateMain()
    self:UpdateRoster()
    self:UpdateAnnounceButton()

    PM:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        if not B.db or not B.db.enabled then return end
        B._lastRosterHash = nil
        B._rosterPending = true
    end)
    PM:RegisterEvent("UNIT_CONNECTION", function(_, arg1)
        if not B.db or not B.db.enabled then return end
        if type(arg1) == "string" and
           (arg1:match("^party%d") or arg1:match("^raid%d")) then
            B._rosterPending = true
        end
    end)
    PM:RegisterEvent("PARTY_MEMBERS_CHANGED", function()
        if not B.db or not B.db.enabled then return end
        B._rosterPending = true
    end)
    PM:RegisterEvent("RAID_ROSTER_UPDATE", function()
        if not B.db or not B.db.enabled then return end
        B._rosterPending = true
    end)
end

local delayT = 0
local delayFrame = CreateFrame("Frame")
delayFrame:SetScript("OnUpdate", function(_, el)
    if not B._rosterPending then return end
    delayT = delayT + el
    if delayT < 2 then return end
    delayT = 0
    B._rosterPending = false
    B:UpdateRoster()
end)

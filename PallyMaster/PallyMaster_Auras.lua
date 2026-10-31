--[[
    PallyMaster_Auras
    Модуль аур: показывает, какая аура активна у каждого паладина группы/рейда.
--]]

local PM = _G.PallyMaster
local A = PM:NewModule("auras")

local AL = {}
if GetLocale() == "ruRU" then
    AL.noAura      = "Без ауры"
    AL.nameColor   = "Цвет ников"
    AL.colWhite    = "Белый"
    AL.colClass    = "Классовый"
    AL.colAura     = "По ауре"
    AL.secNames    = "Ники"
else
    AL.noAura      = "No aura"
    AL.nameColor   = "Name color"
    AL.colWhite    = "White"
    AL.colClass    = "Class"
    AL.colAura     = "By aura"
    AL.secNames    = "Names"
end
A.AL = AL

-- ==================== SPELL DEFINITIONS ====================
local SPELL_DEFS = {
    devotion      = { type = "aura", order = 1, defaultIcon = "Interface\\Icons\\Spell_Holy_DevotionAura" },
    retribution   = { type = "aura", order = 2, defaultIcon = "Interface\\Icons\\Spell_Holy_Magnitude" },
    concentration = { type = "aura", order = 3, defaultIcon = "Interface\\Icons\\Spell_Holy_MindSooth" },
    shadow_res    = { type = "aura", order = 4, defaultIcon = "Interface\\Icons\\Spell_Frost_WizardMark" },
    frost_res     = { type = "aura", order = 5, defaultIcon = "Interface\\Icons\\Spell_Frost_FrostResistance" },
    fire_res      = { type = "aura", order = 6, defaultIcon = "Interface\\Icons\\Spell_Fire_SealOfFire" },
    crusader      = { type = "aura", order = 7, defaultIcon = "Interface\\Icons\\Spell_Holy_CrusaderAura" },
}

local NAME_TO_KEY = {
    ["Аура самоотверженности"] = "devotion",
    ["Аура воздаяния"] = "retribution",
    ["Аура возмездия"] = "retribution",
    ["Аура сосредоточенности"] = "concentration",
    ["Аура концентрации"] = "concentration",
    ["Аура сопротивления тьме"] = "shadow_res",
    ["Аура сопротивления магии льда"] = "frost_res",
    ["Аура сопротивления магии огня"] = "fire_res",
    ["Аура воина Света"] = "crusader",
    ["Крестоносный поход"] = "crusader",
    ["Devotion Aura"] = "devotion",
    ["Retribution Aura"] = "retribution",
    ["Concentration Aura"] = "concentration",
    ["Shadow Resistance Aura"] = "shadow_res",
    ["Frost Resistance Aura"] = "frost_res",
    ["Fire Resistance Aura"] = "fire_res",
    ["Crusader Aura"] = "crusader",
}

local SPELL_ID_TO_KEY = {
    [465] = "devotion", [643] = "devotion", [10290] = "devotion", [10291] = "devotion",
    [10292] = "devotion", [10293] = "devotion", [1032] = "devotion", [27149] = "devotion",
    [48941] = "devotion", [48942] = "devotion",

    [7294] = "retribution", [8990] = "retribution", [10298] = "retribution", [10299] = "retribution",
    [10300] = "retribution", [10301] = "retribution", [27150] = "retribution", [54043] = "retribution",

    [19746] = "concentration",

    [19876] = "shadow_res", [19895] = "shadow_res", [19898] = "shadow_res",
    [27151] = "shadow_res", [48943] = "shadow_res", [19896] = "shadow_res",

    [19888] = "frost_res", [19897] = "frost_res", [19900] = "frost_res",
    [27152] = "frost_res", [48945] = "frost_res",

    [19891] = "fire_res", [19899] = "fire_res", [19903] = "fire_res",
    [27153] = "fire_res", [48947] = "fire_res",

    [32223] = "crusader",
}

local FALLBACK_RULES = {
    { key = "devotion",      ru = { "самоотверж" },         en = "devotion" },
    { key = "retribution",   ru = { "воздаян", "возмезд" }, en = "retribution" },
    { key = "concentration", ru = { "сосредоточен", "концентрац" }, en = "concentration" },
    { key = "shadow_res",    ru = { "тьм" },                en = "shadow" },
    { key = "frost_res",     ru = { "льд", "ледя" },        en = "frost" },
    { key = "fire_res",      ru = { "огн" },                en = "fire" },
    { key = "crusader",      ru = { "воина света", "крестоносн" }, en = "crusader" },
}

local AURA_COLORS = {
    devotion      = { 0.85, 0.85, 0.85 },
    retribution   = { 1.00, 0.35, 0.35 },
    concentration = { 0.50, 0.70, 1.00 },
    shadow_res    = { 0.65, 0.45, 0.85 },
    frost_res     = { 0.40, 0.80, 1.00 },
    fire_res      = { 1.00, 0.55, 0.25 },
    crusader      = { 1.00, 0.90, 0.40 },
}

local function MatchList(list, s)
    if type(list) == "table" then
        for _, p in ipairs(list) do
            if s:find(p, 1, true) then return true end
        end
    else
        return s:find(list, 1, true)
    end
    return false
end

local function ClassifyAuraName(name)
    local lname = string.lower(name)
    local isAura = lname:find("aura$") or name:find("^[Аа]ура%s")
    if not isAura then return nil end
    for _, rule in ipairs(FALLBACK_RULES) do
        if MatchList(rule.ru, name) or (rule.en and lname:find(rule.en, 1, true)) then
            return rule.key
        end
    end
    return nil
end

-- ==================== SETTINGS ====================
function A:GetDefaults()
    return {
        version      = 2,
        enabled      = true,
        hideInCombat = false,
        groupOnly    = false,
        showWithout  = true,
        nameColor    = "WHITE",
        width        = 230,
        scale        = 1.0,
        spacing      = 2,
        iconSize     = 0,
        fontSize     = 12,
        texture      = "Interface\\Buttons\\WHITE8X8",
        barColor     = "dark",
        barAlpha     = 0.70,
        font         = "Fonts\\FRIZQT__.TTF",
        fontOutline  = "OUTLINE",
        point        = "CENTER",
        relPoint     = "CENTER",
        x            = 0,
        y            = 0,
        locked       = true,
        customSpells = "",
    }
end

function A:RebuildCustom()
    if not self.db then return end
    if self._customKeys then
        for _, ckey in ipairs(self._customKeys) do
            SPELL_DEFS[ckey] = nil
            for name, key in pairs(NAME_TO_KEY) do
                if key == ckey then NAME_TO_KEY[name] = nil end
            end
        end
    end
    self._customKeys = {}
    local order = 600
    for idstr in tostring(self.db.customSpells or ""):gmatch("%d+") do
        local id = tonumber(idstr)
        if id then
            local name, _, icon = GetSpellInfo(id)
            if name then
                local ckey = "custom:" .. id
                SPELL_DEFS[ckey] = { type = "custom", order = order, id = id, defaultIcon = icon }
                NAME_TO_KEY[name] = ckey
                self._customKeys[#self._customKeys + 1] = ckey
                order = order + 1
            end
        end
    end
end

-- ==================== SCAN ====================
function A:ScanUnit(unit, ownOnly)
    local found = {}
    for i = 1, 40 do
        -- 3.3.5a: name, rank, icon, count, duration, debuffType,
        -- expirationTime(7), unitCaster(8), steal(9), consolidate(10), spellId(11)
        local name, _, icon, _, _, _, _, caster, _, _, spellId = UnitBuff(unit, i)
        if not name then break end
        local own = true
        if ownOnly then
            own = caster and (caster == unit or (UnitIsUnit and UnitIsUnit(caster, unit)) or UnitName(caster) == UnitName(unit))
        end
        if own then
            if not icon then
                local _, _, i2 = GetSpellInfo(name)
                icon = i2
            end
            local key = (spellId and SPELL_ID_TO_KEY[spellId]) or NAME_TO_KEY[name] or ClassifyAuraName(name)
            if key and SPELL_DEFS[key] then
                found[#found + 1] = { key = key, def = SPELL_DEFS[key], icon = icon, name = name }
            end
        end
    end
    return found
end

local function GetNameColor(db, key)
    if db.nameColor == "CLASS" then
        local c = (RAID_CLASS_COLORS and RAID_CLASS_COLORS.PALADIN) or { r = 1, g = 0.5, b = 0.75 }
        return c.r, c.g, c.b
    elseif db.nameColor == "AURA" then
        local c = AURA_COLORS[key]
        if c then return c[1], c[2], c[3] end
        return 1, 1, 1
    end
    return 1, 1, 1
end

function A:Collect()
    local db = self.db
    local groups, orderList = {}, {}
    local noAura = {}

    local function GetGroup(key, def, displayName)
        local g = groups[key]
        if not g then
            g = { key = key, def = def, names = {}, displayName = displayName or key }
            groups[key] = g
            orderList[#orderList + 1] = g
        end
        return g
    end

    local units = PM:GetPaladinUnits()
    for _, unit in ipairs(units) do
        local unitName = UnitName(unit)
        local found = self:ScanUnit(unit, true)
        if #found == 0 then
            if db.showWithout then
                noAura[#noAura + 1] = unitName
            end
        else
            for _, f in ipairs(found) do
                local g = GetGroup(f.key, f.def, f.name)
                g.names[#g.names + 1] = unitName
                if not g.icon then g.icon = f.icon or (f.def.defaultIcon or nil) end
            end
        end
    end

    table.sort(orderList, function(a, b)
        if #a.names ~= #b.names then return #a.names > #b.names end
        local oa = a.def.order or 999
        local ob = b.def.order or 999
        if oa ~= ob then return oa < ob end
        return a.displayName < b.displayName
    end)

    if #noAura > 0 then
        orderList[#orderList + 1] = {
            key = "__none",
            def = { type = "none", order = 9999 },
            names = noAura,
            displayName = AL.noAura,
            icon = nil,
        }
    end

    return orderList
end

-- ==================== UI ====================
function A:CreateMain()
    if self.main then return end
    local main = CreateFrame("Frame", "PallyMasterAurasFrame", UIParent)
    main:SetClampedToScreen(true)
    main:SetMovable(true)
    main:EnableMouse(false)
    main:RegisterForDrag("LeftButton")
    main:SetScript("OnDragStart", function(f)
        if not A.db.locked then f:StartMoving() end
    end)
    main:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        PM:SavePosition(f, A.db)
    end)
    self.main = main
    self.rows = {}
end

function A:AcquireRow(index)
    local row = self.rows[index]
    if not row then
        row = CreateFrame("Frame", "PallyMasterAurasRow" .. index, self.main)
        row:EnableMouse(true)
        row.bar = row:CreateTexture(nil, "BORDER")
        row.bar:SetAllPoints(row)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.name = row:CreateFontString(nil, "OVERLAY")
        row:SetScript("OnEnter", function(f)
            if not f.group then return end
            GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
            GameTooltip:AddLine(f.group.displayName, 1, 1, 1)
            GameTooltip:AddLine(table.concat(f.group.names, ", "), 1, 0.84, 0)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.rows[index] = row
    end
    return row
end

function A:ApplyFrameSettings()
    local db = self.db
    local main = self.main
    if not main or not db then return end
    main:SetScale(db.scale)
    main:SetFrameStrata("MEDIUM")
    main:EnableMouse(not db.locked)
    PM:ApplyPosition(main, db)
end

function A:Rebuild()
    local db = self.db
    local main = self.main
    if not main or not db then return end

    if not db.enabled
        or (db.hideInCombat and PM.inCombat)
        or (db.groupOnly and not PM:HasGroup()) then
        main:Hide()
        return
    end

    local list = self:Collect()
    if #list == 0 then
        main:Hide()
        return
    end

    local h = PM:GetBarHeight(db)
    local spacing = db.spacing
    local w = db.width
    local iconSize = PM:GetBarIconSize(db)
    local fontPath = db.font
    local fontSize = db.fontSize
    local fontOutline = db.fontOutline
    if fontOutline == "NONE" or fontOutline == "" then fontOutline = nil end

    main:SetWidth(w)
    main:SetHeight(#list * (h + spacing) - spacing)
    main:Show()

    for i, group in ipairs(list) do
        local row = self:AcquireRow(i)
        row.group = group
        row:SetHeight(h)
        row:SetWidth(w)
        row:EnableMouse(db.locked)
        row:ClearAllPoints()
        if i == 1 then
            row:SetPoint("TOPLEFT", main, "TOPLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", self.rows[i - 1], "BOTTOMLEFT", 0, -spacing)
        end
        row:Show()

        row.bar:SetTexture(db.texture or "Interface\\Buttons\\WHITE8X8")
        local br, bg, bb = PM:GetBarColor(db.barColor)
        row.bar:SetVertexColor(br, bg, bb, db.barAlpha or 0.70)

        local textOffset = 4
        if group.icon then
            row.icon:Show()
            row.icon:SetWidth(iconSize)
            row.icon:SetHeight(iconSize)
            row.icon:ClearAllPoints()
            row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
            row.icon:SetTexture(group.icon)
            row.icon:SetVertexColor(1, 1, 1, 1)
            textOffset = iconSize + 6
        else
            row.icon:Hide()
        end

        PM:SetSafeFont(row.name, fontPath, fontSize, fontOutline)
        row.name:SetShadowColor(0, 0, 0, 1)
        row.name:SetShadowOffset(1, -1)
        row.name:SetJustifyH("LEFT")
        row.name:SetJustifyV("MIDDLE")
        row.name:SetHeight(h)
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", row, "LEFT", textOffset, 0)
        row.name:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.name:SetText(table.concat(group.names, ", "))
        local r, g, b = GetNameColor(db, group.key)
        row.name:SetTextColor(r, g, b, 1)
    end

    for i = #list + 1, #self.rows do
        self.rows[i]:Hide()
        self.rows[i].group = nil
    end
end

function A:Refresh()
    if not self.db then return end
    self:ApplyFrameSettings()
    self.dirty = false
    self:Rebuild()
end

function A:MarkDirty()
    self.dirty = true
end

function A:Reset()
    self.db = PM:ResetSection("auras", self:GetDefaults())
    self:RebuildCustom()
    self:Refresh()
end

-- ==================== EVENTS / INIT ====================
function A:Init()
    self.db = PM:InitSection("auras", self:GetDefaults(), { "point", "relPoint", "x", "y" })
    self:RebuildCustom()
    self:CreateMain()
    self:Refresh()

    PM:RegisterEvent("PLAYER_ENTERING_WORLD", function() A:MarkDirty() end)
    PM:RegisterEvent("PARTY_MEMBERS_CHANGED", function() A:MarkDirty() end)
    PM:RegisterEvent("RAID_ROSTER_UPDATE", function() A:MarkDirty() end)
    PM:RegisterEvent("UNIT_AURA", function() A:MarkDirty() end)
end

local elapsedTotal = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, el)
    if not A.db or not A.dirty then return end
    elapsedTotal = elapsedTotal + el
    if elapsedTotal < 0.25 then return end
    elapsedTotal = 0
    A.dirty = false
    A:Rebuild()
end)

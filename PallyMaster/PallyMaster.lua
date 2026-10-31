--[[
    PallyMaster
    Единый аддон для паладинов: модуль аур и модуль назначения баффов.
    Ядро: общие настройки, база данных, шина событий, скрытие в бою.
--]]

local ADDON = "PallyMaster"
local PM = {}
_G[ADDON] = PM
PM.ADDON = ADDON
PM.version = "1.0.0"

PM.modules = {}
PM.order = {}
PM.configPages = {}
PM.inCombat = (InCombatLockdown and InCombatLockdown()) and true or false

-- ==================== LOCALE ====================
local L = {}
if GetLocale() == "ruRU" then
    L.loaded       = "Загружен. /pm — настройки."
    L.title        = "PallyMaster"
    L.tabAuras     = "Ауры"
    L.tabBuffs     = "Назначение бафов"
    L.enable       = "Включить"
    L.hideInCombat = "Скрывать в бою"
    L.groupOnly    = "Только в группе/рейде"
    L.width        = "Ширина"
    L.scale        = "Масштаб"
    L.spacing      = "Отступ"
    L.iconSize     = "Иконка (0 = авто)"
    L.fontSize     = "Размер шрифта"
    L.barAlpha     = "Прозрачность баров"
    L.secGeneral   = "Общее"
    L.secSize      = "Размер"
    L.secColor     = "Цвет"
    L.barColor     = "Цвет полоски"
    L.colorDark    = "Тёмный"
    L.colorGray    = "Серый"
    L.colorBlue    = "Синий"
    L.colorRed     = "Красный"
    L.colorGreen   = "Зелёный"
    L.colorPurple  = "Фиолетовый"
    L.colorGold    = "Золотой"
    L.colorSpec    = "По специализации"
    L.locked       = "Закрепить позицию"
    L.close        = "Закрыть"
    L.resetSection = "Сбросить раздел"
    L.resetDone    = "Настройки раздела сброшены."
    L.allResetDone = "Настройки PallyMaster сброшены."
    L.lockedMsg    = "Позиция закреплена."
    L.unlockedMsg  = "Позиция разблокирована — тяните мышью."
    L.hint         = "/pm — настройки | /pm auras | /pm buffs | /pm lock | /pm unlock | /pm reset"
    L.noGroup      = "Вы не в группе и не в рейде."
else
    L.loaded       = "Loaded. Type /pm for options."
    L.title        = "PallyMaster"
    L.tabAuras     = "Auras"
    L.tabBuffs     = "Buff assignment"
    L.enable       = "Enable"
    L.hideInCombat = "Hide in combat"
    L.groupOnly    = "Only in group/raid"
    L.width        = "Width"
    L.scale        = "Scale"
    L.spacing      = "Spacing"
    L.iconSize     = "Icon (0 = auto)"
    L.fontSize     = "Font size"
    L.barAlpha     = "Bar alpha"
    L.secGeneral   = "General"
    L.secSize      = "Size"
    L.secColor     = "Color"
    L.barColor     = "Bar color"
    L.colorDark    = "Dark"
    L.colorGray    = "Gray"
    L.colorBlue    = "Blue"
    L.colorRed     = "Red"
    L.colorGreen   = "Green"
    L.colorPurple  = "Purple"
    L.colorGold    = "Gold"
    L.colorSpec    = "By specialization"
    L.locked       = "Lock position"
    L.close        = "Close"
    L.resetSection = "Reset section"
    L.resetDone    = "Section settings reset."
    L.allResetDone = "PallyMaster settings reset."
    L.lockedMsg    = "Position locked."
    L.unlockedMsg  = "Position unlocked — drag with mouse."
    L.hint         = "/pm — options | /pm auras | /pm buffs | /pm lock | /pm unlock | /pm reset"
    L.noGroup      = "You are not in a group or raid."
end
PM.L = L

-- ==================== UTILITIES ====================
function PM:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF7D0A" .. ADDON .. "|r: " .. tostring(msg))
end

function PM:SetSafeFont(fs, path, size, outline)
    local ok = pcall(function() fs:SetFont(path, size, outline) end)
    if not ok then
        pcall(function() fs:SetFont("Fonts\\FRIZQT__.TTF", size, outline) end)
    end
end

function PM:HasGroup()
    return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0
end

-- ==================== BAR METRICS ====================
-- Высота полоски не настраивается: она всегда выводится из размера иконки.
-- iconSize = 0 означает "авто" — иконка чуть больше шрифта.
function PM:GetBarIconSize(db)
    local icon = db.iconSize or 0
    if icon <= 0 then
        icon = (db.fontSize or 12) + 6
    end
    return icon
end

function PM:GetBarHeight(db)
    local icon = self:GetBarIconSize(db)
    local textH = (db.fontSize or 12) + 4
    if textH > icon then icon = textH end
    return icon + 4
end

-- ==================== BAR COLORS ====================
-- Общая палитра полосок для обоих модулей: ключ -> r, g, b.
PM.BAR_COLORS = {
    dark   = { 0.10, 0.10, 0.10 },
    gray   = { 0.35, 0.35, 0.35 },
    blue   = { 0.15, 0.25, 0.50 },
    red    = { 0.50, 0.12, 0.12 },
    green  = { 0.12, 0.40, 0.18 },
    purple = { 0.35, 0.12, 0.50 },
    gold   = { 0.50, 0.38, 0.06 },
}
PM.BAR_COLOR_ORDER = { "dark", "gray", "blue", "red", "green", "purple", "gold" }

function PM:GetBarColor(key)
    local c = self.BAR_COLORS[key] or self.BAR_COLORS.dark
    return c[1], c[2], c[3]
end

-- Пункты меню для выбора цвета полоски (с подписями из L).
function PM:GetBarColorItems(includeSpec)
    local names = {
        dark   = L.colorDark,
        gray   = L.colorGray,
        blue   = L.colorBlue,
        red    = L.colorRed,
        green  = L.colorGreen,
        purple = L.colorPurple,
        gold   = L.colorGold,
    }
    local items = {}
    if includeSpec then
        items[#items + 1] = { text = L.colorSpec, value = "spec" }
    end
    for _, key in ipairs(self.BAR_COLOR_ORDER) do
        items[#items + 1] = { text = names[key] or key, value = key }
    end
    return items
end

-- Список unit-токенов паладинов группы/рейда (для соло — сам игрок).
function PM:GetPaladinUnits()
    local units = {}
    if GetNumRaidMembers() > 0 then
        for i = 1, GetNumRaidMembers() do
            local unit = "raid" .. i
            local _, class = UnitClass(unit)
            if class == "PALADIN" and UnitIsConnected(unit) then
                units[#units + 1] = unit
            end
        end
    else
        local _, pclass = UnitClass("player")
        if pclass == "PALADIN" then
            units[#units + 1] = "player"
        end
        for i = 1, GetNumPartyMembers() do
            local unit = "party" .. i
            local _, class = UnitClass(unit)
            if class == "PALADIN" and UnitIsConnected(unit) then
                units[#units + 1] = unit
            end
        end
    end
    return units
end

function PM:ApplyPosition(frame, db)
    frame:ClearAllPoints()
    frame:SetPoint(db.point or "CENTER", UIParent, db.relPoint or "CENTER", db.x or 0, db.y or 0)
end

function PM:SavePosition(frame, db)
    local point, _, relPoint, x, y = frame:GetPoint()
    db.point = point or "CENTER"
    db.relPoint = relPoint or "CENTER"
    db.x = x or 0
    db.y = y or 0
end

-- ==================== MODULES ====================
function PM:NewModule(key)
    local m = { key = key, PM = self }
    self.modules[key] = m
    self.order[#self.order + 1] = m
    return m
end

function PM:GetModule(key)
    return self.modules[key]
end

function PM:AddConfigPage(key, title, build)
    self.configPages[#self.configPages + 1] = { key = key, title = title, build = build }
end

-- ==================== DATABASE ====================
local function CopyTable(src)
    local t = {}
    for k, v in pairs(src) do t[k] = v end
    return t
end
PM.CopyTable = CopyTable

local function CopyDefaults(defaults)
    local t = {}
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            t[k] = CopyTable(v)
        else
            t[k] = v
        end
    end
    return t
end

function PM:InitSection(name, defaults, keep)
    local db = PallyMasterDB
    local s = db[name]
    if type(s) ~= "table" then
        s = {}
        db[name] = s
    end

    if s.version ~= defaults.version then
        local saved = {}
        for _, k in ipairs(keep or {}) do saved[k] = s[k] end
        for k in pairs(s) do s[k] = nil end
        for k, v in pairs(CopyDefaults(defaults)) do s[k] = v end
        for k, v in pairs(saved) do
            if v ~= nil then s[k] = v end
        end
        s.version = defaults.version
    end

    for k, v in pairs(defaults) do
        if s[k] == nil then
            if type(v) == "table" then
                s[k] = CopyTable(v)
            else
                s[k] = v
            end
        end
    end
    return s
end

function PM:ResetSection(name, defaults, keep)
    local s = PallyMasterDB[name]
    if type(s) ~= "table" then
        s = {}
        PallyMasterDB[name] = s
    end
    local saved = {}
    for _, k in ipairs(keep or {}) do saved[k] = s[k] end
    for k in pairs(s) do s[k] = nil end
    for k, v in pairs(CopyDefaults(defaults)) do s[k] = v end
    for k, v in pairs(saved) do
        if v ~= nil then s[k] = v end
    end
    return s
end

function PM:InitDB()
    if type(PallyMasterDB) ~= "table" then PallyMasterDB = {} end
    local db = PallyMasterDB
    if type(db.version) ~= "number" then db.version = 1 end
    self.db = db
end

-- ==================== EVENT BUS ====================
local eventFrame = CreateFrame("Frame")
local handlers = {}

function PM:RegisterEvent(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
    local list = handlers[event]
    list[#list + 1] = fn
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        list[i](event, ...)
    end
end)

-- ==================== COMBAT ====================
function PM:SetCombatState(inCombat)
    if self.inCombat == inCombat then return end
    self.inCombat = inCombat
    for _, m in ipairs(self.order) do
        if m.Refresh then m:Refresh() end
    end
end

PM:RegisterEvent("PLAYER_REGEN_DISABLED", function() PM:SetCombatState(true) end)
PM:RegisterEvent("PLAYER_REGEN_ENABLED",  function() PM:SetCombatState(false) end)

-- ==================== INIT / SLASH ====================
PM:RegisterEvent("ADDON_LOADED", function(_, arg1)
    if arg1 ~= ADDON then return end
    PM:InitDB()
    for _, m in ipairs(PM.order) do
        if m.Init then m:Init() end
    end
    PM:Print(L.loaded)
end)

local function Normalize(msg)
    return tostring(msg or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
end

function PM:HandleSlash(msg, defaultTab)
    msg = Normalize(msg)
    local buffs = PM.modules.buffs
    local auras = PM.modules.auras
    if not PM.db then return end

    if msg == "auras" or msg == "aura" then
        PM:ToggleConfig("auras")
    elseif msg == "buffs" or msg == "buff" then
        PM:ToggleConfig("buffs")
    elseif msg == "lock" then
        if auras then auras.db.locked = true end
        if buffs then buffs.db.locked = true end
        PM:RefreshAll()
        PM:Print(L.lockedMsg)
    elseif msg == "unlock" then
        if auras then auras.db.locked = false end
        if buffs then buffs.db.locked = false end
        PM:RefreshAll()
        PM:Print(L.unlockedMsg)
    elseif msg == "reset" then
        if auras and auras.Reset then auras:Reset() end
        if buffs and buffs.Reset then buffs:Reset() end
        PM:RefreshAll()
        if PM.RefreshConfigUI then PM:RefreshConfigUI() end
        PM:Print(L.allResetDone)
    elseif msg == "announce" then
        if buffs and buffs.Announce then buffs:Announce() end
    elseif msg == "announcetest" then
        if buffs and buffs.AnnounceTest then buffs:AnnounceTest() end
    elseif msg == "whoami" then
        if buffs and buffs.WhoAmI then buffs:WhoAmI() end
    elseif msg == "refresh" then
        if buffs and buffs.ResetSpecCache then buffs:ResetSpecCache() end
    elseif msg == "debug" then
        if buffs and buffs.PrintDebug then buffs:PrintDebug() end
    elseif msg == "inspectdebug" then
        if buffs then
            buffs._debugInspect = not buffs._debugInspect
            PM:Print("inspect debug: " .. tostring(buffs._debugInspect))
        end
    else
        PM:ToggleConfig(defaultTab)
    end
end

SLASH_PALLYMASTER1 = "/pm"
SlashCmdList["PALLYMASTER"] = function(msg) PM:HandleSlash(msg) end

-- Совместимость со старыми командами: не перекрываем их, если старые аддоны включены.
if not SlashCmdList["PALAURAS"] then
    SLASH_PALLYMASTER_AURAS1 = "/pa"
    SlashCmdList["PALAURAS"] = function(msg) PM:HandleSlash(msg, "auras") end
end
if not SlashCmdList["PALADINBUFFASSIGN"] then
    SLASH_PALLYMASTER_BUFFS1 = "/pba"
    SlashCmdList["PALADINBUFFASSIGN"] = function(msg) PM:HandleSlash(msg, "buffs") end
end

function PM:RefreshAll()
    for _, m in ipairs(self.order) do
        if m.Refresh then m:Refresh() end
    end
end

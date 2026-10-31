--[[
    PallyMaster_Config
    Единое окно настроек с вкладками модулей.
--]]

local PM = _G.PallyMaster
local L = PM.L
local A = PM:GetModule("auras")
local B = PM:GetModule("buffs")

local cfg = nil
local tabs = {}
local refreshers = {}
local widgetSeq = 0

local X1, X2 = 8, 390

local function AddRefresher(fn)
    refreshers[#refreshers + 1] = fn
end

local function WidgetName(prefix)
    widgetSeq = widgetSeq + 1
    return "PallyMasterCfg" .. prefix .. widgetSeq
end

local function MakeSection(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text)
    return 26
end

local function MakeCheckbox(parent, text, x, y, get, set, onChange)
    local cb = CreateFrame("CheckButton", WidgetName("CB"), parent, "UICheckButtonTemplate")
    cb:SetWidth(24)
    cb:SetHeight(24)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local lab = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lab:SetPoint("LEFT", cb, "LEFT", 30, 0)
    lab:SetJustifyH("LEFT")
    lab:SetText(text)
    cb:SetHitRectInsets(0, -(lab:GetStringWidth() + 8), 0, 0)
    cb:SetScript("OnClick", function(self)
        set(not not self:GetChecked())
        if onChange then onChange() end
    end)
    cb.refresh = function()
        cb:SetChecked(not not get())
    end
    AddRefresher(cb.refresh)
    return 24
end

local function MakeSlider(parent, key, label, x, y, minv, maxv, step, get, set, onChange)
    local name = WidgetName("S_" .. key .. "_")
    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetWidth(210)
    s:SetHeight(16)
    s:SetMinMaxValues(minv, maxv)
    s:SetValueStep(step)
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 14)
    local st = _G[name .. "Text"]
    if st then st:SetText(label) end
    local sLow = _G[name .. "Low"]
    if sLow then sLow:SetText(string.format("%g", minv)) end
    local sHigh = _G[name .. "High"]
    if sHigh then sHigh:SetText(string.format("%g", maxv)) end
    if not st then
        local lab = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lab:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 4)
        lab:SetText(label)
    end

    local val = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val:SetPoint("LEFT", s, "RIGHT", 10, 0)
    val:SetWidth(46)
    val:SetJustifyH("LEFT")
    local fmt = (step < 1) and "%.2f" or "%d"

    s:SetScript("OnValueChanged", function(self, value)
        local v = math.floor(value / step + 0.5) * step
        v = math.floor(v * 100 + 0.5) / 100
        if v ~= self._lock then
            self._lock = v
            self:SetValue(v)
        end
        val:SetText(string.format(fmt, v))
        if get() ~= v then
            set(v)
            if onChange then onChange() end
        end
    end)
    s.refresh = function()
        local v = get()
        s._lock = v
        s:SetValue(v)
        val:SetText(string.format(fmt, v))
    end
    AddRefresher(s.refresh)
    return 48
end

local function MakeDropdown(parent, key, label, x, y, items, get, set, onChange)
    local lab = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lab:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lab:SetText(label)

    local name = WidgetName("DD_" .. key .. "_")
    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", parent, "TOPLEFT", x - 16, y - 20)
    UIDropDownMenu_SetWidth(dd, 170)

    UIDropDownMenu_Initialize(dd, function(_, level)
        for _, item in ipairs(items) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.text
            info.func = function()
                set(item.value)
                UIDropDownMenu_SetText(dd, item.text)
                CloseDropDownMenus()
                if onChange then onChange() end
            end
            info.checked = (get() == item.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    dd.refresh = function()
        local cur = get()
        for _, item in ipairs(items) do
            if item.value == cur then
                UIDropDownMenu_SetText(dd, item.text)
                return
            end
        end
        if items[1] then
            UIDropDownMenu_SetText(dd, items[1].text)
        end
    end
    AddRefresher(dd.refresh)
    return 48
end

local function MakeButton(parent, text, x, y, width, onclick)
    local b = CreateFrame("Button", WidgetName("Btn"), parent, "UIPanelButtonTemplate")
    b:SetWidth(width or 110)
    b:SetHeight(22)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", onclick)
    return b
end

local function MakeResetButton(page, module)
    local b = MakeButton(page, L.resetSection, 0, 0, 160, function()
        if module and module.Reset then module:Reset() end
        PM:RefreshConfigUI()
        PM:Print(L.resetDone)
    end)
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 8, 4)
end

-- ==================== SHARED BLOCKS ====================
-- Общие секции: одинаковый порядок и одинаковые координаты в обеих вкладках.
local function BuildGeneral(page, d, onChange, onChangeForce)
    local y = 0
    y = y - MakeSection(page, L.secGeneral, X1, y)
    y = y - MakeCheckbox(page, L.enable, X1 + 8, y,
        function() return d.enabled end,
        function(v) d.enabled = v end, onChangeForce or onChange)
    y = y - MakeCheckbox(page, L.hideInCombat, X1 + 8, y,
        function() return d.hideInCombat end,
        function(v) d.hideInCombat = v end, onChange)
    y = y - MakeCheckbox(page, L.groupOnly, X1 + 8, y,
        function() return d.groupOnly end,
        function(v) d.groupOnly = v end, onChange)
    y = y - MakeCheckbox(page, L.locked, X1 + 8, y,
        function() return d.locked end,
        function(v) d.locked = v end, onChange)
    return y
end

local function BuildSize(page, d, y, onChange)
    y = y - 8
    y = y - MakeSection(page, L.secSize, X1, y)
    y = y - MakeSlider(page, "width", L.width, X1 + 8, y, 60, 500, 1,
        function() return d.width end, function(v) d.width = v end, onChange)
    y = y - MakeSlider(page, "scale", L.scale, X1 + 8, y, 0.5, 2, 0.05,
        function() return d.scale end, function(v) d.scale = v end, onChange)
    y = y - MakeSlider(page, "spacing", L.spacing, X1 + 8, y, 0, 20, 1,
        function() return d.spacing end, function(v) d.spacing = v end, onChange)
    y = y - MakeSlider(page, "iconsize", L.iconSize, X1 + 8, y, 0, 40, 1,
        function() return d.iconSize end, function(v) d.iconSize = v end, onChange)
    y = y - MakeSlider(page, "fontsize", L.fontSize, X1 + 8, y, 8, 24, 1,
        function() return d.fontSize end, function(v) d.fontSize = v end, onChange)
    y = y - MakeSlider(page, "baralpha", L.barAlpha, X1 + 8, y, 0, 1, 0.05,
        function() return d.barAlpha end, function(v) d.barAlpha = v end, onChange)
    return y
end

local function BuildBarColor(page, d, onChange, includeSpec)
    local y = 0
    y = y - MakeSection(page, L.secColor, X2, y)
    y = y - MakeDropdown(page, "barcolor", L.barColor, X2 + 8, y,
        PM:GetBarColorItems(includeSpec),
        function() return d.barColor end,
        function(v) d.barColor = v end, onChange)
    return y
end

-- ==================== AURAS PAGE ====================
local function BuildAurasPage(page)
    local d = A.db
    local AL = A.AL
    local function changed() A:Refresh() end

    local y = BuildGeneral(page, d, changed)
    BuildSize(page, d, y, changed)

    local ry = BuildBarColor(page, d, changed, false)
    ry = ry - 8
    ry = ry - MakeSection(page, AL.secNames, X2, ry)
    ry = ry - MakeDropdown(page, "namecolor", AL.nameColor, X2 + 8, ry, {
        { text = AL.colWhite, value = "WHITE" },
        { text = AL.colClass, value = "CLASS" },
        { text = AL.colAura,  value = "AURA" },
    }, function() return d.nameColor end, function(v) d.nameColor = v end, changed)

    MakeResetButton(page, A)
end

-- ==================== BUFFS PAGE ====================
local function BuildBuffsPage(page)
    local d = B.db
    local BL = B.L
    local function changed() B:Refresh() end
    local function changedForce() B:Refresh(true) end

    local y = BuildGeneral(page, d, changed, changedForce)
    BuildSize(page, d, y, changed)

    local ry = BuildBarColor(page, d, changed, true)
    ry = ry - 8
    ry = ry - MakeSection(page, BL.secMenu, X2, ry)
    ry = ry - MakeDropdown(page, "menudir", BL.menuDirection, X2 + 8, ry, {
        { text = BL.dirLeft, value = "left" },
        { text = BL.dirRight, value = "right" },
    }, function() return d.menuDirection end, function(v) d.menuDirection = v end, changed)
    ry = ry - MakeSlider(page, "menuAlpha", BL.menuAlpha, X2 + 8, ry, 0, 1, 0.05,
        function() return d.menuAlpha end, function(v) d.menuAlpha = v end, changed)

    ry = ry - 8
    ry = ry - MakeSection(page, BL.secNames, X2, ry)
    ry = ry - MakeDropdown(page, "buffnamemode", BL.buffNameMode, X2 + 8, ry, {
        { text = BL.bmIcon, value = "icon" },
        { text = BL.bmShort, value = "short" },
        { text = BL.bmFull, value = "full" },
    }, function() return d.buffNameMode end, function(v) d.buffNameMode = v end, changed)
    ry = ry - MakeDropdown(page, "announcenamemode", BL.announceNameMode, X2 + 8, ry, {
        { text = BL.anShort, value = "short" },
        { text = BL.anFull, value = "full" },
    }, function() return d.announceNameMode end, function(v) d.announceNameMode = v end, changed)

    MakeResetButton(page, B)
end

PM:AddConfigPage("auras", L.tabAuras, BuildAurasPage)
PM:AddConfigPage("buffs", L.tabBuffs, BuildBuffsPage)

-- ==================== WINDOW ====================
function PM:CreateConfig()
    if cfg then return end

    local f = CreateFrame("Frame", PM.ADDON .. "ConfigFrame", UIParent)
    f:SetWidth(760)
    f:SetHeight(680)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(s) s:StartMoving() end)
    f:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() end)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    cfg = f

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -18)
    title:SetText(L.title)

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)
    hint:SetText(L.hint)

    local closeBtn = MakeButton(f, L.close, 0, 0, 110, function() f:Hide() end)
    closeBtn:ClearAllPoints()
    closeBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 16)

    local tabX = 28
    for i, pageDef in ipairs(self.configPages) do
        local btn = CreateFrame("Button", PM.ADDON .. "Tab" .. i, f, "UIPanelButtonTemplate")
        btn:SetWidth(170)
        btn:SetHeight(22)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", tabX, -44)
        btn:SetText(pageDef.title)
        btn:SetScript("OnClick", function() PM:SelectTab(pageDef.key) end)

        local page = CreateFrame("Frame", PM.ADDON .. "Page" .. pageDef.key, f)
        page:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -76)
        page:SetWidth(712)
        page:SetHeight(540)
        page:Hide()

        pageDef.build(page)
        tabs[pageDef.key] = { button = btn, page = page }
        tabX = tabX + 176
    end

    if self.configPages[1] then
        self:SelectTab(self.configPages[1].key)
    end
    f:Hide()
end

function PM:SelectTab(key)
    if not cfg or not tabs[key] then return end
    self.currentTab = key
    for k, t in pairs(tabs) do
        if k == key then
            t.page:Show()
            if t.button.SetButtonState then t.button:SetButtonState("PUSHED", true) end
        else
            t.page:Hide()
            if t.button.SetButtonState then t.button:SetButtonState("NORMAL", false) end
        end
    end
    self:RefreshConfigUI()
end

function PM:RefreshConfigUI()
    if not cfg then return end
    for i = 1, #refreshers do
        refreshers[i]()
    end
end

function PM:ToggleConfig(key)
    if not cfg then
        self:CreateConfig()
    end
    if cfg:IsShown() and (not key or key == self.currentTab) then
        cfg:Hide()
    else
        if key then
            self:SelectTab(key)
        end
        cfg:Show()
        self:RefreshConfigUI()
    end
end

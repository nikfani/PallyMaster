--[[
    PallyMaster_Buffs_UI
    Бары паладинов, контекстное меню и кнопка анонса.
--]]

local PM = _G.PallyMaster
local B = PM:GetModule("buffs")
local L = B.L

local rows = {}
local menuFrame = nil
local announceBtn = nil

local function GetSpecColor(spec)
    if spec == "Protection" then return 0.70, 0.30, 0.30 end
    if spec == "Holy" then return 0.30, 0.70, 0.30 end
    if spec == "Retribution" then return 0.90, 0.70, 0.10 end
    return 0.60, 0.60, 0.60
end

-- ==================== VISIBILITY ====================
function B:ShouldShow()
    local d = self.db
    if not d or not d.enabled then return false end
    if d.hideInCombat and PM.inCombat then return false end
    return true
end

function B:GroupOK()
    local d = self.db
    return d and (not d.groupOnly or PM:HasGroup())
end

-- ==================== MAIN FRAME ====================
function B:CreateMain()
    if self.main then return end
    local d = self.db
    local main = CreateFrame("Frame", PM.ADDON .. "BuffsFrame", UIParent)
    main:SetClampedToScreen(true)
    main:SetMovable(true)
    main:SetFrameStrata("MEDIUM")
    main:SetScale(d.scale or 1.0)
    PM:ApplyPosition(main, d)
    main:EnableMouse(not d.locked)
    main:RegisterForDrag("LeftButton")
    main:SetScript("OnDragStart", function(f)
        if menuFrame then menuFrame:Hide() end
        if not d.locked then f:StartMoving() end
    end)
    main:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        PM:SavePosition(f, d)
    end)
    self.main = main
end

function B:ApplyFrameSettings()
    local d = self.db
    local main = self.main
    if not main or not d then return end
    main:SetScale(d.scale)
    PM:ApplyPosition(main, d)
    main:EnableMouse(not d.locked)

    local hasPals = next(self.paladins) ~= nil
    if self:ShouldShow() and self:GroupOK() and hasPals then
        main:Show()
    else
        main:Hide()
    end
end

-- ==================== BAR UI ====================
function B:RebuildBars()
    local d = self.db
    local main = self.main
    if not main or not d then return end

    if not self:ShouldShow() or not self:GroupOK() then
        main:Hide()
        return
    end

    local paladinNames = {}
    for name in pairs(self.paladins) do
        paladinNames[#paladinNames + 1] = name
    end
    table.sort(paladinNames)

    if #paladinNames == 0 then
        main:Hide()
        return
    end

    local h = PM:GetBarHeight(d)
    local spacing = d.spacing
    local w = d.width
    local iconSize = PM:GetBarIconSize(d)
    local fontSize = d.fontSize or 12

    main:SetWidth(w)
    main:SetHeight(#paladinNames * (h + spacing) - spacing)
    main:Show()

    local i = 1
    for _, name in ipairs(paladinNames) do
        local row = rows[i]
        if not row then
            row = self:AcquireRow(i)
        end
        rows[i] = row
        row:Show()

        local p = self.paladins[name]
        row:SetHeight(h)
        row:SetWidth(w)
        row:ClearAllPoints()
        if i == 1 then
            row:SetPoint("TOPLEFT", main, "TOPLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -spacing)
        end

        row.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        local r, g, b
        if d.barColor and d.barColor ~= "spec" then
            r, g, b = PM:GetBarColor(d.barColor)
        else
            r, g, b = GetSpecColor(p.spec)
            r, g, b = r * 0.30, g * 0.30, b * 0.30
        end
        row.bg:SetVertexColor(r, g, b, d.barAlpha or 0.85)

        row.specIcon:SetWidth(iconSize)
        row.specIcon:SetHeight(iconSize)
        row.specIcon:SetTexture(self:GetSpecIcon(p.spec))
        row.specIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.specIcon:Show()

        PM:SetSafeFont(row.name, "Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
        row.name:SetShadowColor(0, 0, 0, 1)
        row.name:SetShadowOffset(1, -1)
        row.name:SetText(name)
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS.PALADIN or { r = 1, g = 0.5, b = 0.75 }
        row.name:SetTextColor(color.r, color.g, color.b, 1)
        row.name:SetJustifyV("MIDDLE")
        row.name:SetHeight(h)
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", row.specIcon, "RIGHT", 6, 0)

        local buffs = self:GetPaladinBuffs(name)
        local buffNameMode = d.buffNameMode or "icon"

        for _, iconTex in ipairs(row.buffIcons) do
            iconTex:Hide()
            iconTex:SetTexture("")
            iconTex:SetTexCoord(0, 1, 0, 1)
        end
        wipe(row.buffIcons)
        row.buffText:Hide()

        if #buffs > 0 then
            local offsetX = 0
            for idx, bk in ipairs(buffs) do
                local iconTex = row.buffIcons[idx]
                if not iconTex then
                    iconTex = row:CreateTexture(nil, "ARTWORK")
                    table.insert(row.buffIcons, iconTex)
                end
                iconTex:SetWidth(iconSize)
                iconTex:SetHeight(iconSize)
                iconTex:SetTexture(self:GetBuffIcon(bk))
                iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                iconTex:ClearAllPoints()
                iconTex:SetPoint("RIGHT", row, "RIGHT", -4 - offsetX, 0)
                iconTex:Show()
                offsetX = offsetX + iconSize + 4
            end

            local parts = {}
            for _, bk in ipairs(buffs) do
                parts[#parts + 1] = self:FormatBuffName(bk, buffNameMode)
            end

            if buffNameMode == "icon" then
                row.buffText:Hide()
            else
                PM:SetSafeFont(row.buffText, "Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
                row.buffText:SetShadowColor(0, 0, 0, 1)
                row.buffText:SetShadowOffset(1, -1)
                row.buffText:SetText(table.concat(parts, ", "))
                row.buffText:Show()
                row.buffText:SetPoint("RIGHT", row, "RIGHT", -4 - offsetX, 0)
                row.buffText:SetJustifyH("RIGHT")
                row.buffText:SetTextColor(0.9, 0.9, 0.3, 1)
            end
        else
            local iconTex = row.buffIcons[1]
            if not iconTex then
                iconTex = row:CreateTexture(nil, "ARTWORK")
                table.insert(row.buffIcons, iconTex)
            end
            iconTex:SetWidth(iconSize)
            iconTex:SetHeight(iconSize)
            iconTex:SetTexture("Interface\\Buttons\\UI-StopButton")
            iconTex:SetTexCoord(0, 1, 0, 1)
            iconTex:ClearAllPoints()
            iconTex:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            iconTex:Show()
        end

        row.paladinName = name
        i = i + 1
    end

    for j = i, #rows do
        rows[j]:Hide()
    end

    self:UpdateAnnounceButton()
end

function B:AcquireRow(index)
    local row = rows[index]
    if row then return row end

    local d = self.db
    local main = self.main
    local h = PM:GetBarHeight(d)
    local w = d.width

    row = CreateFrame("Button", PM.ADDON .. "BuffsRow" .. index, main)
    row:SetHeight(h)
    row:SetWidth(w)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:RegisterForDrag("LeftButton")

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.bg:SetVertexColor(0.1, 0.1, 0.1, 0.85)

    row.specIcon = row:CreateTexture(nil, "ARTWORK")
    row.specIcon:SetWidth(h - 4)
    row.specIcon:SetHeight(h - 4)
    row.specIcon:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.specIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    row.name = row:CreateFontString(nil, "OVERLAY")
    PM:SetSafeFont(row.name, "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    row.name:SetPoint("LEFT", row.specIcon, "RIGHT", 6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetJustifyV("MIDDLE")

    row.buffIcons = {}

    row.buffText = row:CreateFontString(nil, "OVERLAY")
    PM:SetSafeFont(row.buffText, "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    row.buffText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.buffText:SetJustifyH("RIGHT")
    row.buffText:SetJustifyV("MIDDLE")

    row:SetScript("OnEnter", function(self) self:LockHighlight() end)
    row:SetScript("OnLeave", function(self) self:UnlockHighlight() end)

    row:SetScript("OnClick", function(self, button)
        if button ~= "LeftButton" and button ~= "RightButton" then return end
        if menuFrame and menuFrame:IsShown() and menuFrame.paladinName == self.paladinName then
            menuFrame:Hide()
        else
            B:ShowMenu(self.paladinName, self, d.menuDirection)
        end
    end)

    row:SetScript("OnDragStart", function(self)
        if menuFrame then menuFrame:Hide() end
        if not d.locked then B.main:StartMoving() end
    end)
    row:SetScript("OnDragStop", function(self)
        B.main:StopMovingOrSizing()
        PM:SavePosition(B.main, d)
    end)

    rows[index] = row
    return row
end

-- ==================== CONTEXT MENU (HORIZONTAL) ====================
local function HideMenu()
    if menuFrame then menuFrame:Hide() end
end

function B:ShowMenu(paladinName, anchorFrame, direction)
    HideMenu()

    local d = self.db
    local p = self.paladins[paladinName]
    if not p then return end

    local assignable = self:GetAssignableBuffs(paladinName)
    if #assignable == 0 then return end

    -- === Размеры (горизонтальная полоса) ===
    local itemH      = PM:GetBarHeight(d)
    local iconSize   = PM:GetBarIconSize(d)
    local padding    = 0
    local itemSpacing = 2

    local buffNameMode = d.buffNameMode or "icon"
    local itemW
    if buffNameMode == "icon" then
        itemW = itemH
    else
        local maxTextWidth = 0
        for _, buffKey in ipairs(assignable) do
            local text = self:FormatBuffName(buffKey, buffNameMode)
            if text and text ~= "" then
                maxTextWidth = math.max(maxTextWidth, #text * 8 + 12)
            end
        end
        itemW = itemH + 8 + maxTextWidth
    end

    local numItems = #assignable
    local mWidth   = padding * 2 + numItems * itemW + (numItems - 1) * itemSpacing
    local mHeight  = itemH + padding * 2

    -- === Создаём контейнер (один раз) ===
    -- Меню — обычный дочерний фрейм бара: слой MEDIUM, как у самих баров,
    -- чтобы оно не всплывало поверх остального интерфейса игры.
    if not menuFrame then
        menuFrame = CreateFrame("Frame", PM.ADDON .. "BuffsMenu", B.main)
        menuFrame:SetClampedToScreen(true)
        menuFrame:EnableMouse(true)
        menuFrame.bg = menuFrame:CreateTexture(nil, "BACKGROUND")
        menuFrame.bg:SetAllPoints(menuFrame)
        menuFrame.bg:SetTexture(0, 0, 0, d.menuAlpha or 0.90)
    end
    menuFrame.bg:SetTexture(0, 0, 0, d.menuAlpha or 0.90)
    menuFrame.paladinName = paladinName

    menuFrame:ClearAllPoints()
    menuFrame:SetWidth(mWidth)
    menuFrame:SetHeight(mHeight)

    -- === Позиционирование ===
    local aLeft   = anchorFrame:GetLeft()
    local aRight  = anchorFrame:GetRight()
    local aBottom = anchorFrame:GetBottom()
    local aHeight = anchorFrame:GetHeight()
    local mLeft   = B.main:GetLeft()
    local mBottom = B.main:GetBottom()

    local mx
    if direction == "left" then
        mx = aLeft - mLeft - mWidth - 4
    else
        mx = aRight - mLeft + 4
    end
    local my = (aBottom - mBottom) + (aHeight - mHeight) / 2

    menuFrame:SetPoint("BOTTOMLEFT", B.main, "BOTTOMLEFT", mx, my)
    menuFrame:Show()

    -- === Заполняем элементами (горизонтально) ===
    if not menuFrame.items then menuFrame.items = {} end
    for _, item in ipairs(menuFrame.items) do item:Hide() end

    local rowIdx = 0
    for _, buffKey in ipairs(assignable) do
        rowIdx = rowIdx + 1
        local item = menuFrame.items[rowIdx]
        if not item then
            item = CreateFrame("Button", nil, menuFrame)
            item:EnableMouse(true)

            item.bg = item:CreateTexture(nil, "BACKGROUND")
            item.bg:SetAllPoints(item)
            item.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
            item.bg:SetVertexColor(0.15, 0.15, 0.15, 0.9)

            item.icon = item:CreateTexture(nil, "ARTWORK")
            item.icon:SetWidth(iconSize)
            item.icon:SetHeight(iconSize)
            item.icon:SetPoint("LEFT", item, "LEFT", 2, 0)

            item.text = item:CreateFontString(nil, "OVERLAY")
            PM:SetSafeFont(item.text, "Fonts\\FRIZQT__.TTF", d.fontSize or 12, "OUTLINE")
            item.text:SetJustifyH("LEFT")
            item.text:SetJustifyV("MIDDLE")

            item:SetScript("OnEnter", function(self)
                self.bg:SetVertexColor(0.3, 0.3, 0.3, 0.9)
            end)
            item:SetScript("OnLeave", function(self)
                if B:HasBuff(self.paladinName, self.buffKey) then
                    self.bg:SetVertexColor(0.4, 0.35, 0.1, 0.95)
                    self.text:SetTextColor(1, 0.9, 0.4, 1)
                else
                    self.bg:SetVertexColor(0.15, 0.15, 0.15, 0.9)
                    self.text:SetTextColor(1, 1, 1, 1)
                end
            end)
            item:SetScript("OnClick", function(self, button)
                if button == "LeftButton" then
                    B:AssignBuff(self.paladinName, self.buffKey)
                    menuFrame:Hide()
                end
            end)

            menuFrame.items[rowIdx] = item
        end

        item.paladinName = paladinName
        item.buffKey     = buffKey

        item:ClearAllPoints()
        item:SetWidth(itemW)
        item:SetHeight(itemH)
        item:SetPoint("LEFT", menuFrame, "LEFT",
            padding + (rowIdx - 1) * (itemW + itemSpacing), 0)
        item:Show()

        item.icon:SetWidth(iconSize)
        item.icon:SetHeight(iconSize)
        item.icon:SetTexture(self:GetBuffIcon(buffKey))
        item.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        local dispText = self:FormatBuffName(buffKey, buffNameMode)
        if buffNameMode == "icon" then
            item.text:Hide()
            item.icon:ClearAllPoints()
            item.icon:SetPoint("CENTER", item, "CENTER", 0, 0)
        else
            item.text:Show()
            item.icon:ClearAllPoints()
            item.icon:SetPoint("LEFT", item, "LEFT", 2, 0)
            item.text:ClearAllPoints()
            item.text:SetPoint("LEFT", item.icon, "RIGHT", 6, 0)
            item.text:SetPoint("RIGHT", item, "RIGHT", -4, 0)
            item.text:SetText(dispText)
        end

        if self:HasBuff(paladinName, buffKey) then
            item.bg:SetVertexColor(0.4, 0.35, 0.1, 0.95)
            item.text:SetTextColor(1, 0.9, 0.4, 1)
        else
            item.bg:SetVertexColor(0.15, 0.15, 0.15, 0.9)
            item.text:SetTextColor(1, 1, 1, 1)
        end
    end
end

-- ==================== ANNOUNCE BUTTON ====================
function B:UpdateAnnounceButton()
    local d = self.db
    if not d then return end

    local show = self:AnyBuffAssigned()

    if not announceBtn then
        announceBtn = CreateFrame("Button", PM.ADDON .. "AnnounceBtn", B.main, "UIPanelButtonTemplate")
        announceBtn:SetWidth(120)
        announceBtn:SetHeight(22)
        announceBtn:SetText(L.announce)
        announceBtn:SetScript("OnClick", function()
            B:Announce()
        end)
        announceBtn:Hide()
    end

    announceBtn:SetParent(B.main)
    announceBtn:ClearAllPoints()
    announceBtn:SetPoint("TOPLEFT", B.main, "BOTTOMLEFT", 0, -2)

    if show and B.main:IsShown() then
        announceBtn:Show()
    else
        announceBtn:Hide()
    end
end

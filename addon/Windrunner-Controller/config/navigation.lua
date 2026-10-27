-- Settings use two predictable focus areas: categories and the current page.
local Config=ConsoleExperience.config
local function L(key) return ConsoleExperience.locale and ConsoleExperience.locale.T(key) or key end
local function Within(frame,parent)
    while frame do
        if frame==parent then return true end
        frame=frame.GetParent and frame:GetParent()
    end
    return false
end

function Config:GetPageFocus()
    local cursor=ConsoleExperience.cursor
    local section=self.contentSections and self.contentSections[self.currentSection]
    if not cursor or not section then return end
    local buttons=cursor:CollectVisibleButtons(section)
    local remembered=self.pageFocus and self.pageFocus[self.currentSection]
    for _,info in ipairs(buttons) do if info.button==remembered then return remembered end end
    local viewport=section.scrollFrame
    for _,info in ipairs(buttons) do
        if not viewport or (info.y<viewport:GetTop() and info.y>viewport:GetBottom()) then return info.button end
    end
    return buttons[1] and buttons[1].button
end

function Config:UpdateNavigationHint()
    if not self.frame or not self.frame.navigationHint then return end
    local pad=WindrunnerController
    local confirm=pad and pad.GetMenuButtonName and pad:GetMenuButtonName("confirm") or L("Select")
    local cancel=pad and pad.GetMenuButtonName and pad:GetMenuButtonName("cancel") or L("Back")
    local native=pad and pad.HasNativeInput and pad:HasNativeInput()
    self.frame.navigationHint:SetText(L(native and "Left stick / D-pad: Navigate" or "D-pad: Navigate")
        .. "   |   " .. L("Left / right: Adjust") .. "   |   " .. confirm .. ": " .. L("Select") .. "   |   " .. cancel .. ": " .. L("Back"))
end

function Config:HandleNavigation(direction)
    local cursor=ConsoleExperience.cursor
    local current=cursor and cursor.navigationState and cursor.navigationState.currentButton
    if not self.frame or not self.frame:IsVisible() or not Within(current,self.frame) then return false end
    local locked=cursor.navigationState.navigationLockFrame
    if locked and locked~=self.frame then return false end
    local target
    if current.sectionId and self.sidebarButtons[current.sectionId]==current then
        local index=1
        for i,section in ipairs(self.SECTIONS) do if section.id==current.sectionId then index=i end end
        if direction=="UP" or direction=="DOWN" then
            index=math.max(1,math.min(table.getn(self.SECTIONS),index+(direction=="UP" and -1 or 1)))
            local id=self.SECTIONS[index].id
            if id~=self.currentSection then self:ShowSection(id) end
            target=self.sidebarButtons[id]
        elseif direction=="RIGHT" then target=self:GetPageFocus() end
    elseif current==self.frame.closeButton then
        if direction=="UP" then target=self:GetPageFocus()
        elseif direction=="LEFT" then target=self.sidebarButtons[self.currentSection] end
    else
        local section=self.contentSections[self.currentSection]
        if not Within(current,section) then return false end
        if (direction=="LEFT" or direction=="RIGHT") and current.cursorAdjust then
            current.cursorAdjust(direction)
            return true
        end
        self.pageFocus=self.pageFocus or {}
        self.pageFocus[self.currentSection]=current
        local x,y=(current.ceSettingsRow or current):GetCenter()
        if not x or not y then return true end
        local buttons=cursor:CollectVisibleButtons(section)
        local bestY,bestX
        for _,info in ipairs(buttons) do
            if info.button~=current then
                if info.button.ceSettingsRow then info.x,info.y=info.button.ceSettingsRow:GetCenter() end
                local dx,dy=info.x-x,info.y-y
                if direction=="UP" or direction=="DOWN" then
                    local distance=direction=="UP" and dy or -dy
                    -- Move to the next visual row, then preserve the column.
                    if distance>10 and (not bestY or distance<bestY-10
                        or (math.abs(distance-bestY)<=10 and math.abs(dx)<bestX)) then
                        target,bestY,bestX=info.button,distance,math.abs(dx)
                    end
                else
                    local distance=direction=="RIGHT" and dx or -dx
                    local rowTolerance=math.max(18,(current:GetHeight() or 24)/2)
                    if distance>1 and math.abs(dy)<=rowTolerance and (not bestX or distance<bestX) then
                        target,bestX=info.button,distance
                    end
                end
            end
        end
        if not target and direction=="LEFT" then target=self.sidebarButtons[self.currentSection]
        elseif not target and direction=="DOWN" then target=self.frame.closeButton end
    end
    if target then cursor:MoveCursorToButton(target) end
    return true -- Edges stay put; never wrap into another focus area.
end

function Config:HandleBack()
    local cursor=ConsoleExperience.cursor
    local current=cursor and cursor.navigationState and cursor.navigationState.currentButton
    local section=self.contentSections and self.contentSections[self.currentSection]
    local lock=cursor and cursor.navigationState and cursor.navigationState.navigationLockFrame
    if not self.frame or not self.frame:IsVisible() or (lock and lock~=self.frame) or not Within(current,section) then return false end
    self.pageFocus=self.pageFocus or {}
    self.pageFocus[self.currentSection]=current
    cursor:MoveCursorToButton(self.sidebarButtons[self.currentSection])
    return true
end

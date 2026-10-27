local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
-- Sticks, triggers, and menu buttons share the binding overview's controller art.
local Config=ConsoleExperience.config
local Controls=ConsoleExperience.controllerControls
local ROOT="Interface\\AddOns\\Windrunner-Controller\\textures\\"
local WHITE="Interface\\Buttons\\WHITE8X8"
local function L(key) return ConsoleExperience.locale and ConsoleExperience.locale.T(key) or key end
local function Text(parent,width,height,role)
    local text=parent:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    text:SetWidth(width); text:SetHeight(height); text:SetJustifyH("LEFT")
    if ConsoleExperience.theme then ConsoleExperience.theme:Register(text,role or "text") end
    return text
end
local function Button(parent,name,label,width,callback)
    local button=CreateFrame("Button",name,parent,"UIPanelButtonTemplate")
    button:SetWidth(width); button:SetHeight(30); button:SetText(L(label)); button.label=L(label)
    button:SetScript("OnClick",callback)
    if ConsoleExperience.theme then ConsoleExperience.theme:Button(button) end
    return button
end

function Config:SetBindingMode(mode)
    self.bindingOverview.mode=mode=="controls" and "controls" or "actions"
    if CloseDropDownMenus then CloseDropDownMenus() end
    self:RefreshBindingOverview()
    if ConsoleExperience.cursor and ConsoleExperience.cursor.RefreshFrame then ConsoleExperience.cursor:RefreshFrame() end
end

function Config:UpdateBindingModeVisual()
    local view=self.bindingOverview
    local controls=view.mode=="controls"
    for mode,button in pairs(view.modeButtons or {}) do
        button.themeSelected=mode==view.mode
        if ConsoleExperience.theme then ConsoleExperience.theme:Apply(button) end
    end
    view.intro:SetText(L(controls and "Sticks, triggers and menu buttons." or "Face buttons, D-pad and bumpers."))
    for _,row in ipairs(view.controlRows or {}) do
        if controls then row:Show() else
            row:Hide(); for _,line in ipairs(row.lines) do line:Hide() end
        end
    end
    if view.nativeMarker then view.nativeMarker:Hide() end
    if view.controlNotice then if controls then view.controlNotice:Show() else view.controlNotice:Hide() end end
    if view.controlTuning then if controls then view.controlTuning:Show() else view.controlTuning:Hide() end end
    if controls then view.placeButton:Hide() else view.placeButton:Show() end
    if not controls then
        view.changeButton:Enable(); view.changeButton:SetAlpha(1)
        view.changeButton.cursorPrompt=L("Change binding")
        view.editorHelp:SetText(L("Choose a spell, item, macro, or menu action."))
    end
    local label=L(controls and "Reset these controls" or "Reset Bindings")
    view.resetButton:SetText(label); view.resetButton.label=label
    view.resetButton.tooltipText=L(controls and "Restore the selected page's stick-click, trigger and menu-button assignments." or
        "Restores the default controller bindings for action slots and the quick menu. System-action assignments are kept.")
end

function Config:SelectControllerInput(input)
    local view=self.bindingOverview
    local control=Controls.INPUTS[input]
    if not control then return end
    view.selectedInput=input
    local info=Controls:GetInputInfo(input,view.page)
    view.editorTitle:SetText(Controls:GetInputName(input) .. "  /  " .. info.name)
    view.editorHelp:SetText(L(info.editable and "Assignment for the selected modifier page. Unassigned pages inherit the base." or "Contextual control. Adjust stick feel in Gameplay."))
    view.changeButton.tooltipText=info.description
    view.changeButton.cursorPrompt=L(info.editable and "Choose system action" or "Fixed control")
    if info.editable then view.changeButton:Enable(); view.changeButton:SetAlpha(1)
    else view.changeButton:Disable(); view.changeButton:SetAlpha(0.45) end
    self:PaintControllerBindings()
end

function Config:PaintControllerBindings()
    local view=self.bindingOverview
    if not view or view.mode~="controls" then return end
    local p=ConsoleExperience.theme:Palette()
    for _,row in ipairs(view.controlRows) do
        local active=row.input==view.selectedInput
        row:SetBackdropColor(p.card[1],p.card[2],p.card[3],active and 0.9 or 0.3)
        row.title:SetTextColor(unpack(active and p.focus or p.text))
        row.value:SetTextColor(unpack(p.muted))
        for _,line in ipairs(row.lines) do
            local color=active and p.accent or p.border
            line:SetVertexColor(color[1],color[2],color[3],active and 0.85 or 0.32)
        end
    end
    local control=Controls.INPUTS[view.selectedInput or "LS"]
    local point=control.points[self:Get("controllerType")=="ps" and 2 or 1]
    view.nativeMarker:ClearAllPoints()
    view.nativeMarker:SetPoint("CENTER",view.section,"TOPLEFT",view.width/2+(point[1]-256)*224/512,-285+(256-point[2])*180/409.6)
    view.nativeMarker:SetWidth(control.size); view.nativeMarker:SetHeight(control.size)
    view.nativeMarker:SetVertexColor(unpack(p.focus)); view.nativeMarker:Show()
    if self.ArrangeBindingRows then self:ArrangeBindingRows() end
end

function Config:RefreshControllerBindings()
    local view=self.bindingOverview
    self:UpdateBindingModeVisual()
    if view.page>4 then view.page=1 end
    local width=(view.width-50)/4
    for page,tab in ipairs(view.tabs) do
        if page<=4 then
            tab:SetWidth(width); tab:ClearAllPoints()
            tab:SetPoint("TOPLEFT",view.section,"TOPLEFT",16+(page-1)*(width+6),-82)
            tab.themeSelected=page==view.page; tab:Show()
            if ConsoleExperience.theme then ConsoleExperience.theme:Apply(tab) end
        else tab:Hide() end
    end
    for _,row in ipairs(view.rows) do row:Hide(); for _,line in ipairs(row.lines) do line:Hide() end end
    for _,marker in ipairs(view.controls) do marker:Hide() end
    view.fixedText:Hide(); view.triggerText:Hide(); view.touchHelp:Hide(); view.body:Show()
    local ps=self:Get("controllerType")=="ps"
    view.body:SetTexture(ROOT .. "bindings\\" .. (ps and "ps" or "xbox"))
    for _,row in ipairs(view.controlRows) do
        local info=Controls:GetInputInfo(row.input,view.page)
        row.title:SetText(Controls:GetInputName(row.input)); row.value:SetText(info.name)
        if ConsoleExperience.theme then
            ConsoleExperience.theme:Apply(row.title)
            ConsoleExperience.theme:Apply(row.value)
        end
        row.label=Controls:GetInputName(row.input) .. " / " .. info.name
        row.tooltipText=info.description
        row.cursorPrompt=L(info.editable and "Choose system action" or "View control")
        local point=Controls.INPUTS[row.input].points[ps and 2 or 1]
        local tx,ty=view.width/2+(point[1]-256)*224/512,-285+(256-point[2])*180/409.6
        local start=row.side=="left" and 228 or view.width-228
        local elbow=row.side=="left" and 240 or view.width-240
        local y=-164-(row.ordinal-1)*62
        Config.DrawBindingLine(row.lines[1],view.section,start,y,elbow,y)
        Config.DrawBindingLine(row.lines[2],view.section,elbow,y,tx,ty)
        for _,line in ipairs(row.lines) do line:Show() end
    end
    local native=WindrunnerController and WindrunnerController.HasNativeInput and WindrunnerController:HasNativeInput()
    view.controlNotice:SetText(L(native and "Native controls. The pause combination stays reserved." or "Native input required. Mapper keys: Open Key Bindings."))
    self:SelectControllerInput(view.selectedInput or "LS")
end

function Config:CreateControllerBindingView(view)
    view.mode="actions"; view.modeButtons={}; view.controlRows={}
    for index,mode in ipairs({"actions","controls"}) do
        local captured=mode
        local button=Button(view.section,"CEBindingMode" .. mode,mode=="actions" and "Action buttons" or "Other controls",170,
            function() Config:SetBindingMode(captured) end)
        button:SetPoint("TOPLEFT",view.section,"TOPLEFT",16+(index-1)*178,-44)
        view.modeButtons[mode]=button
    end
    view.intro:ClearAllPoints(); view.intro:SetPoint("TOPLEFT",view.section,"TOPLEFT",380,-43)
    view.intro:SetWidth(view.width-396); view.intro:SetHeight(32)
    view.nativeMarker=view.section:CreateTexture(nil,"OVERLAY")
    view.nativeMarker:SetTexture(ROOT .. "radial\\ring"); view.nativeMarker:Hide()
    view.controlNotice=Text(view.section,216,60,"muted")
    view.controlNotice:SetPoint("TOPLEFT",view.section,"TOPLEFT",view.width/2-108,-382)
    view.controlNotice:SetJustifyH("CENTER"); view.controlNotice:Hide()
    for sideIndex,inputs in ipairs({{"LS","LEFT_AXIS","LT","BACK","PAUSE"},{"RS","RIGHT_AXIS","RT","START","POINTER"}}) do
        for ordinal,input in ipairs(inputs) do
            local captured=input
            local row=CreateFrame("Button","CEBindingControl" .. input,view.section)
            row:SetWidth(212); row:SetHeight(60)
            row:SetPoint("TOPLEFT",view.section,"TOPLEFT",sideIndex==1 and 16 or view.width-228,-134-(ordinal-1)*62)
            row:SetBackdrop({bgFile=WHITE}); row.input=input; row.ordinal=ordinal; row.side=sideIndex==1 and "left" or "right"
            row.title=Text(row,188,20,"text"); row.title:SetPoint("TOPLEFT",row,"TOPLEFT",12,-5)
            row.themeLabel=row.title
            row.value=Text(row,188,35,"muted"); row.value:SetPoint("TOPLEFT",row,"TOPLEFT",12,-25)
            row.lines={}
            for i=1,2 do row.lines[i]=view.section:CreateTexture(nil,"BORDER"); row.lines[i]:SetTexture(WHITE); row.lines[i]:Hide() end
            row.cursorOnFocus=function() Config:SelectControllerInput(captured) end
            row:SetScript("OnEnter",function() Config:SelectControllerInput(captured) end)
            row:SetScript("OnClick",function()
                Config:SelectControllerInput(captured)
                if Controls:GetInputInfo(captured,view.page).editable then Config:OpenBindingActionMenu() end
            end)
            row:Hide(); table.insert(view.controlRows,row)
        end
    end
    view.controlTuning=Button(view.editor,"CEBindingControlTuning","Stick settings",156,function() Config:ShowSection("controller",true) end)
    view.controlTuning:SetPoint("TOPLEFT",view.editor,"TOPLEFT",216,-51); view.controlTuning:Hide()
end

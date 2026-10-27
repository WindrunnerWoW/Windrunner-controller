local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
-- Visual binding editor. Uses the same proxied-action backend as the action bars.
local Config = ConsoleExperience.config
local ROOT = "Interface\\AddOns\\Windrunner-Controller\\textures\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local LEFT_CONTROLS = {10, 7, 6, 8, 5}
local RIGHT_CONTROLS = {9, 3, 2, 4, 1}
local ICON_NAMES = {"a", "x", "y", "b", "down", "left", "up", "right", "rb", "lb"}
local CONTROL_NAMES = {"A", "X", "Y", "B", "Down", "Left", "Up", "Right", "RB", "LB"}
local PS_NAMES = {"Cross", "Square", "Triangle", "Circle", "Down", "Left", "Up", "Right", "R1", "L1"}
-- These coordinates share the 512px source canvas used by generate-binding-textures.py.
local CONTROL_POINTS = {
    xbox={{388,200},{357,169},{388,138},{419,169},{176,281},{153,258},{176,235},{199,258},{395,94},{117,94}},
    ps={{392,203},{361,172},{392,141},{423,172},{120,195},{97,172},{120,149},{143,172},{395,94},{117,94}},
}

local function L(key)
    return ConsoleExperience.locale and ConsoleExperience.locale.T(key) or key
end

local function Register(object, role, callback)
    if ConsoleExperience.theme then ConsoleExperience.theme:Register(object, role, callback) end
end

local function Text(parent, value, x, y, width, height, role, font)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    text:SetWidth(width); text:SetHeight(height)
    text:SetJustifyH("LEFT"); text:SetText(L(value))
    text:SetTextColor(0.94, 0.95, 0.97)
    Register(text, role or "text")
    return text
end

local function Texture(parent, layer, path, width, height)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetTexture(path); texture:SetWidth(width); texture:SetHeight(height)
    return texture
end

local function Button(parent, name, label, width, callback)
    local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    button:SetWidth(width); button:SetHeight(30); button:SetText(L(label))
    button.label = L(label); button.cursorPrompt = button.label
    button:SetScript("OnClick", callback)
    if ConsoleExperience.theme then ConsoleExperience.theme:Button(button) end
    return button
end

local function Palette()
    return ConsoleExperience.theme and ConsoleExperience.theme:Palette() or {
        bg={0.055,0.049,0.043}, card={0.105,0.093,0.078}, border={0.24,0.27,0.3},
        accent={1,0.73,0.32}, focus={1,0.82,0.35}, text={0.94,0.95,0.97}, muted={0.7,0.75,0.8}, opacity=0.96,
    }
end

local function IconPath(name)
    if Config:Get("controllerModifierSource")=="bumpers" then
        local swap={lb="lt",rb="rt",lt="lb",rt="rb"}
        name=swap[name] or name
    end
    local prompts=ConsoleExperience.controllerControls
    if prompts and prompts.GetGlyphName then name=prompts:GetGlyphName(name) end
    if name=="down" or name=="left" or name=="up" or name=="right" then
        return ROOT .. "controllers\\" .. name
    end
    return ROOT .. "controllers\\" .. (Config:Get("controllerType") or "xbox") .. "\\" .. name
end

local function ControlPoint(points,index)
    local point=points[index]
    if index>=9 and Config:Get("controllerModifierSource")=="bumpers" then return {point[1],75} end
    return point
end

local function ControlName(index)
    local token=string.upper(ICON_NAMES[index])
    if Config:Get("controllerModifierSource")=="bumpers" then
        if token=="LB" then token="LT" elseif token=="RB" then token="RT" end
    end
    return L(ConsoleExperience.controllerControls:GetPromptLabel(token))
end

local function ModifierName(page)
    local inputs=ConsoleExperience.controllerControls
    local bumpers=Config:Get("controllerModifierSource")=="bumpers"
    local left,right=inputs:GetPromptLabel(bumpers and "LB" or "LT"),inputs:GetPromptLabel(bumpers and "RB" or "RT")
    if page==2 then return left .. " / " .. L("Shift") end
    if page==3 then return right .. " / " .. L("Ctrl") end
    if page==4 then return left .. " + " .. right end
    if page==5 then return L("Touch bars") end
    return L("No Modifier")
end

function Config:GetBindingInputName(slot)
    if slot>40 then
        return L(slot<=45 and "Left" or "Right") .. " " .. (slot<=45 and slot-40 or slot-45)
    end
    local index = math.mod(slot-1,10)+1
    local page = math.floor((slot-1)/10)+1
    local inputs=ConsoleExperience.controllerControls
    local bumpers=self:Get("controllerModifierSource")=="bumpers"
    local left,right=inputs:GetPromptLabel(bumpers and "LB" or "LT"),inputs:GetPromptLabel(bumpers and "RB" or "RT")
    local prefix=page==2 and (left.." + ") or page==3 and (right.." + ") or page==4 and (left.." + "..right.." + ") or ""
    return prefix .. ControlName(index)
end

function Config:GetBindingSlotInfo(slot)
    local proxied = ConsoleExperience.proxied
    local id = proxied and proxied:GetSlotBinding(slot)
    local action = id and proxied:GetActionByID(id)
    local actionSlot = slot
    if slot<=10 then
        local bars = ConsoleExperience.actionbars
        if bars and bars.GetActionOffset then actionSlot = bars:GetActionOffset(1)+slot end
    end
    local info = {slot=slot, actionSlot=actionSlot, binding=id, name=action and action.name or id,
        icon=action and action.icon, description=action and action.desc}
    if id then return info end
    local occupied = HasAction and HasAction(actionSlot)
    info.icon = occupied and GetActionTexture and GetActionTexture(actionSlot) or nil
    if occupied then
        info.name = GetActionText and GetActionText(actionSlot)
        if not info.name or info.name=="" then
            -- Keep the shared tooltip and controller prompts untouched while reading names.
            local tooltip = self.bindingOverview and self.bindingOverview.actionTooltip
            if tooltip then
                tooltip:SetOwner(UIParent,"ANCHOR_NONE")
                tooltip:SetAction(actionSlot)
                local line = getglobal("CEBindingActionTooltipTextLeft1")
                info.name = line and line:GetText()
                tooltip:Hide()
            end
        end
    end
    if not info.name or info.name=="" then
        info.name = occupied and string.format(L("Slot %d"),slot) or L("Empty slot")
    end
    info.description = L("Without a system-action assignment, this controller input uses its action-bar slot.")
    return info
end

local function DrawLine(line, parent, x1, y1, x2, y2)
    local dx, dy = x2-x1, y2-y1
    line:ClearAllPoints()
    line:SetPoint("CENTER",parent,"TOPLEFT",(x1+x2)/2,(y1+y2)/2)
    line:SetWidth(math.max(1,math.abs(dx))); line:SetHeight(math.max(1,math.abs(dy)))
    if math.abs(dx)<1 or math.abs(dy)<1 then
        line:SetTexture(WHITE); line:SetTexCoord(0,1,0,1)
    else
        line:SetTexture(ROOT .. "bindings\\diagonal")
        if dx*dy>0 then line:SetTexCoord(0,1,1,0) else line:SetTexCoord(0,1,0,1) end
    end
end

Config.DrawBindingLine = DrawLine

function Config:PaintBindingOverview()
    if self.bindingOverview and self.bindingOverview.mode=="controls" then return self:PaintControllerBindings() end
    local view = self.bindingOverview
    if not view then return end
    local p = Palette()
    for _,row in ipairs(view.rows) do
        local active = row.slot==view.selectedSlot
        row:SetBackdropColor(p.card[1],p.card[2],p.card[3],active and 0.9 or 0.3)
        row.marker:SetVertexColor(unpack(p.focus))
        if active then row.marker:Show() else row.marker:Hide() end
        row.title:SetTextColor(unpack(active and p.focus or p.text))
        row.rule:SetVertexColor(p.border[1],p.border[2],p.border[3],0.4)
        for page,preview in ipairs(row.previews) do
            local current = view.page==5 or page==view.page
            local color = current and p.focus or p.border
            preview.border:SetVertexColor(color[1],color[2],color[3],current and 1 or 0.55)
            preview.icon:SetVertexColor(1,1,1,current and 1 or 0.55)
        end
        for _,line in ipairs(row.lines) do
            local color = active and p.accent or p.border
            line:SetVertexColor(color[1],color[2],color[3],active and 0.85 or 0.32)
        end
    end
    for index,marker in ipairs(view.controls) do
        if view.page~=5 and view.selectedSlot and math.mod(view.selectedSlot-1,10)+1==index then
            marker:SetVertexColor(p.focus[1],p.focus[2],p.focus[3],1); marker:Show()
        else marker:Hide() end
    end
    if self.ArrangeBindingRows then self:ArrangeBindingRows() end
end

function Config:SelectBindingSlot(slot)
    local view = self.bindingOverview
    if not view or not slot then return end
    view.selectedSlot = slot
    local info = view.info[slot] or self:GetBindingSlotInfo(slot)
    view.editorTitle:SetText(self:GetBindingInputName(slot) .. "  /  " .. (info.name or L("Empty slot")))
    view.changeButton.tooltipText = info.description
    -- A system action can be replaced by a spell, item, or macro from the same
    -- picker, so placement stays available even when the slot is assigned.
    if ConsoleExperience.placement then
        view.placeButton:Enable(); view.placeButton:SetAlpha(1)
    else view.placeButton:Disable(); view.placeButton:SetAlpha(0.45) end
    self:PaintBindingOverview()
end

function Config:SetBindingPage(page)
    local view = self.bindingOverview
    if not view then return end
    local current = view.selectedSlot or 1
    local index = current<=40 and math.mod(current-1,10)+1 or 1
    view.page = page
    view.mode = view.mode or "actions"
    view.selectedSlot = page<=4 and ((page-1)*10+index) or nil
    if CloseDropDownMenus then CloseDropDownMenus() end
    self:RefreshBindingOverview()
    if ConsoleExperience.cursor and ConsoleExperience.cursor.RefreshFrame then ConsoleExperience.cursor:RefreshFrame() end
end

function Config:RefreshBindingOverview()
    local view = self.bindingOverview
    if not view then return end
    if view.mode=="controls" then self:RefreshControllerBindings(); return end
    self:UpdateBindingModeVisual()
    local leftEnabled, rightEnabled = self:Get("sideBarLeftEnabled"), self:Get("sideBarRightEnabled")
    local hasTouch = leftEnabled or rightEnabled
    if view.page==5 and not hasTouch then view.page=1; view.selectedSlot=1 end
    local tabCount = hasTouch and 5 or 4
    local width = (view.width-32-(tabCount-1)*6)/tabCount
    for page,tab in ipairs(view.tabs) do
        tab:SetWidth(width); tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT",view.section,"TOPLEFT",16+(page-1)*(width+6),-82)
        tab:SetText(ModifierName(page)); tab.label=ModifierName(page)
        tab.themeSelected = page==view.page
        if page==5 and not hasTouch then tab:Hide() else tab:Show() end
        if ConsoleExperience.theme then ConsoleExperience.theme:Apply(tab) end
    end
    local ps = self:Get("controllerType")=="ps"
    view.body:SetTexture(ROOT .. "bindings\\" .. (ps and "ps" or "xbox"))
    local points = CONTROL_POINTS[ps and "ps" or "xbox"]
    view.info = {}
    local selectedVisible
    for _,row in ipairs(view.rows) do
        local touch = view.page==5
        row.slot = touch and ((row.side=="left" and 40 or 45)+row.ordinal)
            or ((view.page-1)*10+row.controlIndex)
        local count = self:Get(row.side=="left" and "sideBarLeftButtons" or "sideBarRightButtons") or 3
        count = math.max(1,math.min(5,count))
        local enabled = row.side=="left" and leftEnabled or row.side=="right" and rightEnabled
        local visible = not touch or (enabled and row.ordinal<=count)
        if visible then row:Show() else row:Hide() end
        if visible and row.slot==view.selectedSlot then selectedVisible=true end
        row.glyph:SetTexture(touch and nil or IconPath(ICON_NAMES[row.controlIndex]))
        if touch then row.glyph:Hide() else row.glyph:Show() end
        for page,preview in ipairs(row.previews) do
            local slot = touch and row.slot or ((page-1)*10+row.controlIndex)
            if not touch or page==1 then
                local info = view.info[slot] or self:GetBindingSlotInfo(slot)
                view.info[slot] = info
                preview.bg:Show(); preview.border:Show()
                if info.icon then
                    if preview.path~=info.icon then SetPortraitToTexture(preview.icon,info.icon); preview.path=info.icon end
                    preview.icon:Show()
                else preview.icon:Hide(); preview.path=nil end
            else preview.bg:Hide(); preview.border:Hide(); preview.icon:Hide() end
        end
        local info = view.info[row.slot]
        row.title:SetText(info and info.name or L("Empty slot"))
        row.slotLabel:SetText(string.format(L("Slot %d"),row.slot))
        row.label = self:GetBindingInputName(row.slot) .. " / " .. (info and info.name or "")
        row.tooltipText = info and info.description
        local point = ControlPoint(points,row.controlIndex)
        local tx,ty = view.width/2+(point[1]-256)*224/512, -285+(256-point[2])*180/409.6
        local startX = row.side=="left" and 228 or view.width-228
        local elbow = row.side=="left" and 240 or view.width-240
        local rowY = -164-(row.ordinal-1)*62
        DrawLine(row.lines[1],view.section,startX,rowY,elbow,rowY)
        DrawLine(row.lines[2],view.section,elbow,rowY,tx,ty)
        for _,line in ipairs(row.lines) do if touch or not visible then line:Hide() else line:Show() end end
    end
    for index,marker in ipairs(view.controls) do
        local point=ControlPoint(points,index)
        marker:ClearAllPoints()
        marker:SetPoint("CENTER",view.section,"TOPLEFT",view.width/2+(point[1]-256)*224/512,-285+(256-point[2])*180/409.6)
    end
    if view.page==5 then
        view.body:Hide(); view.triggerText:Hide(); view.fixedText:Hide(); view.touchHelp:Show()
    else
        view.body:Show(); view.triggerText:Show(); view.fixedText:Show(); view.touchHelp:Hide()
    end
    local inputs=ConsoleExperience.controllerControls
    local bumpers=self:Get("controllerModifierSource")=="bumpers"
    view.triggerText:SetText(inputs:GetPromptLabel(bumpers and "LB" or "LT")..": "..L("Shift").."    "..inputs:GetPromptLabel(bumpers and "RB" or "RT")..": "..L("Ctrl"))
    view.fixedText:SetText(inputs:GetInputName("BACK") .. ": " .. inputs:GetInputInfo("BACK",view.page).name .. "\n"
        .. inputs:GetInputName("START") .. ": " .. inputs:GetInputInfo("START",view.page).name)
    if not selectedVisible then
        view.selectedSlot=nil
        for _,row in ipairs(view.rows) do if row:IsShown() then view.selectedSlot=row.slot; break end end
    end
    self:SelectBindingSlot(view.selectedSlot)
end

function Config:OpenBindingActionMenu()
    local view=self.bindingOverview
    local picker=ConsoleExperience.actionpicker
    if not view or not picker then return false end
    if view and view.mode=="controls" then
        local input=view.selectedInput
        return input and picker:OpenForControllerInput(input,view.page) or false
    end
    return view.selectedSlot and picker:OpenForSlotBinding(view.selectedSlot, "spells") or false
end

function Config:CreateBindingsSection()
    local section=self:CreateScrollableSection("bindings")
    section:Hide()
    local view={section=section,width=section:GetWidth(),
        page=1,selectedSlot=1,tabs={},rows={},controls={},info={}}
    self.bindingOverview=view
    Text(section,"Controller bindings",16,-12,430,26,"text","GameFontNormalLarge")
    view.intro=Text(section,"Pick a controller input, then choose a spell, item, macro, or menu action.",16,-43,view.width-32,28,"muted")
    local gameBindings=Button(section,"CEBindingOpenKeyBindings","Open Key Bindings",165,function()
        if Config.OpenGameKeyBindings and KeyBindingFrame_LoadUI and ShowUIPanel then
            Config:Hide(); Config.OpenGameKeyBindings()
        end
    end)
    gameBindings:SetPoint("TOPLEFT",section,"TOPLEFT",16,-80)
    gameBindings:SetWidth(view.width-32); gameBindings:SetHeight(40)
    for page=1,5 do
        local captured=page
        view.tabs[page]=Button(section,"CEBindingModifierButton"..page,ModifierName(page),120,function() Config:SetBindingPage(captured) end)
    end
    view.body=Texture(section,"ARTWORK",ROOT.."bindings\\xbox",224,180)
    view.body:SetPoint("CENTER",section,"TOPLEFT",view.width/2,-285)
    view.body:SetTexCoord(0,1,0.1,0.9)
    view.triggerText=Text(section,"",view.width/2-108,-148,216,28,"accent")
    view.triggerText:SetJustifyH("CENTER")
    view.fixedText=Text(section,"",view.width/2-108,-382,216,64,"muted")
    view.fixedText:SetJustifyH("CENTER")
    view.touchHelp=Text(section,"Touch bars use their own action slots. Enable and size them in Bars.",view.width/2-97,-230,194,90,"muted")
    view.touchHelp:SetJustifyH("CENTER")
    for index=1,10 do
        local marker=Texture(section,"OVERLAY",ROOT.."radial\\ring",index>=9 and 38 or (index<=4 and 22 or 18),index>=9 and 14 or (index<=4 and 22 or 18))
        marker:Hide(); view.controls[index]=marker
    end
    for sideIndex,indices in ipairs({LEFT_CONTROLS,RIGHT_CONTROLS}) do
        local side=sideIndex==1 and "left" or "right"
        for ordinal,controlIndex in ipairs(indices) do
            local row=CreateFrame("Button","CEBindingInput"..controlIndex,section)
            row:SetWidth(212); row:SetHeight(60)
            row:SetPoint("TOPLEFT",section,"TOPLEFT",sideIndex==1 and 16 or view.width-228,-134-(ordinal-1)*62)
            row:SetBackdrop({bgFile=WHITE})
            row.controlIndex=controlIndex; row.ordinal=ordinal; row.side=side
            row.previews={}; row.lines={}
            row.title=Text(row,"",12,-1,162,38,"text","GameFontNormalSmall")
            row.title.themeSemantic=true
            row.slotLabel=Text(row,"",110,-41,94,18,"muted")
            row.slotLabel:SetJustifyH("RIGHT")
            row.glyph=Texture(row,"OVERLAY",IconPath(ICON_NAMES[controlIndex]),24,24)
            row.glyph:SetPoint("TOPRIGHT",row,"TOPRIGHT",-7,-9)
            row.marker=Texture(row,"OVERLAY",WHITE,2,58)
            row.marker:SetPoint("LEFT",row,"LEFT",0,0)
            row.rule=Texture(row,"BORDER",WHITE,210,1)
            row.rule:SetPoint("BOTTOM",row,"BOTTOM",0,0)
            for page=1,4 do
                local preview={}
                preview.bg=Texture(row,"BACKGROUND",ROOT.."radial\\disc",20,20)
                preview.bg:SetPoint("TOPLEFT",row,"TOPLEFT",10+(page-1)*24,-40)
                preview.bg:SetVertexColor(0.015,0.018,0.024,1)
                preview.icon=Texture(row,"ARTWORK",nil,17,17)
                preview.icon:SetPoint("CENTER",preview.bg,"CENTER",0,0)
                preview.border=Texture(row,"OVERLAY",ROOT.."radial\\ring",22,22)
                preview.border:SetPoint("CENTER",preview.bg,"CENTER",0,0)
                row.previews[page]=preview
            end
            for i=1,2 do row.lines[i]=Texture(section,"BORDER",WHITE,1,1) end
            row.cursorPrompt=L("Choose system action")
            row.cursorOnFocus=function(button) Config:SelectBindingSlot(button.slot) end
            row:SetScript("OnEnter",function() Config:SelectBindingSlot(this.slot) end)
            row:SetScript("OnClick",function() Config:SelectBindingSlot(this.slot); Config:OpenBindingActionMenu() end)
            table.insert(view.rows,row)
        end
    end
    local editor=CreateFrame("Frame","CEBindingEditor",section)
    editor:SetPoint("TOPLEFT",section,"TOPLEFT",16,-458)
    editor:SetPoint("TOPRIGHT",section,"TOPRIGHT",-16,-458)
    editor:SetHeight(88); Register(editor,"card")
    view.editor=editor
    view.editorTitle=Text(editor,"",14,-8,view.width-64,20,"accent","GameFontNormal")
    view.editorHelp=Text(editor,"Choose a spell, item, macro, or menu action.",14,-29,view.width-64,18,"muted")
    view.changeButton=Button(editor,"CEBindingChangeAction","Change Binding",190,function() Config:OpenBindingActionMenu() end)
    view.changeButton:SetPoint("TOPLEFT",editor,"TOPLEFT",14,-51)
    view.placeButton=Button(editor,"CEConfigShowPlacement","Bind Spell or Item",156,function()
        if ConsoleExperience.actionpicker then
            ConsoleExperience.actionpicker:OpenForSlotBinding(view.selectedSlot, "spells")
        elseif ConsoleExperience.placement then ConsoleExperience.placement:Show(); Config:Hide() end
    end)
    view.placeButton:SetPoint("TOPLEFT",editor,"TOPLEFT",216,-51)
    view.placeButton.tooltipText=L("Opens the spells list. Choosing a spell, item, or macro replaces any system action on this slot.")
    local reset=Button(editor,"CEConfigResetBindings","Reset Bindings",220,function()
        if view.mode=="controls" then
            for _,input in ipairs({"LS","RS","BACK","START"}) do
                local control=ConsoleExperience.controllerControls.INPUTS[input]
                ConsoleExperience.controllerControls:SetBinding(input,control.default,view.page)
            end
            Config:RefreshBindingOverview()
        else StaticPopup_Show("CE_RESET_BINDINGS") end
    end)
    view.resetButton=reset
    reset:SetPoint("TOPRIGHT",editor,"TOPRIGHT",-14,-51)
    reset.tooltipText=L("Restores the default controller bindings for action slots and the quick menu. System-action assignments are kept.")
    view.actionTooltip=CreateFrame("GameTooltip","CEBindingActionTooltip",UIParent,"GameTooltipTemplate")
    view.actionTooltip:Hide()
    for _,event in ipairs({"ACTIONBAR_SLOT_CHANGED","UPDATE_BONUS_ACTIONBAR","PLAYER_ENTERING_WORLD","SPELLS_CHANGED","UPDATE_MACROS"}) do section:RegisterEvent(event) end
    section:SetScript("OnEvent",function() if section:IsVisible() then Config:RefreshBindingOverview() end end)
    section:SetScript("OnHide",function() if CloseDropDownMenus then CloseDropDownMenus() end end)
    Register(section,"binding-overview",function() Config:PaintBindingOverview() end)
    self.contentSections.bindings=section
    self:CreateControllerBindingView(view)
    view.intro:ClearAllPoints(); view.intro:SetPoint("TOPLEFT",section,"TOPLEFT",16,-44); view.intro:SetWidth(view.width-32)
    view.modeRow=self:CreateSettingRow(section,"CEBindingGroup","Inputs",function() return "<  "..L(view.mode=="controls" and "Other controls" or "Action buttons").."  >" end,function(delta)
        Config:SetBindingMode(delta<0 and "actions" or "controls")
    end)
    view.modeRow:SetPoint("TOPLEFT",section,"TOPLEFT",16,-128)
    view.pageRow=self:CreateSettingRow(section,"CEBindingPage","Modifier page",function() return "<  "..ModifierName(view.page).."  >" end,function(delta)
        local touch=view.mode~="controls" and (Config:Get("sideBarLeftEnabled") or Config:Get("sideBarRightEnabled"))
        Config:SetBindingPage(math.max(1,math.min(touch and 5 or 4,view.page+delta)))
    end)
    view.pageRow:SetPoint("TOPLEFT",section,"TOPLEFT",16,-176)
    self:RefreshBindingOverview()
end

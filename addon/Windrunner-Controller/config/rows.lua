local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
-- Each preference occupies one row and one controller focus stop.
local Config=ConsoleExperience.config
local function L(key) return ConsoleExperience.locale and ConsoleExperience.locale.T(key) or key end
local function Invoke(frame,script)
    local callback=frame:GetScript(script)
    if not callback then return end
    local previous=this; this=frame; callback(); this=previous
end

function Config:CreateSettingRow(parent,name,label,getValue,adjust,activate)
    local row=CreateFrame("Button",name,parent)
    row:SetWidth(parent:GetWidth()-32); row:SetHeight(40)
    row.label=L(label); row.cursorPrompt=L("Select")
    row.ceSettingRow=true
    row:RegisterForClicks("LeftButtonUp","RightButtonUp")
    local text=row:CreateFontString(nil,"OVERLAY","GameFontNormal")
    text:SetPoint("LEFT",row,"LEFT",12,0); text:SetWidth(row:GetWidth()-224)
    text:SetHeight(32); text:SetJustifyV("CENTER")
    text:SetJustifyH("LEFT"); text:SetText(row.label)
    local value=row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    value:SetPoint("RIGHT",row,"RIGHT",-12,0); value:SetWidth(192); value:SetJustifyH("RIGHT")
    row.valueText=value
    if ConsoleExperience.theme and getValue then
        local well=ConsoleExperience.theme:Art(row,"valueWell","button","BACKGROUND")
        well:SetWidth(202); well:SetHeight(30); well:SetPoint("RIGHT",row,"RIGHT",-5,0)
        ConsoleExperience.theme:Register(well,"custom",function(region,p) region:SetVertexColor(p.bg[1]*0.65,p.bg[2]*0.65,p.bg[3]*0.65,0.96) end)
    end
    row.refreshFromProfile=function() if getValue then value:SetText(getValue() or "") end end
    row.cursorAdjust=adjust and function(direction) adjust(direction=="LEFT" and -1 or 1); row.refreshFromProfile() end
    row:SetScript("OnClick",function()
        if activate then activate() elseif adjust then adjust(arg1=="RightButton" and -1 or 1) end
        row.refreshFromProfile()
    end)
    if ConsoleExperience.theme then
        ConsoleExperience.theme:Button(row,text)
        ConsoleExperience.theme:Register(value,"accent")
        if activate and not getValue then ConsoleExperience.theme:ActionButton(row) end
    end
    row.refreshFromProfile()
    return row
end

function Config:CreateChoiceRow(parent,name,label,key,choices,changed)
    local function Current()
        for i,choice in ipairs(choices) do if choice[1]==Config:Get(key) then return i end end
        return 1
    end
    return self:CreateSettingRow(parent,name,label,function() return "<  "..L(choices[Current()][2]).."  >" end,function(delta)
        local index=math.max(1,math.min(table.getn(choices),Current()+delta))
        Config:Set(key,choices[index][1]); if changed then changed() end
    end)
end

local function LabelRegion(control,box)
    if control.cursorFocusRegion and control.cursorFocusRegion.GetObjectType
        and control.cursorFocusRegion:GetObjectType()=="FontString" then return control.cursorFocusRegion end
    for i=1,(control.GetNumPoints and control:GetNumPoints() or 1) do
        local point,relative=control:GetPoint(i)
        if type(relative)=="string" then relative=getglobal(relative) end
        if (point=="LEFT" or point=="RIGHT") and relative and relative.GetObjectType
            and relative:GetObjectType()=="FontString" and relative:GetParent()==box then return relative end
    end
end

local function AdjustDropdown(dropdown,button,direction)
    if not dropdown.initialize then return end
    local choices={}
    local addButton=UIDropDownMenu_AddButton
    UIDropDownMenu_AddButton=function(info)
        if info.func and not info.disabled and not info.isTitle then
            local copy={}; for key,value in pairs(info) do copy[key]=value end
            table.insert(choices,copy)
        end
    end
    local ok=pcall(dropdown.initialize)
    UIDropDownMenu_AddButton=addButton
    if not ok or table.getn(choices)==0 then return end
    local selected=1
    for i,choice in ipairs(choices) do if choice.checked then selected=i end end
    local index=math.max(1,math.min(table.getn(choices),selected+(direction=="LEFT" and -1 or 1)))
    if index==selected then return end
    local previous,previousValue=this,button.value
    this=button; button.value=choices[index].value
    local success,err=pcall(choices[index].func)
    this=previous; button.value=previousValue
    if not success and CE_Debug then CE_Debug("Settings choice failed: "..tostring(err)) end
end

-- Keep the existing setters, profile refreshers and mouse widgets; only replace
-- their dense columns with a vertical layout and a whole-row focus outline.
function Config:ArrangeSettingsRows(section)
    if section.ceRowsArranged then return end
    section.ceRowsArranged=true
    local previous
    for _,box in ipairs({section:GetChildren()}) do
        if box.CalculateHeight then
            local offset=math.max(25,(section:GetTop() or 0)-(box:GetTop() or 0))
            box:ClearAllPoints(); box:SetWidth(section:GetWidth()-10)
            box:SetPoint("TOPLEFT",previous or section,previous and "BOTTOMLEFT" or "TOPLEFT",previous and 0 or 5,previous and -30 or -offset)
            previous=box
        end
        if box.CalculateHeight and not box.ceCustomRows then
            local entries,labels={},{}
            for _,control in ipairs({box:GetChildren()}) do
                local kind=control:GetObjectType()
                local dropdown=control:GetName() and getglobal(control:GetName().."Button")
                if kind=="EditBox" or kind=="CheckButton" or kind=="Button" or dropdown then
                    local label=LabelRegion(control,box)
                    if label then labels[label]=true end
                    table.insert(entries,{control=control,label=label,dropdown=dropdown,kind=kind})
                end
            end
            if table.getn(entries)>0 then
                local y=18
                -- Descriptions stay above their settings, with room for wrapping.
                for _,region in ipairs({box:GetRegions()}) do
                    if region:GetObjectType()=="FontString" and not labels[region] and region:IsShown() and region:GetText() and region:GetText()~="" then
                        region:ClearAllPoints(); region:SetPoint("TOPLEFT",box,"TOPLEFT",16,-y)
                        region:SetWidth(box:GetWidth()-32); region:SetJustifyH("LEFT")
                        y=y+math.max(24,region:GetHeight() or 14)+12
                    end
                end
                for _,entry in ipairs(entries) do
                    local control,label,kind=entry.control,entry.label,entry.kind
                    local row=CreateFrame("Frame",nil,box)
                    row.cursorIgnore=true; row:SetWidth(box:GetWidth()-32); row:SetHeight(40)
                    row:SetPoint("TOPLEFT",box,"TOPLEFT",16,-y)
                    if ConsoleExperience.theme and kind~="Button" then
                        -- Labels still belong to the section box. Keep their
                        -- decoration on that frame's background layer rather
                        -- than a child frame, which would cover the labels.
                        local theme=ConsoleExperience.theme
                        local surface=box:CreateTexture(nil,"BACKGROUND")
                        surface:SetTexture(theme.ART.."button"); surface:SetAllPoints(row)
                        theme:Register(surface,"custom",function(region,p)
                            region:SetVertexColor(p.card[1]+0.015,p.card[2]+0.015,p.card[3]+0.015,p.opacity)
                        end)
                        local rule=box:CreateTexture(nil,"BORDER")
                        rule:SetTexture(theme.ART.."rule"); rule:SetHeight(1)
                        rule:SetPoint("TOPLEFT",row,"TOPLEFT",0,0); rule:SetPoint("TOPRIGHT",row,"TOPRIGHT",0,0)
                        theme:Register(rule,"custom",function(region,p) region:SetVertexColor(p.metal[1],p.metal[2],p.metal[3],0.45) end)
                    end
                    control.ceSettingsRow=row
                    control.ceSettingsLabel=label
                    control:ClearAllPoints()
                    local actionButton=kind=="Button" and not entry.dropdown and not control.colorPreview
                    if actionButton then
                        control:SetPoint("TOPLEFT",row,"TOPLEFT",0,0)
                        control:SetWidth(row:GetWidth()); control:SetHeight(40)
                    elseif kind=="CheckButton" then
                        control:SetPoint("LEFT",row,"LEFT",0,0)
                        control.cursorAdjust=function(direction)
                            local checked=control:GetChecked()==1 or control:GetChecked()==true
                            local wanted=direction=="RIGHT"
                            if checked~=wanted then control:SetChecked(wanted and 1 or 0); Invoke(control,"OnClick") end
                        end
                        if label then
                            label:ClearAllPoints(); label:SetPoint("LEFT",row,"LEFT",32,0)
                            label:SetWidth(row:GetWidth()-40); label:SetHeight(32); label:SetJustifyH("LEFT")
                            control:SetHitRectInsets(0,-(row:GetWidth()-24),-8,-8)
                        end
                    else
                        if label then
                            label:ClearAllPoints(); label:SetPoint("LEFT",row,"LEFT",8,0)
                            label:SetWidth(row:GetWidth()-254); label:SetHeight(32); label:SetJustifyH("LEFT")
                            if kind=="EditBox" and control.label then label:SetText(control.label) end
                        end
                        if control.colorPreview then
                            control:SetWidth(80); control:SetHeight(28); control:SetPoint("RIGHT",row,"RIGHT",-8,0)
                        elseif kind=="EditBox" then
                            control:SetWidth(104); control:SetHeight(28)
                            control:SetPoint("RIGHT",row,"RIGHT",-28,0)
                            local up=getglobal(control:GetName().."Up")
                            local down=getglobal(control:GetName().."Down")
                            if up and down then
                                up.cursorIgnore=true; down.cursorIgnore=true
                                control.cursorAdjust=function(direction) Invoke(direction=="LEFT" and down or up,"OnClick") end
                            end
                        else
                            control:SetPoint("RIGHT",row,"RIGHT",8,0)
                            UIDropDownMenu_SetWidth(200,control)
                            if entry.dropdown then
                                local dropdownButton=entry.dropdown
                                dropdownButton.ceSettingsRow=row
                                dropdownButton.cursorAdjust=function(direction) AdjustDropdown(control,dropdownButton,direction) end
                            end
                        end
                    end
                    if label and actionButton then label:Hide() end
                    if control:IsShown() then y=y+48 end
                end
                box:SetHeight(y+10); box.heightCalculated=true
            end
        end
    end
end

function Config:ArrangeBindingRows()
    local view=self.bindingOverview
    if not view or not view.pageRow then return end
    for _,button in ipairs(view.tabs) do button:Hide() end
    for _,button in pairs(view.modeButtons) do button:Hide() end
    for _,frame in ipairs({view.body,view.triggerText,view.fixedText,view.touchHelp,view.nativeMarker,view.controlNotice}) do frame:Hide() end
    for _,marker in ipairs(view.controls) do marker:Hide() end
    local index=0
    local controls=view.mode=="controls"
    for _,row in ipairs(controls and view.controlRows or view.rows) do
        if row:IsShown() then
            row:ClearAllPoints(); row:SetPoint("TOPLEFT",view.section,"TOPLEFT",16,-236-index*68)
            row:SetWidth(view.width-32); row:SetHeight(60)
            row.title:SetWidth(row:GetWidth()-160)
            if controls then
                row.value:SetWidth(row:GetWidth()-24)
            else
                row.title:SetText(self:GetBindingInputName(row.slot)..": "..(view.info[row.slot].name or L("Empty slot")))
                row.slotLabel:ClearAllPoints(); row.slotLabel:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",-8,4)
                row.rule:SetWidth(row:GetWidth()); row.marker:SetHeight(58)
                for page,preview in ipairs(row.previews) do
                    preview.bg:ClearAllPoints(); preview.bg:SetPoint("TOPLEFT",row,"TOPLEFT",row:GetWidth()-132+(page-1)*24,-36)
                end
            end
            index=index+1
        end
        for _,line in ipairs(row.lines) do line:Hide() end
    end
    view.editor:ClearAllPoints(); view.editor:SetPoint("TOPLEFT",view.section,"TOPLEFT",16,-236-index*68-12)
    view.editor:SetWidth(view.width-32); view.editor:SetHeight(214)
    local buttonIndex=0
    for _,button in ipairs({view.changeButton,controls and view.controlTuning or view.placeButton,view.resetButton}) do
        button:ClearAllPoints(); button:SetPoint("TOPLEFT",view.editor,"TOPLEFT",12,-64-buttonIndex*48)
        button:SetWidth(view.editor:GetWidth()-24); button:SetHeight(40); buttonIndex=buttonIndex+1
    end
    view.pageRow.refreshFromProfile(); view.modeRow.refreshFromProfile()
    self:UpdateScrollableSectionHeight(view.section)
end

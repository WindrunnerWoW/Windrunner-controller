local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
local Config, Theme = ConsoleExperience.config, ConsoleExperience.theme
local function L(key) return ConsoleExperience.locale and ConsoleExperience.locale.T(key) or key end
local function Text(parent, value, x, y, width, role, font)
    local region = parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
    region:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    region:SetWidth(width); region:SetJustifyH("LEFT"); region:SetText(L(value))
    Theme:Register(region,role or "text")
    return region
end
local function Button(parent, name, label, width, height, callback)
    local button = CreateFrame("Button",name,parent,"UIPanelButtonTemplate")
    button:SetWidth(width); button:SetHeight(height); button:SetText(L(label))
    button.label=L(label); button.cursorPrompt=L(label)
    button:SetScript("OnClick",callback)
    Theme:Button(button)
    return button
end
function Config:PickAccentColor()
    if not ColorPickerFrame then return end
    local old = {self:Get("uiAccent"),Theme:Get("uiAccentR"),Theme:Get("uiAccentG"),Theme:Get("uiAccentB")}
    local color = Theme:Palette().accent
    local function Apply(r,g,b,choice)
        Config:Set("uiAccentR",r,true); Config:Set("uiAccentG",g,true); Config:Set("uiAccentB",b,true)
        Config:Set("uiAccent",choice)
    end
    ColorPickerFrame:Hide()
    ColorPickerFrame.hasOpacity=false
    ColorPickerFrame.opacityFunc=nil
    ColorPickerFrame.func=function()
        local r,g,b=ColorPickerFrame:GetColorRGB()
        Apply(r,g,b,"custom")
    end
    ColorPickerFrame.cancelFunc=function() Apply(old[2],old[3],old[4],old[1]) end
    ColorPickerFrame:SetColorRGB(unpack(color))
    ColorPickerFrame:Show()
end
function Config:CreateAppearanceSection()
    local section=self:CreateScrollableSection("appearance"); section:Hide()
    Text(section,"Make it your own",16,-12,600,"accent","GameFontNormalLarge")
    Text(section,"A shared look for your menus, keyboard and controller focus.",16,-40,620,"muted")
    local previous
    local function Box(title,height)
        local box=Config:CreateSectionBox(section,L(title),height)
        box.ceCustomRows=true
        -- Rows are hand-positioned on a fixed grid, so the authored height is
        -- authoritative. Re-measuring would let the card grow on repaints.
        box.fixedHeight=true
        box.heightCalculated=true
        box:SetPoint("TOPLEFT",previous or section,previous and "BOTTOMLEFT" or "TOPLEFT",previous and 0 or 5,previous and -30 or -88)
        previous=box; return box
    end
    local rows={}
    local function Place(row,box,index)
        row:SetPoint("TOPLEFT",box,"TOPLEFT",16,-16-(index-1)*48)
        table.insert(rows,row); return row
    end
    local look=Box("Theme and color",176)
    Place(self:CreateChoiceRow(look,"CEAppearanceTheme","Theme","uiTheme",{{"ember","Ember"},{"frost","Frost"},{"grove","Grove"}},function() Config:Set("uiAccent","theme") end),look,1)
    Place(self:CreateChoiceRow(look,"CEAppearanceAccent","Accent color","uiAccent",{{"theme","Theme"},{"gold","Gold"},{"ice","Ice"},{"emerald","Jade"},{"violet","Violet"},{"rose","Rose"},{"class","Class"},{"custom","Custom"}}),look,2)
    Place(self:CreateSettingRow(look,"CEAppearanceCustomColor","Choose custom color",nil,nil,function() Config:PickAccentColor() end),look,3)
    local tuning=Box("Size and readability",416)
    local function Stepper(key,label,index,step,percent)
        Place(Config:CreateSettingRow(tuning,"CEAppearance"..key,label,function()
            local current=Theme:Get(key)
            return "<  "..(percent and string.format("%d%%",math.floor(current*100+0.5)) or tostring(current)).."  >"
        end,function(delta)
            local range=Theme.RANGES[key]
            local value=math.floor((Theme:Get(key)+delta*step)*100+0.5)/100
            Config:Set(key,math.max(range[1],math.min(range[2],value)))
        end),tuning,index)
    end
    Stepper("uiPanelOpacity","Panel opacity",1,0.04,true)
    Stepper("uiMenuScale","Settings scale",2,0.05,true)
    Stepper("uiRadialScale","Quick-menu scale",3,0.05,true)
    Stepper("uiTextScale","Text size",4,0.05,true)
    Stepper("uiFocusThickness","Focus outline",5,1,false)
    Stepper("uiHintDuration","Hint duration (seconds)",6,0.5,false)
    for index,choice in ipairs({{"uiReducedMotion","Reduce animation"},{"uiShowPointer","Show navigation pointer"}}) do
        Place(self:CreateChoiceRow(tuning,"CEAppearance"..choice[1],choice[2],choice[1],{{false,"Off"},{true,"On"}}),tuning,index+6)
    end
    local layout=Box("Action-bar layout",128)
    local sizes={{"Compact",48,53,430},{"Balanced",60,65,600},{"Large",72,78,660}}
    local function SizeIndex()
        local size=Config:Get("barButtonSize") or 60
        if size<=48 then return 1 elseif size>=72 then return 3 end
        return 2
    end
    Place(self:CreateSettingRow(layout,"CEAppearanceLayout","Button size",function() return "<  "..L(sizes[SizeIndex()][1]).."  >" end,function(delta)
        local choice=sizes[math.max(1,math.min(3,SizeIndex()+delta))]
        Config:Set("barButtonSize",choice[2]); Config:Set("barPadding",choice[3]); Config:Set("barStarPadding",choice[4])
        Config:UpdateActionBarLayout()
    end),layout,1)
    Place(self:CreateChoiceRow(layout,"CEAppearanceStyle","Appearance","barAppearance",{{"classic","Classic"},{"modern","Modern"}},function() Config:UpdateActionBarLayout() end),layout,2)
    local labels=Box("Controller labels",368)
    local function Bars() return ConsoleExperience.actionbars end
    local presetNames={reference="Reference symbols",badges="Round badges",custom="Custom"}
    Place(self:CreateSettingRow(labels,"CEAppearanceLabelPreset","Label preset",function()
        local preset=Bars() and Bars().GetControllerLabelPreset and Bars():GetControllerLabelPreset() or "reference"
        return "<  "..L(presetNames[preset]).."  >"
    end,function(delta)
        if Bars() and Bars().ApplyControllerLabelPreset then Bars():ApplyControllerLabelPreset(delta<0 and "reference" or "badges") end
    end),labels,1)
    Place(self:CreateChoiceRow(labels,"CEAppearanceLabelEnabled","Show controller labels","barLabelEnabled",{{false,"Off"},{true,"On"}}),labels,2)
    Place(self:CreateChoiceRow(labels,"CEAppearanceLabelBackground","Label background","barLabelBackground",{{false,"None"},{true,"Round badge"}}),labels,3)
    local function LabelNumber(key,label,index,low,high)
        Place(self:CreateSettingRow(labels,"CEAppearance"..key,label,function() return "<  "..tostring(Config:Get(key)).."  >" end,function(delta)
            Config:Set(key,math.max(low,math.min(high,(tonumber(Config:Get(key)) or Config.DEFAULTS[key])+delta)))
        end),labels,index)
    end
    LabelNumber("barLabelSize","Label size",4,8,48)
    Place(self:CreateChoiceRow(labels,"CEAppearanceLabelAnchor","Label position","barLabelAnchor",{{"TOP","Top"},{"BOTTOM","Bottom"},{"LEFT","Left"},{"RIGHT","Right"},{"CENTER","Center"}}),labels,5)
    LabelNumber("barLabelX","Label horizontal offset",6,-80,80)
    LabelNumber("barLabelY","Label vertical offset",7,-80,80)
    local reset=Button(section,"CEAppearanceReset","Reset appearance",section:GetWidth()-32,40,function()
        Theme:Reset()
        if Bars() and Bars().ApplyControllerLabelPreset then Bars():ApplyControllerLabelPreset("reference") end
        section:RefreshAppearance()
    end)
    reset:SetPoint("TOPLEFT",labels,"BOTTOMLEFT",0,-20)
    reset.tooltipText=L("Reset colors, menu sizes and readability. Keep your bars, bindings and profiles.")
    section.RefreshAppearance=function() for _,row in ipairs(rows) do row.refreshFromProfile() end end
    section:RefreshAppearance()
    self.contentSections.appearance=section
end

-- Shared styling for the addon-owned UI. Compatible with the Vanilla Lua 5.0 API.
ConsoleExperience.theme = {objects=setmetatable({}, {__mode="k"})}
local Theme = ConsoleExperience.theme
local WHITE = "Interface\\Buttons\\WHITE8X8"
local ART = "Interface\\AddOns\\Windrunner-Controller\\textures\\ui\\"
Theme.ART = ART
Theme.PRESETS = {
    ember={name="Ember", bg={0.047,0.054,0.064}, card={0.084,0.093,0.108}, accent={0.94,0.72,0.40}},
    frost={name="Frost", bg={0.032,0.051,0.076}, card={0.060,0.087,0.125}, accent={0.46,0.79,0.98}},
    grove={name="Grove", bg={0.035,0.058,0.053}, card={0.065,0.099,0.087}, accent={0.48,0.83,0.65}},
}
Theme.ACCENTS = {gold={1,0.73,0.32}, ice={0.39,0.78,1}, emerald={0.42,0.88,0.67}, violet={0.76,0.59,1}, rose={1,0.52,0.63}}
Theme.SETTINGS = {
    uiTheme="ember", uiAccent="theme", uiAccentR=1, uiAccentG=0.73, uiAccentB=0.32,
    uiPanelOpacity=0.96, uiMenuScale=1, uiRadialScale=1, uiTextScale=1,
    uiFocusThickness=2, uiShowPointer=false, uiReducedMotion=false, uiHintDuration=3,
}
Theme.RANGES = {
    uiAccentR={0,1}, uiAccentG={0,1}, uiAccentB={0,1}, uiPanelOpacity={0.72,1},
    uiMenuScale={0.65,1.25}, uiRadialScale={0.65,1.3}, uiTextScale={0.9,1.2},
    uiFocusThickness={1,4}, uiHintDuration={1,6},
}
function Theme:Get(key)
    local config = ConsoleExperience.config
    local value = config and config.Get and config:Get(key)
    if value == nil then value = self.SETTINGS[key] end
    local range = self.RANGES[key]
    if range then
        value = tonumber(value)
        if not value or value ~= value then value = self.SETTINGS[key] end
        return math.max(range[1], math.min(range[2], value))
    end
    return value
end
function Theme:Palette()
    local preset = self.PRESETS[self:Get("uiTheme")] or self.PRESETS.ember
    local accent = self.ACCENTS[self:Get("uiAccent")] or preset.accent
    if self:Get("uiAccent") == "class" and UnitClass and RAID_CLASS_COLORS then
        local _, class = UnitClass("player")
        local color = RAID_CLASS_COLORS[class]
        if color then accent = {color.r,color.g,color.b} end
    elseif self:Get("uiAccent") == "custom" then
        accent = {self:Get("uiAccentR"),self:Get("uiAccentG"),self:Get("uiAccentB")}
    end
    local luminance=accent[1]*0.2126+accent[2]*0.7152+accent[3]*0.0722
    local lift=luminance < 0.45 and (0.45-luminance)/(1-luminance) or 0
    local focus={accent[1]+(1-accent[1])*lift,accent[2]+(1-accent[2])*lift,accent[3]+(1-accent[3])*lift}
    local metal={accent[1]*0.28+0.17,accent[2]*0.28+0.18,accent[3]*0.28+0.20}
    return {bg=preset.bg, card=preset.card, accent=accent, focus=focus, border={0.18,0.21,0.25}, metal=metal,
        text={0.95,0.94,0.90}, muted={0.64,0.69,0.74}, success={0.47,0.84,0.65}, danger={1,0.48,0.43},
        opacity=self:Get("uiPanelOpacity")}
end
local function Color(object, method, color, alpha)
    if object and object[method] then object[method](object, color[1],color[2],color[3],alpha or 1) end
end
function Theme:Backdrop(frame, background, border, alpha, thickness, texture)
    frame:SetBackdrop({bgFile=texture and (ART..texture) or WHITE, edgeFile=WHITE, tile=false, edgeSize=thickness or 1,
        insets={left=1,right=1,top=1,bottom=1}})
    Color(frame,"SetBackdropColor",background,alpha)
    Color(frame,"SetBackdropBorderColor",border)
end
-- Decorations are textures, so they never introduce controller focus stops.
function Theme:Art(frame,key,file,layer)
    frame.themeArt=frame.themeArt or {}
    local texture=frame.themeArt[key]
    if not texture then
        texture=frame:CreateTexture(nil,layer or "ARTWORK")
        texture:SetTexture(ART..file)
        frame.themeArt[key]=texture
    end
    if ConsoleExperience.IsControllerOwned and not ConsoleExperience:IsControllerOwned(frame) then texture:Show() end
    return texture
end
function Theme:Trim(frame,p,active)
    local trim=self:Art(frame,"trim","rule","BORDER")
    trim:SetPoint("TOPLEFT",frame,"TOPLEFT",1,-1)
    trim:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-1,-1); trim:SetHeight(1)
    Color(trim,"SetVertexColor",active and p.focus or p.metal,active and 0.8 or 0.45)
end
function Theme:Typography(text,size,role)
    text.themeDisplay=true
    self:Register(text,role or "text")
    local spec=self.objects[text]
    spec.size=size
    if spec.font and string.find(string.lower(spec.font),"arialn",1,true) then spec.font="Fonts\\FRIZQT__.TTF" end
    self:Apply(text)
end
function Theme:Apply(object)
    local spec = self.objects[object]
    if not spec then return end
    if ConsoleExperience.IsControllerOwned and not ConsoleExperience:IsControllerOwned(object) then
        if not ConsoleExperience:IsControllerActive() then return end
        ConsoleExperience:CaptureThemeState(object)
        if spec.role == "button" then
            for _,method in ipairs({"SetNormalTexture", "SetPushedTexture", "SetHighlightTexture", "SetDisabledTexture"}) do
                if object[method] then object[method](object, "") end
            end
        end
    end
    local p = self:Palette()
    local role = spec.role
    if spec.font then
        local size=spec.size*self:Get("uiTextScale")
        object:SetFont(spec.font,size,spec.flags or "")
        local parent=object.GetParent and object:GetParent()
        if parent and parent.GetObjectType and parent:GetObjectType()=="Button"
            and parent.themeLabel==object and not parent.ceSettingRow and object.GetStringWidth then
            local width=object:GetStringWidth()
            local available=parent:GetWidth()-16
            if object.GetWidth then available=math.min(available,object:GetWidth()-2) end
            if width>available and available>0 then object:SetFont(spec.font,size*available/width,spec.flags or "") end
        end
    end
    if spec.callback then spec.callback(object,p); return end
    if role == "text" or role == "muted" or role == "accent" or role == "font" then
        if role ~= "font" or not object.themeSemantic then Color(object,"SetTextColor",role == "accent" and p.focus or (role == "muted" and p.muted or p.text)) end
    elseif role == "focus" then
        self:Backdrop(object,p.focus,p.focus,0.06,self:Get("uiFocusThickness"))
        self:Trim(object,p,true)
    elseif role == "button" then
        local enabled = not object.IsEnabled or object:IsEnabled() == 1 or object:IsEnabled() == true
        local active = object.themeSelected or object.themeHovered
        local accent = object.themeIntent == "success" and p.success or (object.themeIntent == "danger" and p.danger or p.accent)
        local indicator=(object.themeIntent=="success" or object.themeIntent=="danger") and accent or p.focus
        local nav=object.themeKind=="navigation"
        local row=object.ceSettingRow
        local bg = (active or object.themeKind=="primary") and {p.card[1]+accent[1]*0.12,p.card[2]+accent[2]*0.12,p.card[3]+accent[3]*0.12}
            or (nav and p.bg or {p.card[1]+0.015,p.card[2]+0.015,p.card[3]+0.015})
        self:Backdrop(object,bg,active and indicator or (row and p.card or p.metal),nav and not active and 0 or p.opacity,1,"button")
        if nav and not active then object:SetBackdropBorderColor(0,0,0,0) end
        if not nav then self:Trim(object,p,active) end
        if object.themeLabel then Color(object.themeLabel,"SetTextColor",enabled and (object.themeSelected and indicator or p.text) or p.muted) end
        if object.themeMarker then Color(object.themeMarker,"SetVertexColor",p.focus); if object.themeSelected then object.themeMarker:Show() else object.themeMarker:Hide() end end
        if object.themeIcon then Color(object.themeIcon,"SetVertexColor",object.themeSelected and p.focus or p.muted) end
        if object.themeChevron then
            Color(object.themeChevron,"SetVertexColor",enabled and p.focus or p.muted)
            if nav and not object.themeSelected then object.themeChevron:Hide() else object.themeChevron:Show() end
        end
    else
        local panel=role=="panel" or role=="rail" or role=="well"
        local background=panel and p.bg or (role == "field" and {p.bg[1]*0.55,p.bg[2]*0.55,p.bg[3]*0.55} or p.card)
        self:Backdrop(object,background,(role=="card" or role=="row" or role=="well") and p.card or p.metal,p.opacity,1,"surface")
        if role=="panel" then
            self:Trim(object,p,false)
            local shadow=self:Art(object,"shadow","shadow","BACKGROUND")
            shadow:SetPoint("TOPLEFT",object,"BOTTOMLEFT",-8,-1); shadow:SetPoint("TOPRIGHT",object,"BOTTOMRIGHT",8,-1)
            shadow:SetHeight(14); shadow:SetVertexColor(1,1,1,0.5)
            local wash=self:Art(object,"wash","wash","BACKGROUND")
            wash:SetPoint("TOPLEFT",object,"TOPLEFT",2,-2); wash:SetPoint("TOPRIGHT",object,"TOPRIGHT",-2,-2)
            wash:SetHeight(math.min(64,object.GetHeight and object:GetHeight() or 64))
            Color(wash,"SetVertexColor",p.accent,0.09)
        end
    end
end
function Theme:Register(object, role, callback)
    if not object then return end
    if ConsoleExperience.CaptureThemeState and ConsoleExperience:IsControllerActive() then ConsoleExperience:CaptureThemeState(object) end
    local spec = self.objects[object]
    if not spec then
        spec = {}; self.objects[object] = spec
        if object.GetFont then
            spec.font,spec.size,spec.flags = object:GetFont()
            -- The stock fantasy font loses legibility in dense settings pages.
            -- Keep locale-specific fonts and use the client's bundled sans face
            -- for Latin text, without depending on pfUI or external font files.
            if spec.size and spec.size>=17 then object.themeDisplay=true; spec.size=math.max(20,spec.size) end
            if spec.font and string.find(string.lower(spec.font),"frizqt",1,true) and not object.themeDisplay then
                spec.font="Fonts\\ARIALN.TTF"
                spec.flags=""
            end
            if spec.size then spec.size=math.max(13,spec.size) end
        end
    end
    spec.role, spec.callback = role, callback
    self:Apply(object)
    return object
end
function Theme:Button(button, label)
    if button.themeIgnore then return end
    if ConsoleExperience.CaptureThemeState and ConsoleExperience:IsControllerActive() then ConsoleExperience:CaptureThemeState(button) end
    button.themeLabel = label or button.themeLabel or (button.GetFontString and button:GetFontString())
    if not self.objects[button] then
        for _,method in ipairs({"SetNormalTexture","SetPushedTexture","SetHighlightTexture","SetDisabledTexture"}) do
            if button[method] then button[method](button,"") end
        end
        local enter, leave = button:GetScript("OnEnter"), button:GetScript("OnLeave")
        button:SetScript("OnEnter",function()
            this.themeHovered=true
            if enter then enter() end
            Theme:Apply(this)
        end)
        button:SetScript("OnLeave",function()
            this.themeHovered=false
            if leave then leave() end
            Theme:Apply(this)
        end)
    end
    self:Register(button,"button")
    if button.themeLabel then self:Register(button.themeLabel,"text") end
    self:Apply(button)
end
function Theme:PaintKey(button, intent, active)
    if not button then return end
    if not self.objects[button] then self:Button(button,button.label) end
    button.themeIntent, button.themeSelected = intent, active
    self:Apply(button)
end
function Theme:ActionButton(button,icon,primary)
    button.themeKind=primary and "primary" or "action"
    self:Button(button)
    if button.themeLabel then
        button.themeLabel:ClearAllPoints(); button.themeLabel:SetPoint("LEFT",button,"LEFT",icon and 46 or 14,0)
        button.themeLabel:SetWidth(button:GetWidth()-(icon and 78 or 46)); button.themeLabel:SetHeight(32)
        button.themeLabel:SetJustifyH("LEFT"); button.themeLabel:SetJustifyV("CENTER")
    end
    if icon then
        local art=self:Art(button,"icon","nav-"..icon,"ARTWORK")
        art:SetWidth(22); art:SetHeight(22); art:SetPoint("LEFT",button,"LEFT",14,0)
        button.themeIcon=art
    end
    local arrow=self:Art(button,"chevron","chevron","ARTWORK")
    arrow:SetWidth(18); arrow:SetHeight(18); arrow:SetPoint("RIGHT",button,"RIGHT",-10,0)
    button.themeChevron=arrow
    self:Apply(button)
end
function Theme:SkinTree(frame)
    if not frame or frame.themeIgnore then return end
    local kind = frame.GetObjectType and frame:GetObjectType()
    if kind == "Button" and frame.GetText and frame:GetText() and frame:GetText() ~= "" then
        self:Button(frame)
    elseif kind == "EditBox" and frame.GetBackdrop and frame:GetBackdrop() then
        self:Register(frame,"field")
    end
    if frame.GetChildren then for _,child in ipairs({frame:GetChildren()}) do self:SkinTree(child) end end
    if frame.GetRegions then
        for _,region in ipairs({frame:GetRegions()}) do
            if region.GetObjectType and region:GetObjectType()=="FontString" and not self.objects[region] then self:Register(region,"font") end
        end
    end
end
function Theme:RefreshAll()
    for object,spec in pairs(self.objects) do if spec.font then self:Apply(object) end end
    for object,spec in pairs(self.objects) do if not spec.font then self:Apply(object) end end
    local config = ConsoleExperience.config
    if config then
        if config.frame then
            self:SkinTree(config.frame)
            config:UpdateFrameScale()
            -- Repainting (colors, opacity, focus width) must not re-measure the
            -- settings pages. Only a text-scale change can alter wrapped text,
            -- and hand-laid-out boxes keep the height they were built with.
            local textScale = self:Get("uiTextScale")
            if config.layoutTextScale ~= textScale then
                config.layoutTextScale = textScale
                for _,section in pairs(config.contentSections or {}) do
                    for _,child in ipairs({section:GetChildren()}) do
                        if child.CalculateHeight and not child.fixedHeight then child.heightCalculated=false end
                    end
                end
            end
        end
        local page = config.contentSections and config.contentSections.appearance
        if page and page.RefreshAppearance then page:RefreshAppearance() end
        if config.frame and config.frame:IsVisible() and config.currentSection then config:ShowSection(config.currentSection) end
    end
    local radial = ConsoleExperience.radial
    if radial and radial.frame then
        radial:UpdateScale()
        for _,button in ipairs(radial.buttons or {}) do radial:UpdateButtonVisual(button) end
    end
    local cursor = ConsoleExperience.cursor
    if cursor and cursor.RefreshFrame and cursor.navigationState and cursor.navigationState.enabled then cursor:RefreshFrame() end
    local itemmenu = ConsoleExperience.itemmenu
    if itemmenu and itemmenu.frame and itemmenu.frame:IsVisible() then
        local item = itemmenu:Validate()
        if item then itemmenu:Render(item) else itemmenu:Close() end
    end
end
function Theme:Reset()
    for key,value in pairs(self.SETTINGS) do ConsoleExperience.config:Set(key,value,true) end
    self:RefreshAll()
end

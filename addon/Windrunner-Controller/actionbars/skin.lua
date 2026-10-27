local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
-- Circular button art uses the Vanilla portrait mask, including system actions.
local Bars = ConsoleExperience.actionbars
local ART = "Interface\\AddOns\\Windrunner-Controller\\textures\\radial\\"

Bars.LABEL_DEFAULTS = {
    barLabelEnabled=true, barLabelBackground=false, barLabelSize=18,
    barLabelAnchor="TOP", barLabelX=0, barLabelY=6,
}
local labelPresets = {
    reference=Bars.LABEL_DEFAULTS,
    badges={barLabelEnabled=true,barLabelBackground=true,barLabelSize=30,
        barLabelAnchor="TOP",barLabelX=0,barLabelY=-13},
}
local labelAnchors = {TOP={0,0.5},BOTTOM={0,-0.5},LEFT={-0.5,0},RIGHT={0.5,0},CENTER={0,0}}

function Bars:GetControllerLabelOptions()
    local config=ConsoleExperience.config
    local function Get(key)
        local value=config and config.Get and config:Get(key)
        if value==nil then return self.LABEL_DEFAULTS[key] end
        return value
    end
    local function Number(key,low,high)
        local value=tonumber(Get(key))
        if not value or value~=value then value=self.LABEL_DEFAULTS[key] end
        return math.max(low,math.min(high,value))
    end
    local anchor=Get("barLabelAnchor")
    return {enabled=Get("barLabelEnabled")~=false,background=Get("barLabelBackground")==true,
        size=Number("barLabelSize",8,48),x=Number("barLabelX",-80,80),y=Number("barLabelY",-80,80),
        anchor=labelAnchors[anchor] and anchor or "TOP"}
end

function Bars:GetControllerLabelPreset()
    local config=ConsoleExperience.config
    for name,preset in pairs(labelPresets) do
        local matches=true
        for key,value in pairs(preset) do
            local current=config:Get(key)
            if current==nil then current=self.LABEL_DEFAULTS[key] end
            if current~=value then matches=false; break end
        end
        if matches then return name end
    end
    return "custom"
end

function Bars:ApplyControllerLabelPreset(name)
    local preset=labelPresets[name]
    if not preset then return end
    local config=ConsoleExperience.config
    for key,value in pairs(preset) do config:Set(key,value,true) end
    config:UpdateActionBarLayout()
    if self.UpdateAllButtons then self:UpdateAllButtons() end
    local section=config.contentSections and config.contentSections.appearance
    if section and section.RefreshAppearance then section:RefreshAppearance() end
end

-- Include customized labels when fitting and moving either action cluster.
function Bars:GetControllerLabelBounds(buttonSize)
    local half=buttonSize/2
    local bounds={minX=-half,maxX=half,minY=-half,maxY=half}
    local options=self:GetControllerLabelOptions()
    if not options.enabled then return bounds end
    local anchor=labelAnchors[options.anchor]
    local x,y=anchor[1]*buttonSize+options.x,anchor[2]*buttonSize+options.y
    local labelHalf=options.size/2
    bounds.minX=math.min(bounds.minX,x-labelHalf); bounds.maxX=math.max(bounds.maxX,x+labelHalf)
    bounds.minY=math.min(bounds.minY,y-labelHalf); bounds.maxY=math.max(bounds.maxY,y+labelHalf)
    return bounds
end

function Bars:ApplyControllerLabel(button)
    local glyph=getglobal(button:GetName().."ControllerIcon")
    if not glyph then return end
    local options=self:GetControllerLabelOptions()
    if not options.enabled then glyph:Hide(); return end
    if not button.controllerIconFrame then
        button.controllerIconFrame=CreateFrame("Frame",button:GetName().."ControllerIconFrame",button)
        button.controllerIconFrame:SetAllPoints(button)
    end
    button.controllerIconFrame:SetFrameLevel(button:GetFrameLevel()+10)
    glyph:SetParent(button.controllerIconFrame); glyph:SetDrawLayer("OVERLAY")
    local path=self:GetButtonIcons()[button:GetID()]
    if path and not options.background then
        path=string.gsub(path,"\\textures\\controllers\\","\\textures\\controller-labels\\")
    end
    glyph:SetTexture(path); glyph:SetTexCoord(0,1,0,1); glyph:SetVertexColor(1,1,1,1)
    glyph:SetWidth(options.size); glyph:SetHeight(options.size)
    glyph:ClearAllPoints(); glyph:SetPoint("CENTER",button,options.anchor,options.x,options.y); glyph:Show()
end

function Bars:PositionSideBar(frame, side)
    local config = ConsoleExperience.config
    local w, h = frame:GetWidth(), frame:GetHeight()
    local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
    local x = side == "Left" and (12 + w / 2) or (screenW - 12 - w / 2)
    x = math.max(w / 2 + 8, math.min(screenW - w / 2 - 8, x + (config:Get("sideBar" .. side .. "X") or 0)))
    local y = math.max(h / 2 + 8, math.min(screenH - h / 2 - 28, screenH / 2 + (config:Get("sideBar" .. side .. "Y") or 0)))
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

function Bars:SetActionIcon(button, path)
    local icon = getglobal(button:GetName() .. "Icon") or button.icon
    button.actionIconPath = path
    if not icon then return end
    icon:SetTexCoord(0, 1, 0, 1)
    if path and ConsoleExperience.config and ConsoleExperience.config:Get("barAppearance") == "modern"
        and SetPortraitToTexture then
        SetPortraitToTexture(icon, path)
    else
        icon:SetTexture(path)
    end
end

local function Round(region, button, texture, size, layer)
    if not region then return end
    region:SetTexture(ART .. texture)
    region:SetTexCoord(0, 1, 0, 1)
    region:SetWidth(size); region:SetHeight(size)
    region:ClearAllPoints(); region:SetPoint("CENTER", button, "CENTER", 0, 0)
    region:SetBlendMode("BLEND")
    if layer then region:SetDrawLayer(layer) end
end

function Bars:StyleCooldownShade(button)
    local frame = button.circularCooldown
    if not frame or not frame.shade then return end
    local modern = ConsoleExperience.config and ConsoleExperience.config:Get("barAppearance") == "modern"
    frame.shade:SetTexture(modern and (ART .. "disc") or "Interface\\Buttons\\WHITE8X8")
    frame.shade:ClearAllPoints()
    frame.shade:SetPoint("CENTER", button, "CENTER", 0, 0)
    local size = modern and button:GetWidth() * 0.88 / 0.95 or button:GetWidth() - 4
    frame.shade:SetWidth(size); frame.shade:SetHeight(size)
    frame.text:ClearAllPoints(); frame.text:SetPoint("CENTER", button, "CENTER", 0, 0)
end

function Bars:ApplyCleanButtonAppearance(button)
    local name, size = button:GetName(), button:GetWidth()
    local icon = getglobal(name .. "Icon") or button.icon
    local bg = getglobal(name .. "Background") or button.background
    local normal = getglobal(name .. "NormalTexture")
    if normal then normal:SetTexture(nil) end
    if bg then
        Round(bg, button, "disc", size, "BACKGROUND")
        bg:SetVertexColor(0.025, 0.03, 0.04, 0.85); bg:Show()
    end
    local rim = getglobal(name .. "Overlay") or button:CreateTexture(name .. "Overlay", "ARTWORK")
    Round(rim, button, "ring", size)
    local color = button.vertexstate == 1 and self.RANGE_COLOR or (button.vertexstate == 2 and self.OOM_COLOR)
    rim:SetVertexColor(unpack(color or {0.62, 0.66, 0.7, 0.9})); rim:Show()
    if icon then
        local path = button.actionIconPath or (icon.GetTexture and icon:GetTexture())
        if path then self:SetActionIcon(button, path) end
        icon:SetWidth(size * 0.88); icon:SetHeight(size * 0.88)
        icon:ClearAllPoints(); icon:SetPoint("CENTER", button, "CENTER", 0, 0)
        -- Do not crop UVs after SetPortraitToTexture: that crops away the mask.
    end
    Round(button:GetHighlightTexture(), button, "ring", size * 1.04)
    local highlight = button:GetHighlightTexture()
    if highlight then highlight:SetVertexColor(1, 0.85, 0.48, 0.9) end
    Round(button:GetPushedTexture(), button, "disc", size * 0.94)
    local pushed = button:GetPushedTexture()
    if pushed then pushed:SetVertexColor(0, 0, 0, 0.35) end
    Round(button:GetCheckedTexture(), button, "ring", size * 1.08, "OVERLAY")
    local checked = button:GetCheckedTexture()
    if checked then checked:SetVertexColor(1, 0.7, 0.2, 1) end
    local flash = getglobal(name .. "Flash") or button.flash
    Round(flash, button, "ring", size * 1.08)
    if flash then flash:SetVertexColor(1, 0.25, 0.12, 0.85) end
    if ConsoleExperience.theme then
        ConsoleExperience.theme:Register(button,"action",function(b,p)
            local stateColor=b.vertexstate==1 and Bars.RANGE_COLOR or (b.vertexstate==2 and Bars.OOM_COLOR)
            local metal=p.metal or p.border
            rim:SetVertexColor(unpack(stateColor or {metal[1]+0.13,metal[2]+0.13,metal[3]+0.13,0.95}))
            if highlight then highlight:SetVertexColor(p.focus[1],p.focus[2],p.focus[3],0.95) end
            if checked then checked:SetVertexColor(p.accent[1],p.accent[2],p.accent[3],1) end
        end)
    end
    if button.activeFrame then
        Round(button.activeFrame.border, button, "ring", size * 1.08, "OVERLAY")
        Round(button.activeFrame.glow, button, "glow", size * 1.15, "OVERLAY")
        button.activeFrame.glow:SetVertexColor(1, 0.7, 0.2, 0.45)
    end
    Round(getglobal(name .. "Border"), button, "ring", size * 1.08)
    self:StyleCooldownShade(button)
    local count = getglobal(name .. "Count") or button.count
    if count then
        count:ClearAllPoints(); count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -size * 0.12, size * 0.08)
    end
end

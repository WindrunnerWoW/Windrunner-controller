-- Shared descriptions and assignments for inputs outside the forty action slots.
ConsoleExperience.controllerControls = {}
local Controls = ConsoleExperience.controllerControls
Controls.INPUTS = {
    LS={key="controllerLeftStickClick",default="TARGETNEARESTENEMY",xbox="LS",ps="L3",name="Left-stick click",points={{132,172},{176,274}},size=44},
    RS={key="controllerRightStickClick",default="CE_TOGGLE_POINTER",xbox="RS",ps="R3",name="Right-stick click",points={{342,268},{336,274}},size=44},
    BACK={key="controllerBackButton",default="TOGGLEWORLDMAP",xbox="Back",ps="Share",name="Back",points={{222,164},{167,132}},size=18},
    START={key="controllerStartButton",default="CE_TOGGLE_RADIAL",xbox="Start",ps="Options",name="Start",points={{290,164},{345,132}},size=18},
    LEFT_AXIS={xbox="Left stick",ps="Left stick",name="Left stick",action="Move / menu navigation",desc="Move and strafe in the world. Navigate focused menus with the left stick. Radial selection follows your stick preference on the Controller page.",points={{132,172},{176,274}},size=44},
    RIGHT_AXIS={xbox="Right stick",ps="Right stick",name="Right stick",action="Camera / pointer / radial",desc="Move the camera in the world or the pointer in menus. Radial selection follows your stick preference on the Controller page.",points={{342,268},{336,274}},size=44},
    LT={xbox="LT",ps="L2",name="Left trigger",action="Shift modifier",desc="Hold for action slots 11-20. Hold both triggers for slots 31-40.",points={{112,75},{112,75}},size=22},
    RT={xbox="RT",ps="R2",name="Right trigger",action="Ctrl modifier",desc="Hold for action slots 21-30. Hold both triggers for slots 31-40.",points={{400,75},{400,75}},size=22},
    PAUSE={xbox="Back + Start",ps="Share + Options",name="Pause / resume",action="Pause / resume input",desc="This combination stays reserved for pausing and resuming native input. Release all controls after resuming to arm input again.",points={{256,164},{256,132}},size=30},
    POINTER={xbox="A / X",ps="Cross / Square",name="Pointer clicks",action="Left / right mouse click",desc="In pointer click mode, A/Cross holds the left mouse button and X/Square holds the right. Their normal action slots stay available in focus or camera mode.",points={{388,169},{392,172}},size=62},
}
Controls.SPECIAL_ACTIONS = {
    {id="NONE",name="Disabled",desc="This input does nothing."},
    {id="CE_TOGGLE_RADIAL",name="Quick Menu",desc="Open or close the quick menu, including from other menus.",icon="Interface\\Icons\\INV_Misc_Gear_01"},
    {id="CE_TOGGLE_POINTER",name="Switch pointer / focus mode",desc="Switch camera/pointer movement in the world and focus/click actions in menus. Requires the optional mouse bridge.",icon="Interface\\Icons\\INV_Misc_SpyGlass_03"},
}
Controls.MENU_ACTIONS = {CE_TOGGLE_RADIAL=true,CE_TOGGLE_POINTER=true,TOGGLEWORLDMAP=true,
    OPENALLBAGS=true,TOGGLEGAMEMENU=true,TOGGLECHARACTER0=true,TOGGLESPELLBOOK=true,
    TOGGLETALENTS=true,TOGGLEQUESTLOG=true,TOGGLESOCIAL=true}
local function L(key) return ConsoleExperience.locale and ConsoleExperience.locale.T(key) or key end

function Controls:GetRadialStickMode()
    local config=ConsoleExperience.config
    local mode=config and config.Get and config:Get("radialSelectionStick")
    if mode=="left" or mode=="right" then return mode end
    return "both"
end

function Controls:GetRadialStickLabel()
    local mode=self:GetRadialStickMode()
    return L(mode=="left" and "Left stick" or (mode=="right" and "Right stick" or "Either stick"))
end

function Controls:GetActionInfo(id)
    if type(id)~="string" then return nil end
    for _,action in ipairs(self.SPECIAL_ACTIONS) do
        if action.id==id then return {id=id,name=L(action.name),desc=L(action.desc),icon=action.icon} end
    end
    local proxied=ConsoleExperience.proxied
    return proxied and proxied.GetActionByID and proxied:GetActionByID(id)
end

function Controls:GetBinding(input,page)
    local control=self.INPUTS[input]
    if not control or not control.key then return nil end
    local config=ConsoleExperience.config
    if (input=="LT" or input=="RT") and (not config or config:Get("controllerModifierSource")~="bumpers") then return "NONE" end
    local id
    if page and page>1 and page<=4 then
        id=config and config:Get(control.key .. "Page" .. page)
    end
    id=id or (config and config:Get(control.key) or (WindrunnerExperienceDB and WindrunnerExperienceDB.config and WindrunnerExperienceDB.config[control.key]))
    if id and self:GetActionInfo(id) then return id end
    return control.default
end

function Controls:SetBinding(input,id,page)
    local control=self.INPUTS[input]
    if not control or not control.key or not self:GetActionInfo(id) then return false end
    local key=control.key
    if page and page>1 and page<=4 then key=key .. "Page" .. page end
    ConsoleExperience.config:Set(key,id)
    local config=ConsoleExperience.config
    if config.bindingOverview then config:RefreshBindingOverview() end
    local page=config.contentSections and config.contentSections.controller
    if page and page.UpdateControllerPrompts then page.UpdateControllerPrompts() end
    local help=config.contentSections and config.contentSections.help
    if help and help.UpdateHelpPrompts then help.UpdateHelpPrompts() end
    return true
end

function Controls:GetInputName(input)
    local control=self.INPUTS[input]
    if not control then return "" end
    if input=="PAUSE" then return self:GetInputName("BACK") .. " + " .. self:GetInputName("START") end
    if input=="POINTER" then return L(self:GetPromptLabel("A")).." / "..L(self:GetPromptLabel("X")) end
    local glyph=L(self:GetPromptLabel(input))
    if not control.key and input~="LT" and input~="RT" then glyph=L(control.xbox) end
    if input=="LS" or input=="RS" then return glyph .. " / " .. L(control.name) end
    return glyph
end

function Controls:GetInputInfo(input,page)
    local control=self.INPUTS[input]
    if not control then return nil end
    if (input=="LT" or input=="RT") and ConsoleExperience.config:Get("controllerModifierSource")~="bumpers" then
        return {name=L(control.action),description=L(control.desc),editable=false}
    end
    local action=control.key and self:GetActionInfo(self:GetBinding(input,page))
    return {name=action and action.name or L(control.action or ""),description=action and action.desc or L(control.desc or ""),
        icon=action and action.icon,editable=control.key~=nil}
end

-- Prompt labels describe the physical controller layout selected by the user.
-- These presets only translate glyphs and labels; the input backend remains the
-- configured Xbox or PlayStation controller type.
local PROMPT_PRESETS={standard=true,switch=true,deck=true}
local SWITCH_FACE_GLYPHS={A="B",B="A",X="Y",Y="X"}
local STANDARD_XBOX_LABELS={A="A",B="B",X="X",Y="Y",LB="LB",RB="RB",LT="LT",RT="RT",BACK="Back",START="Start",LS="LS",RS="RS"}
local STANDARD_PS_LABELS={A="Cross",B="Circle",X="Square",Y="Triangle",LB="L1",RB="R1",LT="L2",RT="R2",BACK="Share",START="Options",LS="L3",RS="R3"}
local SWITCH_LABELS={A="B",B="A",X="Y",Y="X",LB="L",RB="R",LT="ZL",RT="ZR",BACK="-",START="+",LS="LS",RS="RS"}
function Controls:GetPromptPreset()
    local preset=ConsoleExperience.config and ConsoleExperience.config.Get and ConsoleExperience.config:Get("controllerPromptPreset")
    if PROMPT_PRESETS[preset] then return preset end
    return "standard"
end
function Controls:GetGlyphName(name)
    if type(name)~="string" then return name end
    local key=string.upper(name)
    if self:GetPromptPreset()=="switch" and SWITCH_FACE_GLYPHS[key] then
        return string.lower(SWITCH_FACE_GLYPHS[key])
    end
    return string.lower(name)
end
function Controls:GetPromptLabel(name)
    if type(name)~="string" then return tostring(name or "") end
    local key=string.upper(name)
    local preset=self:GetPromptPreset()
    if preset=="switch" then return SWITCH_LABELS[key] or name end
    local isPS=preset=="standard" and ConsoleExperience.config and ConsoleExperience.config.Get and ConsoleExperience.config:Get("controllerType")=="ps"
    local labels=isPS and STANDARD_PS_LABELS or STANDARD_XBOX_LABELS
    return labels[key] or name
end
function Controls:SetPromptPreset(preset)
    if not PROMPT_PRESETS[preset] then return false end
    if not ConsoleExperience.config or not ConsoleExperience.config.Set then return false end
    ConsoleExperience.config:Set("controllerPromptPreset",preset)
    if preset=="switch" or preset=="deck" then ConsoleExperience.config:Set("controllerType","xbox") end
    local config=ConsoleExperience.config
    if config.RefreshBindingOverview then config:RefreshBindingOverview() end
    local page=config.contentSections and config.contentSections.controller
    if page and page.UpdateControllerPrompts then page.UpdateControllerPrompts() end
    local help=config.contentSections and config.contentSections.help
    if help and help.UpdateHelpPrompts then help.UpdateHelpPrompts() end
    return true
end

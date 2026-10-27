local root=assert(arg[1])
local model=assert(loadfile("tests/ui-model.lua"))()
CreateFrame=function(kind,name,parent,template) return model:Create(kind,name,parent,template) end
UIParent=CreateFrame("Frame","UIParent"); UIParent:SetWidth(1920); UIParent:SetHeight(1080)
GameMenuFrame=CreateFrame("Frame","GameMenuFrame",UIParent)
ConsoleExperience={}
WindrunnerExperienceDB={config={},proxiedActions={[1]="JUMP"}}
SlashCmdList={}; StaticPopupDialogs={}; UISpecialFrames={}; tinsert=table.insert
getglobal=function(name) return getfenv(0)[name] end
getfenv(0)._G=getfenv(0)
CE_Debug=function() end; CE_Print=function() end; PlaySound=function() end
UnitClass=function() return "Warrior","WARRIOR" end
RAID_CLASS_COLORS={WARRIOR={r=0.78,g=0.61,b=0.43}}
IsShiftKeyDown=function() return false end; IsControlKeyDown=function() return false end
local function load(path) assert(loadfile(root.."/"..path))() end
GetLocale=function() return arg[3] or "enUS" end
load("locale/locale.lua"); load("locale/translations_enUS.lua"); load("locale/translations_deDE.lua")
load("ui/theme.lua"); load("actionbars/bars.lua"); load("actionbars/skin.lua")
load("config/config.lua"); load("config/rows.lua"); load("config/appearance.lua")
local config,theme=ConsoleExperience.config,ConsoleExperience.theme
-- Other settings pages are independently tested; exercise the real shell and new page.
config.CreateContentSections=function(self)
    self.contentSections={}
    self:CreateControllerSection(); self:CreateAppearanceSection()
end
config:CreateMainFrame(); config.frame:Show(); config:ShowSection("appearance")
model:Tick(); model:Tick()
local function click(name) model:Invoke(assert(model.named[name],name),"OnClick") end
local originalButtonSize=config:Get("barButtonSize")
model.named.CEAppearanceLabelEnabled.cursorAdjust("LEFT")
assert(config:Get("barLabelEnabled")==false,"label visibility must be adjustable without touching action buttons")
model.named.CEAppearanceLabelPreset.cursorAdjust("RIGHT")
assert(config:Get("barLabelEnabled") and config:Get("barLabelBackground") and config:Get("barLabelSize")==30)
model.named.CEAppearancebarLabelSize.cursorAdjust("LEFT")
model.named.CEAppearanceLabelAnchor.cursorAdjust("RIGHT")
model.named.CEAppearancebarLabelX.cursorAdjust("RIGHT")
model.named.CEAppearancebarLabelY.cursorAdjust("LEFT")
assert(config:Get("barLabelSize")==29 and config:Get("barLabelAnchor")=="BOTTOM" and config:Get("barLabelX")==1 and config:Get("barLabelY")==-14)
assert(ConsoleExperience.actionbars:GetControllerLabelPreset()=="custom")
model.named.CEAppearanceLabelPreset.cursorAdjust("LEFT")
assert(not config:Get("barLabelBackground") and config:Get("barLabelSize")==18 and config:Get("barLabelAnchor")=="TOP" and config:Get("barLabelX")==0 and config:Get("barLabelY")==6)
assert(config:Get("barButtonSize")==originalButtonSize,"label presets must preserve action-button size")
model.named.CEAppearanceTheme.cursorAdjust("RIGHT")
assert(config:Get("uiTheme")=="frost" and config:Get("uiAccent")=="theme")
assert(config.frame.background[3]>config.frame.background[1],"theme must recolor an existing shell")
assert(config.sidebarButtons.appearance.themeSelected and not config.sidebarButtons.controller.themeSelected)
config:Set("uiAccent","violet"); config.contentSections.appearance:RefreshAppearance()
assert(theme:Palette().accent[1]==theme.ACCENTS.violet[1],"accent selection must update live")
assert(config.sidebarButtons.appearance.text.textColor[1]==theme.ACCENTS.violet[1],"the selected tab must retain its accent")
model.named.CEAppearanceuiMenuScale.cursorAdjust("LEFT")
assert(math.abs(config:Get("uiMenuScale")-0.95)<0.0001 and math.abs(config.frame:GetScale()-0.95)<0.0001)
-- Changing a look setting must never re-measure the hand-laid-out cards: that
-- grew the cards' empty space on every repaint on the 1.12 client.
local look=assert(model.named.CEAppearanceTheme:GetParent(),"appearance rows live in a card")
assert(look.fixedHeight and look.heightCalculated,"appearance cards keep their authored height")
local lookHeight=look:GetHeight()
config:Set("uiAccent","gold"); config:Set("uiAccent","theme"); model:Tick(); model:Tick()
assert(look.heightCalculated and look:GetHeight()==lookHeight,"repainting must not re-measure appearance cards")
config:Set("uiTextScale",1.1); model:Tick(); model:Tick()
assert(look:GetHeight()==lookHeight,"text scale must not grow a hand-laid-out card")
config:Set("uiTextScale",1); config:Set("uiAccent","violet")
local close=model.named.ConsoleExperienceConfigCloseButton
local script=close:GetScript("OnClick")
theme:RefreshAll(); theme:RefreshAll()
assert(close:GetScript("OnClick")==script,"skinning must preserve handlers")
model:Invoke(close,"OnEnter"); assert(close.themeHovered)
model:Invoke(close,"OnLeave"); assert(not close.themeHovered)
local focus=CreateFrame("Frame",nil,UIParent)
theme:Register(focus,"focus")
config:Set("uiFocusThickness",4)
assert(focus.backdrop.edgeSize==4,"focus width must update without recreating it")
ColorPickerFrame={Hide=function() end, Show=function() end,SetColorRGB=function() end,GetColorRGB=function() return 0.2,0.8,0.6 end}
config:PickAccentColor(); ColorPickerFrame.func()
assert(config:Get("uiAccent")=="custom" and config:Get("uiAccentR")==0.2)
ColorPickerFrame.cancelFunc()
assert(config:Get("uiAccent")=="violet","cancelling the picker must restore the prior color choice")
config:Set("uiAccentR",0,true); config:Set("uiAccentG",0,true); config:Set("uiAccentB",0,true); config:Set("uiAccent","custom")
assert(theme:Palette().accent[1]==0 and theme:Palette().focus[1]>=0.45,"dark custom colors must retain a readable focus outline")
config:Set("uiAccent","class")
assert(theme:Palette().accent[1]==0.78)
config:Set("uiTextScale",1.2)
local size=close.fontString.fontSize
theme:RefreshAll(); assert(close.fontString.fontSize==size,"refresh must not repeatedly multiply font size")
config:Set("uiMenuScale",1.25)
UIParent:SetWidth(800); UIParent:SetHeight(600); config:UpdateFrameScale()
assert(config.frame:GetScale()*config.FRAME_WIDTH<=768 and config.frame:GetScale()*config.FRAME_HEIGHT<=568,"centered settings must fit small screens with a 16-unit margin")
UIParent:SetWidth(1920); UIParent:SetHeight(1080)
config:Set("uiTheme","invalid"); config:Set("uiPanelOpacity","invalid")
assert(theme:Palette().bg[1]==theme.PRESETS.ember.bg[1] and theme:Get("uiPanelOpacity")==0.96)
config:Set("barButtonSize",66)
click("CEAppearanceReset")
assert(config:Get("barButtonSize")==66 and WindrunnerExperienceDB.proxiedActions[1]=="JUMP","appearance reset must preserve gameplay settings")
assert(config:Get("uiTheme")=="ember" and config:Get("uiTextScale")==1)
-- Profiles directly replace config; the actual loader must refresh existing themed frames.
load("config/profiles.lua")
config.UpdateCrosshair=function() end; config.UpdateActionBarLayout=function() end
WindrunnerExperienceDB.profiles={Blue={config={uiTheme="frost",uiAccent="ice",uiMenuScale=0.9},proxiedActions={[1]="JUMP"}}}
ConsoleExperience.profiles:LoadProfile("Blue")
assert(config.frame.background[3]>config.frame.background[1] and config.frame:GetScale()==0.9,"profile changes must repaint and resize existing frames")
config:Set("uiTextScale",1.2); model:Tick(); model:Tick()
local page=config.contentSections.appearance
for _,frame in ipairs(model.objects) do
    if frame.kind=="Button" and frame.parent and frame:IsVisible() and string.find(frame.name or "","^CEAppearance") then
        assert(frame:GetLeft()>=config.frame.content:GetLeft()-1,"control starts outside the content column: "..tostring(frame.name))
        assert(frame:GetRight()<=config.frame.content:GetRight()+1,"control exceeds the content column: "..tostring(frame.name))
    end
end
config:Set("uiTextScale",1); config:Set("uiMenuScale",1)
-- Native notifications and the radial menu honor the same live preferences.
DEFAULT_CHAT_FRAME={AddMessage=function() end}
ChatFrameEditBox={IsShown=function() return false end}
load("WindrunnerController.lua")
config:Set("uiHintDuration",5); config:Set("uiReducedMotion",true)
WindrunnerController:ShowModeHint("Camera mode")
model:Invoke(WindrunnerController.modeHint,"OnUpdate",4.7)
assert(WindrunnerController.modeHint.alpha==1 and WindrunnerController.modeHint:IsShown(),"reduced motion must disable hint fading")
model:Invoke(WindrunnerController.modeHint,"OnUpdate",0.4)
assert(not WindrunnerController.modeHint:IsShown(),"notifications must still expire")
SetPortraitTexture=function() end
SetPortraitToTexture=function(texture,path) texture.circularIcon=path end
load("radial/radial.lua")
local radial=ConsoleExperience.radial
radial:CreateFrame()
assert(table.getn(radial.buttons)==12,"the polished wheel must retain every fixed sector")
for _,button in ipairs(radial.buttons) do
    assert(button.icon.circularIcon==button.item.icon,"menu icons must use the native circular portrait mask")
    assert(string.find(button.border.texture[1],"textures\\radial\\ring",1,true),"focus must use the round border art")
    assert(button.labelHitArea:GetLeft()==button.label:GetLeft() and button.labelHitArea:GetRight()==button.label:GetRight(),"click targets must follow outward-aligned labels")
end
radial:SetSelected(12)
assert(radial.buttons[12].glow:IsShown() and not radial.buttons[1].glow:IsShown(),"only the selected icon should glow")
radial:SetSelected(8)
assert(radial.frame.statusText:GetText()==ConsoleExperience.locale.T("You are not in a guild."),"unavailable feedback must stay in the center")
radial:SetSelected(1)
assert(radial.frame.statusText:GetText()=="","available selections must clear prior feedback")
radial:StartOpenAnimation()
assert(not radial.frame:GetScript("OnUpdate"),"reduced motion must bypass the radial animation")
config:Set("uiRadialScale",1.3)
UIParent:SetWidth(300); UIParent:SetHeight(250); radial:UpdateScale()
assert(radial.frame:GetScale()*radial.frame:GetHeight()<=218,"small-screen fitting must not enforce an overflowing minimum scale")
UIParent:SetWidth(1920); UIParent:SetHeight(1080)
ConsoleExperience.ControllerIsShiftDown=IsShiftKeyDown; ConsoleExperience.ControllerIsControlDown=IsControlKeyDown
load("keyboard/keyboard.lua")
local keyboard=ConsoleExperience.keyboard
keyboard.keys={}
local key=keyboard:CreateKey(UIParent,"q",30,30,40,40)
local action=key:GetScript("OnClick")
keyboard:StyleKey(key,"shift",true)
assert(key.themeSelected and key.border[1]==theme:Palette().accent[1])
keyboard:StyleKey(key,"shift",false)
assert(not key.themeSelected and key:GetScript("OnClick")==action,"keyboard repaint must preserve key actions")
key:Hide()
load("cursor/cursor.lua")
assert(ConsoleExperience.cursor.frame.texture.alpha==0,"the focus outline must be the default navigation indicator")
radial.frame:Show()
ConsoleExperience.cursor.frame:Show(); ConsoleExperience.cursor.highlight:Show()
ConsoleExperience.cursor:UpdateCursorPosition(radial.buttons[4])
assert(radial.selectedIndex==4 and not ConsoleExperience.cursor.frame:IsShown()
    and not ConsoleExperience.cursor.highlight:IsShown(),"cursor refreshes must preserve circular focus without stacking a square")
radial.frame:Hide()
config:Set("uiShowPointer",true)
assert(ConsoleExperience.cursor.frame.texture.alpha==1,"the optional arrow must update live")
config:Set("uiShowPointer",false)
-- Serialize actual module-created layout for an optional visual proof.
if arg[2] then
    local out=assert(io.open(arg[2],"w"))
    local function str(s) return '"'..string.gsub(string.gsub(string.gsub(s or "","\\","\\\\"),'"','\\"'),"\n","\\n")..'"' end
    local function color(value) return value and ('['..table.concat(value,",")..']') or "null" end
    out:write('[')
    local first=true
    for _,frame in ipairs(model.objects) do
        if frame:IsVisible() then
            local l,b,w,h=frame:Rect()
            local ancestor=frame.parent
            local clip="null"
            while ancestor do
                if ancestor.kind=="ScrollFrame" then
                    local cl,cb,cw,ch=ancestor:Rect()
                    clip='['..cl..','..cb..','..cw..','..ch..']'; break
                end
                ancestor=ancestor.parent
            end
            if not first then out:write(',') end; first=false
            out:write('{"id":'..frame.previewId..',"parent":'..(frame.parent and frame.parent.previewId or 0)..',"layer":'..str(frame.drawLayer)..',"font":'..str(frame.font)..',"valign":'..str(frame.justifyV)..',"alpha":'..frame.alpha..',"bgTexture":'..str(frame.backdrop and frame.backdrop.bgFile)..',"kind":'..str(frame.kind)..',"name":'..str(frame.name)..',"x":'..l..',"y":'..b..',"w":'..w..',"h":'..h..',"text":'..str(frame.kind=="FontString" and frame.text or "")..',"size":'..frame.fontSize..',"justify":'..str(frame.justify)..',"clip":'..clip..',"bg":'..color(frame.background)..',"border":'..color(frame.border)..',"vertex":'..color(frame.vertex)..',"texture":'..str(frame.texture and type(frame.texture[1])=="string" and frame.texture[1] or "")..',"color":'..color(frame.textColor)..'}')
        end
    end
    out:write(']'); out:close()
end
print("PASS: theme presets, live accents/scaling/focus, picker cancellation, profile refresh, reset isolation, font stability and small-screen layout.")

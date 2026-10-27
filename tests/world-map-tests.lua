-- Fullscreen map input must keep polling while Vanilla hides UIParent.
local root=assert(arg[1],"pass the addon root")
local model=assert(loadfile("tests/ui-model.lua"))()
local create=model.Create
function model:Create(kind,name,parent,template)
    local frame=create(self,kind,name,parent,template)
    function frame:GetID() return self.id or 0 end
    function frame:GetCenter() local l,b,w,h=self:Rect(); return l+w/2,b+h/2 end
    function frame:GetFrameStrata() return self.strata or "MEDIUM" end
    function frame:SetFrameStrata(value) self.strata=value end
    function frame:GetFrameLevel() return self.level or 0 end
    function frame:SetFrameLevel(value) self.level=value end
    function frame:SetParent(value) self.parent=value end
    function frame:Show() if not self.shown then self.shown=true; model:Invoke(self,"OnShow") end end
    function frame:Hide() if self.shown then self.shown=false; model:Invoke(self,"OnHide") end end
    function frame:EnableKeyboard(value) self.keyboardEnabled=value end
    function frame:Click(button) model:Invoke(self,"OnClick",button or "LeftButton") end
    function frame:GetAlpha() return self.alpha end
    return frame
end
CreateFrame=function(kind,name,parent,template) return model:Create(kind,name,parent,template) end
getglobal=function(name) return getfenv(0)[name] end
getfenv(0)._G=getfenv(0)
UIParent=CreateFrame("Frame","UIParent"); UIParent:SetWidth(1920); UIParent:SetHeight(1080)
GameTooltip=CreateFrame("GameTooltip","GameTooltip",UIParent)
ChatFrameEditBox=CreateFrame("EditBox","ChatFrameEditBox",UIParent); ChatFrameEditBox:Hide()
ConsoleExperience={locale={T=function(key) return key end}}
local settings={controllerType="xbox",controllerBackButton="TOGGLEWORLDMAP",controllerRightStickClick="CE_TOGGLE_POINTER"}
ConsoleExperience.config={Get=function(self,key) return settings[key] end}
SlashCmdList={}; WindrunnerControllerDB={}; UISpecialFrames={}
CE_Debug=function() end; CE_Print=function() end; PlaySound=function() end
local mappings={}
ConsoleExperience.SetControllerBinding=function(key,action) mappings[key]=action end
ConsoleExperience.GetControllerBindingAction=function(key) return mappings[key] end
ConsoleExperience.GetControllerBindingKey=function() end
ConsoleExperience.SaveControllerBindings=function() end
SetBinding=function() error("map input must not modify keyboard bindings") end
CursorHasItem=function() return false end
CursorHasSpell=CursorHasItem; CursorHasMoney=CursorHasItem; SpellIsTargeting=CursorHasItem
IsShiftKeyDown=CursorHasItem; IsControlKeyDown=CursorHasItem
GetCurrentKeyBoardFocus=function() end
BOOKTYPE_SPELL="spell"

local state={true,0,0,0,0,0,0,0,true,1,0}
local scope,polls,movementMask,mouse=nil,0,0,nil
WindrunnerController_Poll=function() polls=polls+1; return unpack(state) end
WindrunnerController_SetMovement=function(mask)
    assert(scope=="frame" or (scope=="release" and mask==0),"movement escaped native input")
    movementMask=mask; return true
end
WindrunnerController_Jump=function() error("map confirm leaked into gameplay") end
WindrunnerController_ToggleAutorun=function() error("map input leaked into gameplay") end
ConsoleExperience_ActionButton=function() error("map input leaked into the action bar") end
WindrunnerController_Mouse=function(x,y,buttons,mode)
    assert(scope=="frame"); mouse={x,y,buttons,mode}; return true
end
WindrunnerController_Release=function() end
WindrunnerController_RunFrame=function()
    local previous=scope; scope="frame"
    local ok,message=pcall(WindrunnerController_DispatchFrame)
    scope=previous; return ok,message
end
WindrunnerController_RunRelease=function()
    local previous=scope; scope="release"
    local ok,message=pcall(WindrunnerController_DispatchRelease)
    scope=previous; return ok,message
end
local function load(path) assert(loadfile(root.."/"..path))() end
load("config/controls.lua")
assert(loadfile(arg[2] or root.."/WindrunnerController.lua"))()
load("cursor/cursor.lua"); load("cursor/tooltip.lua"); load("cursor/actions.lua")
load("cursor/keybindings.lua"); load("cursor/hooks.lua")
local controller,cursor,hooks=WindrunnerController,ConsoleExperience.cursor,ConsoleExperience.hooks
cursor.tooltip:Initialize()
-- Keep real context bindings; tooltip rendering is outside this input regression.
cursor.tooltip.ShowButtonTooltip=function() end
cursor.tooltip.HideButtonTooltip=function() end
cursor:Enable()
event="PLAYER_ENTERING_WORLD"; model:Invoke(controller,"OnEvent"); event=nil

local function button(name,parent,x,y,callback)
    local frame=CreateFrame("Button",name,parent)
    frame:SetWidth(100); frame:SetHeight(30); frame:SetPoint("CENTER",parent,"CENTER",x,y)
    frame:SetScript("OnClick",callback)
    return frame
end
local panel=CreateFrame("Frame","CharacterFrame",UIParent)
panel:SetWidth(400); panel:SetHeight(500); panel:SetPoint("CENTER",UIParent,"CENTER",0,0)
local first=button("CharacterTestFirst",panel,0,50,function() end)
local remembered=button("CharacterTestRemembered",panel,0,-50,function() end)
hooks:HookDynamicFrame(panel)
cursor:MoveCursorToButton(remembered)

-- Stock full-screen panels have no UIParent ancestry. SetFullScreenFrame
-- hides UIParent on open and shows it again after hiding the map.
WorldMapFrame=CreateFrame("Frame","WorldMapFrame")
WorldMapFrame:SetWidth(1920); WorldMapFrame:SetHeight(1080)
WorldMapFrame:SetPoint("CENTER",UIParent,"CENTER",0,0); WorldMapFrame:SetFrameStrata("FULLSCREEN")
WorldMapFrame:Hide()
WorldMapFrame:SetScript("OnShow",function() UIParent:Hide() end)
WorldMapFrame:SetScript("OnHide",function() UIParent:Show() end)
local toggles,zoomClicks=0,0
ToggleWorldMap=function()
    toggles=toggles+1
    if WorldMapFrame:IsShown() then WorldMapFrame:Hide() else WorldMapFrame:Show() end
end
local surface=button("WorldMapButton",WorldMapFrame,0,0,function() end)
surface:SetWidth(1800); surface:SetHeight(900)
local zoom=button("WorldMapZoomOutButton",WorldMapFrame,-100,450,function() zoomClicks=zoomClicks+1 end)
local close=button("WorldMapFrameCloseButton",WorldMapFrame,100,450,ToggleWorldMap)
hooks:HookFrame(WorldMapFrame,"World Map")

local function tick(buttons,lx,ly,rx,ry)
    state[2],state[5],state[6],state[7],state[8]=buttons or 0,lx or 0,ly or 0,rx or 0,ry or 0
    model:Tick() -- Only visible frames receive OnUpdate, matching the client.
    assert(not controller.lastError,controller.lastError)
end
local function settle() for i=1,4 do tick() end end
tick(); assert(controller.armed,"neutral controller must arm")
tick(32) -- Back opens the map through the real auxiliary binding.
assert(WorldMapFrame:IsVisible() and not UIParent:IsVisible(),"fullscreen map must hide the main UI")
assert(cursor.navigationState.currentButton==zoom and cursor.highlight:IsVisible(),"map controls must receive visible focus")
assert(cursor.navigationState.navigationLockFrame==WorldMapFrame,"map must own navigation")
local before=polls
tick()
assert(polls>before,"controller polling stopped when fullscreen map hid UIParent")
tick(8)
assert(cursor.navigationState.currentButton==close,"D-pad must reach the map close control")
tick(); tick(4)
assert(cursor.navigationState.currentButton==zoom,"D-pad must return to the zoom control")
tick(); tick(4096)
assert(zoomClicks==1,"A must activate a map control")
tick(); tick(0,0.8,0)
assert(cursor.navigationState.currentButton==close and movementMask==0,"left stick must navigate without moving the player")
tick(); tick(0,0,0,0.5,-0.5)
assert(mouse and mouse[1]>0 and mouse[2]>0 and mouse[4]==0,"right stick must keep moving the map pointer")
tick(); tick(8192)
assert(not WorldMapFrame:IsVisible() and UIParent:IsVisible(),"B must close the fullscreen map")
settle()
assert(cursor.navigationState.currentButton==remembered,"closing map must restore the previous panel selection")
assert(cursor.highlight:IsVisible() and cursor.frame:GetParent()==UIParent,"focus must return to the restored UI")

tick(32); tick(); tick(32)
assert(not WorldMapFrame:IsVisible() and toggles==4,"Back must also close the map while UIParent is hidden")
settle()
tick(32); tick()
assert(cursor.navigationState.currentButton==close,"reopening map must remember its selected control")
tick(4096)
assert(not WorldMapFrame:IsVisible(),"A must activate the map close button")
settle()

-- The input driver must keep observing disconnect, focus loss, and neutral
-- rearming even while the map remains open.
tick(32); tick()
state[1]=false; tick(4096)
assert(not controller.armed and WorldMapFrame:IsVisible(),"disconnect must stop input without closing the map")
state[1]=true; tick(4096)
assert(not controller.armed,"reconnection with a held button must not arm")
tick(); assert(controller.armed,"neutral input must rearm while the map is open")
state[9]=false; tick(8192)
assert(not controller.armed and WorldMapFrame:IsVisible(),"focus loss must stop map input")
state[9]=true; tick(8192)
assert(not controller.armed,"focus recovery with a held button must not arm")
tick(); tick(8192); settle()
assert(UIParent:IsVisible() and cursor.navigationState.currentButton==remembered,"rearmed input must close the map and restore focus")
print("PASS: fullscreen map polling, D-pad/stick focus, confirm, B/Back/close button, pointer, and disconnect/focus recovery.")

-- Connection lifecycle with the real main entry point and native input driver (Lua 5.0).
local root = assert(arg[1])
local frames = {}
local function frame(kind,name,parent)
    local f={kind=kind,name=name,parent=parent,shown=true,points={},scripts={},events={},width=400,height=150,scale=1,alpha=1}
    table.insert(frames,f)
    if name then getfenv(0)[name]=f end
    function f:GetName() return self.name end
    function f:GetParent() return self.parent end
    function f:SetParent(value) self.parent=value end
    function f:GetObjectType() return self.kind end
    function f:IsObjectType(value) return self.kind==value end
    function f:SetScript(name,fn) self.scripts[name]=fn end
    function f:GetScript(name) return self.scripts[name] end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function f:RegisterEvent(name) self.events[name]=true end
    function f:UnregisterAllEvents() self.events={} end
    function f:SetPoint(...) table.insert(self.points,arg) end
    function f:GetNumPoints() return table.getn(self.points) end
    function f:GetPoint(i) return unpack(self.points[i]) end
    function f:ClearAllPoints() self.points={} end
    function f:CreateTexture() return frame("Texture",nil,self) end
    function f:CreateFontString() return frame("FontString",nil,self) end
    for _,property in ipairs({"Width","Height","Scale","Alpha","FrameStrata","FrameLevel"}) do
        local key=string.lower(property)
        f["Get"..property]=function(self) return self[key] end
        f["Set"..property]=function(self,value) self[key]=value end
    end
    for _,method in ipairs({"SetAllPoints","SetTexture","SetText","SetTextColor","SetJustifyH","SetWordWrap"}) do f[method]=function() end end
    return f
end
CreateFrame=frame
local originalCreateFrame=CreateFrame
UIParent=frame("Frame","UIParent")
MainMenuBar=frame("Frame","MainMenuBar",UIParent)
MultiBarRight=frame("Frame","MultiBarRight",UIParent); MultiBarRight:Hide()
ChatFrame1=frame("Frame","ChatFrame1",UIParent); ChatFrame1:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",27,41)
ChatFrameEditBox=frame("EditBox","ChatFrameEditBox",UIParent); ChatFrameEditBox:Hide()
GameMenuFrame=frame("Frame","GameMenuFrame",UIParent)
local messages=0
SlashCmdList={}; DEFAULT_CHAT_FRAME={AddMessage=function() messages=messages+1 end}
getglobal=function(name) return getfenv(0)[name] end
IsShiftKeyDown=function() return false end; IsControlKeyDown=function() return false end
EnumerateFrames=function(previous)
    if not previous then return frames[1] end
    for i,f in ipairs(frames) do if f==previous then return frames[i+1] end end
end
local state={false,0,0,0,0,0,0,0,true,1,0}
WindrunnerController_Poll=function() return unpack(state) end
WindrunnerController_RunFrame=function() return true end
WindrunnerController_RunRelease=function() WindrunnerController_DispatchRelease(); return true end
WindrunnerController_SetMovement=function() return true end
WindrunnerController_Jump=function() return true end
WindrunnerController_ToggleAutorun=function() return true end
WindrunnerController_Release=function() end
WindrunnerController_Mouse=function() return true end
local function source(path) dofile(root.."/"..path) end
source("main.lua"); source("controller-lifecycle.lua"); source("WindrunnerController.lua")
local addon,driver=ConsoleExperience,WindrunnerController
local initializations,worlds,actions,events=0,0,0,0
local hud=addon.ControllerCreateFrame("Frame","TestControllerHUD",UIParent)
hud:SetScript("OnEvent",function() events=events+1 end)
addon.config={Get=function() return false end,InitializeDB=function() initializations=initializations+1 end,
    CreateGameMenuButton=function() GameMenuFrame:SetHeight(GameMenuFrame:GetHeight()+25) end,
    UpdateCrosshair=function() end,UpdateActionBarLayout=function() end}
addon.actionbars={Initialize=function() MainMenuBar:Hide(); ChatFrame1:SetScale(2) end,
    OnPlayerEnteringWorld=function() worlds=worlds+1; MainMenuBar:Hide() end,
    HideDefaultBars=function() MainMenuBar:Hide() end,UpdateAllButtons=function() end,UpdateBagBarVisibility=function() end}
addon.cursor={Enable=function() end,Disable=function() end}
addon.xpbar={UpdateAllBars=function() end}; addon.castbar={ReloadConfig=function() end,ShowBlizzardCastbar=function() end}
ConsoleExperience_ActionButton=function() actions=actions+1 end
local function event(name)
    getfenv(0).event=name
    addon:GetScript("OnEvent")()
    driver:GetScript("OnEvent")()
end
event("VARIABLES_LOADED"); event("PLAYER_ENTERING_WORLD")
assert(initializations==0 and worlds==0 and MainMenuBar:IsShown() and ChatFrame1:GetScale()==1)
assert(CreateFrame==originalCreateFrame and not hud:IsVisible() and messages==0,"disconnected login must preserve UI and CreateFrame and remain silent")
hud:GetScript("OnEvent")(); ConsoleExperience_ActionButton(1)
assert(events==0 and actions==0,"disconnected events and bindings must do nothing")
state[1]=true; driver:Update(0.016)
assert(addon:IsControllerActive() and initializations==1 and not MainMenuBar:IsShown() and hud:IsVisible())
assert(driver.armed and CreateFrame~=originalCreateFrame,"hot-plug must activate and arm neutral input")
hud:GetScript("OnEvent")(); ConsoleExperience_ActionButton(1)
assert(events==1 and actions==1)
local stockButton=frame("Button", "TestStockLootButton", UIParent)
stockButton.backdrop={bgFile="original"}
function stockButton:GetBackdrop() return self.backdrop end
function stockButton:SetBackdrop(value) self.backdrop=value end
local decoration=stockButton:CreateTexture()
stockButton.themeArt={wash=decoration}
addon:CaptureThemeState(stockButton)
stockButton:SetBackdrop({bgFile="controller"}); stockButton:SetAlpha(0.4)
state[1]=false; driver:Update(0.016)
assert(not addon:IsControllerActive() and not driver.armed and not hud:IsVisible())
assert(MainMenuBar:IsShown() and not MultiBarRight:IsShown() and ChatFrame1:GetScale()==1 and GameMenuFrame:GetHeight()==150)
assert(ChatFrame1:GetNumPoints()==1)
local _,_,_,x,y=ChatFrame1:GetPoint(1); assert(x==27 and y==41)
assert(CreateFrame==originalCreateFrame and not WindrunnerControllerModeHint:IsShown())
assert(stockButton:GetBackdrop().bgFile=="original" and stockButton:GetAlpha()==1 and not decoration:IsShown(),"disconnect must restore stock loot styling and hide controller decorations")
hud:GetScript("OnEvent")(); ConsoleExperience_ActionButton(1); assert(events==1 and actions==1)
-- A changed keyboard UI becomes the next restoration baseline.
ChatFrame1:SetScale(1.3)
state[1]=true; state[2]=4096; driver:Update(0.016)
assert(addon:IsControllerActive() and initializations==1 and not driver.armed,"held reconnect must wait for neutral input")
state[2]=0; driver:Update(0.016); assert(driver.armed)
state[1]=0; driver:Update(0.016)
assert(not addon:IsControllerActive() and ChatFrame1:GetScale()==1.3 and GameMenuFrame:GetHeight()==150)
state[1]=true; driver:Update(0.016)
WindrunnerController_Poll=nil; driver:Update(0.016)
assert(not addon:IsControllerActive() and CreateFrame==originalCreateFrame,"loss of native bridge must also restore keyboard UI")
print("PASS: disconnected startup, hot-plug, dormant events/bindings, full UI restoration, reconnect, neutral arming, numeric states, and bridge loss.")

-- Regression scenarios execute the current addon modules under Lua 5.0.3.
local root = assert(arg[1], "pass the current addon root")
local frames, calls = {}, {}
local function record(name, value) table.insert(calls, {name, value}) end
local function last(name)
    for i=table.getn(calls),1,-1 do if calls[i][1]==name then return calls[i][2] end end
end
local function ui(name)
    local frame = {scripts={}, visible=true, enabled=true, width=640, height=400}
    function frame:GetName() return name end
    function frame:SetScript(eventName, callback) self.scripts[eventName]=callback end
    function frame:GetScript(eventName) return self.scripts[eventName] end
    function frame:Show() self.visible=true end
    function frame:Hide() self.visible=false end
    function frame:IsShown() return self.visible end
    function frame:IsVisible() return self.visible end
    function frame:Enable() self.enabled=true end
    function frame:Disable() self.enabled=false end
    function frame:SetWidth(value) self.width=value end
    function frame:SetHeight(value) self.height=value end
    function frame:GetWidth() return self.width end
    function frame:GetHeight() return self.height end
    function frame:SetText(value) self.text=value end
    function frame:GetText() return self.text end
    function frame:CreateTexture() return ui() end
    function frame:CreateFontString() return ui() end
    for _,method in ipairs({"SetPoint","SetFrameStrata","SetFrameLevel","SetAllPoints","SetTexture",
        "SetJustifyH","SetJustifyV","SetTextColor","SetAlpha","RegisterEvent","RegisterForClicks"}) do frame[method]=function() end end
    if name then frames[name]=frame end
    return frame
end
getglobal=function(name) return getfenv(0)[name] or frames[name] end
getfenv(0)._G=getfenv(0)
CreateFrame=function(kind,name) return ui(name) end
UIParent=ui("UIParent")
GameMenuFrame=ui("GameMenuFrame")
SlashCmdList={}
StaticPopupDialogs={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
ChatFrameEditBox={IsShown=function() return false end}
IsShiftKeyDown=function() return false end
IsControlKeyDown=function() return false end
CE_Debug=function() end
PlaySound=function() end
local bonusBar=0
GetBonusBarOffset=function() return bonusBar end
UnitClass=function() return "Warrior","WARRIOR" end
HasAction=function() return true end
local target, previousTarget="enemy",nil
UnitExists=function(unit) return unit~="target" or target~=nil end
UnitIsUnit=function(unit, other) return (unit=="target" and target or unit)==other end
TargetUnit=function(unit) previousTarget=target; target=unit end
TargetLastTarget=function() target=previousTarget end
ClearTarget=function() target=nil end
SpellIsTargeting=function() return false end
SpellCanTargetUnit=function() return true end
local scope, failAction=nil,false
UseAction=function(slot)
    assert(scope=="frame" or scope=="hardware", "action escaped input scope")
    if failAction then error("simulated cast failure") end
    record("action",{slot,target})
end
RunBinding=function(action) assert(scope); record("binding",action) end
TargetNearestEnemy=function() record("target") end
ToggleWorldMap=function() record("map") end
WindrunnerController_SetMovement=function(mask) assert(scope); record("movement",mask); return true end
WindrunnerController_Jump=function() assert(scope=="frame"); record("jump",true); return true end
WindrunnerController_ToggleAutorun=function() assert(scope=="frame"); record("autorun",true); return true,true end
WindrunnerController_Mouse=function(dx,dy,buttons,mode) record("mouse",{dx,dy,buttons,mode}); return true end
WindrunnerController_Release=function() end
WindrunnerController_RunRelease=function()
    local prior=scope; scope="release"
    local ok,message=pcall(WindrunnerController_DispatchRelease)
    scope=prior; return ok,message
end
WindrunnerController_RunFrame=function()
    local prior=scope; scope="frame"
    local ok,message=pcall(WindrunnerController_DispatchFrame)
    scope=prior; return ok,message
end
local state={true,0,0,0,0,0,0,0,true,1,0}
WindrunnerController_Poll=function() return unpack(state) end
local function loadSource(path) assert(loadfile(root .. "/" .. path))() end
ConsoleExperience={}
WindrunnerExperienceDB={config={healerMode=false},proxiedActions={}}
loadSource("WindrunnerController.lua")
loadSource("WindrunnerControllerIntegration.lua")
loadSource("keybindings.lua")
loadSource("actionbars/bars.lua")
local controller, bars=WindrunnerController,ConsoleExperience.actionbars
ConsoleExperience.config={Get=function(self,key) return WindrunnerExperienceDB.config[key] end}
ConsoleExperience.proxied={GetSlotBinding=function(self,slot)
    return WindrunnerExperienceDB.proxiedActions[slot] or (slot>=73 and WindrunnerExperienceDB.proxiedActions[slot-bonusBar*12-60])
end}
local focused=ui("PartyMemberFrame2")
local menu=false
ConsoleExperience.cursor={navigationState={currentButton=focused,activeFrames={}},
    keybindings={IsCursorModeActive=function() return menu end},tooltip={GetBindings=function()
        return {{key="1",action="CE_CURSOR_CLICK_LEFT"},{key="5",action="CE_CURSOR_MOVE_DOWN"}}
    end}}
ConsoleExperience.hooks={IsPartyRaidFrame=function(self,name) return name=="PartyMemberFrame2" end}
CE_ClickCursor=function() record("click",true) end
CE_MoveCursor=function(direction) record("navigate",direction) end
controller.world=true
controller.armed=true
local function dispatch(buttons,lt,rt,lx,ly,rx,ry)
    controller.pendingInput={0.016,buttons or 0,lt or 0,rt or 0,lx or 0,ly or 0,rx or 0,ry or 0}
    local ok,message=WindrunnerController_RunFrame()
    controller.pendingInput=nil
    assert(ok,message)
end
bars.currentPage=2
keystate="previous"
dispatch(16384)
assert(last("action")[1]==2 and keystate=="previous", "released LT must use base X before the bar refresh")
dispatch(0)
dispatch(16384,0.6)
assert(last("action")[1]==12, "LT+X must use its sampled page")
dispatch(0)
bonusBar=3; bars.currentPage=4
dispatch(16384)
assert(last("action")[1]==98, "released triggers must retain the active stance offset")
bonusBar=0
menu=true
WindrunnerExperienceDB.config.healerMode=true
ConsoleExperience.cursor.navigationState.activeFrames[focused]={healerMode=true}
bars.currentPage=1
dispatch(0)
dispatch(16384,0.6,0,0,1,0.5,0)
assert(last("action")[1]==12 and last("action")[2]=="party2", "native healer X must cast on the focused party2 unit and sampled page")
assert(target=="enemy" and keystate=="previous", "healing must restore target and keystate")
assert(last("movement")==16 and last("mouse")[4]==1, "healer focus must preserve movement and camera")
dispatch(0)
local panel=ui("MerchantFrame")
ConsoleExperience.cursor.navigationState.activeFrames[panel]=true
dispatch(4096,0,0,0,1,0.5,0)
assert(last("click") and last("movement")==0 and last("mouse")[4]==0, "a real menu must override healer gameplay")
ConsoleExperience.cursor.navigationState.activeFrames[panel]=nil
failAction=true
local ok=pcall(function() dispatch(16384) end)
assert(not ok and target=="enemy" and keystate=="previous" and scope==nil, "failed healer cast must restore target, keystate, and scope")
failAction=false
menu=false; WindrunnerExperienceDB.config.healerMode=false
WindrunnerExperienceDB.proxiedActions[1]="JUMP"
scope="hardware"; keystate="down"; ConsoleExperience_ActionButton(1); scope=nil
assert(last("binding")=="JUMP", "mapped A must honor the main-bar jump proxy")
dispatch(0); dispatch(4096)
assert(last("jump"), "native A must keep its native jump route")
local hint=frames.WindrunnerControllerModeHint
controller:ShowModeHint("Ready","success")
this=hint; arg1=0.05
for i=1,65 do if hint.scripts.OnUpdate then hint.scripts.OnUpdate() end end
assert(not hint.visible and not hint.scripts.OnUpdate, "ordinary hints must expire and remove their timer")
controller:SetPaused(true)
this=hint; arg1=0.05
assert(pcall(hint.scripts.OnUpdate), "formatted pause hints must use frame elapsed time")
controller:SetPaused(false)
WindrunnerControllerDB={sensitivity=1200}
assert(controller:GetSetting("cameraSensitivity")==1200 and controller:GetSetting("pointerSensitivity")==1200, "legacy sensitivity must migrate to both speeds")
controller:SetSetting("cameraSensitivity",900)
assert(controller:GetSetting("pointerSensitivity")==1200, "camera tuning must not change pointer speed")
controller:SetSetting("leftDeadzone",0.10)
local x,y=controller:NormalizeStick(0.05,0,controller:GetSetting("leftDeadzone"))
assert(x==0 and y==0, "calibrated deadzone must remove drift")
x,y=controller:NormalizeStick(1,1,0.10)
assert(math.abs(x*x+y*y-1)<0.00001, "calibrated diagonals must stay inside the unit circle")
controller:SetSetting("cameraSensitivity",5000)
assert(controller:GetSetting("cameraSensitivity")==3000, "speed must remain bounded")
controller:SetSetting("cameraSensitivity",900)
controller:SetSetting("rightDeadzone",0.10)
controller.armed=true; controller.pointer=false
dispatch(0,0,0,0,0,0.5,0)
assert(math.abs(last("mouse")[1]-7.2)<0.00001, "camera must use camera speed")
controller.pointer=true
dispatch(0,0,0,0,0,0.5,0)
assert(math.abs(last("mouse")[1]-9.6)<0.00001, "pointer must use its independent speed")
controller.connected=true; controller.foreground=true; controller.hasRawInput=true
assert(controller:BeginCalibration())
assert(controller:UpdateCalibration(0.05,4096,0,0,0.02,0,0.03,0) and controller.calibration,
    "calibration must wait for its activating button to be released")
for i=1,21 do controller:UpdateCalibration(0.05,0,0,0,0.02,0,0.03,0) end
assert(not controller.calibration and not controller.armed, "calibration must complete without enabling gameplay")
assert(math.abs(controller:GetSetting("leftDeadzone")-0.06)<0.00001 and math.abs(controller:GetSetting("rightDeadzone")-0.07)<0.00001,
    "calibration must save measured drift plus a margin")
local oldDeadzone=controller:GetSetting("leftDeadzone")
controller:BeginCalibration()
controller:UpdateCalibration(0.1,0,0,0,0,0,0,0)
controller:UpdateCalibration(0.1,0,0,0,1,0,0,0)
assert(not controller.calibration and controller:GetSetting("leftDeadzone")==oldDeadzone, "moving a stick during measurement must cancel without replacing settings")
controller:SetSetting("leftDeadzone",0.10); controller:SetSetting("rightDeadzone",0.10)
controller.pointer=false
state={true,0,0,0,0,0,0,0,true,1,0,0.02,0,0.03,0}
controller:Update(0.05)
assert(controller.hasRawInput and controller.armed and controller.sample[4]==0,
    "raw poll values must pass through the configured deadzone before neutral arming")
state[12]=0.5; state[14]=0.5
controller:Update(0.05)
assert(last("movement")==128 and math.abs(last("mouse")[1]-20)<0.00001,
    "raw axes must drive movement and camera using calibrated travel")
assert(controller:BeginCalibration())
state[2]=4096; state[12]=0.02; state[14]=0.03
controller:Update(0.05)
assert(controller.calibration and not controller.armed, "calibration must consume the activating press")
state[2]=0
for i=1,25 do
    if not controller.calibration then break end
    controller:Update(0.05)
end
assert(not controller.calibration and not controller.armed, "poll-driven calibration must require a new neutral frame before gameplay resumes")
controller:Update(0.05)
assert(controller.armed, "controller must rearm after calibration on neutral input")
-- Current radial math must select the correct cardinal sectors on Lua 5.0.
loadSource("radial/radial.lua")
local radial=ConsoleExperience.radial
radial.frame=ui(); radial.menuItems={}
for i=1,12 do table.insert(radial.menuItems,{}) end
radial.SetSelected=function(self,index) self.selectedIndex=index end
radial:SelectFromStick(0,1); assert(radial.selectedIndex==1)
radial:SelectFromStick(1,0); assert(radial.selectedIndex==4)
radial:SelectFromStick(0,-1); assert(radial.selectedIndex==7)
radial:SelectFromStick(-1,0); assert(radial.selectedIndex==10)
radial.frame:Hide()
-- Exercise the real settings controls with a lightweight layout host.
loadSource("config/config.lua")
loadSource("config/rows.lua")
local config=ConsoleExperience.config
config.contentSections={}
config.CreateScrollableSection=function() return ui() end
local boxes={}
config.CreateSectionBox=function()
    local frame=ui(); frame.contentLeft=12; frame.contentTop=-25
    table.insert(boxes,frame); return frame
end
config.CreateCheckbox=function() return ui() end
config:CreateControllerSection()
local cameraBefore=controller:GetSetting("cameraSensitivity")
frames.CEControllercameraSensitivity.cursorAdjust("RIGHT")
assert(controller:GetSetting("cameraSensitivity")==cameraBefore+50, "camera UI control must change only camera speed")
local leftBefore=controller:GetSetting("leftDeadzone")
frames.CEControllerleftDeadzone.cursorAdjust("RIGHT")
assert(math.abs(controller:GetSetting("leftDeadzone")-leftBefore-0.01)<0.00001, "deadzone UI control must adjust calibration")
controller.hasRawInput=false
this=boxes[3]; arg1=0.3; boxes[3].scripts.OnUpdate()
assert(not frames.CEControllerleftDeadzone.enabled and not frames.CEControllerCalibrate.enabled,
    "older DLLs must disable raw-axis tuning and calibration in the UI")
-- Older DLLs remain usable; raw-axis controls must be unavailable.
assert(controller:BeginCalibration()==false, "old DLL must not perform a fake calibration")
print("PASS: current action pages, stances, healer targeting/movement, mapped proxies, hints, radial sectors, calibration, and tuning UI.")

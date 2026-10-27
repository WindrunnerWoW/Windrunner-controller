-- Run under real Lua 5.0.3; tests exercise safety transitions and native dispatch.
local calls = {}
local scripts = {}
local frames = {}
local function record(name, value) table.insert(calls,{name,value}) end
local function count(name)
    local result=0
    for _,entry in ipairs(calls) do if entry[1]==name then result=result+1 end end
    return result
end
getglobal=function(name) return getfenv(0)[name] end
UIParent={}
SlashCmdList={}
WindrunnerControllerDB={debug=true}
local function uiFrame(name)
    local frame={scripts={},shown=true}
    function frame:SetScript(eventName,fn) self.scripts[eventName]=fn end
    function frame:GetScript(eventName) return self.scripts[eventName] end
    function frame:Hide() self.shown=false end
    function frame:Show() self.shown=true end
    function frame:IsShown() return self.shown end
    function frame:IsVisible() return self.shown end
    function frame:SetText(text) self.text=text end
    for _,method in ipairs({"RegisterEvent","SetWidth","SetHeight","SetPoint","SetFrameStrata",
        "SetFrameLevel","SetAllPoints","SetTexture","SetJustifyH","SetTextColor","SetAlpha"}) do
        frame[method]=function() end
    end
    function frame:CreateTexture() return uiFrame() end
    function frame:CreateFontString() return uiFrame() end
    if name then frames[name]=frame end
    if name=="WindrunnerControllerFrame" then scripts=frame.scripts end
    return frame
end
CreateFrame=function(kind,name,parent,template)
    if kind=="EditBox" then
        return {shown=true,scripts={}, IsObjectType=function(self,query) return query=="EditBox" end,
            GetScript=function(self,eventName) return self.scripts[eventName] end,
            SetScript=function(self,eventName,fn) self.scripts[eventName]=fn end,
            IsShown=function(self) return self.shown end, IsVisible=function(self) return self.shown end,
            originalArgs={kind,name,parent,template}}
    end
    return uiFrame(name)
end
DEFAULT_CHAT_FRAME={AddMessage=function(self,message) record("message",message) end}
ChatFrameEditBox={shown=false,IsShown=function(self) return self.shown end}
local edit={shown=true,scripts={}}
function edit:IsObjectType(kind) return kind=="EditBox" end
function edit:GetScript(name) return self.scripts[name] end
function edit:SetScript(name,fn) self.scripts[name]=fn end
function edit:IsShown() return self.shown end
EnumerateFrames=function(previous) if not previous then return edit end end
local state={true,0,0,0,0,0,0,0,true,1,0}
local nativeScope=nil
local nativeAvailable=true
local function protectedInput(name,value)
    assert(nativeScope,"protected input escaped native dispatch: "..name)
    if nativeScope=="release" then assert(string.find(name,"Stop$"),"release dispatch must only stop movement") end
    record(name,value)
    local movementBits={MoveForwardStart=16,MoveBackwardStart=32,StrafeLeftStart=64,StrafeRightStart=128}
    local stoppedBits={MoveForwardStop=16,MoveBackwardStop=32,StrafeLeftStop=64,StrafeRightStop=128}
    if movementBits[name] then state[11]=state[11]+(math.mod(state[11],movementBits[name]*2)<movementBits[name] and movementBits[name] or 0) end
    if stoppedBits[name] and math.mod(state[11],stoppedBits[name]*2)>=stoppedBits[name] then state[11]=state[11]-stoppedBits[name] end
end
local currentMovementMask=0
WindrunnerController_SetMovement=function(mask)
    assert(nativeScope,"native movement dispatch escaped controller scope")
    if nativeScope=="release" then assert(mask==0,"release scope may only stop movement") end
    if mask~=currentMovementMask then record("movement",mask) end
    currentMovementMask=mask
    state[11]=(state[11]-math.mod(state[11],256))+mask
    return true
end
WindrunnerController_Jump=function()
    assert(nativeScope=="frame","jump must use the authorized frame scope")
    record("jump")
    return true
end
WindrunnerController_ToggleAutorun=function()
    assert(nativeScope=="frame","autorun must use the authorized frame scope")
    local enabled=math.mod(math.floor(state[11]/4096),2)==0
    if enabled then state[11]=state[11]+4096 else state[11]=state[11]-4096 end
    return true,enabled
end
WindrunnerController_RunFrame=function()
    if not nativeAvailable or not state[1] or not state[9] then return false end
    assert(not nativeScope,"frame dispatch must not recurse")
    nativeScope="frame"
    local ok,message=pcall(WindrunnerController_DispatchFrame)
    nativeScope=nil
    return ok,message
end
WindrunnerController_RunRelease=function()
    local previous=nativeScope
    nativeScope="release"
    local ok,message=pcall(WindrunnerController_DispatchRelease)
    nativeScope=previous
    return ok,message
end
WindrunnerController_Poll=function() return unpack(state) end
WindrunnerController_Release=function() record("release") end
WindrunnerController_Mouse=function(x,y,buttons,mode) record("mouse",{x,y,buttons,mode}) end
for _,name in ipairs({"MoveForwardStart","MoveForwardStop","MoveBackwardStart","MoveBackwardStop",
    "StrafeLeftStart","StrafeLeftStop","StrafeRightStart","StrafeRightStop","Jump","ToggleWorldMap","CE_ToggleRadialMenu"}) do
    local command=name
    getfenv(0)[command]=function() protectedInput(command) end
end
TargetNearestEnemy=function(reverse) protectedInput("target",reverse) end
RunBinding=function(command) protectedInput("binding",command) end
local menu=false
local proxied={ [1]="JUMP",[30]="CE_INTERACT" }
local current={GetName=function() return "MerchantItem1ItemButton" end}
ConsoleExperience={cursor={navigationState={currentButton=current},keybindings={IsCursorModeActive=function() return menu end},
    tooltip={GetBindings=function(self,name) return {{key="1",action="CE_CURSOR_CLICK_LEFT"},{key="2",action="CE_CURSOR_BIND"},
        {key="5",action="CE_CURSOR_MOVE_DOWN"},{key="6",action="CE_CURSOR_MOVE_LEFT"},
        {key="7",action="CE_CURSOR_MOVE_UP"},{key="8",action="CE_CURSOR_MOVE_RIGHT"}} end}},
    proxied={GetSlotBinding=function(self,slot) return proxied[slot] end}}
ConsoleExperience_ActionButton=function(slot) assert(keystate=="down"); protectedInput("action",slot) end
CE_MoveCursor=function(direction) protectedInput("navigate",direction) end
CE_ClickCursor=function(button) protectedInput("click",button) end
CE_CloseFrame=function() protectedInput("close") end
CE_Bind=function() protectedInput("bind") end
CE_PickupItem=function() end
CE_DeleteItem=function() end
CE_UnequipItem=function() end
CE_PLACEMENT_CLEAR=function() end
assert(arg[1], "pass the merged Windrunner-Controller controller Lua path")
if arg[2] then assert(loadfile(arg[2] .. "/config/controls.lua"))() end
assert(loadfile(arg[1]))()
local controller=WindrunnerController
local function frame(buttons,lx,ly,lt,rt,rx,ry)
    state[2],state[3],state[4],state[5],state[6],state[7],state[8]=buttons or 0,lt or 0,rt or 0,lx or 0,ly or 0,rx or 0,ry or 0
    controller:Update(0.05)
end
local function event(name) getfenv(0).event=name; scripts.OnEvent() end
event("VARIABLES_LOADED")
frame(0,0,1)
assert(state[11]==0,"login must never move")
event("PLAYER_ENTERING_WORLD")
frame(0,0,1)
assert(not controller.armed,"held movement must not arm on login")
frame()
assert(controller.armed,"neutral controller should arm")
frame(0,0.7,0.8)
assert(state[11]==144 and count("movement")==1,"stick should reach the native movement dispatcher")
frame(0,0.7,0.8)
controller:UpdateStatus()
assert(string.find(controller.statusText.text,"Game flags F1 B0 L0 R1 AutoRun 0"),"debug overlay should expose live movement and autorun flags: " .. tostring(controller.statusText.text))
frame(0,0.7,0.8)
assert(count("movement")==1,"unchanged held movement must not reissue starts")
frame()
assert(state[11]==0 and count("movement")==2,"neutral should stop held movement")
frame(4096)
frame(4096)
assert(count("jump")==1,"jump should fire once per press")
assert(controller.lastRoute=="1 -> Jump","debug overlay should show the jump route")
frame()
proxied[2]="TOGGLEAUTORUN"
frame(16384)
assert(math.mod(math.floor(state[11]/4096),2)==1 and controller.lastRoute=="2 -> AutoRun ON",
    "the CE autorun binding should toggle the game's autorun flag on")
frame()
frame(16384)
assert(math.mod(math.floor(state[11]/4096),2)==0 and controller.lastRoute=="2 -> AutoRun OFF",
    "a second CE autorun press should toggle autorun off")
frame()
local toggleAutorun=WindrunnerController_ToggleAutorun
WindrunnerController_ToggleAutorun=function()
    assert(nativeScope=="frame","a refused autorun press must stay in frame scope")
    record("autorun-refused")
    return false,false
end
state[2],state[6]=16384,1
getfenv(0).arg1=0.05
scripts.OnUpdate()
assert(not controller.paused and controller.armed and not controller.lastError and controller.movement.forward,
    "a refused autorun action must not raise a Lua error, pause input or stop stick movement")
assert(controller.lastRoute=="2 -> AutoRun unavailable" and controller.pendingInput==nil and nativeScope==nil,
    "a refused autorun action should report unavailable and restore dispatch state")
frame(16384,0,1)
assert(count("autorun-refused")==1,"holding a refused autorun button must not retry every frame")
frame()
assert(not controller.movement.forward,"stick movement must still release after an autorun refusal")
nativeScope="frame"
controller:RunAuxAction("TOGGLEAUTORUN","LS")
nativeScope=nil
assert(controller.lastRoute=="LS -> AutoRun unavailable" and not controller.paused,
    "auxiliary autorun assignments must also handle refusals without a Lua error")
WindrunnerController_ToggleAutorun=toggleAutorun
frame(16384)
assert(math.mod(math.floor(state[11]/4096),2)==1 and controller.lastRoute=="2 -> AutoRun ON",
    "autorun should work on the next press after a temporary refusal")
frame()
frame(16384)
frame()
proxied[2]=nil
keystate="previous"
frame(16384,0,0,0.6)
assert(calls[table.getn(calls)-1][1]=="action" and calls[table.getn(calls)-1][2]==12,"LT+X should use action 12")
assert(keystate=="previous","CE action must preserve prior key state")
frame()
menu=true
frame(4096)
assert(count("click")==1,"A in menus must select the CE cursor")
frame()
frame(1)
local before=count("navigate")
for i=1,12 do frame(1) end
assert(count("navigate")>before,"D-pad menu navigation should repeat")
frame(1,0,1)
assert(state[11]==0,"menu should suppress gameplay movement")
menu=false
frame()
frame(0,0,1)
state[9]=false
frame(0,0,1)
assert(not controller.armed and state[11]==0,"focus loss must release movement")
state[9]=true
frame(0,0,1)
assert(not controller.armed,"focus regain while held must stay disarmed")
frame()
assert(controller.armed)
frame(0,0,1)
state[10]=2
frame(0,0,1)
assert(not controller.armed and state[11]==0,"controller epoch replacement must release and disarm")
frame()
frame(0,0,1)
ChatFrameEditBox.shown=true
frame(4096,0,1)
assert(not controller.armed and state[11]==0,"chat must release movement and block actions")
assert(count("jump")==1,"chat must block jump")
ChatFrameEditBox.shown=false
-- A CE virtual keyboard is a native menu, even while the real edit box has
-- physical keyboard focus. It must accept controller navigation, but never
-- fall back to jump/casts when contextual keys are missing or still loading.
ConsoleExperience.keyboard={frame={IsVisible=function() return true end}}
ChatFrameEditBox.shown=true
frame()
assert(controller.armed and not controller:IsTyping() and controller:IsMenuActive(),"virtual keyboard must arm and navigate while real chat retains focus")
local virtualClicks=count("click")
local virtualStarts=count("movement")
frame(4096,0,1)
assert(count("click")==virtualClicks+1 and count("movement")==virtualStarts,"virtual keyboard accepts A and suppresses stick movement")
frame()
local originalBindings=ConsoleExperience.cursor.tooltip.GetBindings
ConsoleExperience.cursor.tooltip.GetBindings=function() return nil end
local virtualJumps=count("jump")
local virtualActions=count("action")
frame(4096+512+64+16)
assert(count("jump")==virtualJumps and count("action")==virtualActions,"virtual keyboard must not execute gameplay fallbacks or shoulders")
ConsoleExperience.cursor.tooltip.GetBindings=originalBindings
ConsoleExperience.keyboard=nil
ChatFrameEditBox.shown=false
frame(4096)
assert(not controller.armed,"held buttons when closing chat must stay disarmed")
frame()
frame(0,0,1)
getfenv(0).this=edit
edit.scripts.OnEditFocusGained()
assert(not controller.armed and state[11]==0,"any focused editbox must release immediately")
frame(4096)
assert(count("jump")==1,"non-chat typing must block actions")
edit.scripts.OnEditFocusLost()
frame()
-- A lazy dialog focuses a new editbox immediately, before the periodic scan.
local dynamic=CreateFrame("EditBox","ImmediateFocus",UIParent,"InputBoxTemplate")
assert(dynamic.originalArgs[2]=="ImmediateFocus" and dynamic.originalArgs[4]=="InputBoxTemplate","CreateFrame arguments must be preserved")
local gainedCalls=0
dynamic:SetScript("OnEditFocusGained",function() gainedCalls=gainedCalls+1 end)
getfenv(0).this=dynamic
dynamic.scripts.OnEditFocusGained()
assert(not controller.armed and controller:IsTyping() and gainedCalls==1,"new editbox focus must block immediately and preserve scripts")
local previousGained=dynamic:GetScript("OnEditFocusGained")
dynamic:SetScript("OnEditFocusGained",function() previousGained(); gainedCalls=gainedCalls+10 end)
dynamic.scripts.OnEditFocusGained()
assert(gainedCalls==12,"focus handlers chained by other addons must not recurse")
dynamic.scripts.OnEditFocusLost()
frame()
-- Menu selection may focus an editbox synchronously while processing this frame.
local originalClick=CE_ClickCursor
menu=true
CE_ClickCursor=function(button) getfenv(0).this=dynamic; dynamic.scripts.OnEditFocusGained() end
local mouseBefore=count("mouse")
local actionsBefore=count("action")
frame(4096+32768,0,0,0,0,1,0)
assert(not controller.armed and count("mouse")==mouseBefore and count("action")==actionsBefore,
    "synchronous focus during A selection must stop further actions and mouse in the same frame")
dynamic.scripts.OnEditFocusLost()
CE_ClickCursor=originalClick
menu=false
frame()
local releasesBeforePointerToggle=count("release")
frame(128,0,0,0,0,0.5,0.25)
assert(controller.pointer,"right-stick click should toggle pointer")
assert(count("release")==releasesBeforePointerToggle,"right-stick click must not invalidate the native heartbeat mid-frame")
local pointerSwitchMouse=calls[table.getn(calls)][2]
assert(pointerSwitchMouse[4]==0,"right-stick click should send the pointer-mode mouse update in the same frame")
frame()
frame(4096,0,0,0,0,0.5,0.5)
local mouse=calls[table.getn(calls)][2]
assert(mouse[3]==1 and mouse[4]==0,"pointer A must hold left mouse")
assert(count("jump")==1,"pointer A must not also jump")
frame(16384)
mouse=calls[table.getn(calls)][2]
assert(mouse[3]==2,"pointer X must hold right mouse")
frame()
frame(48)
assert(controller.paused and not controller.armed,"Back+Start should pause")
frame(48)
assert(controller.paused,"held pause chord should not toggle repeatedly")
frame()
frame(48)
assert(not controller.paused and not controller.armed,"resume requires neutral afterward")
frame()
assert(controller.armed)
-- Auxiliary assignments use the same native frame and respect context/typing.
local savedConfig=ConsoleExperience.config
local savedLookup=ConsoleExperience.proxied.GetActionByID
local auxiliary={controllerLeftStickClick="JUMP",controllerRightStickClick="OPENALLBAGS",
    controllerBackButton="NONE",controllerStartButton="TOGGLEWORLDMAP"}
ConsoleExperience.config={Get=function(self,key) return auxiliary[key] end}
local validAux={JUMP=true,OPENALLBAGS=true,TOGGLEWORLDMAP=true,TARGETNEARESTENEMY=true}
ConsoleExperience.proxied.GetActionByID=function(self,id) return validAux[id] and {id=id} end
local auxJumps=count("jump")
frame(64)
frame(64)
assert(count("jump")==auxJumps+1 and controller.lastRoute=="LS -> JUMP","stick click should run its assignment once per press")
frame()
frame(64,0,0,0.6)
assert(count("jump")==auxJumps+2,"auxiliary assignment must apply while trigger modifiers are held")
frame()
local auxBindings=count("binding")
frame(128)
assert(count("binding")==auxBindings+1 and calls[table.getn(calls)-1][2]=="OPENALLBAGS","right-stick click must dispatch its chosen interface action")
frame()
menu=true
frame(128)
assert(count("binding")==auxBindings+2,"interface auxiliary actions should remain usable in menus")
frame()
frame(64)
assert(count("jump")==auxJumps+2,"gameplay auxiliary actions must be suppressed in menus")
menu=false; frame()
local auxMaps=count("ToggleWorldMap")
frame(32)
assert(count("ToggleWorldMap")==auxMaps,"disabled Back must do nothing")
frame()
frame(16)
assert(count("ToggleWorldMap")==auxMaps+1,"Start must dispatch a remapped map action")
frame()
frame(48)
assert(controller.paused and not controller.armed and count("ToggleWorldMap")==auxMaps+1,
    "pause chord must stay reserved even when Back and Start have different assignments")
frame(); frame(48); frame()
assert(not controller.paused and controller.armed)
local originalRadial=CE_ToggleRadialMenu
local radialShown=false
ConsoleExperience.radial={IsVisible=function() return radialShown end,Hide=function() radialShown=false end}
CE_ToggleRadialMenu=function() protectedInput("aux-radial"); radialShown=true end
auxiliary.controllerLeftStickClick="CE_TOGGLE_RADIAL"; auxiliary.controllerStartButton="NONE"
local auxActions=count("action"); auxBindings=count("binding")
frame(64+4096,0,1,0,0,1,0)
assert(radialShown and count("aux-radial")==1 and count("jump")==auxJumps+2 and count("action")==auxActions,
    "a remapped radial toggle must capture action buttons and movement on the opening frame")
assert(not controller.movement.forward and calls[table.getn(calls)][2][1]==0,"radial open must suppress camera movement")
frame(); frame(64)
assert(not radialShown,"the assigned radial button should close the menu")
frame()
auxiliary.controllerStartButton="not-a-binding"
frame(16)
assert(radialShown and count("aux-radial")==2 and count("binding")==auxBindings,"unknown saved actions must safely use the input's default")
radialShown=false; frame()
auxiliary.controllerLeftStickClick="JUMP"
ChatFrameEditBox.shown=true
frame(64+128+16)
assert(not controller.armed and count("jump")==auxJumps+2 and count("binding")==auxBindings and count("aux-radial")==2,
    "typing must suppress auxiliary assignments")
ChatFrameEditBox.shown=false; frame()
ConsoleExperience.keyboard={frame={IsVisible=function() return true end}}
frame(64+128+16)
assert(count("jump")==auxJumps+2 and count("binding")==auxBindings and count("aux-radial")==2,
    "virtual keyboard navigation must suppress auxiliary assignments")
ConsoleExperience.keyboard=nil
-- Modifier-specific auxiliary dispatch reads the current sample's page.
auxiliary.controllerLeftStickClickPage2="OPENALLBAGS"
frame()
local pageBindings=count("binding")
frame(64,0,0,0.6)
assert(controller:GetPage()==2 and count("binding")==pageBindings+1 and controller.lastRoute=="LS -> OPENALLBAGS")
frame()
-- Bumpers can replace triggers as modifiers; latches reset on release/focus loss.
auxiliary.controllerModifierSource="bumpers"
auxiliary.controllerModifierLatch=true
frame(256)
assert(controller:GetPage()==2 and controller.lastRoute~="0 -> action slot 20")
frame()
assert(controller:GetPage()==2,"latched modifiers must survive a physical release")
frame(512)
assert(controller:GetPage()==4)
frame()
controller:Release()
assert(controller:GetPage()==1,"recovery must clear both modifier latches")
frame()
auxiliary.controllerModifierLatch=false
frame(256+512)
assert(controller:GetPage()==4)
frame()
assert(controller:GetPage()==1)
-- Triggers become assignable buttons with bumper modifiers.
local triggerControl=ConsoleExperience.controllerControls.INPUTS.LT
triggerControl.key="controllerLeftTrigger"; triggerControl.default="NONE"
auxiliary.controllerLeftTrigger="JUMP"
local triggerJumps=count("jump")
frame(0,0,0,0.8)
frame(0,0,0,0.8)
assert(count("jump")==triggerJumps+1)
frame()
auxiliary.controllerModifierSource="triggers"; auxiliary.controllerLeftTrigger="NONE"
local savedPointer=controller.pointer; controller.pointer=false
menu=true; auxiliary.menuSwapConfirm=true
local swapClicks,swapCloses=count("click"),count("close")
frame(8192); frame(); frame(4096); frame()
assert(count("click")==swapClicks+1 and count("close")==swapCloses+1,"menu swap must exchange confirm and cancel")
auxiliary.menuSwapConfirm=false; menu=false; controller.pointer=savedPointer
-- A held utility-ring binding owns input until its release, in native scope.
validAux.CE_RING_12=true; validAux.CE_ACTION_10=true; validAux.NONE=true
auxiliary.controllerLeftStickClick="CE_RING_12"; auxiliary.controllerLeftStickClickPage2=nil
auxiliary.utilityRingRelease=true
local ringOpened,ringEnded=0,0
ConsoleExperience.rings={
    BeginHeld=function(_,index) protectedInput("ring-open",index); ringOpened=index; radialShown=true end,
    EndHeld=function(_,activate) if activate then protectedInput("ring-release"); ringEnded=ringEnded+1 end; radialShown=false end,
    Open=function(_,index) protectedInput("ring-open",index); ringOpened=index; radialShown=true end}
frame(64+4096,0,1)
assert(ringOpened==12 and radialShown and state[11]==0 and controller.heldRing==64)
frame(64)
frame()
assert(ringEnded==1 and controller.heldRing==nil and not radialShown)
frame(64)
controller:Release()
assert(ringEnded==1 and not radialShown,"focus/release cancellation must not activate held rings")
-- A ring in a normal action slot and behind a trigger shortcut captures the opening frame.
local slotRingGetter=ConsoleExperience.proxied.GetSlotBinding
ConsoleExperience.proxied.GetSlotBinding=function(_,slot)
    if slot==1 or slot==10 then return "CE_RING_12" end
end
local ringPointer=controller.pointer; controller.pointer=false
auxiliary.controllerLeftStickClick="NONE"
frame()
local actionBeforeRing=count("action")
frame(4096+16384,0,1,0,0,1,1)
assert(ringOpened==12 and controller.heldRing==4096 and state[11]==0 and count("action")==actionBeforeRing,
    "an action-slot wheel must suppress co-pressed actions, movement and mouse on its opening sample")
local wheelMouse=calls[table.getn(calls)][2]
assert(wheelMouse[1]==0 and wheelMouse[2]==0 and wheelMouse[3]==0 and wheelMouse[4]==0)
frame()
assert(ringEnded==2 and not radialShown)
auxiliary.controllerModifierSource="bumpers"; auxiliary.controllerLeftTrigger="CE_ACTION_10"
frame(0,0,1,0.8,0,1,1)
assert(controller.heldRing==1024 and state[11]==0,"trigger action-slot shortcuts must acquire held wheel input")
frame()
assert(ringEnded==3 and not radialShown)
auxiliary.utilityRingRelease=false
frame(4096,0,1,0,0,1,1)
assert(radialShown and controller.heldRing==nil and state[11]==0)
radialShown=false
frame()
auxiliary.controllerModifierSource="triggers"; auxiliary.controllerLeftTrigger="NONE"
controller.pointer=ringPointer
ConsoleExperience.proxied.GetSlotBinding=slotRingGetter
ConsoleExperience.rings=nil
auxiliary.utilityRingRelease=false; auxiliary.controllerLeftStickClick="JUMP"
frame()
-- Left-stick focus navigation has a drift gate, delayed repeat and D-pad priority.
menu=true; controller.pointer=false
local stickNavigation=count("navigate")
frame(0,0.9,0)
assert(count("navigate")==stickNavigation+1 and state[11]==0,"left stick moves menu focus without moving the character")
for i=1,3 do frame(0,0.9,0) end
assert(count("navigate")==stickNavigation+1,"holding a stick waits for the configured repeat delay")
for i=1,10 do frame(0,0.9,0) end
assert(count("navigate")>stickNavigation+1,"held stick navigation repeats after the delay")
frame()
stickNavigation=count("navigate")
frame(0,0.3,0)
assert(count("navigate")==stickNavigation,"small stick drift must not move menu focus")
frame(1,0.9,0)
assert(count("navigate")==stickNavigation+1,"D-pad wins over the stick instead of producing two focus moves")
frame()
stickNavigation=count("navigate")
frame(0,0.9,0.87); frame(0,0.9,0.92)
assert(count("navigate")==stickNavigation+1 and controller.menuStickDirection=="RIGHT",
    "stick noise near a diagonal must preserve the current navigation axis")
frame(0,0.5,0.95)
assert(count("navigate")==stickNavigation+2 and controller.menuStickDirection=="UP",
    "deliberately changing the dominant axis must navigate immediately")
frame()
menu=false; radialShown=true
local radialSample
ConsoleExperience.radial.SelectFromSticks=function(_,lx,ly,rx,ry) radialSample={lx,ly,rx,ry} end
frame(0,0.9,0,0,0,0,-0.9)
assert(radialSample and radialSample[1]>0.5 and radialSample[4]<-0.5 and state[11]==0,
    "native radial dispatch must supply both sticks and suppress character movement")
radialShown=false; controller.pointer=ringPointer
ConsoleExperience.radial=nil
frame()
CE_ToggleRadialMenu=originalRadial
ConsoleExperience.config=savedConfig; ConsoleExperience.proxied.GetActionByID=savedLookup
frame()
frame(0,0,1)
event("PLAYER_LEAVING_WORLD")
assert(not controller.world and not controller.armed,"world exit must disarm")
state[1]=0
frame()
assert(not controller.connected,"numeric zero is false under defensive native bool handling")
state[1]=1;state[9]=1
event("PLAYER_ENTERING_WORLD")
frame()
assert(controller.armed,"numeric one is accepted defensively")
-- An alpha CE action failure must not strand held movement or camera.
local originalAction=ConsoleExperience_ActionButton
ConsoleExperience_ActionButton=function() error("simulated CE action failure") end
controller.pointer=false
state[2],state[6]=16384,1
getfenv(0).arg1=0.05
scripts.OnUpdate()
assert(controller.paused and not controller.armed and not controller.movement.forward,
    "a downstream Lua exception must release movement and pause the controller")
assert(keystate=="previous","action exception must preserve prior key state")
assert(nativeScope==nil and controller.pendingInput==nil,"native error must restore scope and clear pending input")
ConsoleExperience_ActionButton=originalAction

-- Direct addon/other script calls remain subject to the client's protection.
local protectedBefore=count("Jump")
local jumpsBefore=count("jump")
local outsideOk=pcall(Jump)
assert(not outsideOk and count("Jump")==protectedBefore and count("jump")==jumpsBefore and nativeScope==nil,
    "ordinary external protected calls must remain blocked after controller dispatch")
local externalAction=pcall(controller.DispatchSlot,controller,2)
assert(not externalAction and nativeScope==nil and keystate=="previous",
    "direct Lua action dispatch must not grant a scope or leak synthetic key state")

-- Missing/outdated native dispatch APIs must never fall back to protected Lua calls.
local runFrame=WindrunnerController_RunFrame
local runRelease=WindrunnerController_RunRelease
controller:SetPaused(false)
frame()
local startBefore=count("movement")
WindrunnerController_RunFrame=nil
frame(4096,0,1)
assert(not controller.armed and count("movement")==startBefore and count("Jump")==protectedBefore and count("jump")==jumpsBefore,
    "missing frame dispatcher must disable controller gameplay")
WindrunnerController_RunFrame=runFrame
WindrunnerController_RunRelease=nil
frame()
frame(4096,0,1)
assert(not controller.armed and count("movement")==startBefore,
    "missing cleanup dispatcher must prevent arming and gameplay")
WindrunnerController_RunRelease=runRelease
frame()
assert(controller.armed)

-- A native hardware/focus race may refuse one frame without an error string.
frame(0,0,1)
local stoppedBefore=count("movement")
nativeAvailable=false
frame(4096,0,1)
assert(not controller.armed and not controller.movement.forward and controller.pendingInput==nil,
    "dispatch refusal must disarm, discard pending actions and stop held movement")
assert(count("movement")==stoppedBefore+1 and state[11]==0 and count("Jump")==protectedBefore and count("jump")==jumpsBefore,
    "refused native frame must perform cleanup without firing a button action")
nativeAvailable=true
frame(4096,0,1)
assert(not controller.armed,"restored native dispatch still requires neutral controls")
frame()
assert(controller.armed)

-- Explicit dispatcher errors and unexpected native Lua exceptions clean up too.
WindrunnerController_RunFrame=function() return false,"simulated dispatch refusal" end
state[2],state[6]=4096,1
scripts.OnUpdate()
assert(controller.paused and not controller.armed and controller.pendingInput==nil and nativeScope==nil,
    "explicit dispatch error must pause safely and restore pending/scope state")
WindrunnerController_RunFrame=runFrame
controller:SetPaused(false)
frame()
WindrunnerController_RunFrame=function() error("simulated native API error") end
state[2],state[6]=4096,1
scripts.OnUpdate()
assert(controller.paused and not controller.armed and controller.pendingInput==nil and nativeScope==nil,
    "native API exception must discard pending input before the outer error handler")
WindrunnerController_RunFrame=runFrame

-- Cleanup privilege cannot execute a jump/action, and error reporting stays bounded.
local dispatchRelease=WindrunnerController_DispatchRelease
WindrunnerController_DispatchRelease=function() Jump() end
local messagesBefore=count("message")
controller:Release()
controller:Release()
assert(nativeScope==nil and count("Jump")==protectedBefore and count("jump")==jumpsBefore and count("message")==messagesBefore+1,
    "release scope must permit only stops, restore its scope, and report repeated failure once")
WindrunnerController_DispatchRelease=dispatchRelease
controller:Release()
assert(controller.releaseError==nil,"successful cleanup must clear its previous error")
assert(not pcall(Jump) and nativeScope==nil,"protected calls remain blocked after release errors")

-- Execute the patched CE binding modules and ensure no physical binding calls occur.
local addonRoot=assert(arg[2],"pass the current addon root")
local bootstrap=addonRoot .. "/WindrunnerControllerIntegration.lua"
do
    local physicalWrites=0
    SetBinding=function() physicalWrites=physicalWrites+1 end
    SaveBindings=function() physicalWrites=physicalWrites+1 end
    GetBindingKey=function() return nil end
    GetBindingAction=function() return "PHYSICAL" end
    local oldDown=function() end
    local oldUp=function() end
    ActionButtonDown,ActionButtonUp=oldDown,oldUp
    getfenv(0)._G=getfenv(0)
    ConsoleExperience={}
    WindrunnerExperienceDB={}
    CE_Debug=function() end
    assert(loadfile(bootstrap))()
    assert(loadfile(addonRoot .. "/keybindings.lua"))()
    assert(loadfile(addonRoot .. "/config/proxied.lua"))()
    assert(loadfile(addonRoot .. "/cursor/keybindings.lua"))()
    ConsoleExperience.keybindings:Initialize()
    assert(physicalWrites==0,"CE initialization must never write or persist physical keyboard bindings")
    assert(ActionButtonDown==oldDown and ActionButtonUp==oldUp,"CE must preserve keyboard action handlers")
    assert(ConsoleExperience:GetControllerBindingAction("1")=="JUMP","default A should be virtual JUMP")
    assert(ConsoleExperience.GetControllerBindingAction("CTRL-0")=="CE_INTERACT","default RT+LB should be virtual interact")
    assert(ConsoleExperience:GetControllerBindingAction("SHIFT-2")=="CE_ACTION_12","LT+X virtual mapping")
    local keys=ConsoleExperience.cursor.keybindings
    ConsoleExperience.cursor.tooltip={GetBindings=function() return {{key="7",action="CE_CURSOR_MOVE_UP"},
        {key="5",action="CE_CURSOR_MOVE_DOWN"}} end}
    keys:SetupCursorBindings()
    assert(ConsoleExperience:GetControllerBindingAction("7")=="CE_CURSOR_MOVE_UP","cursor must use virtual bindings")
    local button={GetName=function() return "TestButton" end}
    keys:ApplyContextBindings({{key="1",action="CE_CURSOR_CLICK_LEFT"}},button)
    assert(ConsoleExperience:GetControllerBindingAction("1")=="CE_CURSOR_CLICK_LEFT","cursor A contextual virtual binding")
    ConsoleExperience.proxied:SetSlotBinding(5,"TOGGLEAUTORUN")
    assert(ConsoleExperience:GetControllerBindingAction("5")=="CE_CURSOR_MOVE_DOWN","changing proxy while in menu must retain cursor navigation")
    ConsoleExperience.proxied:SetSlotBinding(5,nil)
    assert(ConsoleExperience:GetControllerBindingAction("5")=="CE_CURSOR_MOVE_DOWN","clearing proxy while in menu must retain cursor navigation")
    keys:RestoreOriginalBindings()
    assert(ConsoleExperience:GetControllerBindingAction("1")=="JUMP","closing menus must restore virtual action")
    assert(ConsoleExperience:GetControllerBindingAction("5")=="CE_ACTION_5","closing menus must restore latest proxy choice")
    assert(physicalWrites==0,"cursor/proxied paths must never persist keyboard changes")
    -- Exercise the upstream Keyboard:Show implementation with our integration.
    -- Physical text and virtual typing must share one real edit box without
    -- enabling a keyboard-capturing frame or clearing the target's focus.
    assert(loadfile(addonRoot .. "/keyboard/keyboard.lua"))()
    local keyboard=ConsoleExperience.keyboard
    ConsoleExperience.config={Get=function() return true end}
    UIParent.GetWidth=function() return 1280 end
    UIParent.GetHeight=function() return 720 end
    local function uiFrame()
        return {scripts={},SetScript=function(self,key,fn) self.scripts[key]=fn end,
            Show=function(self) self.visible=true end,Hide=function(self) self.visible=false end,
            IsVisible=function(self) return self.visible end,ClearAllPoints=function() end,
            SetPoint=function() end,SetHeight=function() end,
            EnableKeyboard=function(self,enabled) self.keyboardEnabled=enabled end}
    end
    local originalCreate=CreateFrame
    CreateFrame=function() return uiFrame() end
    local text=uiFrame()
    text.value="before"
    function text:GetText() return self.value end
    function text:SetText(value)
        self.value=value
        if self.scripts.OnTextChanged then getfenv(0).this=self; self.scripts.OnTextChanged() end
    end
    function text:GetScript(key) return self.scripts[key] end
    function text:SetFocus() self.focused=true end
    function text:ClearFocus() error("native keyboard must preserve physical focus") end
    local physicalTextEvents=0
    text:SetScript("OnTextChanged",function() physicalTextEvents=physicalTextEvents+1 end)
    keyboard.frame=uiFrame()
    keyboard.fakeEditBox=uiFrame()
    keyboard.fakeEditBox.SetText=function(self,value) self.value=value end
    keyboard:Show(text)
    assert(text.keyboardEnabled and text.focused and keyboard.frame.keyboardEnabled==false,
        "virtual keyboard must retain physical typing and never capture keys")
    text:SetText("typed with physical keyboard")
    assert(keyboard.currentText==text.value and keyboard.fakeEditBox.value==text.value and physicalTextEvents==1,
        "physical typing must synchronize virtual text and chain original text script")
    keyboard:Show(text)
    text:SetText("typed again")
    assert(physicalTextEvents==2 and keyboard.currentText=="typed again","showing twice must not duplicate text hooks")
    controller.paused=false; controller.lastError=nil; controller.armed=true; controller.dispatchRefused=false
    controller.world=true; controller.connected=true; controller.foreground=true
    controller.sample={4096,0,0,0.75,-0.25,0,0}
    controller:UpdateStatus()
    assert(controller.statusText.shown and string.find(controller.statusText.text,"Ready %- virtual keyboard") and
        string.find(controller.statusText.text,"Buttons 1000") and string.find(controller.statusText.text,"Left 0.75,%-0.25"),
        "visible diagnostic must show real input values and virtual keyboard readiness")
    controller.foreground=false
    controller:UpdateStatus()
    assert(string.find(controller.statusText.text,"Game not focused"),"visible diagnostic must identify focus gating")
    CreateFrame=originalCreate
    print("PASS: actual CE virtual keyboard preserves physical focus and synchronizes typed text.")
    print("PASS: CE virtual binding initialization, cursor contexts, restore, and keyboard preservation.")
end
print("PASS: Lua 5.0 input safety, neutral gates, movement, camera/pointer, action pages, typing, and reconnect tests.")



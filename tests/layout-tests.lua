-- Real addon layout, circular state feedback, and chat lifecycle under Lua 5.0.
local root=assert(arg[1])
local model=assert(loadfile("tests/ui-model.lua"))()
local create=model.Create
function model:Create(kind,name,parent,template)
    local f=create(self,kind,name,parent,template)
    function f:GetCenter() return self:GetLeft()+self:GetWidth()/2,self:GetBottom()+self:GetHeight()/2 end
    function f:GetTexture() return self.texture and self.texture[1] end
    function f:SetTexCoord(...) self.uv=arg end
    function f:SetDrawLayer(layer) self.layer=layer end
    function f:SetParent(parent) self.parent=parent end
    function f:SetFrameLevel(level) self.level=level end
    function f:GetFrameLevel() return self.level or 1 end
    function f:SetFrameStrata(strata) self.strata=strata end
    function f:GetFrameStrata() return self.strata or "BACKGROUND" end
    function f:GetAlpha() return self.alpha end
    function f:GetID() return self.id or 0 end
    function f:SetID(id) self.id=id end
    function f:GetNumPoints() local n=0; for _ in pairs(self.points) do n=n+1 end; return n end
    function f:GetPoint(index) local n=0; for point,spec in pairs(self.points) do n=n+1; if n==index then return point,unpack(spec) end end end
    function f:EnableMouse(enabled) self.mouse=enabled end
    function f:GetHighlightTexture() return self.highlight end
    function f:GetPushedTexture() return self.pushed end
    function f:GetCheckedTexture() return self.checkedTexture end
    function f:SetCheckedTexture(value)
        if type(value)=="string" then self.checkedTexture=self:CreateTexture(nil,"ARTWORK"); self.checkedTexture:SetTexture(value)
        else self.checkedTexture=value end
    end
    for _,method in ipairs({"RegisterForDrag","RegisterForClicks","StartMoving","StopMovingOrSizing","Raise","SetFading","SetFadeDuration","ScrollToBottom","UnregisterAllEvents"}) do
        f[method]=function() end
    end
    if kind=="CheckButton" then
        f.highlight=f:CreateTexture(nil,"HIGHLIGHT")
        f.pushed=f:CreateTexture(nil,"ARTWORK")
        f.checkedTexture=f:CreateTexture(nil,"ARTWORK")
    end
    return f
end
CreateFrame=function(...) return model:Create(unpack(arg)) end
getfenv(0)._G=getfenv(0)
getglobal=function(name) return getfenv(0)[name] end
UIParent=CreateFrame("Frame","UIParent"); UIParent:SetWidth(1920); UIParent:SetHeight(1080)
GameMenuFrame=CreateFrame("Frame","GameMenuFrame",UIParent)
ConsoleExperience={}; WindrunnerExperienceDB={config={}}; SlashCmdList={}; StaticPopupDialogs={}; UISpecialFrames={}
CE_Debug=function() end; PlaySound=function() end; tinsert=table.insert
UnitClass=function() return "Warrior","WARRIOR" end; UnitName=function() return "Player" end
local combatState=0; UnitAffectingCombat=function() return combatState end
RAID_CLASS_COLORS={WARRIOR={r=0.78,g=0.61,b=0.43}}
GetLocale=function() return arg[3] or "enUS" end
GetBonusBarOffset=function() return 0 end
IsShiftKeyDown=function() return false end; IsControlKeyDown=function() return false end
GetNumPartyMembers=function() return 0 end; GetNumRaidMembers=function() return 0 end
GetActionTexture=function(slot) return "Interface\\Icons\\Ability" .. slot end
GetActionText=function() return "Ability" end; HasAction=function() return true end
GetActionCount=function() return 1 end; ActionHasRange=function() return false end
IsConsumableAction=function() return false end; IsStackableAction=function() return false end
IsCurrentAction=function() return false end; IsAutoRepeatAction=function() return false end
IsEquippedAction=function() return false end; IsUsableAction=function() return true end
IsAttackAction=function() return false end; GetActionCooldown=function() return 0,0,0 end
CooldownFrame_SetTimer=function() end; GetTime=function() return 100 end
GameTooltip={IsOwned=function() return false end,Hide=function() end}
FCF_SetWindowColor=function() end; FCF_SetWindowAlpha=function() end
NUM_CHAT_WINDOWS=1; UIParent_ManageFramePositions=function() end
SetPortraitToTexture=function(texture,path) texture.portrait=path end
local function load(path) assert(loadfile(root .. "/" .. path))() end
load("locale/locale.lua"); load("locale/translations_enUS.lua"); load("locale/translations_deDE.lua")
load("ui/theme.lua"); load("actionbars/bars.lua"); load("actionbars/skin.lua"); load("config/config.lua")
for i=1,10 do
    local name="ConsoleActionButton" .. i
    local button=CreateFrame("CheckButton",name,UIParent); button:SetID(i); button:SetWidth(60); button:SetHeight(60)
    for _,part in ipairs({"Icon","Background","NormalTexture","Flash","ControllerIcon"}) do button:CreateTexture(name .. part,"ARTWORK") end
    button:CreateFontString(name .. "Count","OVERLAY")
    CreateFrame("Model",name .. "Cooldown",button)
end
ChatFrame1=CreateFrame("Frame","ChatFrame1",UIParent)
ChatFrame1:SetWidth(400); ChatFrame1:SetHeight(150); ChatFrame1:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",25,40)
ChatFrame1Tab=CreateFrame("Button","ChatFrame1Tab",UIParent)
ChatFrame2=CreateFrame("Frame","ChatFrame2",UIParent); ChatFrame2:Hide()
ChatFrame2Tab=CreateFrame("Button","ChatFrame2Tab",UIParent); ChatFrame2Tab:Hide()
ChatFrameEditBox=CreateFrame("EditBox","ChatFrameEditBox",UIParent); ChatFrameEditBox:Hide()
load("chat/chat.lua"); load("ui/layout.lua")
local config,bars,chat,layout=ConsoleExperience.config,ConsoleExperience.actionbars,ConsoleExperience.chat,ConsoleExperience.layout
local function close(a,b) assert(math.abs(a-b)<0.01,tostring(a).." ~= "..tostring(b)) end
config:UpdateActionBarLayout(); chat:Initialize()
assert(config:Get("barAppearance")=="modern")
bars:UpdateButton(ConsoleActionButton2)
assert(ConsoleActionButton2Icon.portrait=="Interface\\Icons\\Ability2","real action updates must keep circular masking")
assert(ConsoleActionButton2Icon.uv[1]==0 and ConsoleActionButton2Icon.uv[2]==1,"cropping must not remove the portrait mask")
assert(string.find(ConsoleActionButton2.highlight.texture[1],"radial\\ring",1,true))
assert(ConsoleActionButton2ControllerIcon.points.CENTER[2]=="TOP","reference symbols belong above the icon")
local glyph=ConsoleActionButton2ControllerIcon
assert(string.find(glyph:GetTexture(),"controller-labels\\xbox\\x",1,true),"new profiles default to bare controller symbols")
local savedSize=ConsoleActionButton2:GetWidth()
local savedAnchor=ConsoleActionButton2.points.CENTER
bars:ApplyControllerLabelPreset("badges")
assert(bars:GetControllerLabelPreset()=="badges" and glyph:GetWidth()==30)
assert(string.find(glyph:GetTexture(),"controllers\\xbox\\x",1,true),"round-badge preset must preserve the existing artwork")
assert(glyph.points.CENTER[4]==-13,"round badges retain their existing position on the upper rim")
config:Set("barLabelSize",26); config:Set("barLabelAnchor","LEFT"); config:Set("barLabelX",-11); config:Set("barLabelY",9)
assert(glyph:GetWidth()==26 and glyph.points.CENTER[2]=="LEFT" and glyph.points.CENTER[3]==-11 and glyph.points.CENTER[4]==9)
assert(bars:GetControllerLabelPreset()=="custom")
assert(ConsoleActionButton2:GetWidth()==savedSize,"label resizing must not resize action buttons")
close(ConsoleActionButton2.points.CENTER[3],savedAnchor[3]); close(ConsoleActionButton2.points.CENTER[4],savedAnchor[4])
config:Set("barLabelEnabled",false); bars:UpdateButton(ConsoleActionButton2)
assert(not glyph:IsShown() and ConsoleActionButton2:IsShown(),"hidden labels must stay hidden after action updates without disabling buttons")
config:Set("barLabelEnabled",true); config:Set("barLabelBackground",false)
config:Set("controllerType","ps"); bars:UpdateButton(ConsoleActionButton2)
assert(glyph:IsShown() and string.find(glyph:GetTexture(),"controller-labels\\ps\\x",1,true),"bare symbols must follow the selected controller type")
config:Set("controllerType","xbox")
bars:ApplyControllerLabelPreset("reference")
assert(bars:GetControllerLabelPreset()=="reference" and glyph:GetWidth()==18)
-- Large labels moved outside a button still belong to its fitted cluster.
local bounds=bars:GetControllerLabelBounds(60)
close(bounds.maxY,45)
config:Set("barLabelSize",48); config:Set("barLabelAnchor","RIGHT"); config:Set("barLabelX",80); config:Set("barLabelY",80)
bounds=bars:GetControllerLabelBounds(60)
assert(bounds.maxX==134 and bounds.maxY==104)
UIParent:SetWidth(800); UIParent:SetHeight(600); config:Set("barScale",2); config:Set("barYOffset",500); config:Set("barXOffset",1000)
config:Set("barIndependent",true); config:UpdateActionBarLayout()
local fitted=layout.mainGeometry
for _,position in ipairs(fitted.buttons) do
    assert(400+position.x+bounds.minX*fitted.scale>=11.9 and 400+position.x+bounds.maxX*fitted.scale<=788.1,"moved labels must fit horizontally")
    assert(position.y+bounds.minY*fitted.scale>=11.9 and position.y+bounds.maxY*fitted.scale<=540.1,"moved labels must fit vertically")
end
UIParent:SetWidth(1920); UIParent:SetHeight(1080); config:Set("barIndependent",false)
config:Set("barScale",1); config:Set("barXOffset",0); config:Set("barYOffset",70)
bars:ApplyControllerLabelPreset("reference")
bars:StartCircularCooldown(ConsoleActionButton2,95,10)
assert(string.find(ConsoleActionButton2.circularCooldown.shade.texture[1],"radial\\disc",1,true),"cooldown shading must also be round")
assert(tonumber(ConsoleActionButton2.circularCooldown.text:GetText())==5)
ConsoleActionButton2Icon:SetVertexColor(1,0.1,0.1,1)
bars:UpdateCircularCooldown(ConsoleActionButton2.circularCooldown)
assert(ConsoleActionButton2Icon.vertex[2]==0.1,"cooldown shading must preserve range tint")
config:Set("barAppearance","classic"); bars:ApplyButtonAppearance(ConsoleActionButton2)
assert(ConsoleActionButton2Icon.texture[1]=="Interface\\Icons\\Ability2","switching to Classic must restore the original full icon")
assert(ConsoleActionButton2.circularCooldown.shade.texture[1]=="Interface\\Buttons\\WHITE8X8")
config:Set("barAppearance","modern")
config:Set("barXOffset",110); config:Set("barYOffset",380); config:Set("barScale",0.6)
config:UpdateActionBarLayout()
local g=layout.mainGeometry
close(g.x,110); close(g.y,380)
for _,position in ipairs(g.buttons) do
    local button=getglobal("ConsoleActionButton"..position.id)
    local anchor=button.points.CENTER
    close(anchor[3]*button:GetScale(),g.x+position.x)
    close(anchor[4]*button:GetScale(),g.y+position.y)
end
-- Fitting a smaller game window keeps actual button rectangles on screen.
config:Set("barButtonSize",80); config:Set("barScale",2); config:Set("barStarPadding",950)
UIParent:SetWidth(800); UIParent:SetHeight(600); layout:Refresh()
g=layout.mainGeometry
assert(g.x-g.width/2>=-388.01 and g.x+g.width/2<=388.01,"small-screen horizontal bounds")
assert(g.bottom>=12 and g.bottom+g.height<=540)
UIParent:SetWidth(1920); UIParent:SetHeight(1080)
config:Set("barButtonSize",60); config:Set("barScale",1); config:Set("barStarPadding",430)
config:Set("barYOffset",70); config:Set("barXOffset",0); layout:Refresh()
local c=chat:GetIdleGeometry(); g=layout.mainGeometry
assert(g.bottom>=c.y+c.height+8,"visible chat and occupied ability circles must not overlap")
config:Set("chatBottomY",750); layout:Refresh(); c=chat:GetIdleGeometry(); g=layout.mainGeometry
assert(g.bottom+g.height<c.y,"upper chat positions must leave the action bars below them")
config:Set("chatBottomY",20)
-- Hidden chat never disables the observer or loses Enter-to-open behavior.
config:Set("chatVisibility","typing"); layout:Refresh()
assert(not ChatFrame1:IsShown() and not ChatFrame1Tab:IsShown() and not chat.oskHelper.mouse)
assert(chat.oskHelper:IsShown(),"input observer must continue while chat is hidden")
NUM_CHAT_WINDOWS=2; ChatFrame2:Show(); ChatFrame2Tab:Show(); chat:UpdateVisibility()
assert(not ChatFrame2:IsShown() and not ChatFrame2Tab:IsShown(),"typing-only mode also hides other chat windows")
config:Set("keyboardEnabled",false); config:Set("chatXOffset",300); config:Set("chatBottomY",180)
ChatFrameEditBox:Show(); model:Invoke(chat.oskHelper,"OnUpdate",0.05)
assert(ChatFrame1:IsShown() and chat.oskHelper.state==1)
assert(ChatFrame2:IsShown() and ChatFrame2Tab:IsShown(),"typing restores only the previously visible extra chat windows")
c=chat:GetIdleGeometry(); close(ChatFrame1.points.BOTTOMLEFT[3],c.x-c.width/2)
close(ChatFrameEditBox.points.BOTTOM[3]*ChatFrameEditBox:GetScale(),c.x)
ChatFrameEditBox:Hide(); model:Invoke(chat.oskHelper,"OnUpdate",0.05)
assert(not ChatFrame1:IsShown() and chat.oskHelper.state==0)
local keyboardShown=0
ConsoleExperience.keyboard={GetPreferredHeight=function() return 220 end,IsVisible=function() return false end,
    Show=function() keyboardShown=keyboardShown+1 end,Hide=function() end}
config:Set("keyboardEnabled",true); ChatFrameEditBox:Show(); model:Invoke(chat.oskHelper,"OnUpdate",0.05)
assert(keyboardShown==1 and ChatFrame1.points.BOTTOMLEFT[2]=="BOTTOMLEFT","virtual keyboard retains the wide focused layout")
ChatFrameEditBox:Hide(); model:Invoke(chat.oskHelper,"OnUpdate",0.05)
close(ChatFrame1.points.BOTTOMLEFT[3],c.x-c.width/2)
-- Retain coverage for the legacy linked layout, which old profiles can still load.
local function startLegacy()
    layout:Start()
    config:Set("barIndependent",false); config:Set("hudIndependent",false)
    layout:Refresh(); layout:SelectTarget("bars")
end
-- Edit mode reveals hidden chat; drag stop saves UI coordinates, not scaled offsets.
local priorControls=ConsoleExperience.controllerControls
ConsoleExperience.controllerControls={GetPromptLabel=function(_,name)
    return ({X="Square",A="Cross",B="Circle"})[name] or name
end}
local configFrame=config.frame or CreateFrame("Frame","LayoutTestConfig",UIParent)
config.frame=configFrame; configFrame:Show()
startLegacy(); assert(layout.active and ChatFrame1:IsShown())
assert(not configFrame:IsShown(),"opening layout hides the settings panel")
assert(string.find(layout.doneButton:GetText(),"Square",1,true),"finish button uses the configured physical prompt label")
assert(string.find(layout.moveStatus:GetText(),"Cross",1,true) and string.find(layout.moveStatus:GetText(),"Circle",1,true)
    and string.find(layout.moveStatus:GetText(),"selects",1,true) and string.find(layout.moveStatus:GetText(),"back",1,true),
    "idle layout hints expose target selection and Back prompt labels")
assert(layout:HandleInput(2) and not layout:IsVisible() and configFrame:IsShown(),"slot two saves and returns to the settings panel")
startLegacy()
assert(layout:Back() and not layout:IsVisible() and configFrame:IsShown(),"idle Back returns to the settings panel")
configFrame:Hide()
startLegacy()
assert(layout:IsVisible() and layout.targetButtons.bars:IsShown() and layout.targetButtons.chat:IsShown(),
    "layout editor exposes controller-focusable target buttons")
assert(layout.frame.ceNavigationModal,"layout editor confines controller focus to its controls")
assert(not layout:IsMoving() and not layout.targetButtons.mainleft:IsShown(),
    "cluster layout offers the combined bar target only")
local originalBarX=config:Get("barXOffset")
-- A label shifted to one side must not shift the bar when its mover is saved.
local savedLabelBarY=config:Get("barYOffset")
config:Set("barLabelSize",48); config:Set("barLabelAnchor","RIGHT"); config:Set("barLabelX",80)
layout:Refresh()
local labelGeometry=layout.mainGeometry
local labelMover=layout.handles.bars
local labelCenterX,labelCenterY=labelMover:GetCenter()
close(labelCenterX,UIParent:GetWidth()/2+labelGeometry.x+labelGeometry.centerOffsetX)
local labelMoverGetCenter=labelMover.GetCenter
labelMover.GetCenter=function() return labelCenterX,labelCenterY end
model:Invoke(labelMover,"OnDragStop")
close(config:Get("barXOffset"),labelGeometry.x); close(config:Get("barYOffset"),labelGeometry.y)
assert(layout:MoveTargetBy("bars",10,0))
close(config:Get("barXOffset"),labelGeometry.x+10)
labelMover.GetCenter=labelMoverGetCenter
config:Set("barXOffset",originalBarX); config:Set("barYOffset",savedLabelBarY)
bars:ApplyControllerLabelPreset("reference"); layout:Refresh()
model:Invoke(layout.targetButtons.bars,"OnClick")
assert(layout:IsMoving(),"cursor-selecting a target enters controller move mode")
assert(layout:HandleDirection("right"),"D-pad directions nudge the selected target")
close(config:Get("barXOffset"),originalBarX+10)
local originalMoveSnapshot=layout.moveSnapshot
model:Invoke(layout.targetButtons.bars,"OnClick")
assert(layout.moveSnapshot==originalMoveSnapshot,"selecting the moving target again preserves the cancel baseline")
assert(layout:Back() and not layout:IsMoving() and layout:IsVisible(),"Back cancels an unconfirmed move and keeps the editor open")
close(config:Get("barXOffset"),originalBarX)
assert(layout:Back() and not layout:IsVisible(),"a second Back closes the idle editor")
startLegacy()
model:Invoke(layout.nudgeButtons.left,"OnClick")
close(config:Get("barXOffset"),originalBarX-layout.moveStep)
model:Invoke(layout.nudgeButtons.right,"OnClick")
close(config:Get("barXOffset"),originalBarX)
assert(layout:BeginMove("bars") and layout:HandleInput(6),"logical left slot is consumed as a nudge")
close(config:Get("barXOffset"),originalBarX-layout.moveStep)
assert(layout:HandleInput(8),"logical right slot is consumed as a nudge")
close(config:Get("barXOffset"),originalBarX)
assert(layout:ConfirmMove())
assert(layout:BeginMove("bars")); layout:CycleMoveStep()
assert(layout:HandleInput(8),"native right action slot is consumed as a nudge while moving")
close(config:Get("barXOffset"),originalBarX+25)
assert(layout:HandleInput(1) and not layout:IsMoving(),"confirm commits the controller move")
close(config:Get("barXOffset"),originalBarX+25)
config:Set("barXOffset",originalBarX); config:UpdateActionBarLayout()
config:Set("barXOffset",5000); config:UpdateActionBarLayout(); layout:Refresh()
assert(layout:BeginMove("bars") and layout:HandleDirection("right"),"edge target remains nudgeable")
local boundedX=layout.handles.bars:GetCenter()
assert(boundedX+layout.handles.bars:GetWidth()/2<=UIParent:GetWidth()+0.01,"controller nudges clamp handles inside the screen")
assert(layout:CancelMove()); config:Set("barXOffset",originalBarX); config:UpdateActionBarLayout()
local strataOrder={BACKGROUND=1,LOW=2,MEDIUM=3,HIGH=4,DIALOG=5,FULLSCREEN=6,FULLSCREEN_DIALOG=7,TOOLTIP=8}
for _,mover in pairs(layout.handles) do
    assert(strataOrder[mover:GetFrameStrata()]>strataOrder.HIGH,"movers must receive mouse input above HIGH action bars")
end
assert(strataOrder[layout.frame:GetFrameStrata()]>=strataOrder[layout.handles.chat:GetFrameStrata()],"layout controls must remain above moved panels")
local handle=layout.handles.chat
handle.GetCenter=function() return 1260,460 end
model:Invoke(handle,"OnDragStop")
close(config:Get("chatXOffset"),300); close(config:Get("chatBottomY"),385)
handle=layout.handles.bars
handle.GetCenter=function() return 1060,450 end
model:Invoke(handle,"OnDragStop")
close(config:Get("barXOffset"),100)
close(config:Get("barYOffset"),math.floor(450-layout.mainGeometry.glyph/2+0.5))

-- Done commits an active move, while Reset discards the move snapshot so a
-- later Back cannot restore pre-reset coordinates.
assert(layout:BeginMove("bars") and layout:MoveSelected("right"))
local doneBarX=config:Get("barXOffset")
model:Invoke(getglobal("CELayoutDone"),"OnClick")
assert(not layout:IsVisible() and not layout:IsMoving(),"Done saves an active move and closes the editor")
close(config:Get("barXOffset"),doneBarX)
local positionKeys={"barXOffset","barYOffset","barLeftX","barLeftY","barRightX","barRightY",
    "petBarX","petBarY","chatXOffset","chatBottomY","sideBarLeftX","sideBarLeftY","sideBarRightX","sideBarRightY"}
local savedPositions={}
for _,key in ipairs(positionKeys) do savedPositions[key]=config:Get(key) end
startLegacy()
assert(layout:BeginMove("bars") and layout:MoveSelected("right"))
model:Invoke(getglobal("CELayoutReset"),"OnClick")
assert(not layout:IsMoving(),"Reset clears the active movement snapshot")
local defaultBarX=config:Get("barXOffset")
assert(defaultBarX==config.DEFAULTS.barXOffset,"Reset applies the configured default")
assert(layout:Back() and not layout:IsVisible(),"Back closes after Reset")
close(config:Get("barXOffset"),defaultBarX)
for _,key in ipairs(positionKeys) do config:Set(key,savedPositions[key]) end
config:UpdateActionBarLayout(); startLegacy()

-- Vanilla's UIParent center can differ from half its reported width. Nudge
-- offsets from current geometry, and mouse saves, must use the actual center.
local oldCenter=UIParent.GetCenter
local oldGetCenter=layout.handles.bars.GetCenter
local oldScreenW,oldScreenH=UIParent:GetWidth(),UIParent:GetHeight()
local oldBarX,oldBarY=config:Get("barXOffset"),config:Get("barYOffset")
UIParent:SetWidth(1365.3334); UIParent:SetHeight(768)
UIParent.GetCenter=function() return 720,405 end
layout:Refresh()
local barsHandle=layout.handles.bars
barsHandle.GetCenter=function() return 952,405 end
assert(layout:BeginMove("bars") and layout:HandleDirection("left"))
close(config:Get("barXOffset"),oldBarX-layout.moveStep)
assert(layout:HandleDirection("right")); close(config:Get("barXOffset"),oldBarX)
assert(layout:ConfirmMove())
local liveGeometry=layout.mainGeometry
-- Drag callbacks receive the actual screen-space center: 760 is the parent
-- center (720) plus the desired saved bar offset (40).
barsHandle.GetCenter=function() return 760,liveGeometry.y+liveGeometry.glyph/2 end
model:Invoke(barsHandle,"OnDragStop")
close(config:Get("barXOffset"),40)
close(config:Get("barYOffset"),liveGeometry.y)
barsHandle.GetCenter=oldGetCenter
UIParent.GetCenter=oldCenter
UIParent:SetWidth(oldScreenW); UIParent:SetHeight(oldScreenH)
config:Set("barXOffset",oldBarX); config:Set("barYOffset",oldBarY)
layout:Refresh()
layout:Stop(); assert(not layout.active and not ChatFrame1:IsShown() and not layout.handles.bars:IsShown())
ConsoleExperience.controllerControls=priorControls
-- Touch bars share size, but keep their independently saved anchors.
config:Set("sideBarLeftEnabled",true); config:Set("sideBarLeftX",200); config:Set("sideBarLeftY",120)
config:Set("barScale",0.5); bars:UpdateSideBars()
local side=bars.sideBarLeftFrame
close(side.points.CENTER[3],12+side:GetWidth()/2+200); close(side.points.CENTER[4],660)
assert(bars.sideBarLeftButtons[1].icon.portrait,"touchbar action updates must also keep the mask")
-- XP, reputation, and cast bars track the same moved idle anchor.
FACTION_STANDING_INCREASED="Reputation with %s increased by %d."
load("xpbar/xpbar.lua"); load("castbar/castbar.lua")
local xp,cast=ConsoleExperience.xpbar,ConsoleExperience.castbar
xp.xpBar=CreateFrame("Frame","TestXP",UIParent); xp.xpBar.barType="XP"
xp.repBar=CreateFrame("Frame","TestREP",UIParent); xp.repBar.barType="REP"
cast.castBar=CreateFrame("Frame","TestCast",UIParent)
xp:UpdateAllBars(); cast:UpdatePosition(); c=chat:GetIdleGeometry()
close(xp.xpBar.points.BOTTOM[3],c.x); close(xp.repBar.points.BOTTOM[3],c.x)
close(xp.repBar.points.BOTTOM[4],c.baseY)
close(xp.xpBar.points.BOTTOM[4],c.baseY+xp.repBar.height+2)
close(cast.castBar.points.BOTTOMLEFT[3],c.x-c.width/2)
close(cast.castBar.points.BOTTOMLEFT[4],c.y+c.height+5)
ChatFrameEditBox:Show(); model:Invoke(chat.oskHelper,"OnUpdate",0.05)
xp:UpdateAllBars()
assert(ChatFrame1.points.BOTTOMLEFT[2]=="BOTTOMLEFT","progress updates must preserve the focused keyboard layout")
ConsoleExperience.keyboard.IsVisible=function() return true end
local countBeforeResize=keyboardShown
UIParent:SetWidth(800); UIParent:SetHeight(600); layout:Refresh()
assert(keyboardShown==countBeforeResize+1,"resizing while typing must reflow the visible virtual keyboard")
assert(ChatFrameEditBox:GetWidth()*ChatFrameEditBox:GetScale()<=768)
UIParent:SetWidth(1920); UIParent:SetHeight(1080)
ChatFrameEditBox:Hide(); model:Invoke(chat.oskHelper,"OnUpdate",0.05)
chat:Disable()
assert(ChatFrame1:IsShown() and ChatFrame1Tab:IsShown() and not chat.oskHelper:IsShown(),"disabling managed chat must restore visible stock chat")
close(ChatFrame1.points.BOTTOMLEFT[3],25); close(ChatFrame1.points.BOTTOMLEFT[4],40)

-- Independent groups support all presets and preserve button anchors in
-- UIParent coordinates after applying the common scale.
local function positionById(geometry,id)
    for _,position in ipairs(geometry.buttons) do if position.id==id then return position end end
end
local function assertAnchors(geometry)
    for _,position in ipairs(geometry.buttons) do
        local button=getglobal("ConsoleActionButton"..position.id)
        close(button.points.CENTER[3]*button:GetScale(),position.x)
        close(button.points.CENTER[4]*button:GetScale(),position.y)
    end
end
UIParent:SetWidth(1920); UIParent:SetHeight(1080)
config:Set("barIndependent",true); config:Set("barLayout","clusters")
config:Set("barButtonSize",60); config:Set("barPadding",68); config:Set("barScale",1)
config:Set("barStarPadding",520); config:Set("barXOffset",-24); config:Set("barYOffset",360)
config:Set("barLeftX",-55); config:Set("barLeftY",35); config:Set("barRightX",72); config:Set("barRightY",-28)
config:UpdateActionBarLayout(); g=layout.mainGeometry
assert(g.independent and g.groups.left and g.groups.right,"independent cluster layout exposes two groups")
local left8,right2=positionById(g,8),positionById(g,2)
close(left8.x,g.centers.left.x+g.padding)
close(right2.x,g.centers.right.x-g.padding)
assert(left8.x~=right2.x,"independent action clusters remain separated")
assertAnchors(g)

config:Set("barLayout","horizontal"); config:Set("barIndependent",false)
config:UpdateActionBarLayout(); g=layout.mainGeometry
assert(g.independent,"horizontal layout selects independent geometry even when the checkbox is off")
local horizontal={left={6,7,10,5,8},right={2,3,9,1,4}}
for side,ids in pairs(horizontal) do
    for index,id in ipairs(ids) do
        local position=positionById(g,id)
        close(position.x,g.centers[side].x+(index-3)*g.padding)
        close(position.y,g.centers[side].y)
    end
end
assertAnchors(g)

config:Set("barLayout","crossbar"); config:Set("barIndependent",false)
config:UpdateActionBarLayout(); g=layout.mainGeometry
assert(g.independent,"crossbar uses independent groups")
local crossbar={[6]={-2,0},[7]={-1,0.55},[5]={-1,-0.55},[8]={0,0},[10]={1,0},
    [9]={-1,0},[2]={0,0},[3]={1,0.55},[1]={1,-0.55},[4]={2,0}}
for id,offset in pairs(crossbar) do
    local position=positionById(g,id)
    local side
    if id==6 or id==7 or id==5 or id==8 or id==10 then side="left" else side="right" end
    close(position.x,g.centers[side].x+offset[1]*g.padding)
    close(position.y,g.centers[side].y+offset[2]*g.padding)
end
assertAnchors(g)

-- Oversized controls, requested scale, and extreme offsets fit the actual
-- window instead of escaping the viewport.
config:Set("barLayout","crossbar"); config:Set("barIndependent",true)
config:Set("barButtonSize",160); config:Set("barPadding",300); config:Set("barScale",2)
config:Set("barStarPadding",2000); config:Set("barXOffset",2000); config:Set("barYOffset",2000)
config:Set("barLeftX",-2000); config:Set("barLeftY",2000); config:Set("barRightX",2000); config:Set("barRightY",-2000)
UIParent:SetWidth(640); UIParent:SetHeight(480); config:UpdateActionBarLayout(); g=layout.mainGeometry
assert(g.scale>0 and g.scale<2,"independent large controls downscale to fit")
for _,position in ipairs(g.buttons) do
    local half=160*g.scale/2
    assert(position.x-half>=-640/2+11 and position.x+half<=640/2-11,"large independent action remains horizontally visible")
    assert(position.y-half>=11 and position.y+half+18*g.scale<=480-59,"large independent action and label remain vertically visible")
end
assertAnchors(g)

-- Restore a roomy window for mover tests and exercise actual save->refresh
-- round trips for both independent groups and the scaled pet bar's bottom.
UIParent:SetWidth(1920); UIParent:SetHeight(1080)
config:Set("barButtonSize",60); config:Set("barPadding",68); config:Set("barScale",1)
config:Set("barStarPadding",520); config:Set("barXOffset",0); config:Set("barYOffset",360)
config:Set("barLeftX",-40); config:Set("barLeftY",20); config:Set("barRightX",40); config:Set("barRightY",-20)
config:Set("barLayout","clusters"); config:Set("barIndependent",true)
config:Set("barVisibility","always"); layout.active=false
config:UpdateActionBarLayout(); g=layout.mainGeometry; layout:Start()
assert(layout.targetButtons.mainleft:IsShown() and layout.targetButtons.mainright:IsShown()
    and not layout.targetButtons.bars:IsShown(),"independent layouts expose both reachable bar targets")
assert(layout.targetButtons.Left:IsShown() and not layout.targetButtons.Right:IsShown(),
    "only enabled touch bars appear as controller targets")
assert(not layout:SelectTarget("bars"),"unavailable combined bar target cannot be selected")
local originalTouchX=config:Get("sideBarLeftX")
assert(layout:BeginMove("Left") and layout:HandleDirection("right"))
close(config:Get("sideBarLeftX"),originalTouchX+layout.moveStep)
assert(layout:CancelMove()); close(config:Get("sideBarLeftX"),originalTouchX)
assert(layout:BeginMove("mainleft") and layout:HandleDirection("up"))
close(config:Get("barLeftY"),20+layout.moveStep)
assert(layout:CancelMove()); close(config:Get("barLeftX"),-40); close(config:Get("barLeftY"),20)
assert(layout:BeginMove("mainleft")); layout:MoveSelected("up"); assert(layout:ConfirmMove())
close(config:Get("barLeftY"),20+layout.moveStep)
config:Set("barLeftY",20); config:UpdateActionBarLayout()
local leftMover=layout.handles.mainleft
local leftCenter=g.groups.left
local desiredGroupX=UIParent:GetWidth()/2+leftCenter.x+125
local desiredGroupY=leftCenter.y+64
local originalGetCenter=leftMover.GetCenter
leftMover.GetCenter=function() return desiredGroupX,desiredGroupY end
model:Invoke(leftMover,"OnDragStop")
leftMover.GetCenter=originalGetCenter
close(config:Get("barLeftX"),-40+125); close(config:Get("barLeftY"),20+64)
g=layout.mainGeometry
close(g.groups.left.x,leftCenter.x+125); close(g.groups.left.y,leftCenter.y+64)
local actualGroupX,actualGroupY=leftMover:GetCenter()
close(actualGroupX,desiredGroupX); close(actualGroupY,desiredGroupY)
local rightMover=layout.handles.mainright
local rightCenter=g.groups.right
local desiredRightX=UIParent:GetWidth()/2+rightCenter.x-85
local desiredRightY=rightCenter.y-32
originalGetCenter=rightMover.GetCenter
rightMover.GetCenter=function() return desiredRightX,desiredRightY end
model:Invoke(rightMover,"OnDragStop")
rightMover.GetCenter=originalGetCenter
close(config:Get("barRightX"),40-85); close(config:Get("barRightY"),-20-32)
g=layout.mainGeometry
close(g.groups.right.x,rightCenter.x-85); close(g.groups.right.y,rightCenter.y-32)
actualGroupX,actualGroupY=rightMover:GetCenter()
close(actualGroupX,desiredRightX); close(actualGroupY,desiredRightY)

local pet=CreateFrame("Frame","LayoutTestPetBar",UIParent)
pet:SetWidth(280); pet:SetHeight(48); pet:SetScale(0.75); pet:Show()
local function updatePetPosition()
    pet:ClearAllPoints()
    pet:SetPoint("BOTTOM",UIParent,"BOTTOM",config:Get("petBarX")/pet:GetScale(),config:Get("petBarY")/pet:GetScale())
end
function pet:GetCenter()
    local anchor=self.points.BOTTOM
    return UIParent:GetWidth()/2+anchor[3]*self:GetScale(),anchor[4]*self:GetScale()+self:GetHeight()*self:GetScale()/2
end
PetHasActionBar=function() return 1 end
ConsoleExperience.pet={frame=pet,UpdatePosition=updatePetPosition}
config:Set("petBarX",-240); config:Set("petBarY",170); updatePetPosition(); layout:Refresh()
assert(layout.targetButtons.pet:IsShown(),"a live pet action bar becomes a controller target")
local petMover=layout.handles.pet
petMover.GetCenter=function() return pet:GetCenter() end
assert(layout:BeginMove("pet") and layout:HandleDirection("right"))
close(config:Get("petBarX"),-240+layout.moveStep)
assert(layout:CancelMove()); close(config:Get("petBarX"),-240)
local effectivePetHeight=pet:GetHeight()*(pet:GetEffectiveScale()/UIParent:GetEffectiveScale())
local desiredPetX=UIParent:GetWidth()/2+145
local desiredPetCenterY=295
local petGetCenter=petMover.GetCenter
petMover.GetCenter=function() return desiredPetX,desiredPetCenterY end
model:Invoke(petMover,"OnDragStop")
petMover.GetCenter=petGetCenter
close(config:Get("petBarX"),145)
close(config:Get("petBarY"),desiredPetCenterY-effectivePetHeight/2)
updatePetPosition()
local savedPetCenterX,savedPetCenterY=pet:GetCenter()
close(savedPetCenterX,desiredPetX); close(savedPetCenterY,desiredPetCenterY)
layout:Stop(); ConsoleExperience.pet=nil

local function center(frame,index)
    local x,y=frame:GetCenter(); if index==1 then return x else return y end
end
-- Opening the normal editor detaches every bar without moving the HUD.
config:Set("barIndependent",false); config:Set("hudIndependent",false)
config:Set("barLayout","clusters"); config:Set("barScale",1); config:Set("barVisibility","always")
layout:Refresh()
local xpBar,repBar,castBar=ConsoleExperience.xpbar.xpBar,ConsoleExperience.xpbar.repBar,ConsoleExperience.castbar.castBar
local xpX,xpY=xpBar:GetCenter(); local repX,repY=repBar:GetCenter(); local castX,castY=castBar:GetCenter()
local chatY=chat:GetIdleGeometry().y
layout:Start()
assert(config:Get("barIndependent") and config:Get("hudIndependent"),"the normal editor unlocks every element")
assert(not layout.targetButtons.bars:IsShown() and layout.targetButtons.mainleft:IsShown() and layout.targetButtons.mainright:IsShown())
assert(layout:IsTargetAvailable("xp") and layout:IsTargetAvailable("rep") and layout:IsTargetAvailable("cast"))
close(center(xpBar,1),xpX); close(center(xpBar,2),xpY)
close(center(repBar,1),repX); close(center(repBar,2),repY)
close(center(castBar,1),castX); close(center(castBar,2),castY)
close(chat:GetIdleGeometry().y,chatY)
local rightCenter=layout.mainGeometry.groups.right.x
assert(layout:BeginMove("mainleft") and layout:MoveSelected("right") and layout:ConfirmMove())
close(layout.mainGeometry.groups.right.x,rightCenter)
local originalXP=config:Get("xpBarX")
assert(layout:BeginMove("xp") and layout:MoveSelected("right"))
close(config:Get("xpBarX"),originalXP+layout.moveStep)
close(center(repBar,1),repX); close(center(castBar,1),castX)
assert(layout:CancelMove()); close(config:Get("xpBarX"),originalXP)
assert(layout:BeginMove("cast") and layout:MoveSelected("up") and layout:ConfirmMove())
local movedCastY=center(castBar,2)
close(movedCastY,castY+layout.moveStep)
assert(layout:BeginMove("chat") and layout:MoveSelected("right") and layout:ConfirmMove())
layout:Stop(); layout:Refresh()
close(center(xpBar,1),xpX); close(center(xpBar,2),xpY)
close(center(repBar,1),repX); close(center(castBar,2),movedCastY)
repBar:Hide(); ConsoleExperience.xpbar:UpdateAllBars()
close(center(xpBar,2),xpY)
assert(chat:GetIdleGeometry().reserve==0,"independent progress bars never push chat or one another")

-- Visibility policies normalize Vanilla's numeric 0/1 combat return values,
-- including both sidebars and the page indicator.
config:Set("sideBarLeftEnabled",true); config:Set("sideBarRightEnabled",true); bars:UpdateSideBars()
bars:CreatePageIndicator(); bars.pageIndicator:Show()
local updates=0; local oldUpdateAll=bars.UpdateAllButtons
bars.UpdateAllButtons=function(self) updates=updates+1; return oldUpdateAll(self) end
config:Set("barVisibility","combat"); combatState=0; layout.lastBarVisibility=nil; layout:UpdateVisibility()
assert(not ConsoleActionButton1:IsShown() and not bars.sideBarLeftFrame:IsShown() and not bars.sideBarRightFrame:IsShown(),"numeric zero combat hides all action groups")
assert(not bars.pageIndicator:IsShown(),"hidden bars also hide the page indicator")
local updatesAtHidden=updates; layout:UpdateVisibility()
assert(updates==updatesAtHidden,"unchanged visibility does not rebuild main action buttons")
combatState=1; layout:UpdateVisibility()
assert(ConsoleActionButton1:IsShown() and bars.sideBarLeftFrame:IsShown() and bars.sideBarRightFrame:IsShown(),"numeric one combat shows enabled action groups")
config:Set("barVisibility","idle"); combatState=0; layout.lastBarVisibility=nil; layout:UpdateVisibility()
assert(ConsoleActionButton1:IsShown(),"idle policy treats numeric zero as outside combat")
combatState=1; layout:UpdateVisibility()
assert(not ConsoleActionButton1:IsShown() and not bars.sideBarLeftFrame:IsShown(),"idle policy hides numeric one combat")
WindrunnerController={IsMenuActive=function() return true end}; layout:UpdateVisibility()
assert(ConsoleActionButton1:IsShown() and bars.sideBarLeftFrame:IsShown(),"active controller menu reveals bars during combat")
WindrunnerController=nil; config:Set("barVisibility","always"); layout.lastBarVisibility=nil; layout:UpdateVisibility()
bars.UpdateAllButtons=oldUpdateAll

if arg[2] then
    config:Set("chatVisibility","typing"); config:Set("barButtonSize",60); config:Set("barScale",1)
    config:Set("barIndependent",false); config:Set("barLayout","clusters")
    config:Set("barStarPadding",600); config:Set("barYOffset",160); config:Set("barXOffset",0)
    if arg[4] then config:Set("controllerType",arg[4]) end
    if arg[5] then bars:ApplyControllerLabelPreset(arg[5]) end
    layout:Refresh(); bars:UpdateAllButtons()
    local file=assert(io.open(arg[2],"w")); local g=layout.mainGeometry
    local options=bars:GetControllerLabelOptions()
    file:write(string.format('{"width":%g,"height":%g,"size":%g,"labelSize":%g,"labelAnchor":"%s","labelX":%g,"labelY":%g,"buttons":[',g.width,g.height,60*g.scale,options.size*g.scale,options.anchor,options.x*g.scale,options.y*g.scale))
    for i,button in ipairs(g.buttons) do
        if i>1 then file:write(',') end
        local path=string.gsub(getglobal("ConsoleActionButton"..button.id.."ControllerIcon"):GetTexture(),"\\","/")
        file:write(string.format('{"id":%d,"x":%g,"y":%g,"glyph":"%s"}',button.id,button.x,button.y,path))
    end
    file:write(']}'); file:close()
end
print("PASS: circular actions/cooldowns, cluster/crossbar/horizontal geometry, extreme fitting, mover round-trips, numeric combat visibility, chat/OSK lifecycle, touchbar positions, stock-chat restoration.")

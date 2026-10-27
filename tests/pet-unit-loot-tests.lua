local root=assert(arg[1],"addon root required")
local model=assert(loadfile("tests/ui-model.lua"))()
local nativeCreate=model.Create
CreateFrame=function(kind,name,parent,template)
    local frame=nativeCreate(model,kind,name,parent,template)
    local show,hide=frame.Show,frame.Hide
    function frame:Show()
        local was=self.shown; show(self)
        if not was and self.scripts.OnShow then model:Invoke(self,"OnShow") end
    end
    function frame:Hide()
        local was=self.shown; hide(self)
        if was and self.scripts.OnHide then model:Invoke(self,"OnHide") end
    end
    function frame:RegisterForClicks(...) self.clicks=arg end
    function frame:RegisterForDrag(...) self.drags=arg end
    function frame:RegisterEvent(event) self.events=self.events or {}; self.events[event]=true end
    function frame:SetID(value) self.id=value end
    function frame:GetID() return self.id end
    function frame:Click(button)
        if self:IsEnabled()==0 then return false end
        model:Invoke(self,"OnClick",button or "LeftButton"); return true
    end
    return frame
end
UIParent=CreateFrame("Frame","UIParent"); UIParent:SetWidth(1920); UIParent:SetHeight(1080)
getglobal=function(name) return getfenv(0)[name] end; getfenv(0)._G=getfenv(0)
UISpecialFrames={}; TEXT={}; LOCK_ACTIONBAR="0"
IsShiftKeyDown=function() return false end
SetPortraitToTexture=function(region,texture) region.portrait=texture end
CooldownFrame_SetTimer=function(frame,start,duration,enable) frame.cooldown={start,duration,enable} end
GameTooltip={SetOwner=function() end,SetPetAction=function(self,index) self.petAction=index end,Show=function() end,Hide=function() end}
local theme={registered={},buttons={}}
local petBarScale=1
function theme:Get(key)
    if key=="uiTextScale" then return 1.2 elseif key=="uiMenuScale" then return 1 elseif key=="barScale" then return 1 end
end
function theme:Register(frame,role) self.registered[frame]=role; return frame end
function theme:Button(button,text) self.buttons[button]=text end
function theme:Apply() end
local hooks={hides=0}
function hooks:HookDynamicFrame(frame)
    local old=frame:GetScript("OnHide")
    frame:SetScript("OnHide",function() if old then old() end; hooks.hides=hooks.hides+1 end)
end
local cursor={navigationState={currentButton=nil}}
function cursor:MoveCursorToButton(button)
    assert(button and type(button.label)=="string","focused navigation row must have a string label")
    self.navigationState.currentButton=button
end
function cursor:RefreshFrame() self.refreshes=(self.refreshes or 0)+1 end
function cursor:RefreshNavigationLock() end
ConsoleExperience={locale={T=function(text) return text end},theme=theme,hooks=hooks,cursor=cursor,
    config={Get=function(_,key) if key=="petBarX" then return 0 elseif key=="petBarY" then return 270 elseif key=="barScale" then return petBarScale end end}}
local function load(path) assert(loadfile(root.."/"..path))() end

-- Original 1.12 GetPetActionInfo tuple: name, subtext, texture, isToken,
-- active, autocast allowed, autocast enabled. Numeric 0 is false.
local petActions={
    [1]={"Bite","Bite tooltip","PetBite",nil,0,1,0},
    [2]={"Growl","Growl tooltip","PetGrowl",nil,0,0,0},
    [3]={"Cower",nil,"PetCower",nil,1,1,1}
}
GetPetActionInfo=function(index)
    local values=petActions[index]
    if values then return values[1],values[2],values[3],values[4],values[5],values[6],values[7] end
end
GetPetActionCooldown=function() return 0,0,0 end; PetHasActionBar=function() return 1 end
local petCalls={}
CastPetAction=function(index) table.insert(petCalls,{"cast",index}) end
PickupPetAction=function(index) table.insert(petCalls,{"pickup",index}) end
TogglePetAutocast=function(index) table.insert(petCalls,{"autocast",index}) end
PetAttack=function() table.insert(petCalls,{"attack"}) end
PetFollow=function() table.insert(petCalls,{"follow"}) end
PetWait=function() table.insert(petCalls,{"stay"}) end
PetPassiveMode=function() table.insert(petCalls,{"passive"}) end
PetDefensiveMode=function() table.insert(petCalls,{"defensive"}) end
PetAggressiveMode=function() table.insert(petCalls,{"aggressive"}) end
IsPetAttackActive=function(index) return index==3 and 1 or 0 end
PetStopAttack=function() table.insert(petCalls,{"stop"}) end
CursorHasSpell=function() return false end; CursorHasItem=function() return false end
load("actionbars/pet.lua")
local pet=ConsoleExperience.pet
assert(pet:Initialize() and pet.initialized,"pet action bar initializes")
assert(pet.frame:IsVisible(),"numeric PetHasActionBar=1 shows the persistent bar")
assert(not pet:IsVisible(),"persistent pet HUD must not be treated as a modal")
assert(pet.buttons[1].petName=="Bite" and pet.buttons[1].icon.portrait=="PetBite")
local _,_,_,_,rawActive,rawAllowed,rawEnabled=GetPetActionInfo(1)
assert(rawAllowed==1 and rawEnabled==0,"mock must preserve all seven Vanilla pet tuple values")
assert(pet.buttons[1].autocastAllowed and not pet.buttons[1].autocastEnabled,
    "numeric autocast flags must be normalized: "..tostring(pet.buttons[1].autocastAllowed).." / "..tostring(pet.buttons[1].autocastEnabled))
assert(not pet.buttons[2].autocastAllowed,"numeric zero autocast capability must stay false")
local function lastPetCall() return petCalls[table.getn(petCalls)][1] end
assert(pet:ActivateSlot(1,"LeftButton") and lastPetCall()=="cast")
assert(pet:ActivateSlot(1,"RightButton") and lastPetCall()=="autocast")
assert(pet:ActivateSlot(3,"LeftButton") and lastPetCall()=="stop")
CursorHasSpell=function() return true end
assert(pet:ActivateSlot(1,"LeftButton") and lastPetCall()=="pickup","held spell must be placed, not cast")
CursorHasSpell=function() return false end
CE_PET_MENU(); assert(pet.commandFrame:IsVisible() and pet:IsVisible())
for _,row in ipairs(pet.commandRows) do assert(type(row.label)=="string" and row.text.text==row.label) end
pet.commandRows[2]:Click(); assert(lastPetCall()=="follow" and not pet:IsVisible())
CE_PET_MENU(); pet.commandRows[7]:Click()
assert(pet.abilityFrame:IsVisible() and pet:IsVisible())
assert(cursor.navigationState.currentButton.petAction~=nil,"editor needs initial focus")
assert(pet:HandleInput(1) and lastPetCall()=="cast")
assert(pet:HandleInput(2) and lastPetCall()=="autocast")
assert(pet:HandleInput(3) and lastPetCall()=="pickup")
assert(pet:HandleInput(4) and not pet:IsVisible() and pet.frame:IsVisible(),"B closes only modal editor")
local priorHides=hooks.hides; pet:ShowMenu(); pet:HideMenu()
assert(hooks.hides>priorHides,"pet popup must preserve the dynamic-frame OnHide hook")
local previousScale=petBarScale; petBarScale=1.8; UIParent:SetWidth(800); UIParent:SetHeight(600); pet:UpdatePosition()
assert(pet.frame:GetScale()*pet.frame:GetWidth()<=776.1,"pet bar scale must fit screen width")
assert(pet.frame:GetScale()*pet.frame:GetHeight()<=568.1,"pet bar scale must fit screen height")
petBarScale=previousScale; UIParent:SetWidth(1920); UIParent:SetHeight(1080); pet:UpdatePosition()
local hasPet=PetHasActionBar; PetHasActionBar=function() return 0 end; pet:Refresh()
assert(not pet.frame:IsVisible() and not pet:ShowAbilities(),"numeric zero pet state disables bar and editor")
pet:ShowMenu(); assert(cursor.navigationState.currentButton==pet.commandRows[8],"empty-pet menu focuses its enabled Close action")
pet:HideMenu()
PetHasActionBar=hasPet; pet:Refresh()

-- Selected-unit actions are checked again at activation. A changed target
-- identity cannot inherit an action offered for the previous target.
local unit={name="Friendly",realm="Realm",player=1,friendly=1,level=60,class="Warrior",guid="unit-guid",faction="Alliance"}
local partySize,raidSize,partyLeader,raidLeader,raidOfficer=1,0,1,0,0
UnitExists=function(who) return who=="target" and 1 or 0 end
UnitName=function() return unit.name,unit.realm end
UnitIsPlayer=function() return unit.player end; UnitIsFriend=function() return unit.friendly end
UnitLevel=function() return unit.level end; UnitClass=function() return unit.class end
UnitGUID=function() return unit.guid end; UnitIsUnit=function() return 0 end
CheckInteractDistance=function() return 1 end; CanInspect=function() return 0 end
GetNumPartyMembers=function() return partySize end; GetNumRaidMembers=function() return raidSize end
IsPartyLeader=function() return partyLeader end; IsRaidLeader=function() return raidLeader end; IsRaidOfficer=function() return raidOfficer end
UnitFactionGroup=function(who) return who=="player" and "Alliance" or unit.faction end
local unitCalls={}
FollowByName=function(name,force) table.insert(unitCalls,{"follow",name,force}) end
InitiateTrade=function(who) table.insert(unitCalls,{"trade",who}) end
NotifyInspect=function(who) table.insert(unitCalls,{"inspect",who}) end
InviteByName=function(name) table.insert(unitCalls,{"invite",name}) end
AssistUnit=function(who) table.insert(unitCalls,{"assist",who}) end
SetRaidTargetIcon=function(who,index) table.insert(unitCalls,{"marker",who,index}) end
load("cursor/unitmenu.lua")
local menu=ConsoleExperience.unitmenu
assert(menu:Open("target") and menu:IsVisible())
assert(cursor.navigationState.currentButton==menu.rows[1])
for _,row in ipairs(menu.rows) do if row:IsShown() then assert(type(row.label)=="string" and row.text.text==row.label) end end
local function unitRow(id)
    for _,row in ipairs(menu.rows) do if row:IsShown() and row.action==id then return row end end
end
assert(unitRow("follow"):IsEnabled()==1)
assert(unitRow("inspect"):IsEnabled()==0,"CanInspect numeric zero disables Inspect")
assert(unitRow("invite"):IsEnabled()==1,"invites remain available with party room")
partyLeader=0; menu:Render(); assert(unitRow("invite"):IsEnabled()==0,"nonleader cannot invite from an existing party")
partyLeader=1; menu:Render()
unitRow("follow"):Click(); assert(unitCalls[table.getn(unitCalls)][1]=="follow" and unitCalls[table.getn(unitCalls)][3]==1 and not menu:IsVisible())
menu:Open("target"); unit.name="Replacement"; local before=table.getn(unitCalls)
assert(not menu:Execute("trade") and table.getn(unitCalls)==before,"changed unit identity blocks mutation")
unit.name="Friendly"; menu:Open("target"); unit.friendly=0; menu:Render()
assert(unitRow("follow"):IsEnabled()==0 and unitRow("invite"):IsEnabled()==0 and unitRow("assist"):IsEnabled()==0)
unit.friendly=1; unit.player=0; menu:Open("target")
local npcFollow,npcInvite,npcAssist=unitRow("follow"),unitRow("invite"),unitRow("assist")
assert(not npcFollow and not npcInvite and npcAssist and npcAssist:IsEnabled()==1,"friendly NPC exposes Assist without player-only actions")
unitRow("raidmark"):Click(); assert(menu.mode=="markers" and menu:IsVisible())
local markerRow
for _,row in ipairs(menu.rows) do if row.markerIndex==3 then markerRow=row end end
assert(markerRow and markerRow:IsEnabled()==1 and type(markerRow.label)=="string")
local markerBack
for _,row in ipairs(menu.rows) do if row:IsShown() and row.action=="back" then markerBack=row end end
assert(markerBack and type(markerBack.label)=="string","complete marker picker includes a back row after eight choices")
local markerCallCount=table.getn(unitCalls); partyLeader=0
assert(not menu:Execute("marker",3) and table.getn(unitCalls)==markerCallCount,"marker permission is revalidated at selection")
partyLeader=1; menu:Open("target"); unitRow("raidmark"):Click()
for _,row in ipairs(menu.rows) do if row:IsShown() and row.markerIndex==3 then markerRow=row end end
markerRow:Click(); assert(unitCalls[table.getn(unitCalls)][1]=="marker" and unitCalls[table.getn(unitCalls)][3]==3)
partyLeader=0; menu:Open("target"); assert(unitRow("raidmark"):IsEnabled()==0,"numeric zero party-leader flag disables markers")
priorHides=hooks.hides; menu:Close(); assert(hooks.hides>priorHides,"unit popup preserves hooked OnHide")
menu:Open("target"); model:Invoke(menu.events,"OnEvent","PLAYER_TARGET_CHANGED"); assert(not menu:IsVisible(),"target change closes stale context")
partyLeader=1
unit.player=1; raidSize=1; raidLeader=0; raidOfficer=0; menu:Open("target")
assert(unitRow("invite"):IsEnabled()==0,"raid invite requires leadership permission")
raidOfficer=1; menu:Render(); assert(unitRow("invite"):IsEnabled()==1,"raid assistant can invite into available capacity")
raidSize=0; raidOfficer=0; menu:Close()
unit.player=1; unit.faction="Horde"; menu:Open("target")
assert(unitRow("invite"):IsEnabled()==0,"opposing faction cannot be invited")
unit.faction="Alliance"; UnitIsUnit=function() return 1 end; menu:Render()
assert(unitRow("follow"):IsEnabled()==0 and unitRow("trade"):IsEnabled()==0,"self-target actions are disabled")
UnitIsUnit=function() return 0 end; raidSize=40; menu:Render()
assert(unitRow("invite"):IsEnabled()==0,"full raid cannot be invited")
raidSize=0; menu:Close()

-- Vanilla loot rolls have five GetLootRollItemInfo return values. Capability
-- is read from stock buttons and server time remains in milliseconds.
local function makeStockFrame(name)
    local frame=CreateFrame("Frame",name,UIParent); frame.rollID=nil
    return frame
end
local function makeButton(name,parent)
    local button=CreateFrame("Button",name,parent); return button
end
LootFrame=CreateFrame("Frame","LootFrame",UIParent)
for i=1,4 do
    getfenv(0)["LootButton"..i]=makeButton("LootButton"..i,LootFrame)
    getfenv(0)["LootButton"..i.."Text"]=LootFrame:CreateFontString("LootButton"..i.."Text","OVERLAY","GameFontNormal")
end
LootFramePrev=makeButton("LootFramePrev",LootFrame); LootFrameNext=makeButton("LootFrameNext",LootFrame)
local groupFrame=makeStockFrame("GroupLootFrame1"); groupFrame.rollID=77
groupFrame:Show()
GroupLootFrame1RollButton=makeButton("GroupLootFrame1RollButton",groupFrame)
GroupLootFrame1GreedButton=makeButton("GroupLootFrame1GreedButton",groupFrame)
GroupLootFrame1PassButton=makeButton("GroupLootFrame1PassButton",groupFrame)
GroupLootFrame1Name=groupFrame:CreateFontString("GroupLootFrame1Name","OVERLAY","GameFontNormal")
GroupLootFrame1Timer=groupFrame:CreateFontString("GroupLootFrame1Timer","OVERLAY","GameFontNormal")
GroupLootFrame1IconFrameIcon=groupFrame:CreateTexture("GroupLootFrame1IconFrameIcon","ARTWORK")
for i=2,4 do getfenv(0)["GroupLootFrame"..i]=makeStockFrame("GroupLootFrame"..i) end
GroupLootFrame1RollButton:Enable(); GroupLootFrame1GreedButton:Disable()
GetLootRollItemInfo=function(id) if id==77 then return "LootTexture","Silver Ring",1,2,0 end end
GetLootRollItemLink=function(id) if id==77 then return "|Hitem:123|h[Silver Ring]|h" end end
GetLootRollTimeLeft=function(id) if id==77 then return 24000 end end
local rollCalls={}; RollOnLoot=function(id,choice) table.insert(rollCalls,{id,choice}); groupFrame.rollID=nil; groupFrame:Hide() end
load("cursor/lootpanel.lua")
local loot=ConsoleExperience.lootpanel
assert(loot:Initialize() and theme.registered[LootFrame]=="panel" and theme.registered[groupFrame]=="card")
assert(loot.events.events.START_LOOT_ROLL and loot.events.events.PLAYER_LOGIN
    and not loot.events.events.LOOT_SLOT_CHANGED,"loot watcher uses only known Vanilla events")
assert(loot:Open() and loot:IsVisible())
assert(table.getn(loot:Pending())==1,"pending roll should appear from stock group frame")
local row=loot.rows[1]
assert(row:IsVisible() and row.rollID==77 and row.name.text=="|Hitem:123|h[Silver Ring]|h")
assert(row.timer.text=="Time left: 24 sec","server milliseconds should display as seconds")
assert(row.rollButtons.need:IsEnabled()==1 and row.rollButtons.greed:IsEnabled()==0 and row.rollButtons.pass:IsEnabled()==1)
for _,button in pairs(row.rollButtons) do assert(type(button.label)=="string") end
assert(cursor.navigationState.currentButton and cursor.navigationState.currentButton.label,"pending roll receives initial focus")
assert(not loot:Choose(77,1,"stale-item-link") and table.getn(rollCalls)==0,"changed roll item identity cannot receive stale choice")
local changed=0; loot.events:SetScript("OnEvent",function() changed=changed+1; loot:Refresh() end)
model:Invoke(loot.events,"OnEvent","LOOT_SLOT_CLEARED"); assert(changed==1 and table.getn(rollCalls)==0,"read-state event cannot roll loot")
row.rollButtons.greed:Click(); assert(table.getn(rollCalls)==0,"unavailable greed cannot mutate roll")
row.rollButtons.need:Click(); assert(rollCalls[1][1]==77 and rollCalls[1][2]==1,"Need dispatches only from its button callback")
assert(loot:IsVisible(),"roll response leaves the consolidated view open for other pending rolls")
assert(loot.frame.initialCursorButton==loot.closeButton and type(loot.closeButton.label)=="string","empty roll panel retains controller focus via Close")
loot:Close()
print("PASS: pet controls, unit menu, pending rolls, UI labels/focus, Vanilla 1.12 API shape")

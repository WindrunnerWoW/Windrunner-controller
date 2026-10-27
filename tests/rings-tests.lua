-- Utility rings and picker action routes under the Vanilla 1.12 API surface.
WindrunnerExperienceDB={config={utilityRings={
    {name="Travel",entries={{kind="spell",name="Portal"},{kind="item",itemID=42,name="Potion"},{kind="macro",slot=12,name="Pet macro",body="/petattack"}}},
    {name="Travel",entries={{kind="spell",name="Invalid"}}},
    {name="Bad",entries={{kind="unknown",name="bad"},{kind="item",itemID="x"}}},
}}}
local actionOffset=24
ConsoleExperience={config={Get=function() return nil end},cursor={heldItemTexturePath=nil},
    actionbars={GetActionOffset=function(self,page) return actionOffset end}}
BOOKTYPE_SPELL="spell"
local spellIndex=4
GetSpellName=function(index)
    if index==1 then return "Fireball","Rank 1" elseif index==2 then return "Portal","Rank 1"
    elseif index==3 then return "Frostbolt","Rank 1" elseif index==spellIndex then return "Portal","Rank 2" end
end
GetSpellTexture=function(index) if index==2 or index==spellIndex then return "spell-icon" end end
GetSpellBookItemName=nil; GetSpellBookItemTexture=nil; GetActionInfo=nil
cursorSpell,cursorItem,cursorMoney,spellTarget=false,false,false,false
CursorHasSpell=function() return cursorSpell end
CursorHasItem=function() return cursorItem end
CursorHasMoney=function() return cursorMoney end
SpellIsTargeting=function() return spellTarget end
CastSpell=function(index,book) if index==spellIndex then cursorSpell=true end; _G.lastCast={index,book} end
PickupSpell=function(index,book) if index==spellIndex then cursorSpell=true end end
local carried=true
local itemLocked=false
GetContainerNumSlots=function(bag) return bag==0 and 2 or 0 end
GetContainerItemLink=function(bag,slot) if carried and bag==0 and slot==2 then return "|Hitem:42:0:0|h[Potion]|h" end end
GetContainerItemInfo=function(bag,slot) if carried and bag==0 and slot==2 then return "potion-icon",3,itemLocked and 1 or 0 end end
PickupContainerItem=function(bag,slot) if carried and bag==0 and slot==2 and not itemLocked then cursorItem=true end end
useCount=0
UseContainerItem=function(bag,slot) useCount=useCount+1; _G.lastUse={bag,slot} end
local macroBody="/petattack"
local macroName2,macroBody2=nil,"/petfollow"
local actionText={[12]="Pet macro"}
GetMacroInfo=function(index)
    if index==1 then return "Pet macro","macro-icon",macroBody end
    if index==2 and macroName2 then return macroName2,"macro-icon-2",macroBody2 end
end
GetActionText=function(slot) return actionText[slot] end
UseAction=function(slot) _G.lastAction=slot end
PickupMacro=function(index) if index==1 then return false end end
local placed={}
PlaceAction=function(slot) table.insert(placed,slot); cursorSpell=false; cursorItem=false end
local binding={actionSlot=25,binding=nil}
ConsoleExperience.config.GetBindingSlotInfo=function(self,slot) if slot==1 then return binding end end
UIErrorsFrame={AddMessage=function() end}
assert(loadfile(arg[1].."/radial/rings.lua"))()
local rings=ConsoleExperience.rings
rings:Initialize()
local all=rings:GetAll()
assert(table.getn(all)==3 and all[1].name=="Travel" and all[2].name=="Travel 2")
assert(table.getn(all[3].entries)==0)
assert(rings:Add({kind="item",itemID=1,name="Bandage"},1))
assert(not rings:Add({kind="item",itemID=1,name="Bandage"},1))
assert(rings:Move(1,4,-1)); assert(rings:Remove(1,3))
local items=rings:BuildItems(1)
assert(table.getn(items)==3)
items[1].action(); assert(lastCast and lastCast[1]==spellIndex and lastCast[2]==BOOKTYPE_SPELL)
assert(cursorSpell and not items[2].isAvailable()) -- cursor payload blocks using another entry
cursorSpell=false
items[2].action(); assert(lastUse and lastUse[1]==0 and lastUse[2]==2)
itemLocked=true; assert(not items[2].isAvailable())
local priorUseCount=useCount; items[2].action(); assert(useCount==priorUseCount)
itemLocked=false; carried=false; assert(not items[2].isAvailable())
items[2].action(); assert(useCount==priorUseCount)
carried=true
assert(items[3].isAvailable()); items[3].action(); assert(lastAction==12)
macroName2="Pet macro"
assert(not items[3].isAvailable(),"duplicate macro names must be rejected when the action slot cannot identify the body")
macroName2=nil
actionText[12]="Different macro"; assert(not items[3].isAvailable())
actionText[12]="Pet macro"; macroBody="/petfollow"; assert(not items[3].isAvailable())

-- Native system actions can be saved and executed from a ring.
local proxiedAction={id="TOGGLEGAMEMENU",nameKey="Game Menu",icon="gear-icon"}
ConsoleExperience.proxied={
    ACTIONS={proxiedAction},
    GetActionByID=function(self,id) if id=="TOGGLEGAMEMENU" then return proxiedAction end end,
    GetActionName=function(self,action) return action.name or action.nameKey end,
    GetActionDesc=function() return "Open the game menu" end,
}
local boundAction
RunBinding=function(id) boundAction=id end
assert(rings:Add({kind="action",command="TOGGLEGAMEMENU",name="Game Menu"},1))
assert(not rings:Add({kind="action",command="TOGGLEGAMEMENU",name="Game Menu"},1),"duplicate system actions rejected")
local actionItem
for _,item in ipairs(rings:BuildItems(1)) do if item.subtitle=="System action" then actionItem=item end end
assert(actionItem and actionItem.name=="Game Menu" and actionItem.isAvailable())
actionItem.action(); assert(boundAction=="TOGGLEGAMEMENU")
cursorItem=true; assert(actionItem.isAvailable(),"game menu stays available with a cursor payload"); cursorItem=false

assert(rings:Create("Dinner")); assert(rings:Rename(rings.selectedRing,"Feast")); assert(rings:Delete(rings.selectedRing))
assert(rings:EndHeld(true)==false)

-- Exercise picker selection without constructing frames; OpenForBinding still
-- records the originating control and Choose rechecks it before placement.
assert(loadfile(arg[1].."/config/actionpicker.lua"))()
local picker=ConsoleExperience.actionpicker
picker.Show=function() end
picker.frame={Hide=function() end}
assert(not picker:Open(0)); assert(not picker:Open(121))
assert(picker:OpenForBinding(1))
cursorItem=true
local count=table.getn(placed); assert(not picker:Choose({kind="spell",name="Portal"})); assert(table.getn(placed)==count)
cursorItem=false
binding={actionSlot=25,binding=nil}
assert(picker:OpenForBinding(1))
binding={actionSlot=25,binding="STANCE"}
assert(not picker:Choose({kind="spell",name="Portal"})); assert(table.getn(placed)==count)
binding={actionSlot=25,binding=nil}
assert(picker:OpenForBinding(1))
PickupSpell=function() end -- failed pick must not call PlaceAction
assert(not picker:Choose({kind="spell",name="Portal"})); assert(table.getn(placed)==count)
PickupSpell=function(index,book) if index==spellIndex then cursorSpell=true end end
assert(picker:OpenForBinding(1)); itemLocked=true
assert(not picker:Choose({kind="item",name="Potion",itemID=42})); assert(table.getn(placed)==count)
itemLocked=false
assert(picker:OpenForBinding(1)); PickupContainerItem=function(bag,slot) cursorItem=true end
assert(picker:Choose({kind="item",name="Potion",itemID=42})); assert(table.getn(placed)==count+1 and placed[count+1]==25)
count=table.getn(placed)
assert(picker:OpenForBinding(1)); PickupContainerItem=function() end
assert(not picker:Choose({kind="item",name="Potion",itemID=42})); assert(table.getn(placed)==count)
PickupContainerItem=function(bag,slot) cursorItem=true end
binding={actionSlot=25,binding=nil}; assert(picker:OpenForBinding(1)); actionOffset=25
assert(not picker:Choose({kind="spell",name="Portal"})); assert(table.getn(placed)==count)
actionOffset=24; binding={actionSlot=25,binding=nil}; assert(picker:OpenForBinding(1)); binding={actionSlot=25,binding="PROXY_STANCE"}
assert(not picker:Choose({kind="spell",name="Portal"})); assert(table.getn(placed)==count)
binding={actionSlot=25,binding="STANCE"}; assert(picker:OpenForBinding(1)==false)
binding={actionSlot=25,binding=nil}
assert(picker:OpenForBinding(1)); macroBody="/petattack"; local macroEntry={kind="macro",name="Pet macro",body="/petattack"}
assert(not picker:Choose(macroEntry)); assert(table.getn(placed)==count) -- mock pickup reports failure

assert(picker:OpenForBinding(1)); binding={actionSlot=25,binding="STANCE"}
assert(not picker:Choose({kind="spell",name="Portal"})); assert(table.getn(placed)==count)

-- Held ring release needs an intentional D-pad/stick selection. A deadzone,
-- B/cancel, focus loss, disconnect, or typing release closes without firing.
assert(loadfile(arg[1].."/radial/radial.lua"))()
local radial=ConsoleExperience.radial
rings:Initialize() -- collection registration is refreshed after radial loads
local fired=0
local fakeFrame={shown=true,IsVisible=function(self) return self.shown end,Hide=function(self) self.shown=false end}
radial.frame=fakeFrame; radial.overlay={Hide=function() end}
radial.menuItems={{name="one"},{name="two"}}
radial.buttons={{item={name="one",action=function() fired=fired+1 end},positionX=0,positionY=0},
    {item={name="two",action=function() fired=fired+1 end},positionX=10,positionY=0}}
radial.selectedIndex=1; radial.UpdateButtonVisual=function() end; radial.SyncCursorSelection=function() end
radial:BeginHeldSelection(); assert(not radial:EndHeldSelection(true)); assert(fired==0 and not fakeFrame.shown)
fakeFrame.shown=true; radial:BeginHeldSelection(); radial:SelectFromStick(1,0); radial:SelectFromStick(0,0)
assert(not radial:EndHeldSelection(true)); assert(fired==0 and not fakeFrame.shown)
fakeFrame.shown=true; radial:BeginHeldSelection(); radial:MoveSelection("RIGHT")
assert(radial:EndHeldSelection(true)); assert(fired==1 and not fakeFrame.shown)
fakeFrame.shown=true; radial:BeginHeldSelection(); radial:MoveSelection("RIGHT")
assert(not radial:EndHeldSelection(false)); assert(fired==1 and not fakeFrame.shown)
fakeFrame.shown=true; assert(not radial:EndHeldSelection(false)); assert(not fakeFrame.shown)
-- Both sticks share one intent state. Neutral input from the unused stick is
-- harmless; recentering both sticks still cancels a held release selection.
assert(loadfile(arg[1].."/config/controls.lua"))()
local getOption=ConsoleExperience.config.Get
local mode="both"
ConsoleExperience.config.Get=function(_,key) if key=="radialSelectionStick" then return mode end end
local capturedStick
local selectStick=radial.SelectFromStick
radial.SelectFromStick=function(_,x,y) capturedStick={x,y} end
mode="left"; radial:SelectFromSticks(0,1,1,0); assert(capturedStick[1]==0 and capturedStick[2]==1)
mode="right"; radial:SelectFromSticks(0,1,1,0); assert(capturedStick[1]==1 and capturedStick[2]==0)
mode="both"; radial.selectionStick=nil
radial:SelectFromSticks(0,1,0,0); assert(capturedStick[2]==1)
radial:SelectFromSticks(0,0.9,0.9,0); assert(capturedStick[2]==0.9,"equal deflection must retain the active stick")
radial:SelectFromSticks(0,0,1,0); assert(capturedStick[1]==1,"the other stick takes over after the first centers")
radial.SelectFromStick=selectStick
fakeFrame.shown=true; radial:BeginHeldSelection(); radial:SelectFromSticks(1,0,0,0)
assert(radial.heldSelectionIntent,"the neutral unused stick must preserve intentional left-stick selection")
radial:SelectFromSticks(0,0,0,0); assert(not radial:EndHeldSelection(true) and fired==1)
ConsoleExperience.config.Get=getOption
WindrunnerController={heldRing=true,Release=function(self)
    if self.heldRing then self.heldRing=nil; rings:EndHeld(false) end
end}
for _,reason in ipairs({"focus loss","disconnect","typing","B cancel"}) do
    fakeFrame.shown=true; radial:BeginHeldSelection(); radial:MoveSelection("RIGHT")
    WindrunnerController.heldRing=true; WindrunnerController:Release()
    assert(not fakeFrame.shown and fired==1,reason.." must cancel a held ring without activating")
end

-- CycleCollection uses the real OpenCollection/ShowCollection route while
-- retaining the hold latch but discarding the prior collection's selection.
local function textRegion()
    return {text="",SetText=function(self,value) self.text=value end,
        GetText=function(self) return self.text end}
end
fakeFrame.heading=textRegion(); fakeFrame.selectionText=textRegion(); fakeFrame.statusText=textRegion()
fakeFrame.instructions=textRegion()
fakeFrame.Show=function(self) self.shown=true end
radial.overlay.Show=function() end
radial.UpdateScale=function() end
radial.StartOpenAnimation=function() end
radial.RefreshMenuItems=function(self)
    self.menuItems=self.collectionItems or {}
    self.buttons={}
    for i,item in ipairs(self.menuItems) do
        table.insert(self.buttons,{item=item,positionX=(i-1)*10,positionY=0})
    end
    self.selectedIndex=1
end
local alphaFired,betaFired=0,0
radial:RegisterCollection("Held A",function()
    return {{name="A1",action=function() alphaFired=alphaFired+1 end},
        {name="A2",action=function() alphaFired=alphaFired+1 end}}
end)
radial:RegisterCollection("Held B",function()
    return {{name="B1",action=function() betaFired=betaFired+1 end},
        {name="B2",action=function() betaFired=betaFired+1 end}}
end)
assert(radial:OpenCollection("Held A"))
radial:BeginHeldSelection(); radial:MoveSelection("RIGHT")
assert(radial.heldSelectionIntent and radial.heldDpadIntent)
assert(radial:CycleCollection(1) and radial.collectionTitle=="Held B")
assert(radial.heldSelection and not radial.heldSelectionIntent and not radial.heldDpadIntent,
    "switching collections should retain the hold while clearing old selection intent")
assert(not radial:EndHeldSelection(true) and betaFired==0 and not fakeFrame.shown,
    "release without fresh selection after cycling should close without activation")

assert(radial:OpenCollection("Held A"))
radial:BeginHeldSelection(); radial:MoveSelection("RIGHT")
assert(radial:CycleCollection(1) and radial.collectionTitle=="Held B")
radial:MoveSelection("RIGHT")
assert(radial.heldSelectionIntent and radial:EndHeldSelection(true))
assert(betaFired==1 and alphaFired==0 and not fakeFrame.shown,
    "fresh post-cycle selection should activate the selected item in the new collection")
print("rings-tests: ok")

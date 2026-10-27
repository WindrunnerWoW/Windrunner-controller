-- Actual item menu, cursor focus, tooltip bindings and native routes under Lua 5.0.
local root=assert(arg[1],"pass the addon root")
local model=assert(loadfile("tests/ui-model.lua"))()
local create=model.Create
function model:Create(kind,name,parent,template)
    local frame=create(self,kind,name,parent,template)
    function frame:GetID() return self.id or 0 end
    function frame:SetID(id) self.id=id end
    function frame:GetCenter() local l,b,w,h=self:Rect(); return l+w/2,b+h/2 end
    function frame:GetFrameStrata() return self.strata or "MEDIUM" end
    function frame:SetFrameStrata(value) self.strata=value end
    function frame:GetFrameLevel() return self.level or 0 end
    function frame:SetFrameLevel(value) self.level=value end
    function frame:SetParent(value) self.parent=value end
    function frame:Show() if not self.shown then self.shown=true; model:Invoke(self,"OnShow") end end
    function frame:Hide() if self.shown then self.shown=false; model:Invoke(self,"OnHide") end end
    function frame:Click(button) if self:IsEnabled()==1 then model:Invoke(self,"OnClick",button or "LeftButton") end end
    function frame:RegisterForClicks() end
    function frame:GetAlpha() return self.alpha end
    if kind=="GameTooltip" then
        function frame:SetOwner(button) self.owner=button end
        function frame:IsOwned(button) return self.owner==button end
        function frame:SetBagItem(bag,slot) self.bag,self.slot=bag,slot end
        function frame:SetInventoryItem() end
        function frame:AddLine() end
        function frame:NumLines() return 0 end
    end
    return frame
end
CreateFrame=function(kind,name,parent,template) return model:Create(kind,name,parent,template) end
UIParent=CreateFrame("Frame","UIParent"); UIParent:SetWidth(1920); UIParent:SetHeight(1080)
GameTooltip=CreateFrame("GameTooltip","GameTooltip",UIParent)
ChatFrameEditBox=CreateFrame("EditBox","ChatFrameEditBox",UIParent); ChatFrameEditBox:Hide()
ConsoleExperience={}; WindrunnerExperienceDB={config={}}
SlashCmdList={}; UISpecialFrames={}; StaticPopupDialogs={}
getglobal=function(name) return getfenv(0)[name] end; getfenv(0)._G=getfenv(0)
CE_Debug=function() end; CE_Print=function() end; PlaySound=function() end
GetLocale=function() return arg[2] or "enUS" end
GetCurrentKeyBoardFocus=function() return nil end
GetTime=function() return 1 end
local settings={controllerType=arg[3] or "xbox",healerMode=false}
ConsoleExperience.config={Get=function(self,key) return settings[key] end}
local mappings={}
ConsoleExperience.SetControllerBinding=function(key,action) mappings[key]=action end
ConsoleExperience.GetControllerBindingAction=function(key) return mappings[key] end
ConsoleExperience.GetControllerBindingKey=function() end
ConsoleExperience.SaveControllerBindings=function() end
SetBinding=function() error("must not modify keyboard bindings") end
local held,spellTarget,money=false,false,false
CursorHasItem=function() return held end
CursorHasSpell=function() return false end
CursorHasMoney=function() return money end
SpellIsTargeting=function() return spellTarget end
SpellCanTargetItem=function() return spellTarget end
IsShiftKeyDown=function() return false end; IsControlKeyDown=IsShiftKeyDown
BOOKTYPE_SPELL="spell"; BANK_CONTAINER=-1; NUM_BAG_SLOTS=4
local link="|cff0070dd|Hitem:123:0:0:0|h[Arcane Silk Vest]|h|r"
local slots={}
local function key(bag,slot) return bag..":"..slot end
local function put(bag,slot,count,locked,itemLink)
    slots[key(bag,slot)]={texture="Interface\\Icons\\INV_Chest_Cloth_17",count=count or 20,locked=locked,link=itemLink or link}
end
GetContainerItemInfo=function(bag,slot)
    local item=slots[key(bag,slot)]
    if item then return item.texture,item.count,item.locked,3 end
end
GetContainerItemLink=function(bag,slot) return slots[key(bag,slot)] and slots[key(bag,slot)].link end
GetContainerNumSlots=function(bag) return bag==2 and 16 or 0 end
GetItemInfo=function() return "Arcane Silk Vest",link,3,40,35,"Armor","Cloth",20,"INVTYPE_CHEST" end
local known=true
GetSpellName=function(index) if known and index==1 then return "Entzaubern" end end
GetSpellTexture=function(index) if known and index==1 then return "Interface\\Icons\\INV_Enchant_Disenchant" end end
local scope,calls=nil,{}
local function record(action,bag,slot,amount)
    assert(scope=="hardware" or scope=="native",action.." escaped hardware input")
    table.insert(calls,{action,bag,slot,amount})
end
UseContainerItem=function(bag,slot) record("use",bag,slot); spellTarget=false end
PickupContainerItem=function(bag,slot) record("pickup",bag,slot); held=slots[key(bag,slot)]~=nil end
SplitContainerItem=function(bag,slot,amount) record("split",bag,slot,amount); held=true end
DeleteCursorItem=function() record("delete"); held=false end
CastSpell=function(index,book) record("cast",index,book); spellTarget=true end
DressUpItemLink=function(value) record("preview",value) end
WindrunnerController_SetMovement=function(mask) assert(scope=="native" or scope=="release"); return true end
WindrunnerController_Mouse=function(x,y,buttons,mode) assert(scope); calls.mouse={x,y,buttons,mode}; return true end
WindrunnerController_Release=function() end
WindrunnerController_RunRelease=function()
    local prior=scope; scope="release"
    local ok,message=pcall(WindrunnerController_DispatchRelease)
    scope=prior; return ok,message
end
WindrunnerController_RunFrame=function()
    local prior=scope; scope="native"
    local ok,message=pcall(WindrunnerController_DispatchFrame)
    scope=prior; return ok,message
end
UseAction=function() error("inventory input leaked to the action bar") end
local function load(path) assert(loadfile(root.."/"..path))() end
load("locale/locale.lua"); load("locale/translations_enUS.lua"); load("locale/translations_deDE.lua")
load("ui/theme.lua"); load("WindrunnerController.lua")
load("cursor/cursor.lua"); load("cursor/tooltip.lua"); load("cursor/actions.lua")
load("cursor/keybindings.lua"); load("cursor/hooks.lua"); load("cursor/itemmenu.lua")
load("radial/rings.lua")
load("keybindings.lua")
local cursor,menu,controller=ConsoleExperience.cursor,ConsoleExperience.itemmenu,WindrunnerController
cursor.tooltip:Initialize(); cursor:Enable()
local function hardware(fn) scope="hardware"; fn(); scope=nil end
local function frame(name,id)
    local f=CreateFrame("Frame",name,UIParent); f:SetID(id); f:SetWidth(200); f:SetHeight(200)
    f:SetPoint("CENTER",UIParent,"CENTER",400,0); return f
end
local function button(name,parent,id)
    local b=CreateFrame("Button",name,parent); b:SetID(id); b.hasItem=true
    b:SetWidth(32); b:SetHeight(32); b:SetPoint("CENTER",parent,"CENTER",0,0); return b
end
local container=frame("ContainerFrame9",2)
local bag=button("ContainerFrame9Item5",container,7)
put(2,7)
ConsoleExperience.hooks:HookDynamicFrame(container,container:GetName())
cursor:MoveCursorToButton(bag)
local function binding(b,keyValue)
    for _,entry in ipairs(cursor.tooltip:GetBindings(b:GetName(),nil,b)) do if entry.key==keyValue then return entry.action end end
end
assert(binding(bag,"3")=="CE_CURSOR_ITEM_ACTIONS","Y must open the item menu")
cursor.tooltip:ShowButtonTooltip(bag)
assert(GameTooltip.bag==2 and GameTooltip.slot==7,"stock tooltip must use bag ID, not pooled frame number")
local function open(source)
    held,money,spellTarget=false,false,false; cursor:ClearHeldItemTexture()
    controller.pointer=false
    cursor:MoveCursorToButton(source or bag)
    hardware(CE_ItemActions)
    assert(menu.frame:IsVisible(),"item actions did not open")
    controller.armed=true
end
local function act(action) hardware(function() menu:Execute(action) end) end
local function dispatch(buttons)
    controller.world=true
    controller.pendingInput={0.016,buttons or 0,0,0,0,0,0,0}
    local ok,message=WindrunnerController_RunFrame(); controller.pendingInput=nil
    assert(ok,message)
end
open()
assert(cursor.navigationState.navigationLockFrame==menu.frame,"item menu must own focus")
assert(cursor.navigationState.currentButton==menu.rows[1])
assert(table.getn(cursor:CollectAllVisibleButtons())==9,"utility-ring action should be available in item context")
local function mapped(slot)
    hardware(function() keystate="down"; ConsoleExperience_ActionButton(slot); keystate=nil end)
end
mapped(4); assert(not menu.frame:IsVisible(),"mapped B must close the item menu")
mapped(3); assert(menu.frame:IsVisible(),"mapped Y must open the focused item")
-- Timed loot should not steal focus from an explicit item decision.
local roll=frame("GroupLootFrame1",0); button("GroupLootFrame1PassButton",roll,0)
assert(table.getn(cursor:CollectAllVisibleButtons())==9,"loot stole modal item focus")
roll:Hide()
act("splitMenu")
assert(menu.mode=="split" and menu.amount==10)
assert(binding(menu.rows[1],"6")=="CE_ITEM_MENU_LESS" and binding(menu.rows[1],"8")=="CE_ITEM_MENU_MORE")
mapped(8); assert(menu.amount==11,"mapped right D-pad must change count")
hardware(function() CE_MoveCursor("LEFT") end); assert(menu.amount==10,"dedicated cursor binding must adjust count")
controller.armed=true -- simulate the neutral sample after the earlier mapped close
dispatch(8); assert(menu.amount==11,"native right D-pad must change count")
dispatch(0); dispatch(16384); assert(menu.amount==10,"X must select half")
dispatch(0); dispatch(32768); assert(menu.amount==19,"Y must leave one")
controller.pointer=true
dispatch(0); dispatch(16384)
assert(menu.amount==10 and calls.mouse[3]==0,"pointer mode must yield A/X to the item menu")
controller.pointer=false
dispatch(0); dispatch(4096)
assert(calls[table.getn(calls)][1]=="split" and calls[table.getn(calls)][4]==10)
assert(not menu.frame:IsVisible() and not controller.armed,"closing must require button release")
assert(cursor.navigationState.currentButton==bag and held and cursor.heldItemTexturePath)
local n=table.getn(calls); dispatch(4096)
assert(table.getn(calls)==n,"held confirm repeated a split")
open(); act("splitMenu")
put(2,7,3); menu:Adjust(100)
assert(menu.amount==2,"split must clamp to the current stack")
put(2,7,1); model:Invoke(menu.frame,"OnUpdate",0.3)
assert(menu.mode=="actions","a singleton must leave the split selector")
put(2,7,20)
-- A recycled button or replaced item cannot redirect a cached action.
act("destroy"); assert(cursor.navigationState.currentButton==menu.rows[1],"Cancel must be selected first")
put(2,7,20,false,"|Hitem:999:0:0:0|h[Replacement]|h")
n=table.getn(calls); act("confirmDestroy")
assert(table.getn(calls)==n and not menu.frame:IsVisible(),"stale item was destroyed")
put(2,7); open(); bag:SetID(8); act("primary")
assert(table.getn(calls)==n and not menu.frame:IsVisible(),"recycled addon slot was used")
bag:SetID(7)
open(); act("destroy"); hardware(CE_ItemMenuBack)
assert(menu.mode=="actions"); hardware(CE_ItemMenuBack)
assert(not menu.frame:IsVisible() and table.getn(calls)==n,"cancel must not pick up or delete an item")
open(); act("destroy"); act("confirmDestroy")
assert(calls[table.getn(calls)-1][1]=="pickup" and calls[table.getn(calls)][1]=="delete")
open(); act("destroy"); put(2,7,30); n=table.getn(calls); act("confirmDestroy")
assert(table.getn(calls)==n and menu.mode=="actions","changed stack needs a fresh destructive selection")
hardware(CE_ItemMenuBack); put(2,7)
open(); act("disenchant"); act("confirmDisenchant")
assert(calls[table.getn(calls)-1][1]=="cast" and calls[table.getn(calls)][1]=="use")
known=false; open(); assert(not menu:DisenchantSpell(menu:Validate())); hardware(CE_ItemMenuBack); known=true
open(); act("preview"); assert(calls[table.getn(calls)][1]=="preview")
local placed=false
ConsoleExperience.placement={Show=function() assert(scope); placed=true end}
open(); act("bind"); assert(placed and held and cursor.heldItemTexturePath)
ConsoleExperience.placement=nil
open(); money=true; n=table.getn(calls); act("primary")
assert(table.getn(calls)==n and not menu.frame:IsVisible(),"money payload was consumed")
money=false
-- Context changes require a new selection, never a stale Sell -> Equip action.
MerchantFrame=frame("MerchantFrame",0); MerchantFrame.selectedTab=1
open(); assert(menu.rows[1].label:GetText()==ConsoleExperience.locale.T("Sell"))
MerchantFrame:Hide(); n=table.getn(calls); act("primary")
assert(table.getn(calls)==n and menu.frame:IsVisible())
act("primary"); assert(calls[table.getn(calls)][1]=="use")
MerchantFrame:Show(); MerchantFrame.selectedTab=2
open(); assert(menu.rows[1]:IsEnabled()==0 and cursor.navigationState.currentButton==menu.rows[2])
hardware(CE_ItemMenuBack); MerchantFrame:Hide()
for _,name in ipairs({"AuctionFrame","TradeFrame","SendMailFrame"}) do
    local panel=frame(name,0)
    open(); assert(menu.primaryContext==({AuctionFrame="auction",TradeFrame="trade",SendMailFrame="attach"})[name])
    act("primary"); panel:Hide()
end
BankFrame=frame("BankFrame",0); BankFrame:Hide()
local sources={button("pfBag0item3",container,99),button("BagshuiBagsItem1",container,99),
    button("BagnonItem3",frame("BagnonBag",0),3),button("BankFrameItem3",BankFrame,3),
    button("BagshuiBankItem1",container,99),button("BanknonItem3",frame("BanknonBag",-1),3)}
sources[2].bagshuiData={bagNum=0,slotNum=3}; sources[5].bagshuiData={bagNum=-1,slotNum=3}
put(0,3); put(-1,3)
for i=1,3 do open(sources[i]); assert(menu.source.bag==0 and menu.source.slot==3); act("primary") end
sources[3].isLink=1; assert(not menu:Read(sources[3]),"cached other-character bags cannot act on live slots")
sources[3].isLink=nil
sources[2].bagshuiData.inventory={online=false}
assert(not menu:Read(sources[2]),"offline Bagshui character must be read-only")
sources[2].bagshuiData.inventory={online=true,editMode=true}
assert(not menu:Read(sources[2]),"Bagshui layout edit mode must not mutate items")
sources[2].bagshuiData={inventory={online=true},item={bagNum=0,slotNum=3,itemString="item:123:0:0:0"}}
assert(menu:Read(sources[2]),"Bagshui item metadata fallback")
sources[2].bagshuiData.item.itemString="item:999:0:0:0"
assert(not menu:Read(sources[2]),"Bagshui display must agree with the live item")
sources[2].bagshuiData={bagNum=0,slotNum=3}
for i=4,6 do
    held=false; cursor:ClearHeldItemTexture()
    assert(not menu:Read(sources[i]),"offline bank must have no item actions")
end
BankFrame:Show(); menu.bankOpen=true
for i=4,6 do open(sources[i]); assert(menu.primaryContext=="withdraw"); act("primary") end
open(sources[5]); event="BANKFRAME_CLOSED"; model:Invoke(menu.events,"OnEvent"); event=nil
assert(not menu.frame:IsVisible() and not menu.bankOpen,"bank close must dismiss cached bank actions")
menu.bankOpen=true
open(); assert(menu.primaryContext=="deposit"); hardware(CE_ItemMenuBack)
BankFrame:Hide(); menu.bankOpen=false
put(2,7,20,true); open(); assert(menu.rows[1]:IsEnabled()==0)
assert(cursor.navigationState.currentButton.itemAction=="preview","locked items must skip modifying actions")
n=table.getn(calls); act("destroy"); assert(table.getn(calls)==n and menu.mode=="actions")
hardware(CE_ItemMenuBack); put(2,7)
-- Pointer Y selects the hovered item, even if controller focus is elsewhere.
GetMouseFocus=function() return sources[1] end
controller.pointer=true; cursor:MoveCursorToButton(bag); hardware(CE_ItemActions)
assert(menu.source.bag==0 and menu.source.slot==3); hardware(CE_ItemMenuBack)
GetMouseFocus=function() return UIParent end
hardware(CE_ItemActions); assert(not menu.frame:IsVisible(),"empty pointer hover used an old focused item")
controller.pointer=false
-- Utility-ring item integration uses the real ring persistence and menu code.
local rings=ConsoleExperience.rings
assert(rings and rings:Create("Favorites"),"ring manager should create a persisted utility ring")
open(); act("ringMenu")
assert(menu.mode=="rings" and menu.rows[1].itemAction=="ring:1","item menu should offer the existing ring")
act("ring:1")
local saved=rings:GetAll()
assert(table.getn(saved[1].entries)==1 and saved[1].entries[1].kind=="item"
    and saved[1].entries[1].itemID==123,"selected carried item ID should be saved into the ring")
assert(menu.mode=="actions","adding an item should return to the item actions page")
act("ringMenu"); act("ringCreate")
saved=rings:GetAll()
assert(table.getn(saved)==2 and saved[2].name=="Items" and saved[2].entries[1].itemID==123,
    "create-and-add should persist the item in a new ring")
-- More than five rings must page, and Back must restore the item action page.
for i=3,6 do assert(rings:Create("Ring "..i)) end
open(); act("ringMenu")
assert(menu.ringPage==1 and menu.rows[6].itemAction=="ringNext","first ring page should expose Next")
act("ringNext")
assert(menu.ringPage==2 and menu.rows[1].itemAction=="ring:6","next page should show the sixth ring")
act("back"); assert(menu.mode=="actions","ring submenu Back should return to item actions")
-- The menu must reject a live slot that was replaced after the menu opened.
open(); act("ringMenu")
local priorCount=table.getn(rings:GetAll()[1].entries)
put(2,7,20,false,"|Hitem:999:0:0:0|h[Replacement]|h")
act("ring:1")
assert(table.getn(rings:GetAll()[1].entries)==priorCount and not menu.frame:IsVisible(),
    "replaced item must not be added to a ring")
put(2,7)
-- Locked slots are not valid ring sources, including from the submenu.
put(2,7,20,true); open(); act("ringMenu")
priorCount=table.getn(rings:GetAll()[1].entries)
act("ring:1")
assert(table.getn(rings:GetAll()[1].entries)==priorCount,"locked item must not be added to a ring")
hardware(CE_ItemMenuBack); put(2,7)
-- Fit and readability at maximum font/menu scale and a small screen.
settings.uiTextScale=1.2; settings.uiMenuScale=1.25
UIParent:SetWidth(800); UIParent:SetHeight(600)
open(); ConsoleExperience.theme:RefreshAll()
assert(menu.frame:GetHeight()*menu.frame:GetScale()<=560.01)
for _,row in ipairs(menu.rows) do
    if row:IsVisible() then assert(row.label:GetStringWidth()<=row.label:GetWidth(),"row label overflows") end
end
hardware(CE_ItemMenuBack)
-- Optional proofs serialize actual frame geometry, not a proposed mockup.
if arg[4] then
    settings.uiTextScale=1; settings.uiMenuScale=1
    UIParent:SetWidth(1920); UIParent:SetHeight(1080)
    open(); ConsoleExperience.theme:RefreshAll()
    local function export(suffix)
        local out=assert(io.open(arg[4]..suffix..".json","w"))
        local function str(s) return '"'..string.gsub(string.gsub(string.gsub(s or "","\\","\\\\"),'"','\\"'),"\n","\\n")..'"' end
        local function color(value) return value and ('['..table.concat(value,",")..']') or "null" end
        out:write('[')
        local first=true
        for _,f in ipairs(model.objects) do
            local parent=f
            while parent and parent~=menu.frame do parent=parent.parent end
            if parent and f:IsVisible() then
                local l,b,w,h=f:Rect()
                if not first then out:write(',') end; first=false
                out:write('{"kind":'..str(f.kind)..',"name":'..str(f.name)..',"x":'..l..',"y":'..b..',"w":'..w..',"h":'..h..',"text":'..str(f.kind=="FontString" and f.text or "")..',"size":'..f.fontSize..',"justify":'..str(f.justify)..',"clip":null,"bg":'..color(f.background)..',"border":'..color(f.border)..',"vertex":'..color(f.vertex)..',"texture":'..str(f.texture and type(f.texture[1])=="string" and f.texture[1] or "")..',"color":'..color(f.textColor)..'}')
            end
        end
        out:write(']'); out:close()
    end
    export("-actions"); act("splitMenu"); export("-split"); hardware(CE_ItemMenuBack)
    act("destroy"); export("-confirm"); hardware(CE_ItemMenuBack); hardware(CE_ItemMenuBack)
end
print("PASS: inventory menu, utility-ring item integration, native controls, split limits, item/context changes, confirmations, bag integrations, bank access and focus ("..GetLocale()..", "..settings.controllerType..").")

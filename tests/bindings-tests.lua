-- Run against the actual editor and proxy backend under Lua 5.0.3.
local root=assert(arg[1],"pass the Windrunner-Controller root")
local model=assert(loadfile("tests/ui-model.lua"))()
local create=model.Create
local actions={
    [2]={name="Frostbolt",icon="Interface\\Icons\\Spell_Frost_FrostBolt02"},
    [3]={name="Greater Blessing of Kings",icon="Interface\\Icons\\Spell_Magic_GreaterBlessingofKings"},
    [12]={name="Fireball",icon="Interface\\Icons\\Spell_Fire_FlameBolt"},
    [22]={name="Attack macro",icon="Interface\\Icons\\Ability_Warrior_Charge",macro=true},
    [32]={name="Healing Potion",icon="Interface\\Icons\\INV_Potion_51"},
    [74]={name="Overpower",icon="Interface\\Icons\\Ability_MeleeDamage"},
}
function model:Create(kind,name,parent,template)
    local frame=create(self,kind,name,parent,template)
    function frame:GetCenter() local l,b,w,h=self:Rect(); return l+w/2,b+h/2 end
    function frame:SetTexCoord(...) self.uv=arg end
    local createTexture,createFont=frame.CreateTexture,frame.CreateFontString
    function frame:CreateTexture(name,layer) local region=createTexture(self,name,layer); region.layer=layer; return region end
    function frame:CreateFontString(name,layer,template) local region=createFont(self,name,layer,template); region.layer=layer; return region end
    if kind=="GameTooltip" then
        function frame:SetOwner() end
        function frame:SetAction(slot)
            local action=actions[slot]
            local text=self:GetName().."TextLeft1"
            getfenv(0)[text]={GetText=function() return action and action.name end}
        end
    end
    return frame
end
CreateFrame=function(kind,name,parent,template) return model:Create(kind,name,parent,template) end
UIParent=CreateFrame("Frame","UIParent"); UIParent:SetWidth(1920); UIParent:SetHeight(1080)
GameMenuFrame=CreateFrame("Frame","GameMenuFrame",UIParent)
GameTooltip=CreateFrame("GameTooltip","GameTooltip",UIParent)
ConsoleExperience={}
WindrunnerExperienceDB={config={},proxiedActions={[1]="JUMP",[30]="CE_INTERACT"}}
SlashCmdList={}; StaticPopupDialogs={}; UISpecialFrames={}; tinsert=table.insert
getglobal=function(name) return getfenv(0)[name] end; getfenv(0)._G=getfenv(0)
CE_Debug=function() end; CE_Print=function() end; PlaySound=function() end
GetLocale=function() return arg[3] or "enUS" end
IsShiftKeyDown=function() return false end; IsControlKeyDown=function() return false end
SetBinding=function() error("the editor must not write global keyboard bindings") end
SaveBindings=SetBinding
HasAction=function(slot) return actions[slot]~=nil end
GetActionTexture=function(slot) return actions[slot] and actions[slot].icon end
GetActionText=function(slot) return actions[slot] and actions[slot].macro and actions[slot].name or nil end
SetPortraitToTexture=function(texture,path) texture.circular=true; texture:SetTexture(path) end
-- Spellbook, bag and macro data used by the categorized action picker.
local pickedSpell,cursorSpell=nil,false
local placedActions={}
GetSpellName=function(index)
    if index==1 then return "Frostbolt","Rank 1" end
    if index==2 then return "Fireball","Rank 1" end
    if index==3 then return "Fireball","Rank 2" end
end
GetSpellTexture=function(index)
    if index==1 then return "Interface\\Icons\\Spell_Frost_FrostBolt02" end
    if index==2 or index==3 then return "Interface\\Icons\\Spell_Fire_FlameBolt" end
end
PickupSpell=function(index) pickedSpell=index; cursorSpell=true end
CursorHasSpell=function() return cursorSpell end
PlaceAction=function(slot) table.insert(placedActions,slot); cursorSpell=false end
GetContainerNumSlots=function(bag) return bag==0 and 1 or 0 end
GetContainerItemLink=function(bag,slot) if bag==0 and slot==1 then return "|Hitem:32:0:0|h[Healing Potion]|h" end end
GetContainerItemInfo=function() return "Interface\\Icons\\INV_Potion_51",1,0 end
GetItemInfo=function(id) if id==32 then return "Healing Potion" end end
GetMacroInfo=function(index) if index==1 then return "Attack macro","Interface\\Icons\\Ability_Warrior_Charge","/startattack" end end
local entries,opened={},nil
local vanillaDropdownLimit=32
UIDropDownMenu_Initialize=function(dropdown,fn) dropdown.initialize=fn end
UIDropDownMenu_SetSelectedValue=function(dropdown,value) dropdown.selectedValue=value end
UIDropDownMenu_AddButton=function(info)
    assert(table.getn(entries)<vanillaDropdownLimit,"Vanilla dropdown button limit exceeded")
    table.insert(entries,info)
end
CloseDropDownMenus=function() opened=nil end
ToggleDropDownMenu=function(_,_,dropdown,owner)
    assert(type(owner)=="string" and getglobal(owner),"Vanilla dropdowns need a named anchor")
    opened=getglobal(owner); entries={}; dropdown.initialize()
end
local placementOpened=false
ConsoleExperience.placement={Show=function() placementOpened=true end}
local bonus=0
ConsoleExperience.actionbars={GetActionOffset=function(_,page) return page==1 and bonus or (page-1)*10 end}
local function load(path) assert(loadfile(root.."/"..path))() end
load("WindrunnerControllerIntegration.lua")
load("locale/locale.lua"); load("locale/translations_enUS.lua"); load("locale/translations_deDE.lua")
load("ui/theme.lua"); load("config/controls.lua"); load("config/proxied.lua"); load("config/actionpicker.lua"); load("config/config.lua"); load("config/rows.lua"); load("config/bindings.lua"); load("config/control-view.lua")
local config,theme=ConsoleExperience.config,ConsoleExperience.theme
local picker=ConsoleExperience.actionpicker
config.CreateContentSections=function(self) self.contentSections={}; self:CreateBindingsSection() end
config:CreateMainFrame(); config.frame:Show(); config:ShowSection("bindings")
local view=config.bindingOverview
assert(table.getn(view.rows)==10 and view.info[1].binding=="JUMP")
assert(view.info[2].name=="Frostbolt" and view.info[12].name=="Fireball" and view.info[22].name=="Attack macro")
local function row(index)
    for _,button in ipairs(view.rows) do if button.controlIndex==index then return button end end
end
local function choose(id)
    assert(config:OpenBindingActionMenu(),"binding editor should open the bounded system-action picker")
    for _,entry in ipairs(picker.entries or {}) do
        if entry.id==id and entry.kind=="system" then
            assert(picker:Choose(entry),"system action assignment should succeed: "..tostring(id))
            return
        end
    end
    error("missing choice: "..tostring(id))
end
config:SelectBindingSlot(2); choose("JUMP")
assert(table.getn(entries)==0,"system binding choices must bypass the bounded Vanilla dropdown")
assert(ConsoleExperience.proxied:GetSlotBinding(1)==nil and ConsoleExperience.proxied:GetSlotBinding(2)=="JUMP")
assert(ConsoleExperience.GetControllerBindingAction("2")=="JUMP","edits must reach the existing logical binding backend")
assert(view.info[1].name==ConsoleExperience.locale.T("Empty slot") and view.info[2].name==ConsoleExperience.locale.T("Jump"),"moving a unique action must refresh both rows")
assert(config:OpenBindingActionMenu())
assert(picker.category=="spells","a binding opens on the spellbook so spells are one click away")
assert(picker:GetCategory("menus") and picker:GetCategory("spells")
    and picker:GetCategory("items") and picker:GetCategory("macros"),
    "the picker offers menus, spells, items, and macros")
assert(picker.list and picker.listChild,"results use a scrollable list instead of paged rows")
assert(table.getn(picker.rows)==table.getn(picker:GetCategory("spells").entries),
    "the scrollable spell list is built without Previous/Next paging")
local menuRows=table.getn(picker:GetCategory("menus").entries)
picker.search:SetText("interact"); model:Invoke(picker.search,"OnTextChanged")
assert(table.getn(picker.filtered)==1 and picker.filtered[1].id=="CE_INTERACT",
    "search spans every category, including menu actions")
picker.search:SetText(""); model:Invoke(picker.search,"OnTextChanged")
model:Invoke(picker.categoryButtons.menus,"OnClick")
assert(picker.category=="menus" and table.getn(picker.filtered)==menuRows,
    "category tabs switch the scrollable list")
local fireball
for _,entry in ipairs(picker:GetCategory("spells").entries) do
    if entry.name=="Fireball" then fireball=entry; break end
end
assert(fireball,"spellbook entries are available from the binding picker")
assert(picker:Choose(fireball),"a spell can be bound from the binding picker")
assert(ConsoleExperience.proxied:GetSlotBinding(2)==nil,"choosing a spell clears the system assignment")
assert(table.getn(placedActions)==1 and placedActions[1]==2,"the spell is placed on the underlying action slot")
assert(pickedSpell==3,"the highest spell rank is placed")
choose(nil)
assert(view.info[2].name=="Frostbolt" and view.placeButton:IsEnabled()==1,"clearing a proxy must reveal the actual ability and keep placement available")
model:Invoke(view.tabs[3],"OnClick")
assert(view.page==3 and view.selectedSlot==22 and row(2).slot==22,"modifier tabs must preserve the physical control")
choose("JUMP")
assert(ConsoleExperience.GetControllerBindingAction("CTRL-2")=="JUMP" and view.info[2].binding==nil)
assert(view.placeButton:IsEnabled()==1,"a spell can still replace a system action")
choose(nil)
config:SelectBindingSlot(2)
assert(config:OpenBindingActionMenu())
local capturedSlotChoice
for _,entry in ipairs(picker.entries) do if entry.id=="JUMP" then capturedSlotChoice=entry; break end end
assert(capturedSlotChoice,"bounded picker should include proxied system actions")
config:SetBindingPage(3)
assert(not picker:Choose(capturedSlotChoice) and ConsoleExperience.proxied:GetSlotBinding(22)==nil,
    "changing modifier page while open must not redirect an action-slot assignment")
config:SetBindingPage(1); config:SelectBindingSlot(2)
model:Invoke(view.placeButton,"OnClick")
assert(picker.systemAssignment and picker.systemAssignment.kind=="slot" and picker.category=="spells",
    "Bind Spell or Item opens the scrollable spell category for the selected slot")
config.frame:Show()
config:Set("controllerType","ps")
assert(string.find(view.body.texture[1],"bindings\\ps",1,true) and string.find(view.tabs[2]:GetText(),"L2",1,true))
assert(string.find(row(2).glyph.texture[1],"controllers\\ps\\x",1,true))
config:Set("sideBarLeftEnabled",true); config:Set("sideBarRightEnabled",false)
config:Set("sideBarLeftButtons",3); config:SetBindingPage(5)
assert(not view.body:IsShown() and view.pageRow.valueText:GetText()~="" and view.selectedSlot==41)
assert(view.rows[3]:IsShown() and not view.rows[4]:IsShown() and not view.rows[6]:IsShown(),"touch view must respect both enabled state and count")
config:SelectBindingSlot(43); config:Set("sideBarLeftButtons",2)
assert(view.selectedSlot==41 and not view.rows[3]:IsShown(),"shrinking the touch bar must leave a visible selection")
config:Set("sideBarLeftEnabled",false)
assert(view.page==1 and not view.tabs[5]:IsShown() and not view.body:IsShown(),"disabling the last touch bar must restore controller view")
bonus=72; model:Invoke(view.section,"OnEvent")
assert(view.info[2].actionSlot==74 and view.info[2].name=="Overpower","the base layer must show the current stance or form")
bonus=0; model:Invoke(view.section,"OnEvent")
assert(view.info[2].name=="Frostbolt")
config:Set("uiTextScale",1.2)
for _,button in ipairs(view.rows) do
    assert(button.title:GetStringHeight()<=button.title:GetHeight(),"ability name clips at enlarged text")
    assert(button:GetLeft()>=view.section:GetLeft() and button:GetRight()<=view.section:GetRight(),"row overflows the content panel")
end
assert(model.named.CEBindingEditor:GetBottom()>=view.section:GetBottom(),"editor falls below the settings panel")
for _,button in ipairs({view.changeButton,view.placeButton,model.named.CEConfigResetBindings,model.named.CEBindingOpenKeyBindings}) do
    assert(button:GetFontString():GetStringWidth()<=button:GetWidth()-12,"localized button caption exceeds its available width: "..button:GetName())
end
for _,tab in ipairs(view.tabs) do if tab:IsShown() then
    assert(tab:GetLeft()>=view.section:GetLeft() and tab:GetRight()<=view.section:GetRight(),"modifier tabs overflow")
end end
load("cursor/cursor.lua")
ConsoleExperience.cursor:UpdateCursorPosition(row(7))
assert(view.selectedSlot==7 and not view.controls[7]:IsShown() and not view.controls[2]:IsShown(),"D-pad focus must update the editor and diagram")
config:Set("uiTheme","grove"); config:Set("controllerType",arg[4] or "xbox")
assert(row(7).marker.vertex[2]==theme:Palette().focus[2],"theme changes must recolor existing selection art")
assert(WindrunnerExperienceDB.proxiedActions[30]=="CE_INTERACT","unrelated assignments must survive every view change")
UIParent:SetWidth(800); UIParent:SetHeight(600); config:UpdateFrameScale()
assert(config.frame:GetScale()*config.FRAME_WIDTH<=768 and config.frame:GetScale()*config.FRAME_HEIGHT<=568,"centered binding screen must fit small displays")
UIParent:SetWidth(1920); UIParent:SetHeight(1080); config:UpdateFrameScale()
ConsoleExperience.cursor:Hide()
config:SelectBindingSlot(2)
local openedGameBindings=false
KeyBindingFrame=CreateFrame("Frame","KeyBindingFrame",UIParent)
KeyBindingFrame_LoadUI=function() end
ShowUIPanel=function(frame) openedGameBindings=frame==KeyBindingFrame and not config.frame:IsShown() end
model:Invoke(model.named.CEBindingOpenKeyBindings,"OnClick")
assert(openedGameBindings,"the game binding screen must open in front of the dismissed settings panel")
KeyBindingFrame:Hide(); config.frame:Show()
local inputs=ConsoleExperience.controllerControls
model:Invoke(view.modeButtons.controls,"OnClick")
assert(view.mode=="controls" and table.getn(view.controlRows)==10 and view.modeRow:IsShown() and view.pageRow:IsShown())
assert(view.selectedInput=="LS" and not view.nativeMarker:IsShown() and not view.placeButton:IsShown())
assert(inputs:GetBinding("LS")=="TARGETNEARESTENEMY" and inputs:GetBinding("RS")=="CE_TOGGLE_POINTER")
assert(config:OpenBindingActionMenu())
local capturedControlChoice
for _,entry in ipairs(picker.entries) do if entry.id=="JUMP" then capturedControlChoice=entry; break end end
assert(capturedControlChoice)
config:SelectControllerInput("START")
assert(not picker:Choose(capturedControlChoice) and inputs:GetBinding("START")=="CE_TOGGLE_RADIAL",
    "changing selected control while open must not redirect its system action")
config:SelectControllerInput("LS")
assert(config:OpenBindingActionMenu())
capturedControlChoice=nil
for _,entry in ipairs(picker.entries) do if entry.id=="JUMP" then capturedControlChoice=entry; break end end
config:SetBindingPage(2)
assert(not picker:Choose(capturedControlChoice) and inputs:GetBinding("LS",2)=="TARGETNEARESTENEMY",
    "changing modifier page while open must not redirect an auxiliary assignment")
config:SetBindingPage(1); config:SelectControllerInput("LS")
config:SelectControllerInput("LS"); choose("JUMP")
assert(config:Get("controllerLeftStickClick")=="JUMP" and inputs:GetBinding("LS")=="JUMP")
assert(WindrunnerExperienceDB.proxiedActions[1]==nil and WindrunnerExperienceDB.proxiedActions[30]=="CE_INTERACT",
    "auxiliary assignments must not move or clear any action-slot assignment")
config:SelectControllerInput("START"); choose("TOGGLEGAMEMENU")
config:SelectControllerInput("BACK"); choose("NONE")
assert(inputs:GetBinding("START")=="TOGGLEGAMEMENU" and inputs:GetBinding("BACK")=="NONE")
config:SelectControllerInput("RS"); choose("CE_TOGGLE_RADIAL")
assert(inputs:GetBinding("RS")=="CE_TOGGLE_RADIAL")
config:SelectControllerInput("PAUSE")
assert(not view.changeButton.enabled and not view.placeButton:IsShown(),"reserved controls must not offer an action-slot editor")
config:SelectControllerInput("RT")
assert(not view.changeButton.enabled and view.controlTuning:IsShown())
assert(not inputs:SetBinding("RT","JUMP") and not inputs:SetBinding("LS","arbitrary-command"),"fixed and unknown actions must reject edits")
config:Set("controllerType","ps"); config:SelectControllerInput("LS")
assert(string.find(view.editorTitle:GetText(),"L3",1,true))
config:SelectControllerInput("START"); assert(string.find(view.editorTitle:GetText(),ConsoleExperience.locale.T("Options"),1,true))
config:SelectControllerInput("PAUSE"); assert(string.find(view.editorTitle:GetText(),ConsoleExperience.locale.T("Share"),1,true))
for _,button in ipairs(view.controlRows) do
    assert(button.title:GetStringHeight()<=button.title:GetHeight(),"control input name clips at enlarged text: "..button.input)
    assert(button.value:GetStringHeight()<=button.value:GetHeight(),"control action name clips at enlarged text: "..button.input)
end
assert(view.controlNotice:GetStringHeight()<=view.controlNotice:GetHeight(),"native availability note clips")
for _,button in pairs(view.modeButtons) do
    assert(button:GetFontString():GetStringWidth()<=button:GetWidth()-12,"mode caption clips")
end
assert(view.resetButton:GetFontString():GetStringWidth()<=view.resetButton:GetWidth()-12)
model:Invoke(view.resetButton,"OnClick")
assert(inputs:GetBinding("LS")=="TARGETNEARESTENEMY" and inputs:GetBinding("START")=="CE_TOGGLE_RADIAL" and inputs:GetBinding("BACK")=="TOGGLEWORLDMAP")
assert(WindrunnerExperienceDB.proxiedActions[30]=="CE_INTERACT","resetting controls must preserve action slots")
-- Each modifier page can override auxiliary inputs without replacing the base.
config:SetBindingPage(2)
assert(view.mode=="controls" and view.tabs[2].themeSelected,"modifier tabs must retain the auxiliary editor")
config:SelectControllerInput("LS"); choose("JUMP")
assert(inputs:GetBinding("LS",2)=="JUMP" and inputs:GetBinding("LS",1)=="TARGETNEARESTENEMY")
assert(inputs:GetBinding("LS",3)=="TARGETNEARESTENEMY","unassigned pages must inherit the base")
config:SetBindingPage(3); config:SelectControllerInput("START"); choose("NONE")
assert(inputs:GetBinding("START",3)=="NONE" and inputs:GetBinding("START",2)=="CE_TOGGLE_RADIAL")
config:SetBindingPage(1)

model:Invoke(view.modeButtons.actions,"OnClick")
assert(view.mode=="actions" and view.pageRow:IsShown() and view.changeButton.enabled and view.placeButton:IsShown())
for _,button in ipairs(view.controlRows) do for _,line in ipairs(button.lines) do assert(not line:IsShown(),"control callouts must hide with their view") end end
-- Profile saves and direct profile loads must keep auxiliary assignments and refresh the live view.
load("config/profiles.lua")
local profiles=ConsoleExperience.profiles
profiles.SaveActionBars=function() return {} end; profiles.LoadActionBars=function() end
config.UpdateCrosshair=function() end; config.UpdateActionBarLayout=function() end
inputs:SetBinding("LS","JUMP"); inputs:SetBinding("START","NONE")
profiles:SaveCurrentProfile()
assert(WindrunnerExperienceDB.profiles.Default.config.controllerLeftStickClick=="JUMP"
    and WindrunnerExperienceDB.profiles.Default.config.controllerStartButton=="NONE")
assert(profiles:CreateProfile("DefaultControls"))
config:SetBindingMode("controls")
profiles:LoadProfile("DefaultControls")
assert(inputs:GetBinding("LS")=="TARGETNEARESTENEMY" and inputs:GetBinding("START")=="CE_TOGGLE_RADIAL",
    "new profiles must restore the auxiliary defaults")
profiles:LoadProfile("Default")
assert(inputs:GetBinding("LS")=="JUMP" and inputs:GetBinding("START")=="NONE")
assert(view.controlRows[1].value:GetText()==inputs:GetInputInfo("LS").name,"profile loading must update an existing control row")
model:Invoke(view.resetButton,"OnClick"); config:SetBindingMode("actions")
if arg[5]=="controls" then config:Set("controllerType",arg[4] or "xbox"); config:SetBindingMode("controls"); config:SelectControllerInput("RS") end
if arg[6]=="picker" then
    config.frame:Show(); config:SelectBindingSlot(2); config:OpenBindingActionMenu()
end
if arg[2] then
    local function str(s)
        s=type(s)=="string" and s or ""
        return '"'..string.gsub(string.gsub(string.gsub(s,"\\","\\\\"),'"','\\"'),"\n","\\n")..'"'
    end
    local function color(value) return value and ('['..table.concat(value,",")..']') or "null" end
    local out=assert(io.open(arg[2],"w")); out:write('[')
    local first=true
    for _,frame in ipairs(model.objects) do if frame:IsVisible() then
        local l,b,w,h=frame:Rect(); local depth,parent=0,frame.parent
        while parent do depth=depth+1; parent=parent.parent end
        if not first then out:write(',') end; first=false
        out:write('{"kind":'..str(frame.kind)..',"name":'..str(frame.name)..',"layer":'..str(frame.layer)..',"depth":'..depth..',"x":'..l..',"y":'..b..',"w":'..w..',"h":'..h..',"text":'..str(frame.kind=="FontString" and frame.text or "")..',"size":'..frame.fontSize..',"justify":'..str(frame.justify)..',"bg":'..color(frame.background)..',"border":'..color(frame.border)..',"vertex":'..color(frame.vertex)..',"texture":'..str(frame.texture and type(frame.texture[1])=="string" and frame.texture[1] or "")..',"color":'..color(frame.textColor)..',"uv":'..color(frame.uv)..',"circular":'..tostring(frame.circular or false)..'}')
    end end
    out:write(']'); out:close()
end
print("PASS: visual binding editor, modifier slots, all supported inputs, auxiliary remaps/resets/profiles, Xbox/PS labels, touch visibility, stance names, controller focus, themes, and enlarged/small-screen layout.")

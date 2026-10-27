-- Actual item menu, cursor focus, tooltip bindings and native routes under Lua 5.0.
local root=assert(arg[1],"pass the addon root")
local model=assert(loadfile("tests/ui-model.lua"))()
local create=model.Create
function model:Create(kind,name,parent,template)
    assert(kind~="Cooldown","Vanilla cooldowns must use Model with CooldownFrameTemplate")
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
    function frame:SetMaxLetters(value) self.maxLetters=value end
    function frame:SetMultiLine(value) self.multiLine=value end
    function frame:SetFontObject(value) self.fontObject=value end
    function frame:GetTextInsets() return 0,0,0,0 end
    function frame:SetTextInsets(...) self.insets=arg end
    function frame:GetAlpha() return self.alpha end
    function frame:SetVerticalScroll(value) self.verticalScroll=value end
    function frame:GetVerticalScroll() return self.verticalScroll or 0 end
    function frame:GetVerticalScrollRange() return math.max(0,(self.scrollChild and self.scrollChild:GetHeight() or 0)-self:GetHeight()) end
    if kind=="ScrollFrame" then function frame:GetScrollChild() return self.scrollChild end end
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

GameMenuFrame=CreateFrame("Frame","GameMenuFrame",UIParent)
ChatFrame1=CreateFrame("Frame","ChatFrame1",UIParent)
UnitClass=function() return "Warrior","WARRIOR" end
UnitName=function() return "Player" end
UnitLevel=function() return 60 end
UnitExists=function() return false end
UnitIsPlayer=function() return false end
UnitIsFriend=function() return false end
RAID_CLASS_COLORS={WARRIOR={r=.78,g=.61,b=.43}}
GetNumSpellTabs=function() return 0 end
GetSpellName=function() end
GetSpellTexture=function() end
GetContainerNumSlots=function() return 0 end
GetContainerItemInfo=function() end
GetContainerItemLink=function() end
GetPetActionInfo=function() end
GetPetActionCooldown=function() return 0,0,0 end
HasPetUI=function() return nil end
PetHasActionBar=HasPetUI
GetBonusBarOffset=function() return 0 end
GetTime=function() return 1 end
GetMacroInfo=function() end
GetActionText=function() end
HasAction=function() return false end
CursorHasItem=function() return false end
CursorHasSpell=CursorHasItem; CursorHasMoney=CursorHasItem; SpellIsTargeting=CursorHasItem
IsShiftKeyDown=CursorHasItem; IsControlKeyDown=CursorHasItem
SetPortraitTexture=function(icon,unit) icon:SetTexture("portrait:"..unit) end
SetPortraitToTexture=function(icon,path) icon.portrait=path; icon:SetTexture(path) end
function model:GetFrames() return self.frames end
SetBinding=function() error("must not change physical bindings") end
BOOKTYPE_SPELL="spell"; GameFontHighlightSmall={}
tinsert=table.insert
local entries={}
UIDropDownMenu_Initialize=function(dropdown,fn) dropdown.initialize=fn end
UIDropDownMenu_SetText=function(text,dropdown) dropdown.text=text end
UIDropDownMenu_SetWidth=function(width,dropdown) dropdown:SetWidth(width) end
UIDropDownMenu_SetSelectedValue=function(dropdown,value) dropdown.selectedValue=value end
UIDropDownMenu_GetSelectedValue=function(dropdown) return dropdown.selectedValue end
UIDropDownMenu_AddButton=function(info) table.insert(entries,info) end
CloseDropDownMenus=function() end
local function load(path) assert(loadfile(root.."/"..path))() end
load("locale/locale.lua"); load("locale/translations_enUS.lua"); load("locale/translations_deDE.lua")
load("ui/theme.lua"); load("config/controls.lua"); load("WindrunnerControllerIntegration.lua"); load("WindrunnerController.lua")
load("cursor/cursor.lua"); load("cursor/tooltip.lua"); load("cursor/actions.lua"); load("cursor/keybindings.lua"); load("cursor/hooks.lua")
load("config/profiles.lua"); load("config/proxied.lua"); load("config/config.lua")
load("config/bindings.lua"); load("config/control-view.lua"); load("config/appearance.lua")
load("radial/radial.lua"); load("radial/rings.lua"); load("config/actionpicker.lua")
load("actionbars/pet.lua"); load("cursor/unitmenu.lua"); load("cursor/lootpanel.lua")
load("keyboard/keyboard.lua"); load("keyboard/suggestions.lua")
load("config/setup.lua"); load("config/sharing.lua"); load("config/features.lua")
load("config/rows.lua"); load("config/navigation.lua")
local config,controller=ConsoleExperience.config,WindrunnerController
controller.Release=function(self) self.armed=false end
config:CreateMainFrame(); config.frame:Show(); config:ShowSection("gameplay")
assert(config.contentSections.gameplay and config.contentSections.gameplay:IsVisible(),"Gameplay must show its registered scroll content")
local gameplayButtons=0
for _,object in ipairs(model.objects) do
    local parent=object.parent
    while parent and parent~=config.contentSections.gameplay do parent=parent.parent end
    if parent and object:IsVisible() and object.kind=="Button" then gameplayButtons=gameplayButtons+1 end
end
assert(gameplayButtons>=7,"Gameplay tools and layout editor must be visible")
-- Vanilla FontStrings do not render modern inline texture tags.
local oldNative,oldMouse=controller.HasNativeInput,controller.HasMouseBridge
local oldType,oldPreset,oldModifiers=WindrunnerExperienceDB.config.controllerType,WindrunnerExperienceDB.config.controllerPromptPreset,WindrunnerExperienceDB.config.controllerModifierSource
controller.HasNativeInput=function() return true end
controller.HasMouseBridge=function() return false end
local function DescendantText(section)
    local text={}
    for _,object in ipairs(model.objects) do
        local parent=object.parent
        while parent and parent~=section do parent=parent.parent end
        if parent and object.kind=="FontString" and object.text then
            assert(not string.find(object.text,"|T",1,true),"Vanilla help must not expose inline texture markup")
            table.insert(text,object.text)
        end
    end
    return table.concat(text,"\n")
end
for _,device in ipairs({{"xbox","standard"},{"ps","standard"},{"xbox","switch"},{"xbox","deck"}}) do
    WindrunnerExperienceDB.config.controllerType=device[1]
    WindrunnerExperienceDB.config.controllerPromptPreset=device[2]
    for _,source in ipairs({"triggers","bumpers"}) do
        WindrunnerExperienceDB.config.controllerModifierSource=source
        config:RefreshControllerType()
        local text=DescendantText(config.contentSections.controller)
        local label=ConsoleExperience.controllerControls:GetPromptLabel(source=="bumpers" and "LB" or "LT")
        assert(string.find(text,label..": "..ConsoleExperience.locale.T("Shift modifier"),1,true),
            "Controller help must use the selected physical modifier label")
        DescendantText(config.contentSections.help)
    end
end
WindrunnerExperienceDB.config.controllerType=oldType
WindrunnerExperienceDB.config.controllerPromptPreset=oldPreset
WindrunnerExperienceDB.config.controllerModifierSource=oldModifiers
controller.HasNativeInput=oldNative; controller.HasMouseBridge=oldMouse
config:RefreshControllerType()
ConsoleExperience.cursor.tooltip:Initialize(); ConsoleExperience.cursor:Enable()
ConsoleExperience:RegisterQuickCollections()
-- Mapped controllers also cycle the owned radial collections using logical X.
local radial=ConsoleExperience.radial
radial:Show()
local radialBindings=ConsoleExperience.cursor.tooltip:GetBindings("CERadialButton1",nil,radial.buttons[1])
local mappedMore=false
for _,binding in ipairs(radialBindings) do if binding.key=="2" and binding.action=="CE_RADIAL_MORE" then mappedMore=true end end
assert(mappedMore,"radial X must expose next collection to mapped input")
controller:DispatchSlot(2)
assert(radial.collectionTitle,"mapped X must open a collection")
controller:DispatchSlot(4)
assert(not radial:IsVisible(),"mapped cancel closes the wheel")

assert(ConsoleExperience.radial.collections.Tools and ConsoleExperience.radial.collections.Professions)
ConsoleExperience.pet:Initialize()
assert(not ConsoleExperience.pet:IsVisible(),"the pet HUD must not consume native menu input")
ConsoleExperience.setup:Show()
assert(controller:IsMenuActive() and ConsoleExperience.setup:IsVisible())
ConsoleExperience.setup:Back()
ConsoleExperience.sharing:Show()
assert(controller:IsMenuActive() and ConsoleExperience.sharing:IsVisible())
ConsoleExperience.sharing:Back()
ConsoleExperience.rings:OpenEditor()
assert(controller:IsMenuActive() and ConsoleExperience.rings:IsVisible())
ConsoleExperience.rings:Back()
ConsoleExperience.actionpicker:Open(1)
assert(controller:IsMenuActive() and ConsoleExperience.actionpicker:IsVisible())
ConsoleExperience.actionpicker:Back()
-- Layout movement owns both native and mapped input, including pointer mode.
local previousLayout=ConsoleExperience.layout
local layoutCalls={}
local layout={active=true,moving=true}
function layout:IsVisible() return self.active end
function layout:IsMoving() return self.active and self.moving end
function layout:HandleInput(slot) table.insert(layoutCalls,slot); return true end
function layout:HandleDirection(direction) self.direction=direction; return self:IsMoving() end
function layout:ConfirmMove() self.confirmed=true; return self:IsMoving() end
function layout:Back() self.back=true end
function layout:FinishEditing() self.finished=true end
ConsoleExperience.layout=layout
local movePrompts=ConsoleExperience.cursor.tooltip:GetActions("CELayoutTargetchat",nil,nil)
assert(movePrompts[1].prompt==ConsoleExperience.locale.T("Save") and movePrompts[2].prompt==ConsoleExperience.locale.T("Cancel"),
    "moving layout advertises save and cancel")
assert(movePrompts[3].prompt==ConsoleExperience.locale.T("Done"),"layout exposes a direct finish shortcut")
local layoutBindings=ConsoleExperience.cursor.tooltip:GetBindings("CELayoutTargetchat",nil,nil)
local mappedFinish=false
for _,binding in ipairs(layoutBindings) do if binding.key=="2" and binding.action=="CE_CURSOR_BIND" then mappedFinish=true end end
assert(mappedFinish,"mapped layout finish reuses an existing registered binding")
assert(controller:IsMenuActive() and controller:IsGameplayBlocked(),"layout owns input before generic cursor focus arrives")
controller:DispatchSlot(7); assert(layoutCalls[1]==7,"native D-pad reaches the layout editor")
local oldSwap=WindrunnerExperienceDB.config.menuSwapConfirm
WindrunnerExperienceDB.config.menuSwapConfirm=true
controller:DispatchSlot(4); assert(layoutCalls[2]==1,"layout uses the configured logical confirm button")
WindrunnerExperienceDB.config.menuSwapConfirm=oldSwap
local savedButton=ConsoleExperience.cursor.navigationState.currentButton
ConsoleExperience.cursor.navigationState.currentButton=nil
CE_MoveCursor("UP"); assert(layout.direction=="UP","mapped D-pad reaches moving layout without a cursor button")
CE_ClickCursor("LeftButton"); assert(layout.confirmed,"mapped confirm saves the moving layout")
CE_CloseFrame(); assert(layout.back,"mapped cancel returns to layout target selection")
CE_Bind(); assert(layout.finished,"mapped Square finishes editing without finding the Done button")
ConsoleExperience.cursor.navigationState.currentButton=savedButton
local oldMovementBridge,oldMouseBridge=WindrunnerController_SetMovement,WindrunnerController_Mouse
local movementMask,mouseState
WindrunnerController_SetMovement=function(mask) movementMask=mask; return true end
WindrunnerController_Mouse=function(x,y,buttons,mode) mouseState={x,y,buttons,mode}; return true end
local oldPointer,oldArmed,oldButtons=controller.pointer,controller.armed,controller.buttons
controller.pointer=true; controller.armed=true; controller.buttons=0
controller:ApplyInput(.02,1,0,0,1,1,1,1)
assert(layoutCalls[3]==7,"native pointer mode preserves layout D-pad control")
assert(movementMask==0,"layout never moves the character")
assert(mouseState[1]==0 and mouseState[2]==0 and mouseState[3]==0 and mouseState[4]==0,
    "moving the layout suppresses native pointer and camera input")
controller.pointer=oldPointer; controller.armed=oldArmed; controller.buttons=oldButtons
WindrunnerController_SetMovement=oldMovementBridge; WindrunnerController_Mouse=oldMouseBridge
ConsoleExperience.layout=previousLayout
ConsoleExperience.keyboard:CreateFrame()
assert(ConsoleExperience.keyboard.suggestionButtons and ConsoleExperience.keyboard.showPhrasesButton)
local keyboard=ConsoleExperience.keyboard
keyboard.suggestionStrip:ClearAllPoints(); keyboard.suggestionStrip:SetWidth(360)
keyboard.suggestionStrip:SetPoint("TOPLEFT",keyboard.frame,"TOPLEFT",8,-8)
keyboard:UpdateSuggestionLayout()
for i=1,2 do assert(keyboard.suggestionButtons[i]:GetRight()+3<=keyboard.suggestionButtons[i+1]:GetLeft(),"suggestion buttons must not overlap") end
assert(keyboard.suggestionButtons[3]:GetRight()+3<=keyboard.showPhrasesButton:GetLeft(),"suggestions must leave space for saved phrases")

ConsoleExperience.keyboard:ShowPhraseManager()
assert(ConsoleExperience.keyboard.phraseFrame.ceNavigationModal)
ConsoleExperience.keyboard.phraseFrame:Hide()
config:Set("uiTextScale",1.2)
UIParent:SetWidth(800); UIParent:SetHeight(600)
for _,module in ipairs({ConsoleExperience.setup,ConsoleExperience.sharing,ConsoleExperience.actionpicker}) do
    if module.Show then module:Show() end
    local frame=module.frame
    assert(frame:GetWidth()*frame:GetScale()<=768,"popup width must fit")
    assert(frame:GetHeight()*frame:GetScale()<=568,"popup height must fit: "..frame:GetName().." "..frame:GetHeight()*frame:GetScale())
    module:Back()
end
ConsoleExperience.rings:OpenEditor()
assert(ConsoleExperience.rings.editor:GetWidth()*ConsoleExperience.rings.editor:GetScale()<=768)
assert(ConsoleExperience.rings.editor:GetHeight()*ConsoleExperience.rings.editor:GetScale()<=568)
local ringName=ConsoleExperience.rings.editor.nameEdit
assert(ringName.HasFocus==nil,"stock Vanilla edit boxes have no HasFocus method")
model:Invoke(ringName,"OnEditFocusGained")
ringName:SetText("Name being edited")
ConsoleExperience.rings:RefreshEditor()
assert(ringName:GetText()=="Name being edited","ring refresh must preserve an in-progress name")
model:Invoke(ringName,"OnEditFocusLost")
ConsoleExperience.rings:RefreshEditor()
assert(ringName:GetText()~="Name being edited","unfocused names follow the selected ring")
-- Profiles own their nested ring snapshots and clear rings absent from older saves.
local profiles=ConsoleExperience.profiles
local applyBindings=ConsoleExperience.proxied.ApplyAllBindings
local updateCrosshair=config.UpdateCrosshair
local updateActionBarLayout=config.UpdateActionBarLayout
ConsoleExperience.proxied.ApplyAllBindings=function() end
config.UpdateCrosshair=function() end; config.UpdateActionBarLayout=function() end
local rings=ConsoleExperience.rings
assert(rings:Create("Profile utility"))
assert(rings:Add({kind="item",itemID=123,name="Test item"},1))
WindrunnerExperienceDB.config.barLeftX=-240; WindrunnerExperienceDB.config.petBarY=310
profiles:SaveCurrentProfile()
local saved=profiles:GetProfile("Default")
assert(saved.config.utilityRings~=WindrunnerExperienceDB.config.utilityRings)
WindrunnerExperienceDB.config.utilityRings[1].entries[1].itemID=456
assert(saved.config.utilityRings[1].entries[1].itemID==123,"editing live rings must not change a saved snapshot")
assert(profiles:CreateProfile("Ring clone","Default"))
local clone=profiles:GetProfile("Ring clone")
clone.config.utilityRings[1].entries[1].itemID=789
assert(saved.config.utilityRings[1].entries[1].itemID==123,"cloned ring entries must be independent")
clone.actionBars=nil
local profileLayoutRefreshes=0
local previousLayout=ConsoleExperience.layout
ConsoleExperience.layout={Refresh=function()
    profileLayoutRefreshes=profileLayoutRefreshes+1
    assert(WindrunnerExperienceDB.config.barLeftX==-240 and WindrunnerExperienceDB.config.petBarY==310)
end}
assert(profiles:LoadProfile("Ring clone"))
assert(profileLayoutRefreshes==1,"profile loading must refresh independent bars and pet position")
assert(WindrunnerExperienceDB.config.utilityRings[1].entries[1].itemID==789)
assert(radial.collections["Ring: Profile utility"])
ConsoleExperience.layout=previousLayout
WindrunnerExperienceDB.profiles.LegacyEmpty={config={},proxiedActions={}}
assert(profiles:LoadProfile("LegacyEmpty"))
assert(table.getn(rings:GetAll())==0 and not radial.collections["Ring: Profile utility"],
    "old profiles without rings must clear the previous profile's rings and collections")
assert(table.getn(config.DEFAULTS.utilityRings)==0,"profile edits must not mutate ring defaults")
ConsoleExperience.proxied.ApplyAllBindings=applyBindings
config.UpdateCrosshair=updateCrosshair; config.UpdateActionBarLayout=updateActionBarLayout
-- Delayed profile layout must not reopen the page the user just left.
ConsoleExperience.rings:Back()
ConsoleExperience.keyboard.frame:Hide()
config:ShowSection("controller"); model:Tick(); model:Tick()
assert(config.currentSection=="controller","a deferred profile refresh must preserve a newly selected page")
local cursor=ConsoleExperience.cursor
cursor:SetNavigationLockFrame(config.frame)
cursor:MoveCursorToButton(config.sidebarButtons.controller)
CE_MoveCursor("UP")
assert(cursor.navigationState.currentButton==config.sidebarButtons.controller,"category edges must stay put")
CE_MoveCursor("DOWN")
assert(config.currentSection=="appearance" and cursor.navigationState.currentButton==config.sidebarButtons.appearance,
    "category navigation previews the page and retains category focus: " .. tostring(config.currentSection) .. " / "
        .. tostring(cursor.navigationState.currentButton and cursor.navigationState.currentButton:GetName()) .. " / lock "
        .. tostring(cursor.navigationState.navigationLockFrame and cursor.navigationState.navigationLockFrame:GetName()))
CE_MoveCursor("UP"); model:Tick(); model:Tick()
local stickRow=model.named.CEControllerRadialStick
config:Set("radialSelectionStick","left"); cursor:MoveCursorToButton(stickRow)
CE_MoveCursor("RIGHT"); assert(config:Get("radialSelectionStick")=="right" and cursor.navigationState.currentButton==stickRow)
CE_MoveCursor("RIGHT"); assert(config:Get("radialSelectionStick")=="both" and cursor.navigationState.currentButton==stickRow)
CE_MoveCursor("RIGHT"); assert(config:Get("radialSelectionStick")=="both","choice row clamps at its end")
CE_MoveCursor("LEFT"); assert(config:Get("radialSelectionStick")=="right","left adjusts the same row without leaving the page")
CE_CloseFrame(); assert(config.frame:IsVisible() and cursor.navigationState.currentButton==config.sidebarButtons.controller,
    "Back returns from settings to categories")
CE_MoveCursor("RIGHT"); assert(cursor.navigationState.currentButton==stickRow,"returning restores the remembered setting")
cursor:MoveCursorToButton(model.named.CEControllerOpenKeyBindings)
assert(config.contentSections.controller.scrollFrame:GetVerticalScroll()>0,"offscreen settings must scroll into view when focused: "
    .. model.named.CEControllerOpenKeyBindings:GetBottom() .. " / viewport " .. config.contentSections.controller.scrollFrame:GetBottom()
    .. " / child height " .. config.contentSections.controller:GetHeight())
local modal=CreateFrame("Frame","MenuNavigationTestModal",UIParent)
cursor.navigationState.navigationLockFrame=modal
assert(not config:HandleNavigation("LEFT") and not config:HandleBack(),"a popup must keep exclusive navigation ownership")
modal:Hide(); cursor:SetNavigationLockFrame(config.frame)
-- Every page presents one vertical focus sequence, including former columns,
-- numeric steppers, dropdowns, binding inputs and profile actions.
for _,id in ipairs({"interface","bars","profiles","help","gameplay","appearance","bindings","controller"}) do
    config:ShowSection(id); model:Tick(); model:Tick()
    local buttons=cursor:CollectVisibleButtons(config.contentSections[id])
    local rows={}
    for _,info in ipairs(buttons) do
        if info.button.ceSettingsLabel then assert(info.button.ceSettingsLabel:IsShown(),"the row label must stay visible: "..tostring(info.button:GetName())) end
        local _,y=(info.button.ceSettingsRow or info.button):GetCenter()
        table.insert(rows,{y=y,name=info.button:GetName()})
    end
    table.sort(rows,function(a,b) return a.y>b.y end)
    for i=2,table.getn(rows) do
        assert(rows[i-1].y-rows[i].y>20,"settings require one focus stop per row: "..id.." / "..tostring(rows[i-1].name).." / "..tostring(rows[i].name).." y "..rows[i-1].y.." / "..rows[i].y)
    end
end
config:ShowSection("interface"); model:Tick(); model:Tick()
local deviceButton=model.named.CEConfigControllerTypeDropdownButton
config:Set("controllerType","xbox"); config:RefreshControllerType()
cursor:MoveCursorToButton(deviceButton); CE_MoveCursor("RIGHT")
assert(config:Get("controllerType")=="ps" and cursor.navigationState.currentButton==deviceButton,"a dropdown changes in place with right: "..tostring(config:Get("controllerType")).." selected "..tostring(model.named.CEConfigControllerTypeDropdown.selectedValue).." adjust "..tostring(deviceButton.cursorAdjust).." focus "..tostring(cursor.navigationState.currentButton and cursor.navigationState.currentButton:GetName()))
CE_MoveCursor("LEFT"); assert(config:Get("controllerType")=="xbox","a dropdown changes back with left")
config:ShowSection("bars"); model:Tick(); model:Tick()
local sizeField
for _,object in ipairs(model.objects) do if object.kind=="EditBox" and object.label==ConsoleExperience.locale.T("Button Size") then sizeField=object end end
assert(sizeField and sizeField.ceSettingsRow)
config:Set("barButtonSize",60); config:RefreshProfileControls(config.contentSections.bars)
cursor:MoveCursorToButton(sizeField); CE_MoveCursor("RIGHT")
assert(config:Get("barButtonSize")==61 and cursor.navigationState.currentButton==sizeField,"numeric rows adjust without entering typing or focusing an arrow")
CE_MoveCursor("LEFT"); assert(config:Get("barButtonSize")==60)
CE_MoveCursor("DOWN"); assert(cursor.navigationState.currentButton~=sizeField and not cursor.navigationState.currentButton.cursorIgnore,"down reaches the next preference")
config:ShowSection("controller"); model:Tick(); model:Tick()
cursor:MoveCursorToButton(config.sidebarButtons.controller)
CE_CloseFrame(); assert(not config.frame:IsVisible(),"Back from categories closes the settings window")
if arg[4] then
    ConsoleExperience.rings:Back()
    for _,frame in ipairs({ConsoleExperience.keyboard.frame,ConsoleExperience.pet.frame}) do if frame then frame:Hide() end end
    model.named.WindrunnerControllerModeHint:Hide()
    UIParent:SetWidth(1600); UIParent:SetHeight(1000); config:Set("uiTextScale",1)
    config:Set("controllerType",arg[3] or "xbox")
    if arg[5]=="setup" then config.frame:Hide(); ConsoleExperience.setup:Show()
    elseif arg[5]=="pet" then config.frame:Hide(); ConsoleExperience.pet:ShowAbilities()
    elseif arg[5]=="picker" then config.frame:Hide(); ConsoleExperience.actionpicker:Open(1)
    elseif arg[5]=="sharing" then config.frame:Hide(); ConsoleExperience.sharing:Show()
    elseif arg[5]=="radial" then config.frame:Hide(); controller:SetScript("OnUpdate",nil); ConsoleExperience.radial:Show(); ConsoleExperience.radial:SetSelected(1)
    else
        if arg[5]=="controller" then
            controller:SetScript("OnUpdate",nil)
            controller.HasNativeInput=function() return true end
            controller.HasMouseBridge=function() return true end
            controller.connected=true; controller.foreground=true; controller.world=true; controller.armed=true; controller.hasRawInput=true; controller.paused=false
        end
        config.frame:Show(); config:ShowSection(config.contentSections[arg[5] or ""] and arg[5] or "gameplay")
        cursor:MoveCursorToButton(config.sidebarButtons[config.currentSection])
    end
    for i=1,12 do model:Tick() end
    model.named.WindrunnerControllerModeHint:Hide()
    if arg[6]=="labels" then
        local scroll=config.contentSections.appearance.scrollFrame
        scroll:SetVerticalScroll(scroll:GetVerticalScrollRange())
    end
    local out=assert(io.open(arg[4],"w"))
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
                    b=b+ancestor:GetVerticalScroll()
                    local cl,cb,cw,ch=ancestor:Rect()
                    clip='['..cl..','..cb..','..cw..','..ch..']'; break
                end
                ancestor=ancestor.parent
            end
            if not first then out:write(',') end; first=false
            out:write('{"id":'..frame.previewId..',"parent":'..(frame.parent and frame.parent.previewId or 0)..',"layer":'..str(frame.drawLayer)..',"strata":'..str(frame.strata)..',"level":'..(frame.level or 0)..',"font":'..str(frame.font)..',"valign":'..str(frame.justifyV)..',"alpha":'..frame.alpha..',"bgTexture":'..str(frame.backdrop and frame.backdrop.bgFile)..',"kind":'..str(frame.kind)..',"name":'..str(frame.name)..',"x":'..l..',"y":'..b..',"w":'..w..',"h":'..h..',"text":'..str(frame.kind=="FontString" and frame.text or "")..',"size":'..frame.fontSize..',"justify":'..str(frame.justify)..',"clip":'..clip..',"bg":'..color(frame.background)..',"border":'..color(frame.border)..',"vertex":'..color(frame.vertex)..',"texture":'..str(frame.texture and type(frame.texture[1])=="string" and frame.texture[1] or "")..',"color":'..color(frame.textColor)..'}')
        end
    end
    out:write(']'); out:close()
end
print("PASS: feature registration, complete gameplay settings, modal input ownership, stock-only APIs and small-screen popup fitting.")

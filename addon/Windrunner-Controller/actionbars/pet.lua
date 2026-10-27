local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
-- Vanilla pet controls. All cast, autocast, pickup and command calls occur
-- only from explicit button/controller callbacks.
ConsoleExperience.pet = { initialized=false, buttons={}, abilityButtons={} }
local Pet = ConsoleExperience.pet

local function L(key) return ConsoleExperience.locale.T(key) end
local function Flag(value) return value and value ~= 0 end
local function Text(parent,size,role)
    local value=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    local scale=ConsoleExperience.theme:Get("uiTextScale") or 1
    value:SetFont("Fonts\\FRIZQT__.TTF",size*scale,"")
    ConsoleExperience.theme:Register(value,role)
    return value
end
local function Fit(frame,width,height)
    local scale=ConsoleExperience.theme:Get("uiMenuScale") or 1
    if UIParent and UIParent.GetWidth and UIParent.GetHeight then
        scale=math.min(scale,(UIParent:GetWidth()-24)/width,(UIParent:GetHeight()-24)/height)
    end
    frame:SetScale(math.max(0.5,scale))
end

function Pet:ActionInfo(index)
    if not GetPetActionInfo then return end
    -- Exact 1.12 tuple: name, subtext, texture, isToken, isActive,
    -- autoCastAllowed, autoCastEnabled.
    local name,subtext,texture,isToken,active,autocastAllowed,autocastEnabled=GetPetActionInfo(index)
    if Flag(isToken) and getglobal then
        local resolved=texture and getglobal(texture)
        if resolved then texture=resolved end
        local token=name and getglobal(name)
        if token and TEXT then name=TEXT(token) elseif token then name=token end
    end
    return name,subtext,texture,Flag(active),Flag(autocastAllowed),Flag(autocastEnabled)
end

function Pet:RefreshButton(button)
    local index=button.petAction
    local name,subtext,texture,active,autocastAllowed,autocastEnabled=self:ActionInfo(index)
    if texture then
        if SetPortraitToTexture then SetPortraitToTexture(button.icon,texture) else button.icon:SetTexture(texture) end
        button.icon:Show()
    else button.icon:SetTexture(nil); button.icon:Hide() end
    button.petName=name
    button.label=name or (L("Pet action").." "..index)
    button.tooltipSubtext=subtext
    button.autocastAllowed=autocastAllowed
    button.autocastEnabled=autocastEnabled
    if active then button.active:Show() else button.active:Hide() end
    if autocastAllowed then
        button.autocast:SetText(autocastEnabled and "●" or "○")
        button.autocast:Show()
    else button.autocast:Hide() end
    local start,duration,enable=GetPetActionCooldown(index)
    local bars=ConsoleExperience.actionbars
    local modern=ConsoleExperience.config and ConsoleExperience.config:Get("barAppearance")=="modern" and bars and bars.StartCircularCooldown
    if button.cooldown and start and duration and duration>0 and Flag(enable) then
        if modern then button.cooldown:Hide(); bars:StartCircularCooldown(button,start,duration)
        else
            if bars and bars.StopCircularCooldown then bars:StopCircularCooldown(button) end
            CooldownFrame_SetTimer(button.cooldown,start,duration,enable); button.cooldown:Show()
        end
    else
        if button.cooldown then button.cooldown:Hide() end
        if bars and bars.StopCircularCooldown then bars:StopCircularCooldown(button) end
    end
    if name then button:Enable() else button:Disable() end
    ConsoleExperience.theme:Apply(button)
end

function Pet:Refresh()
    if not self.frame then return end
    local hasPet=Flag(PetHasActionBar and PetHasActionBar())
    if hasPet then self.frame:Show() else self.frame:Hide() end
    for i=1,10 do
        self:RefreshButton(self.buttons[i])
        if self.abilityButtons[i] then self:RefreshButton(self.abilityButtons[i]) end
    end
    if self.commandFrame and self.commandFrame:IsVisible() then self:RenderCommands() end
end

function Pet:Command(command)
    if not Flag(PetHasActionBar and PetHasActionBar()) then return false end
    local commands={attack=PetAttack,follow=PetFollow,stay=PetWait,passive=PetPassiveMode,
        defensive=PetDefensiveMode,aggressive=PetAggressiveMode}
    local fn=commands[command]
    if not fn then return false end
    fn()
    return true
end

function Pet:ActivateSlot(slot,mouseButton,shiftDown)
    if type(slot)~="number" or slot<1 or slot>10 or not GetPetActionInfo then return false end
    local held=(CursorHasSpell and CursorHasSpell()) or (CursorHasItem and CursorHasItem())
    if held and PickupPetAction then PickupPetAction(slot); return true end
    local name,_,_,_,autocastAllowed=self:ActionInfo(slot)
    if not name then return false end
    if shiftDown and PickupPetAction then PickupPetAction(slot)
    elseif mouseButton=="RightButton" and autocastAllowed and TogglePetAutocast then TogglePetAutocast(slot)
    elseif mouseButton~="RightButton" and IsPetAttackActive and Flag(IsPetAttackActive(slot)) and PetStopAttack then PetStopAttack()
    elseif mouseButton~="RightButton" and CastPetAction then CastPetAction(slot)
    else return false end
    return true
end

function Pet:BuildAbilityButton(parent,index,name,point,relative,x,y)
    local button=CreateFrame("CheckButton",name,parent)
    button.petAction=index
    button:SetWidth(46); button:SetHeight(46); button:SetPoint(point,relative,point,x,y)
    if button.RegisterForClicks then button:RegisterForClicks("LeftButtonUp","RightButtonUp") end
    if button.RegisterForDrag then button:RegisterForDrag("LeftButton","RightButton") end
    button.icon=button:CreateTexture(nil,"ARTWORK")
    button.icon:SetWidth(42); button.icon:SetHeight(42); button.icon:SetPoint("CENTER",button,"CENTER",0,0)
    button.cooldown=CreateFrame("Model",name.."Cooldown",button,"CooldownFrameTemplate")
    button.cooldown:SetWidth(38); button.cooldown:SetHeight(38); button.cooldown:SetPoint("CENTER",button,"CENTER",0,0)
    button.active=button:CreateTexture(nil,"OVERLAY")
    button.active:SetTexture("Interface\\AddOns\\Windrunner-Controller\\textures\\radial\\glow")
    button.active:SetAllPoints(button); button.active:SetBlendMode("ADD"); button.active:Hide()
    button.autocast=Text(button,12,"accent"); button.autocast:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-1,1)
    button:SetScript("OnClick",function()
        Pet:ActivateSlot(this.petAction,arg1,IsShiftKeyDown and IsShiftKeyDown())
        Pet:Refresh()
    end)
    button:SetScript("OnDragStart",function()
        if LOCK_ACTIONBAR~="1" and PickupPetAction then PickupPetAction(this.petAction); Pet:Refresh() end
    end)
    button:SetScript("OnReceiveDrag",function()
        if LOCK_ACTIONBAR~="1" and PickupPetAction then PickupPetAction(this.petAction); Pet:Refresh() end
    end)
    button:SetScript("OnEnter",function()
        if GameTooltip then GameTooltip:SetOwner(this,"ANCHOR_TOP"); GameTooltip:SetPetAction(this.petAction); GameTooltip:Show() end
    end)
    button:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    ConsoleExperience.theme:Button(button)
    button.ring=button:CreateTexture(nil,"OVERLAY")
    button.ring:SetTexture("Interface\\AddOns\\Windrunner-Controller\\textures\\radial\\ring"); button.ring:SetAllPoints(button)
    ConsoleExperience.theme:Register(button,"petAction",function(b,p)
        b:SetBackdrop(nil)
        local focus=b.themeHovered or (ConsoleExperience.cursor and ConsoleExperience.cursor.navigationState.currentButton==b)
        local color=focus and p.focus or p.border
        b.ring:SetVertexColor(color[1],color[2],color[3],1)
        b.active:SetVertexColor(p.accent[1],p.accent[2],p.accent[3],0.6)
    end)
    button.cursorOnFocus=function()
        for _,b in ipairs(Pet.abilityButtons) do ConsoleExperience.theme:Apply(b) end
    end
    return button
end

function Pet:CreateCommandMenu()
    if self.commandFrame then return end
    local frame=CreateFrame("Frame","CEPetCommandMenu",UIParent)
    self.commandFrame=frame; frame:Hide(); frame:SetWidth(300); frame:SetHeight(330)
    frame:SetPoint("CENTER",UIParent,"CENTER",0,10); frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(100); frame:EnableMouse(true); frame:SetClampedToScreen(true); frame.ceNavigationModal=true
    ConsoleExperience.theme:Register(frame,"panel")
    local title=Text(frame,18,"accent"); title:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-16); title:SetText(L("Pet commands"))
    self.commandRows={}
    local rows={{"attack",L("Attack")},{"follow",L("Follow")},{"stay",L("Stay")},{"passive",L("Passive")},
        {"defensive",L("Defensive")},{"aggressive",L("Aggressive")},{"abilities",L("Show abilities")},{"close",L("Close")}}
    for i=1,table.getn(rows) do
        local data=rows[i]; local b=CreateFrame("Button","CEPetCommandButton"..i,frame)
        b:SetWidth(264); b:SetHeight(30); b:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-48-(i-1)*34)
        b.text=Text(b,14,"text"); b.text:SetPoint("LEFT",b,"LEFT",10,0); b.text:SetText(data[2]); b.label=data[2]
        b.command=data[1]; b:SetScript("OnClick",function() Pet:ExecuteCommand(this.command) end)
        ConsoleExperience.theme:Button(b,b.text); self.commandRows[i]=b
    end
    if ConsoleExperience.hooks then ConsoleExperience.hooks:HookDynamicFrame(frame,"CEPetCommandMenu") end
    local oldHide=frame:GetScript("OnHide")
    frame:SetScript("OnHide",function()
        if oldHide then oldHide() end
        if ConsoleExperience.cursor then ConsoleExperience.cursor:RefreshFrame() end
        if WindrunnerController and WindrunnerController.Release then WindrunnerController:Release() end
    end)
    if UISpecialFrames then table.insert(UISpecialFrames,"CEPetCommandMenu") end
    Fit(frame,300,330)
end

function Pet:CreateAbilityPanel()
    if self.abilityFrame then return end
    local frame=CreateFrame("Frame","CEPetAbilityPanel",UIParent)
    self.abilityFrame=frame; frame:Hide(); frame:SetWidth(372); frame:SetHeight(214)
    frame:SetPoint("CENTER",UIParent,"CENTER",0,20); frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(100); frame:EnableMouse(true); frame:SetClampedToScreen(true); frame.ceNavigationModal=true
    ConsoleExperience.theme:Register(frame,"panel")
    local title=Text(frame,18,"accent"); title:SetPoint("TOPLEFT",frame,"TOPLEFT",16,-14); title:SetText(L("Pet abilities"))
    local hint=Text(frame,11,"muted"); hint:SetPoint("BOTTOM",frame,"BOTTOM",0,10)
    hint:SetWidth(340); hint:SetHeight(30); frame.hint=hint
    for i=1,10 do
        local col=i-1; local row=0
        if col>=5 then col=col-5; row=1 end
        local button=self:BuildAbilityButton(frame,i,"CEPetAbilityButton"..i,"TOPLEFT",frame,16+col*70,-54-row*60)
        self.abilityButtons[i]=button
    end
    if ConsoleExperience.hooks then ConsoleExperience.hooks:HookDynamicFrame(frame,"CEPetAbilityPanel") end
    local oldHide=frame:GetScript("OnHide")
    frame:SetScript("OnHide",function()
        if oldHide then oldHide() end
        if ConsoleExperience.cursor then ConsoleExperience.cursor:RefreshFrame() end
        if WindrunnerController and WindrunnerController.Release then WindrunnerController:Release() end
    end)
    if UISpecialFrames then table.insert(UISpecialFrames,"CEPetAbilityPanel") end
    Fit(frame,372,214)
end

function Pet:RenderCommands()
    local hasPet=Flag(PetHasActionBar and PetHasActionBar())
    for _,button in ipairs(self.commandRows or {}) do
        if button.command=="close" or (button.command=="abilities" and hasPet) or hasPet then button:Enable() else button:Disable() end
    end
end

function Pet:ExecuteCommand(command)
    if command=="close" then self.commandFrame:Hide(); return end
    if command=="abilities" then self:ShowAbilities(); self.commandFrame:Hide(); return end
    if self:Command(command) then self:Refresh(); self.commandFrame:Hide() end
end

function Pet:Create()
    if self.frame then return true end
    if not CreateFrame or not UIParent or not GetPetActionInfo then return false end
    local frame=CreateFrame("Frame","CEPetActionBar",UIParent)
    self.frame=frame; frame:Hide(); frame:SetWidth(10*51-5); frame:SetHeight(58)
    frame:SetFrameStrata("LOW")
    ConsoleExperience.theme:Register(frame,"card")
    for i=1,10 do
        local button=self:BuildAbilityButton(frame,i,"CEPetActionButton"..i,"LEFT",frame,0,0)
        button:ClearAllPoints(); button:SetPoint("LEFT",frame,"LEFT",(i-1)*51,0)
        self.buttons[i]=button
    end
    frame:EnableMouse(true); self.initialized=true
    self:UpdatePosition()
    return true
end

function Pet:UpdatePosition()
    if not self.frame or not UIParent then return end
    local config=ConsoleExperience.config
    local x=config and config.Get and config:Get("petBarX") or 0
    local y=config and config.Get and config:Get("petBarY") or 270
    local requested=config and config.Get and config:Get("barScale") or 1
    local parentWidth=UIParent:GetWidth()
    local parentHeight=UIParent:GetHeight()
    local scale=math.min(requested,(parentWidth-24)/self.frame:GetWidth(),(parentHeight-32)/self.frame:GetHeight())
    scale=math.max(0.05,scale)
    local width=self.frame:GetWidth()*scale
    local height=self.frame:GetHeight()*scale
    x=math.max(-parentWidth/2+width/2+12,math.min(parentWidth/2-width/2-12,x))
    y=math.max(16,math.min(parentHeight-height-32,y))
    self.frame:SetScale(scale)
    self.frame:ClearAllPoints()
    self.frame:SetPoint("BOTTOM",UIParent,"BOTTOM",x/scale,y/scale)
end

function Pet:Initialize()
    if not self:Create() then return false end
    if not self.events then
        self.events=CreateFrame("Frame")
        self.events:RegisterEvent("PLAYER_LOGIN"); self.events:RegisterEvent("UNIT_PET")
        self.events:RegisterEvent("UNIT_FLAGS"); self.events:RegisterEvent("UNIT_AURA")
        self.events:RegisterEvent("PET_BAR_UPDATE"); self.events:RegisterEvent("PET_BAR_UPDATE_COOLDOWN")
        self.events:RegisterEvent("PET_BAR_SHOWGRID"); self.events:RegisterEvent("PET_BAR_HIDEGRID")
        self.events:SetScript("OnEvent",function() Pet:Refresh() end)
    end
    self:Refresh()
    return true
end

function Pet:Show() if self:Initialize() then self.frame:Show() end end
function Pet:ShowAbilities()
    if not self:Initialize() or not Flag(PetHasActionBar and PetHasActionBar()) then return false end
    self:CreateAbilityPanel(); self:Refresh()
    local controls=ConsoleExperience.controllerControls
    local controller=WindrunnerController
    local confirm=controller and controller.GetMenuButtonName and controller:GetMenuButtonName("confirm") or "A"
    local cancel=controller and controller.GetMenuButtonName and controller:GetMenuButtonName("cancel") or "B"
    local x=controls and controls.GetPromptLabel and controls:GetPromptLabel("X") or "X"
    local y=controls and controls.GetPromptLabel and controls:GetPromptLabel("Y") or "Y"
    self.abilityFrame.hint:SetText(confirm..": "..L("Cast").."   "..x..": "..L("Autocast").."\n"..y..": "..L("Pick up").."   "..cancel..": "..L("Back"))
    Fit(self.abilityFrame,372,214)
    self.abilityFrame:Show()
    if ConsoleExperience.cursor then
        local first
        for i=1,10 do if self.abilityButtons[i]:IsEnabled() ~= 0 then first=self.abilityButtons[i]; break end end
        if first then ConsoleExperience.cursor:MoveCursorToButton(first) end
    end
    return true
end
function Pet:Hide()
    if self.commandFrame then self.commandFrame:Hide() end
    if self.abilityFrame then self.abilityFrame:Hide() end
    if self.frame then self.frame:Hide() end
end
function Pet:ShowMenu()
    if not self:Initialize() then return false end
    self:CreateCommandMenu(); self:RenderCommands(); self.commandFrame:Show()
    if ConsoleExperience.cursor then
        for _,button in ipairs(self.commandRows) do
            if button:IsEnabled() ~= 0 then ConsoleExperience.cursor:MoveCursorToButton(button); break end
        end
    end
    return true
end
function Pet:HideMenu()
    if self.commandFrame then self.commandFrame:Hide() end
    if self.abilityFrame then self.abilityFrame:Hide() end
end
function Pet:Back()
    if self.abilityFrame and self.abilityFrame:IsVisible() then self.abilityFrame:Hide()
    elseif self.commandFrame and self.commandFrame:IsVisible() then self.commandFrame:Hide() end
end
function Pet:IsVisible()
    return not not ((self.commandFrame and self.commandFrame:IsVisible()) or (self.abilityFrame and self.abilityFrame:IsVisible()))
end
function Pet:HandleInput(action)
    if self.abilityFrame and self.abilityFrame:IsVisible() then
        local button=ConsoleExperience.cursor and ConsoleExperience.cursor.navigationState.currentButton
        local slot=button and button.petAction
        if action==4 or action=="back" or action=="b" then self:Back(); return true end
        if action==2 or action=="autocast" or action=="x" then
            if slot then self:ActivateSlot(slot,"RightButton",false) end
            return true
        end
        if action==3 or action=="pickup" or action=="y" then
            if slot and PickupPetAction and ((CursorHasSpell and CursorHasSpell()) or (CursorHasItem and CursorHasItem())) then
                PickupPetAction(slot); return true
            end
            if slot then self:ActivateSlot(slot,"LeftButton",true) end
            return true
        end
        if action==1 or action=="select" or action=="a" then
            if slot and PickupPetAction and ((CursorHasSpell and CursorHasSpell()) or (CursorHasItem and CursorHasItem())) then
                PickupPetAction(slot); return true
            end
            if slot then self:ActivateSlot(slot,"LeftButton",false) end
            return true
        end
    end
    return false
end
function CE_PET_MENU()
    Pet:ShowMenu()
end
function CE_PetMenuBack() Pet:Back() end

local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
-- Consolidated view of live group rolls; Blizzard's LootFrame remains the
-- authority for corpse looting and all stock frame navigation stays enabled.
ConsoleExperience.lootpanel = { rows = {} }
local Loot = ConsoleExperience.lootpanel
local function L(key) return ConsoleExperience.locale.T(key) end
local function RollFrame(index) return getglobal and getglobal("GroupLootFrame"..index) end
local function Flag(value) return value and value ~= 0 end
local function FontSize(size) return size*(ConsoleExperience.theme:Get("uiTextScale") or 1) end

function Loot:StyleStockFrames()
    local theme=ConsoleExperience.theme
    local frame=getglobal and getglobal("LootFrame")
    if frame then
        theme:Register(frame,"panel")
        if ConsoleExperience.hooks then ConsoleExperience.hooks:HookDynamicFrame(frame,"LootFrame") end
        for i=1,4 do
            local button=getglobal("LootButton"..i)
            if button then theme:Button(button) end
            local text=getglobal("LootButton"..i.."Text")
            if text then theme:Register(text,"text") end
        end
        for _,name in ipairs({"LootFramePrev","LootFrameNext"}) do
            local text=getglobal(name)
            if text then theme:Register(text,"accent") end
        end
    end
    for i=1,4 do
        local roll=RollFrame(i)
        if roll then
            theme:Register(roll,"card")
            if ConsoleExperience.hooks then ConsoleExperience.hooks:HookDynamicFrame(roll,"GroupLootFrame"..i) end
            local name=getglobal("GroupLootFrame"..i.."Name")
            local timer=getglobal("GroupLootFrame"..i.."Timer")
            local icon=getglobal("GroupLootFrame"..i.."IconFrameIcon")
            if name then theme:Register(name,"text") end
            if timer then theme:Register(timer,"accent") end
            if icon then theme:Register(icon,"custom",function(region,p) region:SetVertexColor(unpack(p.accent)) end) end
            for _,suffix in ipairs({"RollButton","GreedButton","PassButton"}) do
                local button=getglobal("GroupLootFrame"..i..suffix)
                if button then theme:Button(button) end
            end
        end
    end
end

function Loot:ReadRoll(frame)
    if not frame or not frame.IsVisible or not frame:IsVisible() or not frame.rollID then return end
    local rollID=frame.rollID
    if not GetLootRollItemInfo or not GetLootRollTimeLeft then return end
    -- 1.12 returns only the item fields. Optional server capability values are
    -- honored where present; otherwise use the stock Roll/Greed button state.
    local texture,name,count,quality,bindOnPickUp,canNeed,canGreed=GetLootRollItemInfo(rollID)
    local link=GetLootRollItemLink and GetLootRollItemLink(rollID)
    if not texture and not link then return end
    local frameName=frame.GetName and frame:GetName() or "GroupLootFrame"
    local need=getglobal and getglobal(frameName.."RollButton")
    local greed=getglobal and getglobal(frameName.."GreedButton")
    if canNeed==nil then canNeed=need and need.IsEnabled and need:IsEnabled() end
    if canGreed==nil then canGreed=greed and greed.IsEnabled and greed:IsEnabled() end
    local time=GetLootRollTimeLeft(rollID)
    if not time or time<=0 then return end
    return {id=rollID,texture=texture,name=name or link or L("Pending roll"),link=link,
        count=count or 1,quality=quality,time=time,
        canNeed=Flag(canNeed),canGreed=Flag(canGreed),
        frame=frame}
end

function Loot:Initialize()
    if not self.events then
        self.events=CreateFrame("Frame")
        self.events:RegisterEvent("START_LOOT_ROLL")
        self.events:RegisterEvent("CANCEL_LOOT_ROLL")
        self.events:RegisterEvent("CONFIRM_LOOT_ROLL")
        self.events:RegisterEvent("LOOT_OPENED")
        self.events:RegisterEvent("LOOT_CLOSED")
        self.events:RegisterEvent("LOOT_SLOT_CLEARED")
        self.events:RegisterEvent("PLAYER_LOGIN")
        self.events:SetScript("OnEvent",function()
            Loot:StyleStockFrames()
            if Loot.frame and Loot.frame:IsVisible() then Loot:Refresh() end
        end)
    end
    self:StyleStockFrames()
    return true
end

function Loot:Pending()
    local rolls={}
    for i=1,4 do local roll=self:ReadRoll(RollFrame(i)); if roll then table.insert(rolls,roll) end end
    return rolls
end

function Loot:Validate(rollID)
    for _,roll in ipairs(self:Pending()) do if roll.id == rollID then return roll end end
end

function Loot:Create()
    if self.frame then return end
    local frame=CreateFrame("Frame","CELootPanel",UIParent)
    self.frame=frame; frame:Hide(); frame:SetWidth(500); frame:SetHeight(380)
    frame:SetPoint("CENTER",UIParent,"CENTER",0,20); frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(100); frame:EnableMouse(true); frame:SetClampedToScreen(true); frame.ceNavigationModal=true
    ConsoleExperience.theme:Register(frame,"panel")
    self.title=frame:CreateFontString(nil,"OVERLAY","GameFontNormal"); self.title:SetFont("Fonts\\FRIZQT__.TTF",FontSize(18),"")
    self.title:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-16); self.title:SetText(L("Pending group rolls"))
    ConsoleExperience.theme:Register(self.title,"accent")
    self.details=frame:CreateFontString(nil,"OVERLAY","GameFontNormal"); self.details:SetFont("Fonts\\FRIZQT__.TTF",FontSize(12),"")
    self.details:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-47); self.details:SetWidth(464); self.details:SetHeight(32)
    self.details:SetJustifyH("LEFT"); ConsoleExperience.theme:Register(self.details,"muted")
    for i=1,4 do
        local row=CreateFrame("Frame","CELootRollRow"..i,frame); row:SetWidth(464); row:SetHeight(58)
        row:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-84-(i-1)*62); ConsoleExperience.theme:Register(row,"card")
        row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetWidth(38); row.icon:SetHeight(38); row.icon:SetPoint("LEFT",row,"LEFT",8,0)
        row.name=row:CreateFontString(nil,"OVERLAY","GameFontNormal"); row.name:SetFont("Fonts\\FRIZQT__.TTF",FontSize(12),"")
        row.name:SetPoint("TOPLEFT",row,"TOPLEFT",56,-7); row.name:SetWidth(202); row.name:SetJustifyH("LEFT")
        ConsoleExperience.theme:Register(row.name,"text")
        row.timer=row:CreateFontString(nil,"OVERLAY","GameFontNormal"); row.timer:SetFont("Fonts\\FRIZQT__.TTF",FontSize(11),"")
        row.timer:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",56,7); ConsoleExperience.theme:Register(row.timer,"muted")
        row.rollButtons={}
        local choices={{"need",1,"Need"},{"greed",2,"Greed"},{"pass",0,"Pass"}}
        for j=1,3 do
            local choice=choices[j]
            local button=CreateFrame("Button","CELootRoll"..i..choice[1],row)
            button:SetWidth(56); button:SetHeight(32); button:SetPoint("RIGHT",row,"RIGHT",-((3-j)*60+8),0)
            button.text=button:CreateFontString(nil,"OVERLAY","GameFontNormal"); button.text:SetFont("Fonts\\FRIZQT__.TTF",FontSize(11),"")
            button.text:SetPoint("CENTER",button,"CENTER"); button.text:SetText(choice[3])
            button.label=choice[3]; button.rollChoice=choice[2]
            button:SetScript("OnClick",function() Loot:Choose(this.rollID,this.rollChoice,this.rollSignature) end)
            ConsoleExperience.theme:Button(button,button.text); row.rollButtons[choice[1]]=button
            button.label=choice[3]
        end
        self.rows[i]=row
    end
    self.closeButton=CreateFrame("Button","CELootPanelClose",frame)
    self.closeButton:SetWidth(78); self.closeButton:SetHeight(30)
    self.closeButton:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-18,12)
    self.closeButton.text=self.closeButton:CreateFontString(nil,"OVERLAY","GameFontNormal")
    self.closeButton.text:SetFont("Fonts\\FRIZQT__.TTF",FontSize(12),"")
    self.closeButton.text:SetPoint("CENTER",self.closeButton,"CENTER")
    self.closeButton.text:SetText(L("Close")); self.closeButton.label=L("Close")
    self.closeButton:SetScript("OnClick",function() Loot:Close() end)
    ConsoleExperience.theme:Button(self.closeButton,self.closeButton.text)
    if ConsoleExperience.hooks then ConsoleExperience.hooks:HookDynamicFrame(frame,"CELootPanel") end
    frame:SetScript("OnUpdate",function()
        this.elapsed=(this.elapsed or 0)+arg1
        if this.elapsed>=0.5 then this.elapsed=0; Loot:Refresh() end
    end)
    local oldHide=frame:GetScript("OnHide")
    frame:SetScript("OnHide",function()
        if oldHide then oldHide() end
        if ConsoleExperience.cursor then ConsoleExperience.cursor:RefreshFrame() end
        if WindrunnerController and WindrunnerController.Release then WindrunnerController:Release() end
    end)
    if UISpecialFrames then table.insert(UISpecialFrames,"CELootPanel") end
    local scale=ConsoleExperience.theme:Get("uiMenuScale") or 1
    scale=math.min(scale,(UIParent:GetWidth()-24)/500,(UIParent:GetHeight()-24)/380)
    frame:SetScale(math.max(0.5,scale))
    self:Initialize()
end

function Loot:Refresh()
    if not self.frame then return end
    local rolls=self:Pending()
    self.details:SetText(table.getn(rolls)>0 and L("Choose Roll, Greed or Pass. Roll time is reported by the server.")
        or L("No group rolls are pending. Corpse items use the standard loot window."))
    for i,row in ipairs(self.rows) do
        local roll=rolls[i]
        if roll then
            row.rollID=roll.id
            if roll.texture and SetPortraitToTexture then SetPortraitToTexture(row.icon,roll.texture)
            else row.icon:SetTexture(roll.texture) end
            row.name:SetText(roll.link or roll.name)
            row.timer:SetText(string.format(L("Time left: %d sec"),math.ceil(roll.time/1000)))
            row.rollButtons.need.rollID=roll.id; row.rollButtons.greed.rollID=roll.id; row.rollButtons.pass.rollID=roll.id
            local signature=roll.link or (tostring(roll.texture)..":"..tostring(roll.name))
            row.rollButtons.need.rollSignature=signature; row.rollButtons.greed.rollSignature=signature
            row.rollButtons.pass.rollSignature=signature
            if roll.canNeed then row.rollButtons.need:Enable() else row.rollButtons.need:Disable() end
            if roll.canGreed then row.rollButtons.greed:Enable() else row.rollButtons.greed:Disable() end
            row.rollButtons.pass:Enable()
            row:Show()
        else row.rollID=nil; row:Hide() end
    end
    local first
    for _,row in ipairs(self.rows) do
        if row:IsVisible() then
            for _,button in pairs(row.rollButtons) do if button:IsEnabled() ~= 0 then first=button; break end end
            if first then break end
        end
    end
    self.frame.initialCursorButton=first or self.closeButton
end

function Loot:Choose(rollID,choice,expectedSignature)
    local roll=self:Validate(rollID)
    if not roll or not RollOnLoot then self:Refresh(); return false end
    local signature=roll.link or (tostring(roll.texture)..":"..tostring(roll.name))
    if expectedSignature and signature~=expectedSignature then self:Refresh(); return false end
    if choice == 1 and not roll.canNeed or choice == 2 and not roll.canGreed
        or (choice ~= 0 and choice ~= 1 and choice ~= 2) then self:Refresh(); return false end
    RollOnLoot(roll.id,choice)
    self:Refresh()
    return true
end

function Loot:Open()
    if not CreateFrame then return false end
    self:Create()
    self:Refresh()
    self.frame:Show()
    if ConsoleExperience.cursor and self.frame.initialCursorButton then ConsoleExperience.cursor:MoveCursorToButton(self.frame.initialCursorButton) end
    return true
end
function Loot:Show() return self:Open() end
function Loot:Close() if self.frame then self.frame:Hide() end end
function Loot:Hide() self:Close() end
function Loot:Back() self:Close() end
function Loot:IsVisible() return self.frame and self.frame:IsVisible() end
function CE_LOOT_MENU() Loot:Open() end
function CE_LootMenuBack() Loot:Back() end

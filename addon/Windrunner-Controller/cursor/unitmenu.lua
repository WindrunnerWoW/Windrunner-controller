local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
-- Context actions for the currently selected Vanilla unit.
ConsoleExperience.unitmenu = { rows = {} }
local Menu = ConsoleExperience.unitmenu
local function Visible(frame) return frame and frame:IsVisible() end
local function L(key) return ConsoleExperience.locale.T(key) end
local function Flag(value) return value and value ~= 0 end
local function Scaled(size)
    return size * (ConsoleExperience.theme:Get("uiTextScale") or 1)
end

function Menu:Snapshot(unit)
    unit = unit or "target"
    if not UnitExists or not Flag(UnitExists(unit)) then return end
    local name, realm = UnitName(unit)
    if not name or name == "" then return end
    return { unit=unit, name=name, realm=realm, player=Flag(UnitIsPlayer and UnitIsPlayer(unit)),
        level=UnitLevel and UnitLevel(unit), class=UnitClass and UnitClass(unit),
        friend=Flag(UnitIsFriend and UnitIsFriend("player",unit)),
        guid=UnitGUID and UnitGUID(unit) }
end

function Menu:Validate()
    if not self.source then return end
    local now = self:Snapshot(self.source.unit)
    if not now or now.name ~= self.source.name or now.realm ~= self.source.realm
        or now.player ~= self.source.player or now.level ~= self.source.level or now.class ~= self.source.class
        or (self.source.guid and now.guid ~= self.source.guid) then return end
    return now
end

function Menu:Availability()
    local target = self:Validate()
    if not target then return {}, L("Target changed. Close and reopen this menu.") end
    local unit = target.unit
    local actions = {}
    local function Add(id, label, enabled, why) table.insert(actions,{id=id,label=label,enabled=enabled,why=why}) end
    local friendly = target.friend
    local selfTarget = Flag(UnitIsUnit and UnitIsUnit("player",unit))
    local nearTrade = Flag(CheckInteractDistance and CheckInteractDistance(unit,2))
    local nearInspect = Flag(CheckInteractDistance and CheckInteractDistance(unit,1))
    local nearFollow = Flag(CheckInteractDistance and CheckInteractDistance(unit,4))
    local playerDead=Flag(UnitIsDeadOrGhost and UnitIsDeadOrGhost("player"))
    local targetDead=Flag(UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit))
    local fullControl=HasFullControl==nil or Flag(HasFullControl())
    local partySize=GetNumPartyMembers and GetNumPartyMembers() or 0
    local raidSize=GetNumRaidMembers and GetNumRaidMembers() or 0
    local grouped = partySize>0 or raidSize>0
    if target.player then
        Add("follow", L("Follow"), friendly and not selfTarget and not playerDead and not targetDead and nearFollow and (FollowByName or FollowUnit) ~= nil,
            not friendly and L("Target must be friendly.") or (selfTarget and L("You cannot follow yourself.")
            or ((playerDead or targetDead) and L("Living characters are required to follow.")) or (not nearFollow and L("Move closer to follow."))))
        Add("trade", L("Trade"), friendly and not selfTarget and not playerDead and not targetDead and fullControl and nearTrade and InitiateTrade ~= nil,
            not friendly and L("Target must be friendly.") or (selfTarget and L("You cannot trade with yourself.")
            or ((playerDead or targetDead) and L("Living characters are required to trade.")) or (not fullControl and L("You do not have full control."))
            or (not nearTrade and L("Move closer to trade."))))
        Add("inspect", L("Inspect"), friendly and not selfTarget and not playerDead and nearInspect and (CanInspect == nil or Flag(CanInspect(unit))) and (InspectUnit or InspectFrame_Show or NotifyInspect) ~= nil,
            not friendly and L("Target must be friendly.") or (selfTarget and L("You cannot inspect yourself.")
            or (playerDead and L("You cannot inspect while dead.")) or (not nearInspect and L("Move closer to inspect."))))
        local sameFaction=UnitFactionGroup and UnitFactionGroup("player")==UnitFactionGroup(unit)
        local room=(raidSize>0 and raidSize<40) or (raidSize==0 and partySize<4)
        local invitePermission
        if raidSize>0 then
            invitePermission=Flag(IsRaidLeader and IsRaidLeader()) or Flag(IsRaidOfficer and IsRaidOfficer())
        elseif partySize>0 then
            invitePermission=Flag(IsPartyLeader and IsPartyLeader())
        else invitePermission=true end
        Add("invite", L("Invite to group"), not selfTarget and friendly and sameFaction and room and invitePermission and InviteByName~=nil,
            selfTarget and L("You cannot invite yourself.") or (not friendly and L("Target must be friendly.")
            or (not sameFaction and L("Target must be on your faction.")) or (not room and L("Your group is full."))
            or (not invitePermission and L("Raid leader or assistant required."))))
    end
    Add("assist", L("Assist"), friendly and not selfTarget and AssistUnit ~= nil,
        not friendly and L("Target must be friendly.") or (selfTarget and L("You cannot assist yourself.")))
    local canMark=false
    if raidSize>0 then
        canMark=(SetRaidTargetIcon or SetRaidTarget) and (Flag(IsRaidLeader and IsRaidLeader()) or Flag(IsRaidOfficer and IsRaidOfficer()))
    elseif GetNumPartyMembers and GetNumPartyMembers()>0 then
        canMark=(SetRaidTargetIcon or SetRaidTarget) and Flag(IsPartyLeader and IsPartyLeader())
    end
    Add("raidmark", L("Raid marker"), canMark,
        not canMark and L("Party or raid leader required."))
    Add("close", L("Close"), true)
    return actions
end

function Menu:Create()
    if self.frame then return end
    local frame = CreateFrame("Frame", "CEUnitMenuFrame", UIParent)
    self.frame = frame
    frame:Hide(); frame:SetWidth(360); frame:SetHeight(430)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
    frame:SetFrameStrata("FULLSCREEN_DIALOG"); frame:SetFrameLevel(100)
    frame:EnableMouse(true); frame:SetClampedToScreen(true); frame.ceNavigationModal = true
    ConsoleExperience.theme:Register(frame,"panel")
    self.title = frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
    self.title:SetFont("Fonts\\FRIZQT__.TTF",Scaled(18),""); self.title:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-16)
    ConsoleExperience.theme:Register(self.title,"accent")
    self.details = frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
    self.details:SetFont("Fonts\\FRIZQT__.TTF",Scaled(12),""); self.details:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-48)
    self.details:SetWidth(324); self.details:SetHeight(35); self.details:SetJustifyH("LEFT")
    ConsoleExperience.theme:Register(self.details,"muted")
    for i=1,10 do
        local b = CreateFrame("Button","CEUnitMenuButton"..i,frame)
        b:SetWidth(324); b:SetHeight(30); b:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-88-(i-1)*32)
        b.text = b:CreateFontString(nil,"OVERLAY","GameFontNormal")
        b.text:SetFont("Fonts\\FRIZQT__.TTF",Scaled(13),"")
        b.text:SetPoint("LEFT",b,"LEFT",12,0); b.text:SetWidth(284); b.text:SetJustifyH("LEFT")
        b.markerIcon=b:CreateTexture(nil,"ARTWORK"); b.markerIcon:SetWidth(22); b.markerIcon:SetHeight(22)
        b.markerIcon:SetPoint("RIGHT",b,"RIGHT",-10,0)
        b:SetScript("OnClick",function() Menu:Execute(this.action,this.markerIndex) end)
        ConsoleExperience.theme:Button(b,b.text)
        self.rows[i]=b
    end
    if ConsoleExperience.hooks then ConsoleExperience.hooks:HookDynamicFrame(frame,"CEUnitMenuFrame") end
    self.events=CreateFrame("Frame")
    self.events:RegisterEvent("PLAYER_TARGET_CHANGED")
    self.events:SetScript("OnEvent",function()
        if Menu.source and Menu.source.unit=="target" then Menu:Close() end
    end)
    local old = frame:GetScript("OnHide")
    frame:SetScript("OnHide",function()
        if old then old() end
        Menu.source=nil
        if ConsoleExperience.cursor then ConsoleExperience.cursor:RefreshFrame() end
        if WindrunnerController and WindrunnerController.Release then WindrunnerController:Release() end
    end)
    if UISpecialFrames then table.insert(UISpecialFrames,"CEUnitMenuFrame") end
    local scale=ConsoleExperience.theme:Get("uiMenuScale") or 1
    scale=math.min(scale,(UIParent:GetWidth()-24)/360,(UIParent:GetHeight()-24)/430)
    frame:SetScale(math.max(0.5,scale))
end

function Menu:Render()
    local target = self:Validate()
    if not target then self:Close(); return end
    local actions, detail
    if self.mode=="markers" then
        actions={{id="marker",markerIndex=0,label=L("Clear marker"),enabled=true}}
        for i=1,8 do table.insert(actions,{id="marker",markerIndex=i,label=L("Raid marker").." "..i,enabled=true}) end
        table.insert(actions,{id="back",label=L("Back"),enabled=true})
        detail=L("Choose a marker for ")..target.name
    else actions, detail = self:Availability() end
    self.title:SetText(target.name..(target.realm and target.realm ~= "" and " - "..target.realm or ""))
    self.details:SetText(detail or (target.class or L("Player")).."  ·  "..L("Choose an action"))
    local first
    for i,b in ipairs(self.rows) do
        local row=actions[i]
        if row then
            b.action=row.id; b.markerIndex=row.markerIndex
            b.label=row.enabled and row.label or row.label.." — "..(row.why or L("Unavailable"))
            b.text:SetText(b.label)
            if row.markerIndex and row.markerIndex>0 then
                b.markerIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_"..row.markerIndex)
                b.markerIcon:Show()
            else b.markerIcon:Hide() end
            if row.enabled then b:Enable(); if not first then first=b end else b:Disable() end
            ConsoleExperience.theme:Apply(b); b:Show()
        else b:Hide() end
    end
    self.frame.initialCursorButton=first or self.rows[1]
    if self.frame:IsVisible() and ConsoleExperience.cursor then ConsoleExperience.cursor:RefreshFrame() end
end

function Menu:Open(unit)
    local source=self:Snapshot(unit or "target")
    if not source then return false end
    self:Create(); self.source=source; self.mode="actions"; self:Render(); self.frame:Show()
    if ConsoleExperience.cursor and self.frame.initialCursorButton then ConsoleExperience.cursor:MoveCursorToButton(self.frame.initialCursorButton) end
    return true
end
function Menu:Show(unit) return self:Open(unit or "target") end
function Menu:Close() if self.frame then self.frame:Hide() end end
function Menu:Hide() self:Close() end
function Menu:Back()
    if self.mode=="markers" then self.mode="actions"; self:Render(); return end
    self:Close()
end
function Menu:IsVisible() return Visible(self.frame) end

function Menu:Execute(action,markerIndex)
    if action=="back" then self:Back(); return true end
    if action=="close" then self:Close(); return true end
    local target=self:Validate()
    if not target then self:Close(); return false end
    local current
    if action=="marker" and self.mode=="markers" then
        for _,row in ipairs(self:Availability()) do if row.id=="raidmark" then current=row; break end end
    else for _,row in ipairs(self:Availability()) do if row.id == action then current=row; break end end end
    if not current or not current.enabled then
        if action=="marker" then self.mode="actions" end
        self:Render(); return false
    end
    local unit=target.unit
    if action == "follow" then
        if FollowByName then FollowByName(target.name,1) else FollowUnit(unit) end
    elseif action == "trade" then InitiateTrade(unit)
    elseif action == "inspect" then
        if InspectUnit then InspectUnit(unit)
        elseif InspectFrame_Show then InspectFrame_Show(unit)
        else NotifyInspect(unit) end
    elseif action == "invite" then InviteByName(target.name)
    elseif action == "assist" then AssistUnit(unit)
    elseif action == "raidmark" then
        self.mode="markers"; self:Render(); return true
    elseif action == "marker" then
        if type(markerIndex)~="number" or markerIndex<0 or markerIndex>8 then return false end
        if SetRaidTargetIcon then SetRaidTargetIcon(unit,markerIndex) else SetRaidTarget(unit,markerIndex) end
    else return false end
    self:Close()
    return true
end

function CE_UNIT_MENU() Menu:Open("target") end
function CE_UnitMenuBack() Menu:Back() end

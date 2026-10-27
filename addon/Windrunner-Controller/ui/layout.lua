local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
-- Positions are stored in UIParent units, independently of button scale.
ConsoleExperience.layout = {}
local Layout = ConsoleExperience.layout
local function L(key) return ConsoleExperience.locale and ConsoleExperience.locale.T(key) or key end
local function Config() return ConsoleExperience.config end
local function Clamp(value, low, high) return math.max(low, math.min(high, value)) end
local function ParentCenterX()
    local x=UIParent and UIParent.GetCenter and UIParent:GetCenter()
    return x or (UIParent:GetWidth()/2)
end
local function ParentBottom()
    local y=UIParent and UIParent.GetBottom and UIParent:GetBottom()
    return y or 0
end
local function ControllerPrompt(name)
    local controls=ConsoleExperience.controllerControls
    if controls and controls.GetPromptLabel then return controls:GetPromptLabel(name) end
    return name
end

local function LabelBounds(size)
    local bars=ConsoleExperience.actionbars
    if bars and bars.GetControllerLabelBounds then return bars:GetControllerLabelBounds(size) end
    return {minX=-size/2,maxX=size/2,minY=-size/2,maxY=size/2+15}
end

function Layout:GetMainGeometry()
    local config = Config()
    if config:Get("barIndependent") or (config:Get("barLayout") and config:Get("barLayout")~="clusters") then
        return self:GetIndependentGeometry()
    end
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    local size = config:Get("barButtonSize") or 60
    local bounds=LabelBounds(size)
    local scale = config:Get("barScale") or 1
    local padding = math.max(config:Get("barPadding") or 65, size + 8) * scale
    local spacing = math.max((config:Get("barStarPadding") or 600) / 2, padding * 2.1 + size * scale * 0.6)
    local fit = math.min(1, (width - 24) / (spacing * 2 + padding * 2 + (bounds.maxX-bounds.minX) * scale),
        (height - 110) / (padding * 2 + (bounds.maxY-bounds.minY) * scale))
    fit = math.max(0.05, fit)
    scale, padding, spacing = scale * fit, padding * fit, spacing * fit
    local minX,maxX,minY,maxY=bounds.minX*scale,bounds.maxX*scale,bounds.minY*scale,bounds.maxY*scale
    local glyph=(bounds.minY+bounds.maxY)*scale
    local x = Clamp(config:Get("barXOffset") or 0, -width / 2 + spacing + padding - minX + 12,
        width / 2 - spacing - padding - maxX - 12)
    local y = Clamp(config:Get("barYOffset") or 70, padding - minY + 12, height - padding - maxY - 60)
    local buttons = {}
    for _,info in ipairs(config.BUTTON_LAYOUT) do
        local bx, by = info.x, info.y
        if config:Get("barAppearance") == "modern" and (info.id == 9 or info.id == 10) then
            bx, by = info.id == 10 and 2.1 or -2.1, 0.45
        end
        table.insert(buttons, {id=info.id, x=(info.star == "left" and -spacing or spacing) + bx * padding, y=by * padding})
    end
    -- Test the occupied circles rather than the empty space between the groups.
    local chat = ConsoleExperience.chat
    if chat and chat:IsEnabled() and config:Get("chatVisibility") ~= "typing" and not self.active then
        local c = chat:GetIdleGeometry()
        local chatTop = c.y + c.height
        if config:Get("castbarEnabled") then chatTop = chatTop + (config:Get("castbarHeight") or 20) + 5 end
        for _,button in ipairs(buttons) do
            if x + button.x + maxX + 8 > c.x - c.width / 2 and x + button.x + minX - 8 < c.x + c.width / 2
                and y + button.y + minY < chatTop + 8 and y + button.y + maxY > c.y - 8 then
                local above = chatTop + padding - minY + 12
                local below = c.y - padding - maxY - 12
                if above <= height - padding - maxY - 60 then y=above
                elseif below >= padding - minY + 12 then y=below end
                break
            end
        end
    end
    return {x=x, y=y, scale=scale, padding=padding, spacing=spacing, buttons=buttons,
        width=spacing * 2 + padding * 2 + maxX-minX, height=padding * 2 + maxY-minY,
        bottom=y - padding + minY, glyph=glyph,topExtent=maxY,centerOffsetX=(minX+maxX)/2}
end

function Layout:GetIndependentGeometry()
    local config=Config()
    local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    local size=config:Get("barButtonSize") or 60
    local labelBounds=LabelBounds(size)
    local requested=config:Get("barScale") or 1
    local padding=math.max(config:Get("barPadding") or 65,size+8)
    local preset=config:Get("barLayout") or "clusters"
    local points={}
    local rows={left={6,7,10,5,8},right={2,3,9,1,4}}
    for _,info in ipairs(config.BUTTON_LAYOUT) do
        local x,y=info.x,info.y
        if preset=="horizontal" then
            for i,id in ipairs(rows[info.star]) do if id==info.id then x,y=i-3,0 end end
        elseif preset=="crossbar" then
            local positions={[6]={-2,0},[7]={-1,0.55},[5]={-1,-0.55},[8]={0,0},[10]={1,0},
                [9]={-1,0},[2]={0,0},[3]={1,0.55},[1]={1,-0.55},[4]={2,0}}
            x,y=positions[info.id][1],positions[info.id][2]
        elseif config:Get("barAppearance")=="modern" and (info.id==9 or info.id==10) then
            x,y=info.id==10 and 2.1 or -2.1,0.45
        end
        table.insert(points,{id=info.id,star=info.star,x=x*padding,y=y*padding})
    end
    local extents={left={minX=0,maxX=0,minY=0,maxY=0},right={minX=0,maxX=0,minY=0,maxY=0}}
    for _,point in ipairs(points) do
        local e=extents[point.star]
        e.minX=math.min(e.minX,point.x+labelBounds.minX); e.maxX=math.max(e.maxX,point.x+labelBounds.maxX)
        e.minY=math.min(e.minY,point.y+labelBounds.minY); e.maxY=math.max(e.maxY,point.y+labelBounds.maxY)
    end
    local fit=requested
    for _,e in pairs(extents) do
        fit=math.min(fit,(width/2-24)/(e.maxX-e.minX),(height-110)/(e.maxY-e.minY))
    end
    fit=math.max(0.05,fit)
    local centers,groups={},{}
    local spacing=math.max((config:Get("barStarPadding") or 600)/2,padding*requested*2.1)
    for _,side in ipairs({"left","right"}) do
        local e=extents[side]
        local prefix=side=="left" and "barLeft" or "barRight"
        local x=(config:Get("barXOffset") or 0)+(side=="left" and -spacing or spacing)+(config:Get(prefix.."X") or 0)
        local y=(config:Get("barYOffset") or 70)+(config:Get(prefix.."Y") or 0)
        x=Clamp(x,-width/2-e.minX*fit+12,width/2-e.maxX*fit-12)
        y=Clamp(y,-e.minY*fit+12,height-e.maxY*fit-60)
        local chat=ConsoleExperience.chat
        if not config:Get("hudIndependent") and chat and chat:IsEnabled() and config:Get("chatVisibility")~="typing" and not self.active then
            local c=chat:GetIdleGeometry()
            local top=c.y+c.height+(config:Get("castbarEnabled") and (config:Get("castbarHeight") or 20)+5 or 0)
            if x+e.maxX*fit>c.x-c.width/2 and x+e.minX*fit<c.x+c.width/2
                and y+e.minY*fit<top+8 and y+e.maxY*fit>c.y-8 then
                y=Clamp(top-e.minY*fit+12,-e.minY*fit+12,height-e.maxY*fit-60)
            end
        end
        centers[side]={x=x,y=y}
        groups[side]={x=x+(e.minX+e.maxX)*fit/2,y=y+(e.minY+e.maxY)*fit/2,
            width=(e.maxX-e.minX)*fit,height=(e.maxY-e.minY)*fit}
    end
    for _,point in ipairs(points) do
        point.x=centers[point.star].x+point.x*fit
        point.y=centers[point.star].y+point.y*fit
    end
    return {x=0,y=0,scale=fit,buttons=points,groups=groups,centers=centers,independent=true,
        spacing=spacing,padding=padding*fit,glyph=(labelBounds.minY+labelBounds.maxY)*fit,
        topExtent=labelBounds.maxY*fit,width=width-24,height=height-80,bottom=12}
end

function Layout:Refresh()
    if self.refreshing then return end
    self.refreshing=true
    Config():UpdateActionBarLayout()
    if ConsoleExperience.pet and ConsoleExperience.pet.UpdatePosition then
        ConsoleExperience.pet:UpdatePosition()
        if ConsoleExperience.pet.Refresh then ConsoleExperience.pet:Refresh() end
    end
    self:UpdateVisibility()
    local chat = ConsoleExperience.chat
    if chat then chat:UpdateChatLayout(self.active) end
    local xp = ConsoleExperience.xpbar
    if xp and xp.UpdateAllBars then xp:UpdateAllBars() end
    local cast = ConsoleExperience.castbar
    if cast and cast.UpdatePosition then cast:UpdatePosition() end
    if Config().UpdateCrosshair then Config():UpdateCrosshair() end
    if self.active then self:UpdateHandles() end
    self.refreshing=false
end

function Layout:UpdateVisibility()
    local policy=Config():Get("barVisibility") or "always"
    local combat=UnitAffectingCombat and UnitAffectingCombat("player")
    local inCombat=combat==true or (type(combat)=="number" and combat~=0)
    local menu=WindrunnerController and WindrunnerController:IsMenuActive()
    local shown=self.active or menu or policy=="always" or (policy=="combat" and inCombat) or (policy=="idle" and not inCombat)
    shown=shown and true or false
    local changed=self.lastBarVisibility~=shown
    self.lastBarVisibility=shown
    if changed then for i=1,10 do
        local button=getglobal("ConsoleActionButton"..i)
        if button then if shown then button:Show() else button:Hide() end end
    end end
    local bars=ConsoleExperience.actionbars
    if bars then
        for _,side in ipairs({"Left","Right"}) do
            local frame=bars["sideBar"..side.."Frame"]
            if frame then
                if shown and Config():Get("sideBar"..side.."Enabled") then frame:Show() else frame:Hide() end
            end
        end
        local pet=ConsoleExperience.pet and ConsoleExperience.pet.frame
        if pet then
            local hasPet=PetHasActionBar and PetHasActionBar()
            if shown and hasPet and hasPet~=0 then pet:Show() else pet:Hide() end
        end
        if not shown and bars.pageIndicator then bars.pageIndicator:Hide() end
        if shown and changed then bars:UpdateAllButtons() end
    end
end

function Layout:CreateHandle(id, label, save)
    local frame = CreateFrame("Frame", "CELayoutHandle" .. id, UIParent)
    frame.layoutTargetId=id
    frame.savePosition=save
    frame:SetFrameStrata("DIALOG"); frame:SetFrameLevel(150)
    frame:SetMovable(true); frame:EnableMouse(true); frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    frame:SetBackdropColor(0.04, 0.07, 0.1, 0.55); frame:SetBackdropBorderColor(0.9, 0.72, 0.35, 0.9)
    local text = frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    text:SetPoint("BOTTOM", frame,"TOP",0,4); text:SetText(L(label))
    frame:SetScript("OnDragStart",function()
        if Layout.IsMoving and Layout:IsMoving() then Layout:ConfirmMove() end
        Layout:SelectTarget(this.layoutTargetId)
        this:StartMoving(); this.dragging=true
    end)
    frame:SetScript("OnDragStop",function()
        this:StopMovingOrSizing(); this.dragging=false
        local x,y = this:GetCenter()
        local factor = this:GetEffectiveScale() / UIParent:GetEffectiveScale()
        this.savePosition(x * factor, y * factor)
        Layout:Refresh()
    end)
    frame:Hide()
    self.handles[id]=frame
    return frame
end

local TARGETS={
    {id="bars",label="Action bars",keys={"barXOffset","barYOffset"}},
    {id="mainleft",label="Left action bar",keys={"barLeftX","barLeftY"}},
    {id="mainright",label="Right action bar",keys={"barRightX","barRightY"}},
    {id="chat",label="Chat",keys={"chatXOffset","chatBottomY"}},
    {id="Left",label="Touch bar: Left",keys={"sideBarLeftX","sideBarLeftY"}},
    {id="Right",label="Touch bar: Right",keys={"sideBarRightX","sideBarRightY"}},
    {id="pet",label="Pet action bar",keys={"petBarX","petBarY"}},
    {id="xp",label="XP Bar",keys={"xpBarX","xpBarY"}},
    {id="rep",label="Rep Bar",keys={"repBarX","repBarY"}},
    {id="cast",label="Cast Bar",keys={"castbarX","castbarY"}},
    {id="crosshair",label="Crosshair",keys={"crosshairX","crosshairY"}},
    {id="indicator",label="Action page",keys={"pageIndicatorX","pageIndicatorY"}},
}
local TARGET_BY_ID={}
for _,target in ipairs(TARGETS) do TARGET_BY_ID[target.id]=target end

function Layout:IsVisible()
    return self.active and self.frame and self.frame:IsVisible() or false
end

function Layout:IsMoving()
    return self.movingTarget~=nil
end

function Layout:GetTargetFrame(id)
    local xp=ConsoleExperience.xpbar
    if id=="xp" then return xp and xp.xpBar end
    if id=="rep" then return xp and xp.repBar end
    if id=="cast" and Config():Get("castbarEnabled") then return ConsoleExperience.castbar and ConsoleExperience.castbar.castBar end
    if id=="crosshair" and Config():Get("crosshairEnabled") then return Config().crosshairFrame end
    if id=="indicator" then return ConsoleExperience.actionbars and ConsoleExperience.actionbars.pageIndicator end
end

function Layout:IsTargetAvailable(id)
    if not self.active then return false end
    if not TARGET_BY_ID[id] then return false end
    local bars=ConsoleExperience.actionbars
    if id=="bars" then return self.mainGeometry and not self.mainGeometry.independent or false end
    if id=="mainleft" or id=="mainright" then return self.mainGeometry and self.mainGeometry.independent or false end
    if id=="chat" then return ConsoleExperience.chat and ConsoleExperience.chat:IsEnabled() and ChatFrame1~=nil end
    if id=="Left" or id=="Right" then
        local frame=bars and bars["sideBar"..id.."Frame"]
        return Config():Get("sideBar"..id.."Enabled") and frame~=nil and frame:IsShown()
    end
    if id=="pet" then
        local pet=ConsoleExperience.pet
        local hasPet=PetHasActionBar and PetHasActionBar()
        return pet and pet.frame and hasPet and hasPet~=0 and pet.frame:IsShown()
    end
    if self:GetTargetFrame(id) then return true end
    return false
end

function Layout:UpdateTargetButtons()
    if not self.targetButtons then return end
    if self.selectedTarget and not self:IsTargetAvailable(self.selectedTarget) then self.selectedTarget=nil end
    if not self.selectedTarget then
        for _,target in ipairs(TARGETS) do
            if self:IsTargetAvailable(target.id) then self.selectedTarget=target.id; break end
        end
    end
    local row=0
    for _,target in ipairs(TARGETS) do
        local button=self.targetButtons[target.id]
        if button then
            if self:IsTargetAvailable(target.id) then
                button:Show()
                button:ClearAllPoints(); button:SetPoint("TOPLEFT",self.frame,"TOPLEFT",16,-60-row*36)
                row=row+1
                button:SetText((self.selectedTarget==target.id and "> " or "") .. L(target.label))
            else button:Hide() end
        end
    end
    self.frame:SetHeight(240+row*36)
    self.frame:SetScale(math.min(1,(UIParent:GetWidth()-32)/340,(UIParent:GetHeight()-32)/self.frame:GetHeight()))
    if self.moveStatus then
        local target=TARGET_BY_ID[self.selectedTarget]
        local label=target and L(target.label) or L("Choose a target")
        local step=self.moveStep or 10
        local promptX,promptA,promptB=ControllerPrompt("X"),ControllerPrompt("A"),ControllerPrompt("B")
        local mode=self:IsMoving() and (L("D-pad moves").."; "..promptA.." "..L("saves").."; "..promptB.." "..L("cancels").."; "..promptX.." "..L("saves and exits"))
            or (L("Choose a target to move").."; "..promptA.." "..L("selects").."; "..promptB.." "..L("back").."; "..promptX.." "..L("saves and exits"))
        self.moveStatus:SetText(label .. "  |  " .. tostring(step) .. " px  |  " .. mode)
    end
    if self.doneButton then
        local prompt=ControllerPrompt("X")
        self.doneButton:SetText(prompt .. ": " .. L("Save + exit"))
        self.doneButton.label=prompt .. ": " .. L("Save + exit")
        self.doneButton.cursorPrompt=self.doneButton.label
    end
    if self.stepButton then self.stepButton:SetText(L("Step") .. ": " .. tostring(self.moveStep or 10)) end
    for _,target in ipairs(TARGETS) do
        local handle=self.handles and self.handles[target.id]
        if handle and handle.SetBackdropBorderColor then
            if self.selectedTarget==target.id then handle:SetBackdropBorderColor(1,0.82,0.25,1)
            else handle:SetBackdropBorderColor(0.9,0.72,0.35,0.9) end
        end
    end
end

function Layout:SelectTarget(id)
    if not self:IsTargetAvailable(id) then return false end
    if self:IsMoving() and self.movingTarget~=id then self:CancelMove() end
    self.selectedTarget=id
    self:UpdateTargetButtons()
    return true
end

function Layout:BeginMove(id)
    id=id or self.selectedTarget
    if self:IsMoving() and self.movingTarget==id then return true end
    if not self:SelectTarget(id) then return false end
    local snapshot={}
    for _,key in ipairs(TARGET_BY_ID[id].keys) do snapshot[key]=Config():Get(key) end
    self.moveSnapshot=snapshot
    self.movingTarget=id
    self:UpdateTargetButtons()
    return true
end

function Layout:ConfirmMove()
    if not self:IsMoving() then return false end
    self.movingTarget=nil
    self.moveSnapshot=nil
    self:UpdateTargetButtons()
    return true
end

function Layout:CancelMove()
    if not self:IsMoving() then return false end
    local snapshot=self.moveSnapshot or {}
    self.movingTarget=nil
    self.moveSnapshot=nil
    for key,value in pairs(snapshot) do Config():Set(key,value) end
    self:Refresh()
    return true
end

function Layout:CycleMoveStep()
    local steps={1,5,10,25}
    local current=self.moveStep or 10
    for index,value in ipairs(steps) do
        if value==current then
            local nextIndex=index+1
            if nextIndex>table.getn(steps) then nextIndex=1 end
            self.moveStep=steps[nextIndex]
            break
        end
    end
    if not self.moveStep then self.moveStep=10 end
    self:UpdateTargetButtons()
end

function Layout:MoveTargetBy(id,dx,dy)
    local config=Config()
    local screenW,screenH=UIParent:GetWidth(),UIParent:GetHeight()
    local g=self.mainGeometry or self:GetMainGeometry()
    if id=="bars" then
        local width,height=g.width,g.height
        local offsetX=g.centerOffsetX or 0
        local x=Clamp(g.x+offsetX+dx,-screenW/2+width/2,screenW/2-width/2)-offsetX
        local centerY=g.y+g.glyph/2+dy
        centerY=Clamp(centerY,height/2,screenH-height/2)
        config:Set("barXOffset",math.floor(x+0.5))
        config:Set("barYOffset",math.floor(centerY-g.glyph/2+0.5))
    elseif id=="mainleft" or id=="mainright" then
        local side=id=="mainleft" and "left" or "right"
        local group=g.groups[side]
        local prefix=side=="left" and "barLeft" or "barRight"
        local x=Clamp(group.x+dx,-screenW/2+group.width/2,screenW/2-group.width/2)
        local y=Clamp(group.y+dy,group.height/2,screenH-group.height/2)
        config:Set(prefix.."X",math.floor((config:Get(prefix.."X") or 0)+x-group.x+0.5))
        config:Set(prefix.."Y",math.floor((config:Get(prefix.."Y") or 0)+y-group.y+0.5))
    elseif id=="chat" then
        local chat=ConsoleExperience.chat
        local c=chat and chat:GetIdleGeometry()
        if not c then return false end
        local x=Clamp(c.x+dx,-screenW/2+c.width/2+16,screenW/2-c.width/2-16)
        local y=Clamp(c.baseY+dy,0,screenH-c.height-c.reserve-70)
        config:Set("chatXOffset",math.floor(x+0.5))
        config:Set("chatBottomY",math.floor(y+0.5))
    elseif id=="Left" or id=="Right" then
        local side=id
        local frame=ConsoleExperience.actionbars and ConsoleExperience.actionbars["sideBar"..side.."Frame"]
        if not frame then return false end
        local scale=frame:GetEffectiveScale()/UIParent:GetEffectiveScale()
        local width,height=frame:GetWidth()*scale,frame:GetHeight()*scale
        local defaultX=side=="Left" and (12+width/2) or (screenW-12-width/2)
        local keyX,keyY="sideBar"..side.."X","sideBar"..side.."Y"
        local x=Clamp(defaultX+(config:Get(keyX) or 0)+dx,width/2+8,screenW-width/2-8)
        local y=Clamp(screenH/2+(config:Get(keyY) or 0)+dy,height/2+8,screenH-height/2-28)
        config:Set(keyX,math.floor(x-defaultX+0.5))
        config:Set(keyY,math.floor(y-screenH/2+0.5))
    elseif self:GetTargetFrame(id) then
        local frame=self:GetTargetFrame(id)
        local cx,cy=frame:GetCenter()
        if not cx or not cy then return false end
        local scale=frame:GetEffectiveScale()/UIParent:GetEffectiveScale()
        local w,h=frame:GetWidth()*scale,frame:GetHeight()*scale
        local x=Clamp(cx*scale+dx,ParentCenterX()-screenW/2+w/2+8,ParentCenterX()+screenW/2-w/2-8)
        local y=Clamp(cy*scale+dy,ParentBottom()+h/2+8,ParentBottom()+screenH-h/2-8)
        self.handles[id].savePosition(x,y)
    elseif id=="pet" then
        local pet=ConsoleExperience.pet and ConsoleExperience.pet.frame
        if not pet then return false end
        local scale=pet:GetEffectiveScale()/UIParent:GetEffectiveScale()
        local width,height=pet:GetWidth()*scale,pet:GetHeight()*scale
        local x=Clamp((config:Get("petBarX") or 0)+dx,-screenW/2+width/2+12,screenW/2-width/2-12)
        local y=Clamp((config:Get("petBarY") or 0)+dy,16,screenH-height-32)
        config:Set("petBarX",math.floor(x+0.5))
        config:Set("petBarY",math.floor(y+0.5))
    else
        return false
    end
    self:Refresh()
    self:UpdateTargetButtons()
    return true
end

function Layout:MoveSelected(direction)
    if not self:IsMoving() then return false end
    local delta=self.moveStep or 10
    local dx,dy=0,0
    direction=string.lower(direction or "")
    if direction=="left" then dx=-delta
    elseif direction=="right" then dx=delta
    elseif direction=="up" then dy=delta
    elseif direction=="down" then dy=-delta
    else return false end
    local handle=self.handles and self.handles[self.movingTarget]
    if not handle or not handle.savePosition then return false end
    return self:MoveTargetBy(self.movingTarget,dx,dy)
end

function Layout:HandleDirection(direction)
    if not self:IsMoving() then return false end
    return self:MoveSelected(direction)
end

function Layout:HandleInput(slot)
    if not self:IsVisible() then return false end
    if slot==2 then self:FinishEditing(); return true end
    if not self:IsMoving() then
        if slot==4 then self:Back(); return true end
        return false
    end
    if slot==1 then self:ConfirmMove()
    elseif slot==4 then self:Back()
    elseif slot==5 then self:MoveSelected("down")
    elseif slot==6 then self:MoveSelected("left")
    elseif slot==7 then self:MoveSelected("up")
    elseif slot==8 then self:MoveSelected("right") end
    return true
end

function Layout:Back()
    if self:IsMoving() then self:CancelMove(); return true end
    if self:IsVisible() then self:Stop(); return true end
    return false
end

function Layout:FinishEditing()
    if self:IsMoving() then self:ConfirmMove() end
    if self:IsVisible() then self:Stop(); return true end
    return false
end

function Layout:CreateEditor()
    if self.frame then return end
    self.handles={}
    local frame = CreateFrame("Frame", "CELayoutEditor", UIParent)
    self.frame=frame
    frame:SetWidth(340); frame:SetHeight(570); frame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",16,-16)
    frame.ceNavigationModal=true
    frame:SetFrameStrata("DIALOG"); frame:SetFrameLevel(160)
    local theme=ConsoleExperience.theme
    if theme then theme:Register(frame,"panel") end
    local title=frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
    title:SetPoint("TOPLEFT",frame,"TOPLEFT",16,-12); title:SetText(L("Choose a target, then nudge with the D-pad. Confirm saves; Back cancels."))
    title:SetWidth(308); title:SetHeight(40); title:SetJustifyH("LEFT")
    if theme then theme:Register(title,"text") end
    self.targetButtons={}; self.nudgeButtons={}; self.moveStep=10
    for _,target in ipairs(TARGETS) do
        local width=308
        local targetID=target.id
        local targetButton=CreateFrame("Button","CELayoutTarget" .. targetID,frame,"UIPanelButtonTemplate")
        targetButton:SetWidth(width); targetButton:SetHeight(30); targetButton:SetPoint("TOPLEFT",frame,"TOPLEFT",16,-60)
        targetButton:SetText(L(target.label)); targetButton.cursorPrompt=target.label
        targetButton:SetScript("OnClick",function() Layout:BeginMove(targetID) end)
        if theme then theme:Button(targetButton) end
        self.targetButtons[targetID]=targetButton
    end
    self.moveStatus=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    self.moveStatus:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",16,108)
    self.moveStatus:SetWidth(308); self.moveStatus:SetHeight(66); self.moveStatus:SetJustifyH("LEFT")
    if theme then theme:Register(self.moveStatus,"text") end
    local nudgeEntries={{"left","<"},{"down","v"},{"up","^"},{"right",">"}}
    local nudgeX=16
    for _,entry in ipairs(nudgeEntries) do
        local direction,label=entry[1],entry[2]
        local button=CreateFrame("Button","CELayoutNudge" .. string.upper(direction),frame,"UIPanelButtonTemplate")
        button:SetWidth(48); button:SetHeight(24); button:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",nudgeX,48)
        button:SetText(label); button.cursorPrompt=L(direction)
        button:SetScript("OnClick",function()
            if not Layout:IsMoving() and not Layout:BeginMove() then return end
            Layout:MoveSelected(direction); Layout:ConfirmMove()
        end)
        if theme then theme:Button(button) end
        self.nudgeButtons[direction]=button
        nudgeX=nudgeX+54
    end
    self.stepButton=CreateFrame("Button","CELayoutMoveStep",frame,"UIPanelButtonTemplate")
    self.stepButton:SetWidth(104); self.stepButton:SetHeight(24); self.stepButton:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-16,78)
    self.stepButton.cursorPrompt=L("Change nudge step")
    self.stepButton:SetScript("OnClick",function() Layout:CycleMoveStep() end)
    if theme then theme:Button(self.stepButton) end
    local function Button(name,label,x,width,callback)
        local button=CreateFrame("Button",name,frame,"UIPanelButtonTemplate")
        button:SetWidth(width); button:SetHeight(26); button:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",x,10)
        button:SetText(L(label)); button.label=L(label); button.cursorPrompt=button.label
        button:SetScript("OnClick",callback)
        if theme then theme:Button(button) end
        return button
    end
    Button("CELayoutReset","Reset positions",16,156,function()
        if Layout:IsMoving() then Layout:ConfirmMove() end
        local config=Config()
        for _,key in ipairs({"barXOffset","barYOffset","barLeftX","barLeftY","barRightX","barRightY","petBarX","petBarY","chatXOffset","chatBottomY","sideBarLeftX","sideBarLeftY","sideBarRightX","sideBarRightY","xpBarX","xpBarY","repBarX","repBarY","castbarX","castbarY","pageIndicatorX","pageIndicatorY","crosshairX","crosshairY"}) do
            config:Set(key,config.DEFAULTS[key])
        end
        Layout:Refresh()
    end)
    self.doneButton=Button("CELayoutDone","Done",184,140,function()
        Layout:FinishEditing()
    end)
    frame:SetScript("OnHide",function() if Layout.active then Layout:Stop() end end)
    table.insert(UISpecialFrames,"CELayoutEditor")
    frame:Hide()
    self:CreateHandle("bars","Action bars",function(x,y)
        Config():Set("barXOffset",math.floor(x-ParentCenterX()-(Layout.mainGeometry.centerOffsetX or 0)+0.5))
        Config():Set("barYOffset",math.floor(y-ParentBottom()-Layout.mainGeometry.glyph/2+0.5))
    end)
    for _,side in ipairs({"left","right"}) do
        local which=side
        self:CreateHandle("main"..which,which=="left" and "Left action bar" or "Right action bar",function(x,y)
            local g=Layout.mainGeometry
            local group=g.groups[which]
            local prefix=which=="left" and "barLeft" or "barRight"
            Config():Set(prefix.."X",math.floor((Config():Get(prefix.."X") or 0)+x-ParentCenterX()-group.x+0.5))
            Config():Set(prefix.."Y",math.floor((Config():Get(prefix.."Y") or 0)+y-ParentBottom()-group.y+0.5))
        end)
    end
    self:CreateHandle("pet","Pet action bar",function(x,y)
        Config():Set("petBarX",math.floor(x-ParentCenterX()+0.5))
        local pet=ConsoleExperience.pet and ConsoleExperience.pet.frame
        local height=pet and pet:GetHeight()*(pet:GetEffectiveScale()/UIParent:GetEffectiveScale()) or 0
        Config():Set("petBarY",math.floor(y-ParentBottom()-height/2+0.5))
        if ConsoleExperience.pet and ConsoleExperience.pet.UpdatePosition then ConsoleExperience.pet:UpdatePosition() end
    end)
    self:CreateHandle("chat","Chat",function(x,y)
        local c=ConsoleExperience.chat:GetIdleGeometry()
        Config():Set("chatXOffset",math.floor(x-ParentCenterX()+0.5))
        Config():Set("chatBottomY",math.max(0,math.floor(y-ParentBottom()-c.height/2-c.reserve+0.5)))
    end)
    for _,id in ipairs({"xp","rep","cast","crosshair","indicator"}) do
        local targetID=id
        local target=TARGET_BY_ID[id]
        self:CreateHandle(id,target.label,function(x,y)
            local frame=Layout:GetTargetFrame(targetID)
            local height=frame and frame:GetHeight()*frame:GetEffectiveScale()/UIParent:GetEffectiveScale() or 0
            Config():Set(target.keys[1],math.floor(x-ParentCenterX()+0.5))
            local origin=targetID=="crosshair" and UIParent:GetHeight()/2 or 0
            local inset=targetID=="crosshair" and 0 or height/2
            Config():Set(target.keys[2],math.floor(y-ParentBottom()-origin-inset+0.5))
        end)
    end
    for _,side in ipairs({"Left","Right"}) do
        local which=side
        self:CreateHandle(side,"Touch bar: " .. side,function(x,y)
            local bars=ConsoleExperience.actionbars
            local target=bars["sideBar" .. which .. "Frame"]
            local defaultX=which=="Left" and (12+target:GetWidth()/2) or (UIParent:GetWidth()-12-target:GetWidth()/2)
            Config():Set("sideBar" .. which .. "X",math.floor(x-UIParent:GetLeft()-defaultX+0.5))
            Config():Set("sideBar" .. which .. "Y",math.floor(y-ParentBottom()-UIParent:GetHeight()/2+0.5))
        end)
    end
    if ConsoleExperience.hooks and ConsoleExperience.hooks.HookDynamicFrame then
        ConsoleExperience.hooks:HookDynamicFrame(frame,"Windrunner Layout")
    end
end

function Layout:UpdateHandles()
    if not self.active then return end
    local g=self.mainGeometry or self:GetMainGeometry()
    local bars=self.handles.bars
    if not g.independent and not bars.dragging then
        bars:SetWidth(g.width); bars:SetHeight(g.height); bars:ClearAllPoints()
        bars:SetPoint("BOTTOM",UIParent,"BOTTOM",g.x+(g.centerOffsetX or 0),g.bottom)
    end
    if g.independent then bars:Hide() else bars:Show() end
    for _,side in ipairs({"left","right"}) do
        local mover=self.handles["main"..side]
        if g.independent then
            local group=g.groups[side]
            if not mover.dragging then
                mover:SetWidth(group.width); mover:SetHeight(group.height); mover:ClearAllPoints()
                mover:SetPoint("CENTER",UIParent,"BOTTOM",group.x,group.y)
            end
            mover:Show()
        else mover:Hide() end
    end
    local pet=ConsoleExperience.pet and ConsoleExperience.pet.frame
    local petMover=self.handles.pet
    if pet and pet:IsShown() then
        if not petMover.dragging then petMover:SetAllPoints(pet) end
        petMover:Show()
    else petMover:Hide() end
    local chat=ConsoleExperience.chat
    local handle=self.handles.chat
    if chat and chat:IsEnabled() and ChatFrame1 then
        if not handle.dragging then handle:SetAllPoints(ChatFrame1) end
        handle:Show()
    else handle:Hide() end
    for _,side in ipairs({"Left","Right"}) do
        local target=ConsoleExperience.actionbars["sideBar" .. side .. "Frame"]
        local mover=self.handles[side]
        if target and target:IsShown() then
            if not mover.dragging then mover:SetAllPoints(target) end
            mover:Show()
        else mover:Hide() end
    end
    for _,id in ipairs({"xp","rep","cast","crosshair","indicator"}) do
        local target=self:GetTargetFrame(id)
        local mover=self.handles[id]
        if target then
            if not mover.dragging then mover:SetAllPoints(target) end
            mover:Show()
        else mover:Hide() end
    end
    self:UpdateTargetButtons()
end

function Layout:Start()
    self:CreateEditor()
    local previousGeometry=self.mainGeometry or self:GetMainGeometry()
    if ChatFrameEditBox and ChatFrameEditBox:IsVisible() then ChatFrameEditBox:Hide() end
    local config=Config()
    if not self.active then self.returnToConfig=config.frame and config.frame:IsShown() or false end
    if config.frame then config.frame:Hide() end
    -- Detach once, keeping displayed HUD positions as the starting point.
    if not config:Get("hudIndependent") then
        local chat=ConsoleExperience.chat
        local c=chat and chat:GetIdleGeometry()
        for _,id in ipairs({"xp","rep","cast","indicator"}) do
            local target=self:GetTargetFrame(id)
            if target then
                local x,y=target:GetCenter()
                local scale=target:GetEffectiveScale()/UIParent:GetEffectiveScale()
                if x and y then self.handles[id].savePosition(x*scale,y*scale) end
            end
        end
        if c then config:Set("chatBottomY",c.y) end
        config:Set("hudIndependent",true)
    end
    self.active=true
    config:Set("barIndependent",true)
    local new=self:GetIndependentGeometry()
    for _,side in ipairs({"left","right"}) do
        local prefix=side=="left" and "barLeft" or "barRight"
        local old=previousGeometry
        local x=old.independent and old.centers[side].x or old.x+(side=="left" and -old.spacing or old.spacing)
        local y=old.independent and old.centers[side].y or old.y
        config:Set(prefix.."X",(config:Get(prefix.."X") or 0)+x-new.centers[side].x)
        config:Set(prefix.."Y",(config:Get(prefix.."Y") or 0)+y-new.centers[side].y)
    end
    self.selectedTarget=self.selectedTarget=="bars" and "mainleft" or self.selectedTarget or "mainleft"
    self:Refresh(); self.frame:Show()
    if ConsoleExperience.cursor and ConsoleExperience.cursor.RefreshFrame then ConsoleExperience.cursor:RefreshFrame() end
end

function Layout:Stop()
    if self:IsMoving() then self:CancelMove() end
    self.active=false
    if self.frame then self.frame:Hide() end
    for _,frame in pairs(self.handles or {}) do frame:StopMovingOrSizing(); frame:Hide() end
    self:Refresh()
    local restoreConfig=self.returnToConfig
    self.returnToConfig=nil
    if restoreConfig and Config().frame then Config().frame:Show() end
    if ConsoleExperience.cursor and ConsoleExperience.cursor.RefreshFrame then ConsoleExperience.cursor:RefreshFrame() end
end

-- Convenient even when chat is hidden between messages.
SLASH_CELAYOUT1="/celayout"
SLASH_CELAYOUT2="/windrunnerlayout"
SlashCmdList.CELAYOUT=function() if Layout.active then Layout:Stop() else Layout:Start() end end

local watcher=CreateFrame("Frame")
watcher:SetScript("OnUpdate",function()
    Layout.visibilityElapsed=(Layout.visibilityElapsed or 0)+(arg1 or 0)
    if Layout.visibilityElapsed>0.15 then
        Layout.visibilityElapsed=0
        if WindrunnerExperienceDB and WindrunnerExperienceDB.config then Layout:UpdateVisibility() end
    end
    local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    if width~=Layout.screenWidth or height~=Layout.screenHeight then
        Layout.screenWidth,Layout.screenHeight=width,height
        if WindrunnerExperienceDB and WindrunnerExperienceDB.config then Layout:Refresh() end
    end
end)

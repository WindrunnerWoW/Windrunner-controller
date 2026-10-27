local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
-- Categorized spell/item/macro/system picker. Every gameplay mutation is
-- performed by a visible button callback after the selected object is resolved
-- again.
ConsoleExperience.actionpicker = ConsoleExperience.actionpicker or {}
local Picker = ConsoleExperience.actionpicker
local BOOK = BOOKTYPE_SPELL or "spell"
local FRAME_WIDTH = 440
local FRAME_HEIGHT = 540
local ROW_HEIGHT = 36
-- The categories hold de-duplicated spellbook names, carried items, macros and
-- system actions, so the list stays small enough to build as real buttons.
local MAX_ROWS = 256
local CATEGORY_ORDER = {"menus", "spells", "items", "macros"}
local CATEGORY_LABELS = {menus="Menus", spells="Spells", items="Items", macros="Macros"}

local function L(value) return ConsoleExperience.locale and ConsoleExperience.locale.T(value) or value end
local function Theme(object, role) if ConsoleExperience.theme then ConsoleExperience.theme:Register(object,role) end end
local function ItemID(link)
    if not link then return nil end
    local _,_,value=string.find(link,"item:(%d+)")
    return tonumber(value)
end

-- Spellbook indices are absolute slots across all tabs. Walking the tab offsets
-- keeps every learned spell reachable on clients that leave gaps between tabs.
local function ForEachSpell(callback)
    if not GetSpellName then return end
    if GetNumSpellTabs and GetSpellTabInfo then
        local tabs=GetNumSpellTabs()
        local indexed=false
        for tab=1,tabs do
            local _,_,offset,count=GetSpellTabInfo(tab)
            if offset and count and count>0 then
                indexed=true
                for index=offset+1,offset+count do callback(index) end
            end
        end
        if indexed then return end
    end
    for index=1,1024 do
        if not GetSpellName(index,BOOK) then break end
        callback(index)
    end
end

local function FindSpell(name)
    if not GetSpellName then return nil end
    local best,bestRank,bestRankNumber,bestIcon
    ForEachSpell(function(index)
        local currentName,rank=GetSpellName(index,BOOK)
        if currentName==name then
            local _,_,rankText=string.find(rank or "","(%d+)")
            local rankNumber=tonumber(rankText) or 0
            if not best or rankNumber>=(bestRankNumber or 0) then
                best,bestRank,bestRankNumber=index,rank,rankNumber
                bestIcon=GetSpellTexture and GetSpellTexture(index,BOOK)
            end
        end
    end)
    return best,bestRank,bestIcon
end
local function FindMacro(name,body)
    if not GetMacroInfo then return nil end
    for index=1,36 do
        local currentName,icon,currentBody=GetMacroInfo(index)
        if currentName and currentName==name and (body==nil or currentBody==body) then return index,icon,currentBody end
    end
end
local function FindItem(itemID)
    if not GetContainerNumSlots or not GetContainerItemLink then return nil end
    for bag=0,4 do for slot=1,GetContainerNumSlots(bag) do
        if ItemID(GetContainerItemLink(bag,slot))==itemID then
            local texture,locked
            if GetContainerItemInfo then
                local itemTexture,itemCount,rawLocked=GetContainerItemInfo(bag,slot)
                texture=itemTexture
                locked=rawLocked == true or rawLocked == 1
            end
            return bag,slot,texture,locked
        end
    end end
end
local function HasCursorPayload()
    local cursor=ConsoleExperience.cursor
    return (CursorHasItem and CursorHasItem()) or (CursorHasSpell and CursorHasSpell())
        or (CursorHasMoney and CursorHasMoney()) or (SpellIsTargeting and SpellIsTargeting())
        or (cursor and cursor.heldItemTexturePath)
end
local function Report(message)
    if UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(L(message),1,.25,.2,1)
    elseif DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(L(message)) end
end
local function ValidActionSlot(slot)
    return type(slot)=="number" and slot==math.floor(slot) and slot>=1 and slot<=120
end
local function BindingStillValid(self)
    if not self.sourceBindingSlot then return ValidActionSlot(self.targetSlot) end
    local cfg=ConsoleExperience.config
    local info=cfg and cfg.GetBindingSlotInfo and cfg:GetBindingSlotInfo(self.sourceBindingSlot)
    if not info or info.binding then return false end
    local target=info.actionSlot
    if self.sourceBindingSlot>=1 and self.sourceBindingSlot<=40 then
        local bars=ConsoleExperience.actionbars
        if not bars or not bars.GetActionOffset then return false end
        local page=math.floor((self.sourceBindingSlot-1)/10)+1
        local button=math.mod(self.sourceBindingSlot-1,10)+1
        target=bars:GetActionOffset(page)+button
    end
    return target==self.targetSlot and ValidActionSlot(target)
end

local function CollectSpells()
    local data,seen={},{}
    ForEachSpell(function(index)
        local name,rank=GetSpellName(index,BOOK)
        if name then
            local key=string.lower(name)
            local entry=seen[key]
            local icon=GetSpellTexture and GetSpellTexture(index,BOOK)
            if not entry then
                entry={kind="spell",name=name,rank=rank,icon=icon}
                seen[key]=entry; table.insert(data,entry)
            else
                local _,_,newRank=string.find(rank or "","(%d+)")
                local _,_,oldRank=string.find(entry.rank or "","(%d+)")
                if (tonumber(newRank) or 0)>=(tonumber(oldRank) or 0) then entry.rank,entry.icon=rank,icon end
            end
        end
    end)
    table.sort(data,function(a,b) return string.lower(a.name or "")<string.lower(b.name or "") end)
    return data
end

local function CollectItems()
    local data={}
    if GetContainerNumSlots and GetContainerItemLink then
        for bag=0,4 do for slot=1,GetContainerNumSlots(bag) do
            local id=ItemID(GetContainerItemLink(bag,slot))
            if id then
                local texture,locked
                if GetContainerItemInfo then
                    local itemTexture,itemCount,rawLocked=GetContainerItemInfo(bag,slot)
                    texture=itemTexture
                    locked=rawLocked == true or rawLocked == 1
                end
                local name=GetItemInfo and GetItemInfo(id) or ("Item "..id)
                table.insert(data,{kind="item",name=name,itemID=id,bag=bag,slot=slot,icon=texture,locked=locked})
            end
        end end
    end
    table.sort(data,function(a,b)
        local left=string.lower((a.name or "").." "..tostring(a.itemID))
        local right=string.lower((b.name or "").." "..tostring(b.itemID))
        return left<right
    end)
    return data
end

local function CollectMacros()
    local data={}
    if GetMacroInfo then
        -- Vanilla 1.12 has 36 macro indices. Empty slots may appear between entries.
        for index=1,36 do
            local name,icon,body=GetMacroInfo(index)
            if name then table.insert(data,{kind="macro",name=name,macroID=index,body=body,icon=icon}) end
        end
    end
    table.sort(data,function(a,b) return string.lower(a.name or "")<string.lower(b.name or "") end)
    return data
end

-- Native WoW binding actions can also live in utility rings. Custom CE_*
-- actions are handled by controller dispatch and cannot be executed by
-- RunBinding from a ring entry, so they stay out of this list.
local function CollectRingActions()
    local entries, seen = {}, {}
    local proxied = ConsoleExperience.proxied
    if not proxied or not proxied.ACTIONS then return entries end
    local function Add(action)
        if action.id and string.sub(action.id, 1, 3) ~= "CE_" and not seen[action.id] then
            seen[action.id] = true
            table.insert(entries, {
                kind = "action",
                command = action.id,
                id = action.id,
                name = proxied.GetActionName and proxied:GetActionName(action) or action.name or action.id,
                description = proxied.GetActionDesc and proxied:GetActionDesc(action) or action.desc or "",
                icon = action.icon,
            })
        end
    end
    -- Put the game menu first; it is the most common utility ring entry.
    for _, action in ipairs(proxied.ACTIONS) do if action.id == "TOGGLEGAMEMENU" then Add(action) end end
    for _, action in ipairs(proxied.ACTIONS) do if action.id ~= "TOGGLEGAMEMENU" then Add(action) end end
    return entries
end
local function CollectSystemActions(assignment)
    local entries,seen={},{}
    local function Add(id,name,description,icon,current)
        if id and seen[id] then return end
        if id then seen[id]=true end
        table.insert(entries,{kind="system",id=id,name=name or tostring(id or ""),description=description,icon=icon,current=current})
    end
    if assignment.kind=="slot" then
        local proxied=ConsoleExperience.proxied
        Add(nil,L("None (Action Bar)"),L("Use this input's action-bar slot instead."),nil,assignment.current==nil)
        for _,action in ipairs(proxied and proxied.ACTIONS or {}) do
            if action.id then
                Add(action.id,proxied:GetActionName(action),proxied:GetActionDesc(action),action.icon,assignment.current==action.id)
            end
        end
    else
        local controls=ConsoleExperience.controllerControls
        for _,action in ipairs(controls and controls.SPECIAL_ACTIONS or {}) do
            local info=controls:GetActionInfo(action.id)
            if info then Add(info.id,info.name,info.desc,info.icon,assignment.current==info.id) end
        end
        local proxied=ConsoleExperience.proxied
        for _,action in ipairs(proxied and proxied.ACTIONS or {}) do
            if action.id then
                Add(action.id,proxied:GetActionName(action),proxied:GetActionDesc(action),action.icon,assignment.current==action.id)
            end
        end
    end
    return entries
end
local function Matches(entry,query)
    if query=="" then return true end
    return string.find(string.lower((entry.name or "").." "..(entry.rank or "").." "..(entry.description or "")
        .." "..tostring(entry.id or "").." "..entry.kind.." "..tostring(entry.categoryLabel or "")),query,1,true)~=nil
end

function Picker:Open(slot)
    if not ValidActionSlot(slot) then Report("Choose a valid action slot (1-120). There is no action slot on this control."); return false end
    self.targetSlot=slot; self.sourceBindingSlot=nil; self.ringIndex=nil; self.systemAssignment=nil
    self.preferredCategory="spells"; self:ResetCategories(); self:PrepareCategories(); self:PickCategory(); self:Show(); return true
end
function Picker:OpenForBinding(bindingSlot)
    if type(bindingSlot)~="number" or bindingSlot~=math.floor(bindingSlot) or bindingSlot<1 or bindingSlot>50 then
        Report("Choose a valid controller action slot."); return false
    end
    local cfg=ConsoleExperience.config
    local info=cfg and cfg.GetBindingSlotInfo and cfg:GetBindingSlotInfo(bindingSlot)
    local target=info and info.actionSlot
    if info and not info.binding and type(bindingSlot)=="number" and bindingSlot>=1 and bindingSlot<=40 then
        local bars=ConsoleExperience.actionbars
        if bars and bars.GetActionOffset then
            local page=math.floor((bindingSlot-1)/10)+1
            local button=math.mod(bindingSlot-1,10)+1
            target=bars:GetActionOffset(page)+button
        end
    end
    if not info or info.binding or not ValidActionSlot(target) then
        Report("System and stance actions cannot hold spells, items, or macros."); return false
    end
    self.targetSlot=target; self.sourceBindingSlot=bindingSlot; self.ringIndex=nil; self.systemAssignment=nil
    self.preferredCategory="spells"; self:ResetCategories(); self:PrepareCategories(); self:PickCategory(); self:Show(); return true
end
function Picker:OpenForRing(index)
    if not ConsoleExperience.rings or not ConsoleExperience.rings:GetAll()[index] then return false end
    self.targetSlot=nil; self.sourceBindingSlot=nil; self.ringIndex=index; self.systemAssignment=nil
    self.preferredCategory="spells"; self:ResetCategories(); self:PrepareCategories(); self:PickCategory(); self:Show(); return true
end
function Picker:OpenForSlotBinding(slot,preferredCategory)
    local config=ConsoleExperience.config
    local view=config and config.bindingOverview
    local proxied=ConsoleExperience.proxied
    if type(slot)~="number" or slot~=math.floor(slot) or slot<1 or slot>50 or not view
        or view.mode~="actions" or view.selectedSlot~=slot or not proxied then return false end
    self.targetSlot=nil; self.sourceBindingSlot=nil; self.ringIndex=nil
    self.systemAssignment={kind="slot",slot=slot,page=view.page,current=proxied:GetSlotBinding(slot)}
    self.preferredCategory=preferredCategory or "spells"
    self:ResetCategories(); self:PrepareCategories(); self:PickCategory(); self:Show(); return true
end
function Picker:OpenForControllerInput(input,page)
    local config=ConsoleExperience.config
    local view=config and config.bindingOverview
    local controls=ConsoleExperience.controllerControls
    local info=controls and controls:GetInputInfo(input,page)
    if not view or view.mode~="controls" or view.selectedInput~=input or view.page~=page
        or not info or not info.editable then return false end
    self.targetSlot=nil; self.sourceBindingSlot=nil; self.ringIndex=nil
    self.systemAssignment={kind="control",input=input,page=page,current=controls:GetBinding(input,page)}
    self.preferredCategory="menus"; self:ResetCategories(); self:PrepareCategories(); self:PickCategory(); self:Show(); return true
end
function Picker:IsVisible() return self.frame and self.frame:IsVisible() or false end
function Picker:Back() if self.frame then self.frame:Hide() end end

function Picker:ResetCategories()
    self.categories=nil
    self.entries=nil
    self.filtered=nil
    self.category=nil
end

function Picker:AddCategory(specs,id,entries)
    if not entries or table.getn(entries)==0 then return end
    local label=L(CATEGORY_LABELS[id])
    for _,entry in ipairs(entries) do
        entry.category=id
        entry.categoryLabel=label
    end
    table.insert(specs,{id=id,label=label,entries=entries})
end

function Picker:PrepareCategories()
    local specs={}
    if self.systemAssignment and self.systemAssignment.kind=="control" then
        self:AddCategory(specs,"menus",CollectSystemActions(self.systemAssignment))
    elseif self.ringIndex then
        self:AddCategory(specs,"menus",CollectRingActions())
        self:AddCategory(specs,"spells",CollectSpells())
        self:AddCategory(specs,"items",CollectItems())
        self:AddCategory(specs,"macros",CollectMacros())
    elseif self.systemAssignment and self.systemAssignment.kind=="slot" then
        self:AddCategory(specs,"menus",CollectSystemActions(self.systemAssignment))
        self:AddCategory(specs,"spells",CollectSpells())
        self:AddCategory(specs,"items",CollectItems())
        self:AddCategory(specs,"macros",CollectMacros())
    else
        self:AddCategory(specs,"spells",CollectSpells())
        self:AddCategory(specs,"items",CollectItems())
        self:AddCategory(specs,"macros",CollectMacros())
    end
    self.categories=specs
    self.entries={}
    for _,category in ipairs(specs) do
        for _,entry in ipairs(category.entries) do table.insert(self.entries,entry) end
    end
end

function Picker:GetCategory(id)
    for _,category in ipairs(self.categories or {}) do
        if category.id==id then return category end
    end
end

function Picker:PickCategory()
    local available={}
    for _,category in ipairs(self.categories or {}) do available[category.id]=true end
    if self.preferredCategory and available[self.preferredCategory] then
        self.category=self.preferredCategory
    elseif self.lastCategory and available[self.lastCategory] then
        self.category=self.lastCategory
    elseif available.spells then
        self.category="spells"
    elseif self.categories and self.categories[1] then
        self.category=self.categories[1].id
    else
        self.category=nil
    end
    self.preferredCategory=nil
end

function Picker:SelectCategory(id)
    if self.category==id then return end
    self.category=id; self.lastCategory=id
    self:Refresh(true)
    if ConsoleExperience.cursor and ConsoleExperience.cursor.RefreshFrame then ConsoleExperience.cursor:RefreshFrame() end
end

function Picker:Show()
    if not self.frame then self:CreateFrame() end
    if not self.categories then self:PrepareCategories(); self:PickCategory() end
    local control=self.systemAssignment and self.systemAssignment.kind=="control"
    self.title:SetText(L(control and "Choose System Action" or (self.ringIndex and "Add to Ring" or "Choose an Action")))
    if control then
        self.infoHelp=L("Choose a system action for this control.")
    elseif self.ringIndex then
        self.infoHelp=L("Choose a spell, item, macro, or menu action to add to this ring.")
    elseif self.systemAssignment then
        self.infoHelp=L("Pick a spell, item, or macro. Menus replace the slot assignment.")
    else
        self.infoHelp=L("Select a result to place.")
    end
    self.info:SetText(self.infoHelp)
    if self.search and self.search.SetText then self.search:SetText("") end
    self:Refresh(true)
    self:FitFrame(); self.frame:Show()
    if ConsoleExperience.hooks then ConsoleExperience.hooks:HookDynamicFrame(self.frame,"Action Picker") end
end
function Picker:FitFrame()
    local frame=self.frame; if not frame then return end
    local sw,sh=UIParent:GetWidth(),UIParent:GetHeight()
    local scale=math.min(1,(sw-32)/FRAME_WIDTH,(sh-32)/FRAME_HEIGHT)
    frame:SetScale(math.max(.05,scale))
end
function Picker:CreateFrame()
    local frame=CreateFrame("Frame","CEActionPickerFrame",UIParent)
    frame:SetWidth(FRAME_WIDTH); frame:SetHeight(FRAME_HEIGHT); frame:SetPoint("CENTER",UIParent,"CENTER",0,0)
    frame:SetFrameStrata("FULLSCREEN_DIALOG"); frame:SetFrameLevel(130); frame:EnableMouse(true); frame:SetClampedToScreen(true); frame.ceNavigationModal=true
    Theme(frame,"panel")
    local title=frame:CreateFontString("CEActionPickerTitle","OVERLAY","GameFontNormalLarge")
    title:SetPoint("TOP",frame,"TOP",0,-18); title:SetText(L("Choose an Action")); Theme(title,"accent"); self.title=title
    local search=CreateFrame("EditBox","CEActionPickerSearch",frame,"InputBoxTemplate")
    search:SetWidth(376); search:SetHeight(26); search:SetPoint("TOPLEFT",frame,"TOPLEFT",24,-46); search:SetAutoFocus(false)
    if search.SetTextInsets then search:SetTextInsets(6,6,0,0) end
    Theme(search,"field"); self.search=search

    -- Category tabs replace the old Previous/Next paging. Empty categories are
    -- skipped, so a control input only offers its applicable action list.
    self.categoryButtons={}
    for _,id in ipairs(CATEGORY_ORDER) do
        local captured=id
        local button=CreateFrame("Button","CEActionPickerTab"..id,frame,"UIPanelButtonTemplate")
        button:SetHeight(26); button:SetText(L(CATEGORY_LABELS[id])); button.label=L(CATEGORY_LABELS[id]); button:Hide()
        button:SetScript("OnClick",function() Picker:SelectCategory(captured) end)
        if ConsoleExperience.theme then ConsoleExperience.theme:Button(button) end
        self.categoryButtons[id]=button
    end

    local list=CreateFrame("ScrollFrame","CEActionPickerListScrollFrame",frame,"UIPanelScrollFrameTemplate")
    list:SetPoint("TOPLEFT",frame,"TOPLEFT",22,-112)
    list:SetWidth(396); list:SetHeight(346); Theme(list,"field")
    local child=CreateFrame("Frame","CEActionPickerListScrollChild",list)
    child:SetWidth(374); child:SetHeight(1)
    list:SetScrollChild(child); self.list=list; self.listChild=child
    local bar=getglobal("CEActionPickerListScrollFrameScrollBar")
    if bar then
        bar.cursorIgnore=true
        for _,widget in ipairs({bar:GetChildren()}) do widget.cursorIgnore=true end
    end
    if list.EnableMouseWheel then
        list:EnableMouseWheel(true)
        list:SetScript("OnMouseWheel",function()
            local scrollBar=getglobal("CEActionPickerListScrollFrameScrollBar")
            if scrollBar and scrollBar.SetValue and scrollBar.GetValue then
                local minValue,maxValue=scrollBar:GetMinMaxValues()
                local value=scrollBar:GetValue()-((arg1 or 0)*ROW_HEIGHT*2)
                if value<minValue then value=minValue end
                if value>maxValue then value=maxValue end
                scrollBar:SetValue(value)
            end
        end)
    end

    self.rows={}
    local info=frame:CreateFontString("CEActionPickerInfo","OVERLAY","GameFontHighlightSmall")
    info:SetPoint("BOTTOM",frame,"BOTTOM",0,42); info:SetWidth(392); info:SetHeight(34); info:SetJustifyH("CENTER")
    info:SetText(L("Select a result to place.")); Theme(info,"muted")
    self.info=info
    local close=CreateFrame("Button","CEActionPickerClose",frame,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-4,-4)
    search:SetScript("OnTextChanged",function() Picker:Refresh(true) end)
    frame:SetScript("OnHide",function()
        if Picker.search and Picker.search.ClearFocus then Picker.search:ClearFocus() end
        if WindrunnerController and WindrunnerController.Release then WindrunnerController:Release() end
        if ConsoleExperience.cursor and ConsoleExperience.cursor.RefreshFrame then ConsoleExperience.cursor:RefreshFrame() end
    end)
    self.frame=frame; tinsert(UISpecialFrames,"CEActionPickerFrame")
end

function Picker:CreateRow(index)
    local row=CreateFrame("Button","CEActionPickerRow"..index,self.listChild)
    row:SetWidth(372); row:SetHeight(ROW_HEIGHT-2)
    row.bg=row:CreateTexture(nil,"BACKGROUND"); row.bg:SetAllPoints(row); row.bg:SetTexture(.08,.08,.08,.45)
    row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetWidth(26); row.icon:SetHeight(26); row.icon:SetPoint("LEFT",row,"LEFT",6,0)
    row.label=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); row.label:SetPoint("LEFT",row.icon,"RIGHT",8,0); row.label:SetWidth(246); row.label:SetJustifyH("LEFT"); Theme(row.label,"text")
    row.hint=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); row.hint:SetPoint("RIGHT",row,"RIGHT",-6,0); row.hint:SetWidth(70); row.hint:SetJustifyH("RIGHT"); Theme(row.hint,"muted")
    row.cursorPrompt=L("Select")
    row:SetScript("OnEnter",function() if this.bg then this.bg:SetTexture(.20,.16,.11,.8) end end)
    row:SetScript("OnLeave",function() if this.bg then this.bg:SetTexture(.08,.08,.08,.45) end end)
    row:SetScript("OnClick",function() Picker:Choose(this.entry) end)
    self.rows[index]=row
    return row
end

function Picker:EntryLabel(entry,crossCategory)
    local label=entry.name or ""
    if entry.current and entry.current==entry.id then label="> "..label end
    return label
end

function Picker:BuildFiltered(query)
    if query=="" then
        local category=self:GetCategory(self.category)
        return category and category.entries or {}
    end
    -- A search spans all categories so a name in the spellbook is found even
    -- while another category is selected.
    local filtered={}
    for _,category in ipairs(self.categories or {}) do
        for _,entry in ipairs(category.entries) do
            if Matches(entry,query) then table.insert(filtered,entry) end
        end
    end
    return filtered
end

function Picker:UpdateCategoryButtons()
    local count=table.getn(self.categories or {})
    local width=math.min(118,math.floor((392-((count>0 and count or 1)-1)*6)/math.max(1,count)))
    local x=24
    for _,category in ipairs(self.categories or {}) do
        local button=self.categoryButtons and self.categoryButtons[category.id]
        if button then
            button:Show(); button:ClearAllPoints(); button:SetPoint("TOPLEFT",self.frame,"TOPLEFT",x,-78)
            button:SetWidth(width); button:SetText(category.label); button.label=category.label
            button.themeSelected=category.id==self.category
            if ConsoleExperience.theme then ConsoleExperience.theme:Apply(button) end
            x=x+width+6
        end
    end
    for id,button in pairs(self.categoryButtons or {}) do
        local shown=false
        for _,category in ipairs(self.categories or {}) do if category.id==id then shown=true end end
        if not shown then button:Hide() end
    end
end

function Picker:Refresh(resetScroll)
    if not self.frame or not self.rows then return end
    local query=string.lower((self.search and self.search.GetText and self.search:GetText()) or "")
    self.filtered=self:BuildFiltered(query)
    local crossCategory=query~=""
    local count=table.getn(self.filtered)
    if count>MAX_ROWS then count=MAX_ROWS end
    for i=1,count do
        local row=self.rows[i] or self:CreateRow(i)
        local entry=self.filtered[i]
        row.entry=entry
        row.label:SetText(self:EntryLabel(entry,crossCategory))
        row.hint:SetText(crossCategory and (entry.categoryLabel or "") or (entry.rank or ""))
        if entry.icon then SetPortraitToTexture(row.icon,entry.icon) else row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",self.listChild,"TOPLEFT",0,-((i-1)*ROW_HEIGHT))
        row:Show()
    end
    for i=count+1,table.getn(self.rows) do
        local row=self.rows[i]
        if row then row:Hide(); row.entry=nil end
    end
    if self.listChild and self.listChild.SetHeight then self.listChild:SetHeight(math.max(1,count*ROW_HEIGHT)) end
    if self.list and self.list.UpdateScrollChildRect then self.list:UpdateScrollChildRect() end
    local scrollBar=getglobal("CEActionPickerListScrollFrameScrollBar")
    if scrollBar and scrollBar.SetMinMaxValues and self.list then
        scrollBar:SetMinMaxValues(0,math.max(0,(count*ROW_HEIGHT)-(self.list:GetHeight() or 0)))
    end
    self:UpdateCategoryButtons()
    if resetScroll then
        if scrollBar and scrollBar.SetValue then scrollBar:SetValue(0) end
        if self.list and self.list.SetVerticalScroll then self.list:SetVerticalScroll(0) end
    end
    if count==0 and self.info and self.info.SetText then
        self.info:SetText(L("No matching actions. Try another search."))
    elseif self.info and self.info.SetText and self.infoHelp then
        self.info:SetText(self.infoHelp)
    end
end

local function Place(entry,slot)
    if not ValidActionSlot(slot) or not PlaceAction then return false,"invalid target" end
    if HasCursorPayload() then return false,"cursor is occupied" end
    if entry.kind=="spell" then
        local index,rank,icon=FindSpell(entry.name)
        if not index or not PickupSpell then return false,"spell unavailable" end
        PickupSpell(index,BOOK)
        if not (CursorHasSpell and CursorHasSpell()) then return false,"spell pickup failed" end
        PlaceAction(slot)
    elseif entry.kind=="item" then
        local bag,bagSlot,texture,locked=FindItem(entry.itemID)
        if not bag or locked or not PickupContainerItem then return false,locked and "item locked" or "item unavailable" end
        PickupContainerItem(bag,bagSlot)
        if not (CursorHasItem and CursorHasItem()) then return false,"item pickup failed" end
        PlaceAction(slot)
    elseif entry.kind=="macro" then
        local index,icon,body=FindMacro(entry.name,entry.body)
        if not index or not PickupMacro then return false,"macro changed" end
        local result=PickupMacro(index)
        if result==false then return false,"macro pickup failed" end
        -- Vanilla's PickupMacro is a void API and macros do not report through
        -- CursorHasItem/Spell. The synchronous, validated pickup is the only
        -- available stock-client evidence before PlaceAction.
        PlaceAction(slot)
    else return false,"unknown action" end
    return true
end

local function ChooseSystemAction(self,entry)
    local assignment=self.systemAssignment
    local config=ConsoleExperience.config
    local view=config and config.bindingOverview
    if not assignment or not entry or entry.kind~="system" or not view then return false end
    local id=entry.id
    if assignment.kind=="slot" then
        if view.mode~="actions" or view.page~=assignment.page or view.selectedSlot~=assignment.slot then
            Report("The selected binding changed while the picker was open. Reopen it and choose again.")
            if self.frame then self.frame:Hide() end
            return false
        end
        local proxied=ConsoleExperience.proxied
        if not proxied or (id~=nil and not proxied:GetActionByID(id)) then return false end
        proxied:SetSlotBinding(assignment.slot,id)
        if proxied:GetSlotBinding(assignment.slot)~=id then return false end
    elseif assignment.kind=="control" then
        local controls=ConsoleExperience.controllerControls
        local info=controls and controls:GetInputInfo(assignment.input,assignment.page)
        if view.mode~="controls" or view.page~=assignment.page or view.selectedInput~=assignment.input
            or not info or not info.editable or type(id)~="string" or not controls:GetActionInfo(id) then
            Report("The selected control changed while the picker was open. Reopen it and choose again.")
            if self.frame then self.frame:Hide() end
            return false
        end
        if not controls:SetBinding(assignment.input,id,assignment.page) then return false end
    else return false end
    if config.RefreshBindingOverview then config:RefreshBindingOverview() end
    self.systemAssignment=nil
    if self.frame then self.frame:Hide() end
    return true
end

-- A spell, item, or macro selected for a controller slot is placed on the
-- underlying action-bar slot. A successful placement then clears any system
-- assignment, so the new action is what the button runs.
local function ChooseActionForSlot(self,entry)
    local assignment=self.systemAssignment
    local config=ConsoleExperience.config
    local view=config and config.bindingOverview
    if not assignment or assignment.kind~="slot" or not view then return false end
    if view.mode~="actions" or view.page~=assignment.page or view.selectedSlot~=assignment.slot then
        Report("The selected binding changed while the picker was open. Reopen it and choose again.")
        if self.frame then self.frame:Hide() end
        return false
    end
    local info=config.GetBindingSlotInfo and config:GetBindingSlotInfo(assignment.slot)
    if not info then
        Report("This binding cannot hold spells, items, or macros.")
        return false
    end
    local target=info.actionSlot
    if assignment.slot>=1 and assignment.slot<=40 then
        local bars=ConsoleExperience.actionbars
        if not bars or not bars.GetActionOffset then return false end
        local page=math.floor((assignment.slot-1)/10)+1
        local button=math.mod(assignment.slot-1,10)+1
        target=bars:GetActionOffset(page)+button
    end
    if not ValidActionSlot(target) then
        Report("This binding cannot hold spells, items, or macros.")
        return false
    end
    local success,reason=Place(entry,target)
    if success then
        local proxied=ConsoleExperience.proxied
        if proxied and proxied:GetSlotBinding(assignment.slot)~=nil then
            proxied:SetSlotBinding(assignment.slot,nil)
        end
        if config.RefreshBindingOverview then config:RefreshBindingOverview() end
        if ConsoleExperience.cursor and ConsoleExperience.cursor.RefreshFrame then ConsoleExperience.cursor:RefreshFrame() end
        self.systemAssignment=nil
        if self.frame then self.frame:Hide() end
        return true
    end
    Report(reason=="cursor is occupied" and "Clear the cursor or finish targeting before placing an action." or "This action could not be placed: "..tostring(reason))
    return false
end

function Picker:Choose(entry)
    if not entry then return false end
    if self.systemAssignment and self.systemAssignment.kind=="control" then return ChooseSystemAction(self,entry) end
    if self.ringIndex then
        local added=false
        if entry.kind=="spell" then added=ConsoleExperience.rings:Add({kind="spell",name=entry.name,icon=entry.icon},self.ringIndex)
        elseif entry.kind=="item" then added=ConsoleExperience.rings:Add({kind="item",name=entry.name,itemID=entry.itemID,icon=entry.icon},self.ringIndex)
        elseif entry.kind=="action" then added=ConsoleExperience.rings:Add({kind="action",command=entry.command,name=entry.name,icon=entry.icon},self.ringIndex)
        elseif entry.kind=="macro" then
            local index,icon,body=FindMacro(entry.name,entry.body)
            local actionSlot
            if index and GetActionText then
                for slot=1,120 do if GetActionText(slot)==entry.name then actionSlot=slot; break end end
            end
            if actionSlot then added=ConsoleExperience.rings:Add({kind="macro",name=entry.name,slot=actionSlot,body=body,icon=icon or entry.icon},self.ringIndex)
            else Report("Place this macro on an action bar before adding it to a ring.") end
        end
        if not added then Report("This entry is already in the ring or the ring is full.") end
        if added then
            self:PrepareCategories()
            self:Refresh()
        end
        return added
    end
    if self.systemAssignment then
        if entry.kind=="system" then return ChooseSystemAction(self,entry) end
        return ChooseActionForSlot(self,entry)
    end
    if not BindingStillValid(self) then Report("This control changed while the picker was open. Reopen the picker and choose again."); self.frame:Hide(); return false end
    local success,reason=Place(entry,self.targetSlot)
    if success then self.frame:Hide(); return true end
    Report(reason=="cursor is occupied" and "Clear the cursor or finish targeting before placing an action." or "This action could not be placed: "..tostring(reason))
    return false
end

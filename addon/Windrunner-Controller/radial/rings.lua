local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
-- User-managed utility rings for spells, carried items, and action-slot macros.
-- This module is loaded after radial/radial.lua.
ConsoleExperience.rings = ConsoleExperience.rings or {}
local Rings = ConsoleExperience.rings
local BOOK = BOOKTYPE_SPELL or "spell"
local MAX_RINGS = 12
local MAX_ENTRIES = 12

local function RingData()
    if not WindrunnerExperienceDB then WindrunnerExperienceDB = {} end
    if not WindrunnerExperienceDB.config then WindrunnerExperienceDB.config = {} end
    local all = WindrunnerExperienceDB.config.utilityRings
    if type(all) ~= "table" then all = {}; WindrunnerExperienceDB.config.utilityRings = all end
    return all
end
local function Notify(msg)
    if UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(msg, 1, .25, .2, 1)
    elseif DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(msg) end
end
local function CleanName(name)
    name = string.gsub(tostring(name or ""), "^%s*(.-)%s*$", "%1")
    if string.len(name) > 28 then name = string.sub(name, 1, 28) end
    return name
end
local function ItemID(link)
    if not link then return nil end
    local _, _, value = string.find(link, "item:(%d+)")
    return tonumber(value)
end

function Rings:Validate()
    local saved, valid, names = RingData(), {}, {}
    for _, ring in ipairs(saved) do
        if table.getn(valid) >= MAX_RINGS then break end
        if type(ring) == "table" then
            local name = CleanName(ring.name)
            if name == "" then name = "Ring " .. (table.getn(valid) + 1) end
            local base, suffix, n = name, 2, 1
            while names[string.lower(name)] do name = base .. " " .. suffix; suffix = suffix + 1 end
            names[string.lower(name)] = true
            local entries = {}
            if type(ring.entries) == "table" then
                for _, entry in ipairs(ring.entries) do
                    if table.getn(entries) >= MAX_ENTRIES then break end
                    if type(entry) == "table" and (entry.kind == "spell" and type(entry.name) == "string"
                        or entry.kind == "item" and tonumber(entry.itemID)
                        or entry.kind == "macro" and tonumber(entry.slot) and type(entry.name) == "string" and type(entry.body) == "string"
                        or entry.kind == "action" and type(entry.command) == "string" and string.len(entry.command) <= 64) then
                        table.insert(entries, {kind=entry.kind, name=entry.name, itemID=tonumber(entry.itemID),
                            slot=tonumber(entry.slot), icon=entry.icon, body=entry.body, command=entry.command})
                    end
                end
            end
            table.insert(valid, {name=name, entries=entries})
        end
    end
    WindrunnerExperienceDB.config.utilityRings = valid
    self.selectedRing = math.min(math.max(1, self.selectedRing or 1), math.max(1, table.getn(valid)))
    local radial = ConsoleExperience.radial
    if radial and radial.RegisterCollection then
        for _, oldName in ipairs(self.collectionNames or {}) do radial.collections[oldName] = nil end
        self.collectionNames = {}
        for index, ring in ipairs(valid) do
            local ringIndex, collectionName = index, "Ring: " .. ring.name
            table.insert(self.collectionNames, collectionName)
            radial:RegisterCollection(collectionName, function()
                return Rings:BuildItems(ringIndex), function() radial:Hide(); Rings:OpenEditor() end
            end)
        end
    end
    return valid
end

function Rings:GetAll() return self:Validate() end
function Rings:GetSelected()
    local all = self:Validate()
    return all[self.selectedRing or 1]
end
function Rings:Create(name)
    local all = self:Validate()
    if table.getn(all) >= MAX_RINGS then return false, "Maximum of 12 rings reached." end
    name = CleanName(name)
    if name == "" then name = "Ring " .. (table.getn(all) + 1) end
    for _, ring in ipairs(all) do if string.lower(ring.name) == string.lower(name) then return false, "A ring with that name already exists." end end
    table.insert(all, {name=name, entries={}})
    self.selectedRing = table.getn(all)
    self:RefreshEditor()
    return true
end
function Rings:Rename(index, name)
    local all, ring = self:Validate(), nil
    ring = all[index or self.selectedRing]
    name = CleanName(name)
    if not ring or name == "" then return false end
    for i, other in ipairs(all) do if i ~= (index or self.selectedRing) and string.lower(other.name) == string.lower(name) then return false end end
    ring.name = name; self:RefreshEditor(); return true
end
function Rings:Delete(index)
    local all = self:Validate(); index = index or self.selectedRing
    if not all[index] then return false end
    table.remove(all, index); self.selectedRing = math.max(1, math.min(index, table.getn(all)))
    self:RefreshEditor(); return true
end
function Rings:Add(entry, index)
    local all = self:Validate(); local ring = all[index or self.selectedRing]
    if not ring or type(entry) ~= "table" then return false end
    for _, old in ipairs(ring.entries) do
        if old.kind == entry.kind and ((entry.kind == "spell" and old.name == entry.name)
            or (entry.kind == "item" and old.itemID == entry.itemID)
            or (entry.kind == "macro" and old.slot == entry.slot)
            or (entry.kind == "action" and old.command == entry.command)) then return false end
    end
    if table.getn(ring.entries) >= MAX_ENTRIES then return false end
    table.insert(ring.entries, {kind=entry.kind, name=entry.name, itemID=entry.itemID,
        slot=entry.slot, icon=entry.icon, body=entry.body, command=entry.command})
    self:RefreshEditor(); return true
end
function Rings:Remove(index, entryIndex)
    local ring = self:Validate()[index or self.selectedRing]
    if not ring or not ring.entries[entryIndex] then return false end
    table.remove(ring.entries, entryIndex); self:RefreshEditor(); return true
end
function Rings:Move(index, entryIndex, delta)
    local ring = self:Validate()[index or self.selectedRing]
    local target = entryIndex + delta
    if not ring or not ring.entries[entryIndex] or not ring.entries[target] then return false end
    ring.entries[entryIndex], ring.entries[target] = ring.entries[target], ring.entries[entryIndex]
    self:RefreshEditor(); return true
end

local function FindSpell(name)
    if not GetSpellName then return nil end
    local best, bestRank, bestRankNumber
    for index=1,512 do
        local spellName, rank = GetSpellName(index, BOOK)
        if not spellName then break end
        if spellName == name then
            local _, _, rankText = string.find(rank or "", "(%d+)")
            local rankNumber = tonumber(rankText) or 0
            if not best or rankNumber >= (bestRankNumber or 0) then
                best, bestRank, bestRankNumber = index, rank, rankNumber
            end
        end
    end
    return best, bestRank
end
local function MacroMatches(entry)
    if not entry or type(entry.name) ~= "string" or type(entry.body) ~= "string" or not GetMacroInfo then return false end
    local matches, matchingBody = 0, false
    for macroIndex=1,36 do
        local name, _, body = GetMacroInfo(macroIndex)
        if name and name == entry.name then
            matches = matches + 1
            if body == entry.body then matchingBody = true end
        end
    end
    -- Vanilla action slots expose only a macro's name. Duplicate names make
    -- the slot ambiguous, so require a unique name plus the saved body.
    return matches == 1 and matchingBody
end
local function MacroSlotMatches(entry)
    return MacroMatches(entry) and GetActionText and GetActionText(entry.slot) == entry.name or false
end
local function HasCursorPayload()
    local cursor=ConsoleExperience.cursor
    return (CursorHasItem and CursorHasItem()) or (CursorHasSpell and CursorHasSpell())
        or (CursorHasMoney and CursorHasMoney()) or (cursor and cursor.heldItemTexturePath)
        or (SpellIsTargeting and SpellIsTargeting())
end
local function ItemUsable(bag, slot)
    if not bag or HasCursorPayload() or not GetContainerItemInfo then return false end
    local _, _, locked = GetContainerItemInfo(bag, slot)
    return not (locked == true or locked == 1)
end
local function FindCarriedItem(itemID)
    if not GetContainerNumSlots or not GetContainerItemLink then return nil end
    for bag=0, 4 do
        for slot=1, GetContainerNumSlots(bag) do
            if ItemID(GetContainerItemLink(bag, slot)) == itemID then return bag, slot end
        end
    end
end

function Rings:BuildItems(index)
    local ring = self:Validate()[index]
    local items = {}
    if not ring then return items end
    for _, saved in ipairs(ring.entries) do
        local entry = saved
        if entry.kind == "spell" then
            local spellIndex, rank = FindSpell(entry.name)
            table.insert(items, {name=entry.name, subtitle=spellIndex and (rank or "") or "Spell unavailable",
                icon=GetSpellTexture and spellIndex and GetSpellTexture(spellIndex,BOOK) or entry.icon,
                isAvailable=function() return FindSpell(entry.name) ~= nil and not HasCursorPayload() end,
                action=function()
                    local current = FindSpell(entry.name)
                    if HasCursorPayload() then Notify("Clear the cursor or finish targeting before selecting an action.")
                    elseif current and CastSpell then CastSpell(current, BOOK) else Notify("That spell is no longer in your spellbook.") end
                end})
        elseif entry.kind == "item" then
            local bag, slot = FindCarriedItem(entry.itemID)
            local icon
            if bag and GetContainerItemInfo then icon = GetContainerItemInfo(bag,slot) end
            table.insert(items, {name=entry.name or ("Item " .. entry.itemID), subtitle=bag and ("Bag " .. bag .. ", slot " .. slot) or "Not carried",
                icon=icon or entry.icon, isAvailable=function()
                    local b,s=FindCarriedItem(entry.itemID)
                    return ItemUsable(b,s)
                end,
                action=function()
                    local currentBag, currentSlot = FindCarriedItem(entry.itemID)
                    if HasCursorPayload() then Notify("Clear the cursor or finish targeting before selecting an action.")
                    elseif not currentBag then Notify("That item is no longer in your bags.")
                    elseif not ItemUsable(currentBag,currentSlot) then Notify("That item is locked or unavailable.")
                    elseif UseContainerItem then UseContainerItem(currentBag, currentSlot) end
                end})
        elseif entry.kind == "macro" then
            local slot = entry.slot
            table.insert(items, {name=entry.name or ("Action " .. slot), subtitle=MacroSlotMatches(entry) and "Macro action" or "Action slot changed",
                icon=entry.icon, isAvailable=function() return MacroSlotMatches(entry) and not HasCursorPayload() end,
                action=function()
                    if HasCursorPayload() then Notify("Clear the cursor or finish targeting before selecting an action.")
                    elseif MacroSlotMatches(entry) and UseAction then UseAction(slot)
                    else Notify("That macro or action slot has changed.") end
                end})
        elseif entry.kind == "action" then
            local command = entry.command
            local proxied = ConsoleExperience.proxied
            local action = proxied and proxied.GetActionByID and proxied:GetActionByID(command)
            if action and string.sub(command, 1, 3) ~= "CE_" then
                local function CommandAvailable()
                    local current = ConsoleExperience.proxied
                    return current and current.GetActionByID and current:GetActionByID(command) ~= nil
                        and (command == "TOGGLEGAMEMENU" or not HasCursorPayload())
                end
                table.insert(items, {name=proxied.GetActionName and proxied:GetActionName(action) or (entry.name or command),
                    subtitle="System action", icon=action.icon or entry.icon,
                    isAvailable=CommandAvailable,
                    action=function()
                        if not CommandAvailable() then Notify("That system action is unavailable right now.")
                        elseif command == "TOGGLEGAMEMENU" and CE_ToggleGameMenu then
                            if not CE_ToggleGameMenu() then Notify("The game menu is unavailable.") end
                        elseif RunBinding then RunBinding(command)
                        else Notify("RunBinding is unavailable.") end
                    end})
            end
        end
    end
    return items
end

function Rings:Open(index)
    local all = self:Validate(); index = index or self.selectedRing
    local ring = all[index]
    if not ring then self:OpenEditor(); return end
    self.selectedRing = index
    local radial = ConsoleExperience.radial
    if not radial then return end
    local items = self:BuildItems(index)
    radial:ShowCollection("Ring: " .. ring.name, items, function() radial:Hide(); Rings:OpenEditor() end)
end
function Rings:BeginHeld(index)
    self:Open(index)
    if ConsoleExperience.radial then ConsoleExperience.radial:BeginHeldSelection() end
end
function Rings:EndHeld(activate)
    return ConsoleExperience.radial and ConsoleExperience.radial:EndHeldSelection(activate) or false
end
function Rings:IsVisible() return self.editor and self.editor:IsVisible() or false end
function Rings:Back() if self.editor then self.editor:Hide() end end

-- Compact editor. Entry discovery is handled by the shared searchable picker.
local function L(text) return ConsoleExperience.locale and ConsoleExperience.locale.T(text) or text end
local function Theme(object, role) if ConsoleExperience.theme then ConsoleExperience.theme:Register(object, role) end end
function Rings:OpenEditor()
    local all = self:Validate()
    if not self.editor then
        local frame = CreateFrame("Frame", "ConsoleExperienceRingEditor", UIParent)
        frame:SetWidth(480); frame:SetHeight(500); frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:SetFrameStrata("FULLSCREEN_DIALOG"); frame:SetFrameLevel(120); frame:EnableMouse(true); frame:SetClampedToScreen(true); frame.ceNavigationModal=true
        if ConsoleExperience.theme then ConsoleExperience.theme:Register(frame,"panel") end
        local title = frame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        title:SetPoint("TOP",frame,"TOP",0,-18); title:SetText(L("Utility Rings")); Theme(title,"accent"); frame.title=title
        local ringText=frame:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        ringText:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-54); ringText:SetWidth(220); ringText:SetJustifyH("LEFT"); frame.ringText=ringText; Theme(ringText,"text")
        frame.entryRows={}
        for i=1,MAX_ENTRIES do
            local row=CreateFrame("Button","CEUtilityRingEntry"..i,frame)
            row:SetWidth(434); row:SetHeight(25); row:SetPoint("TOPLEFT",frame,"TOPLEFT",24,-84-((i-1)*26))
            row.label=row:CreateFontString(nil,"OVERLAY","GameFontHighlight"); row.label:SetPoint("LEFT",row,"LEFT",5,0); row.label:SetWidth(416); row.label:SetJustifyH("LEFT"); Theme(row.label,"text")
            row:SetScript("OnClick",function() Rings.selectedEntry=this.entryIndex; Rings:RefreshEditor() end)
            frame.entryRows[i]=row
        end
        local edit=CreateFrame("EditBox","CEUtilityRingName",frame,"InputBoxTemplate"); edit:SetWidth(200); edit:SetHeight(24); edit:SetPoint("TOPLEFT",frame,"TOPLEFT",250,-52); edit:SetAutoFocus(false); Theme(edit,"field"); frame.nameEdit=edit
        edit:SetScript("OnEditFocusGained",function() edit.editingName=true end)
        edit:SetScript("OnEditFocusLost",function() edit.editingName=false end)
        edit:SetScript("OnEnterPressed",function() if Rings:GetSelected() then Rings:Rename(Rings.selectedRing,edit:GetText()) end; edit:ClearFocus() end)
        local function button(label,x,y,callback)
            local b=CreateFrame("Button","CEUtilityRing"..string.gsub(label,"%s+",""),frame,"UIPanelButtonTemplate"); b:SetWidth(100); b:SetHeight(30); b:SetText(L(label)); b:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",x,y); b:SetScript("OnClick",callback); if ConsoleExperience.theme then ConsoleExperience.theme:Button(b) end; return b
        end
        button("Previous",18,18,function()
            local count=table.getn(Rings:Validate()); if count>0 then Rings.selectedRing=Rings.selectedRing-1; if Rings.selectedRing<1 then Rings.selectedRing=count end; Rings:RefreshEditor() end
        end)
        button("Next",128,18,function()
            local count=table.getn(Rings:Validate()); if count>0 then Rings.selectedRing=Rings.selectedRing+1; if Rings.selectedRing>count then Rings.selectedRing=1 end; Rings:RefreshEditor() end
        end)
        button("Create",238,18,function() Rings:Create(frame.nameEdit:GetText()); frame.nameEdit:SetText("") end)
        button("Delete Ring",348,18,function() Rings:Delete(Rings.selectedRing) end)
        button("Add Entry",18,54,function()
            if ConsoleExperience.actionpicker then ConsoleExperience.actionpicker:OpenForRing(Rings.selectedRing) end
        end)
        button("Remove",128,54,function() Rings:Remove(Rings.selectedRing,Rings.selectedEntry) end)
        button("Move Up",238,54,function() Rings:Move(Rings.selectedRing,Rings.selectedEntry,-1) end)
        button("Move Down",348,54,function() Rings:Move(Rings.selectedRing,Rings.selectedEntry,1) end)
        local close=CreateFrame("Button","CEUtilityRingClose",frame,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-4,-4)
        frame:SetScript("OnHide",function()
            edit.editingName=false
            if WindrunnerController and WindrunnerController.Release then WindrunnerController:Release() end
            if ConsoleExperience.cursor and ConsoleExperience.cursor.RefreshFrame then ConsoleExperience.cursor:RefreshFrame() end
        end)
        self.editor=frame; tinsert(UISpecialFrames,"ConsoleExperienceRingEditor")
    end
    self:RefreshEditor(); self:FitEditor(); self.editor:Show()
    if ConsoleExperience.hooks then ConsoleExperience.hooks:HookDynamicFrame(self.editor,"Utility Ring Editor") end
end
function Rings:FitEditor()
    local frame=self.editor; if not frame then return end
    local sw,sh=UIParent:GetWidth(),UIParent:GetHeight()
    local scale=math.min(1,(sw-32)/480,(sh-32)/500)
    frame:SetScale(math.max(.05,scale))
end
function Rings:RefreshEditor()
    local frame=self.editor; if not frame then return end
    local all=self:Validate(); local ring=all[self.selectedRing]
    frame.ringText:SetText("Ring "..(ring and ring.name or "(none)").."\n"..table.getn(all).."/12 rings  |  "..(ring and table.getn(ring.entries) or 0).."/12 actions\nEdit name and press Enter")
    if frame.nameEdit and not frame.nameEdit.editingName then frame.nameEdit:SetText(ring and ring.name or "") end
    for i,row in ipairs(frame.entryRows or {}) do
        local entry=ring and ring.entries[i]
        row.entryIndex=entry and i or nil
        if entry then
            local label=entry.name
            if entry.kind=="action" then
                local proxied=ConsoleExperience.proxied
                local action=proxied and proxied.GetActionByID and proxied:GetActionByID(entry.command)
                label=action and proxied.GetActionName and proxied:GetActionName(action) or entry.command or label
            end
            label=label or (entry.kind=="item" and ("Item "..entry.itemID) or ("Action "..entry.slot))
            row.label:SetText((self.selectedEntry==i and "> " or "  ")..i..". "..label.."  ["..entry.kind.."]")
            row:Show()
        else row:Hide() end
    end
    if ring and self.selectedEntry and not ring.entries[self.selectedEntry] then self.selectedEntry=nil end
end

function Rings:Initialize() self:Validate() end
Rings:Initialize()


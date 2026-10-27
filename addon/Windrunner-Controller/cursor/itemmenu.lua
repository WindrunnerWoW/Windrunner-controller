local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
-- Item actions use the original 1.12 container APIs, inside a hardware input callback.
ConsoleExperience.itemmenu = {bankOpen=false}
local Menu = ConsoleExperience.itemmenu
local function L(key) return ConsoleExperience.locale.T(key) end
local function Visible(frame) return frame and frame:IsVisible() end
local function Held()
    return (CursorHasItem and CursorHasItem()) or (CursorHasSpell and CursorHasSpell())
        or (CursorHasMoney and CursorHasMoney()) or ConsoleExperience.cursor.heldItemTexturePath
        or (SpellIsTargeting and SpellIsTargeting())
end

-- A ContainerFrame number is a pool index, not a bag ID. Addon slots use their
-- own metadata; all actions below resolve the slot again before touching it.
function Menu:Resolve(button)
    if not button or not button.GetName then return end
    local name = button:GetName() or ""
    local bag, slot, bank
    if string.find(name,"^pfBag%-?%d+item%d+$") then
        local _,_,b,s = string.find(name,"^pfBag(%-?%d+)item(%d+)$")
        bag,slot = tonumber(b),tonumber(s)
    elseif string.find(name,"^BagshuiBagsItem%d+$") or string.find(name,"^BagshuiBankItem%d+$") then
        local data = button.bagshuiData
        if data then
            if data.isEmptySlotStack or (data.inventory and (not data.inventory.online or data.inventory.editMode)) then return end
            local item = data.item or data
            bag,slot = data.bagNum or item.bagNum,data.slotNum or item.slotNum
        end
        bank = string.find(name,"^BagshuiBank") ~= nil
    elseif string.find(name,"^BankFrameItem%d+$") then
        if button.isBag then return end
        bag,slot,bank = BANK_CONTAINER or -1,button:GetID(),true
    elseif string.find(name,"^ContainerFrame%d+Item%d+$") or string.find(name,"^BagnonItem%d+$")
        or string.find(name,"^BanknonItem%d+$") then
        if string.find(name,"^BagnonItem") or string.find(name,"^BanknonItem") then
            if button.isLink or (Bagnon_IsCachedItem and Bagnon_IsCachedItem(button)) then return end
        end
        local parent = button:GetParent()
        bag,slot = parent and parent:GetID(),button:GetID()
        bank = string.find(name,"^Banknon") ~= nil
    end
    if type(bag) ~= "number" or type(slot) ~= "number" or slot < 1 then return end
    bank = bank or bag == (BANK_CONTAINER or -1) or bag > (NUM_BAG_SLOTS or 4)
    return bag,slot,bank
end

function Menu:Read(button)
    local bag,slot,bank = self:Resolve(button)
    if not bag then return end
    if bank and not self.bankOpen and not Visible(BankFrame) then return end
    local texture,count,locked,quality = GetContainerItemInfo(bag,slot)
    local link = GetContainerItemLink(bag,slot)
    if not texture or not link then return end
    local _,_,itemString = string.find(link,"(item:[^|]+)")
    local data = button.bagshuiData
    local displayed = data and (data.itemString or (data.item and data.item.itemString))
    if displayed and displayed ~= itemString then return end
    local name,_,infoQuality,_,_,_,_,_,equipLoc = GetItemInfo(itemString or link)
    return {button=button,bag=bag,slot=slot,bank=bank,texture=texture,count=count or 1,
        locked=locked,quality=quality or infoQuality,name=name or link,link=link,equipLoc=equipLoc}
end

function Menu:Validate()
    local source = self.source
    if not source or not Visible(source.button) or Held() then return end
    local item = self:Read(source.button)
    if not item or item.bag ~= source.bag or item.slot ~= source.slot or item.link ~= source.link then return end
    return item
end

function Menu:Context(item)
    if item.bank then return "withdraw",L("Withdraw") end
    if Visible(MerchantFrame) then return "sell",L("Sell"),MerchantFrame.selectedTab == 2 end
    if Visible(AuctionFrame) then return "auction",L("Auction") end
    if Visible(TradeFrame) then return "trade",L("Trade") end
    if Visible(SendMailFrame) then return "attach",L("Attach") end
    if self.bankOpen or Visible(BankFrame) then return "deposit",L("Deposit") end
    return "use",L(item.equipLoc and item.equipLoc ~= "" and "Equip" or "Use")
end

function Menu:DisenchantSpell(item)
    if item.bank or not item.quality or item.quality < 2 or item.quality > 4
        or not item.equipLoc or item.equipLoc == "" or item.equipLoc == "INVTYPE_BAG"
        or not GetSpellName or not GetSpellTexture or not CastSpell or not SpellCanTargetItem then return end
    local book = BOOKTYPE_SPELL or "spell"
    for index=1,1024 do
        if not GetSpellName(index,book) then return end
        local texture = GetSpellTexture(index,book)
        if texture and string.find(string.lower(texture),"inv_enchant_disenchant$") then return index end
    end
end

function Menu:CanPreview(item)
    local slot = item.equipLoc
    return DressUpItemLink and slot and slot ~= "" and slot ~= "INVTYPE_BAG" and slot ~= "INVTYPE_NECK"
        and slot ~= "INVTYPE_FINGER" and slot ~= "INVTYPE_TRINKET" and slot ~= "INVTYPE_AMMO"
end

function Menu:RestoreFocus()
    local source = self.source
    local cursor = ConsoleExperience.cursor
    if source and Visible(source.button) then cursor:MoveCursorToButton(source.button) end
    self.source,self.mode,self.confirmCount = nil,nil,nil
end

function Menu:Close()
    if self.frame then self.frame:Hide() end
end

function Menu:Create()
    if self.frame then return end
    local theme = ConsoleExperience.theme
    local frame = CreateFrame("Frame","CEItemMenuFrame",UIParent)
    self.frame = frame
    frame:Hide()
    frame:SetWidth(380)
    frame:SetPoint("CENTER",UIParent,"CENTER",0,30)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(100)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame.ceNavigationModal = true
    theme:Register(frame,"panel")
    local function Text(size,role)
        local text = frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
        text:SetFont("Fonts\\FRIZQT__.TTF",size,"")
        text:SetJustifyH("LEFT")
        theme:Register(text,role)
        return text
    end
    self.title = Text(18,"accent")
    self.title:SetPoint("TOPLEFT",frame,"TOPLEFT",20,-18)
    self.icon = frame:CreateTexture(nil,"ARTWORK")
    self.icon:SetWidth(40); self.icon:SetHeight(40)
    self.icon:SetPoint("TOPLEFT",frame,"TOPLEFT",20,-52)
    self.itemName = Text(14,"text")
    self.itemName:SetPoint("TOPLEFT",frame,"TOPLEFT",72,-52)
    self.itemName:SetWidth(288); self.itemName:SetHeight(42)
    self.details = Text(12,"muted")
    self.details:SetPoint("TOPLEFT",frame,"TOPLEFT",20,-102)
    self.details:SetWidth(340); self.details:SetHeight(48)
    self.footer = Text(11,"muted")
    self.footer:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",20,14)
    self.footer:SetWidth(340); self.footer:SetHeight(36)
    self.rows = {}
    for index=1,10 do
        local button = CreateFrame("Button","CEItemMenuButton"..index,frame)
        button:SetWidth(340); button:SetHeight(34)
        button:SetPoint("TOPLEFT",frame,"TOPLEFT",20,-158-(index-1)*40)
        button.label = button:CreateFontString(nil,"OVERLAY","GameFontNormal")
        button.label:SetPoint("LEFT",button,"LEFT",12,0)
        button.label:SetWidth(316); button.label:SetJustifyH("LEFT")
        button:SetScript("OnClick",function() Menu:Execute(this.itemAction) end)
        button:SetScript("OnEnter",function()
            if GameTooltip then GameTooltip:Hide() end
        end)
        theme:Button(button,button.label)
        self.rows[index] = button
    end
    ConsoleExperience.hooks:HookDynamicFrame(frame,"CEItemMenuFrame")
    local hide = frame:GetScript("OnHide")
    frame:SetScript("OnHide",function()
        if hide then hide() end
        Menu:RestoreFocus()
        -- An accepting button may still be held when the popup closes. Require
        -- release before that input can become a bag click or gameplay action.
        if WindrunnerController and WindrunnerController.Release then WindrunnerController:Release() end
    end)
    frame:SetScript("OnUpdate",function()
        this.elapsed = (this.elapsed or 0) + arg1
        if this.elapsed < 0.2 then return end
        this.elapsed = 0
        local item = Menu:Validate()
        if not item then Menu:Close(); return end
        local context,_,unavailable = Menu:Context(item)
        local signature = context..":"..tostring(unavailable)..":"..tostring(item.count)..":"..tostring(item.locked)
        if signature ~= Menu.signature then Menu:Render(item) end
    end)
    if UISpecialFrames then table.insert(UISpecialFrames,"CEItemMenuFrame") end
end

function Menu:Render(item)
    local theme = ConsoleExperience.theme
    local context,label,unavailable = self:Context(item)
    self.signature = context..":"..tostring(unavailable)..":"..tostring(item.count)..":"..tostring(item.locked)
    self.primaryContext = context
    if SetPortraitToTexture then SetPortraitToTexture(self.icon,item.texture) else self.icon:SetTexture(item.texture) end
    self.itemName:SetText(item.link)
    local ps = ConsoleExperience.config:Get("controllerType") == "ps"
    local rows,preferred = {},1
    local function Add(id,text,enabled,intent)
        table.insert(rows,{id=id,text=text,enabled=enabled,intent=intent})
    end
    local previousMode = self.mode
    if self.mode == "split" and item.count <= 1 then self.mode = "actions" end
    if (self.mode == "destroy" or self.mode == "disenchant") and item.count ~= self.confirmCount then self.mode = "actions" end
    if previousMode ~= self.mode then ConsoleExperience.cursor.navigationState.currentButton = nil end
    if self.mode=="rings" then
        self.title:SetText(L("Add to utility ring"))
        self.details:SetText(L("Choose a ring for this item."))
        local rings=ConsoleExperience.rings:Validate()
        local pages=math.max(1,math.ceil(table.getn(rings)/5))
        self.ringPage=math.max(1,math.min(pages,self.ringPage or 1))
        for i=(self.ringPage-1)*5+1,math.min(table.getn(rings),self.ringPage*5) do
            Add("ring:"..i,rings[i].name,table.getn(rings[i].entries)<12)
        end
        if self.ringPage>1 then Add("ringPrevious",L("Previous"),true) end
        if self.ringPage<pages then Add("ringNext",L("Next"),true) end
        if table.getn(rings)<12 then Add("ringCreate",L("Create an item ring"),true) end
        Add("back",L("Back"),true)
    elseif self.mode == "split" then
        self.amount = math.max(1,math.min(self.amount or 1,item.count-1))
        self.title:SetText(L("Split stack"))
        self.details:SetText(string.format(L("Take %d of %d items.\nLeft / Right changes the amount."),self.amount,item.count))
        Add("split",string.format(L("Split %d"),self.amount),not item.locked,"success")
        Add("less",L("Decrease amount"),self.amount>1)
        Add("more",L("Increase amount"),self.amount<item.count-1)
        Add("half",L("Half stack"),true)
        Add("maximum",L("All but one"),true)
        Add("back",L("Back"),true)
        self.footer:SetText(L(ps and "Cross: Select   Circle: Back\nSquare: Half   Triangle: All but one" or "A: Select   B: Back\nX: Half   Y: All but one"))
    elseif self.mode == "destroy" or self.mode == "disenchant" then
        local destroy = self.mode == "destroy"
        self.title:SetText(L(destroy and "Destroy item?" or "Disenchant item?"))
        self.details:SetText(L(destroy and "This permanently deletes the selected stack." or "This consumes the item. Enchanting requirements still apply."))
        Add("back",L("Cancel"),true)
        Add(destroy and "confirmDestroy" or "confirmDisenchant",L(destroy and "Destroy" or "Disenchant"),not item.locked,"danger")
        self.footer:SetText(L(ps and "Cross: Select   Circle: Back" or "A: Select   B: Back"))
    else
        self.title:SetText(L("Item actions"))
        self.details:SetText(item.locked and L("Item is busy. Wait for it to unlock.")
            or string.format(L("Stack: %d\nChoose an action for this item."),item.count))
        Add("primary",label,not item.locked and not unavailable)
        Add("pickup",L("Pickup / Move"),not item.locked)
        Add("bind",L("Place on action bar"),not item.locked)
        if ConsoleExperience.rings and not item.bank then Add("ringMenu",L("Add to utility ring"),not item.locked) end
        if item.count > 1 and SplitContainerItem then Add("splitMenu",L("Split stack"),not item.locked) end
        if self:CanPreview(item) then Add("preview",L("Preview appearance"),true) end
        if self:DisenchantSpell(item) then Add("disenchant",L("Disenchant"),not item.locked,"danger") end
        Add("destroy",L("Destroy"),not item.locked,"danger")
        Add("back",L("Close"),true)
        self.footer:SetText(L(ps and "Cross: Select   Circle: Back" or "A: Select   B: Back"))
    end
    if WindrunnerController and WindrunnerController.GetMenuButtonName then
        local legend=WindrunnerController:GetMenuButtonName("confirm")..": "..L("Select").."   "..WindrunnerController:GetMenuButtonName("cancel")..": "..L("Back")
        if self.mode=="split" then legend=legend.."\n"..L(ps and "Square: Half   Triangle: All but one" or "X: Half   Y: All but one") end
        self.footer:SetText(legend)
    end
    for index,button in ipairs(self.rows) do
        local row = rows[index]
        if row then
            button.itemAction = row.id
            button.label:SetText(row.text)
            button.themeIntent = row.intent
            if row.enabled then button:Enable() else button:Disable() end
            theme:Apply(button)
            button:Show()
        else button:Hide() end
    end
    -- Disabled actions must never become the initial controller selection.
    while rows[preferred] and not rows[preferred].enabled do preferred = preferred+1 end
    self.frame.initialCursorButton = self.rows[preferred]
    local height = 158+table.getn(rows)*40+54
    self.frame:SetHeight(height)
    local scale = math.min(theme:Get("uiMenuScale"),(UIParent:GetHeight()-40)/height,(UIParent:GetWidth()-40)/380)
    self.frame:SetScale(math.max(0.1,scale))
    local cursor = ConsoleExperience.cursor
    if self.frame:IsVisible() then
        local selected = cursor.navigationState.currentButton
        if not selected or selected:GetParent() ~= self.frame or not selected:IsVisible() or selected:IsEnabled() == 0 then
            cursor:MoveCursorToButton(self.frame.initialCursorButton)
        else cursor:RefreshFrame() end
    end
end

function Menu:IsVisible()
    return self.frame and self.frame:IsVisible()
end

function Menu:Open(button)
    if Held() then return end
    local item = self:Read(button)
    if not item then return end
    self:Create()
    self.source,self.mode = item,"actions"
    self:Render(item)
    self.frame:Show()
end

function Menu:Back()
    if not self.frame or not self.frame:IsVisible() then return end
    if self.mode == "actions" then self:Close(); return end
    local item = self:Validate()
    if not item then self:Close(); return end
    self.mode = "actions"
    -- Render switches the meaning of reused rows; start again at a known choice.
    ConsoleExperience.cursor.navigationState.currentButton = nil
    self:Render(item)
end

function Menu:Adjust(amount)
    if self.mode ~= "split" then return end
    local item = self:Validate()
    if not item then self:Close(); return end
    self.amount = math.max(1,math.min((self.amount or 1)+amount,item.count-1))
    self:Render(item)
end

function Menu:Execute(action)
    if action == "back" then self:Back(); return end
    local item = self:Validate()
    if not item then self:Close(); return end
    if action and (string.sub(action,1,4)=="ring") and item.locked then self:Render(item); return end
    if action=="ringMenu" and ConsoleExperience.rings then
        self.mode="rings"; self.ringPage=1; self:Render(item); return
    elseif action=="ringPrevious" or action=="ringNext" then
        self.ringPage=(self.ringPage or 1)+(action=="ringNext" and 1 or -1); self:Render(item); return
    elseif action=="ringCreate" or (action and string.find(action,"^ring:%d+$")) then
        local rings=ConsoleExperience.rings
        if not rings or item.bank then return end
        local index
        if action=="ringCreate" then
            local name=L("Items")
            local existing={}
            for _,ring in ipairs(rings:GetAll()) do existing[ring.name]=true end
            local suffix=2
            while existing[name] do name=L("Items").." "..suffix; suffix=suffix+1 end
            if not rings:Create(name) then return end
            index=rings.selectedRing
        else index=tonumber(string.sub(action,6)) end
        local _,_,id=string.find(item.link,"item:(%d+)")
        local name=GetItemInfo and GetItemInfo(tonumber(id))
        if id and rings:Add({kind="item",itemID=tonumber(id),name=name or L("Item"),icon=item.texture},index) then self:Back()
        else self.details:SetText(L("This entry is already in the ring or the ring is full.")) end
        return
    end
    if action == "less" then self:Adjust(-1); return end
    if action == "more" then self:Adjust(1); return end
    if action == "half" or action == "maximum" then
        if self.mode ~= "split" then return end
        self.amount = action == "half" and math.floor(item.count/2) or item.count-1
        self:Render(item); return
    end
    if item.locked then self:Render(item); return end
    if action == "splitMenu" or action == "destroy" or action == "disenchant" then
        if action == "splitMenu" and item.count <= 1 then return end
        if action == "disenchant" and not self:DisenchantSpell(item) then return end
        self.mode = action == "splitMenu" and "split" or action
        self.confirmCount = item.count
        self.amount = math.max(1,math.floor(item.count/2))
        ConsoleExperience.cursor.navigationState.currentButton = nil
        self:Render(item); return
    end
    if action == "primary" then
        local context,_,unavailable = self:Context(item)
        if context ~= self.primaryContext or unavailable then self:Render(item); return end
        self:Close()
        UseContainerItem(item.bag,item.slot)
    elseif action == "pickup" or action == "bind" then
        self:Close()
        PickupContainerItem(item.bag,item.slot)
        if CursorHasItem() then
            ConsoleExperience.cursor:SetHeldItemTexture(item.texture)
            if action == "bind" and ConsoleExperience.placement then ConsoleExperience.placement:Show() end
        end
    elseif action == "split" and self.mode == "split" and item.count > 1 then
        local amount = math.max(1,math.min(self.amount,item.count-1))
        self:Close()
        SplitContainerItem(item.bag,item.slot,amount)
        if CursorHasItem() then ConsoleExperience.cursor:SetHeldItemTexture(item.texture) end
    elseif action == "preview" and self:CanPreview(item) then
        self:Close()
        if DressUpFrame then ConsoleExperience.hooks:HookDynamicFrame(DressUpFrame,"DressUpFrame") end
        DressUpItemLink(item.link)
    elseif action == "confirmDestroy" and self.mode == "destroy" then
        if item.count ~= self.confirmCount then self:Render(item); return end
        self:Close()
        PickupContainerItem(item.bag,item.slot)
        if CursorHasItem() then DeleteCursorItem() end
    elseif action == "confirmDisenchant" and self.mode == "disenchant" then
        if item.count ~= self.confirmCount then self:Render(item); return end
        local spell = self:DisenchantSpell(item)
        if not spell then self:Back(); return end
        self:Close()
        CastSpell(spell,BOOKTYPE_SPELL or "spell")
        if SpellIsTargeting() and SpellCanTargetItem() then UseContainerItem(item.bag,item.slot) end
    end
    local cursor = ConsoleExperience.cursor
    if cursor.RefreshFrame then cursor:RefreshFrame() end
end

function CE_ItemActions()
    local button = ConsoleExperience.cursor.navigationState.currentButton
    if WindrunnerController and WindrunnerController.pointer and GetMouseFocus then
        button = GetMouseFocus()
        for depth=1,10 do
            if not button or Menu:Resolve(button) then break end
            button = button.GetParent and button:GetParent()
        end
        if not Menu:Resolve(button) then button = nil end
    end
    Menu:Open(button)
end
function CE_ItemMenuBack() Menu:Back() end
function CE_ItemMenuLess() Menu:Adjust(-1) end
function CE_ItemMenuMore() Menu:Adjust(1) end
function CE_ItemMenuHalf() Menu:Execute("half") end
function CE_ItemMenuMaximum() Menu:Execute("maximum") end

-- Events only update availability; item mutations stay in click/input handlers.
local events = CreateFrame("Frame")
events:RegisterEvent("BANKFRAME_OPENED")
events:RegisterEvent("BANKFRAME_CLOSED")
events:RegisterEvent("PLAYER_LEAVING_WORLD")
events:SetScript("OnEvent",function()
    if event == "BANKFRAME_OPENED" then Menu.bankOpen = true
    elseif event == "BANKFRAME_CLOSED" then
        Menu.bankOpen = false
        if Menu.source and Menu.source.bank then Menu:Close() end
    else Menu.bankOpen = false; Menu:Close() end
end)
Menu.events = events
SLASH_CEITEM1 = "/ceitem"
SlashCmdList["CEITEM"] = CE_ItemActions

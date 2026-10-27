local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
--[[
    Windrunner-Controller - Tooltip Module
    
    Handles tooltip display for cursor navigation with controller button icons
]]

-- Get localized text (with fallback)
local function L(key)
    if ConsoleExperience.locale and ConsoleExperience.locale.T then
        return ConsoleExperience.locale.T(key)
    end
    return key
end

local function ChoosePrompt(label)
    if ConsoleExperience.locale and ConsoleExperience.locale.current == "deDE" then
        return label .. " " .. L("Choose")
    end
    return L("Choose") .. " " .. label
end

local function HasHeldCursorPayload()
    local cursor = ConsoleExperience.cursor
    return (CursorHasItem and CursorHasItem())
        or (CursorHasSpell and CursorHasSpell())
        or (CursorHasMoney and CursorHasMoney())
        or (cursor and cursor.heldItemTexturePath)
end

local function HasUnsupportedPlacementPayload()
    return CursorHasMoney and CursorHasMoney()
end

local function HasUnregisteredHeldAction()
    local cursor = ConsoleExperience.cursor
    local hasGameCursorPayload = (CursorHasItem and CursorHasItem())
        or (CursorHasSpell and CursorHasSpell())
        or (CursorHasMoney and CursorHasMoney())
    return cursor and cursor.heldItemTexturePath and not hasGameCursorPayload
end

local function IsEmptyNativeBagSlot(buttonName, button)
    return buttonName and string.find(buttonName, "^ContainerFrame%d+Item%d+$")
        and button and not button.hasItem
end

local function IsEmptyNativeBankSlot(buttonName, button)
    return buttonName and string.find(buttonName, "^BankFrameItem%d+$")
        and button and not button.hasItem
end

local function IsContainerItemButton(buttonName)
    return buttonName and (
        string.find(buttonName, "^ContainerFrame%d+Item%d+$")
        or string.find(buttonName, "^pfBag%-?%d+item%d+$")
        or string.find(buttonName, "^BagshuiBagsItem%d+$")
        or string.find(buttonName, "^BagshuiBankItem%d+$")
        or string.find(buttonName, "^BagnonItem%d+$")
        or string.find(buttonName, "^BanknonItem%d+$")
        or string.find(buttonName, "^BankFrameItem%d+$")
    )
end

local function IsEmptyCharacterEquipmentSlot(buttonName, button)
    return buttonName and string.find(buttonName, "^Character[A-Za-z0-9]+Slot$")
        and button and button.GetID and GetInventoryItemTexture
        and not GetInventoryItemTexture("player", button:GetID())
end

local function IsControllerActionBarButton(buttonName)
    return buttonName and (
        string.find(buttonName, "^ConsoleActionButton%d+$")
        or string.find(buttonName, "^CESideBarleftButton%d+$")
        or string.find(buttonName, "^CESideBarrightButton%d+$"))
end

local function GetControllerActionSlot(button)
    if not button then return nil end
    if button.actionSlot then return button.actionSlot end

    local actionBars = ConsoleExperience.actionbars
    if actionBars and actionBars.GetActionID then
        return actionBars:GetActionID(button)
    end
    return nil
end

local function IsEmptyControllerActionSlot(buttonName, button)
    if not IsControllerActionBarButton(buttonName) or not button or button.isProxiedAction then
        return false
    end
    local actionSlot = GetControllerActionSlot(button)
    return not actionSlot or not (HasAction and HasAction(actionSlot))
end

-- Create tooltip module namespace
ConsoleExperience.cursor = ConsoleExperience.cursor or {}
ConsoleExperience.cursor.tooltip = ConsoleExperience.cursor.tooltip or {}
local Tooltip = ConsoleExperience.cursor.tooltip

-- Create a child frame of GameTooltip to hook show/hide events
local TooltipHookFrame = CreateFrame("Frame", nil, GameTooltip)

-- Function to get icon path based on controller type
local function GetIconPath(iconName)
    if WindrunnerController and WindrunnerController.MenuConfirmSwapped and WindrunnerController:MenuConfirmSwapped() then
        if iconName=="a" then iconName="b" elseif iconName=="b" then iconName="a" end
    end
    local prompts=ConsoleExperience.controllerControls
    if prompts and prompts.GetGlyphName then iconName=prompts:GetGlyphName(iconName) end
    local controllerType = "xbox"  -- Default
    if ConsoleExperience.config and ConsoleExperience.config.Get then
        controllerType = ConsoleExperience.config:Get("controllerType") or "xbox"
    elseif WindrunnerExperienceDB and WindrunnerExperienceDB.config and WindrunnerExperienceDB.config.controllerType then
        controllerType = WindrunnerExperienceDB.config.controllerType
    end
    
    -- D-pad icons are shared, controller-specific icons are in controllers/<type>/
    local dPadIcons = {down = true, left = true, right = true, up = true}
    if dPadIcons[iconName] then
        return "Interface\\AddOns\\Windrunner-Controller\\textures\\controllers\\" .. iconName
    else
        return "Interface\\AddOns\\Windrunner-Controller\\textures\\controllers\\" .. controllerType .. "\\" .. iconName
    end
end

-- Text padding to make room for icon (must have enough space for 16px icon)
local textPadding = "        "

-- Create button icon textures on GameTooltip
local aIcon = GameTooltip:CreateTexture(nil, "OVERLAY")
aIcon:SetWidth(16)
aIcon:SetHeight(16)
aIcon:Hide()

local bIcon = GameTooltip:CreateTexture(nil, "OVERLAY")
bIcon:SetWidth(16)
bIcon:SetHeight(16)
bIcon:Hide()

local xIcon = GameTooltip:CreateTexture(nil, "OVERLAY")
xIcon:SetWidth(16)
xIcon:SetHeight(16)
xIcon:Hide()

local yIcon = GameTooltip:CreateTexture(nil, "OVERLAY")
yIcon:SetWidth(16)
yIcon:SetHeight(16)
yIcon:Hide()

local lbIcon = GameTooltip:CreateTexture(nil, "OVERLAY")
lbIcon:SetWidth(16)
lbIcon:SetHeight(16)
lbIcon:Hide()

local rbIcon = GameTooltip:CreateTexture(nil, "OVERLAY")
rbIcon:SetWidth(16)
rbIcon:SetHeight(16)
rbIcon:Hide()

-- Function to update icon textures when controller type changes
local function UpdateIconTextures()
    aIcon:SetTexture(GetIconPath("a"))
    bIcon:SetTexture(GetIconPath("b"))
    xIcon:SetTexture(GetIconPath("x"))
    yIcon:SetTexture(GetIconPath("y"))
    lbIcon:SetTexture(GetIconPath("lb"))
    rbIcon:SetTexture(GetIconPath("rb"))
end

-- Initialize textures on load
UpdateIconTextures()

-- Refresh controller-specific prompts when the user changes controller type.
function Tooltip:UpdateControllerIcons()
    UpdateIconTextures()
end

-- Map icon names to textures
local tooltipIcons = {
    ["a"] = aIcon,
    ["b"] = bIcon,
    ["x"] = xIcon,
    ["y"] = yIcon,
    ["lb"] = lbIcon,
    ["rb"] = rbIcon,
}

-- Hide all tooltip icons
local function HideAllIcons()
    for _, icon in pairs(tooltipIcons) do
        icon:Hide()
    end
end

-- Add action prompts with icons to tooltip (called AFTER tooltip content is set)
local function AddPrompts(prompts)
    if not prompts or table.getn(prompts) == 0 then return end
    
    -- Hide all icons first
    HideAllIcons()
    
    -- Add separator line
    GameTooltip:AddLine(" ")
    
    -- Add each prompt with its icon
    for i = 1, table.getn(prompts) do
        local prompt = prompts[i]
        local icon = tooltipIcons[prompt.icon]
        local text = prompt.prompt
        
        -- Leave room only when an icon will occupy the left edge.
        GameTooltip:AddLine(icon and (textPadding .. text) or text)
        
        -- Position icon at the left of this line
        if icon then
            local lineNum = GameTooltip:NumLines()
            local lineFrame = getglobal("GameTooltipTextLeft" .. lineNum)
            if lineFrame then
                icon:ClearAllPoints()
                icon:SetPoint("LEFT", lineFrame, "LEFT", 0, 0)
                icon:Show()
            end
        end
    end
end

local function SetActionPrompt(actions, icon, prompt)
    for i, action in ipairs(actions) do
        if action.icon == icon then
            actions[i] = {icon = icon, prompt = prompt}
            return
        end
    end
    table.insert(actions, {icon = icon, prompt = prompt})
end

-- Vanilla 1.12 has GetMouseFocus(), but not GameTooltip:GetOwner(). Resolve
-- the frame under the physical pointer so pointer-mode help text follows the
-- hovered control instead of whichever control still has D-pad focus.
local function GetPointerTargetButton()
    if not GetMouseFocus then return nil end

    local cursor = ConsoleExperience.cursor
    if not cursor or not cursor.IsInteractiveElement then return nil end

    local frame = GetMouseFocus()
    local depth = 0
    while frame and frame ~= UIParent and depth < 20 do
        if cursor:IsInteractiveElement(frame) then
            local frameName = frame.GetName and frame:GetName() or ""
            if not cursor.ShouldIgnoreButton or not cursor:ShouldIgnoreButton(frameName) then
                return frame
            end
        end
        if not frame.GetParent then return nil end
        frame = frame:GetParent()
        depth = depth + 1
    end

    return nil
end

-- Hook GameTooltip show to add our prompts
TooltipHookFrame:SetScript("OnShow", function()
    -- Only add prompts if cursor is active
    if not ConsoleExperience.cursor then return end
    if not ConsoleExperience.cursor.keybindings then return end
    if not ConsoleExperience.cursor.keybindings:IsCursorModeActive() then return end
    
    local button = ConsoleExperience.cursor.navigationState.currentButton
    if not button then return end

    local helpButton = button
    if WindrunnerController and WindrunnerController.pointer then
        local pointerButton = GetPointerTargetButton()
        if pointerButton and GameTooltip.IsOwned and GameTooltip:IsOwned(pointerButton) then
            helpButton = pointerButton
        elseif not (GameTooltip.IsOwned and GameTooltip:IsOwned(button)) then
            helpButton = nil
        end
    end
    
    local buttonName = button:GetName() or ""
    
    local elementType = nil
    if button:IsObjectType("EditBox") then
        elementType = "editbox"
    elseif button:IsObjectType("Slider") then
        elementType = "slider"
    elseif button:IsObjectType("CheckButton") then
        elementType = "checkbox"
    end
    
    -- Add tooltip help text FIRST (above actions)
    if helpButton and helpButton.tooltipText then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(helpButton.tooltipText, 1, 1, 1, true)
    end
    
    -- GetActions may return a shared prompt list. Copy it before adding dynamic
    -- prompts so keyboard or close hints do not leak to later tooltips.
    local actions = {}
    for _, action in ipairs(Tooltip:GetActions(buttonName, elementType, button) or {}) do
        table.insert(actions, action)
    end

    -- Show B = Close only when B is actually using the generic close action.
    local cursorControls = ConsoleExperience.cursor.keybindings.CURSOR_CONTROLS
    local cancelKey = cursorControls and cursorControls.cancel
    local hasDefaultClose = false
    for _, binding in ipairs(Tooltip:GetBindings(buttonName, elementType, button)) do
        if binding.key == cancelKey and binding.action == "CE_CURSOR_CLOSE" then
            hasDefaultClose = true
            break
        end
    end

    local keyboard = ConsoleExperience.keyboard
    local keyboardVisible = keyboard and keyboard.frame and keyboard.frame:IsVisible()
    local config = ConsoleExperience.config
    local keyboardDisabled = not (config and config.Get and config:Get("keyboardEnabled"))
    local focusedEditBox = false
    if elementType == "editbox" then
        if button.HasFocus then
            local success, focused = pcall(function() return button:HasFocus() end)
            focusedEditBox = success and focused
        end
        if not focusedEditBox and GetCurrentKeyBoardFocus then
            focusedEditBox = GetCurrentKeyBoardFocus() == button
        end
    end

    if hasDefaultClose then
        local layout = ConsoleExperience.layout
        if layout and layout.IsMoving and layout:IsMoving() and string.find(buttonName,"^CELayout") then
            SetActionPrompt(actions, "b", L("Cancel"))
        elseif keyboardVisible and keyboard and keyboard.isChatInput == false then
            SetActionPrompt(actions, "b", L("Cancel"))
        elseif focusedEditBox and keyboardDisabled and not keyboardVisible then
            SetActionPrompt(actions, "b", L("Exit field"))
        elseif string.find(buttonName, "^StaticPopup%d+Button%d+$") then
            -- CE_CURSOR_CLOSE runs the popup's cancel button, which performs
            -- its OnCancel cleanup before the dialog disappears.
            local _, _, popupName = string.find(buttonName, "^(StaticPopup%d+)Button%d+$")
            local cancelButton = popupName and getglobal(popupName .. "Button2")
            local cursor = ConsoleExperience.cursor
            local canCancel = cancelButton and cancelButton:IsVisible()
                and cursor and cursor:IsElementEnabled(cancelButton)
            local closePrompt = L("Close")
            if canCancel then
                local cancelLabel = cancelButton.GetText and cancelButton:GetText()
                closePrompt = type(cancelLabel) == "string" and cancelLabel ~= ""
                    and cancelLabel or L("Cancel")
            end
            SetActionPrompt(actions, "b", closePrompt)
        else
            SetActionPrompt(actions, "b", L("Close"))
        end
    end
    
    -- X submits chat text or applies a non-chat edit while the keyboard is open.
    local keyboard = ConsoleExperience.keyboard
    if keyboard and keyboard.frame and keyboard.frame:IsVisible() then
        local keyboardTarget = keyboard.targetEditBox
        local keyboardPrompt = keyboardTarget and keyboardTarget ~= ChatFrameEditBox
            and L("Apply") or L("Send")
        local replacedXPrompt = false
        for i, action in ipairs(actions) do
            if action.icon == "x" then
                actions[i] = {icon = "x", prompt = keyboardPrompt}
                replacedXPrompt = true
                break
            end
        end
        if not replacedXPrompt then
            table.insert(actions, {icon = "x", prompt = keyboardPrompt})
        end
    end

    -- Pointer mode routes A/X as physical mouse clicks, even while a menu or
    -- the virtual keyboard is open. Replace focus actions with the real route.
    local radial = ConsoleExperience.radial
    local layout = ConsoleExperience.layout
    local pointerClicksActive = WindrunnerController and WindrunnerController.pointer
        and not (radial and radial.IsVisible and radial:IsVisible())
        and not (layout and layout.IsVisible and layout:IsVisible())
    if pointerClicksActive then
        -- A/X click at the physical pointer, which can be over a different
        -- control (or a protected action) than the one kept in D-pad focus.
        SetActionPrompt(actions, "a", L("Pointer Click"))
        SetActionPrompt(actions, "x", L("Pointer Right-Click"))
    end
    
    if actions then
        AddPrompts(actions)
    end
    
    GameTooltip:Show()
end)

TooltipHookFrame:SetScript("OnHide", function()
    HideAllIcons()
end)

-- Frame action definitions
Tooltip.frameActions = {}

function Tooltip:Initialize()
    self.frameActions = {
        -- Bag slots share their actions, with B adapting to the open interface.
        {
            pattern = "ContainerFrame%d+Item%d+",
            containerItem = true,
            actions = {{icon = "a", prompt = L("Pickup")}, {icon = "x", prompt = L("Bind")}, {icon = "b", prompt = L("Use")}, {icon = "y", prompt = L("Item actions")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "2", action = "CE_CURSOR_BIND"}, {key = "4", action = "CE_CURSOR_CLICK_RIGHT"}, {key = "3", action = "CE_CURSOR_ITEM_ACTIONS"}}
        },
        -- pfUI bag items
        {
            pattern = "pfBag%-?%d+item%d+",
            containerItem = true,
            actions = {{icon = "a", prompt = L("Pickup")}, {icon = "x", prompt = L("Bind")}, {icon = "b", prompt = L("Use")}, {icon = "y", prompt = L("Item actions")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "2", action = "CE_CURSOR_BIND"}, {key = "4", action = "CE_CURSOR_CLICK_RIGHT"}, {key = "3", action = "CE_CURSOR_ITEM_ACTIONS"}}
        },
        -- Bagshui bag items
        {
            pattern = "BagshuiBagsItem%d+",
            containerItem = true,
            actions = {{icon = "a", prompt = L("Pickup")}, {icon = "x", prompt = L("Bind")}, {icon = "b", prompt = L("Use")}, {icon = "y", prompt = L("Item actions")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "2", action = "CE_CURSOR_BIND"}, {key = "4", action = "CE_CURSOR_CLICK_RIGHT"}, {key = "3", action = "CE_CURSOR_ITEM_ACTIONS"}}
        },
        -- Bagshui bank items
        {
            pattern = "BagshuiBankItem%d+",
            containerItem = true,
            bankItem = true,
            actions = {{icon = "a", prompt = L("Pickup")}, {icon = "x", prompt = L("Bind")}, {icon = "b", prompt = L("Use")}, {icon = "y", prompt = L("Item actions")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "2", action = "CE_CURSOR_BIND"}, {key = "4", action = "CE_CURSOR_CLICK_RIGHT"}, {key = "3", action = "CE_CURSOR_ITEM_ACTIONS"}}
        },
        -- Bagnon bag items
        {
            pattern = "BagnonItem%d+",
            containerItem = true,
            actions = {{icon = "a", prompt = L("Pickup")}, {icon = "x", prompt = L("Bind")}, {icon = "b", prompt = L("Use")}, {icon = "y", prompt = L("Item actions")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "2", action = "CE_CURSOR_BIND"}, {key = "4", action = "CE_CURSOR_CLICK_RIGHT"}, {key = "3", action = "CE_CURSOR_ITEM_ACTIONS"}}
        },
        -- Bagnon bank items
        {
            pattern = "BanknonItem%d+",
            containerItem = true,
            bankItem = true,
            actions = {{icon = "a", prompt = L("Pickup")}, {icon = "x", prompt = L("Bind")}, {icon = "b", prompt = L("Use")}, {icon = "y", prompt = L("Item actions")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "2", action = "CE_CURSOR_BIND"}, {key = "4", action = "CE_CURSOR_CLICK_RIGHT"}, {key = "3", action = "CE_CURSOR_ITEM_ACTIONS"}}
        },
        -- Character equipment slots - B = Unequip
        {
            pattern = "Character[A-Za-z0-9]+Slot",
            actions = {{icon = "a", prompt = L("Select")}, {icon = "b", prompt = L("Unequip")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "4", action = "CE_CURSOR_UNEQUIP"}}
        },
        -- Spellbook tabs
        {
            pattern = "SpellBookFrameTabButton%d+",
            actions = {{icon = "a", prompt = L("Select")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- Spellbook skill line tabs
        {
            pattern = "SpellBookSkillLineTab%d+",
            actions = {{icon = "a", prompt = L("Select")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- Spellbook buttons
        {
            pattern = "SpellButton%d+",
            actions = {{icon = "a", prompt = L("Cast")}, {icon = "x", prompt = L("Bind")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "2", action = "CE_CURSOR_BIND"}}
        },
        -- Talent frame
        {
            pattern = "TalentFrameTalent%d+",
            actions = {{icon = "a", prompt = L("Learn")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- Quest log titles
        {
            pattern = "QuestLogTitle%d+",
            actions = {{icon = "a", prompt = L("Select")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- Static popup buttons
        {
            pattern = "StaticPopup%d+Button%d+",
            actions = {{icon = "a", prompt = L("Select")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- Dropdown choices should read as selection actions, not generic clicks.
        {
            pattern = "DropDownList%d+Button%d+",
            actions = {{icon = "a", prompt = L("Select")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- Gossip buttons
        {
            pattern = "GossipTitleButton%d+",
            actions = {{icon = "a", prompt = L("Select")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- Quest title buttons
        {
            pattern = "QuestTitleButton%d+",
            actions = {{icon = "a", prompt = L("Select")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- Merchant items - B = Buy (right click)
        {
            pattern = "MerchantItem%d+ItemButton",
            actions = {{icon = "a", prompt = L("Select")}, {icon = "b", prompt = L("Buy")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "4", action = "CE_CURSOR_CLICK_RIGHT"}}
        },
        -- Bank items - B = Withdraw
        {
            pattern = "BankFrameItem%d+",
            bankFrameItem = true,
            actions = {{icon = "a", prompt = L("Pickup")}, {icon = "b", prompt = L("Withdraw")}, {icon = "y", prompt = L("Item actions")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "4", action = "CE_CURSOR_CLICK_RIGHT"}, {key = "3", action = "CE_CURSOR_ITEM_ACTIONS"}}
        },
        -- Auction house browse buttons - B = Bid
        {
            pattern = "BrowseButton%d+",
            actions = {{icon = "a", prompt = L("Select")}, {icon = "b", prompt = L("Bid")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "4", action = "CE_CURSOR_CLICK_RIGHT"}}
        },
        -- Auction house auctions buttons
        {
            pattern = "AuctionsButton%d+",
            actions = {{icon = "a", prompt = L("Select")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- World map close button
        {
            pattern = "WorldMapFrameCloseButton",
            actions = {{icon = "a", prompt = L("Close")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- Both dedicated zoom controls move one level out in the map hierarchy.
        {
            pattern = "WorldMapZoomOutButton",
            actions = {{icon = "a", prompt = L("Zoom Out")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        {
            pattern = "WorldMapMagnifyingGlassButton",
            actions = {{icon = "a", prompt = L("Zoom Out")}, {icon = "b", prompt = L("Zoom Out")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "4", action = "CE_CURSOR_CLICK_RIGHT"}}
        },
        -- The map surface and its POIs use right click to zoom out.
        {
            pattern = "WorldMapButton$",
            actions = {{icon = "a", prompt = L("Select")}, {icon = "b", prompt = L("Zoom Out")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "4", action = "CE_CURSOR_CLICK_RIGHT"}}
        },
        {
            pattern = "WorldMapFramePOI%d+",
            actions = {{icon = "a", prompt = L("Select")}, {icon = "b", prompt = L("Zoom Out")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "4", action = "CE_CURSOR_CLICK_RIGHT"}}
        },
        -- World map dropdowns and other buttons should use the normal select action.
        {
            pattern = "WorldMap.*",
            actions = {{icon = "a", prompt = L("Select")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- Game menu buttons
        {
            pattern = "GameMenuButton.*",
            actions = {{icon = "a", prompt = L("Select")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- Windrunner-Controller config buttons
        {
            pattern = "ConsoleExperienceConfigCloseButton",
            actions = {{icon = "a", prompt = L("Close")}, {icon = "x", prompt = L("Close")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLOSE"}, {key = "2", action = "CE_CURSOR_CLOSE"}}
        },
        {
            pattern = "ConsoleExperience.*",
            actions = {{icon = "a", prompt = L("Select")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- Radial menu buttons
        {
            pattern = "CERadialButton%d+",
            actions = {{icon = "a", prompt = L("Select")},{icon="x",prompt=L("More")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"},{key="2",action="CE_RADIAL_MORE"}}
        },
        -- The placement window may focus its close control first; keep X as
        -- a reliable close shortcut from that initial focus as well.
        {
            pattern = "CEPlacementCloseButton%d+",
            actions = {{icon = "a", prompt = L("Close")}, {icon = "x", prompt = L("Close")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLOSE"}, {key = "2", action = "CE_CURSOR_CLOSE"}}
        },
        -- Spell placement buttons
        {
            pattern = "CEPlacementButton%d+",
            actions = {{icon = "a", prompt = L("Pickup / Place")}, {icon = "b", prompt = L("Clear")}, {icon = "x", prompt = L("Close")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "4", action = "CE_PLACEMENT_CLEAR"}, {key = "2", action = "CE_CURSOR_CLOSE"}}
        },
        -- Macro buttons
        {
            pattern = "MacroButton%d+",
            actions = {{icon = "a", prompt = L("Select")}, {icon = "x", prompt = L("Bind")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "2", action = "CE_CURSOR_BIND"}}
        },
        -- Friends list
        {
            pattern = "FriendsFrameFriendButton%d+",
            actions = {{icon = "a", prompt = L("Select")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- Mail items
        {
            pattern = "MailItem%d+Button",
            mailItem = true,
            actions = {{icon = "a", prompt = L("Open Mail")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- Trainer skill buttons
        {
            pattern = "ClassTrainerSkill%d+",
            actions = {{icon = "a", prompt = L("Learn")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- Profession skill buttons
        {
            pattern = "TradeSkillSkill%d+",
            actions = {{icon = "a", prompt = L("Select")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- Profession reagent buttons
        {
            pattern = "TradeSkillReagent%d+",
            actions = {{icon = "a", prompt = L("Select")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- The item icon keeps its tooltip while B offers a one-press pass.
        {
            pattern = "GroupLootFrame%d+IconFrame",
            actions = {{icon = "b", prompt = PASS or L("Pass")}},
            bindings = {{key = "4", action = "CE_CURSOR_LOOT_PASS"}}
        },
        -- Loot roll choices - use the game's localized choice labels.
        {
            pattern = "GroupLootFrame%d+RollButton",
            actions = {{icon = "a", prompt = NEED or L("Need")}, {icon = "b", prompt = PASS or L("Pass")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "4", action = "CE_CURSOR_LOOT_PASS"}}
        },
        {
            pattern = "GroupLootFrame%d+GreedButton",
            actions = {{icon = "a", prompt = GREED or L("Greed")}, {icon = "b", prompt = PASS or L("Pass")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "4", action = "CE_CURSOR_LOOT_PASS"}}
        },
        {
            pattern = "GroupLootFrame%d+PassButton",
            actions = {{icon = "a", prompt = L("Select")}, {icon = "b", prompt = PASS or L("Pass")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "4", action = "CE_CURSOR_LOOT_PASS"}}
        },
        -- Other controls added by loot UI replacements remain selectable.
        {
            pattern = "GroupLootFrame%d+.*Button",
            actions = {{icon = "a", prompt = L("Select")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- Trade items
        {
            pattern = "TradePlayerItem%d+ItemButton",
            actions = {{icon = "a", prompt = L("Trade")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- UICheckButton (checkboxes)
        {
            pattern = ".*CheckButton.*",
            actions = {{icon = "a", prompt = L("Toggle")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- Loot buttons
        {
            pattern = "LootButton%d+",
            actions = {{icon = "a", prompt = L("Loot")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        },
        -- Keyboard keys
        {
            pattern = "CEKeyboardKey.*",
            actions = {{icon = "a", prompt = L("Type")}, {icon = "x", prompt = L("Send")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "2", action = "CE_CURSOR_BIND"}}
        },
        -- Keyboard special keys (Shift, Space, Backspace, etc.)
        {
            pattern = "CEKeyboardSpecialKey.*",
            actions = {{icon = "a", prompt = L("Press")}, {icon = "x", prompt = L("Send")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "2", action = "CE_CURSOR_BIND"}}
        },
        -- Keyboard emote buttons
        {
            pattern = "CEKeyboardEmote.*",
            actions = {{icon = "a", prompt = L("Emote")}, {icon = "x", prompt = L("Send")}},
            bindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}, {key = "2", action = "CE_CURSOR_BIND"}}
        },
    }
    
    -- Special actions for element types (not pattern based)
    self.elementTypeActions = {
        editbox = {{icon = "a", prompt = L("Edit Text")}},
        slider = {{icon = "a", prompt = L("Increase")}, {icon = "b", prompt = L("Decrease")}},
        checkbox = {{icon = "a", prompt = L("Toggle")}},
    }
end

function Tooltip:IsProtectedProxiedAction(buttonName, button)
    if not (IsControllerActionBarButton(buttonName) and button and button.isProxiedAction) then
        return false
    end

    local proxied = ConsoleExperience.proxied
    return proxied and proxied.IsProtectedBinding
        and proxied:IsProtectedBinding(button.isProxiedAction.id) or false
end

function Tooltip:GetActions(buttonName, elementType, button)
    if buttonName and string.find(buttonName,"^CELayout") then
        local layout = ConsoleExperience.layout
        if layout and layout.IsMoving and layout:IsMoving() then
            return {{icon="a",prompt=L("Save")},{icon="b",prompt=L("Cancel")},{icon="x",prompt=L("Done")}}
        end
        return {{icon="a",prompt=button and button.cursorPrompt or L("Select")},{icon="x",prompt=L("Done")}}
    end
    if buttonName and string.find(buttonName,"^CEItemMenuButton%d+$") then
        local actions = {{icon="a",prompt=L("Select")},{icon="b",prompt=L("Back")}}
        if ConsoleExperience.itemmenu and ConsoleExperience.itemmenu.mode == "split" then
            table.insert(actions,{icon="x",prompt=L("Half stack")})
            table.insert(actions,{icon="y",prompt=L("All but one")})
        end
        return actions
    end
    if HasUnsupportedPlacementPayload() and IsContainerItemButton(buttonName) then
        return {{prompt = L("Finish placing what you're holding first")}}
    end

    local config = ConsoleExperience.config
    if buttonName and ConsoleExperience.hooks and ConsoleExperience.hooks.IsPartyRaidFrame
        and ConsoleExperience.hooks:IsPartyRaidFrame(buttonName)
        and config and config.Get and config:Get("healerMode") then
        return {{prompt = L("Action bar buttons cast on this unit.")}}
    end

    if self:IsProtectedProxiedAction(buttonName, button) then
        -- Its own tooltip explains the required binding. Do not add click
        -- prompts for an action WoW cannot activate by clicking its bar icon.
        return {}
    end

    if IsControllerActionBarButton(buttonName) and button then
        if button.isProxiedAction then
            return {{icon = "a", prompt = button.isProxiedAction.name or L("Use")}}
        end

        local actionSlot = GetControllerActionSlot(button)
        if actionSlot and HasAction and HasAction(actionSlot) then
            return {{icon = "a", prompt = L("Use")}}
        end
        return {{prompt = L("Empty slot")}}
    end

    if buttonName and (string.find(buttonName, "^CEConfig")
        or string.find(buttonName, "^CEController")
        or string.find(buttonName, "^CEHelp")) then
        if button and button.cursorPrompt then
            return {{icon = "a", prompt = button.cursorPrompt}}
        end
        local isDropdownButton = buttonName
            and (string.find(buttonName, "DropdownButton") or string.find(buttonName, "DropDownButton"))
        if isDropdownButton and button and button.label and button.label ~= "" then
            return {{icon = "a", prompt = ChoosePrompt(button.label)}}
        end
        if elementType == "checkbox" and button and button.GetChecked then
            local prompt = button:GetChecked() == 1 and L("Disable") or L("Enable")
            return {{icon = "a", prompt = prompt}}
        end
        if elementType == "editbox" and button and button.label then
            return {{icon = "a", prompt = L("Edit") .. " " .. button.label}}
        end
        if elementType and self.elementTypeActions and self.elementTypeActions[elementType] then
            return self.elementTypeActions[elementType]
        end
        return {{icon = "a", prompt = L("Select")}}
    end

    -- Confirmation dialogs use localized button labels. B dismisses the dialog
    -- without accepting it, so advertise that safe path beside the focused choice.
    if buttonName and string.find(buttonName, "^StaticPopup%d+Button%d+$") and button and button.GetText then
        local buttonText = button:GetText()
        if buttonText and buttonText ~= "" then
            return {
                {icon = "a", prompt = buttonText},
                {icon = "b", prompt = L("Cancel")}
            }
        end
    end

    -- Main-menu choices have explicit, localized labels such as Continue,
    -- Options, and Logout. Carry that meaning into the controller prompt.
    if buttonName and string.find(buttonName, "^GameMenuButton") and button and button.GetText then
        local buttonText = button:GetText()
        if buttonText and buttonText ~= "" then
            return {{icon = "a", prompt = buttonText}}
        end
    end

    -- Read the currently focused dropdown option so navigation prompts name
    -- the choice the player is about to select.
    if buttonName and string.find(buttonName, "^DropDownList%d+Button%d+$") and button and button.GetText then
        local optionText = button:GetText()
        if optionText and optionText ~= "" then
            return {{icon = "a", prompt = ChoosePrompt(optionText)}}
        end
    end

    -- Quest reward choices are selectable; fixed rewards only need their
    -- native item tooltip and should not advertise a no-op click.
    if buttonName and string.find(buttonName, "^QuestInfoItem%d+$") then
        if button and button.type == "choice" then
            return {{icon = "a", prompt = L("Choose Reward")}}
        end
        return {}
    end

    -- Quest actions change by stage (Accept, Continue, Complete, Goodbye).
    -- Read the visible label so controller prompts follow the current dialog
    -- and the game's own localization.
    if buttonName and string.find(buttonName, "^QuestFrame.*Button$") then
        if buttonName == "QuestFrameCloseButton" then
            return {{icon = "a", prompt = L("Close")}}
        end
        if button and button.GetText then
            local buttonText = button:GetText()
            if buttonText and buttonText ~= "" then
                return {{icon = "a", prompt = buttonText}}
            end
        end
    end

    -- These opened-mail controls take their attachment from the message.
    -- The inbox rows use the separate MailItem buttons above.
    if buttonName == "OpenMailPackageButton"
        or buttonName == "OpenMailMoneyButton"
        or buttonName == "OpenMailLetterButton" then
        return {{icon = "a", prompt = L("Take")}}
    end

    -- Check button name patterns FIRST (more specific than element type)
    if buttonName then
        for _, config in ipairs(self.frameActions) do
            if string.find(buttonName, config.pattern) then
                -- Bag addons share container actions, with B adapted to context.
                if config.containerItem then
                    local isBankItem = config.bankItem
                    if not isBankItem and string.find(buttonName, "pfBag%-?%d+item%d+")
                        and pfUI and pfUI.bag and pfUI.bag.left then
                        local parent = button
                        while parent do
                            if parent == pfUI.bag.left then
                                isBankItem = true
                                break
                            end
                            if not parent.GetParent then break end
                            parent = parent:GetParent()
                        end
                    end
                    return self:GetContainerItemActions(isBankItem, buttonName, button)
                end
                if config.bankFrameItem then
                    local hasCursorItem = CursorHasItem() or CursorHasSpell()
                    if HasUnregisteredHeldAction() then
                        return {{prompt = L("Finish placing what you're holding first")}}
                    end
                    if IsEmptyNativeBankSlot(buttonName, button) then
                        if CursorHasItem() then
                            return {{icon = "a", prompt = L("Place")}}
                        end
                        return {{prompt = L("Empty bank slot")}}
                    end
                    if HasHeldCursorPayload() then
                        return {
                            {prompt = L("Finish placing what you're holding first")},
                            {icon = "a", prompt = hasCursorItem and L("Pickup / Place") or L("Pickup")},
                            {icon = "b", prompt = L("Close")}
                        }
                    end
                    return {
                        {icon = "a", prompt = hasCursorItem and L("Pickup / Place") or L("Pickup")},
                        {icon = "b", prompt = L("Withdraw")},
                        {icon = "y", prompt = L("Item actions")}
                    }
                end
                if config.mailItem and button and button.GetChecked and button:GetChecked() then
                    return {{icon = "a", prompt = L("Close")}}
                end
                if string.find(buttonName, "CEKeyboardEmote") and button and button.label then
                    local emoteLabel = button.label
                    if emoteLabel.GetText then
                        emoteLabel = emoteLabel:GetText()
                    end
                    if type(emoteLabel) == "string" and emoteLabel ~= "" then
                        return {
                            {icon = "a", prompt = L("Emote") .. ": " .. emoteLabel},
                            {icon = "x", prompt = L("Send")}
                        }
                    end
                end
                if string.find(buttonName, "^CEKeyboardKey")
                    or string.find(buttonName, "^CEKeyboardSpecialKey") then
                    local keyboard = ConsoleExperience.keyboard
                    local confirmPrompt = keyboard and keyboard.isChatInput == false
                        and L("Apply") or L("Send")
                    local actionPrompt = L("Press")

                    if string.find(buttonName, "^CEKeyboardKey") then
                        actionPrompt = keyboard and keyboard.emoteMode and L("Emote") or L("Type")
                    else
                        if button and button.cursorPrompt and button.cursorPrompt ~= "" then
                            actionPrompt = button.cursorPrompt
                        else
                            local label = button and button.label
                            if type(label) == "string" then
                                actionPrompt = label
                            elseif label and label.GetText then
                                actionPrompt = label:GetText() or actionPrompt
                            end
                        end
                    end

                    return {
                        {icon = "a", prompt = actionPrompt},
                        {icon = "x", prompt = confirmPrompt}
                    }
                end
                if string.find(buttonName, "CEPlacementButton%d+") then
                    local holdingPayload = HasHeldCursorPayload()
                    local hasSlotAction = button and button.actionSlot and HasAction(button.actionSlot)
                    if HasUnsupportedPlacementPayload() then
                        return {
                            {icon = "a", prompt = L("Can't place this here")},
                            {icon = "b", prompt = L("Close")},
                            {icon = "x", prompt = L("Close")}
                        }
                    elseif holdingPayload then
                        return {
                            {icon = "a", prompt = hasSlotAction and L("Place / Swap") or L("Place")},
                            {icon = "b", prompt = L("Close")},
                            {icon = "x", prompt = L("Close")}
                        }
                    elseif hasSlotAction then
                        return {
                            {icon = "a", prompt = L("Pickup")},
                            {icon = "b", prompt = L("Clear")},
                            {icon = "x", prompt = L("Close")}
                        }
                    end
                    return {
                        {prompt = L("Pick up an action first")},
                        {icon = "b", prompt = L("Close")},
                        {icon = "x", prompt = L("Close")}
                    }
                end
                if string.find(buttonName, "Character[A-Za-z0-9]+Slot") then
                    if IsEmptyCharacterEquipmentSlot(buttonName, button) then
                        return {{prompt = L("Empty equipment slot")}}
                    end
                    return {
                        {icon = "a", prompt = L("Select")},
                        {icon = "b", prompt = HasHeldCursorPayload() and L("Finish placing what you're holding first") or L("Unequip")}
                    }
                end
                return config.actions
            end
        end
    end

    -- Specific frame behavior above takes priority; custom controls can still
    -- provide a clear action prompt when their names do not match a known frame.
    if button and button.cursorPrompt then
        return {{icon = "a", prompt = button.cursorPrompt}}
    end

    -- Unknown buttons still expose their localized action label. Reuse it for
    -- controller focus instead of leaving the prompt at the generic "Click".
    if not elementType and button and button.GetText then
        local buttonText = button:GetText()
        if type(buttonText) == "string" and buttonText ~= "" then
            return {{icon = "a", prompt = buttonText}}
        end
    end
    
    -- Fall back to element type for generic handling (editbox, slider, checkbox)
    if elementType and self.elementTypeActions and self.elementTypeActions[elementType] then
        return self.elementTypeActions[elementType]
    end
    
    return {{icon = "a", prompt = L("Click")}}
end

-- Get dynamic actions for container (bag) items based on open frames
function Tooltip:GetContainerItemActions(isBankItem, buttonName, button)
    local bAction = L("Use")  -- Default action
    local hasCursorItem = CursorHasItem() or CursorHasSpell()
    local hasHeldPayload = HasHeldCursorPayload()
    local hasUnregisteredHeldAction = HasUnregisteredHeldAction()

    if HasUnsupportedPlacementPayload() then
        return {{prompt = L("Finish placing what you're holding first")}}
    end

    if hasUnregisteredHeldAction then
        return {{prompt = L("Finish placing what you're holding first")}}
    end

    -- Vanilla's bag buttons expose hasItem, so empty slots can avoid showing
    -- actions such as Use, Bind, and Destroy that cannot apply to them.
    if IsEmptyNativeBagSlot(buttonName, button) then
        if CursorHasItem() then
            return {{icon = "a", prompt = L("Place")}}
        end
        return {{prompt = L("Empty bag slot")}}
    end
    
    -- Bank slots move items back to the player's bags; bag slots move them
    -- into the bank when it is open.
    if isBankItem then
        bAction = L("Withdraw")
    -- Check if merchant frame is visible
    elseif MerchantFrame and MerchantFrame:IsVisible() then
        bAction = L("Sell")
    -- Check if auction frame is visible
    elseif AuctionFrame and AuctionFrame:IsVisible() then
        bAction = L("Auction")
    -- Check if trade frame is visible
    elseif TradeFrame and TradeFrame:IsVisible() then
        bAction = L("Trade")
    -- Check if mail frame is visible (send mail)
    elseif SendMailFrame and SendMailFrame:IsVisible() then
        bAction = L("Attach")
    -- Check if bank frame is visible
    elseif BankFrame and BankFrame:IsVisible() then
        bAction = L("Deposit")
    end
    
    if hasHeldPayload then
        return {
            {prompt = L("Finish placing what you're holding first")},
            {icon = "a", prompt = hasCursorItem and L("Pickup / Place") or L("Pickup")},
            {icon = "x", prompt = L("Bind")},
            {icon = "b", prompt = L("Close")}
        }
    end

    return {
        {icon = "a", prompt = hasCursorItem and L("Pickup / Place") or L("Pickup")},
        {icon = "x", prompt = L("Bind")},
        {icon = "b", prompt = bAction},
        {icon = "y", prompt = L("Item actions")}
    }
end

function Tooltip:GetBindings(buttonName, elementType, button)
    local bindings = {}
    local isKeyboardButton = false
    local isProtectedProxiedActionButton = self:IsProtectedProxiedAction(buttonName, button)
    
    -- Check if this is a party/raid/player frame (healer mode - D-pad only)
    local isHealerModeFrame = false
    if buttonName and ConsoleExperience.hooks and ConsoleExperience.hooks.IsPartyRaidFrame then
        isHealerModeFrame = ConsoleExperience.hooks:IsPartyRaidFrame(buttonName)
    end
    
    -- Always include base navigation bindings (these never change)
    local CursorKeys = ConsoleExperience.cursor.keybindings
    if CursorKeys then
        table.insert(bindings, {key = CursorKeys.CURSOR_CONTROLS.up, action = "CE_CURSOR_MOVE_UP"})
        table.insert(bindings, {key = CursorKeys.CURSOR_CONTROLS.down, action = "CE_CURSOR_MOVE_DOWN"})
        table.insert(bindings, {key = CursorKeys.CURSOR_CONTROLS.left, action = "CE_CURSOR_MOVE_LEFT"})
        table.insert(bindings, {key = CursorKeys.CURSOR_CONTROLS.right, action = "CE_CURSOR_MOVE_RIGHT"})
    end

    if buttonName and string.find(buttonName,"^CELayout") then
        table.insert(bindings,{key="1",action="CE_CURSOR_CLICK_LEFT"})
        table.insert(bindings,{key="2",action="CE_CURSOR_BIND"})
        table.insert(bindings,{key="4",action="CE_CURSOR_CLOSE"})
        return bindings
    end

    if buttonName and string.find(buttonName,"^CEItemMenuButton%d+$") then
        table.insert(bindings,{key="1",action="CE_CURSOR_CLICK_LEFT"})
        table.insert(bindings,{key="4",action="CE_ITEM_MENU_BACK"})
        if ConsoleExperience.itemmenu and ConsoleExperience.itemmenu.mode == "split" then
            for _,binding in ipairs(bindings) do
                if binding.key == "6" then binding.action = "CE_ITEM_MENU_LESS" end
                if binding.key == "8" then binding.action = "CE_ITEM_MENU_MORE" end
            end
            table.insert(bindings,{key="2",action="CE_ITEM_MENU_HALF"})
            table.insert(bindings,{key="3",action="CE_ITEM_MENU_MAXIMUM"})
        end
        return bindings
    end

    -- Do not pick up, use, bind, or destroy an inventory item while money is
    -- held on the game cursor. Keep D-pad navigation and the usual B close.
    if HasUnsupportedPlacementPayload() and IsContainerItemButton(buttonName) then
        if CursorKeys and CursorKeys.CURSOR_CONTROLS.cancel then
            table.insert(bindings, {key = CursorKeys.CURSOR_CONTROLS.cancel, action = "CE_CURSOR_CLOSE"})
        end
        return bindings
    end
    
    -- For healer mode frames, only return D-pad bindings (no action buttons)
    if isHealerModeFrame then
        return bindings
    end
    
    -- Get context-specific bindings for this button
    local contextBindings = nil
    if isProtectedProxiedActionButton then
        -- Preserve the original key binding. Protected system actions cannot be
        -- invoked by clicking the bar icon, even when it has controller focus.
        contextBindings = {}
    elseif IsEmptyCharacterEquipmentSlot(buttonName, button) then
        -- Empty equipment slots cannot be selected or unequipped. Keep B as
        -- the normal close action and let pointer mode handle carried items.
        contextBindings = {}
    elseif IsEmptyNativeBagSlot(buttonName, button) then
        -- Empty storage slots only accept a carried item. Remove
        -- unrelated click, bind, and delete actions; keep B available to close.
        if CursorHasItem() then
            contextBindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        else
            contextBindings = {}
        end
    elseif IsEmptyNativeBankSlot(buttonName, button) then
        -- An empty bank slot can receive a carried item, but it cannot be
        -- withdrawn from. Keep B as the normal close action in either case.
        if CursorHasItem() then
            contextBindings = {{key = "1", action = "CE_CURSOR_CLICK_LEFT"}}
        else
            contextBindings = {}
        end
    elseif buttonName and string.find(buttonName, "^CEPlacementButton%d+") and button then
        local holdingPayload = HasHeldCursorPayload()
        local hasSlotAction = button.actionSlot and HasAction(button.actionSlot)
        -- B clears only an occupied slot when empty-handed; otherwise it backs
        -- out of the placement frame while preserving the carried action.
        contextBindings = {
            {key = "1", action = "CE_CURSOR_CLICK_LEFT"},
            {key = "2", action = "CE_CURSOR_CLOSE"},
            {key = CursorKeys.CURSOR_CONTROLS.cancel,
                action = (holdingPayload or not hasSlotAction) and "CE_CURSOR_CLOSE" or "CE_PLACEMENT_CLEAR"}
        }
    elseif buttonName then
        for _, config in ipairs(self.frameActions) do
            if string.find(buttonName, config.pattern) then
                if (config.containerItem or config.bankFrameItem) and HasHeldCursorPayload() then
                    contextBindings = {}
                    local hasUnregisteredHeldAction = HasUnregisteredHeldAction()
                    for _, binding in ipairs(config.bindings or {}) do
                        local blocksAction = binding.action == "CE_CURSOR_CLICK_RIGHT"
                            or binding.action == "CE_CURSOR_DELETE"
                            or binding.action == "CE_CURSOR_ITEM_ACTIONS"
                            or (hasUnregisteredHeldAction and (binding.action == "CE_CURSOR_BIND"
                                or binding.action == "CE_CURSOR_CLICK_LEFT"))
                        if not blocksAction then
                            table.insert(contextBindings, binding)
                        end
                    end
                else
                    contextBindings = config.bindings
                end
                -- Check if this is a keyboard button (already has key "2" binding)
                if string.find(buttonName, "CEKeyboard") then
                    isKeyboardButton = true
                end
                break
            end
        end
    end

    -- Slider prompts use A/B to adjust the focused value. Route those buttons
    -- through the same click handlers that adjust sliders in CE_ClickCursor.
    if not contextBindings and elementType == "slider" then
        contextBindings = {
            {key = "1", action = "CE_CURSOR_CLICK_LEFT"},
            {key = CursorKeys.CURSOR_CONTROLS.cancel, action = "CE_CURSOR_CLICK_RIGHT"},
        }
    end
    
    -- Add context-specific bindings (these override base bindings for same keys)
    if contextBindings then
        for _, binding in ipairs(contextBindings) do
            -- Replace existing binding if key already exists, otherwise add
            local found = false
            for i, existingBinding in ipairs(bindings) do
                if existingBinding.key == binding.key then
                    bindings[i] = binding
                    found = true
                    break
                end
            end
            if not found then
                table.insert(bindings, binding)
            end
        end
    else
        -- Default binding if no pattern matched
        table.insert(bindings, {key = "1", action = "CE_CURSOR_CLICK_LEFT"})
    end
    
    -- If keyboard is visible, add X = Send binding (key "2" = CE_CURSOR_BIND)
    -- But skip this for keyboard buttons themselves (they already have it in frameActions)
    if not isKeyboardButton and ConsoleExperience.keyboard and ConsoleExperience.keyboard.frame and ConsoleExperience.keyboard.frame:IsVisible() then
        -- Check if X binding already exists
        local hasXBinding = false
        for _, binding in ipairs(bindings) do
            if binding.key == "2" then
                hasXBinding = true
                break
            end
        end
        if not hasXBinding then
            table.insert(bindings, {key = "2", action = "CE_CURSOR_BIND"})
        end
    end
    
    -- Default cancel binding if not set
    local hasCancelBinding = false
    if CursorKeys then
        for _, binding in ipairs(bindings) do
            if binding.key == CursorKeys.CURSOR_CONTROLS.cancel then
                hasCancelBinding = true
                break
            end
        end
        if not hasCancelBinding then
            table.insert(bindings, {key = CursorKeys.CURSOR_CONTROLS.cancel, action = "CE_CURSOR_CLOSE"})
        end
    end
    
    return bindings
end

-- ============================================================================
-- Tooltip Display
-- ============================================================================

function Tooltip:ShowButtonTooltip(button)
    if not button then return end

    -- The item panel has its own item header and persistent controls legend.
    if button:GetName() and string.find(button:GetName(),"^CEItemMenuButton%d+$") then
        HideAllIcons()
        GameTooltip:Hide()
        return
    end

    local radial = ConsoleExperience.radial
    if radial and radial.frame and radial:IsVisible() and button.GetParent
        and button:GetParent() == radial.frame then
        HideAllIcons()
        GameTooltip:Hide()
        return
    end

    -- A focused control can remain selected while its label or available
    -- actions change. Reopen its owned tooltip so the controller legend is
    -- rebuilt by the GameTooltip OnShow hook.
    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(button) then
        GameTooltip:Hide()
    end
    
    -- Hide all icons first
    HideAllIcons()
    
    local buttonName = button:GetName()
    if not buttonName then
        buttonName = ""
    end
    
    -- Handle different button types FIRST (before element type checks)
    -- This ensures specific button types like SpellButton are handled correctly
    if string.find(buttonName, "ContainerFrame%d+Item%d+") then
        -- Blizzard bag item
        local parent = button:GetParent()
        local bagID = parent and parent:GetID()
        if bagID then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetBagItem(bagID, button:GetID())
        end
    elseif string.find(buttonName, "pfBag%-?%d+item%d+") then
        -- pfUI bag item: "pfBag{bag}item{slot}"
        local _, _, bagNum, slotNum = string.find(buttonName, "pfBag(%-?%d+)item(%d+)")
        if bagNum and slotNum then
            local bagID = tonumber(bagNum)
            local slotID = tonumber(slotNum)
            if bagID and slotID then
                GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                GameTooltip:SetBagItem(bagID, slotID)
            end
        end
    elseif string.find(buttonName, "BagshuiBagsItem%d+") or string.find(buttonName, "BagshuiBankItem%d+") then
        -- Bagshui bag/bank item: "BagshuiBagsItem{num}" or "BagshuiBankItem{num}"
        -- Bag and slot info is stored in bagshuiData
        if button.bagshuiData and button.bagshuiData.bagNum and button.bagshuiData.slotNum then
            local bagID = button.bagshuiData.bagNum
            local slotID = button.bagshuiData.slotNum
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetBagItem(bagID, slotID)
        end
    elseif string.find(buttonName, "BagnonItem%d+") or string.find(buttonName, "BanknonItem%d+") then
        -- Bagnon bag/bank item: "BagnonItem{num}" or "BanknonItem{num}"
        -- Uses same structure as Blizzard: GetID() for slot, GetParent():GetID() for bag
        local parent = button:GetParent()
        if parent then
            local bagID = parent:GetID()
            local slotID = button:GetID()
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetBagItem(bagID, slotID)
        end
    elseif string.find(buttonName, "Character[A-Za-z0-9]+Slot") then
        -- Equipment slot
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetInventoryItem("player", button:GetID())
    elseif string.find(buttonName, "SpellBookFrameTabButton%d+") or string.find(buttonName, "SpellBookSkillLineTab%d+") then
        -- Spellbook tabs - use button's OnEnter script
        local onEnterScript = button:GetScript("OnEnter")
        if onEnterScript then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            local oldThis = this
            this = button
            onEnterScript()
            this = oldThis
        end
    elseif string.find(buttonName, "SpellButton%d+") then
        -- Spellbook spell
        if SpellBookFrame and SpellBookFrame.bookType then
            local id = button:GetID()
            local spellID = id
            if SpellBookFrame.bookType ~= BOOKTYPE_PET then
                spellID = id + SpellBookFrame.selectedSkillLineOffset + 
                    (SPELLS_PER_PAGE * (SPELLBOOK_PAGENUMBERS[SpellBookFrame.selectedSkillLine] - 1))
            end
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetSpell(spellID, SpellBookFrame.bookType)
        end
    elseif string.find(buttonName, "LootButton%d+") then
        -- Loot item
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetLootItem(button:GetID())
    elseif string.find(buttonName, "MerchantItem%d+ItemButton") then
        -- Merchant item
        local _, _, itemIndex = string.find(buttonName, "MerchantItem(%d+)")
        if itemIndex then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetMerchantItem(tonumber(itemIndex))
        end
    elseif string.find(buttonName, "BankFrameItem%d+") then
        -- Bank item
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetInventoryItem("player", button:GetID())
    elseif string.find(buttonName, "MailItem%d+Button") then
        -- Mail item - use button's OnEnter script (Classic WoW doesn't have SetMailItem)
        local onEnterScript = button:GetScript("OnEnter")
        if onEnterScript then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            local oldThis = this
            this = button
            onEnterScript()
            this = oldThis
        end
    elseif string.find(buttonName, "ClassTrainerSkill%d+") then
        -- Trainer skill - use button's OnEnter script (Classic WoW doesn't have SetTrainerService)
        local onEnterScript = button:GetScript("OnEnter")
        if onEnterScript then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            local oldThis = this
            this = button
            onEnterScript()
            this = oldThis
        end
    elseif string.find(buttonName, "TradeSkillSkill%d+") then
        -- Profession skill - use button's OnEnter script (Classic WoW doesn't have SetTradeSkillSkill)
        local onEnterScript = button:GetScript("OnEnter")
        if onEnterScript then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            local oldThis = this
            this = button
            onEnterScript()
            this = oldThis
        end
    elseif string.find(buttonName, "TradeSkillReagent%d+") then
        -- Profession reagent - use button's OnEnter script (Classic WoW doesn't have SetTradeSkillReagent)
        local onEnterScript = button:GetScript("OnEnter")
        if onEnterScript then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            local oldThis = this
            this = button
            onEnterScript()
            this = oldThis
        end
    elseif string.find(buttonName, "WorldMapFramePOI%d+") then
        -- The built-in POI OnEnter updates map labels, not GameTooltip. Show
        -- the selected point's name and description with the controller hints.
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(tostring(button.name or buttonName))
        if button.description and button.description ~= "" then
            GameTooltip:AddLine(button.description, 1, 1, 1, true)
        end
        GameTooltip:Show()
    elseif (string.find(buttonName, "^GroupLootFrame%d+RollButton$")
        or string.find(buttonName, "^GroupLootFrame%d+GreedButton$")
        or string.find(buttonName, "^GroupLootFrame%d+PassButton$"))
        and GameTooltip.SetLootRollItem then
        -- Keep the item details visible while a controller user chooses a roll.
        local lootFrame = button:GetParent()
        if lootFrame and lootFrame.rollID then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetLootRollItem(lootFrame.rollID)
        end
    else
        -- Check element types for generic UI elements
        -- Determine element type
        local elementType = nil
        if button:IsObjectType("EditBox") then
            elementType = "editbox"
        elseif button:IsObjectType("Slider") then
            elementType = "slider"
        elseif button:IsObjectType("CheckButton") and not string.find(buttonName, "SpellButton%d+") then
            -- Only treat as checkbox if it's not a SpellButton
            elementType = "checkbox"
        end
        
        -- Handle EditBox specially
        if elementType == "editbox" then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            local label = button.label or L("Text Input")
            local currentText = button:GetText() or ""
            GameTooltip:SetText(tostring(label))
            if currentText ~= "" then
                GameTooltip:AddLine(L("Current: ") .. currentText, 0.7, 0.7, 0.7)
            end
            -- tooltipText is added in OnShow handler (above actions)
            GameTooltip:Show()
            return
        end
        
        -- Handle Slider specially
        if elementType == "slider" then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            local label = button.label or L("Slider")
            local value = button:GetValue() or 0
            local min, max = button:GetMinMaxValues()
            GameTooltip:SetText(tostring(label))
            GameTooltip:AddLine(L("Value: ") .. string.format("%.1f (%.1f - %.1f)", value, min, max), 0.7, 0.7, 0.7)
            -- tooltipText is added in OnShow handler (above actions)
            GameTooltip:Show()
            return
        end
        
        -- Handle CheckButton specially
        if elementType == "checkbox" then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            -- Try to get label from stored property or button text
            local label = nil
            -- If label is a FontString (has GetText), get the text from it
            if button.label and type(button.label) == "table" and button.label.GetText then
                label = button.label:GetText()
            -- If label is already a string, use it directly
            elseif button.label and type(button.label) == "string" then
                label = button.label
            end
            if not label or label == "" then
                label = button.GetText and button:GetText()
            end
            if not label or label == "" then
                label = buttonName
            end
            if not label or label == "" then
                label = "Checkbox"
            end
            local checked = button:GetChecked() and L("Enabled") or L("Disabled")
            GameTooltip:SetText(tostring(label))
            GameTooltip:AddLine(L("Status: ") .. checked, 0.7, 0.7, 0.7)
            -- tooltipText is added in OnShow handler (above actions)
            GameTooltip:Show()
            return
        end
        
        -- Check if button has custom tooltip text (config controls, dropdowns, etc.)
        if button.tooltipText or button.label or button.keyChar then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            local label = nil
            -- For keyboard keys, use keyChar
            if button.keyChar then
                label = button.keyChar
            -- If label is a FontString (has GetText), get the text from it
            elseif button.label and type(button.label) == "table" and button.label.GetText then
                label = button.label:GetText()
            -- If label is already a string, use it directly
            elseif button.label and type(button.label) == "string" then
                label = button.label
            end
            if not label or label == "" then
                label = button.GetText and button:GetText()
            end
            if not label or label == "" then
                label = buttonName
            end
            if not label or label == "" then
                label = "Option"
            end
            GameTooltip:SetText(tostring(label))
            -- tooltipText is added in OnShow handler (above actions)
            GameTooltip:Show()
            return
        end
        
        -- Try to run the button's OnEnter script
        local onEnterScript = button:GetScript("OnEnter")
        if onEnterScript then
            -- Save current 'this' and set it to button
            local oldThis = this
            this = button
            onEnterScript()
            this = oldThis
        else
            -- Show a simple tooltip with button text if available
            local buttonText = button.GetText and button:GetText()
            if buttonText and buttonText ~= "" then
                GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                GameTooltip:SetText(tostring(buttonText))
                GameTooltip:Show()
            end
        end
    end
    
    -- Note: Action prompts are added automatically via TooltipHookFrame OnShow
end

function Tooltip:HideButtonTooltip()
    HideAllIcons()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

-- Module loaded silently

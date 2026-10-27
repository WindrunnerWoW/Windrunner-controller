-- WindrunnerController integration: controller bindings are private logical symbols.
-- These locals preserve cursor/proxy state without writing any keyboard binding.
local SetBinding = ConsoleExperience.SetControllerBinding
local GetBindingAction = ConsoleExperience.GetControllerBindingAction
local GetBindingKey = ConsoleExperience.GetControllerBindingKey
local SaveBindings = ConsoleExperience.SaveControllerBindings

-- Get localized text (with fallback)
local function L(key)
    if ConsoleExperience.locale and ConsoleExperience.locale.T then
        return ConsoleExperience.locale.T(key)
    end
    return key
end

--[[
    Windrunner-Controller - Keybindings Module
    
    Names the addon's controller bindings for WoW's keybinding interface and
    routes action-slot presses to the controller action bars.
    Bindings.xml uses runOnUp="true" for these bindings.
    
    40 action slots mapped to keys:
    - Actions 1-10: No modifier (keys 1-0)
    - Actions 11-20: Shift (Shift+1-0)
    - Actions 21-30: Ctrl (Ctrl+1-0)
    - Actions 31-40: Ctrl+Shift (Ctrl+Shift+1-0)
]]

-- ============================================================================
-- Create Binding Names Dynamically (like pfUI does)
-- ============================================================================

-- Binding header
_G["BINDING_HEADER_WINDRUNNEREXPERIENCE"] = L("Windrunner-Controller")
_G["BINDING_HEADER_CELEFTBAR"] = L("Windrunner Left Touch Bar")
_G["BINDING_HEADER_CERIGHTBAR"] = L("Windrunner Right Touch Bar")

local function GetControllerType()
    if ConsoleExperience.config and ConsoleExperience.config.Get then
        return ConsoleExperience.config:Get("controllerType") or "xbox"
    end
    if WindrunnerExperienceDB and WindrunnerExperienceDB.config then
        return WindrunnerExperienceDB.config.controllerType or "xbox"
    end
    return "xbox"
end

local function UpdateFeatureBindingNames()
    local names={CE_PET_MENU="Pet controls",CE_UNIT_MENU="Target actions",CE_LOOT_MENU="Pending loot rolls",
        CE_RADIAL_MORE="Quick menu: next collection",CE_RING_EDITOR="Edit utility rings",CE_KEYBOARD_SPACE="Virtual keyboard: space",CE_KEYBOARD_BACKSPACE="Virtual keyboard: backspace"}
    for id,name in pairs(names) do _G["BINDING_NAME_"..id]=L(name) end
    for i=1,12 do _G["BINDING_NAME_CE_RING_"..i]=L("Utility ring").." "..i end
end
UpdateFeatureBindingNames()

local function UpdateActionBindingNames()
    local buttonNames
    local leftTrigger, rightTrigger
    if GetControllerType() == "ps" then
        buttonNames = {
            [1] = L("Cross"), [2] = L("Square"), [3] = L("Triangle"), [4] = L("Circle"),
            [5] = L("Down"), [6] = L("Left"), [7] = L("Up"), [8] = L("Right"),
            [9] = "R1", [10] = "L1",
        }
        leftTrigger, rightTrigger = "L2", "R2"
    else
        buttonNames = {
            [1] = "A", [2] = "X", [3] = "Y", [4] = "B",
            [5] = L("Down"), [6] = L("Left"), [7] = L("Up"), [8] = L("Right"),
            [9] = "RB", [10] = "LB",
        }
        leftTrigger, rightTrigger = "LT", "RT"
    end

    local modifierPrefixes = {
        [1] = "",
        [2] = leftTrigger .. " + ",
        [3] = rightTrigger .. " + ",
        [4] = leftTrigger .. " + " .. rightTrigger .. " + ",
    }

    for i = 1, 40 do
        local page = math.floor((i - 1) / 10) + 1
        local buttonIndex = math.mod(i - 1, 10) + 1
        _G["BINDING_NAME_CE_ACTION_" .. i] = L("Action") .. i .. " (" .. modifierPrefixes[page] .. buttonNames[buttonIndex] .. ")"
    end
end

UpdateActionBindingNames()

-- Create binding names for left touch bar (slots 41-45)
for i = 41, 45 do
    local buttonIndex = i - 40  -- Button 1-5 on left bar
    _G["BINDING_NAME_CE_ACTION_" .. i] = L("Left Touch Bar Button") .. " " .. buttonIndex
end

-- Create binding names for right touch bar (slots 46-50)
for i = 46, 50 do
    local buttonIndex = i - 45  -- Button 1-5 on right bar
    _G["BINDING_NAME_CE_ACTION_" .. i] = L("Right Touch Bar Button") .. " " .. buttonIndex
end

-- Cursor header and binding names
_G["BINDING_HEADER_CECURSOR"] = L("Cursor Navigation")
_G["BINDING_NAME_CE_CURSOR_MOVE_UP"] = L("Cursor Up")
_G["BINDING_NAME_CE_CURSOR_MOVE_DOWN"] = L("Cursor Down")
_G["BINDING_NAME_CE_CURSOR_MOVE_LEFT"] = L("Cursor Left")
_G["BINDING_NAME_CE_CURSOR_MOVE_RIGHT"] = L("Cursor Right")
_G["BINDING_NAME_CE_CURSOR_CLICK_LEFT"] = L("Cursor Click")
_G["BINDING_NAME_CE_CURSOR_CLICK_RIGHT"] = L("Cursor Right-Click")
_G["BINDING_NAME_CE_CURSOR_PICKUP"] = L("Cursor Pickup")
_G["BINDING_NAME_CE_CURSOR_BIND"] = L("Cursor Bind")
_G["BINDING_NAME_CE_CURSOR_DELETE"] = L("Cursor Delete")
_G["BINDING_NAME_CE_CURSOR_ITEM_ACTIONS"] = L("Item actions")
_G["BINDING_NAME_CE_CURSOR_UNEQUIP"] = L("Cursor Unequip")
_G["BINDING_NAME_CE_CURSOR_CLOSE"] = L("Cursor Close")

-- Radial menu header and binding name
_G["BINDING_HEADER_CERADIAL"] = L("Quick Menu")
_G["BINDING_NAME_CE_TOGGLE_RADIAL"] = L("Toggle Radial Menu")

-- Interact header and binding name
_G["BINDING_HEADER_CEINTERACT"] = L("Target Interaction")
_G["BINDING_NAME_CE_INTERACT"] = L("Interact with Target")

-- ============================================================================
-- CE_InteractNearest Function (used by CE_INTERACT binding)
-- ============================================================================

function CE_InteractNearest()
    -- InteractNearest is provided by Interact.dll (Turtle WoW addon)
    if InteractNearest then
        InteractNearest(1)
        return
    end

    -- Without Interact.dll, use the native mouse bridge to let the player aim
    -- and interact manually when that capability is available.
    local controller = WindrunnerController
    if controller and controller.HasMouseBridge and controller:HasMouseBridge()
        and controller.SetPointerMode then
        if not controller.pointer then
            controller:SetPointerMode(true)
            if controller.ShowModeHint then controller:ShowModeHint() end
            if controller.Print then
                controller:Print(L("Pointer mode: right stick aims the cursor; X right-clicks NPCs and objects."))
            end
        end
        return
    end

    -- Do not replace an interaction command with target selection: that is a
    -- surprising side effect and still does not interact with the target.
    if not ConsoleExperience.interactUnavailableNoticeShown then
        ConsoleExperience.interactUnavailableNoticeShown = true
        DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[Windrunner]|r " .. L("Interaction needs Interact.dll or a mouse click on the target."), 1, 0.6, 0)
    end
end

-- ============================================================================
-- Global Action Button Handler (like pfUI's pfActionButton)
-- ============================================================================

-- Debug flag - set to true to see key press debug info
ConsoleExperience_DEBUG_KEYS = true

function ConsoleExperience_ActionButton(slot, inputPage)
    -- Let a focused controller UI consume mapped keys during text entry.
    local Controller = WindrunnerController
    local menuActive = Controller and Controller.IsMenuActive and Controller:IsMenuActive()
    if ChatFrameEditBox and ChatFrameEditBox:IsShown() and not menuActive then return end
    
    -- Only trigger on key down (keystate is set by WoW for runOnUp bindings)
    if keystate == "down" then
        local ActionBars = ConsoleExperience.actionbars
        local shouldCastOnHealerTarget = Controller and Controller.IsHealerFocusActive
            and Controller:IsHealerFocusActive()
        if not Controller or not Controller.IsHealerFocusActive then
            shouldCastOnHealerTarget = ActionBars and ActionBars.ShouldCastOnHealerTarget
                and ActionBars:ShouldCastOnHealerTarget()
        end
        local controllerSlot = slot >= 1 and slot <= 40 and (math.mod(slot - 1, 10) + 1)
        local healerActionButton = shouldCastOnHealerTarget and controllerSlot
            and (controllerSlot <= 4 or controllerSlot >= 9)
        if menuActive and not healerActionButton then
            -- Keyboard-mapped controllers enter through WoW's action-slot
            -- bindings. Reuse native input's contextual routing so these keys
            -- navigate and activate focused controls while a UI is open.
            if Controller.DispatchSlot and controllerSlot and controllerSlot <= 8 then
                Controller:DispatchSlot(controllerSlot)
            end
            return
        end

        -- Calculate actual slot using the same logic as ActionBars:GetActionOffset()
        -- This ensures keybindings use the same slots as the displayed buttons
        local actualSlot = slot

        local function UpdateSlotVisual()
            if slot >= 41 and slot <= 50 then
                if ActionBars and ActionBars.UpdateAllSideBarButtons then
                    ActionBars:UpdateAllSideBarButtons()
                end
                return
            end

            local buttonNum = math.mod(slot - 1, 10) + 1
            local button = getglobal("ConsoleActionButton" .. buttonNum)
            if button and ActionBars then
                ActionBars:UpdateButtonState(button)
            end
        end

        -- For slots 1-10 (base bar without modifiers), use GetActionOffset logic
        if slot >= 1 and slot <= 10 then
            if ActionBars and ActionBars.GetActionOffset then
                -- Use the same offset calculation as the action bars
                local page = inputPage or (ActionBars.GetCurrentModifierPage and ActionBars:GetCurrentModifierPage())
                local offset = ActionBars:GetActionOffset(page)
                actualSlot = offset + slot
            else
                -- Fallback: basic bonus bar calculation
                local bonusBar = GetBonusBarOffset()
                if bonusBar and bonusBar > 0 then
                    actualSlot = 60 + (bonusBar * 12) + slot
                end
            end
        end

        -- Mapped controllers use the same proxy assignments as native pads,
        -- including main-bar slots and stance aliases.
        local Proxied = ConsoleExperience.proxied
        local binding = Proxied and Proxied.GetSlotBinding and Proxied:GetSlotBinding(actualSlot)
        if binding then
            if RunBinding then RunBinding(binding) end
            UpdateSlotVisual()
            return
        end
        
        -- Debug output
        if ConsoleExperience_DEBUG_KEYS then
            local bonusBar = GetBonusBarOffset() or 0
            CE_Debug("Key slot=" .. slot .. " bonus=" .. bonusBar .. " actual=" .. actualSlot .. " has=" .. tostring(HasAction(actualSlot)))
        end
        
        -- Check if healer mode is enabled and cursor is over a party/raid/player frame
        if shouldCastOnHealerTarget then
            local Cursor = ConsoleExperience.cursor
            local currentButton = Cursor.navigationState.currentButton
            local unit = ActionBars:GetUnitFromFrame(currentButton)
            
            if unit then
                if ActionBars.UseActionOnHealerTarget then
                    ActionBars:UseActionOnHealerTarget(actualSlot, unit)
                    UpdateSlotVisual()
                    return
                end
                -- Use the action first
                UseAction(actualSlot, 0)
                
                -- If spell is awaiting target selection, check if we can cast on the unit
                if SpellIsTargeting() then
                    -- Check if the spell can target this unit
                    if SpellCanTargetUnit(unit) then
                        -- Cast on the unit
                        SpellTargetUnit(unit)
                        CE_Debug("Healer mode: Casting action " .. actualSlot .. " on " .. unit)
                        
                        -- Update button visual
                        UpdateSlotVisual()
                        return
                    else
                        -- Can't target this unit, let it work normally (player can target manually or use current target)
                        CE_Debug("Healer mode: Cannot cast action " .. actualSlot .. " on " .. unit .. " (invalid target, using default behavior)")
                        -- Don't return - let it fall through to normal behavior below
                    end
                else
                    -- Spell doesn't require targeting (instant cast, self-buff, etc.) - already executed
                    CE_Debug("Healer mode: Used action " .. actualSlot .. " (no targeting required)")
                    
                    -- Update button visual
                    UpdateSlotVisual()
                    return
                end
            end
        end
        
        -- Use the action (checkCursor=0, onSelf=nil to use normal targeting)
        UseAction(actualSlot, 0)
        
        -- Update button visual
        UpdateSlotVisual()
    end
end

-- ============================================================================
-- Keybindings Module
-- ============================================================================

ConsoleExperienceKeybindings = {}

function ConsoleExperienceKeybindings:RefreshBindingNames()
    UpdateActionBindingNames()
    UpdateFeatureBindingNames()
end

-- Default key bindings (can be customized)
ConsoleExperienceKeybindings.DEFAULT_KEYS = {
    "1", "2", "3", "4", "5", "6", "7", "8", "9", "0"
}

function ConsoleExperienceKeybindings:SetupDefaultBindings()
    ConsoleExperience:ResetControllerBindings()
end
function ConsoleExperienceKeybindings:Initialize()
    -- Check if any CE_ACTION binding already has a key assigned.
    -- We scan all 40 slots because some may be proxied to system actions (like JUMP),
    -- which replaces their CE_ACTION_X key. On a fresh install, none will have keys.
    -- This is more robust than a saved variable flag because it directly reflects
    -- the actual WoW binding state and can't get out of sync.
    local hasExistingBindings = false
    for i = 1, 40 do
        if GetBindingKey("CE_ACTION_" .. i) then
            hasExistingBindings = true
            break
        end
    end
    
    if not hasExistingBindings then
        CE_Debug("No CE bindings found, setting up defaults...")
        self:SetupDefaultBindings()
    else
        CE_Debug("Existing CE bindings found, skipping default setup")
    end
    
    -- Initialize and apply proxied actions (replaces old useAForJump system)
    if ConsoleExperience.proxied and ConsoleExperience.proxied.Initialize then
        ConsoleExperience.proxied:Initialize()
    end
    
    -- WindrunnerController dispatches actions directly. Keep other addons' keyboard handlers.
    CE_Debug("Keybindings module initialized!")
end

-- Attach to main addon
ConsoleExperience.keybindings = ConsoleExperienceKeybindings

-- Function to force reset all keybindings (called from config menu)
function ConsoleExperienceKeybindings:ResetAllBindings()
    ConsoleExperience:ResetControllerBindings()
    if ConsoleExperience.proxied and ConsoleExperience.proxied.ApplyAllBindings then
        ConsoleExperience.proxied:ApplyAllBindings()
    end
end

local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
--[[
    Windrunner-Controller - Profiles Module
    
    Manages multiple configuration profiles per character.
    Each profile stores:
    - Complete config settings
    - Proxied action bindings
    - Action bar contents (slots 1-120)
]]

-- Create the profiles module namespace
ConsoleExperience.profiles = ConsoleExperience.profiles or {}
local Profiles = ConsoleExperience.profiles

-- Ring entries and other nested settings must belong to one profile snapshot.
local function CopyConfigValue(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, entry in pairs(value) do copy[key] = CopyConfigValue(entry, seen) end
    return copy
end

local function L(key)
    local Locale = ConsoleExperience.locale
    return Locale and Locale.T and Locale.T(key) or key
end

-- Constants
Profiles.DEFAULT_PROFILE_NAME = "Default"
Profiles.MAX_ACTION_SLOTS = 120  -- WoW 1.12 has 120 action slots total
Profiles.ACTION_BAR_SAVE_DEBOUNCE = 0.15

-- ============================================================================
-- Profile Data Access
-- ============================================================================

-- Get current profile name (returns "Default" if not set)
function Profiles:GetCurrentProfileName()
    if not WindrunnerExperienceDB or not WindrunnerExperienceDB.currentProfile then
        return self.DEFAULT_PROFILE_NAME
    end
    return WindrunnerExperienceDB.currentProfile
end

-- Get profile data by name
function Profiles:GetProfile(profileName)
    if not WindrunnerExperienceDB or not WindrunnerExperienceDB.profiles then
        return nil
    end
    return WindrunnerExperienceDB.profiles[profileName]
end

-- Get current profile data
function Profiles:GetCurrentProfile()
    local profileName = self:GetCurrentProfileName()
    return self:GetProfile(profileName)
end

-- List all profile names
function Profiles:ListProfiles()
    if not WindrunnerExperienceDB or not WindrunnerExperienceDB.profiles then
        return {}
    end
    
    local profiles = {}
    for name, _ in pairs(WindrunnerExperienceDB.profiles) do
        table.insert(profiles, name)
    end
    table.sort(profiles)  -- Sort alphabetically
    return profiles
end

-- ============================================================================
-- Action Bar Save/Load
-- ============================================================================

-- Helper: Find spell ID in spellbook by name and, when available, rank.
local function FindSpellIDByName(spellName, spellRank)
    if not spellName then return nil end
    
    -- Remove rank from spell name to get base name
    local baseName = string.gsub(spellName, " %(Rank %d+%)$", "")
    
    -- Search spellbook
    local i = 1
    local fallbackID
    while true do
        local spellNameInBook, spellRankInBook = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellNameInBook then break end
        
        -- Check if names match
        if spellNameInBook == baseName then
            if not spellRank or spellRank == "" or spellRankInBook == spellRank then
                return i  -- Return spellbook index (ID)
            end
            if not fallbackID then
                fallbackID = i
            end
        end
        
        i = i + 1
    end
    
    return fallbackID
end

-- Match a spell tooltip to its spellbook entry while preserving rank. The
-- action tooltip may show the rank in its title or on a separate line.
local function FindSpellByTooltip(actionName, tooltipLines)
    if not actionName then return nil end

    local normalizedActionName = string.gsub(actionName, " %(Rank %d+%)$", "")
    local i = 1
    local fallbackID, fallbackName, fallbackRank
    while true do
        local spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then break end

        local rankSuffix = spellRank and spellRank ~= "" and (" (" .. spellRank .. ")") or nil
        local titleIncludesRank = rankSuffix and actionName == spellName .. rankSuffix
        local titleMatches = normalizedActionName == spellName or titleIncludesRank
        if titleMatches then
            if titleIncludesRank then
                return i, spellName, spellRank
            end

            if not fallbackID then
                fallbackID = i
                fallbackName = spellName
                fallbackRank = spellRank
            end

            if spellRank and spellRank ~= "" then
                for _, tooltipLine in ipairs(tooltipLines or {}) do
                    if tooltipLine == spellRank then
                        return i, spellName, spellRank
                    end
                end
            else
                return i, spellName, spellRank
            end
        end

        i = i + 1
    end

    return fallbackID, fallbackName, fallbackRank
end

-- Helper: Find macro ID by name
local function FindMacroIDByName(macroName)
    if not macroName then return nil end
    
    -- Search through macros (1-36 in WoW 1.12)
    for i = 1, 36 do
        local name, texture, body = GetMacroInfo(i)
        if name and name == macroName then
            return i
        end
    end
    
    return nil
end

-- Save current action bar state
-- Returns a table mapping slot -> action data
-- Note: We save ALL slots (1-120), including empty ones as nil entries
-- This ensures that when loading, we can clear slots that were previously filled
function Profiles:SaveActionBars()
    local actionBars = {}
    local profile = self:GetCurrentProfile()
    
    -- Start with existing action bars from profile (to preserve slots that might not be in current state)
    if profile and profile.actionBars then
        for slot, data in pairs(profile.actionBars) do
            actionBars[slot] = data
        end
    end
    
    -- Now update with current state - iterate through all possible action slots (1-120)
    for slot = 1, self.MAX_ACTION_SLOTS do
        if HasAction(slot) then
            -- Get texture (always available)
            local texture = GetActionTexture(slot)
            
            -- Get tooltip info to identify the action
            GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
            GameTooltip:ClearLines()
            GameTooltip:SetAction(slot)
            
            local actionName = nil
            local tooltipLines = {}
            local numLines = GameTooltip:NumLines() or 0
            for lineNumber = 1, numLines do
                for _, side in ipairs({"Left", "Right"}) do
                    local line = getglobal("GameTooltipText" .. side .. lineNumber)
                    local lineText = line and line.GetText and line:GetText()
                    if lineText then
                        table.insert(tooltipLines, lineText)
                    end
                end
            end
            local firstLine = getglobal("GameTooltipTextLeft1")
            if firstLine and firstLine.GetText then
                actionName = firstLine:GetText()
            end
            
            GameTooltip:Hide()
            
            if actionName and texture then
                -- Try to identify as spell
                local spellID, spellName, spellRank = FindSpellByTooltip(actionName, tooltipLines)
                if spellID then
                    actionBars[slot] = {
                        type = "spell",
                        id = spellID,
                        name = spellName,
                        rank = spellRank,
                        texture = texture,
                    }
                else
                    -- Try to identify as macro
                    local macroID = FindMacroIDByName(actionName)
                    if macroID then
                        actionBars[slot] = {
                            type = "macro",
                            id = macroID,
                            name = actionName,  -- Store name for reference
                            texture = texture,
                        }
                    else
                        -- Unknown type - save what we can
                        actionBars[slot] = {
                            type = "unknown",
                            name = actionName,
                            texture = texture,
                        }
                    end
                end
            end
        else
            -- Slot is empty - explicitly set to nil to clear it from profile
            actionBars[slot] = nil
        end
    end
    
    return actionBars
end

-- Load action bar state from saved data
function Profiles:LoadActionBars(actionBars)
    -- A second profile switch can happen before a previous restore finishes.
    -- Cancel that work so the most recently selected profile wins.
    if self.actionBarRestoreFrame then
        self.actionBarRestoreFrame:SetScript("OnUpdate", nil)
        self.actionBarRestoreFrame:Hide()
        self.actionBarRestoreFrame = nil
    end

    -- Slot-change events fire while restoring actions too. Keep them from
    -- repeatedly saving a partially restored bar over the profile snapshot.
    self.isLoadingActionBars = true

    -- Always clear ALL action slots first (1-120) to ensure clean state
    -- This ensures that slots that were cleared in the profile are actually cleared
    for slot = 1, self.MAX_ACTION_SLOTS do
        if HasAction(slot) then
            PickupAction(slot)
            ClearCursor()
        end
    end
    
    -- If actionBars is empty or nil, we're done (all slots already cleared)
    if not actionBars or next(actionBars) == nil then
        self.isLoadingActionBars = false

        -- Update action bar display
        if ConsoleExperience.actionbars and ConsoleExperience.actionbars.UpdateAllButtons then
            ConsoleExperience.actionbars:UpdateAllButtons()
        end
        
        CE_Debug("Profiles: All action bars cleared (empty profile)")
        return
    end
    
    -- Small delay to ensure cursor is cleared before placing actions
    local restoreFrame = CreateFrame("Frame")
    self.actionBarRestoreFrame = restoreFrame
    local slotsToRestore = {}
    for slot, data in pairs(actionBars) do
        table.insert(slotsToRestore, {slot = slot, data = data})
    end
    
    local currentIndex = 1
    local restoreDelay = 0
    local slotsCount = table.getn(slotsToRestore)
    restoreFrame:SetScript("OnUpdate", function()
        local elapsed = arg1
        restoreDelay = restoreDelay + elapsed
        -- Wait a small amount before starting restoration
        if restoreDelay < 0.1 then
            return
        end
        
        -- Restore one slot per frame to avoid overwhelming the game
        if currentIndex <= slotsCount then
            local item = slotsToRestore[currentIndex]
            local slot = item.slot
            local data = item.data
            
            -- Restore the action based on type
            if data.type == "spell" and data.id then
                -- Resolve ranked snapshots by name so learning another spell
                -- rank later cannot shift the saved spellbook index.
                local spellID
                if data.rank and data.rank ~= "" then
                    spellID = FindSpellIDByName(data.name, data.rank)
                        or FindSpellIDByName(data.name)
                end
                -- Keep the saved index path for older profiles without rank data.
                spellID = spellID or data.id
                if spellID then
                    PickupSpell(spellID, BOOKTYPE_SPELL)
                    PlaceAction(slot)
                    ClearCursor()
                end
            elseif data.type == "macro" and data.id then
                -- Restore macro using macro ID
                PickupMacro(data.id)
                PlaceAction(slot)
                ClearCursor()
            elseif data.type == "unknown" and data.name then
                -- Try to find and restore by name (spell or macro)
                local spellID = FindSpellIDByName(data.name, data.rank)
                if spellID then
                    PickupSpell(spellID, BOOKTYPE_SPELL)
                    PlaceAction(slot)
                    ClearCursor()
                else
                    local macroID = FindMacroIDByName(data.name)
                    if macroID then
                        PickupMacro(macroID)
                        PlaceAction(slot)
                        ClearCursor()
                    end
                end
            end
            
            currentIndex = currentIndex + 1
        else
            -- All slots restored, clean up
            restoreFrame:SetScript("OnUpdate", nil)
            restoreFrame:Hide()
            if Profiles.actionBarRestoreFrame == restoreFrame then
                Profiles.actionBarRestoreFrame = nil
                Profiles.isLoadingActionBars = false
            end
            
            -- Update action bar display
            if ConsoleExperience.actionbars and ConsoleExperience.actionbars.UpdateAllButtons then
                ConsoleExperience.actionbars:UpdateAllButtons()
            end
            
            CE_Debug("Profiles: Action bars restored (" .. slotsCount .. " slots)")
        end
    end)
end

-- ============================================================================
-- Profile Management
-- ============================================================================

-- Create a new profile
-- sourceProfile: profile name to copy from (nil = use defaults)
function Profiles:CreateProfile(name, sourceProfile)
    if not name or name == "" then
        return false, "Profile name cannot be empty"
    end
    
    -- Check if profile already exists
    if self:GetProfile(name) then
        return false, "Profile already exists"
    end
    
    -- Initialize profiles table if needed
    if not WindrunnerExperienceDB.profiles then
        WindrunnerExperienceDB.profiles = {}
    end
    
    local newProfile = {
        config = {},
        proxiedActions = {},
        actionBars = {},
    }
    
    if sourceProfile then
        -- Clone from source profile
        local source = self:GetProfile(sourceProfile)
        if source then
            -- Deep copy config
            for key, value in pairs(source.config or {}) do
                newProfile.config[key] = CopyConfigValue(value)
            end
            -- Deep copy proxied actions
            for slot, binding in pairs(source.proxiedActions or {}) do
                newProfile.proxiedActions[slot] = binding
            end
            -- Deep copy action bars
            for slot, action in pairs(source.actionBars or {}) do
                newProfile.actionBars[slot] = {}
                for k, v in pairs(action) do
                    newProfile.actionBars[slot][k] = v
                end
            end
        end
    else
        -- New profile with defaults
        -- Config will be populated with defaults when loaded
        -- Action bars start empty
        -- Set default proxied actions (same as proxied.lua Initialize)
        newProfile.proxiedActions[1] = "JUMP"
        newProfile.proxiedActions[30] = "CE_INTERACT"
        CE_Debug("Profiles: Created new profile with default proxied actions (JUMP on slot 1, CE_INTERACT on slot 30)")
    end
    
    WindrunnerExperienceDB.profiles[name] = newProfile
    return true, nil
end

-- Delete a profile
function Profiles:DeleteProfile(name)
    if not name or name == "" then
        return false, "Profile name cannot be empty"
    end
    
    -- Prevent deleting default profile
    if name == self.DEFAULT_PROFILE_NAME then
        return false, "Cannot delete the default profile"
    end
    
    -- Check if profile exists
    if not self:GetProfile(name) then
        return false, "Profile does not exist"
    end
    
    -- If deleting current profile, switch to default first
    if self:GetCurrentProfileName() == name then
        self:SetProfile(self.DEFAULT_PROFILE_NAME)
    end
    
    -- Delete the profile
    WindrunnerExperienceDB.profiles[name] = nil
    
    return true, nil
end

-- Switch to a profile
function Profiles:SetProfile(profileName, currentProfileSaved)
    if not profileName or profileName == "" then
        profileName = self.DEFAULT_PROFILE_NAME
    end
    
    -- Check if profile exists
    if not self:GetProfile(profileName) then
        CE_Debug("Profiles: Profile '" .. profileName .. "' does not exist, creating it")
        self:CreateProfile(profileName, nil)
    end
    
    -- Save current state before switching (if we have a current profile)
    local currentProfileName = self:GetCurrentProfileName()
    if currentProfileName and currentProfileName ~= profileName and not currentProfileSaved then
        self:SaveCurrentProfile()
    end
    
    -- Set new current profile
    WindrunnerExperienceDB.currentProfile = profileName
    
    -- Load the new profile
    self:LoadProfile(profileName)
    
    return true, nil
end

-- Save current profile state (config, proxied actions, action bars)
function Profiles:SaveCurrentProfile()
    -- A direct save (profile switch, config close, or logout) supersedes any
    -- queued action-bar save.
    if self.actionBarSaveFrame then
        self.actionBarSaveFrame:SetScript("OnUpdate", nil)
        self.actionBarSaveFrame.elapsed = 0
    end

    local profileName = self:GetCurrentProfileName()
    local profile = self:GetProfile(profileName)
    
    if not profile then
        -- Create profile if it doesn't exist
        self:CreateProfile(profileName, nil)
        profile = self:GetProfile(profileName)
    end
    
    -- Save config (copy from WindrunnerExperienceDB.config)
    if WindrunnerExperienceDB.config then
        profile.config = {}
        for key, value in pairs(WindrunnerExperienceDB.config) do
            profile.config[key] = CopyConfigValue(value)
        end
    end
    
    -- Ensure all defaults are in the profile (adds any new defaults that were added)
    if ConsoleExperience.config and ConsoleExperience.config.DEFAULTS then
        for key, defaultValue in pairs(ConsoleExperience.config.DEFAULTS) do
            if profile.config[key] == nil then
                profile.config[key] = CopyConfigValue(defaultValue)
                CE_Debug("Profiles: Added missing default '" .. key .. "' = " .. tostring(defaultValue) .. " to profile when saving")
            end
        end
    end
    
    -- Save proxied actions (copy from WindrunnerExperienceDB.proxiedActions)
    if WindrunnerExperienceDB.proxiedActions then
        profile.proxiedActions = {}
        for slot, binding in pairs(WindrunnerExperienceDB.proxiedActions) do
            profile.proxiedActions[slot] = binding
        end
    end
    
    -- Save action bars only outside a profile restore. Closing the config panel
    -- or switching again mid-restore must not replace the saved snapshot with
    -- the partially cleared live bar.
    if not self.isLoadingActionBars then
        profile.actionBars = self:SaveActionBars()
    end
    
    CE_Debug("Profiles: Saved " .. (self:CountTableKeys(profile.actionBars) or 0) .. " action bar slots")
end

-- Load a profile (apply its settings)
function Profiles:LoadProfile(profileName)
    local profile = self:GetProfile(profileName)
    if not profile then
        CE_Debug("Profiles: Profile '" .. profileName .. "' not found")
        return false
    end

    local Locale = ConsoleExperience.locale
    local previousLanguage = Locale and Locale.current

    if WindrunnerController and WindrunnerController.Release then WindrunnerController:Release() end
    if ConsoleExperience.radial and ConsoleExperience.radial.Hide then ConsoleExperience.radial:Hide() end
    
    -- Initialize config if needed
    if not WindrunnerExperienceDB.config then
        WindrunnerExperienceDB.config = {}
    end
    
    -- Load config (merge with defaults)
    -- First, reset to defaults (ensures new defaults are added)
    if ConsoleExperience.config and ConsoleExperience.config.DEFAULTS then
        for key, defaultValue in pairs(ConsoleExperience.config.DEFAULTS) do
            WindrunnerExperienceDB.config[key] = CopyConfigValue(defaultValue)
        end
    end
    
    -- Then apply saved values from profile
    if profile.config then
        for key, value in pairs(profile.config) do
            WindrunnerExperienceDB.config[key] = CopyConfigValue(value)
        end
    end
    
    -- Ensure any new defaults not in the profile are added
    if ConsoleExperience.config and ConsoleExperience.config.DEFAULTS then
        for key, defaultValue in pairs(ConsoleExperience.config.DEFAULTS) do
            if WindrunnerExperienceDB.config[key] == nil then
                WindrunnerExperienceDB.config[key] = CopyConfigValue(defaultValue)
                CE_Debug("Profiles: Added missing default config '" .. key .. "' = " .. tostring(defaultValue) .. " when loading profile")
            end
        end
    end

    if ConsoleExperience.rings and ConsoleExperience.rings.Validate then
        ConsoleExperience.rings:Validate()
        ConsoleExperience.rings:RefreshEditor()
    end

    -- Profiles can select a different addon language. Apply it now and offer
    -- the same reload flow as the language dropdown so all visible text stays
    -- consistent after the user confirms.
    if Locale and Locale.Initialize then
        Locale:Initialize()
        if previousLanguage and previousLanguage ~= Locale.current then
            if ConsoleExperience.config and ConsoleExperience.config.RefreshPopupTranslations then
                ConsoleExperience.config:RefreshPopupTranslations()
            end
            if StaticPopup_Show then
                StaticPopup_Show("CE_RELOAD_UI")
            end
        end
    end
    
    -- Load proxied actions
    if not WindrunnerExperienceDB.proxiedActions then
        WindrunnerExperienceDB.proxiedActions = {}
    else
        -- Clear existing proxied actions
        for slot, _ in pairs(WindrunnerExperienceDB.proxiedActions) do
            WindrunnerExperienceDB.proxiedActions[slot] = nil
        end
    end
    
    if profile.proxiedActions then
        for slot, binding in pairs(profile.proxiedActions) do
            WindrunnerExperienceDB.proxiedActions[slot] = binding
            CE_Debug("Profiles: Loaded proxied action - slot " .. slot .. " -> " .. tostring(binding))
        end
    else
        -- If profile has no proxied actions, check if it's a new profile and should have defaults
        -- (This shouldn't happen if CreateProfile sets defaults, but just in case)
        if not profile.config or next(profile.config) == nil then
            -- Looks like a new profile, set defaults
            WindrunnerExperienceDB.proxiedActions[1] = "JUMP"
            WindrunnerExperienceDB.proxiedActions[30] = "CE_INTERACT"
            CE_Debug("Profiles: Applied default proxied actions to new profile")
        end
    end
    
    -- Apply config settings immediately
    if ConsoleExperience.config then
        -- Apply debug setting
        if WindrunnerExperienceDB.config.debugEnabled ~= nil then
            ConsoleExperience_DEBUG_KEYS = WindrunnerExperienceDB.config.debugEnabled
        end
        
        -- Apply crosshair
        if ConsoleExperience.theme then ConsoleExperience.theme:RefreshAll() end
        if ConsoleExperience.config.UpdateCrosshair then
            ConsoleExperience.config:UpdateCrosshair()
        end
        
        -- Apply action bar layout
        if ConsoleExperience.config.UpdateActionBarLayout then
            ConsoleExperience.config:UpdateActionBarLayout()
        end
        
        -- Apply sidebars (must be called after action bar layout)
        if ConsoleExperience.actionbars and ConsoleExperience.actionbars.UpdateSideBars then
            ConsoleExperience.actionbars:UpdateSideBars()
        end
        
        -- Apply chat layout
        if ConsoleExperience.chat and ConsoleExperience.chat.UpdateChatLayout then
            ConsoleExperience.chat:UpdateChatLayout()
        end
        
        -- Apply XP/Rep bar layout
        if ConsoleExperience.xpbar and ConsoleExperience.xpbar.UpdateAllBars then
            ConsoleExperience.xpbar:UpdateAllBars()
        end
        
        -- Apply castbar layout
        if ConsoleExperience.castbar and ConsoleExperience.castbar.ReloadConfig then
            ConsoleExperience.castbar:ReloadConfig()
        end
        
        -- Update keyboard visibility based on keyboardEnabled setting
        if ConsoleExperience.keyboard then
            local keyboardEnabled = WindrunnerExperienceDB.config.keyboardEnabled
            if keyboardEnabled == false and ConsoleExperience.keyboard:IsVisible() then
                -- Hide keyboard if disabled
                ConsoleExperience.keyboard:Hide()
            end
            -- Note: Keyboard will show automatically when chat opens if enabled
            if ConsoleExperience.keyboard.RefreshLayout then
                ConsoleExperience.keyboard:RefreshLayout()
            end
        end
        
        -- Profile loading writes config directly instead of using Config:Set.
        -- Refresh every settings control and controller-specific visual from it.
        if ConsoleExperience.config and ConsoleExperience.config.RefreshProfileControls then
            ConsoleExperience.config:RefreshProfileControls()
        end

        if ConsoleExperience.layout and ConsoleExperience.layout.Refresh then
            ConsoleExperience.layout:Refresh()
        end
        
        -- Re-layout the selected page after the profile controls have updated.
        if ConsoleExperience.config.frame and ConsoleExperience.config.frame:IsVisible() then
            local currentSection = ConsoleExperience.config.currentSection
            if currentSection and ConsoleExperience.config.ShowSection then
                local refreshFrame = CreateFrame("Frame")
                refreshFrame:SetScript("OnUpdate", function()
                    refreshFrame:SetScript("OnUpdate", nil)
                    local config=ConsoleExperience.config
                    if config.frame:IsVisible() and config.currentSection==currentSection then
                        config:ShowSection(currentSection)
                    end
                end)
            end
        end
    end
    
    -- Apply proxied bindings
    if ConsoleExperience.proxied and ConsoleExperience.proxied.ApplyAllBindings then
        ConsoleExperience.proxied:ApplyAllBindings()
    end
    
    -- Load action bars (with delay to ensure everything else is loaded first)
    if profile.actionBars then
        -- Use a small delay before loading action bars
        local loadFrame = CreateFrame("Frame")
        loadFrame:SetScript("OnUpdate", function()
            loadFrame:SetScript("OnUpdate", nil)
            loadFrame:Hide()
            if Profiles:GetCurrentProfileName() ~= profileName then
                return
            end
            Profiles:LoadActionBars(profile.actionBars)
        end)
    end
    
    return true
end

-- ============================================================================
-- Migration from Legacy Config
-- ============================================================================

-- Migrate legacy config to profile system
function Profiles:MigrateLegacyConfig()
    -- Check if migration is needed
    if WindrunnerExperienceDB.profiles and WindrunnerExperienceDB.profiles[self.DEFAULT_PROFILE_NAME] then
        -- Profiles already exist, no migration needed
        return false
    end
    
    CE_Debug("Profiles: Migrating legacy config to profile system...")
    
    -- Initialize profiles table
    if not WindrunnerExperienceDB.profiles then
        WindrunnerExperienceDB.profiles = {}
    end
    
    -- Create default profile
    local defaultProfile = {
        config = {},
        proxiedActions = {},
        actionBars = {},
    }
    
    -- Migrate config settings
    if WindrunnerExperienceDB.config then
        -- Copy all existing config values
        for key, value in pairs(WindrunnerExperienceDB.config) do
            defaultProfile.config[key] = CopyConfigValue(value)
        end
    else
        -- Initialize with defaults if config doesn't exist
        WindrunnerExperienceDB.config = {}
    end
    
    -- Ensure all default values are set in both places (generic migration)
    -- This automatically adds any new default values that weren't in the old config
    if ConsoleExperience.config and ConsoleExperience.config.DEFAULTS then
        for key, defaultValue in pairs(ConsoleExperience.config.DEFAULTS) do
            -- Add to WindrunnerExperienceDB.config if missing
            if WindrunnerExperienceDB.config[key] == nil then
                WindrunnerExperienceDB.config[key] = CopyConfigValue(defaultValue)
                CE_Debug("Profiles: Added missing default config '" .. key .. "' = " .. tostring(defaultValue))
            end
            -- Add to defaultProfile.config if missing
            if defaultProfile.config[key] == nil then
                defaultProfile.config[key] = CopyConfigValue(defaultValue)
                CE_Debug("Profiles: Added missing default config to profile '" .. key .. "' = " .. tostring(defaultValue))
            end
        end
    end
    
    -- Migrate proxied actions
    if WindrunnerExperienceDB.proxiedActions then
        -- Copy all proxied actions
        for slot, binding in pairs(WindrunnerExperienceDB.proxiedActions) do
            defaultProfile.proxiedActions[slot] = binding
            CE_Debug("Profiles: Migrated proxied action - slot " .. slot .. " -> " .. tostring(binding))
        end
    else
        -- Initialize if it doesn't exist
        WindrunnerExperienceDB.proxiedActions = {}
    end
    
    -- Ensure proxied actions are also preserved in WindrunnerExperienceDB.proxiedActions
    -- (they should already be there, but make sure they're not lost)
    if WindrunnerExperienceDB.proxiedActions and next(WindrunnerExperienceDB.proxiedActions) == nil then
        -- If proxiedActions is empty but we have them in the profile, restore them
        if defaultProfile.proxiedActions and next(defaultProfile.proxiedActions) ~= nil then
            for slot, binding in pairs(defaultProfile.proxiedActions) do
                WindrunnerExperienceDB.proxiedActions[slot] = binding
                CE_Debug("Profiles: Restored proxied action to WindrunnerExperienceDB - slot " .. slot .. " -> " .. tostring(binding))
            end
        end
    end
    
    -- Save current action bar state
    defaultProfile.actionBars = self:SaveActionBars()
    
    -- Store default profile
    WindrunnerExperienceDB.profiles[self.DEFAULT_PROFILE_NAME] = defaultProfile
    
    -- Set as current profile
    WindrunnerExperienceDB.currentProfile = self.DEFAULT_PROFILE_NAME
    
    CE_Debug("Profiles: Migration complete. Created default profile with:")
    CE_Debug("  - " .. (self:CountTableKeys(defaultProfile.config) or 0) .. " config settings")
    CE_Debug("  - " .. (self:CountTableKeys(defaultProfile.proxiedActions) or 0) .. " proxied actions")
    CE_Debug("  - " .. (self:CountTableKeys(defaultProfile.actionBars) or 0) .. " action bar slots")
    
    -- Apply proxied bindings after migration (if proxied module is available)
    -- This ensures the bindings are actually set in the game
    if ConsoleExperience.proxied and ConsoleExperience.proxied.ApplyAllBindings then
        -- Small delay to ensure everything is initialized
        local applyFrame = CreateFrame("Frame")
        applyFrame:SetScript("OnUpdate", function()
            applyFrame:SetScript("OnUpdate", nil)
            ConsoleExperience.proxied:ApplyAllBindings()
            CE_Debug("Profiles: Applied proxied bindings after migration")
        end)
    end
    
    return true
end

-- Helper function to count table keys
function Profiles:CountTableKeys(tbl)
    if not tbl then return 0 end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- ============================================================================
-- Initialization
-- ============================================================================

-- Hook into action bar changes
local function OnActionBarSlotChanged()
    -- Profile restoration triggers the same event as a player edit. The saved
    -- snapshot is already authoritative until the restore finishes.
    if Profiles.isLoadingActionBars then
        return
    end

    -- Several slot-change events can come from one drag, swap, or spell-rank
    -- update. Wait for the burst to settle before scanning all 120 slots.
    if not Profiles.actionBarSaveFrame then
        Profiles.actionBarSaveFrame = CreateFrame("Frame")
    end
    local saveFrame = Profiles.actionBarSaveFrame
    saveFrame.elapsed = 0
    saveFrame:SetScript("OnUpdate", function()
        saveFrame.elapsed = saveFrame.elapsed + (arg1 or 0)
        if saveFrame.elapsed >= Profiles.ACTION_BAR_SAVE_DEBOUNCE then
            saveFrame:SetScript("OnUpdate", nil)
            saveFrame.elapsed = 0
            if not Profiles.isLoadingActionBars then
                Profiles:SaveCurrentProfile()
                CE_Debug("Profiles: Auto-saved profile after action bar changes")
            end
        end
    end)
end

function Profiles:Initialize()
    -- Run migration first
    local migrated = self:MigrateLegacyConfig()
    
    -- Ensure current profile is set
    if not WindrunnerExperienceDB.currentProfile then
        WindrunnerExperienceDB.currentProfile = self.DEFAULT_PROFILE_NAME
    end
    
    -- Ensure default profile exists
    if not self:GetProfile(self.DEFAULT_PROFILE_NAME) then
        self:CreateProfile(self.DEFAULT_PROFILE_NAME, nil)
    end
    
    -- If migration happened, ensure proxied actions are synced
    if migrated then
        local defaultProfile = self:GetProfile(self.DEFAULT_PROFILE_NAME)
        if defaultProfile and defaultProfile.proxiedActions then
            -- Make sure WindrunnerExperienceDB.proxiedActions matches the profile
            if not WindrunnerExperienceDB.proxiedActions then
                WindrunnerExperienceDB.proxiedActions = {}
            end
            -- Sync from profile to WindrunnerExperienceDB
            for slot, binding in pairs(defaultProfile.proxiedActions) do
                if not WindrunnerExperienceDB.proxiedActions[slot] or WindrunnerExperienceDB.proxiedActions[slot] ~= binding then
                    WindrunnerExperienceDB.proxiedActions[slot] = binding
                    CE_Debug("Profiles: Synced proxied action from profile - slot " .. slot .. " -> " .. tostring(binding))
                end
            end
        end
    end
    
    -- Register for action bar change events to auto-save profile
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
        self.eventFrame:RegisterEvent("PLAYER_LOGOUT")
        self.eventFrame:SetScript("OnEvent", function()
            if event == "ACTIONBAR_SLOT_CHANGED" then
                OnActionBarSlotChanged()
            elseif event == "PLAYER_LOGOUT" then
                self:SaveCurrentProfile()
            end
        end)
    end
    
    CE_Debug("Profiles: Initialized. Current profile: " .. self:GetCurrentProfileName())
end

-- ============================================================================
-- Slash Commands
-- ============================================================================

SLASH_CEPROFILE1 = "/ceprofile"
SLASH_CEPROFILE2 = "/cep"
SlashCmdList["CEPROFILE"] = function(msg)
    msg = string.gsub(msg or "", "^%s*(.-)%s*$", "%1")  -- Trim whitespace
    
    if msg == "" or msg == nil then
        -- Show current profile
        local currentProfile = Profiles:GetCurrentProfileName()
        CE_Print(string.format(L("Current profile: %s"), currentProfile))
        CE_Print(L("Usage: /ceprofile <name> or /cep <name>"))
        CE_Print(L("Available profiles:"))
        local profiles = Profiles:ListProfiles()
        for _, name in ipairs(profiles) do
            local marker = (name == currentProfile) and L(" (current)") or ""
            CE_Print("  - " .. name .. marker)
        end
    else
        -- Switch to specified profile
        local profileName = msg
        local profile = Profiles:GetProfile(profileName)
        
        if profile then
            if profileName == Profiles:GetCurrentProfileName() then
                -- Re-selecting the active profile acts as an explicit save.
                Profiles:SaveCurrentProfile()
                CE_Print(string.format(L("Saved profile: %s"), profileName))
            else
                -- SetProfile saves the outgoing profile before loading the new one.
                Profiles:SetProfile(profileName)
                CE_Print(string.format(L("Switched to profile: %s"), profileName))
            end
        else
            CE_Print(string.format(L("Profile '%s' not found."), profileName))
            CE_Print(L("Available profiles:"))
            local profiles = Profiles:ListProfiles()
            for _, name in ipairs(profiles) do
                CE_Print("  - " .. name)
            end
        end
    end
end

CE_Debug("Profiles module loaded")

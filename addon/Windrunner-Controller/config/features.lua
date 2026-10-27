-- Vanilla gameplay and accessibility options shared by native and mapped input.
local Config=ConsoleExperience.config
local Controls=ConsoleExperience.controllerControls
local function L(key) return ConsoleExperience.locale and ConsoleExperience.locale.T(key) or key end
local defaults={controllerPromptPreset="standard",controllerModifierSource="triggers",controllerModifierLatch=false,
    controllerLeftTrigger="CE_ACTION_10",controllerRightTrigger="CE_ACTION_9",menuRepeatDelay=0.4,menuRepeatInterval=0.13,
    menuSwapConfirm=false,barIndependent=true,barLayout="clusters",barLeftX=0,barLeftY=0,barRightX=0,barRightY=0,
    hudIndependent=false,xpBarX=0,xpBarY=20,repBarX=0,repBarY=20,castbarX=0,castbarY=200,pageIndicatorX=0,pageIndicatorY=300,
    barVisibility="always",utilityRingRelease=false,utilityRings={},keyboardRememberWords=false,petBarX=0,petBarY=270,
    reloadOnControllerDisconnect=true}
for key,value in pairs(defaults) do Config.DEFAULTS[key]=value end
Controls.INPUTS.LT.key="controllerLeftTrigger"; Controls.INPUTS.LT.default="CE_ACTION_10"
Controls.INPUTS.RT.key="controllerRightTrigger"; Controls.INPUTS.RT.default="CE_ACTION_9"
table.insert(Controls.SPECIAL_ACTIONS,{id="CE_ACTION_10",name="Left action-bar button",desc="Use the left bumper's action slot on the current modifier page."})
table.insert(Controls.SPECIAL_ACTIONS,{id="CE_ACTION_9",name="Right action-bar button",desc="Use the right bumper's action slot on the current modifier page."})
local newActions={
    {id="SITORSTAND",nameKey="Sit / stand",icon="Interface\\Icons\\Spell_Nature_Sleep"},
    {id="TOGGLESHEATH",nameKey="Sheathe weapon",icon="Interface\\Icons\\INV_Sword_04"},
    {id="FOLLOWTARGET",nameKey="Follow target",icon="Interface\\Icons\\Ability_Tracking"},
    {id="TARGETLASTHOSTILE",nameKey="Last hostile target",icon="Interface\\Icons\\Ability_Hunter_SniperShot"},
    {id="TOGGLEPETBOOK",nameKey="Pet spellbook",icon="Interface\\Icons\\Ability_Hunter_Pet_Wolf"},
    {id="TOGGLERAIDTAB",nameKey="Raid panel",icon="Interface\\Icons\\INV_Banner_03"},
    {id="TOGGLEFRIENDSTAB",nameKey="Friends",icon="Interface\\Icons\\INV_Letter_02"},
    {id="TOGGLEWHOTAB",nameKey="Who list",icon="Interface\\Icons\\INV_Misc_GroupLooking"},
    {id="NAMEPLATES",nameKey="Enemy nameplates",icon="Interface\\Icons\\Ability_Hunter_HuntersMark"},
    {id="FRIENDNAMEPLATES",nameKey="Friendly nameplates",icon="Interface\\Icons\\Spell_Holy_PrayerOfHealing"},
    {id="OPENCHAT",nameKey="Type in chat",icon="Interface\\Icons\\INV_Scroll_03"},
    {id="REPLY",nameKey="Reply to whisper",icon="Interface\\Icons\\INV_Letter_02"},
    {id="CE_PET_MENU",nameKey="Pet controls",icon="Interface\\Icons\\Ability_Hunter_Pet_Wolf"},
    {id="CE_UNIT_MENU",nameKey="Target actions",icon="Interface\\Icons\\Ability_Hunter_SniperShot"},
    {id="CE_LOOT_MENU",nameKey="Pending loot rolls",icon="Interface\\Icons\\INV_Misc_Bag_08"},
    {id="CE_RING_EDITOR",nameKey="Edit utility rings",icon="Interface\\Icons\\INV_Jewelry_Ring_03"},
}
for index=1,12 do
    table.insert(newActions,{id="CE_RING_"..index,nameKey="Utility ring "..index,icon="Interface\\Icons\\INV_Jewelry_Ring_03"})
    Controls.MENU_ACTIONS["CE_RING_"..index]=true
end
for index=1,4 do table.insert(newActions,{id="TARGETPARTYMEMBER"..index,nameKey="Target party member "..index,icon="Interface\\Icons\\Spell_Holy_PrayerOfHealing"}) end
for index=1,8 do table.insert(newActions,{id="RAIDTARGET"..index,nameKey="Raid marker "..index,icon="Interface\\TargetingFrame\\UI-RaidTargetingIcon_"..index}) end
table.insert(newActions,{id="RAIDTARGETNONE",nameKey="Clear raid marker",icon="Interface\\Icons\\INV_Misc_QuestionMark"})
for _,action in ipairs(newActions) do table.insert(ConsoleExperience.proxied.ACTIONS,action) end
for _,id in ipairs({"CE_PET_MENU","CE_UNIT_MENU","CE_LOOT_MENU","CE_RING_EDITOR","CE_RING_1","CE_RING_2","CE_RING_3","CE_RING_4","TOGGLEPETBOOK","TOGGLERAIDTAB","TOGGLEFRIENDSTAB","TOGGLEWHOTAB","TOGGLEGAMEMENU","OPENCHAT","REPLY"}) do Controls.MENU_ACTIONS[id]=true end

function Config:CreateGameplaySection()
    local section=self:CreateScrollableSection("gameplay")
    local previous
    local function Box(title,count)
        local box=Config:CreateSectionBox(section,L(title),32+count*48)
        box.ceCustomRows=true; box:ClearAllPoints()
        box:SetPoint("TOPLEFT",previous or section,previous and "BOTTOMLEFT" or "TOPLEFT",previous and 0 or 5,previous and -30 or -25)
        box:SetWidth(section:GetWidth()-10); previous=box; return box
    end
    local function Place(row,box,index)
        row:SetPoint("TOPLEFT",box,"TOPLEFT",16,-16-(index-1)*48); return row
    end
    local function Choice(box,key,label,choices,index,changed)
        return Place(Config:CreateChoiceRow(box,"CEFeature"..key,label,key,choices,changed),box,index)
    end
    local function Toggle(box,key,label,index,changed)
        return Choice(box,key,label,{{false,"Off"},{true,"On"}},index,changed)
    end
    local function Refresh() if ConsoleExperience.layout then ConsoleExperience.layout:Refresh() end end
    local tools=Box("Tools",7)
    local actions={{"Setup / input test",function() ConsoleExperience.setup:Show() end},
        {"Move elements",function() ConsoleExperience.layout:Start() end},
        {"Edit utility rings",function() ConsoleExperience.rings:OpenEditor() end},
        {"Share profile",function() ConsoleExperience.sharing:Show() end},
        {"Pet controls",function() CE_PET_MENU() end},
        {"Target actions",function() CE_UNIT_MENU() end},
        {"Pending loot rolls",function() CE_LOOT_MENU() end}}
    for i,action in ipairs(actions) do Place(Config:CreateSettingRow(tools,"CEFeatureTool"..i,action[1],nil,nil,action[2]),tools,i) end
    local input=Box("Input and menus",6)
    Choice(input,"controllerModifierSource","Modifier buttons",{{"triggers","Triggers (LT / RT)"},{"bumpers","Bumpers (LB / RB)"}},1,function()
        if WindrunnerController then WindrunnerController:Release() end
        if Config.bindingOverview then Config:RefreshBindingOverview() end
    end)
    Toggle(input,"controllerModifierLatch","Tap modifiers to latch",2,function() if WindrunnerController then WindrunnerController:Release() end end)
    Toggle(input,"menuSwapConfirm","Swap A / B menu confirm and cancel",3,function()
        if ConsoleExperience.cursor.tooltip then ConsoleExperience.cursor.tooltip:UpdateControllerIcons() end
        if ConsoleExperience.radial then ConsoleExperience.radial:UpdateInstructions() end
        if Config.UpdateNavigationHint then Config:UpdateNavigationHint() end
    end)
    for i,setting in ipairs({{"menuRepeatDelay","Repeat delay (seconds)",0.05,0.15,1},{"menuRepeatInterval","Repeat interval (seconds)",0.01,0.06,0.5}}) do
        local key,step,minimum,maximum=setting[1],setting[3],setting[4],setting[5]
        Place(Config:CreateSettingRow(input,"CEFeature"..key,setting[2],function() return "<  "..string.format("%.2f",Config:Get(key)).."  >" end,function(delta)
            Config:Set(key,math.max(minimum,math.min(maximum,math.floor((Config:Get(key)+delta*step)*100+0.5)/100)))
        end),input,i+3)
    end
    Toggle(input,"reloadOnControllerDisconnect","Reload UI after controller disconnect",6,function()
        if WindrunnerController then WindrunnerController.reloadOnDisconnectAt=nil end
    end)
    local bars=Box("Layout and visibility",2)
    Choice(bars,"barLayout","Bar layout",{{"clusters","Controller clusters"},{"crossbar","Crossbar"},{"horizontal","Horizontal rows"}},1,function() Config:Set("barIndependent",true); Refresh() end)
    Choice(bars,"barVisibility","Show action bars",{{"always","Always"},{"combat","Combat and menus"},{"idle","Outside combat and menus"}},2,Refresh)
    local rings=Box("Utility rings and typing",2)
    Toggle(rings,"utilityRingRelease","Release held ring button to activate",1)
    Toggle(rings,"keyboardRememberWords","Remember typed words for suggestions",2)
    self.contentSections.gameplay=section
end

table.insert(Config.SECTIONS,{id="gameplay",name="Gameplay"})

function ConsoleExperience:RegisterQuickCollections()
    local radial=self.radial
    if not radial then return end
    radial:RegisterCollection(L("Tools"),function()
        local function Entry(name,icon,action,available)
            return {name=L(name),icon=icon,action=action,isAvailable=available}
        end
        return {
            Entry("Pet controls","Interface\\Icons\\Ability_Hunter_Pet_Wolf",CE_PET_MENU,function() return HasPetUI and HasPetUI() end),
            Entry("Target actions","Interface\\Icons\\Ability_Hunter_SniperShot",CE_UNIT_MENU,function() return UnitExists and UnitExists("target") end),
            Entry("Pending loot rolls","Interface\\Icons\\INV_Misc_Bag_08",CE_LOOT_MENU),
            Entry("Edit utility rings","Interface\\Icons\\INV_Jewelry_Ring_03",function() ConsoleExperience.rings:OpenEditor() end),
            Entry("Setup / input test","Interface\\Icons\\INV_Misc_Gear_01",function() ConsoleExperience.setup:Show() end),
            Entry("Share profile","Interface\\Icons\\INV_Letter_02",function() ConsoleExperience.sharing:Show() end),
            Entry("Game menu","Interface\\Icons\\INV_Misc_Gear_01",function() CE_ToggleGameMenu() end),
            Entry("Raid panel","Interface\\Icons\\INV_Banner_03",function() RunBinding("TOGGLERAIDTAB") end),
            Entry("Move bars / chat","Interface\\Icons\\INV_Misc_Map_01",function() ConsoleExperience.layout:Start() end),
        }
    end)
    radial:RegisterCollection(L("Professions"),function()
        local skills,items={},{}
        if GetNumSkillLines and GetSkillLineInfo then
            for i=1,GetNumSkillLines() do local name,header=GetSkillLineInfo(i); if name and (not header or header==0) then skills[name]=true end end
        end
        if GetNumSpellTabs and GetSpellTabInfo and GetSpellName then
            for tab=1,GetNumSpellTabs() do
                local _,_,offset,count=GetSpellTabInfo(tab)
                for i=offset+1,offset+count do
                    local name=GetSpellName(i,BOOKTYPE_SPELL or "spell")
                    if name and skills[name] and not (IsPassiveSpell and IsPassiveSpell(i,BOOKTYPE_SPELL or "spell") and IsPassiveSpell(i,BOOKTYPE_SPELL or "spell")~=0) then
                        local index=i
                        table.insert(items,{name=name,icon=GetSpellTexture(i,BOOKTYPE_SPELL or "spell"),action=function()
                            if GetSpellName(index,BOOKTYPE_SPELL or "spell")==name then CastSpell(index,BOOKTYPE_SPELL or "spell") end
                        end})
                    end
                end
            end
        end
        return items
    end)
end

local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
-- Bounded, versioned text interchange for portable settings and control bindings.
-- Imported text is parsed as data; it is never executed or partially applied.
ConsoleExperience.sharing = ConsoleExperience.sharing or {}
local Sharing = ConsoleExperience.sharing
Sharing.VERSION = 1
Sharing.MAX_TEXT = 24000
Sharing.MAX_ENTRIES = 400
local ENUMS={crosshairType={cross=true,dot=true},controllerType={xbox=true,ps=true},controllerModifierSource={triggers=true,bumpers=true},barAppearance={classic=true,modern=true},
    barLabelAnchor={TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,CENTER=true},
    chatVisibility={always=true,typing=true},keyboardLayout={auto=true,enUS=true,deDE=true,frFR=true,esES=true},
    barLayout={clusters=true,crossbar=true,horizontal=true},barVisibility={always=true,combat=true,idle=true},
    controllerPromptPreset={standard=true,switch=true,deck=true},radialSelectionStick={left=true,right=true,both=true},
    xpBarDisplay={XP=true,PETXP=true,REP=true,FLEX=true,XPFLEX=true},repBarDisplay={REP=true,FLEX=true},
    uiTheme={ember=true,frost=true,grove=true},uiAccent={theme=true,gold=true,ice=true,emerald=true,violet=true,rose=true,class=true,custom=true}}
local RANGES={
    crosshairX={-2000,2000},crosshairY={-2000,2000},crosshairSize={8,200},crosshairColorR={0,1},crosshairColorG={0,1},crosshairColorB={0,1},crosshairColorA={0,1},
    barButtonSize={20,160},barXOffset={-2000,2000},barYOffset={-2000,2000},barPadding={0,300},barStarPadding={1,2000},barScale={0.3,2},
    barLabelSize={8,48},barLabelX={-80,80},barLabelY={-80,80},
    sideBarLeftButtons={1,5},sideBarRightButtons={1,5},sideBarLeftX={-2000,2000},sideBarLeftY={-2000,2000},sideBarRightX={-2000,2000},sideBarRightY={-2000,2000},
    chatWidth={200,2000},chatHeight={80,1000},chatXOffset={-2000,2000},chatBottomY={-1000,2000},xpBarWidth={100,2000},xpBarHeight={10,80},xpBarTimeout={0,60},xpBarTextOffsetY={-200,200},
    repBarWidth={100,2000},repBarHeight={10,80},repBarTimeout={0,60},repBarTextOffsetY={-200,200},castbarHeight={10,80},
    castbarColorR={0,1},castbarColorG={0,1},castbarColorB={0,1},castbarChannelColorR={0,1},castbarChannelColorG={0,1},castbarChannelColorB={0,1},
    uiAccentR={0,1},uiAccentG={0,1},uiAccentB={0,1},uiPanelOpacity={0.72,1},uiMenuScale={0.65,1.25},uiRadialScale={0.65,1.3},uiTextScale={0.9,1.2},uiFocusThickness={1,4},uiHintDuration={1,6},
    barLeftX={-2000,2000},barLeftY={-2000,2000},barRightX={-2000,2000},barRightY={-2000,2000},
    petBarX={-2000,2000},petBarY={-2000,2000},menuRepeatDelay={0.05,2},menuRepeatInterval={0.05,1},
    xpBarX={-2000,2000},xpBarY={-2000,2000},repBarX={-2000,2000},repBarY={-2000,2000},
    castbarX={-2000,2000},castbarY={-2000,2000},pageIndicatorX={-2000,2000},pageIndicatorY={-2000,2000}}
local COLOR_KEYS={xpBarColor=true,xpBarRestColor=true}
local AUX_KEYS={}
local AUX_BASES={"controllerLeftStickClick","controllerRightStickClick","controllerStartButton","controllerBackButton","controllerLeftTrigger","controllerRightTrigger"}
local AUX_ORDER={}
for _,base in ipairs(AUX_BASES) do
    AUX_KEYS[base]=true
    table.insert(AUX_ORDER,base)
    for page=2,4 do local key=base.."Page"..page; AUX_KEYS[key]=true; table.insert(AUX_ORDER,key) end
end
local function themeButton(button) if ConsoleExperience.theme and ConsoleExperience.theme.Button then ConsoleExperience.theme:Button(button) end end
local function themeField(box) if ConsoleExperience.theme and ConsoleExperience.theme.Register then ConsoleExperience.theme:Register(box,"field") end end
local function fitFrame(frame)
    local screenW,screenH=UIParent:GetWidth(),UIParent:GetHeight()
    local fit=math.min(1,math.max(0.01,(screenW-32)/760),math.max(0.01,(screenH-32)/620))
    local menuScale=ConsoleExperience.theme and ConsoleExperience.theme.Get and ConsoleExperience.theme:Get("uiMenuScale") or 1
    frame:SetScale(math.min(fit,fit*math.max(0.5,menuScale)))
    frame._windrunnerFitW,frame._windrunnerFitH=screenW,screenH
end
local function percentEncode(s)
    s=string.gsub(s,"([^%w%._%-])",function(c) return string.format("%%%02X",string.byte(c)) end)
    return s
end
local function percentDecode(s)
    local out={}; local i=1
    while i<=string.len(s) do
        local char=string.sub(s,i,i)
        if char=="%" then
            local hex=string.sub(s,i+1,i+2)
            if string.len(hex)~=2 or not string.find(hex,"^[%x][%x]$") then return nil end
            table.insert(out,string.char(tonumber(hex,16))); i=i+3
        else table.insert(out,char); i=i+1 end
    end
    return table.concat(out)
end
local function schema()
    local result={}
    local defaults=ConsoleExperience.config and ConsoleExperience.config.DEFAULTS or {}
    -- These are presentation, navigation, chat, and input preferences. Locale-specific
    -- labels and machine-local paths/debug flags remain local.
    for key,value in pairs(defaults) do
        local portable=key ~= "debugEnabled" and key ~= "language"
        if portable and (type(value)=="boolean" or type(value)=="number" or type(value)=="string") then result[key]=type(value) end
    end
    result.xpBarWidth="number"; result.repBarWidth="number"
    result.barLeftX="number"; result.barLeftY="number"; result.barRightX="number"; result.barRightY="number"
    result.controllerPromptPreset="string"
    for key in pairs(AUX_KEYS) do result[key]="string" end
    return result
end
local function actionCatalog()
    local valid={NONE=true,CE_TOGGLE_POINTER=true,CE_TOGGLE_RADIAL=true}
    for _,action in ipairs(ConsoleExperience.proxied and ConsoleExperience.proxied.ACTIONS or {}) do if action.id then valid[action.id]=true end end
    for _,action in ipairs(ConsoleExperience.controllerControls and ConsoleExperience.controllerControls.SPECIAL_ACTIONS or {}) do if action.id then valid[action.id]=true end end
    return valid
end
local function auxiliaryValue(key,config)
    local value=config and config[key]
    if value~=nil then return value end
    local _,_,base=string.find(key,"^(.-)Page[234]$")
    local defaults=ConsoleExperience.config and ConsoleExperience.config.DEFAULTS or {}
    if base then return (config and config[base]) or defaults[base] or "NONE" end
    return defaults[key] or "NONE"
end
local function validColor(value)
    local _,_,a,b,c,d=string.find(value,"^%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*$")
    if not a then return false end
    for _,part in ipairs({a,b,c,d}) do local n=tonumber(part); if not n or n<0 or n>1 then return false end end
    return true
end
local function validScalar(value, expected,key)
    if expected=="boolean" then return value=="true" or value=="false" end
    if expected=="number" then
        local n=tonumber(value); local range=RANGES[key]
        if not range and ConsoleExperience.theme and ConsoleExperience.theme.RANGES then range=ConsoleExperience.theme.RANGES[key] end
        return n and n==n and range and n>=range[1] and n<=range[2]
    end
    if type(value)~="string" or string.len(value)>128 or string.find(value,"[%c]") then return false end
    if ENUMS[key] then return ENUMS[key][value] and true or false end
    if COLOR_KEYS[key] then return validColor(value) end
    if AUX_KEYS[key] then return actionCatalog()[value] and true or false end
    return false
end
function Sharing:BuildPayload()
    local config=WindrunnerExperienceDB and WindrunnerExperienceDB.config or {}
    local currentProfile=ConsoleExperience.profiles and ConsoleExperience.profiles:GetCurrentProfile()
    local proxies=currentProfile and currentProfile.proxiedActions or (WindrunnerExperienceDB and WindrunnerExperienceDB.proxiedActions) or {}
    local lines={"WINDRUNNER-SETTINGS|"..self.VERSION}
    local whitelist=schema()
    local count=0
    for key,expected in pairs(whitelist) do
        if not AUX_KEYS[key] then
        local value=config[key]
        if value~=nil and type(value)==expected and validScalar(tostring(value),expected,key) then
            count=count+1; if count>self.MAX_ENTRIES then return nil,"Too many settings." end
            table.insert(lines,"C|"..key.."|"..percentEncode(tostring(value)))
        end
        end
    end
    for slot=1,40 do
        local binding=proxies[slot]
        if binding~=nil and (type(binding)~="string" or not actionCatalog()[binding]) then return nil,"Invalid controller binding in slot "..slot end
        count=count+1; if count>self.MAX_ENTRIES then return nil,"Too many settings." end
        table.insert(lines,"B|"..slot.."|"..(binding or ""))
    end
    for _,key in ipairs(AUX_ORDER) do
        local value=auxiliaryValue(key,config)
        if type(value)~="string" or not validScalar(value,"string",key) then return nil,"Invalid controller assignment: "..key end
        count=count+1; if count>self.MAX_ENTRIES then return nil,"Too many settings." end
        table.insert(lines,"A|"..key.."|"..value)
    end
    local rings=config.utilityRings or {}
    local ringIndex=0; local ringEntryCount=0
    for _,ring in ipairs(rings) do
        ringIndex=ringIndex+1
        if ringIndex>12 then return nil,"Too many utility rings." end
        if type(ring)~="table" or type(ring.name)~="string" or string.len(ring.name)>28 then return nil,"A utility ring is invalid." end
        local entries=ring.entries or {}
        local exported=0
        for _,entry in ipairs(entries) do
            if type(entry)=="table" and (entry.kind=="spell" and type(entry.name)=="string" or entry.kind=="item" and tonumber(entry.itemID)
                or entry.kind=="action" and type(entry.command)=="string" and string.sub(entry.command,1,3)~="CE_" and actionCatalog()[entry.command]) then
                exported=exported+1; ringEntryCount=ringEntryCount+1
                if exported>12 or ringEntryCount>144 then return nil,"Too many utility ring entries." end
                local itemId=entry.kind=="item" and tonumber(entry.itemID) or ""
                local entryName=entry.kind=="spell" and entry.name or (entry.kind=="action" and entry.command or (entry.name or ""))
                if string.len(entryName)>128 then return nil,"A utility ring entry is too long." end
                table.insert(lines,"R|"..ringIndex.."|"..percentEncode(ring.name).."|"..entry.kind.."|"..percentEncode(entryName).."|"..tostring(itemId).."|0")
            end
        end
        if exported==0 then table.insert(lines,"R|"..ringIndex.."|"..percentEncode(ring.name).."|empty|||0") end
    end
    table.insert(lines,"END")
    local output=table.concat(lines,"\n")
    if string.len(output)>self.MAX_TEXT then return nil,"Export exceeds the 24 KB limit." end
    return output
end
function Sharing:Parse(text)
    if type(text)~="string" or string.len(text)>self.MAX_TEXT then return nil,"Text is missing or exceeds the 24 KB limit." end
    local lines={}; for line in string.gfind(text,"([^\r\n]+)") do table.insert(lines,line) end
    if table.getn(lines)<2 or lines[1]~="WINDRUNNER-SETTINGS|"..self.VERSION then return nil,"Unknown format or version." end
    local whitelist=schema(); local result={config={},bindings={},rings={}}; local seen={}; local ringEntryCounts={}; local count=0; local ended=false
    for i=2,table.getn(lines) do
        local line=lines[i]
        if line=="END" then ended=true; if i~=table.getn(lines) then return nil,"Unexpected data after END." end; break end
        count=count+1; if count>self.MAX_ENTRIES then return nil,"Too many entries." end
        local _,_,kind=string.find(line,"^([CBAR])|")
        local key,value,extra,name,itemID,unused
        if kind=="C" or kind=="B" or kind=="A" then
            local pattern=kind=="C" and "^C|([^|]+)|([^|]*)$" or (kind=="B" and "^B|([^|]+)|([^|]*)$" or "^A|([^|]+)|([^|]*)$")
            _,_,key,value=string.find(line,pattern)
        elseif kind=="R" then
            _,_,key,value,extra,name,itemID,unused=string.find(line,"^R|([^|]+)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
        end
        if not kind or not key or not value or string.len(key)>64 or string.len(value)>256 then return nil,"Malformed entry." end
        local identity=kind.."|"..key
        if kind~="R" then if seen[identity] then return nil,"Duplicate entry." end; seen[identity]=true end
        if kind=="C" then
            local decoded=percentDecode(value); local expected=whitelist[key]
            if not expected or not decoded or not validScalar(decoded,expected,key) then return nil,"Unsupported or invalid setting: "..key end
            if expected=="boolean" then result.config[key]=decoded=="true"
            elseif expected=="number" then result.config[key]=tonumber(decoded)
            else result.config[key]=decoded end
        elseif kind=="B" then
            local slot=tonumber(key)
            if not slot or slot<1 or slot>40 or slot~=math.floor(slot) then return nil,"Invalid binding entry." end
            if value=="" then result.bindings[slot]=false
            elseif string.len(value)>80 or not string.find(value,"^[A-Z0-9_]+$") or not actionCatalog()[value] then return nil,"Invalid binding entry."
            else result.bindings[slot]=value end
        elseif kind=="A" then
            if not AUX_KEYS[key] or not validScalar(value,"string",key) then return nil,"Invalid auxiliary binding." end
            result.config[key]=value
        else
            if unused~="0" then return nil,"Malformed utility ring entry." end
            local ringIndex=tonumber(key); local ringName=percentDecode(value); local entryKind=extra
            local entryName=percentDecode(name or ""); local item=tonumber(itemID or "")
            if not ringIndex or ringIndex<1 or ringIndex>12 or ringIndex~=math.floor(ringIndex) or not ringName or string.len(ringName)>28 then return nil,"Invalid utility ring." end
            local ring=result.rings[ringIndex]
            if not ring then ring={name=ringName,entries={}}; result.rings[ringIndex]=ring elseif ring.name~=ringName then return nil,"Inconsistent utility ring." end
            if entryKind=="empty" then
                if table.getn(ring.entries)>0 or seen["EMPTY|"..ringIndex] then return nil,"Invalid empty ring." end
                seen["EMPTY|"..ringIndex]=true
            elseif entryKind=="spell" and entryName and string.len(entryName)>0 and string.len(entryName)<=128 and itemID=="" then
                if seen["EMPTY|"..ringIndex] then return nil,"Invalid ring entries." end
                ringEntryCounts[ringIndex]=(ringEntryCounts[ringIndex] or 0)+1
                if ringEntryCounts[ringIndex]>12 then return nil,"Too many utility ring entries." end
                table.insert(ring.entries,{kind="spell",name=entryName})
            elseif entryKind=="item" and entryName and item and item>=1 and item<=10000000 and item==math.floor(item) then
                if seen["EMPTY|"..ringIndex] then return nil,"Invalid ring entries." end
                ringEntryCounts[ringIndex]=(ringEntryCounts[ringIndex] or 0)+1
                if ringEntryCounts[ringIndex]>12 then return nil,"Too many utility ring entries." end
                table.insert(ring.entries,{kind="item",name=entryName,itemID=item})
            elseif entryKind=="action" and entryName and string.len(entryName)<=64
                and string.sub(entryName,1,3)~="CE_" and string.find(entryName,"^[A-Z0-9_]+$") and actionCatalog()[entryName] then
                if seen["EMPTY|"..ringIndex] then return nil,"Invalid ring entries." end
                ringEntryCounts[ringIndex]=(ringEntryCounts[ringIndex] or 0)+1
                if ringEntryCounts[ringIndex]>12 then return nil,"Too many utility ring entries." end
                table.insert(ring.entries,{kind="action",command=entryName,name=entryName})
            else return nil,"Invalid utility ring entry." end
        end
    end
    if not ended then return nil,"Missing END marker." end
    for slot=1,40 do if result.bindings[slot]==nil then return nil,"Import must contain all 40 controller slots." end end
    result.settingCount=0; for _ in pairs(result.config) do result.settingCount=result.settingCount+1 end
    result.bindingCount=0; for _ in pairs(result.bindings) do result.bindingCount=result.bindingCount+1 end
    local ordered={}
    for i=1,12 do if result.rings[i] then table.insert(ordered,result.rings[i]) end end
    result.rings=ordered
    result.ringCount=table.getn(ordered)
    result.includesActionBars=false; result.includesRings=true
    return result
end
local function copyTable(source, depth)
    if type(source)~="table" or depth>8 then return source end
    local out={}; for k,v in pairs(source) do
        if type(k)=="string" or type(k)=="number" then
            if type(v)=="table" then out[k]=copyTable(v,depth+1)
            elseif type(v)=="string" or type(v)=="number" or type(v)=="boolean" then out[k]=v end
        end
    end
    return out
end
function Sharing:Apply(parsed)
    if type(parsed)~="table" or type(parsed.config)~="table" or type(parsed.bindings)~="table" then return false,"Import preview required." end
    local allowed=schema()
    for key,value in pairs(parsed.config) do
        if not allowed[key] or type(value)~=allowed[key] or not validScalar(tostring(value),allowed[key],key) then return false,"Preview is invalid." end
    end
    if type(parsed.rings)~="table" or table.getn(parsed.rings)>12 then return false,"Preview is invalid." end
    for _,ring in ipairs(parsed.rings) do
        if type(ring)~="table" or type(ring.name)~="string" or string.len(ring.name)<1 or string.len(ring.name)>28
            or string.find(ring.name,"[%c]") or type(ring.entries)~="table" or table.getn(ring.entries)>12 then return false,"Preview is invalid." end
        for _,entry in ipairs(ring.entries) do
            if type(entry)~="table" then return false,"Preview is invalid." end
            if entry.kind=="spell" then
                if type(entry.name)~="string" or string.len(entry.name)<1 or string.len(entry.name)>128 or string.find(entry.name,"[%c]") then return false,"Preview is invalid." end
            elseif entry.kind=="item" then
                local item=tonumber(entry.itemID)
                if not item or item<1 or item>10000000 or item~=math.floor(item) then return false,"Preview is invalid." end
            else return false,"Preview is invalid." end
        end
    end
    for slot,value in pairs(parsed.bindings) do
        local n=tonumber(slot)
        if not n or n<1 or n>40 or n~=math.floor(n) or (value~=false and (type(value)~="string" or not actionCatalog()[value])) then return false,"Preview is invalid." end
    end
    for slot=1,40 do if parsed.bindings[slot]==nil then return false,"Preview is incomplete." end end
    local profiles=ConsoleExperience.profiles
    if profiles and profiles.SaveCurrentProfile then profiles:SaveCurrentProfile() end
    WindrunnerExperienceDB=WindrunnerExperienceDB or {}
    WindrunnerExperienceDB.profiles=WindrunnerExperienceDB.profiles or {}
    local base="Import Backup"; local name=base; local suffix=1
    while WindrunnerExperienceDB.profiles[name] do suffix=suffix+1; name=base.." "..suffix end
    if profiles and profiles.GetCurrentProfile then
        local current=profiles:GetCurrentProfile()
        if current then WindrunnerExperienceDB.profiles[name]=copyTable(current,0) end
    end
    WindrunnerExperienceDB.importBackup=name
    WindrunnerExperienceDB.config=WindrunnerExperienceDB.config or {}
    -- Validation above completes before the first write.
    for key,value in pairs(parsed.config) do
        if ConsoleExperience.config and ConsoleExperience.config.Set then ConsoleExperience.config:Set(key,value)
        else WindrunnerExperienceDB.config[key]=value end
    end
    local proxyTarget=WindrunnerExperienceDB.proxiedActions or {}; WindrunnerExperienceDB.proxiedActions=proxyTarget
    for slot=1,40 do proxyTarget[slot]=nil end
    for slot,value in pairs(parsed.bindings) do if value~=false then proxyTarget[slot]=value end end
    WindrunnerExperienceDB.config.utilityRings=copyTable(parsed.rings,0)
    local current=profiles and profiles.GetCurrentProfile and profiles:GetCurrentProfile()
    if current then
        current.config=current.config or {}; current.proxiedActions=current.proxiedActions or {}
        for key,value in pairs(parsed.config) do current.config[key]=value end
        for slot=1,40 do current.proxiedActions[slot]=nil end
        for slot,value in pairs(parsed.bindings) do if value~=false then current.proxiedActions[slot]=value end end
        if parsed.includesRings then current.config.utilityRings=copyTable(parsed.rings,0) end
    end
    if ConsoleExperience.rings and ConsoleExperience.rings.Validate then ConsoleExperience.rings:Validate() end
    if ConsoleExperience.proxied then
        if ConsoleExperience.proxied.ApplySlotBinding then for slot=1,40 do ConsoleExperience.proxied:ApplySlotBinding(slot) end end
        if ConsoleExperience.proxied.ApplyAllBindings then ConsoleExperience.proxied:ApplyAllBindings() end
    end
    local config=ConsoleExperience.config
    if config then
        if ConsoleExperience.theme and ConsoleExperience.theme.RefreshAll then ConsoleExperience.theme:RefreshAll() end
        if config.UpdateCrosshair then config:UpdateCrosshair() end
        if ConsoleExperience.layout and ConsoleExperience.layout.Refresh then ConsoleExperience.layout:Refresh() end
        if config.UpdateActionBarLayout then config:UpdateActionBarLayout() end
        if ConsoleExperience.actionbars and ConsoleExperience.actionbars.UpdateAllButtons then ConsoleExperience.actionbars:UpdateAllButtons() end
        if ConsoleExperience.actionbars and ConsoleExperience.actionbars.UpdateSideBars then ConsoleExperience.actionbars:UpdateSideBars() end
        if ConsoleExperience.chat and ConsoleExperience.chat.UpdateChatLayout then ConsoleExperience.chat:UpdateChatLayout() end
        if ConsoleExperience.xpbar and ConsoleExperience.xpbar.UpdateAllBars then ConsoleExperience.xpbar:UpdateAllBars() end
        if ConsoleExperience.castbar and ConsoleExperience.castbar.ReloadConfig then ConsoleExperience.castbar:ReloadConfig() end
        if ConsoleExperience.keyboard and ConsoleExperience.keyboard.RefreshLayout then ConsoleExperience.keyboard:RefreshLayout() end
        if config.RefreshBindingOverview then config:RefreshBindingOverview() end
        local controllerPage=config.contentSections and config.contentSections.controller
        if controllerPage and controllerPage.UpdateControllerPrompts then controllerPage.UpdateControllerPrompts() end
        local helpPage=config.contentSections and config.contentSections.help
        if helpPage and helpPage.UpdateHelpPrompts then helpPage.UpdateHelpPrompts() end
    end
    if profiles and profiles.SaveCurrentProfile then profiles:SaveCurrentProfile() end
    return true,name
end
function Sharing:ListSharedProfiles()
    WindrunnerSharedProfiles=WindrunnerSharedProfiles or {}
    local names={}
    for name,payload in pairs(WindrunnerSharedProfiles) do
        if type(name)=="string" and type(payload)=="string" then table.insert(names,name) end
    end
    table.sort(names)
    return names
end
function Sharing:SaveSharedProfile(name)
    if type(name)~="string" then return false,"Enter a profile name." end
    name=string.gsub(string.gsub(name,"^%s*(.-)%s*$","%1"),"[%c|]","")
    if string.len(name)<1 or string.len(name)>64 then return false,"Profile names must be 1 to 64 characters." end
    local library=self:ListSharedProfiles(); local exists=false
    for _,savedName in ipairs(library) do if savedName==name then exists=true end end
    if not exists and table.getn(library)>=20 then return false,"The account library holds at most 20 profiles." end
    local payload,err=self:BuildPayload()
    if not payload then return false,err end
    WindrunnerSharedProfiles=WindrunnerSharedProfiles or {}; WindrunnerSharedProfiles[name]=payload
    return true,name
end
function Sharing:PreviewSharedProfile(name)
    WindrunnerSharedProfiles=WindrunnerSharedProfiles or {}
    local payload=WindrunnerSharedProfiles[name]
    if type(payload)~="string" then return nil,"Saved profile not found." end
    local parsed,err=self:Parse(payload)
    return parsed,err,payload
end
function Sharing:CreateFrame()
    if self.frame then return self.frame end
    local f=CreateFrame("Frame","CEProfileSharing",UIParent); f:SetWidth(760); f:SetHeight(620); f:SetPoint("CENTER",UIParent,"CENTER",0,0); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetFrameLevel(130); f.ceNavigationModal=true; f:EnableMouse(true)
    f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=16,insets={left=5,right=5,top=5,bottom=5}})
    if ConsoleExperience.theme then ConsoleExperience.theme:Register(f,"panel") end
    f:SetScript("OnHide",function() if WindrunnerController and WindrunnerController.Release then WindrunnerController:Release() end end)
    f:SetScript("OnShow",function() fitFrame(f) end)
    f:SetScript("OnUpdate",function()
        local width,height=UIParent:GetWidth(),UIParent:GetHeight()
        if width~=f._windrunnerFitW or height~=f._windrunnerFitH then fitFrame(f) end
    end)
    UISpecialFrames=UISpecialFrames or {}; local specialAdded=false
    for _,name in ipairs(UISpecialFrames) do if name==f:GetName() then specialAdded=true end end
    if not specialAdded then table.insert(UISpecialFrames,f:GetName()) end
    local box,summary,scrollFrame
    local updateTextExtent
    local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); title:SetPoint("TOP",f,"TOP",0,-18); title:SetText("Share settings and bindings"); if ConsoleExperience.theme then ConsoleExperience.theme:Register(title,"font") end
    local note=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); note:SetPoint("TOPLEFT",f,"TOPLEFT",24,-44); note:SetWidth(710); note:SetHeight(34); note:SetJustifyH("LEFT"); note:SetText("Portable settings, controller bindings, and utility ring names/spells/items are included. Macro ring entries and action-bar snapshots are omitted. Account library stores up to 20 named exports."); if ConsoleExperience.theme then ConsoleExperience.theme:Register(note,"font") end
    local nameBox=CreateFrame("EditBox","CEProfileShareName",f,"InputBoxTemplate"); nameBox:SetWidth(180); nameBox:SetHeight(24); nameBox:SetPoint("TOPLEFT",f,"TOPLEFT",26,-82); nameBox:SetAutoFocus(false); nameBox:SetMaxLetters(64); nameBox:SetText("My Layout")
    nameBox:SetScript("OnEscapePressed",function() nameBox:ClearFocus() end)
    local nameLabel=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); nameLabel:SetPoint("BOTTOMLEFT",nameBox,"TOPLEFT",0,4); nameLabel:SetText("Library name"); if ConsoleExperience.theme then ConsoleExperience.theme:Register(nameLabel,"font") end; themeField(nameBox)
    local library=CreateFrame("Frame","CEProfileShareLibrary",f,"UIDropDownMenuTemplate"); library:SetPoint("LEFT",nameBox,"RIGHT",8,-2)
    UIDropDownMenu_Initialize(library,function()
        for _,savedName in ipairs(Sharing:ListSharedProfiles()) do
            local selected=savedName
            UIDropDownMenu_AddButton({text=selected,value=selected,func=function()
                UIDropDownMenu_SetSelectedValue(library,selected); UIDropDownMenu_SetText(selected,library)
                local parsed,err,payload=Sharing:PreviewSharedProfile(selected)
                if parsed then box:SetText(payload); updateTextExtent(); scrollFrame:SetVerticalScroll(0); Sharing.pending=parsed; Sharing.pending.includesRings=true
                    summary:SetText(string.format("Preview: %d settings, %d bindings, %d rings. Import creates a character backup.",parsed.settingCount,parsed.bindingCount,parsed.ringCount))
                else summary:SetText("Saved export could not be previewed: "..tostring(err)) end
            end})
        end
    end)
    UIDropDownMenu_SetWidth(160,library); UIDropDownMenu_SetText("Saved profiles",library)
    local save=CreateFrame("Button","CEProfileShareSave",f,"UIPanelButtonTemplate"); save:SetWidth(150); save:SetHeight(24); save:SetPoint("LEFT",library,"RIGHT",8,2); save:SetText("Save to account")
    scrollFrame=CreateFrame("ScrollFrame","CEProfileShareScrollFrame",f,"UIPanelScrollFrameTemplate"); scrollFrame:SetPoint("TOPLEFT",f,"TOPLEFT",25,-122); scrollFrame:SetWidth(708); scrollFrame:SetHeight(300)
    scrollFrame:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=10,insets={left=3,right=3,top=3,bottom=3}}); scrollFrame:SetBackdropColor(0,0,0,0.8); themeField(scrollFrame)
    box=CreateFrame("EditBox","CEProfileShareText",scrollFrame); box:SetMultiLine(true); box:SetAutoFocus(false); box:SetFontObject(GameFontHighlightSmall); box:SetPoint("TOPLEFT",scrollFrame,"TOPLEFT",4,-4); box:SetWidth(680); box:SetHeight(300); box:SetTextInsets(6,6,6,6); box:SetMaxLetters(self.MAX_TEXT); box:EnableMouse(true)
    scrollFrame:SetScrollChild(box)
    updateTextExtent=function()
        -- The text child grows to hold the full payload; the viewport stays fixed.
        local text=box:GetText() or ""; local charsPerLine=78; local lines=1; local column=0
        for i=1,string.len(text) do
            local char=string.sub(text,i,i)
            if char=="\n" then lines=lines+1; column=0
            else column=column+1; if column>charsPerLine then lines=lines+1; column=1 end end
        end
        box:SetHeight(math.max(scrollFrame:GetHeight(),lines*14+12))
    end
    local function scrollToCursor(y)
        if type(y)~="number" or not scrollFrame.SetVerticalScroll then return end
        local desired=math.max(0,math.abs(y)-scrollFrame:GetHeight()+24)
        if scrollFrame.GetVerticalScrollRange then desired=math.min(desired,scrollFrame:GetVerticalScrollRange()) end
        scrollFrame:SetVerticalScroll(desired)
    end
    box:SetScript("OnTextChanged",function() Sharing.pending=nil; updateTextExtent() end)
    box:SetScript("OnCursorChanged",function() scrollToCursor(arg2) end)
    box:SetScript("OnEscapePressed",function() box:ClearFocus() end)
    summary=f:CreateFontString(nil,"OVERLAY","GameFontHighlight"); summary:SetPoint("TOPLEFT",scrollFrame,"BOTTOMLEFT",0,-8); summary:SetWidth(700); summary:SetHeight(92); summary:SetJustifyH("LEFT"); self.summary=summary; if ConsoleExperience.theme then ConsoleExperience.theme:Register(summary,"font") end
    local export=CreateFrame("Button","CEProfileShareExport",f,"UIPanelButtonTemplate"); export:SetWidth(105); export:SetHeight(28); export:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",24,20); export:SetText("Export")
    export:SetScript("OnClick",function() local text,err=Sharing:BuildPayload(); box:SetText(text or err or "Export unavailable"); updateTextExtent(); scrollFrame:SetVerticalScroll(0); box:HighlightText(); Sharing.pending=nil; summary:SetText(text and "Export ready. Select the text and copy it." or tostring(err)) end); themeButton(export)
    local preview=CreateFrame("Button","CEProfileSharePreview",f,"UIPanelButtonTemplate"); preview:SetWidth(105); preview:SetHeight(28); preview:SetPoint("LEFT",export,"RIGHT",8,0); preview:SetText("Preview import")
    preview:SetScript("OnClick",function() local parsed,err=Sharing:Parse(box:GetText() or ""); Sharing.pending=parsed
        if parsed then parsed.includesRings=true; summary:SetText(string.format("Preview: %d portable settings, %d bindings, and %d rings. Macro ring entries and action bars omitted. Import creates a backup profile first.",parsed.settingCount,parsed.bindingCount,parsed.ringCount)) else summary:SetText("Import rejected: "..tostring(err)) end
    end); themeButton(preview)
    local apply=CreateFrame("Button","CEProfileShareApply",f,"UIPanelButtonTemplate"); apply:SetWidth(120); apply:SetHeight(28); apply:SetPoint("LEFT",preview,"RIGHT",8,0); apply:SetText("Apply preview")
    apply:SetScript("OnClick",function() if not Sharing.pending then summary:SetText("Preview a valid import before applying."); return end
        local ok,name=Sharing:Apply(Sharing.pending); if ok then summary:SetText("Imported. Current settings backed up as profile: "..name); Sharing.pending=nil else summary:SetText("Import failed: "..tostring(name)) end
    end); themeButton(apply)
    local close=CreateFrame("Button","CEProfileShareClose",f,"UIPanelButtonTemplate"); close:SetWidth(80); close:SetHeight(28); close:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-24,20); close:SetText("Close"); close:SetScript("OnClick",function() f:Hide() end); themeButton(close)
    save:SetScript("OnClick",function()
        local ok,result=Sharing:SaveSharedProfile(nameBox:GetText() or "")
        if ok then summary:SetText("Saved account layout: "..result)
        else summary:SetText("Could not save: "..tostring(result)) end
    end); themeButton(save)
    self.frame=f; self.editBox=box; self.scrollFrame=scrollFrame; self.exportButton=export; self.previewButton=preview; self.applyButton=apply; self.closeButton=close; self.nameBox=nameBox; self.libraryDropdown=library
    local hooks=ConsoleExperience.hooks
    if hooks and hooks.HookDynamicFrame then hooks:HookDynamicFrame(f,"Profile Sharing") end
    fitFrame(f)
    return f
end
function Sharing:Show() local f=self:CreateFrame(); self.pending=nil; self.summary:SetText("Export a profile or paste a versioned string and preview it before applying."); if self.scrollFrame then self.scrollFrame:SetVerticalScroll(0) end; f:Show(); if WindrunnerController and WindrunnerController.Release then WindrunnerController:Release() end end
function Sharing:IsVisible() return self.frame and self.frame:IsVisible() or false end
function Sharing:Back() if self.frame then self.frame:Hide() end end
CE_Debug("Sharing module loaded")

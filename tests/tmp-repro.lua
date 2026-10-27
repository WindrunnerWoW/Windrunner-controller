local root=assert(arg[1])
local model=assert(loadfile("tests/ui-model.lua"))()
CreateFrame=function(kind,name,parent,template) return model:Create(kind,name,parent,template) end
UIParent=CreateFrame("Frame","UIParent"); UIParent:SetWidth(1920); UIParent:SetHeight(1080)
GameMenuFrame=CreateFrame("Frame","GameMenuFrame",UIParent)
ConsoleExperience={}
WindrunnerExperienceDB={config={},proxiedActions={[1]="JUMP"}}
SlashCmdList={}; StaticPopupDialogs={}; UISpecialFrames={}; tinsert=table.insert
getglobal=function(name) return getfenv(0)[name] end
getfenv(0)._G=getfenv(0)
CE_Debug=function() end; CE_Print=function() end; PlaySound=function() end
UnitClass=function() return "Warrior","WARRIOR" end
RAID_CLASS_COLORS={WARRIOR={r=0.78,g=0.61,b=0.43}}
IsShiftKeyDown=function() return false end; IsControlKeyDown=function() return false end
local function load(path) assert(loadfile(root.."/"..path))() end
GetLocale=function() return "enUS" end
load("locale/locale.lua"); load("locale/translations_enUS.lua")
load("ui/theme.lua"); load("actionbars/bars.lua"); load("actionbars/skin.lua")
load("config/config.lua"); load("config/rows.lua"); load("config/appearance.lua")
local config,theme=ConsoleExperience.config,ConsoleExperience.theme
config.CreateContentSections=function(self)
    self.contentSections={}
    self:CreateControllerSection(); self:CreateAppearanceSection()
end
config:CreateMainFrame(); config.frame:Show(); config:ShowSection("appearance")
model:Tick(); model:Tick()

local page=config.contentSections.appearance
local boxes={}
for _,child in ipairs({page:GetChildren()}) do
    if child.CalculateHeight then table.insert(boxes,child) end
end
local function Report(tag)
    local out={}
    for i,box in ipairs(boxes) do
        table.insert(out,box:GetName().."="..tostring(box.height))
    end
    print(tag.." scrollChild="..tostring(page.height).." "..table.concat(out," "))
end
Report("initial")
for i=1,6 do
    config:Set("uiAccent","gold")
    config:Set("uiAccent","theme")
    model:Tick(); model:Tick()
    Report("after theme change "..i)
end
for i=1,4 do
    config:Set("uiTextScale",1.1)
    model:Tick(); model:Tick()
    Report("after text scale "..i)
end

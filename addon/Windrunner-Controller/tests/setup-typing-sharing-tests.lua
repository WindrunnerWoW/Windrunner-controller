-- Focused Lua 5.0 tests for the setup, keyboard helper, and profile interchange APIs.
local root = arg and arg[1] or "."
local function source(path) return dofile(root .. "/" .. path) end
local function equal(actual, expected, label)
    if actual ~= expected then error((label or "assertion") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end
local function truth(value, label) if not value then error(label or "expected true") end end

ConsoleExperience={
    config={DEFAULTS={keyboardEnabled=true,keyboardRememberWords=false,chatVisibility="always",crosshairEnabled=true,controllerType="xbox",controllerPromptPreset="standard",barScale=1,debugEnabled=false,controllerLeftStickClick="TARGETNEARESTENEMY",controllerRightStickClick="CE_TOGGLE_POINTER",controllerStartButton="CE_TOGGLE_RADIAL",controllerBackButton="TOGGLEWORLDMAP",controllerLeftTrigger="NONE",controllerRightTrigger="NONE"},Get=function(self,key) return WindrunnerExperienceDB.config[key] end,Set=function(self,key,value) WindrunnerExperienceDB.config[key]=value end},
    locale={T=function(self,key) return key end},
    keyboard={CreateFrame=function(self) local f=CreateFrame("Frame","TestKeyboard",UIParent); f.keyboardBox=CreateFrame("Frame",nil,f); f.keysContainer=CreateFrame("Frame",nil,f.keyboardBox); self.keys={}; return f end,CreateKeys=function() end,AddChar=function(self,char) self.currentText=(self.currentText or "")..char end,DeleteChar=function(self) self.currentText=string.sub(self.currentText or "",1,-2) end,Show=function(self) self:CreateFrame():Show() end},
    profiles={GetCurrentProfile=function() return WindrunnerExperienceDB.profiles.Default end,SaveCurrentProfile=function() end},
    proxied={ACTIONS={{id="JUMP"},{id="TARGETNEARESTENEMY"},{id="TOGGLEWORLDMAP"}},ApplyAllBindings=function() end},
}
WindrunnerExperienceDB={config={keyboardEnabled=true,chatVisibility="always",controllerType="xbox",controllerPromptPreset="standard",barScale=1,controllerLeftStickClick="TARGETNEARESTENEMY",controllerRightStickClick="CE_TOGGLE_POINTER",controllerStartButton="CE_TOGGLE_RADIAL",controllerBackButton="TOGGLEWORLDMAP",controllerLeftTrigger="NONE",controllerRightTrigger="NONE",controllerLeftTriggerPage2="JUMP",utilityRings={{name="Travel",entries={{kind="spell",name="Mount Up"},{kind="macro",slot=8,name="Local Macro"}}}}},profiles={Default={config={},proxiedActions={[1]="JUMP"},actionBars={[1]={kind="spell",name="Local Spell"}}}},currentProfile="Default",proxiedActions={[1]="JUMP"}}
WindrunnerController={Release=function() end}
SlashCmdList={}
function CE_Debug() end
function CE_Print() end

-- Minimal UI model for constructing and opening feature windows under Lua 5.0.
local objectMethods={}
local function object(kind,name,parent)
    local o={kind=kind,name=name,parent=parent,width=0,height=0,visible=false,scripts={}}
    setmetatable(o,{__index=objectMethods})
    return o
end
function objectMethods:SetWidth(v) self.width=v end
function objectMethods:SetHeight(v) self.height=v end
function objectMethods:GetWidth() return self.width end
function objectMethods:GetHeight() return self.height end
function objectMethods:SetScale(v) self.scale=v end
local oneArgumentSetPoints={}
function objectMethods:SetPoint(point,relative,relativePoint,x,y)
    if relative==nil then table.insert(oneArgumentSetPoints,self) end
    self.points=self.points or {}; table.insert(self.points,{point,relative,relativePoint,x,y})
end
function objectMethods:ClearAllPoints() end
function objectMethods:SetFrameStrata(value) self.strata=value end
function objectMethods:SetFrameLevel(value) self.frameLevel=value end
function objectMethods:EnableMouse() end
function objectMethods:EnableKeyboard() end
function objectMethods:SetBackdrop() end
function objectMethods:SetBackdropColor() end
function objectMethods:SetTextInsets() end
function objectMethods:SetFontObject() end
function objectMethods:SetJustifyH() end
function objectMethods:SetAutoFocus() end
function objectMethods:ClearFocus() self.focusCleared=true end
function objectMethods:SetMaxLetters() end
function objectMethods:SetMultiLine(value) self.multiline=value end
function objectMethods:HighlightText() end
function objectMethods:SetText(value)
    self.text=value or ""
    if self.multiline then
        local charsPerLine=math.max(24,math.floor((self.width or 0)/7)); local rows=1; local column=0
        for i=1,string.len(self.text) do
            local char=string.sub(self.text,i,i)
            if char=="\n" then rows=rows+1; column=0
            else column=column+1; if column>charsPerLine then rows=rows+1; column=1 end end
        end
        self.height=math.max(self.height,rows*14+12)
    end
    local fn=self.scripts.OnTextChanged; if fn then this=self; fn() end
end
function objectMethods:GetText() return self.text or "" end
function objectMethods:SetScript(event,fn) self.scripts[event]=fn end
function objectMethods:GetScript(event) return self.scripts[event] end
function objectMethods:Show() self.visible=true; local fn=self.scripts.OnShow; if fn then this=self; fn() end end
function objectMethods:Hide() self.visible=false; local fn=self.scripts.OnHide; if fn then this=self; fn() end end
function objectMethods:IsVisible() return self.visible end
function objectMethods:GetName() return self.name end
function objectMethods:CreateFontString(name) return object("FontString",name,self) end
function objectMethods:CreateTexture(name,layer) local texture=object("Texture",name,self); texture.layer=layer; return texture end
function objectMethods:GetFontString() self.fontString=self.fontString or object("FontString",nil,self); return self.fontString end
function objectMethods:SetTexture(path) self.texture=path end
function objectMethods:SetTexCoord(left,right,top,bottom) self.texCoord={left,right,top,bottom} end
function objectMethods:SetVertexColor() end
function objectMethods:SetAlpha() end
function objectMethods:SetAllPoints() end
function objectMethods:SetTextColor() end
function objectMethods:SetMaxLetters() end
function objectMethods:SetCursorPosition(pos) self.cursor=pos end
function objectMethods:GetCursorPosition() return self.cursor or string.len(self:GetText()) end
function objectMethods:SetScrollChild(child) self.scrollChild=child; child.scrollParent=self end
function objectMethods:SetVerticalScroll(value) self.verticalScroll=value end
function objectMethods:GetVerticalScroll() return self.verticalScroll or 0 end
function objectMethods:GetVerticalScrollRange() return math.max(0,(self.scrollChild and self.scrollChild.height or 0)-self.height) end
function objectMethods:Insert(value) self.text=self:GetText()..value end
function objectMethods:HighlightText() end
function objectMethods:Click() local fn=self.scripts.OnClick; if fn then this=self; fn() end end
UIParent=object("Frame","UIParent",nil); UIParent.width=1024; UIParent.height=768
GameFontHighlightSmall={}
function CreateFrame(kind,name,parent,template) return object(kind,name,parent) end
local strataOrder={BACKGROUND=1,LOW=2,MEDIUM=3,HIGH=4,DIALOG=5,FULLSCREEN=6,FULLSCREEN_DIALOG=7,TOOLTIP=8}
local configWindow=CreateFrame("Frame","TestConfigWindow",UIParent); configWindow:SetFrameStrata("HIGH"); configWindow:SetFrameLevel(100)
local function assertModalAboveConfig(frame,label)
    truth((strataOrder[frame.strata] or 0)>(strataOrder[configWindow.strata] or 0),label.." is above HIGH config strata")
    equal(frame.frameLevel,130,label.." frame level")
    truth(frame.ceNavigationModal,label.." marks modal navigation ownership")
end
function UIDropDownMenu_Initialize(frame,fn) frame.initialize=fn end
local savedLibraryButtons={}
function UIDropDownMenu_AddButton(button) table.insert(savedLibraryButtons,button) end
function UIDropDownMenu_SetWidth(width,frame) frame.dropdownWidth=width end
function UIDropDownMenu_SetText(value,frame) frame.dropdownText=value end
function UIDropDownMenu_SetSelectedValue(frame,value) frame.selectedValue=value end
ConsoleExperience.hooks={HookDynamicFrame=function(self,frame) frame.dynamicHooked=true end}
ConsoleExperience.theme={Register=function() end,Button=function() end,Apply=function() end,Get=function() return 1 end}

source("config/controls.lua")
source("config/sharing.lua")
local sharing=ConsoleExperience.sharing
ConsoleExperience.config.DEFAULTS.radialSelectionStick="both"
WindrunnerExperienceDB.config.radialSelectionStick="left"
for key,value in pairs({barLabelEnabled=true,barLabelBackground=false,barLabelSize=18,barLabelAnchor="TOP",barLabelX=0,barLabelY=6}) do
    ConsoleExperience.config.DEFAULTS[key]=value
end
WindrunnerExperienceDB.config.barLabelEnabled=false
WindrunnerExperienceDB.config.barLabelBackground=false
WindrunnerExperienceDB.config.barLabelSize=24
WindrunnerExperienceDB.config.barLabelAnchor="LEFT"
WindrunnerExperienceDB.config.barLabelX=-12
WindrunnerExperienceDB.config.barLabelY=7
local payload,err=sharing:BuildPayload(); truth(payload,err)
local labelPreview=sharing:Parse(payload)
equal(labelPreview.config.barLabelEnabled,false,"label visibility survives export/import")
equal(labelPreview.config.barLabelBackground,false,"bare labels survive export/import")
equal(labelPreview.config.barLabelSize,24,"custom label size survives export/import")
equal(labelPreview.config.barLabelAnchor,"LEFT","label anchor survives export/import")
equal(labelPreview.config.barLabelX,-12,"label horizontal position survives export/import")
equal(labelPreview.config.barLabelY,7,"label vertical position survives export/import")
equal(sharing:Parse(string.gsub(payload,"C|barLabelSize|24","C|barLabelSize|49")),nil,"out-of-range label sizes rejected")
equal(sharing:Parse(string.gsub(payload,"C|barLabelAnchor|LEFT","C|barLabelAnchor|INVALID")),nil,"invalid label anchors rejected")
truth(string.find(payload,"C|radialSelectionStick|left",1,true),"radial stick preference is included in portable profiles")
local stickPayload=sharing:Parse(payload)
equal(stickPayload.config.radialSelectionStick,"left","radial preference survives profile parsing")
equal(sharing:Parse(string.gsub(payload,"C|radialSelectionStick|left","C|radialSelectionStick|invalid")),nil,"invalid radial stick preferences are rejected")
truth(string.find(payload,"WINDRUNNER%-SETTINGS|1"),"version header")
truth(not string.find(payload,"Local Spell",1,true),"action bars excluded")
truth(not string.find(payload,"Local Macro",1,true),"macro ring entries excluded")
local parsed,parseError=sharing:Parse(payload); truth(parsed,parseError)
equal(parsed.config.chatVisibility,"always","typed string")
truth(not parsed.config.debugEnabled,"private debug excluded")
equal(parsed.settingCount,36,"portable settings and controller assignments")
equal(parsed.bindingCount,40,"all action slots included")
equal(parsed.config.controllerLeftTriggerPage2,"JUMP","modifier-specific auxiliary binding included")
local controls=ConsoleExperience.controllerControls
controls:SetPromptPreset("switch")
equal(controls:GetGlyphName("A"),"b","Switch physical A uses B glyph")
equal(controls:GetGlyphName("X"),"y","Switch physical X uses Y glyph")
equal(controls:GetGlyphName("Y"),"x","Switch physical Y uses X glyph")
equal(controls:GetGlyphName("B"),"a","Switch physical B uses A glyph")
equal(controls:GetPromptLabel("LT"),"ZL","Switch left trigger label")
equal(controls:GetPromptLabel("RT"),"ZR","Switch right trigger label")
equal(controls:GetPromptLabel("LB"),"L","Switch left bumper label")
equal(controls:GetPromptLabel("RB"),"R","Switch right bumper label")
equal(controls:GetPromptLabel("BACK"),"-","Switch back label")
equal(controls:GetPromptLabel("START"),"+","Switch start label")
equal(controls:GetPromptLabel("LS"),"LS","Switch left stick label")
equal(controls:GetPromptLabel("RS"),"RS","Switch right stick label")
controls:SetPromptPreset("deck")
equal(controls:GetPromptLabel("LT"),"LT","Deck keeps Xbox modifier label")
equal(controls:GetGlyphName("A"),"a","Deck keeps Xbox face glyph")
WindrunnerExperienceDB.config.controllerType="ps"; controls:SetPromptPreset("standard")
equal(controls:GetPromptLabel("A"),"Cross","PlayStation face label")
equal(controls:GetPromptLabel("B"),"Circle","PlayStation B label")
equal(controls:GetPromptLabel("X"),"Square","PlayStation X label")
equal(controls:GetPromptLabel("Y"),"Triangle","PlayStation Y label")
equal(controls:GetPromptLabel("LT"),"L2","PlayStation trigger label")
equal(controls:GetPromptLabel("BACK"),"Share","PlayStation back label")
equal(parsed.bindings[1],"JUMP","catalogued action binding")
equal(parsed.bindings[2],false,"unassigned slot represented explicitly")
equal(parsed.ringCount,1,"ring names included")
equal(table.getn(parsed.rings[1].entries),1,"portable spell ring entry included")
local applied,backup=sharing:Apply(parsed); truth(applied,"apply preview")
truth(WindrunnerExperienceDB.profiles[backup],"backup profile created")
truth(WindrunnerExperienceDB.profiles[backup].actionBars[1],"action bar snapshot kept in backup")
equal(WindrunnerExperienceDB.config.utilityRings[1].entries[1].name,"Mount Up","portable ring applied")
local badPreview={config={keyboardEnabled="yes"},bindings={},rings={},includesRings=true}
local badApplied=sharing:Apply(badPreview)
equal(badApplied,false,"invalid preview rejected before apply")
local invalid=string.gsub(payload,"END","C|debugEnabled|true\nEND")
local rejected=sharing:Parse(invalid)
equal(rejected,nil,"unknown setting rejected")
local badScale=string.gsub(payload,"C|barScale|1","C|barScale|0")
equal(sharing:Parse(badScale),nil,"out-of-range layout scale rejected")
local badAction=string.gsub(payload,"B|1|JUMP","B|1|UNLISTED_ACTION")
equal(sharing:Parse(badAction),nil,"unlisted action binding rejected")
local duplicate=payload .. "\n"
local parsedTrailing=sharing:Parse(duplicate); truth(parsedTrailing,"trailing newline accepted")
local oversized=string.rep("x",sharing.MAX_TEXT+1)
equal(sharing:Parse(oversized),nil,"oversized payload rejected")
local malformed={"C","C||","C|setting","B","B|x|JUMP","A||JUMP","A|controllerType|fake","R","R|1","R|1|bad|spell||broken|0","R|1|bad|item|x|999999999|0","Q|junk"}
for _,line in ipairs(malformed) do
    local ok,result=pcall(function() return sharing:Parse("WINDRUNNER-SETTINGS|1\n"..line.."\nEND") end)
    truth(ok,"malformed payload returns normally")
    equal(result,nil,"malformed payload rejected: "..line)
end
for i=1,500 do
    local fuzz="WINDRUNNER-SETTINGS|1\n"..string.rep(string.char(31+math.mod(i,90)),math.mod(i,37)).."\nEND"
    local ok,result=pcall(function() return sharing:Parse(fuzz) end)
    truth(ok,"fuzz input never raises")
    equal(result,nil,"fuzz input rejected")
end
truth(sharing:SaveSharedProfile("Vanilla Layout"),"save account library entry")
equal(table.getn(sharing:ListSharedProfiles()),1,"account library names sorted/listed")
local libraryPreview,libraryError=sharing:PreviewSharedProfile("Vanilla Layout")
truth(libraryPreview,libraryError)
for i=1,19 do truth(sharing:SaveSharedProfile("Layout "..i),"account cap entry") end
local overCap,capError=sharing:SaveSharedProfile("Layout 21")
equal(overCap,false,"account library bounded to 20")

source("keyboard/suggestions.lua")
local keyboard=ConsoleExperience.keyboard
keyboard.currentText="hel"
local words=keyboard:GetWordSuggestions()
equal(words[1],"hello","deterministic suggestion")
-- Original 1.12 EditBoxes lack GetCursorPosition. Only virtual append text is
-- completed; a cursor movement or physical edit invalidates that permission.
local stockEdit={text="he",scripts={}}
function stockEdit:GetText() return self.text end
function stockEdit:GetScript(key) return self.scripts[key] end
function stockEdit:SetScript(key,fn) self.scripts[key]=fn end
function stockEdit:HighlightText(first,last) self.first,self.last=first,last end
function stockEdit:Insert(value)
    self.text=string.sub(self.text,1,self.first or string.len(self.text))..value..string.sub(self.text,(self.last or string.len(self.text))+1)
end
keyboard.SyncInputText=function() end
keyboard:Show(stockEdit); keyboard.targetEditBox=stockEdit; keyboard.currentText="he"
keyboard:AddChar("l"); stockEdit.text=keyboard.currentText
truth(keyboard:AcceptSuggestion("hello"),"Vanilla virtual completion")
equal(stockEdit.text,"hello","last word completed without modern methods")
keyboard.currentText="hel"; stockEdit.text="hel"; keyboard._suggestionAppendText="hel"
stockEdit.scripts.OnCursorChanged()
equal(keyboard:AcceptSuggestion("hello"),false,"cursor movement blocks whole-word fallback")
equal(stockEdit.text,"hel","physical cursor text preserved")
keyboard.targetEditBox=nil

truth(keyboard:AddSavedPhrase("Need a moment"),"save phrase")
equal(table.getn(WindrunnerExperienceDB.keyboard.phrases),1,"phrase persisted per character")
equal(keyboard:AddSavedPhrase(string.rep("x",97)),false,"phrase length bounded")
local keyboardFrame=keyboard:CreateFrame(); truth(keyboardFrame.keyboardBox,"keyboard view attached"); keyboardFrame:Show()
truth(keyboard.suggestionStrip,"suggestion strip constructed")
truth(type(keyboard.suggestionButtons[1].label)=="string","cursor label is a string")
local phrasePointCallStart=table.getn(oneArgumentSetPoints)
keyboard:ShowPhraseManager(); truth(keyboard.phraseFrame:IsVisible(),"phrase manager opens")
equal(table.getn(oneArgumentSetPoints),phrasePointCallStart,"phrase manager frame uses valid relative SetPoint form")

source("config/setup.lua")
local setup=ConsoleExperience.setup
local setupPointCallStart=table.getn(oneArgumentSetPoints)
local setupFrame=setup:CreateFrame(); truth(setupFrame,"setup window constructed"); setup:Show(); truth(setup:IsVisible(),"setup window opens"); setup:Back(); equal(setup:IsVisible(),false,"setup closes from modal back")
assertModalAboveConfig(setupFrame,"setup")
equal(table.getn(oneArgumentSetPoints),setupPointCallStart,"setup frame tree uses valid relative SetPoint forms")
local function setupMarker(icon)
    for _,marker in ipairs(setup.markers) do if marker.icon==icon then return marker end end
    error("setup marker missing: "..icon)
end
WindrunnerExperienceDB.config.controllerType="ps"; controls:SetPromptPreset("standard"); setup:RefreshPromptArt()
equal(setup.diagramBody.texture,"Interface\\AddOns\\Windrunner-Controller\\textures\\bindings\\ps","PlayStation binding diagram selected")
equal(setup.diagramBody.layer,"ARTWORK","controller diagram body renders above panel backdrop")
equal(setup.diagramBody.texCoord[1],0,"binding art crop left UV")
equal(setup.diagramBody.texCoord[2],1,"binding art crop right UV")
equal(setup.diagramBody.texCoord[3],0.1,"binding art crop top UV")
equal(setup.diagramBody.texCoord[4],0.9,"binding art crop bottom UV")
truth(setup.promptButtons.ps.themeSelected,"PlayStation prompt choice marked selected")
equal(setup.promptButtons.xbox.themeSelected,false,"Xbox prompt choice not selected for PlayStation")
equal(setupMarker("up").x,120,"PlayStation D-pad up marker X")
equal(setupMarker("up").y,149,"PlayStation D-pad up marker Y")
equal(setupMarker("a").x,392,"PlayStation face marker X")
equal(setupMarker("a").y,203,"PlayStation face marker Y")
local psFacePoint=setupMarker("a").texture.points[table.getn(setupMarker("a").texture.points)]
equal(psFacePoint[4],392*setup.diagramScaleX,"PlayStation face marker transformed X")
equal(psFacePoint[5],-(203-setup.diagramSourceY)*setup.diagramScaleY,"PlayStation face marker transformed Y")
equal(setupMarker("back").x,167,"PlayStation Share marker X")
equal(setupMarker("back").y,132,"PlayStation Share marker Y")
equal(setupMarker("start").x,345,"PlayStation Options marker X")
equal(setupMarker("start").y,132,"PlayStation Options marker Y")
setup:Show(); setup:ObserveSample({rawLx=0,rawLy=0,rawRx=0,rawRy=0})
local leftDotPoint=setup.leftDot.points[table.getn(setup.leftDot.points)]
local rightDotPoint=setup.rightDot.points[table.getn(setup.rightDot.points)]
equal(leftDotPoint[4],176*setup.diagramScaleX,"PlayStation left raw-stick center X")
equal(leftDotPoint[5],-(274-setup.diagramSourceY)*setup.diagramScaleY,"PlayStation left raw-stick center Y")
equal(rightDotPoint[4],336*setup.diagramScaleX,"PlayStation right raw-stick center X")
equal(rightDotPoint[5],-(274-setup.diagramSourceY)*setup.diagramScaleY,"PlayStation right raw-stick center Y")
setup:ObserveSample({rawLy=1,rawRy=1})
local leftUpPoint=setup.leftDot.points[table.getn(setup.leftDot.points)]
local rightUpPoint=setup.rightDot.points[table.getn(setup.rightDot.points)]
truth(leftUpPoint[5]>leftDotPoint[5],"positive left-stick Y moves dot upward")
truth(rightUpPoint[5]>rightDotPoint[5],"positive right-stick Y moves dot upward")
equal(leftUpPoint[5]-leftDotPoint[5],24*setup.diagramScaleY,"left raw Y uses cropped artwork vertical scale")
equal(rightUpPoint[5]-rightDotPoint[5],24*setup.diagramScaleY,"right raw Y uses cropped artwork vertical scale")
setup:ObserveSample({rawLy=-1,rawRy=-1})
local leftDownPoint=setup.leftDot.points[table.getn(setup.leftDot.points)]
local rightDownPoint=setup.rightDot.points[table.getn(setup.rightDot.points)]
truth(leftDownPoint[5]<leftDotPoint[5],"negative left-stick Y moves dot downward")
truth(rightDownPoint[5]<rightDotPoint[5],"negative right-stick Y moves dot downward")
controls:SetPromptPreset("switch"); setup:RefreshPromptArt()
equal(setup.diagramBody.texture,"Interface\\AddOns\\Windrunner-Controller\\textures\\bindings\\xbox","Switch prompt uses Xbox-shaped binding diagram")
truth(setup.promptButtons.switch.themeSelected,"Switch prompt choice marked selected")
equal(setupMarker("up").x,176,"Xbox-shaped D-pad marker X after prompt switch")
equal(setupMarker("back").x,222,"Xbox-shaped Back marker X after prompt switch")
setup:ObserveSample({rawLx=0,rawLy=0,rawRx=0,rawRy=0})
leftDotPoint=setup.leftDot.points[table.getn(setup.leftDot.points)]
rightDotPoint=setup.rightDot.points[table.getn(setup.rightDot.points)]
equal(leftDotPoint[4],132*setup.diagramScaleX,"Xbox-shaped left raw-stick center X")
equal(leftDotPoint[5],-(172-setup.diagramSourceY)*setup.diagramScaleY,"Xbox-shaped left raw-stick center Y")
equal(rightDotPoint[4],342*setup.diagramScaleX,"Xbox-shaped right raw-stick center X")
equal(rightDotPoint[5],-(268-setup.diagramSourceY)*setup.diagramScaleY,"Xbox-shaped right raw-stick center Y")
local xboxFacePoint=setupMarker("a").texture.points[table.getn(setupMarker("a").texture.points)]
equal(xboxFacePoint[4],388*setup.diagramScaleX,"Xbox-shaped face marker transformed X")
equal(xboxFacePoint[5],-(200-setup.diagramSourceY)*setup.diagramScaleY,"Xbox-shaped face marker transformed Y")
controls:SetPromptPreset("standard"); WindrunnerExperienceDB.config.controllerType="ps"; setup:Show()
equal(setup.diagramFamily,"ps","opening setup refreshes current prompt family")
UIParent.width=640; UIParent.height=500; setup:Show(); setupFrame.scripts.OnUpdate(); truth(setupFrame.scale*700<=620.1 and setupFrame.scale*540<=480.1,"setup fits parent padding after resize")
setup:ObserveSample({buttons=4096,lt=0.5,rt=0.25,rawLx=0.1,rawLy=-0.2,rawRx=0.3,rawRy=0.4})
equal(setup.sample.rawRx,0.3,"read-only raw sample accepted")
truth(setup.leftStick:GetText(),"setup input text rendered")
UIParent.width=1024; UIParent.height=768
local sharingPointCallStart=table.getn(oneArgumentSetPoints)
local shareFrame=sharing:CreateFrame(); truth(shareFrame,"sharing window constructed"); sharing:Show(); truth(sharing:IsVisible(),"sharing window opens")
assertModalAboveConfig(shareFrame,"profile sharing")
equal(table.getn(oneArgumentSetPoints),sharingPointCallStart,"sharing frame tree uses valid relative SetPoint forms")
sharing:Back(); equal(sharing:IsVisible(),false,"sharing closes from modal back"); UIParent.width=700; UIParent.height=580; sharing:Show(); shareFrame.scripts.OnUpdate(); truth(shareFrame.scale*760<=680.1 and shareFrame.scale*620<=560.1,"sharing fits parent padding after resize")
truth(sharing.editBox and sharing.summary,"sharing controls constructed")
equal(sharing.scrollFrame.height,300,"share text viewport stays fixed height")
equal(sharing.scrollFrame.scrollChild,sharing.editBox,"multiline export is the scroll child")
truth(sharing.summary.points[1][2]==sharing.scrollFrame,"summary follows viewport, not the growing text child")
savedLibraryButtons={}; sharing.libraryDropdown.initialize(); truth(table.getn(savedLibraryButtons)>0,"saved account profiles populate dropdown")
sharing.scrollFrame:SetVerticalScroll(123)
local savedRow=savedLibraryButtons[1]; savedRow.func()
equal(sharing.libraryDropdown.selectedValue,savedRow.value,"library selection updates dropdown value")
equal(sharing.libraryDropdown.dropdownText,savedRow.value,"library selection updates dropdown label")
equal(sharing.editBox:GetText(),WindrunnerSharedProfiles[savedRow.value],"library selection loads full saved payload")
equal(sharing.scrollFrame:GetVerticalScroll(),0,"library selection resets viewport scroll")
truth(sharing.pending and sharing.pending.includesRings,"library selection creates a parsed preview")
truth(string.find(sharing.summary.text,"Preview:",1,true),"library selection displays preview summary")
sharing.nameBox.scripts.OnEscapePressed(); truth(sharing.nameBox.focusCleared,"Escape clears library-name edit focus")
sharing.editBox.scripts.OnEscapePressed(); truth(sharing.editBox.focusCleared,"Escape clears sharing-text edit focus")
for _,footer in ipairs({sharing.exportButton,sharing.previewButton,sharing.applyButton,sharing.closeButton}) do
    truth(footer.parent==shareFrame,"footer button remains a child of sharing window")
end
local fullExport=sharing:BuildPayload()
sharing.exportButton:Click()
equal(sharing.editBox:GetText(),fullExport,"export text remains complete and copyable")
truth(sharing.editBox.height>sharing.scrollFrame.height,"multiline child grows to hold the full export")
truth(sharing.scrollFrame:GetVerticalScrollRange()>0,"long export is scrollable in the fixed viewport")
equal(sharing.scrollFrame.height,300,"long export does not expand over the footer")
arg2=-450; this=sharing.editBox; sharing.editBox.scripts.OnCursorChanged()
truth(sharing.scrollFrame:GetVerticalScroll()>0,"Vanilla global arg2 cursor callback scrolls the viewport")
sharing:Show(); equal(sharing.scrollFrame:GetVerticalScroll(),0,"sharing opens at the top of the text viewport")

print("setup-typing-sharing-tests: PASS")

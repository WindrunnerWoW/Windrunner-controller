local CreateFrame = ConsoleExperience.ControllerCreateFrame or CreateFrame
-- Small deterministic word hints and character-local phrase shortcuts.
ConsoleExperience.keyboard=ConsoleExperience.keyboard or {}
local Keyboard=ConsoleExperience.keyboard
local COMMON={"about","after","again","all","always","and","are","around","attack","away","back","because","before","buff","can","careful","come","cooldown","could","damage","dead","doing","dont","down","everything","for","friend","from","good","group","guild","have","healer","hello","help","here","hold","in","incoming","is","just","later","left","lets","look","mana","need","nice","not","now","of","off","on","one","party","please","pull","ready","right","sorry","stay","thanks","that","the","there","they","this","to","wait","we","welcome","what","with","you"}
local function cfg(key)
    return ConsoleExperience.config and ConsoleExperience.config.Get and ConsoleExperience.config:Get(key)
end
local function capture(value,pattern)
    local _,_,found=string.find(value,pattern)
    return found
end
local function hasNonAscii(value) return string.find(value,"[^ -~]") ~= nil end
local function remembered()
    WindrunnerExperienceDB=WindrunnerExperienceDB or {}
    WindrunnerExperienceDB.keyboard=WindrunnerExperienceDB.keyboard or {words={},phrases={}}
    local data=WindrunnerExperienceDB.keyboard
    data.words=data.words or {}; data.phrases=data.phrases or {}
    return data
end
function Keyboard:GetWordSuggestions()
    local text=self.currentText or ""
    if self.isChatInput==false or string.find(text,"^%s*/") or hasNonAscii(text) then return {} end
    local prefix=capture(text,"([A-Za-z]+)$")
    if not prefix or string.len(prefix)<2 then return {} end
    local lower=string.lower(prefix); local found={}; local seen={}
    local data=remembered()
    local function add(word)
        if type(word)=="string" and string.lower(string.sub(word,1,string.len(lower)))==lower
            and string.lower(word)~=lower and not seen[string.lower(word)] then
            seen[string.lower(word)]=true; table.insert(found,word)
        end
    end
    for _,word in ipairs(COMMON) do add(word) end
    if cfg("keyboardRememberWords") then for _,word in ipairs(data.words) do add(word) end end
    table.sort(found)
    while table.getn(found)>3 do table.remove(found) end
    return found
end
function Keyboard:AcceptSuggestion(word)
    local text=self.currentText or ""
    if self.isChatInput==false or string.find(text,"^%s*/") or hasNonAscii(text) then return false end
    local prefix=capture(text,"([A-Za-z]+)$")
    if not prefix or not word or not string.find(word,"^[A-Za-z]+$") then return false end
    local edit=self.targetEditBox or ChatFrameEditBox
    if edit and edit.GetCursorPosition and edit.Insert and edit.HighlightText then
        local ok,cursor=pcall(function() return edit:GetCursorPosition() end)
        if not ok or cursor~=string.len(text) then return false end
        if edit.GetTextHighlight then
            local selected,first,last=pcall(function() return edit:GetTextHighlight() end)
            if selected and type(first)=="number" and type(last)=="number" and first~=last then return false end
        end
        local start=cursor-string.len(prefix)
        local changed=pcall(function() edit:HighlightText(start,cursor); edit:Insert(word) end)
        if changed then self.currentText=edit:GetText() or ""; self:SyncInputText(); return true end
    elseif edit and edit.HighlightText and edit.Insert and self._suggestionAppendText==text then
        -- Stock 1.12 has no editbox cursor-position getter. Complete only text
        -- just appended by our virtual keys, until any cursor/physical edit.
        local changed=pcall(function() edit:HighlightText(string.len(text)-string.len(prefix),string.len(text)); edit:Insert(word) end)
        self._suggestionAppendText=nil
        if changed then self.currentText=edit:GetText() or ""; self:SyncInputText(); return true end
    end
    return false
end
function Keyboard:AddSavedPhrase(phrase)
    if type(phrase)~="string" then return false end
    phrase=string.gsub(phrase,"^%s*(.-)%s*$","%1")
    if string.len(phrase)<1 or string.len(phrase)>96 or string.find(phrase,"[%c]") then return false end
    local phrases=remembered().phrases
    for _,saved in ipairs(phrases) do if saved==phrase then return true end end
    if table.getn(phrases)>=12 then table.remove(phrases,1) end
    table.insert(phrases,phrase); self:RefreshSuggestions(); return true
end
function Keyboard:RemoveSavedPhrase(index)
    local phrases=remembered().phrases
    if not phrases[index] then return false end
    table.remove(phrases,index); self:RefreshSuggestions(); self:RefreshPhraseManager(); return true
end
function Keyboard:InsertSavedPhrase(index)
    local phrase=remembered().phrases[index]
    if not phrase then return false end
    local edit=self.targetEditBox or ChatFrameEditBox
    if edit and edit.Insert then
        local ok=pcall(function() edit:Insert(phrase) end)
        if ok then self.currentText=edit:GetText() or ""; self:SyncInputText(); self:RefreshSuggestions(); return true end
    end
    self.currentText=(self.currentText or "")..phrase
    self:SyncInputText(); self:RefreshSuggestions(); return true
end
function Keyboard:AddSpace() self:AddChar(" ") end
function Keyboard:UpdateSuggestionLayout()
    local strip=self.suggestionStrip
    if not strip or not self.suggestionButtons then return end
    local available=strip:GetWidth()
    local phraseWidth=math.min(116,available*0.26)
    local width=math.max(1,(available-phraseWidth-16)/3)
    for i,button in ipairs(self.suggestionButtons) do
        button:SetWidth(width); button:ClearAllPoints()
        button:SetPoint("LEFT",strip,"LEFT",(i-1)*(width+4),0)
        button.text:SetWidth(math.max(1,width-10))
    end
    if self.showPhrasesButton then self.showPhrasesButton:SetWidth(phraseWidth) end
end
function Keyboard:RefreshSuggestions()
    self:UpdateSuggestionLayout()
    if not self.suggestionButtons or not self.frame or not self.frame:IsVisible() then return end
    local words=self:GetWordSuggestions()
    local phrases=remembered().phrases
    local wordCount=table.getn(words)
    for i,button in ipairs(self.suggestionButtons) do
        local value=words[i]
        button.actionKind="word"; button.suggestion=value
        if not value then
            local phraseIndex=i-wordCount
            if phrases[phraseIndex] then
                value="Phrase: "..string.sub(phrases[phraseIndex],1,18)
                button.actionKind="phrase"; button.suggestion=phraseIndex
            end
        end
        if value then
            button.label=string.sub(value,1,24); button.text:SetText(button.label); button.cursorPrompt=button.label; button:Show()
        else button.label=""; button.cursorPrompt=nil; button:Hide() end
    end
end
function Keyboard:RefreshPhraseManager()
    if not self.phraseRows then return end
    local phrases=remembered().phrases
    for i,row in ipairs(self.phraseRows) do
        local phrase=phrases[i]
        if phrase then row.label=string.sub(phrase,1,48); row.text:SetText(row.label); row.removeButton.phraseIndex=i; row:Show()
        else row:Hide() end
    end
end
function Keyboard:CreatePhraseManager()
    if self.phraseFrame then return self.phraseFrame end
    local frame=CreateFrame("Frame","CEKeyboardPhraseManager",UIParent); frame:SetWidth(430); frame:SetHeight(450); frame:SetPoint("CENTER",UIParent,"CENTER",0,0); frame:SetFrameStrata("FULLSCREEN_DIALOG"); frame:SetFrameLevel(180); frame.ceNavigationModal=true; frame:EnableMouse(true)
    frame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=16,insets={left=5,right=5,top=5,bottom=5}})
    if ConsoleExperience.theme then ConsoleExperience.theme:Register(frame,"panel") end
    frame:SetScript("OnHide",function() if WindrunnerController and WindrunnerController.Release then WindrunnerController:Release() end end)
    local title=frame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); title:SetPoint("TOP",frame,"TOP",0,-18); title:SetText("Saved phrases"); if ConsoleExperience.theme then ConsoleExperience.theme:Register(title,"font") end
    local entry=CreateFrame("EditBox","CEKeyboardPhraseEntry",frame,"InputBoxTemplate"); entry:SetWidth(250); entry:SetHeight(24); entry:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-50); entry:SetAutoFocus(false); entry:SetMaxLetters(96); entry:SetText("")
    local add=CreateFrame("Button","CEKeyboardPhraseAdd",frame,"UIPanelButtonTemplate"); add:SetWidth(100); add:SetHeight(24); add:SetPoint("LEFT",entry,"RIGHT",8,0); add:SetText("Save phrase")
    add:SetScript("OnClick",function() if Keyboard:AddSavedPhrase(entry:GetText() or "") then entry:SetText(""); Keyboard:RefreshPhraseManager() end end)
    if ConsoleExperience.theme then ConsoleExperience.theme:Button(add) end
    self.phraseRows={}
    for i=1,12 do
        local row=CreateFrame("Frame","CEKeyboardPhraseRow"..i,frame); row:SetWidth(390); row:SetHeight(24); row:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-92-(i-1)*24)
        row.text=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); row.text:SetPoint("LEFT",row,"LEFT",0,0); row.text:SetWidth(300); row.text:SetJustifyH("LEFT"); row.label=""
        row.removeButton=CreateFrame("Button","CEKeyboardPhraseRemove"..i,row,"UIPanelButtonTemplate"); row.removeButton:SetWidth(70); row.removeButton:SetHeight(21); row.removeButton:SetPoint("RIGHT",row,"RIGHT",0,0); row.removeButton:SetText("Remove")
        row.removeButton:SetScript("OnClick",function() Keyboard:RemoveSavedPhrase(this.phraseIndex) end)
        if ConsoleExperience.theme then ConsoleExperience.theme:Register(row.text,"font"); ConsoleExperience.theme:Button(row.removeButton) end
        table.insert(self.phraseRows,row)
    end
    local close=CreateFrame("Button","CEKeyboardPhraseClose",frame,"UIPanelButtonTemplate"); close:SetWidth(90); close:SetHeight(24); close:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-18,16); close:SetText("Close"); close:SetScript("OnClick",function() frame:Hide() end)
    if ConsoleExperience.theme then ConsoleExperience.theme:Button(close) end
    UISpecialFrames=UISpecialFrames or {}; table.insert(UISpecialFrames,frame:GetName())
    local hooks=ConsoleExperience.hooks
    if hooks and hooks.HookDynamicFrame then hooks:HookDynamicFrame(frame,"Saved Phrases") end
    self.phraseFrame=frame; self.phraseEntry=entry; self:RefreshPhraseManager(); return frame
end
function Keyboard:ShowPhraseManager()
    local frame=self:CreatePhraseManager(); self:RefreshPhraseManager(); frame:SetScale(math.min(1,(UIParent:GetWidth()-32)/430,(UIParent:GetHeight()-32)/450)); frame:Show()
    if WindrunnerController and WindrunnerController.Release then WindrunnerController:Release() end
end
local function createSuggestionUi(keyboard,frame)
    if keyboard.suggestionButtons or not frame.keyboardBox or not frame.keysContainer then return end
    local strip=CreateFrame("Frame","CEKeyboardSuggestionStrip",frame.keyboardBox); strip:SetPoint("TOPLEFT",frame.keyboardBox,"TOPLEFT",10,-5); strip:SetPoint("TOPRIGHT",frame.keyboardBox,"TOPRIGHT",-10,-5); strip:SetHeight(25); keyboard.suggestionStrip=strip
    keyboard.suggestionButtons={}
    for i=1,3 do
        local button=CreateFrame("Button","CEKeyboardSuggestion"..i,strip,"UIPanelButtonTemplate"); button:SetWidth(150); button:SetHeight(22); button:SetPoint("LEFT",strip,"LEFT",(i-1)*160,0); button:Hide()
        button.text=button:GetFontString(); button.label=""
        if button.text then button.text:SetText("") end
        button.action=function()
            if button.actionKind=="phrase" then keyboard:InsertSavedPhrase(button.suggestion)
            elseif button.suggestion then keyboard:AcceptSuggestion(button.suggestion) end
            keyboard:RefreshSuggestions()
        end
        button:SetScript("OnClick",function() this.action() end)
        button.Click=function(self,mouseButton) if mouseButton=="LeftButton" or not mouseButton then self.action() end end
        if ConsoleExperience.theme then ConsoleExperience.theme:Button(button,button.text) end
        keyboard.suggestionButtons[i]=button
    end
    local phrases=CreateFrame("Button","CEKeyboardShowPhrases",strip,"UIPanelButtonTemplate"); phrases:SetWidth(116); phrases:SetHeight(22); phrases:SetPoint("RIGHT",strip,"RIGHT",0,0); phrases:SetText("Saved phrases…")
    phrases:SetScript("OnClick",function() keyboard:ShowPhraseManager() end); phrases.Click=function() keyboard:ShowPhraseManager() end
    if ConsoleExperience.theme then ConsoleExperience.theme:Button(phrases) end
    keyboard.showPhrasesButton=phrases
    local container=frame.keysContainer
    container:ClearAllPoints(); container:SetPoint("TOPLEFT",frame.keyboardBox,"TOPLEFT",8,-34); container:SetPoint("BOTTOMRIGHT",frame.keyboardBox,"BOTTOMRIGHT",-8,8)
    for _,key in ipairs(keyboard.keys or {}) do if key then key:Hide() end end
    keyboard.keys={}; keyboard:CreateKeys(container)
end
if not Keyboard._suggestionFrameHook then
    local createFrame=Keyboard.CreateFrame
    Keyboard.CreateFrame=function(self)
        local frame=createFrame(self)
        createSuggestionUi(self,frame)
        return frame
    end
    Keyboard._suggestionFrameHook=true
end
if not Keyboard._suggestionInputHook then
    local add=Keyboard.AddChar
    Keyboard.AddChar=function(self,char)
        add(self,char)
        self._suggestionAppendText=self.currentText
        if char==" " and cfg("keyboardRememberWords") and self.isChatInput~=false and not string.find(self.currentText or "","^%s*/") then
            local word=capture(self.currentText or "","([A-Za-z]+)%s+$")
            if word and string.len(word)>=3 then
                local words=remembered().words; local found=false
                for _,saved in ipairs(words) do if string.lower(saved)==string.lower(word) then found=true end end
                if not found then if table.getn(words)>=100 then table.remove(words,1) end; table.insert(words,word) end
            end
        end
        self:RefreshSuggestions()
    end
    local delete=Keyboard.DeleteChar
    Keyboard.DeleteChar=function(self) delete(self); self._suggestionAppendText=self.currentText; self:RefreshSuggestions() end
    local show=Keyboard.Show
    Keyboard.Show=function(self,editBox)
        self._suggestionAppendText=nil
        local result=show(self,editBox)
        local target=editBox or ChatFrameEditBox
        if target and target.GetScript and target.SetScript and not target._windrunnerSuggestionCursorHook then
            local previous=target:GetScript("OnCursorChanged")
            target:SetScript("OnCursorChanged",function()
                Keyboard._suggestionAppendText=nil
                if previous then previous() end
            end)
            target._windrunnerSuggestionCursorHook=true
        end
        self:RefreshSuggestions(); return result
    end
    Keyboard._suggestionInputHook=true
end
if not SlashCmdList.CEPHRASE then
    SLASH_CEPHRASE1="/cephrase"
    SlashCmdList.CEPHRASE=function(message)
        message=message or ""
        local phrase=capture(message,"^%s*add%s+(.+)$")
        if phrase and Keyboard:AddSavedPhrase(phrase) then CE_Print("Saved phrase.")
        else CE_Print("Usage: /cephrase add <short phrase> (up to 96 characters)") end
    end
end
CE_Debug("Keyboard suggestions module loaded")

-- Geometry and scripts for addon-owned frames; does not emulate the game renderer.
local Model={objects={},named={}}
local xFactor={LEFT=0,RIGHT=1,CENTER=0.5}
local function factors(point)
    return string.find(point,"LEFT") and 0 or (string.find(point,"RIGHT") and 1 or 0.5),
        string.find(point,"TOP") and 1 or (string.find(point,"BOTTOM") and 0 or 0.5)
end
function Model:Create(kind,name,parent,template)
    local frame={kind=kind,name=name,parent=parent,children={},regions={},points={},scripts={},shown=true,
        enabled=true,alpha=1,font="FRIZQT__.TTF",fontSize=template and string.find(template,"Small") and 10 or (template and string.find(template,"Large") and 18 or 12)}
    table.insert(self.objects,frame)
    frame.previewId=table.getn(self.objects)
    if name then self.named[name]=frame; getfenv(0)[name]=frame end
    if parent then table.insert((kind=="FontString" or kind=="Texture") and parent.regions or parent.children,frame) end
    function frame:GetName() return self.name end
    function frame:GetParent() return self.parent end
    function frame:GetObjectType() return self.kind end
    function frame:IsObjectType(query) return query==self.kind end
    function frame:GetChildren() return unpack(self.children) end
    function frame:GetRegions() return unpack(self.regions) end
    function frame:GetNumPoints() local n=0; for _ in pairs(self.points) do n=n+1 end; return n end
    function frame:GetPoint(index) local n=0; for point,spec in pairs(self.points) do n=n+1; if n==index then return point,unpack(spec) end end end
    function frame:SetScript(event,fn) self.scripts[event]=fn end
    function frame:GetScript(event) return self.scripts[event] end
    function frame:Show() self.shown=true end
    function frame:Hide() self.shown=false end
    function frame:IsShown() return self.shown end
    function frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function frame:Enable() self.enabled=true end
    function frame:Disable() self.enabled=false end
    function frame:IsEnabled() return self.enabled and 1 or 0 end
    function frame:SetWidth(value) self.width=value end
    function frame:SetHeight(value) self.height=value end
    function frame:SetScale(value) self.scale=value end
    function frame:GetScale() return self.scale or 1 end
    function frame:GetEffectiveScale() return self:GetScale()*(self.parent and self.parent:GetEffectiveScale() or 1) end
    function frame:SetPoint(point,relative,relativePoint,x,y)
        if type(relative)=="number" then x,y,relative,relativePoint=relative,relativePoint,self.parent or UIParent,point end
        self.points[point]={relative or self.parent or UIParent,relativePoint or point,x or 0,y or 0}
    end
    function frame:ClearAllPoints() self.points={} end
    function frame:SetAllPoints(relative)
        self:SetPoint("TOPLEFT",relative or self.parent,"TOPLEFT",0,0)
        self:SetPoint("BOTTOMRIGHT",relative or self.parent,"BOTTOMRIGHT",0,0)
    end
    function frame:GetFont() return self.font,self.fontSize,self.fontFlags or "" end
    function frame:SetFont(file,size,flags) self.font,self.fontSize,self.fontFlags=file,size,flags end
    function frame:SetFontObject() end
    function frame:GetStringWidth() return string.len(self.text or "")*self.fontSize*0.55 end
    function frame:GetStringHeight()
        local width=self.width or self:GetStringWidth()
        local lines=0
        for line in string.gfind((self.text or "").."\n","(.-)\n") do
            lines=lines+math.max(1,math.ceil(string.len(line)*self.fontSize*0.55/math.max(1,width)))
        end
        return math.max(1,lines)*self.fontSize*1.2
    end
    function frame:Rect()
        if self==UIParent then return 0,0,self.width,self.height end
        assert(not self.resolving,"cyclic anchors: "..tostring(self.name))
        self.resolving=true
        local left,right,top,bottom,anchorX,anchorY,ownX,ownY
        for point,spec in pairs(self.points) do
            local fx,fy=factors(point)
            local rx,ry=factors(spec[2])
            local l,b,w,h=spec[1]:Rect()
            local ax,ay=l+w*rx+spec[3],b+h*ry+spec[4]
            if fx==0 then left=ax elseif fx==1 then right=ax end
            if fy==0 then bottom=ay elseif fy==1 then top=ay end
            anchorX,anchorY,ownX,ownY=ax,ay,fx,fy
        end
        local width=left and right and right-left or self.width or (self.kind=="FontString" and self:GetStringWidth()) or 0
        local height=top and bottom and top-bottom or self.height or (self.kind=="FontString" and self:GetStringHeight()) or 0
        left=left or (right and right-width) or (anchorX and anchorX-width*ownX) or 0
        bottom=bottom or (top and top-height) or (anchorY and anchorY-height*ownY) or 0
        self.resolving=false
        return left,bottom,width,height
    end
    function frame:GetLeft() local l=self:Rect(); return l end
    function frame:GetRight() local l,b,w=self:Rect(); return l+w end
    function frame:GetBottom() local l,b=self:Rect(); return b end
    function frame:GetTop() local l,b,w,h=self:Rect(); return b+h end
    function frame:GetWidth() local l,b,w=self:Rect(); return w end
    function frame:GetHeight() local l,b,w,h=self:Rect(); return h end
    function frame:SetBackdrop(spec) self.backdrop=spec end
    function frame:GetBackdrop() return self.backdrop end
    function frame:SetBackdropColor(r,g,b,a) self.background={r,g,b,a or 1} end
    function frame:SetBackdropBorderColor(r,g,b,a) self.border={r,g,b,a or 1} end
    function frame:SetTextColor(r,g,b,a) self.textColor={r,g,b,a or 1} end
    function frame:SetJustifyH(value) self.justify=value end
    function frame:SetJustifyV(value) self.justifyV=value end
    function frame:SetDrawLayer(value) self.drawLayer=value end
    function frame:SetVertexColor(r,g,b,a) self.vertex={r,g,b,a or 1} end
    function frame:SetTexture(...) self.texture=arg end
    function frame:SetAlpha(value) self.alpha=value end
    function frame:SetChecked(value) self.checked=value end
    function frame:GetChecked() return self.checked end
    function frame:SetText(value) self.text=value; if self.fontString then self.fontString:SetText(value) end end
    function frame:GetText() return self.text end
    function frame:GetFontString() return self.fontString end
    function frame:CreateFontString(regionName,layer,regionTemplate) local region=Model:Create("FontString",regionName,self,regionTemplate); region.drawLayer=layer; return region end
    function frame:CreateTexture(regionName,layer) local region=Model:Create("Texture",regionName,self); region.drawLayer=layer; return region end
    function frame:SetScrollChild(child)
        self.scrollChild=child
        child:SetPoint("TOPLEFT",self,"TOPLEFT",0,0)
    end
    for _,method in ipairs({"EnableMouse","EnableKeyboard","SetClampedToScreen","SetMovable","SetFrameStrata","SetFrameLevel",
        "RegisterEvent","SetWordWrap","SetHitRectInsets","SetTexCoord","SetBlendMode",
        "SetNormalTexture","SetPushedTexture","SetHighlightTexture","SetDisabledTexture","SetAutoFocus","RegisterForClicks"}) do frame[method]=function() end end
    if kind=="Button" and template then
        frame.fontString=frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        frame.fontString:SetPoint("CENTER",frame,"CENTER",0,0)
    end
    if kind=="Frame" and template=="UIDropDownMenuTemplate" then
        local button=Model:Create("Button",name.."Button",frame)
        button:SetWidth(24); button:SetHeight(24); button:SetPoint("RIGHT",frame,"RIGHT",0,0)
        button:SetScript("OnClick",function() end)
    end
    if kind~="FontString" and kind~="EditBox" then frame.GetFont=nil; frame.SetFont=nil end
    return frame
end
function Model:Invoke(frame,event,...)
    local prior,priorArg=this,arg1
    this,arg1=frame,unpack(arg)
    if frame.scripts[event] then frame.scripts[event]() end
    this,arg1=prior,priorArg
end
function Model:Tick()
    local objects={}
    for _,frame in ipairs(self.objects) do table.insert(objects,frame) end
    for _,frame in ipairs(objects) do if frame:IsVisible() and frame.scripts.OnUpdate then self:Invoke(frame,"OnUpdate",0.05) end end
end
return Model

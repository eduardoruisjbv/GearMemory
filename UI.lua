local _, GM = ...
local L=GM.L
local backdrop={bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1}
local function text(parent, size, x, y, width)
    local font=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    font:SetPoint("TOPLEFT",x,y);font:SetWidth(width);font:SetJustifyH("LEFT")
    font:SetFontObject(size=="small" and GameFontHighlightSmall or GameFontHighlight)
    return font
end
local function tooltip(owner,title,body)
    GameTooltip:SetOwner(owner,"ANCHOR_RIGHT");GameTooltip:SetText(title,0.25,0.79,0.73)
    GameTooltip:AddLine(body,0.9,0.9,0.9,true);GameTooltip:Show()
end
local function button(parent,label,x,y,width,callback)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetPoint("TOPLEFT",x,y);b:SetSize(width,30);b:SetBackdrop(backdrop)
    b:SetBackdropColor(0.10,0.13,0.15,1);b:SetBackdropBorderColor(0.20,0.35,0.36,1)
    b.label=b:CreateFontString(nil,"OVERLAY","GameFontNormal");b.label:SetPoint("CENTER");b.label:SetText(label)
    b.label:SetTextColor(0.25,0.79,0.73)
    b:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(0.25,0.79,0.73,1) end)
    b:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(0.20,0.35,0.36,1);GameTooltip:Hide() end)
    b:SetScript("OnClick",callback)
    return b
end

function GM:PriorityMenu(owner,which)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner,function(_,root)
            root:CreateTitle((which=="first" and L["Prioridade 1"] or L["Prioridade 2"]).." · "..(self.contextNames[self.profile.context] or ""))
            for _,stat in ipairs(self.stats) do
                local value=stat
                root:CreateRadio(self.statNames[value],function() return self.profile[which]==value end,
                    function() self:SetPriority(which,value) end)
            end
        end)
    else
        for index,stat in ipairs(self.stats) do if stat==self.profile[which] then self:SetPriority(which,self.stats[index%#self.stats+1]);break end end
    end
end

StaticPopupDialogs.GEARMEMORY_AUTOMATIC={
    text=L["Ativar equipamento automático no GearMemory para esta especialização?\n\nMelhorias seguras das bolsas serão equipadas fora de combate, conforme seus atributos. Itens com efeitos, conjuntos ou vínculo incerto ficam para revisão."],
    button1=L["Ativar"],button2=L["Cancelar"],timeout=0,whileDead=false,hideOnEscape=true,preferredIndex=3,
    OnAccept=function(_,data)
        if not data or GM.config~=data.config or GM.profile.spec~=data.spec then return end
        GM.config.automatic=true;GM.config.consent=1;GM.blocked={};GM:ScheduleScan();GM:RefreshUI()
    end,
    OnCancel=function() GM:RefreshUI() end,
}

function GM:CreateUI()
    if self.ui then return end
    local f=CreateFrame("Frame","GearMemoryWindow",UIParent,"BackdropTemplate")
    f:SetSize(760,660);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:SetClampedToScreen(true)
    f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",f.StartMoving);f:SetScript("OnDragStop",f.StopMovingOrSizing)
    f:SetBackdrop(backdrop);f:SetBackdropColor(0.055,0.065,0.075,0.98);f:SetBackdropBorderColor(0.20,0.35,0.36,1)
    local title=text(f,"normal",20,-18,640);title:SetText("|cff40c9bbGearMemory|r  |cff90999d"..self.version.."|r")
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-6,-6)
    close:SetScript("OnClick",function() f:Hide() end)
    table.insert(UISpecialFrames,"GearMemoryWindow")
    f.profile=text(f,"normal",20,-52,710)
    f.primary=text(f,"normal",20,-82,710);f.primary:SetTextColor(0.92,0.75,0.37)
    f.first=button(f,"",20,-117,300,function(b) self:PriorityMenu(b,"first") end)
    f.second=button(f,"",335,-117,300,function(b) self:PriorityMenu(b,"second") end)
    f.rule=text(f,"small",20,-156,710)
    f.rule:SetText(L["Principal decide primeiro; com o mesmo principal, +5 de ilvl vence. Secundários: ×3, ×2, ×1. PvP compara o ilvl PvP."])
    f.context=button(f,"",20,-184,245,function()
        self:StopEquipment()
        local values={auto="raid",raid="dungeon",dungeon="world",world="pvp",pvp="auto"}
        self.config.context=values[self.config.context] or "auto";self.blocked={};self:ScheduleScan(nil,true)
    end)
    f.automatic=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate")
    f.automatic:SetPoint("TOPLEFT",285,-182);f.automatic:SetSize(30,30)
    f.automatic.label=text(f,"small",318,-191,400);f.automatic.label:SetText(L["Equipar automaticamente (fora de combate)"])
    f.automatic:SetScript("OnClick",function(b)
        if self.config.automatic then self.config.automatic=false;self:StopEquipment();self:RefreshUI()
        else
            b:SetChecked(false)
            StaticPopup_Show("GEARMEMORY_AUTOMATIC",nil,nil,{config=self.config,spec=self.profile.spec})
        end
    end)
    f.suggestions=button(f,L["Melhorias"],20,-228,140,function() self.view="suggestions";self:RefreshUI() end)
    f.explainButton=button(f,L["Explicar"],410,-228,110,function() self:PrintExplain() end)
    f.categories=button(f,L["Melhores por categoria"],175,-228,220,function() self.view="categories";self:RefreshUI() end)
    f.status=text(f,"small",20,-271,710)
    local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",20,-298);scroll:SetPoint("BOTTOMRIGHT",-42,79)
    local content=CreateFrame("Frame",nil,scroll)
    content:SetWidth(692);content:SetHeight(1);scroll:SetScrollChild(content)
    f.content=content;f.rows={};f.scroll=scroll
    f.empty=text(content,"normal",10,-16,660)
    f.equip=button(f,L["Equipar melhorias"],20,-599,200,function() self:EquipImprovements() end)
    f.refresh=button(f,L["Atualizar"],235,-599,120,function() self:Scan() end)
    f.stop=button(f,L["Parar"],370,-599,90,function() self.config.automatic=false;self:StopEquipment();self:RefreshUI() end)
    f.footer=text(f,"small",20,-638,710)
    f.footer:SetText(L["|cffeac064Revisar|r: efeitos, conjuntos e escala PvP. Comparação de atributos; não simula DPS."])
    self.ui=f;self.view="suggestions";f:Hide()
end

function GM:BuildRows()
    if self.view~="categories" then return self.suggestions or {} end
    local rows={}
    local keys={};for key in pairs(self.categoryBest or {}) do keys[#keys+1]=key end;table.sort(keys)
    for _,key in ipairs(keys) do
        local category=self.categoryBest[key]
        for _,item in ipairs(category.contexts[self.profile.context=="pvp" and "pvp" or "pve"] or {}) do
            local target=item.inventorySlot
            if not target then
                local loc=category.label
                local lookup={INVTYPE_HEAD=1,INVTYPE_NECK=2,INVTYPE_SHOULDER=3,INVTYPE_CHEST=5,INVTYPE_WAIST=6,
                    INVTYPE_LEGS=7,INVTYPE_FEET=8,INVTYPE_WRIST=9,INVTYPE_HAND=10,INVTYPE_FINGER=11,
                    INVTYPE_TRINKET=13,INVTYPE_CLOAK=15,INVTYPE_SHIELD=17,INVTYPE_HOLDABLE=17,INVTYPE_WEAPONOFFHAND=17}
                target=lookup[loc] or 16
            end
            rows[#rows+1]={item=item,target=target,category=true,reason=self:ReviewReason(item,nil)}
        end
    end
    table.sort(rows,function(a,b) if a.target~=b.target then return a.target<b.target end return self:ItemKey(a.item)<self:ItemKey(b.item) end)
    return rows
end

function GM:RefreshUI()
    local f=self.ui
    if not f or not f:IsShown() or not self.config then return end
    local p=self.profile
    f.profile:SetText((p.name or L["Escolha uma especialização"]).."  ·  "..(self.contextNames[p.context] or p.context))
    f.primary:SetText(L["Atributo principal: "]..(self.primaryNames[p.primary] or L["aguardando especialização"])..L["  ·  automático e sempre acima dos secundários"])
    f.first.label:SetText(L["Prioridade 1: "]..self.statNames[p.first].."  ▾")
    f.second.label:SetText(L["Prioridade 2: "]..self.statNames[p.second].."  ▾")
    f.context.label:SetText(L["Perfil: "]..(self.config.context=="auto" and "Auto · " or "")..(self.contextNames[p.context] or p.context).."  ▾")
    f.automatic:SetChecked(self.config.automatic==true)
    local count=#(self.ready or {})
    local state=self.work and L["Equipando…"] or InCombatLockdown() and L["Em combate; atualização ao sair."] or self.wornIncomplete and L["Aguardando dados dos itens."] or count..L[" melhoria(s) segura(s) nas bolsas."]
    if self.view=="categories" then
        state=p.context=="pvp" and L["Categorias PvP: ranking de atributos-base; revise efeitos e escala PvP."] or L["Melhores candidatos de cada tipo de item por atributos."]
    end
    if #(self.excess or {})>0 then
        local names={};for _,stat in ipairs(self.excess) do names[#names+1]=self.statNames[stat] end
        state=state..L[" Acima da faixa de retornos decrescentes: "]..table.concat(names,", ").."."
    end
    if self.db.bank then state=state..L[" Banco: última visita "]..date("%d/%m %H:%M",self.db.bank.time).."." end
    f.status:SetText(state)
    f.suggestions.label:SetTextColor(self.view=="suggestions" and 0.25 or 0.65,0.79,0.73)
    f.categories.label:SetTextColor(self.view=="categories" and 0.25 or 0.65,0.79,0.73)
    local rows=self:BuildRows()
    f.empty:SetShown(#rows==0)
    f.empty:SetText(self.wornIncomplete and L["Aguardando os dados dos itens…"] or L["Nenhuma melhoria disponível para suas prioridades."])
    for index,entry in ipairs(rows) do
        local row=f.rows[index]
        if not row then
            row=CreateFrame("Button",nil,f.content,"BackdropTemplate")
            row:SetSize(690,96);row:SetBackdrop(backdrop);row:SetBackdropColor(0.085,0.10,0.115,1);row:SetBackdropBorderColor(0.13,0.17,0.19,1)
            row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(34,34);row.icon:SetPoint("TOPLEFT",10,-12)
            row.name=text(row,"normal",54,-11,625)
            row.detail=text(row,"small",54,-34,625)
            row.state=text(row,"small",54,-55,460)
            row.explain=text(row,"small",54,-76,625);row.explain:SetTextColor(0.62,0.7,0.72)
            row.bind=button(row,L["Equipar (vincula)"],520,-50,150,function() if row.entry then GM:EquipConfirmed(row.entry) end end)
            row:SetScript("OnEnter",function(b)
                local s=b.entry
                if not s then return end
                GameTooltip:SetOwner(b,"ANCHOR_RIGHT");GameTooltip:SetHyperlink(s.item.link)
                GameTooltip:AddLine(" ")
                if s.old then GameTooltip:AddLine(L["Equipado: "]..s.old.name,0.7,0.7,0.7,true);GameTooltip:AddLine(GM:ScoreText(s.old),0.7,0.7,0.7,true) end
                if s.explain and s.explain~="" then GameTooltip:AddLine(L["Por quê: "]..s.explain,0.62,0.7,0.72,true) end
                GameTooltip:AddLine(s.reason or L["Melhoria segura segundo suas prioridades."],s.reason and 0.92 or 0.25,s.reason and 0.75 or 0.79,s.reason and 0.37 or 0.73,true)
                GameTooltip:AddLine(L["Principal primeiro; com o mesmo principal, +5 de ilvl vence; depois secundários. Em PvP vale o ilvl PvP. Efeitos não são simulados."],0.8,0.8,0.8,true)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave",function() GameTooltip:Hide() end)
            row:SetScript("OnClick",function(b)
                if IsShiftKeyDown() and b.entry then ChatEdit_InsertLink(b.entry.item.link) end
            end)
            f.rows[index]=row
        end
        row.entry=entry;row:SetPoint("TOPLEFT",0,-(index-1)*102);row:Show()
        row.icon:SetTexture(entry.item.icon)
        row.name:SetText((self.slotNames[entry.target] or L["Equipamento"]).." · "..entry.item.link)
        row.detail:SetText(self:ScoreText(entry.item))
        local storage=entry.item.storage=="bag" and L["Bolsas"] or entry.item.storage=="bank" and L["Banco"] or L["Equipado"]
        local status=entry.category and L["Melhor da categoria"] or entry.bindOnly and L["Confirmar vínculo"] or entry.reason and L["Revisar"] or L["Melhoria segura"]
        row.state:SetText((entry.reason and "|cffeac064" or "|cff40c9bb")..status.."|r · "..storage..(entry.reason and " · "..entry.reason or ""))
        row.explain:SetText(entry.explain or "")
        row.bind:SetShown(entry.bindOnly==true and not self.work)
    end
    for index=#rows+1,#f.rows do f.rows[index]:Hide() end
    f.content:SetHeight(math.max(1,#rows*102))
    f.equip:SetEnabled(count>0 and self:CanEquipNow() and not self.work)
    f.equip.label:SetTextColor(count>0 and 0.25 or 0.5,count>0 and 0.79 or 0.5,count>0 and 0.73 or 0.5)
end

-- Brief on-screen notice (like the "Release Spirit" banner): shows, holds ~3s, fades.
function GM:Toast(title, detail)
    if self.db and self.db.toast==false then return end
    local f=self.toast
    if not f then
        f=CreateFrame("Frame","GearMemoryToast",UIParent)
        f:SetSize(520,60);f:SetPoint("TOP",UIParent,"TOP",0,-170);f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:EnableMouse(false);f:Hide()
        f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        f.title:SetPoint("TOP",0,0);f.title:SetTextColor(0.25,0.79,0.73)
        f.detail=f:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        f.detail:SetPoint("TOP",f.title,"BOTTOM",0,-6)
        self.toast=f
    end
    f.title:SetText(title or "")
    f.detail:SetText(detail or "")
    f.token=(f.token or 0)+1
    local token=f.token
    f:SetAlpha(1);f:Show()
    C_Timer.After(2.6,function()
        if f.token~=token then return end
        if UIFrameFadeOut then UIFrameFadeOut(f,0.7,1,0) end
        C_Timer.After(0.75,function() if f.token==token then f:Hide() end end)
    end)
end

function GM:PrintExplain()
    if not self.plan then self:Scan() end
    if not self.plan then return end
    self:Print(L["Perfil "]..(self.contextNames[self.profile.context] or "?")..": "..self.statNames[self.profile.first].." > "..self.statNames[self.profile.second]..".")
    for slot=1,17 do
        local worn,planned=self.worn[slot],self.plan[slot]
        if self.slotNames[slot] and (worn or planned) then
            local head=self.slotNames[slot]..": "
            if planned and not self:Same(planned,worn) then
                local reason=nil
                for _,s in ipairs(self.suggestions) do if s.target==slot and self:Same(s.item,planned) then reason=s end end
                self:Print(head..(worn and worn.link or L["vazio"]).." → "..planned.link.." ["..(reason and reason.explain or "")
                    ..(reason and reason.reason and (" | "..reason.reason) or "").."]")
            elseif worn then
                self:Print(head..worn.link..L[" mantido ("]..self:ScoreText(worn)..")")
            end
        end
    end
end

function GM:ToggleUI()
    self:CreateUI()
    if self.ui:IsShown() then self.ui:Hide()
    else self.ui:Show();self:Scan();self:RefreshUI() end
end

function GM:CreateLauncher()
    if self.launcher or not Minimap then return end
    local b=CreateFrame("Button","GearMemoryMinimapButton",Minimap)
    b:SetSize(30,30);b:SetPoint("TOPLEFT",Minimap,"TOPLEFT",-7,-7)
    b:SetFrameStrata("MEDIUM");b:SetFrameLevel(Minimap:GetFrameLevel()+10)
    local function circle(texture,size)
        texture:ClearAllPoints();texture:SetSize(size,size);texture:SetPoint("CENTER")
        local mask=b:CreateMaskTexture()
        mask:SetTexture(3528314,"CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
        mask:SetSize(size,size);mask:SetPoint("CENTER");texture:AddMaskTexture(mask)
    end
    local rim=b:CreateTexture(nil,"BACKGROUND",nil,0)
    rim:SetColorTexture(0.62,0.51,0.30,1);circle(rim,28)
    local background=b:CreateTexture(nil,"BACKGROUND",nil,1)
    background:SetColorTexture(0.06,0.07,0.075,1);circle(background,26)
    b:SetNormalTexture(135291)
    local icon=b:GetNormalTexture()
    icon:SetTexCoord(0.07,0.93,0.07,0.93);circle(icon,23)
    b:SetHighlightTexture(136477)
    b:SetScript("OnClick",function() self:ToggleUI() end)
    b:SetScript("OnEnter",function(owner) tooltip(owner,"GearMemory",L["Equipamento e prioridades de atributos.\nClique para abrir. /gm também abre o menu."]) end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    self.launcher=b
end

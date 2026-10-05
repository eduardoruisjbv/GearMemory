local _, GM = ...
local L=GM.L

function GM:CanEquipNow()
    if not self.config or InCombatLockdown() or GetCursorInfo() or UnitIsDeadOrGhost("player") then return false end
    if SpellCanTargetItem and SpellCanTargetItem() then return false end
    for _,active in pairs(self.services) do if active then return false end end
    for _,name in ipairs({"MerchantFrame","BankFrame","AuctionHouseFrame","TradeFrame","QuestFrame"}) do
        if _G[name] and _G[name]:IsShown() then return false end
    end
    local bm=_G.BagMemory
    if bm and (bm.selling or bm.bankWork or bm.questWork) then return false end
    return true
end

function GM:StopEquipment()
    self.generation=(self.generation or 0)+1
    self.work=nil;self.manual=nil
end

function GM:EquipImprovements()
    self:StopEquipment()
    self.blocked={}
    self.manual=true
    if not self:StartEquipment(false) then
        self.manual=nil
        self:Print(L["Sem melhoria segura nas bolsas agora. Feche serviços, saia de combate e confira os itens marcados Revisar."])
    end
end

-- One click on a bind-on-equip suggestion. WoW then shows its own binding
-- confirmation, which only the player can accept.
function GM:EquipConfirmed(entry)
    self:StopEquipment()
    self.blocked={}
    if not self:StartEquipment(false,entry) then
        self:Print(L["Não foi possível equipar agora. Feche serviços, saia de combate e tente de novo."])
    end
end

function GM:StartEquipment(automatic, forced)
    if automatic and not self.bagsOpen then return false end
    if self.work or not self:CanEquipNow() or automatic and (not self.config.automatic or self.manual) then return false end
    self:Scan(true)
    self.blocked=self.blocked or {}
    local nextItem
    if forced then
        -- Only a suggestion that is blocked by nothing but its binding, and never a weapon pair.
        for _,suggestion in ipairs(self.suggestions or {}) do
            if suggestion.bindOnly and self:Same(suggestion.item,forced.item) and suggestion.target==forced.target
                and suggestion.target~=16 and suggestion.target~=17
                and self:UniqueAllowed(suggestion.item,self.worn,suggestion.target) then nextItem=suggestion;break end
        end
    else
        for _,suggestion in ipairs(self.ready or {}) do
            local key=self:ItemKey(suggestion.item)
            if not self.blocked[key] and self:UniqueAllowed(suggestion.item,self.worn,suggestion.target) then nextItem=suggestion;break end
        end
    end
    if not nextItem then self.manual=nil;return false end
    local item=nextItem.item
    local container=self:Call(C_Container.GetContainerItemInfo,item.bag,item.slot)
    local guid=self:Call(C_Item.GetItemGUID,item.location)
    if not container or container.isLocked or container.hyperlink~=item.link or not item.guid or guid~=item.guid then return false end
    if not self:UniqueAllowed(item,self.worn,nextItem.target) then return false end
    if nextItem.target==16 or nextItem.target==17 then
        local free=0
        for bag=0,NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5 do
            local count,family=self:Call(C_Container.GetContainerNumFreeSlots,bag)
            if family==0 then free=free+(count or 0) end
        end
        if free<1 then self:Print(L["Abra um espaço nas bolsas antes de trocar as armas."]);self.manual=nil;return false end
    end
    local state={item=item,target=nextItem.target,generation=self.generation or 0,automatic=automatic,started=GetTime(),
        timeout=forced and 20 or 2}
    self.work=state
    -- Native API only. We never dismiss bind/refund confirmations, inject input,
    -- clear the user's cursor, or rely on an optimistic return value as success.
    local ok=type(C_Item.EquipItemByName)=="function" and pcall(C_Item.EquipItemByName,item.link,state.target)
    local function acknowledge()
        if self.work~=state or state.generation~=(self.generation or 0) then return end
        if not self:CanEquipNow() or state.automatic and not self.config.automatic then self:StopEquipment();self:RefreshUI();return end
        local location=ItemLocation:CreateFromEquipmentSlot(state.target)
        if self:Call(C_Item.GetItemGUID,location)==item.guid then
            self.work=nil
            self:Print(L["Equipado: "]..item.link)
            self:Toast(L["Equipamento trocado · "]..(self.contextNames[self.profile.context] or ""),
                (self.slotNames[state.target] or "").." · "..item.link)
            local manual=self.manual
            self:Scan(true)
            if manual or self.config.automatic then
                C_Timer.After(0.3,function()
                    if state.generation~=(self.generation or 0) or self.work then return end
                    if manual and self.manual then self:StartEquipment(false)
                    elseif self.config.automatic then self:StartEquipment(true) end
                end)
            end
        elseif ok and GetTime()-state.started<state.timeout then C_Timer.After(0.15,acknowledge)
        else
            self.blocked[self:ItemKey(item)]=true
            self.work=nil;self.manual=nil
            self:Print(L["O WoW não confirmou a troca. Item preservado; confira a janela nativa ou equipe manualmente."])
            self:ScheduleScan()
        end
    end
    C_Timer.After(0.2,acknowledge)
    self:RefreshUI()
    return true
end

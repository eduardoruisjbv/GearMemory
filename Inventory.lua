local _, GM = ...
local ignored={INVTYPE_BAG=true,INVTYPE_TABARD=true,INVTYPE_BODY=true,
    INVTYPE_PROFESSION_TOOL=true,INVTYPE_PROFESSION_GEAR=true}
local function clean(text)
    if issecretvalue and issecretvalue(text) then return nil end
    return type(text)=="string" and text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("|n"," ") or ""
end
local function pattern(text)
    text=clean(text)
    if not text then return end
    text=text:gsub("%%1%$d","@@LEVEL@@"):gsub("%%d","@@LEVEL@@")
    if not text:find("@@LEVEL@@",1,true) then return end
    return text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1"):gsub("@@LEVEL@@","(%%d+)")
end
-- Turn a localized format string ("%s %d/%d") into a Lua pattern with captures.
local function formatPattern(format)
    format=clean(format)
    if not format or format=="" then return end
    format=format:gsub("%%%d?%$?s","\1"):gsub("%%%d?%$?d","\2")
    format=format:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1")
    return (format:gsub("\1","(.-)"):gsub("\2","(%%d+)"))
end
-- Localized stat names, used to read the numbers gems and enchants add.
local statLabels
local function labels()
    if statLabels then return statLabels end
    statLabels={}
    local keys={"ITEM_MOD_STRENGTH_SHORT","ITEM_MOD_AGILITY_SHORT","ITEM_MOD_INTELLECT_SHORT"}
    for _,key in pairs(GM.statKeys) do keys[#keys+1]=key end
    for key in pairs(GM.rules.tertiaryWeights) do keys[#keys+1]=key end
    for _,key in ipairs(keys) do
        local text=clean(_G[key])
        if text and text~="" then statLabels[#statLabels+1]={key=key,text=text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1")} end
    end
    return statLabels
end
local function addBonus(item,text)
    for _,entry in ipairs(labels()) do
        local amount=text:match("(%d[%d%.,]*)%s+"..entry.text)
        amount=amount and tonumber((amount:gsub("[%.,]","")))
        if amount then
            item.bonusStats=item.bonusStats or {}
            item.bonusStats[entry.key]=(item.bonusStats[entry.key] or 0)+amount
        end
    end
end
local function label(text)
    text=clean(text)
    return text and (text:match("^(.-)%%") or text) or ""
end

function GM:ReadTooltip(item)
    local data
    if item.bag then data=self:Call(C_TooltipInfo.GetBagItem,item.bag,item.slot)
    else data=self:Call(C_TooltipInfo.GetInventoryItem,"player",item.inventorySlot) end
    if not data or type(data.lines)~="table" or #data.lines==0 then item.incomplete=true;return end
    local pvpPattern=pattern(PVP_ITEM_LEVEL_TOOLTIP)
    local upgradePattern=formatPattern(ITEM_UPGRADE_TOOLTIP_FORMAT_STRING)
    local types=Enum and Enum.TooltipDataLineType or {}
    for _,line in ipairs(data.lines) do
        if issecretvalue and issecretvalue(line.type) then item.incomplete=true;return end
        if types.ItemSpell and line.type==types.ItemSpell then item.effect=true end
        local bonusLine=types.GemSocket and line.type==types.GemSocket or types.ItemEnchantment and line.type==types.ItemEnchantment
        for _,field in ipairs({"leftText","rightText"}) do
            local text=clean(line[field])
            if not text then item.incomplete=true;return end
            if bonusLine and field=="leftText" then addBonus(item,text) end
            local track,current,maximum=text:match(upgradePattern or "^$")
            if track and tonumber(current) and tonumber(maximum) then
                item.upgradeTrack,item.upgradeCur,item.upgradeMax=track,tonumber(current),tonumber(maximum)
            end
            local level=pvpPattern and tonumber(text:match(pvpPattern))
            if level then item.pvpLevel=level;item.pvp=true end
            local lower=text:lower()
            if lower:find("pvp",1,true) or lower:find("jogador contra jogador",1,true)
                or lower:find("campos de batalha",1,true) or lower:find("battleground",1,true) then item.pvp=true end
            for _,global in ipairs({"ITEM_SPELL_TRIGGER_ONEQUIP","ITEM_SPELL_TRIGGER_ONUSE"}) do
                local prefix=label(_G[global])
                if prefix~="" and text:find(prefix,1,true) then item.effect=true end
            end
            for _,global in ipairs({"ITEM_STARTS_QUEST","ITEM_BIND_QUEST","ITEM_BIND_TO_BNETACCOUNT",
                "ITEM_ACCOUNTBOUND","ITEM_BNETACCOUNTBOUND","ITEM_ACCOUNTBOUND_UNTIL_EQUIP",
                "ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIP","BIND_TRADE_TIME_REMAINING"}) do
                local prefix=label(_G[global])
                if prefix~="" and text:find(prefix,1,true) then item.bindingReview=true end
            end
            -- Only the active primary stat is used. Inactive adaptive alternatives
            -- are ignored; a grey primary line matching this spec needs review.
            local statLabel=GM.primaryNames[self.profile.primary]
            local localized=({[1]=ITEM_MOD_STRENGTH_SHORT,[2]=ITEM_MOD_AGILITY_SHORT,[4]=ITEM_MOD_INTELLECT_SHORT})[self.profile.primary]
            if localized and text:find(localized,1,true) and text:find("%d") then
                local color=line.leftColor
                if color then
                    local r,g,b=self:Call(color.GetRGB,color)
                    if r and math.abs(r-g)<0.05 and math.abs(g-b)<0.05 and r<0.65 then item.primaryInactive=true end
                end
            end
        end
    end
    if item.pvp and not item.pvpLevel then item.pvpUnknown=true end
end

function GM:ReadItem(link, storage, bag, slot, inventorySlot, container)
    local item={link=link, storage=storage, bag=bag, slot=slot, inventorySlot=inventorySlot}
    local info={self:Call(C_Item.GetItemInfo,link)}
    item.id=container and container.itemID or self:Call(C_Item.GetItemInfoInstant,link)
    if not info[1] then
        item.incomplete=true
        if item.id then self.waiting[item.id]=true;self:Call(C_Item.RequestLoadItemDataByID,item.id) end
        return item
    end
    item.name,item.link,item.quality=info[1],info[2],info[3]
    item.minLevel,item.equipLoc,item.icon=info[5],info[9],info[10]
    item.class,item.subclass,item.bindType,item.setID=info[12],info[13],info[14],info[16]
    item.gear=(item.class==2 or item.class==4) and item.equipLoc~="" and not ignored[item.equipLoc]
    if not item.gear then return item end
    item.location=bag and ItemLocation:CreateFromBagAndSlot(bag,slot) or ItemLocation:CreateFromEquipmentSlot(inventorySlot)
    item.guid=self:Call(C_Item.GetItemGUID,item.location)
    item.locked=container and container.isLocked
    item.level=self:Call(C_Item.GetCurrentItemLevel,item.location) or self:Call(C_Item.GetDetailedItemLevelInfo,item.link)
    item.bound=self:Call(C_Item.IsBound,item.location)
    item.refundable=self:Call(C_Item.CanBeRefunded,item.location)
    item.account=self:Call(C_Item.IsBoundToAccountUntilEquip,item.location)
    item.stats=self:Call(C_Item.GetItemStats,item.link)
    for key,value in pairs(item.stats or {}) do
        if type(key)=="string" and key:find("^EMPTY_SOCKET_") and type(value)=="number" then
            item.emptySockets=(item.emptySockets or 0)+value
        end
    end
    item.specs=self:Call(C_Item.GetItemSpecInfo,item.link)
    item.uniqueCategory,item.uniqueMax=self:Call(C_Item.GetItemUniqueness,item.link)
    item.unique=self:Call(C_Item.GetItemUniquenessByID,item.link)
    item.equippable=self:Call(C_Item.IsEquippableItem,item.link)
    local _,spell=self:Call(C_Item.GetItemSpell,item.link)
    item.effect=spell~=nil
    if bag then
        local quest=self:Call(C_Container.GetContainerItemQuestInfo,bag,slot)
        item.quest=type(quest)~="table" or quest.isQuestItem or quest.questID~=nil
    end
    if type(item.stats)~="table" or type(item.specs)~="table" or not item.level then item.incomplete=true end
    for _,value in pairs(item.stats or {}) do
        if issecretvalue and issecretvalue(value) then item.incomplete=true;item.stats={};break end
    end
    self:ReadTooltip(item)
    return item
end

function GM:ReadBank()
    local result={}
    if not self.services.bank then
        for _,stored in ipairs(self.db.bank and self.db.bank.items or {}) do
            local item={}
            for key,value in pairs(stored) do item[key]=value end
            item.snapshot=true;result[#result+1]=item
        end
        return result
    end
    local types=self:Call(C_Bank and C_Bank.FetchViewableBankTypes)
    local readable=type(types)=="table"
    for _,bankType in ipairs(types or {}) do
        local tabs=self:Call(C_Bank.FetchPurchasedBankTabIDs,bankType)
        if type(tabs)~="table" then readable=false end
        for _,bag in ipairs(tabs or {}) do
            local count=self:Call(C_Container.GetContainerNumSlots,bag)
            if not count then readable=false end
            for slot=1,count or 0 do
                local container=self:Call(C_Container.GetContainerItemInfo,bag,slot)
                if container then
                    local item=self:ReadItem(container.hyperlink or container.itemID,"bank",bag,slot,nil,container)
                    if item.gear then result[#result+1]=item end
                    if item.incomplete then readable=false end
                end
            end
        end
    end
    if readable then
        local items={}
        for _,item in ipairs(result) do
            local saved={}
            for key,value in pairs(item) do
                if key~="location" and key~="bag" and key~="slot" and type(value)~="userdata" then saved[key]=value end
            end
            items[#items+1]=saved
        end
        self.db.bank={items=items,time=time(),spec=self.profile.spec}
    end
    return result
end

function GM:Scan(skipAutomatic)
    if not self.db or InCombatLockdown() then return end
    self:ReadProfile()
    self.waiting={};self.items={};self.worn={};self.incomplete=false;self.copies={}
    self.setItems={}
    local sets=self:Call(C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs)
    self.setsUnknown=type(sets)~="table"
    for _,set in ipairs(sets or {}) do
        local ids=self:Call(C_EquipmentSet.GetItemIDs,set)
        if type(ids)~="table" then self.setsUnknown=true end
        for _,id in pairs(ids or {}) do if type(id)=="number" and id>0 then self.setItems[id]=true end end
    end
    for slot=1,17 do if self.slotNames[slot] then
        local link=self:Call(GetInventoryItemLink,"player",slot)
        if link then
            local item=self:ReadItem(link,"equipped",nil,nil,slot)
            self.worn[slot]=item;self.items[#self.items+1]=item
            if item.incomplete then self.incomplete=true end
        elseif self:Call(GetInventoryItemID,"player",slot) then self.incomplete=true end
    end end
    for bag=0,NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5 do
        for slot=1,C_Container.GetContainerNumSlots(bag) do
            local container=self:Call(C_Container.GetContainerItemInfo,bag,slot)
            if container then
                local item=self:ReadItem(container.hyperlink or container.itemID,"bag",bag,slot,nil,container)
                if item.gear then
                    self.items[#self.items+1]=item
                    self.copies[item.link]=(self.copies[item.link] or 0)+1
                end
                if item.incomplete then self.incomplete=true end
            end
        end
    end
    for _,item in ipairs(self:ReadBank()) do self.items[#self.items+1]=item end
    self:Evaluate()
    self:RefreshUI()
    local available=false
    for _,suggestion in ipairs(self.ready or {}) do
        if not (self.blocked or {})[self:ItemKey(suggestion.item)] and self:UniqueAllowed(suggestion.item,self.worn,suggestion.target) then available=true;break end
    end
    if not skipAutomatic and available and self:CanEquipNow() and not self.manual and not self.work
        and self.config.automatic and not self.autoPending then
        self.autoPending=true
        C_Timer.After(0.5,function()
            self.autoPending=false
            if self.config.automatic then self:StartEquipment(true) end
        end)
    end
end

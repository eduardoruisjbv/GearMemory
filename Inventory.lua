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
    if not data or type(data.lines)~="table" or #data.lines==0 then item.incomplete=true;item.why="tooltip vazio";return end
    local pvpPattern=pattern(PVP_ITEM_LEVEL_TOOLTIP)
    local upgradePattern=formatPattern(ITEM_UPGRADE_TOOLTIP_FORMAT_STRING)
    local types=Enum and Enum.TooltipDataLineType or {}
    for _,line in ipairs(data.lines) do
        if issecretvalue and issecretvalue(line.type) then item.incomplete=true;item.why="tooltip secreto";return end
        if types.ItemSpell and line.type==types.ItemSpell then item.effect=true end
        local bonusLine=types.GemSocket and line.type==types.GemSocket or types.ItemEnchantment and line.type==types.ItemEnchantment
        for _,field in ipairs({"leftText","rightText"}) do
            local text=clean(line[field])
            if not text then item.incomplete=true;item.why="texto do tooltip secreto";return end
            if bonusLine and field=="leftText" then addBonus(item,text) end
            if field=="leftText" and not bonusLine then
                local r,g,b
                if line.leftColor then r,g,b=self:Call(line.leftColor.GetRGB,line.leftColor) end
                local inactive=r and math.abs(r-g)<0.05 and math.abs(g-b)<0.05 and r<0.65
                if not inactive then
                    for _,entry in ipairs(labels()) do
                        local amount=text:match("^%s*%+?(%d[%d%.,]*)%s+"..entry.text.."%s*$")
                        amount=amount and tonumber((amount:gsub("[%.,]","")))
                        if amount then
                            item.stats=item.stats or {}
                            item.stats[entry.key]=math.max(item.stats[entry.key] or 0,amount)
                        end
                    end
                end
            end
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
                "ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIP"}) do
                local prefix=label(_G[global])
                if prefix~="" and text:find(prefix,1,true) then item.bindingReview=true end
            end
            -- Only the active primary stat is used. Inactive adaptive alternatives
            -- are ignored; a grey primary line matching this spec needs review.
            local statLabel=GM.primaryNames[self.profile.primary]
            local localized=({[1]=ITEM_MOD_STRENGTH_SHORT,[2]=ITEM_MOD_AGILITY_SHORT,[4]=ITEM_MOD_INTELLECT_SHORT})[self.profile.primary]
            if field=="leftText" and localized and text:find(localized,1,true) and text:find("%d") then
                local color=line.leftColor
                if color then
                    local r,g,b=self:Call(color.GetRGB,color)
                    if r and math.abs(r-g)<0.05 and math.abs(g-b)<0.05 and r<0.65 then item.primaryInactive=true end
                end
            end
        end
    end
    if self.profile.leveling and item.quality and item.quality<=2 and item.stats==nil then
        -- A fully read starter tooltip may genuinely contain no attribute lines.
        item.stats={}
    end
    if item.pvp and not item.pvpLevel then item.pvpUnknown=true end
end

function GM:ReadItem(link, storage, bag, slot, inventorySlot, container)
    local item={link=link, storage=storage, bag=bag, slot=slot, inventorySlot=inventorySlot}
    item.quality=container and container.quality
        or inventorySlot and self:Call(GetInventoryItemQuality,"player",inventorySlot)
    local info={self:CachedItemCall(C_Item.GetItemInfo,link)}
    item.id=container and container.itemID or self:Call(C_Item.GetItemInfoInstant,link)
    if not info[1] then
        item.incomplete=true;item.why="GetItemInfo ainda não carregou"
        if item.id then self.waiting[item.id]=true;self:Call(C_Item.RequestLoadItemDataByID,item.id) end
        return item
    end
    item.name,item.link,item.quality=info[1],info[2],info[3]
    item.minLevel,item.equipLoc,item.icon=info[5],info[9],info[10]
    item.sellPrice=info[11]
    item.class,item.subclass,item.bindType,item.setID=info[12],info[13],info[14],info[16]
    item.gear=(item.class==2 or item.class==4) and item.equipLoc~="" and not ignored[item.equipLoc]
    if not item.gear then return item end
    item.location=bag and ItemLocation:CreateFromBagAndSlot(bag,slot) or ItemLocation:CreateFromEquipmentSlot(inventorySlot)
    item.guid=self:Call(C_Item.GetItemGUID,item.location)
    item.locked=container and container.isLocked
    local cache=_G.MemoryItemCache
    local saved=self.db.equipmentCache
    local previous=inventorySlot and saved and saved.slots[inventorySlot]
    local confirmed=previous and item.guid and previous.guid==item.guid and previous.link==item.link
        and saved.session==cache.session and saved.scope==cache.Scope()
        and saved.generation==(cache.generation or 0)
    item.level=confirmed and previous.ilvl or self:CachedItemLevel(item.location,item.link,item.guid)
        or self:CachedItemCall(C_Item.GetDetailedItemLevelInfo,item.link) or info[4]
    item.bound=self:Call(C_Item.IsBound,item.location)
    item.refundable=self:Call(C_Item.CanBeRefunded,item.location)
    item.account=self:Call(C_Item.IsBoundToAccountUntilEquip,item.location)
    item.stats=self:CachedItemCall(C_Item.GetItemStats,item.link)
    for key,value in pairs(item.stats or {}) do
        if type(key)=="string" and key:find("^EMPTY_SOCKET_") and type(value)=="number" then
            item.emptySockets=(item.emptySockets or 0)+value
        end
    end
    item.specs=self:CachedItemCall(C_Item.GetItemSpecInfo,item.link)
    -- Rings, necklaces and cloaks have no primary stat, so the game reports no specialization
    -- list for them: that means "any spec", not "data missing".
    if type(item.specs)~="table" and (item.equipLoc=="INVTYPE_FINGER" or item.equipLoc=="INVTYPE_NECK"
        or item.equipLoc=="INVTYPE_CLOAK"
        or self.profile.leveling and item.quality and item.quality<=2) then item.specs={} end
    item.uniqueCategory,item.uniqueMax=self:CachedItemCall(C_Item.GetItemUniqueness,item.link)
    item.unique=self:CachedItemCall(C_Item.GetItemUniquenessByID,item.link)
    item.equippable=self:Call(C_Item.IsEquippableItem,item.link)
    local _,spell=self:CachedItemCall(C_Item.GetItemSpell,item.link)
    item.effect=spell~=nil
    if bag then
        local quest=self:Call(C_Container.GetContainerItemQuestInfo,bag,slot)
        item.quest=type(quest)=="table" and (quest.isQuestItem==true
            or type(quest.questID)=="number" and quest.questID>0) or false
    end
    if type(item.stats)~="table" then item.incomplete=true;item.why="sem estatísticas"
    elseif type(item.specs)~="table" then item.incomplete=true;item.why="sem info de especialização"
    elseif not item.level then item.incomplete=true;item.why="sem item level" end
    for _,value in pairs(item.stats or {}) do
        if issecretvalue and issecretvalue(value) then item.incomplete=true;item.why="estatística secreta";item.stats={};break end
    end
    self:ReadCachedTooltip(item)
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

function GM:CacheEquippedSlots()
    local cache=_G.MemoryItemCache
    local snapshot={version=1,session=cache.session,scope=cache.Scope(),generation=cache.generation or 0,level=self.profile.level,spec=self.profile.spec,atMax=not self.profile.leveling,
        updated=time(),slots={}}
    for slot,item in pairs(self.worn or {}) do
        local score=self:Score(item,self.profile.context)
        snapshot.slots[slot]={guid=item.guid,link=item.link,id=item.id,ilvl=item.level,quality=item.quality,
            primary=score[1],secondary=score[2],stats=_G.MemoryItemCache.Copy(item.stats or {}),
            bonusStats=_G.MemoryItemCache.Copy(item.bonusStats or {}),incomplete=item.incomplete or nil}
    end
    for slot in pairs(self.emptySlots or {}) do snapshot.slots[slot]={empty=true,ilvl=0} end
    self.db.equipmentCache=snapshot
end

function GM:ReadCachedTooltip(item)
    local key=tostring(item.guid or "")..":"..item.link..":"..tostring(item.bound)..":"..tostring(item.account)
    local values=_G.MemoryItemCache.Read(self.ReadTooltip,key,function()
        self:ReadTooltip(item)
        if item.incomplete then return nil end
        local result={}
        for _,field in ipairs({"stats","bonusStats","primaryInactive","pvp","pvpLevel","pvpUnknown",
            "effect","bindingReview","upgradeTrack","upgradeCur","upgradeLevel","upgradeMax","emptySockets"}) do result[field]=item[field] end
        return result
    end)
    if values then for field,value in pairs(values) do item[field]=value end end
end

function GM:Scan(skipAutomatic)
    if not self.db or InCombatLockdown() then return end
    self:ReadProfile()
    self.waiting={};self.items={};self.worn={};self.incomplete=false;self.copies={}
    self.wornIncomplete=false;self.incompleteList={};self.emptySlots={}
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
            if item.incomplete then
                self.incomplete=true;self.wornIncomplete=true
                self.incompleteList[#self.incompleteList+1]={item=item,where="equipado: "..self.slotNames[slot]}
            end
        else
            local occupied=self:Call(C_Item.DoesItemExist,ItemLocation:CreateFromEquipmentSlot(slot))
            if occupied==false then
                self.emptySlots[slot]=true
            else
                -- nil/error/secret is unknown, never proof of an empty slot.
                self.incomplete=true;self.wornIncomplete=true
                self.incompleteList[#self.incompleteList+1]={item={why="link do equipado indisponível"},where="equipado: "..self.slotNames[slot]}
            end
        end
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
                if item.incomplete then
                    self.incomplete=true
                    self.incompleteList[#self.incompleteList+1]={item=item,where="bolsa "..bag.."/"..slot}
                end
            end
        end
    end
    for _,item in ipairs(self:ReadBank()) do self.items[#self.items+1]=item end
    self:Evaluate()
    self:CacheEquippedSlots()
    self:RefreshUI()
    -- Item data can arrive late or never fire an event for what we could not read:
    -- look again a few times instead of waiting for a manual refresh.
    if self.incomplete or self.setsUnknown then
        if (self.retryScans or 0)<6 and not self.retryPending then
            self.retryScans=(self.retryScans or 0)+1;self.retryPending=true
            C_Timer.After(2,function()
                self.retryPending=false
                if (self.incomplete or self.setsUnknown) and not InCombatLockdown() then self:Scan(skipAutomatic) end
            end)
        end
    else self.retryScans=0 end
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

-- /gm diag: which items are unreadable, and why, so a stuck "waiting for data" is explainable.
function GM:DiagLines()
    local out={}
    local function add(text) out[#out+1]=text end
    local cache=_G.MemoryItemCache
    add("diag: cache hits="..tostring(cache and cache.hits)..", leituras="..tostring(cache and cache.misses)
        ..", slots gravados="..tostring(self.db.equipmentCache and self.db.equipmentCache.updated))
    add("diag: equipado incompleto="..tostring(self.wornIncomplete)..", conjuntos desconhecidos="..tostring(self.setsUnknown)
        ..", tentativas="..tostring(self.retryScans or 0))
    add("diag: pronto para equipar="..#(self.ready or {})..", automático="..tostring(self.config.automatic)..", pode equipar agora="..tostring(self:CanEquipNow())..", em combate="..tostring(InCombatLockdown()))
    local shown=0
    for _,s in ipairs(self.suggestions or {}) do
        if shown<14 then
            shown=shown+1
            add("diag: slot "..tostring(s.target).." "..tostring(s.item.link or s.item.name).." → "..tostring(s.reason or "PRONTO"))
        end
    end
    local context=self.profile.context
    add("diag: perfil="..tostring(context)..", spec="..tostring(self.profile.spec)..", principal="..tostring(self.profile.primary)
        ..", nível="..tostring(self.profile.level))
    local lines=0
    for _,item in ipairs(self.items or {}) do
        if item.storage=="bag" and item.gear and lines<20 then
            local why=self:FitsWhy(item)
            local worn
            for _,w in pairs(self.worn or {}) do if w.equipLoc==item.equipLoc then worn=w;if w.level and item.level and w.level<item.level then break end end end
            local a=self:Score(item,context)
            local b=worn and self:Score(worn,context) or nil
            if why or (b and a[3]>b[3]) then
                lines=lines+1
                local text="diag: "..tostring(item.link).." ["..tostring(item.equipLoc).."] "
                if why then text=text.."NÃO CABE: "..why
                else
                    text=text.."cabe: P="..a[1].." S="..a[2].." L="..a[3]
                    if b then text=text.." | equipado P="..b[1].." S="..b[2].." L="..b[3].." → "..tostring((self:Compare(a,b,context,1))) end
                end
                add(text)
            end
        end
    end
    local list=self.incompleteList or {}
    if #list==0 then add("diag: nenhum item incompleto na última leitura.") end
    for _,entry in ipairs(list) do
        local item=entry.item
        add("diag: "..entry.where.." "..tostring(item.link or item.name or item.id or "?").." → "..tostring(item.why or "?"))
    end
    return out
end

function GM:PrintDiagnostics()
    for _,line in ipairs(self:DiagLines()) do self:Print(line) end
end

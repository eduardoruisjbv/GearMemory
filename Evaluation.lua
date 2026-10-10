local _, GM = ...
local L=GM.L
local armor={WARRIOR=4,PALADIN=4,DEATHKNIGHT=4,HUNTER=3,SHAMAN=3,EVOKER=3,
    ROGUE=2,DRUID=2,MONK=2,DEMONHUNTER=2,MAGE=1,PRIEST=1,WARLOCK=1}
local armorSlots={INVTYPE_HEAD=true,INVTYPE_SHOULDER=true,INVTYPE_CHEST=true,INVTYPE_ROBE=true,
    INVTYPE_WAIST=true,INVTYPE_LEGS=true,INVTYPE_FEET=true,INVTYPE_WRIST=true,INVTYPE_HAND=true}
local slots={INVTYPE_HEAD={1},INVTYPE_NECK={2},INVTYPE_SHOULDER={3},INVTYPE_CHEST={5},INVTYPE_ROBE={5},
    INVTYPE_WAIST={6},INVTYPE_LEGS={7},INVTYPE_FEET={8},INVTYPE_WRIST={9},INVTYPE_HAND={10},
    INVTYPE_FINGER={11,12},INVTYPE_TRINKET={13,14},INVTYPE_CLOAK={15}}
local weapons={WARRIOR={[0]=true,[1]=true,[4]=true,[5]=true,[6]=true,[7]=true,[8]=true,[10]=true,[15]=true,[13]=true},
    PALADIN={[0]=true,[1]=true,[4]=true,[5]=true,[6]=true,[7]=true,[8]=true},
    DEATHKNIGHT={[0]=true,[1]=true,[4]=true,[5]=true,[6]=true,[7]=true,[8]=true},
    HUNTER={[0]=true,[1]=true,[2]=true,[3]=true,[6]=true,[7]=true,[8]=true,[10]=true,[15]=true,[18]=true},
    SHAMAN={[0]=true,[1]=true,[4]=true,[5]=true,[10]=true,[13]=true,[15]=true},
    ROGUE={[0]=true,[4]=true,[7]=true,[13]=true,[15]=true},DRUID={[4]=true,[5]=true,[6]=true,[10]=true,[13]=true,[15]=true},
    MONK={[0]=true,[4]=true,[6]=true,[7]=true,[10]=true,[13]=true},DEMONHUNTER={[0]=true,[7]=true,[9]=true,[13]=true},
    MAGE={[7]=true,[10]=true,[15]=true,[19]=true},PRIEST={[4]=true,[10]=true,[15]=true,[19]=true},
    WARLOCK={[7]=true,[10]=true,[15]=true,[19]=true},EVOKER={[0]=true,[4]=true,[7]=true,[10]=true,[13]=true,[15]=true}}
local primaryGroups={ITEM_MOD_STRENGTH_SHORT={1},ITEM_MOD_AGILITY_SHORT={2},ITEM_MOD_INTELLECT_SHORT={4},
    ITEM_MOD_AGI_STR_INT_SHORT={1,2,4},ITEM_MOD_AGI_STR_SHORT={1,2},ITEM_MOD_AGI_INT_SHORT={2,4},ITEM_MOD_STR_INT_SHORT={1,4}}
local function number(value) return type(value)=="number" and value or 0 end
-- A stat is the item's own value plus whatever gems and enchants add to it.
local function statOf(item,key)
    return number(item.stats and item.stats[key])+number(item.bonusStats and item.bonusStats[key])
end
local zeroScore={0,0,0}
GM.bindReason=L["Vínculo/possível transferência: equipe manualmente"]
GM.statOf=statOf

function GM:ItemKey(item) return item and (item.guid or item.storage..":"..tostring(item.bag)..":"..tostring(item.slot)..":"..tostring(item.inventorySlot)..":"..item.link) end
function GM:Same(a,b) return a and b and self:ItemKey(a)==self:ItemKey(b) end
function GM:TwoHanded(item)
    return item and (item.equipLoc=="INVTYPE_2HWEAPON" or item.class==2
        and (item.subclass==2 or item.subclass==3 or item.subclass==18))
end

function GM:Primary(item)
    local highest,has=0,false
    for key,group in pairs(primaryGroups) do
        local value=statOf(item,key)
        if value>0 then
            has=true
            for _,primary in ipairs(group) do if primary==self.profile.primary then highest=math.max(highest,value) end end
        end
    end
    return highest,has
end

-- Leveling eligibility depends on usable equipment and current item level,
-- never a specialization loot list or the presence of secondary/primary stats.
function GM:FitsWhy(item)
    local p=self.profile
    if not item.gear then return "não é equipamento" end
    if item.quest then return "marcado como item de missão" end
    if not armor[p.class] then return "classe sem tipo de armadura" end
    if type(item.level)~="number" then return "sem ilvl para comparar" end
    if item.minLevel and (not p.level or item.minLevel>p.level) then return "nível mínimo acima do personagem" end
    if item.equippable~=true then return "IsEquippableItem="..tostring(item.equippable) end
    if armorSlots[item.equipLoc] and item.subclass~=armor[p.class] then return "tipo de armadura incompatível" end
    if item.class==2 and not weapons[p.class][item.subclass] then return "arma não usável pela classe" end
    if item.equipLoc=="INVTYPE_SHIELD" and not (p.spec==73 or p.spec==66 or p.spec==65
        or p.class=="SHAMAN" and p.spec~=263) then return "escudo incompatível" end
    if item.equipLoc=="INVTYPE_HOLDABLE" and p.primary~=4 then return "mão secundária incompatível" end
    if p.leveling then
        if not item.snapshot and C_PlayerInfo and C_PlayerInfo.CanUseItem
            and self:Call(C_PlayerInfo.CanUseItem,item.id)==false then return "o personagem não pode usar o item" end
        return nil
    end
    local automatic=self.config and self.config.automatic
    if item.incomplete and not automatic then return "incompleto: "..tostring(item.why) end
    if type(item.stats)~="table" then return "sem atributos para comparar" end
    if not p.spec or not p.primary then return "sem especialização/atributo principal no perfil" end
    if type(item.specs)~="table" then return "sem lista de especializações" end
    if #item.specs>0 then
        local matches=false
        for _,spec in ipairs(item.specs) do if spec==p.spec then matches=true end end
        if not matches then return "lista de especializações do item não inclui a atual" end
    end
    local primary,has=self:Primary(item)
    if has and primary<=0 then return "atributo principal incompatível" end
    if item.primaryInactive and not item.snapshot then return "atributo principal inativo" end
    if (armorSlots[item.equipLoc] or item.class==2) and primary<=0 then return "armadura/arma sem atributo principal" end
end

function GM:Fits(item)
    return self:FitsWhy(item)==nil
end

-- Exact twins: same slot, level, stats, gems and enchants. Swapping one for the other changes
-- nothing about the character, only what the spare copy is worth at a vendor.
local function powerKey(item)
    local parts={}
    local function add(prefix,list)
        local keys={}
        for key,value in pairs(list or {}) do if type(value)=="number" then keys[#keys+1]=key end end
        table.sort(keys)
        for _,key in ipairs(keys) do parts[#parts+1]=prefix..key.."="..list[key] end
    end
    add("",item.stats);add("b:",item.bonusStats)
    parts[#parts+1]="sockets="..tostring(item.emptySockets or 0)
    return table.concat(parts,"|")
end

function GM:PowerTwin(a,b)
    if not a or not b or a.equipLoc~=b.equipLoc or a.level~=b.level or a.pvpLevel~=b.pvpLevel then return false end
    if (a.effect==true)~=(b.effect==true) or (a.setID or 0)~=(b.setID or 0) then return false end
    if next(a.stats or {})==nil or next(b.stats or {})==nil then return false end
    return powerKey(a)==powerKey(b)
end

-- A bag copy identical to the equipped one but worth at least 1 silver less at the vendor: wear
-- the cheaper copy so the dearer one (now in the bags) is the one that gets sold.
function GM:CheaperTwin(item, current, context)
    if not item or not current or item.storage=="equipped" or current.storage~="equipped" then return false end
    if item.equipLoc=="INVTYPE_TRINKET" then return false end
    local mine,theirs=item.sellPrice,current.sellPrice
    if type(mine)~="number" or type(theirs)~="number" or mine<=0 or theirs<=0 or theirs-mine<100 then return false end
    if not self:PowerTwin(item,current) then return false end
    return self:Compare(self:Score(item,context),self:Score(current,context),context)==0
end

-- Curated trinkets: rating 1-4 for the current spec and content group.
function GM:TrinketRating(item, context)
    if item.equipLoc~="INVTYPE_TRINKET" then return nil end
    local spec=self.data and self.data.trinkets[self.profile.spec]
    local group=spec and spec[context=="pvp" and "pvp" or "pve"]
    return group and group[item.id]
end

function GM:CurrencyQuantity(id)
    local info=self:Call(C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo,id)
    return type(info)=="table" and number(info.quantity) or 0
end

-- The item level an upgradeable item reaches if the player can pay for every
-- remaining rank right now. Unknown tracks or unaffordable ranks yield nil.
function GM:UpgradePotential(item)
    if not item.upgradeTrack or not item.upgradeCur or not item.upgradeMax or item.upgradeCur>=item.upgradeMax then return nil end
    local config=self.data and self.data.upgradeCurrency[item.upgradeTrack]
    if not config then return nil end
    local ranks=item.upgradeMax-item.upgradeCur
    if self:CurrencyQuantity(config.currency)<config.cost*ranks then return nil end
    return (item.level or 0)+ranks*self.rules.upgradeStep
end

-- PvP compares the buffed item level; PvE the real one (or its affordable
-- upgrade ceiling). Curated trinkets add virtual item level by rating.
function GM:EffectiveLevel(item, context)
    local level=item.level or 0
    if self.profile.leveling then return level end
    if context=="pvp" then level=item.pvpLevel or level
    else level=self:UpgradePotential(item) or level end
    local rating=self:TrinketRating(item,context)
    if rating then level=level+(self.rules.trinketBonus[rating] or 0) end
    return level
end

function GM:Score(item, context)
    if not item then return zeroScore end
    context=context or self.profile.context or "world"
    local cache=self.scoreCache and self.scoreCache[context]
    if self.scoreCache and not cache then cache={};self.scoreCache[context]=cache end
    if cache and cache[item] then return cache[item] end
    if not self:Fits(item) then
        if cache then cache[item]=zeroScore end
        return zeroScore
    end
    local p=self.profile
    local secondary=0
    for _,stat in ipairs(self.stats) do
        local weight=p.leveling and 1 or (stat==p.first and 3 or stat==p.second and 2 or 1)
        secondary=secondary+statOf(item,self.statKeys[stat])*weight
    end
    if not self.tertiaryOrder then
        self.tertiaryOrder={}
        for key in pairs(self.rules.tertiaryWeights) do self.tertiaryOrder[#self.tertiaryOrder+1]=key end
        table.sort(self.tertiaryOrder)
    end
    for _,key in ipairs(self.tertiaryOrder) do secondary=secondary+statOf(item,key)*self.rules.tertiaryWeights[key] end
    local score={self:Primary(item),secondary,self:EffectiveLevel(item,context)}
    if cache then cache[item]=score end
    return score
end

-- Pairwise comparison. Returns 1 / -1 / 0 and the deciding factor.
-- PvE: main attribute first; with the same main attribute an item level lead
-- of at least the threshold wins, otherwise weighted secondaries, then ilvl.
-- PvP: the (buffed) item level decides first, as the player must be ready.
-- `count` scales the threshold for sums over several slots.
function GM:Compare(a,b,context,count)
    count=count or 1
    if self.profile and self.profile.leveling then
        if a[3]~=b[3] then return a[3]>b[3] and 1 or -1,"ilvl" end
        if a[1]~=b[1] then return a[1]>b[1] and 1 or -1,"principal" end
        if a[2]~=b[2] then return a[2]>b[2] and 1 or -1,"secundarios" end
        return 0
    end
    if context=="pvp" then
        if a[3]~=b[3] then return a[3]>b[3] and 1 or -1,"ilvl" end
        if a[1]~=b[1] then return a[1]>b[1] and 1 or -1,"principal" end
        if a[2]~=b[2] then return a[2]>b[2] and 1 or -1,"secundarios" end
        return 0
    end
    if a[1]~=b[1] then return a[1]>b[1] and 1 or -1,"principal" end
    local diff=a[3]-b[3]
    if math.abs(diff)>=self.rules.ilvlThreshold*count then return diff>0 and 1 or -1,"ilvl" end
    if a[2]~=b[2] then return a[2]>b[2] and 1 or -1,"secundarios" end
    if diff~=0 then return diff>0 and 1 or -1,"ilvl" end
    return 0
end
function GM:Better(a,b,context,count) return self:Compare(a,b,context,count)>0 end

function GM:ScoreText(item)
    local context=self.profile.context
    local score=self:Score(item,context)
    return string.format(L["%s %g · secundários %g · %s %g"],self.primaryNames[self.profile.primary] or L["Principal"],
        score[1],score[2],context=="pvp" and L["ilvl PvP"] or "ilvl",score[3])
end

function GM:RatingBonus(stat)
    local ratings={crit=CR_CRIT_MELEE,haste=CR_HASTE_MELEE,vers=CR_VERSATILITY_DAMAGE_DONE,mastery=CR_MASTERY}
    local id=ratings[stat]
    return id and number(self:Call(GetCombatRatingBonus,id)) or 0
end

-- Secondary stats whose rating is already in diminishing returns.
function GM:ExcessStats()
    local result={}
    for _,stat in ipairs(self.stats) do
        if self:RatingBonus(stat)>=self.rules.drStart then result[#result+1]=stat end
    end
    return result
end

function GM:Explain(item, old, slot)
    local context=self.profile.context
    local a,b=self:Score(item,context),self:Score(old,context)
    local parts={}
    local level=context=="pvp" and L["ilvl PvP efetivo"] or "ilvl"
    if not old then
        parts[1]=string.format(L["espaço vazio · %s %g"],level,a[3])
    else
        local _,why=self:Compare(a,b,context,1)
        if why=="principal" then
            parts[1]=string.format(L["principal %g contra %g (%+g) · %s %+g"],a[1],b[1],a[1]-b[1],level,a[3]-b[3])
        elseif why=="ilvl" then
            parts[1]=string.format(L["%s %g contra %g (%+g)"],level,a[3],b[3],a[3]-b[3])
        elseif why=="secundarios" then
            parts[1]=string.format(L["secundários %g contra %g · %s %+g (abaixo do limiar de %d)"],a[2],b[2],level,a[3]-b[3],self.rules.ilvlThreshold)
        elseif self:CheaperTwin(item,old,context) then
            parts[1]=L["idêntico ao equipado, mas vale menos no vendedor: a cópia mais cara será vendida"]
        else
            parts[1]=string.format(L["melhor conjunto completo · %s %g contra %g"],level,a[3],b[3])
        end
    end
    local rating=self:TrinketRating(item,context)
    if rating then parts[#parts+1]=L["berloque curado nota "]..rating end
    local potential=item.upgradeTrack and context~="pvp" and self:UpgradePotential(item)
    if potential then parts[#parts+1]=L["conta o teto de upgrade ("]..potential..")" end
    if item.emptySockets and item.emptySockets>0 then parts[#parts+1]=item.emptySockets..L[" engaste(s) vazio(s)"] end
    for _,stat in ipairs(self.excess or {}) do
        if statOf(item,self.statKeys[stat])>0 then parts[#parts+1]=self.statNames[stat]..L[" acima da faixa de retornos decrescentes"] end
    end
    return table.concat(parts," · ")
end

function GM:UniqueAllowed(item, plan, target)
    if item.unique==nil then return false end
    if item.unique==false and not item.uniqueCategory then return true end
    if item.uniqueCategory and item.uniqueCategory>0 then
        if type(item.uniqueMax)~="number" then return false end
        local count=0
        for slot,other in pairs(plan) do if slot~=target and other then
            if other.unique==nil then return false end
            if other.uniqueCategory==item.uniqueCategory then count=count+1 end
        end end
        return count<item.uniqueMax
    end
    if item.unique then
        for slot,other in pairs(plan) do if slot~=target and other and (other.unique==nil or other.id==item.id) then return false end end
    end
    return true
end

function GM:SetCounts(plan)
    local counts={}
    for _,item in pairs(plan) do
        if item and item.setID and item.setID>0 then counts[item.setID]=(counts[item.setID] or 0)+1 end
    end
    return counts
end

-- Slots whose swap would drop a set bonus (2P or 4P) that is active now.
function GM:SetLosses(plan)
    local before,after,losses=self:SetCounts(self.worn),self:SetCounts(plan),{}
    for id,worn in pairs(before) do
        local planned=after[id] or 0
        if worn>=4 and planned<4 or worn>=2 and planned<2 then
            for slot,old in pairs(self.worn) do
                if old.setID==id and plan[slot]~=old then
                    losses[slot]=string.format(L["Perde bônus de conjunto (%dP→%dP): revise antes de trocar"],worn,planned)
                end
            end
        end
    end
    return losses
end

function GM:IsHeirloom(item)
    return item and item.quality==(Enum.ItemQuality.Heirloom or 7)
end

function GM:IsProtectedHeirloom(item)
    local level=self:Call(UnitLevel,"player")
    return self:IsHeirloom(item) and type(level)=="number" and level<=50
end

function GM:ReviewReason(item, old, loss, ignoreBind)
    if self:IsProtectedHeirloom(old) then return L["Herança equipada: preservada"] end
    local context=self.profile.context
    if item.storage=="bank" then return item.snapshot and L["Banco: registro da última visita; confira e retire o item"] or L["Banco: retire para as bolsas"] end
    -- Adding a plain, non-unique item to a confirmed empty single slot removes
    -- nothing: unreadable unrelated gear/sets cannot change that comparison.
    -- Pair slots/weapons, unique and set items still need the complete state.
    local targets=slots[item.equipLoc]
    local emptyAddition=not old and targets and #targets==1
        and self.emptySlots and self.emptySlots[targets[1]]==true
        and item.unique==false and not (item.uniqueCategory and item.uniqueCategory>0)
        and not (item.setID and item.setID>0) and not item.effect
    local automatic=self.config and self.config.automatic
    if not automatic and (self.wornIncomplete or self.setsUnknown) and not emptyAddition then
        return L["Aguardando dados de itens/conjuntos"]
    end
    if not automatic and (item.incomplete or old and old.incomplete) then return L["Dados incompletos"] end
    if item.storage=="bag" then
        if not item.guid then return L["Identificação/cópias do item exigem revisão"] end
        if item.locked then return L["Item bloqueado"] end
        -- Refund: the game itself asks the player to confirm before equipping a refundable item
        -- (the addon never dismisses that dialog), so it is not a reason to hold the upgrade back.
        if not automatic and not ignoreBind and (item.bound~=true or item.account~=false or item.bindingReview) then return self.bindReason end
    end
    if item.unique==nil or old and old.unique==nil then return L["Unicidade desconhecida"] end
    -- Leveling auto uses the actual stat/ilvl ranking, including replacements of
    -- legacy artifacts/heirlooms. These review labels do not veto the upgrade.
    if self.profile.leveling and old and type(old.level)=="number"
        and item.level-old.level<2 then return L["Leveling: ganho menor que 2 de ilvl"] end
    if automatic then return end
    if item.quality and item.quality>=5 or old and old.quality and old.quality>=5 then return L["Item especial: revise os efeitos"] end
    if loss then return loss end
    if self.setItems[item.id] or old and self.setItems[old.id] then return L["Conjunto salvo: revise"] end
    if item.equipLoc=="INVTYPE_TRINKET" then
        if not self:TrinketRating(item,context) then return L["Berloque fora da lista curada: revise o efeito"] end
    elseif item.effect or old and old.effect and old.equipLoc~="INVTYPE_TRINKET" then
        return L["Efeito: desempenho exige revisão"]
    end
    if context=="pvp" and (item.pvp or old and old.pvp) then return L["Escala PvP: atributos exibidos são de PvE; revise"] end
    if item.pvpUnknown or old and old.pvpUnknown then return L["Escala PvP desconhecida"] end
    if context~="pvp" and item.upgradeTrack then
        local potential=self:UpgradePotential(item)
        if potential and (not old or potential>(old.level or 0)) then
            return L["Depende de upgrade: gaste as moedas antes de contar com o nível máximo"]
        end
    end
end

function GM:Style(main)
    if not main then return nil end
    return self:TwoHanded(main) and "2h" or "1h"
end

function GM:WeaponOptions(candidates)
    local p=self.profile
    local spec=p.spec
    local dualOnly=p.class=="ROGUE" or p.class=="DEMONHUNTER" or spec==263 or spec==72
    local dual=dualOnly or spec==251 or spec==268 or spec==269
    local only2h=spec==71 or spec==250 or spec==252 or spec==255 or p.class=="DRUID" and p.primary==2
    local shield=spec==73 or spec==66
    local ranged=spec==253 or spec==254
    local mains,offs={},{}
    for _,item in ipairs(candidates) do
        local loc=item.equipLoc
        local two=self:TwoHanded(item)
        local one=loc=="INVTYPE_WEAPON" or loc=="INVTYPE_WEAPONMAINHAND" or item.subclass==19 and loc=="INVTYPE_RANGEDRIGHT"
        local mainOK
        if ranged then mainOK=two and (item.subclass==2 or item.subclass==3 or item.subclass==18)
        elseif only2h then mainOK=loc=="INVTYPE_2HWEAPON"
        elseif shield then mainOK=one
        elseif dualOnly then mainOK=one or spec==72 and loc=="INVTYPE_2HWEAPON"
        else mainOK=one or loc=="INVTYPE_2HWEAPON" end
        if (spec==259 or spec==261) and item.subclass~=15 then mainOK=false end
        if spec==260 and item.subclass==15 then mainOK=false end
        if mainOK and (item.storage~="equipped" or item.inventorySlot==16) then mains[#mains+1]=item end
        local offOK=dual and (loc=="INVTYPE_WEAPON" or loc=="INVTYPE_WEAPONOFFHAND" or spec==72 and loc=="INVTYPE_2HWEAPON")
            or not dual and not only2h and not ranged and (loc=="INVTYPE_SHIELD" or loc=="INVTYPE_HOLDABLE")
        if shield then offOK=loc=="INVTYPE_SHIELD" end
        if spec==259 and item.subclass~=15 then offOK=false end
        if offOK and (item.storage~="equipped" or item.inventorySlot==17) then offs[#offs+1]=item end
    end
    return mains,offs,dualOnly,dual,shield
end
function GM:WeaponTotal(main,off,context,total)
    local a,b=self:Score(main,context),self:Score(off,context)
    -- Two handed weapons already carry a two-slot stat budget. Only item level
    -- is doubled so it can break a tie against a complete one handed pair.
    total=total or {}
    total[1],total[2],total[3]=a[1]+b[1],a[2]+b[2],main and self:TwoHanded(main) and not off and a[3]*2 or a[3]+b[3]
    return total
end

-- Lexicographic order for lists and display only. Selection uses Better, which
-- is not a total order (the item level threshold), so it never feeds a sort.
function GM:Surrogate(context)
    local order=context=="pvp" and {3,1,2} or {1,3,2}
    return function(a,b)
        local sa,sb=self:Score(a,context),self:Score(b,context)
        for _,i in ipairs(order) do if sa[i]~=sb[i] then return sa[i]>sb[i] end end
        if a.storage~=b.storage then return a.storage=="equipped" or a.storage=="bag" and b.storage=="bank" end
        return self:ItemKey(a)<self:ItemKey(b)
    end
end

-- The best `capacity` items by repeated champion selection with Better.
function GM:TopItems(items, context, capacity)
    local pool={};for _,item in ipairs(items) do pool[#pool+1]=item end
    table.sort(pool,self:Surrogate(context))
    local top={}
    while #top<capacity and #pool>0 do
        local bestIndex=1
        for index=2,#pool do
            if self:Better(self:Score(pool[index],context),self:Score(pool[bestIndex],context),context) then bestIndex=index end
        end
        top[#top+1]=table.remove(pool,bestIndex)
    end
    return top
end

function GM:BuildPlan(candidates, context)
    local plan={};for slot,item in pairs(self.worn) do plan[slot]=item end
    local ordered={};for _,item in ipairs(candidates) do ordered[#ordered+1]=item end
    table.sort(ordered,self:Surrogate(context))
    for _,item in ipairs(ordered) do
        local targets=slots[item.equipLoc]
        if targets and #targets==1 and item.storage~="equipped" then
            local slot=targets[1]
            local present=false
            for _,other in pairs(plan) do if self:Same(item,other) then present=true end end
            local current=plan[slot]
            if not present and (not current or self:Better(self:Score(item,context),self:Score(current,context),context)
                or self:CheaperTwin(item,current,context))
                and self:UniqueAllowed(item,plan,slot) then plan[slot]=item end
        end
    end
    -- Enumerate complete ring/trinket pairs. A greedy highest-item-first choice
    -- can block a larger total improvement because of a unique category limit.
    for _,pair in ipairs({{11,12,"INVTYPE_FINGER"},{13,14,"INVTYPE_TRINKET"}}) do
        local list={}
        for _,item in ipairs(ordered) do if item.equipLoc==pair[3] then list[#list+1]=item end end
        local function total(a,b,result)
            local sa,sb=self:Score(a,context),self:Score(b,context)
            result=result or {}
            result[1],result[2],result[3]=sa[1]+sb[1],sa[2]+sb[2],sa[3]+sb[3]
            return result
        end
        local first,second=plan[pair[1]],plan[pair[2]]
        local best=total(first,second)
        -- Keep the complete pair search and unique checks; reuse scratch data
        -- instead of allocating a complete equipment table for every pair.
        local proposed,scratch={},{}
        for slot,item in pairs(plan) do if slot~=pair[1] and slot~=pair[2] then proposed[slot]=item end end
        for i=1,#list+1 do for j=1,#list+1 do
            local a,b=list[i],list[j]
            if not self:Same(a,b) then
                -- Retain equipped ring positions; swapping equivalent slots
                -- creates work without changing the equipment's stat total.
                local positioned=not (a and a.storage=="equipped" and a.inventorySlot~=pair[1])
                    and not (b and b.storage=="equipped" and b.inventorySlot~=pair[2])
                local score=total(a,b,scratch)
                if positioned and self:Better(score,best,context,2) then
                    proposed[pair[1]],proposed[pair[2]]=a,b
                    local allowed=(not a or self:UniqueAllowed(a,proposed,pair[1])) and (not b or self:UniqueAllowed(b,proposed,pair[2]))
                    if allowed then
                        first,second=a,b
                        best[1],best[2],best[3]=score[1],score[2],score[3]
                    end
                end
            end
        end end
        plan[pair[1]],plan[pair[2]]=first,second
    end
    -- Weapons: find the best arrangement of each style (two-handed or one-hand
    -- pair), then keep the spec's style unless another one is clearly better.
    local mains,offs,dualOnly,dual,shield=self:WeaponOptions(ordered)
    local currentMain,currentOff=plan[16],plan[17]
    local currentStyle=self:Style(currentMain)
    local currentScore=currentMain and self:WeaponTotal(currentMain,currentOff,context)
    local preferred=self.rules.preferredStyle[self.profile.spec]
    local bestByStyle={}
    if currentMain then bestByStyle[currentStyle]={main=currentMain,off=currentOff,score=currentScore} end
    local proposed={}
    for slot,item in pairs(plan) do if slot~=16 and slot~=17 then proposed[slot]=item end end
    local function consider(main,off)
        if self:Same(main,off) then return end
        if off and dual and ((main.equipLoc=="INVTYPE_2HWEAPON")~=(off.equipLoc=="INVTYPE_2HWEAPON")) then return end
        local style=self:Style(main)
        local score=self:WeaponTotal(main,off,context)
        local entry=bestByStyle[style]
        if entry and not self:Better(score,entry.score,context,2) then return end
        proposed[16],proposed[17]=main,off
        if not self:UniqueAllowed(main,proposed,16) or off and not self:UniqueAllowed(off,proposed,17) then return end
        bestByStyle[style]={main=main,off=off,score=score}
    end
    for _,main in ipairs(mains) do
        if self:TwoHanded(main) and self.profile.spec~=72 then consider(main,nil)
        else
            for _,off in ipairs(offs) do consider(main,off) end
            if not dualOnly and not shield then consider(main,nil) end
        end
    end
    local margin=(self.profile.leveling and 2 or self.rules.styleSwitchIlvl)*2
    local function accept(style,entry)
        if currentMain then
            if style==currentStyle or entry.main==currentMain and entry.off==currentOff then return true end
            if style==preferred then return self:Better(entry.score,currentScore,context,2) end
            return entry.score[3]-currentScore[3]>=margin and self:Better(entry.score,currentScore,context,2)
        end
        local favorite=preferred and bestByStyle[preferred]
        if not favorite or style==preferred then return true end
        return entry.score[3]-favorite.score[3]>=margin and self:Better(entry.score,favorite.score,context,2)
    end
    local result
    for _,style in ipairs({"2h","1h"}) do
        local entry=bestByStyle[style]
        if entry and accept(style,entry) and (not result or self:Better(entry.score,result.score,context,2)) then result=entry end
    end
    if result then plan[16],plan[17]=result.main,result.off end
    -- Preserve worn heirlooms through player level 50 even when their scaled level temporarily falls
    -- behind a drop. Weapons form a pair: do not remove a protected offhand by
    -- replacing the main hand with a two-handed item, or vice versa.
    for slot,old in pairs(self.worn) do
        if self:IsProtectedHeirloom(old) then plan[slot]=old end
    end
    if self:IsProtectedHeirloom(self.worn[16]) and self:TwoHanded(self.worn[16]) then
        plan[17]=self.worn[17]
    elseif self:IsProtectedHeirloom(self.worn[17]) and self:TwoHanded(plan[16]) then
        plan[16]=self.worn[16]
    end
    return plan
end

function GM:Evaluate()
    -- Scores depend on specialization, priorities and current item data.
    -- Share them only inside this evaluation, never across inventory scans.
    self.scoreCache={}
    self.excess=self:ExcessStats()
    local candidates={}
    self.categoryBest={}
    for _,item in ipairs(self.items) do if self:Fits(item) then
        candidates[#candidates+1]=item
        local loc=item.equipLoc=="INVTYPE_ROBE" and "INVTYPE_CHEST" or item.equipLoc
        item.category=loc..":"..tostring(item.subclass)..":"..(item.pvp and "pvp" or "pve")
        self.categoryBest[item.category]=self.categoryBest[item.category] or {items={},label=loc}
        table.insert(self.categoryBest[item.category].items,item)
    end end
    local current=self.profile.context
    local groups={pve=current~="pvp" and current or "world",pvp="pvp"}
    for _,category in pairs(self.categoryBest) do
        category.contexts={}
        local capacity=(category.label=="INVTYPE_FINGER" or category.label=="INVTYPE_TRINKET" or category.label=="INVTYPE_WEAPON"
            or category.label=="INVTYPE_2HWEAPON" and self.profile.spec==72) and 2 or 1
        for group,context in pairs(groups) do
            category.contexts[group]=self:TopItems(category.items,context,capacity)
        end
    end
    self.plan=self:BuildPlan(candidates,current)
    -- A bank upgrade must not suppress a live backpack upgrade that can be
    -- equipped now. Build both complete plans independently.
    local live={};for _,item in ipairs(candidates) do if item.storage~="bank" then live[#live+1]=item end end
    self.livePlan=self:BuildPlan(live,current)
    local planLoss,liveLoss=self:SetLosses(self.plan),self:SetLosses(self.livePlan)
    self.suggestions={}
    self.ready={}
    for slot,item in pairs(self.plan) do
        local old=self.worn[slot]
        if item.storage~="equipped" and not self:Same(item,old) then
            local reason=self:ReviewReason(item,old,planLoss[slot])
            self.suggestions[#self.suggestions+1]={item=item,old=old,target=slot,reason=reason,
                explain=self:Explain(item,old,slot),
                bindOnly=reason==self.bindReason and self:ReviewReason(item,old,planLoss[slot],true)==nil}
        end
    end
    for slot,item in pairs(self.livePlan) do
        local old=self.worn[slot]
        if item.storage=="bag" and not self:Same(item,old) then
            local reason=self:ReviewReason(item,old,liveLoss[slot])
            local bindOnly=reason==self.bindReason and self:ReviewReason(item,old,liveLoss[slot],true)==nil
            -- Weapon arrangements are atomic for review: never equip one
            -- half of a pair if the other half is unsafe or lives in the bank.
            if slot==16 or slot==17 then
                for _,weaponSlot in ipairs({16,17}) do
                    local new,previous=self.livePlan[weaponSlot],self.worn[weaponSlot]
                    if new and not self:Same(new,previous) then reason=reason or self:ReviewReason(new,previous,liveLoss[weaponSlot]) end
                    if not new and previous and (previous.effect or previous.setID and previous.setID>0
                        or self.setItems[previous.id]) then reason=reason or L["Troca remove efeito/conjunto da mão secundária"] end
                    if new and new.storage=="equipped" and not self:Same(new,previous) then reason=reason or L["Reposicionamento de arma: equipe manualmente"] end
                end
                if reason~=self.bindReason then bindOnly=false end
            end
            if not reason then self.ready[#self.ready+1]={item=item,old=old,target=slot} end
            local listed=false
            for _,s in ipairs(self.suggestions) do
                if s.target==slot and self:Same(s.item,item) then s.reason=reason;s.bindOnly=bindOnly;listed=true end
            end
            if not listed then
                self.suggestions[#self.suggestions+1]={item=item,old=old,target=slot,reason=reason,
                    explain=self:Explain(item,old,slot),bindOnly=bindOnly}
            end
        end
    end
    table.sort(self.suggestions,function(a,b)
        if a.target~=b.target then return a.target<b.target end
        return a.item.storage=="bag" and b.item.storage~="bag"
    end)
    table.sort(self.ready,function(a,b) return a.target<b.target end)
    self.scoreCache=nil
end

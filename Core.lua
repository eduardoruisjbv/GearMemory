local addon, GM = ...
local L=GM.L
_G.GearMemory = GM
GM.version = "0.2.1-beta"

function GM:Call(fn, ...)
    if type(fn)~="function" then return end
    local function safe(ok, ...)
        if not ok then return end
        local values={...}
        for _,value in pairs(values) do
            if issecretvalue and issecretvalue(value) then return end
        end
        return ...
    end
    return safe(pcall(fn, ...))
end

function GM:Print(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff40c9bbGearMemory|r: "..message) end
end

-- Which content profile applies right now. In the open world a flagged player
-- (PvP on or War Mode) is always treated as PvP.
function GM:CurrentContext()
    local config=self.config
    local chosen=config and config.context
    if chosen and self.contextNames[chosen] then return chosen end
    local _,instance=self:Call(IsInInstance)
    local flagged=self:Call(UnitIsPVP,"player")==true
        or C_PvP and self:Call(C_PvP.IsWarModeActive)==true
    return self:ContentFor(instance,flagged)
end

function GM:ReadProfile()
    local _,class=self:Call(UnitClass,"player")
    local index=self:Call(C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization)
    local spec,name,_,_,role,primary
    if index then
        spec,name,_,_,role,primary=self:Call(C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo,index)
    end
    self.db.profiles=self.db.profiles or {}
    local id=spec or 0
    self.db.profiles[id]=self.db.profiles[id] or {first="mastery", second="haste", context="auto", automatic=false}
    self.config=self.db.profiles[id]
    self.config.automatic=self.config.automatic==true and self.config.consent==1
    if not self.statNames[self.config.first] then self.config.first="mastery" end
    if not self.statNames[self.config.second] or self.config.second==self.config.first then
        for _,stat in ipairs(self.stats) do if stat~=self.config.first then self.config.second=stat;break end end
    end
    -- 0.1.x stored "pve"/"pvp"; anything that is not a content profile is automatic.
    if not self.contextNames[self.config.context] then self.config.context="auto" end
    local context=self:CurrentContext()
    -- Priorities are kept per content profile; the old single pair is the default.
    self.config.priorities=self.config.priorities or {}
    local priorities=self.config.priorities[context]
    local first,second=self.config.first,self.config.second
    if priorities and self.statNames[priorities.first] and self.statNames[priorities.second]
        and priorities.first~=priorities.second then first,second=priorities.first,priorities.second end
    if self.lastContext and self.lastContext~=context and self.Toast then
        self:Toast(L["Perfil de equipamento: "]..self.contextNames[context],
            self.statNames[first].." > "..self.statNames[second])
    end
    self.lastContext=context
    self.profile={class=class, spec=spec, name=name, role=role, primary=primary,
        level=self:Call(UnitLevel,"player"), context=context, first=first, second=second}
    return self.profile
end

function GM:SetPriority(which, stat)
    self:StopEquipment()
    local context=self.profile.context
    local current={first=self.profile.first, second=self.profile.second}
    local other=which=="first" and "second" or "first"
    if current[other]==stat then current[other]=current[which] end
    current[which]=stat
    self.config.priorities[context]={first=current.first, second=current.second}
    self.blocked={}
    self:ScheduleScan(nil,true)
end

function GM:ScheduleScan(event, service)
    if not service and not self.bagsOpen then self.inventoryDirty=true;return end
    if service then self.scanService=true end
    if not self.db or self.scanPending then return end
    self.scanPending=true
    C_Timer.After(0.25,function()
        self.scanPending=false
        local serviceScan=self.scanService
        self.scanService=nil
        if not serviceScan and not self.bagsOpen then self.inventoryDirty=true;return end
        if not InCombatLockdown() then self.inventoryDirty=nil;self:Scan() end
    end)
end

local opens={MERCHANT_SHOW="merchant", BANKFRAME_OPENED="bank", AUCTION_HOUSE_SHOW="auction",
    TRADE_SHOW="trade", QUEST_DETAIL="quest", QUEST_PROGRESS="quest", QUEST_COMPLETE="quest"}
local closes={MERCHANT_CLOSED="merchant", BANKFRAME_CLOSED="bank", AUCTION_HOUSE_CLOSED="auction",
    TRADE_CLOSED="trade", QUEST_FINISHED="quest"}
GM.services={}
local frame=CreateFrame("Frame")
GM.events=frame
for _,event in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_ENTERING_WORLD",
    "PLAYER_SPECIALIZATION_CHANGED","PLAYER_LEVEL_UP",
    "EQUIPMENT_SETS_CHANGED","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED",
    "MERCHANT_SHOW","MERCHANT_CLOSED","BANKFRAME_OPENED","BANKFRAME_CLOSED","AUCTION_HOUSE_SHOW",
    "AUCTION_HOUSE_CLOSED","TRADE_SHOW","TRADE_CLOSED","QUEST_DETAIL","QUEST_PROGRESS","QUEST_COMPLETE",
    "QUEST_FINISHED","BANK_TABS_CHANGED","PLAYER_FLAGS_CHANGED","WAR_MODE_STATUS_UPDATED",
    "ZONE_CHANGED_NEW_AREA"}) do
    pcall(frame.RegisterEvent,frame,event)
end
frame:SetScript("OnEvent",function(_,event,arg)
    if event=="ADDON_LOADED" then
        if arg~=addon then
            if GM.db then GM:InstallBagHooks() end
            return
        end
        GearMemoryDB=type(GearMemoryDB)=="table" and GearMemoryDB or {}
        GM.db=GearMemoryDB
        GM:ReadProfile()
        GM:InstallBagHooks()
        SLASH_GEARMEMORY1="/gm";SLASH_GEARMEMORY2="/gearmemory"
        SlashCmdList.GEARMEMORY=function(message)
            if message=="stop" then GM.config.automatic=false;GM:StopEquipment();GM:RefreshUI()
            elseif message=="explain" then GM:PrintExplain()
            elseif message=="aviso" or message=="toast" then
                GM.db.toast=GM.db.toast==false
                GM:Print(L["Aviso na tela "]..(GM.db.toast==false and L["desligado."] or L["ligado."]))
            else GM:ToggleUI() end
        end
        return
    end
    if not GM.db then return end
    if opens[event] then GM.services[opens[event]]=true;GM:StopEquipment() end
    if closes[event] then GM.services[closes[event]]=nil end
    if event=="PLAYER_REGEN_DISABLED" then GM:StopEquipment();return end
    if event=="PLAYER_SPECIALIZATION_CHANGED" then
        if arg~="player" then return end
        GM:StopEquipment();GM.blocked={}
    end
    if event=="PLAYER_LOGIN" then GM:CreateLauncher() end
    if event=="PLAYER_FLAGS_CHANGED" and arg~="player" then return end
    if event=="PLAYER_FLAGS_CHANGED" or event=="WAR_MODE_STATUS_UPDATED" or event=="ZONE_CHANGED_NEW_AREA" then
        -- AFK/DND toggle the same flags; only a real content change matters.
        if GM:CurrentContext()==GM.profile.context then return end
        GM:StopEquipment();GM.blocked={}
    end
    if event=="GET_ITEM_INFO_RECEIVED" or event=="ITEM_DATA_LOAD_RESULT" then
        if not GM.bagsOpen then GM.inventoryDirty=true;return end
        if not GM.waiting or not GM.waiting[arg] then return end
        GM.waiting[arg]=nil
    end
    GM:ScheduleScan(event,opens[event]=="bank")
end)

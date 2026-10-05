local _, GM = ...
local inventoryEvents={"BAG_UPDATE_DELAYED","GET_ITEM_INFO_RECEIVED","ITEM_DATA_LOAD_RESULT",
    "PLAYER_EQUIPMENT_CHANGED","PLAYERBANKSLOTS_CHANGED","PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED"}

function GM:HasOpenBags()
    if ContainerFrameUtil_EnumerateContainerFrames then
        for _,frame in ContainerFrameUtil_EnumerateContainerFrames() do
            if frame:IsShown() then return true end
        end
    end
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then return true end
    for index=1,NUM_CONTAINER_FRAMES or 13 do
        local frame=_G["ContainerFrame"..index]
        if frame and frame:IsShown() then return true end
    end
    return false
end

function GM:BagVisibilityChanged()
    local open=self:HasOpenBags()
    if open==self.bagsOpen then return end
    self.bagsOpen=open
    for _,event in ipairs(inventoryEvents) do
        if open then pcall(self.events.RegisterEvent,self.events,event)
        else self.events:UnregisterEvent(event) end
    end
    self.inventoryDirty=true
    if open and self.db then
        self.waiting={}
        self:ScheduleScan("BAG_OPEN")
    elseif self.work and self.work.automatic then
        self:StopEquipment()
    end
end

function GM:WatchBagFrame(frame)
    if not frame or self.bagFrames and self.bagFrames[frame] then return end
    self.bagFrames=self.bagFrames or {}
    self.bagFrames[frame]=true
    frame:HookScript("OnShow",function() self:BagVisibilityChanged() end)
    frame:HookScript("OnHide",function() self:BagVisibilityChanged() end)
end

function GM:InstallBagHooks()
    self.bagFunctionHooks=self.bagFunctionHooks or {}
    for _,fn in ipairs({"OpenBag","CloseBag","OpenAllBags","CloseAllBags","ToggleAllBags"}) do
        if type(_G[fn])=="function" and not self.bagFunctionHooks[fn] then
            self.bagFunctionHooks[fn]=true
            hooksecurefunc(fn,function() self:BagVisibilityChanged() end)
        end
    end
    if ContainerFrameUtil_EnumerateContainerFrames then
        for _,frame in ContainerFrameUtil_EnumerateContainerFrames() do self:WatchBagFrame(frame) end
    end
    self:WatchBagFrame(ContainerFrameCombinedBags)
    if not self.containerHook and ContainerFrameMixin and ContainerFrameMixin.UpdateItems then
        self.containerHook=true
        hooksecurefunc(ContainerFrameMixin,"UpdateItems",function(frame)
            self:WatchBagFrame(frame)
            self:BagVisibilityChanged()
        end)
    end
    self:BagVisibilityChanged()
end

-- Extra scan triggers -------------------------------------------------------
-- A scan also runs (bags open or not) when gear is looted and when the character
-- panel opens. Big loot windows and bursts of loots (material farming) are ignored.
local MAX_LOOT_ITEMS=6                  -- a loot window with more items than this is skipped
local BURST_WINDOW,BURST_MAX,BURST_PAUSE=15,10,15  -- more than 10 loots in 15 s pauses loot scans for 15 s
local LOOT_COOLDOWN,PANEL_COOLDOWN=3,1  -- minimum seconds between requested scans

-- true: gear, false: not gear, nil: could not be read (treated as "maybe").
local function isGearLink(link)
    if type(link)~="string" and type(link)~="number" then
        if issecretvalue and issecretvalue(link) then return nil end
        return false
    end
    if issecretvalue and issecretvalue(link) then return nil end
    local ok,_,_,_,equipLoc,_,classID=pcall(C_Item.GetItemInfoInstant,link)
    if not ok or not classID then return nil end
    return (classID==2 or classID==4) and type(equipLoc)=="string" and equipLoc~="" and equipLoc~="INVTYPE_NON_EQUIP_IGNORE"
end

function GM:RequestScan(reason, cooldown)
    if not self.db then return end
    local now=GetTime()
    if now<(self.scanBlockedUntil or 0) then return end
    if now-(self.lastRequestedScan or 0)<(cooldown or LOOT_COOLDOWN) then return end
    self.lastRequestedScan=now
    -- Let the new item land in the bag before reading it.
    C_Timer.After(0.5,function() self:ScheduleScan(reason,true) end)
end

function GM:NoteLootWindow()
    local now=GetTime()
    local times=self.lootTimes or {}
    self.lootTimes=times
    for i=#times,1,-1 do if now-times[i]>BURST_WINDOW then table.remove(times,i) end end
    times[#times+1]=now
    if #times>BURST_MAX then
        self.scanBlockedUntil=now+BURST_PAUSE
        return true
    end
    return false
end

function GM:OnLootOpened()
    self.lootGear=false
    local burst=self:NoteLootWindow()
    local count=self:Call(GetNumLootItems)
    if type(count)~="number" then count=0 end
    if count>MAX_LOOT_ITEMS then
        -- Also silence the loot chat lines that follow this window.
        self.scanBlockedUntil=math.max(self.scanBlockedUntil or 0,GetTime()+8)
        return
    end
    if burst then return end
    for slot=1,count do
        if isGearLink(self:Call(GetLootSlotLink,slot))~=false then self.lootGear=true;break end
    end
end

function GM:OnLootClosed()
    if not self.lootGear then return end
    self.lootGear=false
    self:RequestScan("LOOT",LOOT_COOLDOWN)
end

-- Loot that never opens a window (rolls, quest rewards, mail, purchases).
function GM:OnLootMessage(text, guid)
    if type(text)~="string" or (issecretvalue and (issecretvalue(text) or issecretvalue(guid))) then return end
    if guid~=UnitGUID("player") then return end
    local itemString=text:match("|H(item:[^|]+)|h")
    if not itemString or isGearLink(itemString)~=true then return end
    self:RequestScan("LOOT_MSG",LOOT_COOLDOWN)
end

function GM:InstallPanelHooks()
    local frame=_G.CharacterFrame
    if frame and not self.panelHooked then
        self.panelHooked=true
        frame:HookScript("OnShow",function() self:RequestScan("CHARACTER",PANEL_COOLDOWN) end)
    elseif not frame and not self.panelToggleHooked and type(_G.ToggleCharacter)=="function" then
        self.panelToggleHooked=true
        hooksecurefunc("ToggleCharacter",function()
            if _G.CharacterFrame and _G.CharacterFrame:IsShown() then
                self:RequestScan("CHARACTER",PANEL_COOLDOWN)
                self:InstallPanelHooks()
            end
        end)
    end
end

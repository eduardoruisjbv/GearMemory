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

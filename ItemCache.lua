-- Shared native item metadata cache. Each addon remains usable on its own.
-- Never cache live locations, locks, binding/refund state, quests or AH prices.
local _, Addon = ...
local cache = _G.MemoryItemCache
if not cache or cache.version ~= 1 then
    cache = {version=1, entries={}, count=0, hits=0, misses=0, session=GetTime()}
    _G.MemoryItemCache = cache
    local function pack(...) return {n=select("#",...),...} end
    local function plain(value,depth)
        if issecretvalue and issecretvalue(value) then return false end
        local kind=type(value)
        if kind=="table" then
            if (depth or 0)>12 then return false end
            for k,v in pairs(value) do
                if not plain(k,(depth or 0)+1) or not plain(v,(depth or 0)+1) then return false end
            end
        elseif kind~="nil" and kind~="string" and kind~="number" and kind~="boolean" then return false end
        return true
    end
    function cache.Copy(value)
        if type(value)~="table" then return value end
        local result={}
        for k,v in pairs(value) do result[k]=cache.Copy(v) end
        return result
    end
    function cache.Scope()
        local fn=C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
        local ok,spec=pcall(fn or function() return 0 end)
        return tostring(UnitGUID("player"))..":"..tostring(UnitLevel("player"))..":"..tostring(ok and spec or 0)
    end
    function cache.Read(fn,key,load)
        if not plain(key) or type(fn)~="function" then return load() end
        local scope=cache.Scope()
        if scope~=cache.scope then cache.entries={};cache.count=0;cache.scope=scope end
        local identity=tostring(key)
        local bucket=cache.entries[fn]
        local entry=bucket and bucket[identity]
        if entry and GetTime()-entry.at<60 then
            cache.hits=cache.hits+1
            local values=cache.Copy(entry.values)
            return unpack(values,1,values.n)
        end
        cache.misses=cache.misses+1
        local values=pack(load())
        if values[1]~=nil and plain(values) then
            if cache.count>=1024 then cache.entries={};cache.count=0 end
            bucket=cache.entries[fn] or {};cache.entries[fn]=bucket
            bucket[identity]={values=cache.Copy(values),at=GetTime()}
            cache.count=cache.count+1
        end
        return unpack(values,1,values.n)
    end
    function cache.Invalidate(id)
        cache.generation=(cache.generation or 0)+1
        if type(id)~="number" then cache.entries={};cache.count=0;return end
        for _,bucket in pairs(cache.entries) do
            for key in pairs(bucket) do
                if tonumber(key:match("item:(%d+)"))==id or key==tostring(id) then bucket[key]=nil end
            end
        end
    end
    local events=CreateFrame("Frame")
    for _,event in ipairs({"ITEM_DATA_LOAD_RESULT","GET_ITEM_INFO_RECEIVED","PLAYER_LEVEL_UP",
        "PLAYER_SPECIALIZATION_CHANGED","TRAIT_CONFIG_UPDATED","PLAYER_ENTERING_WORLD","ITEM_UPGRADE_MASTER_UPDATE"}) do
        pcall(events.RegisterEvent,events,event)
    end
    events:SetScript("OnEvent",function(_,event,arg)
        if event=="ITEM_DATA_LOAD_RESULT" or event=="GET_ITEM_INFO_RECEIVED" then cache.Invalidate(arg)
        elseif event~="PLAYER_SPECIALIZATION_CHANGED" or arg=="player" then cache.Invalidate() end
    end)
    cache.events=events
end
function Addon:CachedItemCall(fn,link)
    return cache.Read(fn,link,function() return self:Call(fn,link) end)
end
function Addon:CachedItemLevel(location,link,guid)
    return cache.Read(C_Item.GetCurrentItemLevel,tostring(guid or "")..":"..tostring(link),function()
        return self:Call(C_Item.GetCurrentItemLevel,location)
    end)
end

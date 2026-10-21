-- Shared native item metadata cache. Each addon remains usable on its own.
-- Never cache live locations, locks, binding/refund state, quests or AH prices.
local _, Addon = ...
local VERSION = 2
local cache = _G.MemoryItemCache
if not cache or (tonumber(cache.version) or 0) < VERSION then
    if cache and cache.events then cache.events:UnregisterAllEvents() end
    cache = {version=VERSION, entries={}, byItem={}, count=0, hits=0, misses=0, session=GetTime()}
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
    local function wipeAll()
        cache.entries={};cache.byItem={};cache.count=0
    end
    function cache.Copy(value)
        if type(value)~="table" then return value end
        local result={}
        for k,v in pairs(value) do result[k]=cache.Copy(v) end
        return result
    end
    -- GetTime() is constant within a frame, so the scope is built at most once per frame.
    function cache.Scope()
        local now=GetTime()
        if cache.scopeAt~=now or not cache.scopeValue then
            local fn=C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
            local ok,spec=pcall(fn or function() return 0 end)
            cache.scopeValue=tostring(UnitGUID("player"))..":"..tostring(UnitLevel("player"))..":"..tostring(ok and spec or 0)
            cache.scopeAt=now
        end
        return cache.scopeValue
    end
    function cache.Read(fn,key,load)
        if not plain(key) or type(fn)~="function" then return load() end
        local scope=cache.Scope()
        if scope~=cache.scope then wipeAll();cache.scope=scope end
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
            if not entry and cache.count>=1024 then wipeAll() end
            bucket=cache.entries[fn] or {};cache.entries[fn]=bucket
            if not bucket[identity] then
                cache.count=cache.count+1
                local id=tonumber(identity:match("item:(%d+)") or identity)
                if id then
                    local refs=cache.byItem[id] or {};cache.byItem[id]=refs
                    refs[#refs+1]={bucket=bucket,identity=identity}
                end
            end
            bucket[identity]={values=cache.Copy(values),at=GetTime()}
        end
        return unpack(values,1,values.n)
    end
    function cache.Invalidate(id)
        cache.generation=(cache.generation or 0)+1
        if type(id)~="number" then wipeAll();cache.scopeValue=nil;return end
        local refs=cache.byItem[id]
        if not refs then return end
        cache.byItem[id]=nil
        for _,ref in ipairs(refs) do
            if ref.bucket[ref.identity] then ref.bucket[ref.identity]=nil;cache.count=cache.count-1 end
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

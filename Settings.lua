local _, GM = ...
local L = GM.L

local function Register(category, variable, key, name, default, get, set)
    if Settings.RegisterProxySetting then
        return Settings.RegisterProxySetting(category, variable, Settings.VarType.String, name, default, get, set)
    end
    -- Older clients: back the setting with a plain table and forward changes.
    local store = {[key] = get()}
    local setting = Settings.RegisterAddOnSetting(category, variable, key, store, Settings.VarType.String, name, default)
    setting:SetValueChangedCallback(function() set(store[key]) end)
    return setting
end

local function RegisterSettingsCategory()
    if GM.settingsCategory then return end
    if not (Settings and Settings.RegisterVerticalLayoutCategory
        and Settings.RegisterAddOnSetting and Settings.CreateDropdown) then
        return
    end

    local category, layout = Settings.RegisterVerticalLayoutCategory("GearMemory")
    if layout and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("GearMemory"))
    end
    if layout and CreateSettingsListTextEntryInitializer then
        layout:AddInitializer(CreateSettingsListTextEntryInitializer(
            "Set the current content profile here. Use /gm to open the equipment review workspace. Automatic equipping still requires its separate confirmation."
        ))
    end

    -- GM.config is swapped on every specialization change, so bind through
    -- getters/setters instead of capturing one profile table at registration.
    local setting = Register(category, "GearMemory_context", "context", "Content profile", "auto",
        function() return GM.config and GM.config.context or "auto" end,
        function(value)
            if not GM.config or GM.config.context == value then return end
            GM.config.context = value
            GM:StopEquipment()
            GM.blocked = {}
            GM:ReadProfile()
            GM:ScheduleScan(nil, true)
            if GM.RefreshUI then GM:RefreshUI() end
        end)
    Settings.CreateDropdown(category, setting, function()
        local values = Settings.CreateControlTextContainer()
        values:Add("auto", "Automatic", "Choose the profile from the current game content.")
        values:Add("raid", L["Raide"], "Use the raid priorities.")
        values:Add("dungeon", L["Masmorra / M+"], "Use the dungeon and Mythic+ priorities.")
        values:Add("world", L["Mundo aberto"], "Use the open-world priorities.")
        values:Add("pvp", "PvP", "Use PvP priorities and item levels.")
        return values:GetData()
    end, "Automatic follows the current game context. A manual selection stays active until changed back.")

    local weaponSetting = Register(category, "GearMemory_weaponStyle", "weaponStyle",
        L["Prioridade de estilo de arma"], "auto",
        function() return GM.config and GM.config.weaponStyle or "auto" end,
        function(value) GM:SetWeaponStyle(value) end)
    Settings.CreateDropdown(category, weaponSetting, function()
        local values = Settings.CreateControlTextContainer()
        values:Add("auto", L["Padrão da especialização"], L["Usar o estilo recomendado para a especialização atual."])
        values:Add("2h", L["Duas mãos"], L["Preferir uma arma de duas mãos quando a especialização atual puder usá-la."])
        values:Add("1h", L["Duas armas de uma mão"], L["Preferir um par de armas de uma mão quando a especialização atual puder usar duas."])
        return values:GetData()
    end, L["A preferência é ignorada quando a especialização atual não pode usar esse estilo de arma."])

    Settings.RegisterAddOnCategory(category)
    GM.settingsCategory = category
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, loadedName)
    if loadedName ~= "GearMemory" then return end
    events:UnregisterEvent("ADDON_LOADED")
    if C_Timer and C_Timer.After then C_Timer.After(0, RegisterSettingsCategory)
    else RegisterSettingsCategory() end
end)

local _, GM = ...
local L = GM.L

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

    local variable = "GearMemory_context"
    local setting = Settings.RegisterAddOnSetting(
        category, variable, "context", GM.config, Settings.VarType.String, "Content profile", "auto"
    )
    setting:SetValueChangedCallback(function()
        if not GM.config then return end
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

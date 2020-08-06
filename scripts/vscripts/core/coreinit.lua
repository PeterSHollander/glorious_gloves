--[[
    TODO: IN PROGRESS

-- This file ensures the Scalable Init Support addon is enabled, and prints a warning message if it is not found

-- Copy this file to "Half-Life Alyx/game/hlvr_addons/<YOUR_ADDON_NAME>/scripts/vscripts/core/coreinit.lua" and make sure it SHIPS with your final build
-- Do not modify this file, as it will be automatically overwritten in the presence of others like it.

local SCALABLE_INIT_WORKSHOP_ID = "2182586257"

local function AddonIsEnabled (workshopID)
    local addonList = Convars:GetStr("default_enabled_addons_list")
    for enabledWorkshopID in addonList:gmatch("[^,]+") do
        if enabledWorkshopID == workshopID then return true end
    end
    return false
end



-- Server initializes before client
if IsServer() then

    Convars:RegisterConvar("scalable_init_support_enabled", "0", "", 0)

    if not AddonIsEnabled(SCALABLE_INIT_WORKSHOP_ID) then

        Warning(
            "\n"..
            "\tScalable Init Support addon not enabled\n"..
            "\tAt least one of the enabled mods depends on Scalable Init Support\n"..
            "\tAttempting to enable Scalable Init Support addon...\n"..
            " "
        )
    
        Convars:SetBool("scalable_init_support_enabled", true)
        SendToServerConsole("addon_enable " .. SCALABLE_INIT_WORKSHOP_ID)

    end

-- Init files get called a second time at client initialization
elseif Convars:GetBool("scalable_init_support_enabled") then

    if AddonIsEnabled(SCALABLE_INIT_WORKSHOP_ID) then
        Warning(
            "\n"..
            "\tScalable Init Support addon successfully enabled\n"..
            "\tRestarting map to mount Scalable Init Support addon\n"..
            " "
        )
        local currentMap = GetMapName():gsub("maps/", "")
        currentMap = currentMap:gsub(".vpk", "")
        SendToConsole("addon_play " .. currentMap)
    else
        Warning(
            "\n"..
            "\tScalable Init Support addon not detected\n"..
            "\tPlease download and enable Scalable Init Support from the workshop in order to use the related mod(s)\n"..
            " "
        )
    end
end

--]]
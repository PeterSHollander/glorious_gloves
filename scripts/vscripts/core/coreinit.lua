-- This file ensures the Scalable Init Support addon is the most recently enabled (ie. priority) addon
-- If it can't be enabled, an in-game warning message will aggressively print to the user
-- You can use the functions found in this file to enforce additional dependencies in your custom mods/init/<YOUR_WORKSHOP_ID>.lua file, as Scalable Init Support's priority will always guarantee their presence.

-- Copy this file to "Half-Life Alyx/game/hlvr_addons/<YOUR_ADDON_NAME>/scripts/vscripts/core/coreinit.lua" and make sure it SHIPS with your final build
-- This file will be automatically overwritten in the presence of others like it.

-----------------------------------------
--  /!\  DO NOT MODIFY THIS FILE  /!\  --
-----------------------------------------


local SCALABLE_INIT_NAME = "Scalable Init Support"
local SCALABLE_INIT_WORKSHOP_ID = "2182586257"
local SCALABLE_INIT_CONVAR = "scalable_init_support_enabled"



local DEPENDENCY_WARNING_NAME = "addon_dependency_warning_message"

local SpawnDependencyWarning
local SubmitConsoleCommand

local playerActivateListener = nil



-- Be careful using overrideAddonPriority - You should have a seriously good reason to raise your priority above Scalable Init Support's.
EnforceAddonDependency = function (workshopID, addonName, addonConvar, overrideAddonPriority)

    addonName = addonName or workshopID
    addonConvar = addonConvar or (workshopID .. "_enabled")
    overrideAddonPriority = overrideAddonPriority or false

    -- Server initializes before client
    if IsServer() then

        Convars:RegisterConvar(addonConvar, "0", "", 0)
        local addonIsEnabled = AddonIsEnabled(workshopID)

        if addonIsEnabled and (AddonIsPriority(workshopID) or not overrideAddonPriority) then
            Convars:SetBool(addonConvar, true)
        else

            local failureStatus = "enabled" if addonIsEnabled then failureStatus = "priority" end

            Warning(
                "\n"..
                "\tAddon \"" .. addonName .. "\" not " .. failureStatus .. "\n"..
                "\tAt least one of the currently enabled mods depends on this addon being " .. failureStatus .. "\n"..
                "\tRequesting to enable...\n"..
                " " )

            if addonIsEnabled then SubmitConsoleCommand("addon_disable " .. workshopID, true) end
            SubmitConsoleCommand("addon_enable " .. workshopID, true)

            if playerActivateListener then StopListeningToGameEvent(playerActivateListener) end
            playerActivateListener = ListenToGameEvent("player_activate", function() SpawnDependencyWarning(workshopID, addonName) end, nil)    -- Game events need to be subscribed to during server initialization, not client

        end

    -- Init files get called a second time at client initialization
    elseif not Convars:GetBool(addonConvar) then

        if AddonIsEnabled(workshopID) then

            Convars:SetBool(addonConvar, true)

            Warning(
                "\n"..
                "\tAddon \"" .. addonName .. "\" successfully enabled\n"..
                "\tRestarting map load to mount addon (will lose any save game information)\n"..
                "\tEnabling " .. addonName .. " manually in the future may prevent extended loading times\n"..
                " " )

            if overrideAddonPriority and not AddonIsPriority(workshopID) then
                Warning(
                    "\n"..
                    "\tAddon \"" .. addonName .. "\" is enabled, but not set as the priority addon!\n"..
                    "\tCertain functionality of multiple addons may depend on " .. addonName .. " being the priority addon\n"..
                    "\tPlease reconsider overriding " .. addonName .. "'s addon priority\n"..
                    " " )
            end

            -- This command will fail in Hammer/tools mode (which is fine, all dependent files should be temporarily copied to the local directory during development anyway)
            SubmitConsoleCommand("addon_play " .. GetMapName():gsub(".*/", ""):gsub("%..*", ""))

        else
            Warning(
                "\n"..
                "\tAddon \"" .. addonName .. "\" not detected\n"..
                "\tAt least one of the currently enabled mods depends on this addon\n"..
                "\tPlease download and enable \"" .. addonName .. "\" from the workshop in order to use the related mod(s)\n"..
                " " )
        end
    end
end



AddonIsEnabled = function (workshopID)
    local addonList = Convars:GetStr("default_enabled_addons_list")
    for enabledWorkshopID in addonList:gmatch("[^,]+") do
        if enabledWorkshopID == workshopID then return true end
    end
    return false
end



AddonIsPriority = function (workshopID)
    local addonList = Convars:GetStr("default_enabled_addons_list")
    if addonList:gsub(".*,", "") == workshopID then return true else return false end
end



SubmitConsoleCommand = function (command, isServer)
    local target = "client" if isServer then target = "server" end
    Msg("sending to " .. target .. " console: " .. command .. "\n")
    if isServer then SendToServerConsole(command) else SendToConsole(command) end
end



SpawnDependencyWarning = function (workshopID, addonName)

    if not AddonIsEnabled(workshopID) then

        for _, warningText in pairs(Entities:FindAllByName(DEPENDENCY_WARNING_NAME)) do
            print("Found multiple addon dependency warning messages!  Only showing most recent")
            warningText:RemoveSelf()
        end

        SpawnEntityFromTableAsynchronous("point_worldtext", {
            targetname = DEPENDENCY_WARNING_NAME;
            message =
                "Addon  \"" .. addonName .. "\"  not detected.\n"..
                "\n"..
                "At least one of the enabled mods depends on this addon.\n"..
                "Please download and enable \"" .. addonName .. "\"\n"..
                "from the workshop in order to use the related mod(s).";
            enabled = "1";
            fullbright = "1";
            color = "191 0 0 255";
            world_units_per_pixel = "0.015";
            font_size = "100";
            justify_horizontal = "1";
            justify_vertical = "1";
        },
        function(warningText)
            warningText:SetParent(Entities:GetLocalPlayer():GetHMDAvatar(), "")
            warningText:SetLocalOrigin(Vector(30, 0, 0))
            warningText:SetLocalAngles(0, 270, 90)
            warningText:SetThink(function()
                print("Removing addon dependency warning text (" .. addonName .. ")")
                warningText:RemoveSelf()
            end, "WaitToRemoveWarningText", 25)
        end, nil)

    end

    StopListeningToGameEvent(playerActivateListener)
    playerActivateListener = nil

end



EnforceAddonDependency(SCALABLE_INIT_WORKSHOP_ID, SCALABLE_INIT_NAME, SCALABLE_INIT_CONVAR, true)
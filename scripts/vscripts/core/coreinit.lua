-- This file notifies the user if the Scalable Init Support addon is not downloaded/enabled
-- Copy this file to "Half-Life Alyx/game/hlvr_addons/<YOUR_ADDON>/scripts/vscripts/core/" and make sure it ships with your final build

local SCALABLE_INIT_WORKSHOP_ID = "2182586257"

if IsServer() then SendToServerConsole("addon_enable " .. SCALABLE_INIT_WORKSHOP_ID) else

    local scalableInitActive = false
    local addonList = Convars:GetStr("default_enabled_addons_list")
    for workshopID in addonList:gmatch("[^,]+") do
        if workshopID == SCALABLE_INIT_WORKSHOP_ID then scalableInitActive = true end
    end

    if not scalableInitActive then Warning(
        "\n"..
        "\tScalable Init Support addon not detected\n"..
        "\tPlease download and enable Scalable Init Support from the workshop in order to use the related mod(s)\n"..
        " "
    ) end

end
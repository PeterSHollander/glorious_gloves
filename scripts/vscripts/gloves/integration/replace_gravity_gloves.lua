require "device/input"
require "gloves/integration/health_status"
require "gloves/core"



local GRAVITY_GLOVE_CLASSNAME = "prop_grabbity_gloves"
local AMMO_COUNTER_CLASSNAME  = "hlvr_gravity_glove_ammo_panel"
local FLASHLIGHT_CLASSNAME    = "hlvr_flashlight_attachment"
local ITEM_HOLDER_CLASSNAME   = "hlvr_hand_item_holder"
local GLORIOUS_GLOVES_NAME    = ".*glorious_glove.*"

PUNTY_PAWS      = "Punt"
LEVITATOR_LIMBS = "Levitate"
GRABBITY_GLOVES = "Grabbity"

local AMMO_BODYGROUP  = 1
local RESIN_BODYGROUP = 0   -- Why are these inverted? <- Appears to be the order they are listed in ModelDoc, not in their CTRL file component

local INITIALIZATION_DELAY  = 1
      ACTIVE_PARTICLE_DELAY = 1.2
      SEARCH_INTERVAL       = 0.1

local HEARTS_OFFSET       = Vector(-1.49, 1.7, 0.48)
local HEARTS_ANGLE_OFFSET = QAngle(-11, -2, -68)

-- TODO: Why have many of these variables stopped working as locals?

controllers = {
    left = nil;
    right = nil;
}

gloves = {
    left = nil;
    right = nil;
}

ammoCounter  = nil
healthStatus = nil

gloveIsActive   = { false, false }
gloveActiveTime = 0

reinitialize = false



function Precache (context)
    if HealthStatus then if HealthStatus.Precache then HealthStatus.Precache(context) end end
    if Punt then if Punt.Precache then Punt.Precache(context) end end
    if Levitate then if Levitate.Precache then Levitate.Precache(context) end end
    if Grabbity then if Grabbity.Precache then Grabbity.Precache(context) end end
end



-- TODO: Implement save/load states for scripts, instead of brute-force reinitializing every time
function Activate ()

    thisEntity:SetThink(Initialize, "GloriousGlovesInitializationDelay", INITIALIZATION_DELAY)

    ListenToGameEvent("grabbity_glove_highlight_start", GloveIsActive, nil)
    ListenToGameEvent("grabbity_glove_locked_on_start", GloveIsActive, nil)
    ListenToGameEvent("grabbity_glove_highlight_stop", GloveIsInactive, nil)

    ListenToGameEvent("weapon_switch", UpdateAmmoCounter, nil)

    ListenToGameEvent("player_picked_up_flashlight", RevertGravityGloves, nil)
    ListenToGameEvent("player_attached_flashlight", Initialize, nil)

    ListenToGameEvent("change_level_activated", RevertGravityGloves, nil)
    
end



function Initialize ()

    print("Initializing Gravity Glove replacer...")

    -- Is this safe to assume that the controller entities will not change over time?
    controllers.left = Input.GetController(Input.LEFT)
    controllers.right = Input.GetController(Input.RIGHT)

    local foundOldGloriousGloves = false
    for _, entity in pairs(Entities:FindAllByClassname("info_target")) do
        if entity:GetName():match("glorious_glove_.*_hand_.*") then
            print("Old instance of Glorious Glove found - removing")
            entity:RemoveSelf()
            foundOldGloriousGloves = true
        end
    end

    if foundOldGloriousGloves then
        print("Reinitializing Glorious Gloves...")
        ResetAttachments()
        RevertGravityGloves()
    end

    -- Not a fan of the (albeit minimal) overhead of constantly checking for the Gravity Gloves.  Wish there was a game event.
    print("Searching for original Gravity Gloves...")
    SEARCH_INTERVAL = 0.1
    thisEntity:SetThink(ReplaceGravityGloves, "SearchingForGravityGloves")

end



-- Checks if both Glorious Gloves are present
function CheckForGloriousGloves ()

    local foundGloriousGlove = false

    for i, child in pairs(controllers.left:GetChildren()) do
        if child:GetName():match("glorious_glove_.*_hand_.*") then
            foundGloriousGlove = true
        end
    end

    for i, child in pairs(controllers.right:GetChildren()) do
        if child:GetName():match("glorious_glove_.*_hand_.*") then
            foundGloriousGlove = true
        end
    end

    if foundGloriousGlove then return true else return false end

end



-- Reassociates/Rebuilds Gravity Glove attachments (ammo counter, health status)
function ResetAttachments ()

    for i, controller in pairs(controllers) do

        local handRenderable = Input.GetHandRenderable(controller)
        local healthStatusFound = false

        for i, child in pairs(handRenderable:GetChildren()) do

            if child:GetClassname() == AMMO_COUNTER_CLASSNAME then
                print("Ammo counter found - reassociating...")
                ammoCounter = child

            elseif child:GetName():match(HealthStatus.ENTITY_NAME .. ".*") then
                print("Health status replacement heart found - removing...")
                healthStatusFound = true
                child:RemoveSelf()
            end

        end

        if healthStatusFound then
            print("Recreating health status replacement...")
            healthStatus = HealthStatus(handRenderable, HEARTS_OFFSET, HEARTS_ANGLE_OFFSET, "grabbity_glove")
        end

    end
end



-- Removes default Gravity Gloves if found and replaces them with Glorious Gloves if not already present
function ReplaceGravityGloves ()

    if not SEARCH_INTERVAL then return nil end  -- Prevents default gloves from being removed immediately after forcing them to respawn

    if RemoveGravityGloves() then

        if not CheckForGloriousGloves() then
            print("Replacing with Glorious Gloves...")
            -- Use EntFireByHandle here to safely delay each configuration call
            EntFireByHandle(thisEntity, thisEntity, "RunScriptCode", "Configure(PUNTY_PAWS)")
            EntFireByHandle(thisEntity, thisEntity, "RunScriptCode", "Configure(LEVITATOR_LIMBS)", 1/30)
            EntFireByHandle(thisEntity, thisEntity, "RunScriptCode", "Configure(GRABBITY_GLOVES)", 2/30)
        end

    end

    return SEARCH_INTERVAL

end



-- Removes default Gravity Gloves when they aren't producing particle effects, preserving the ammo counter, health status, and flashlight if present
function RemoveGravityGloves ()

    local deleted = false
                
    if (not gloveIsActive[1] and not gloveIsActive[2]
    and Time() - gloveActiveTime >= ACTIVE_PARTICLE_DELAY ) then
    
        for i, controller in pairs(controllers) do
            for i, entity in pairs(controller:GetChildren()) do
                if entity:GetClassname() == GRAVITY_GLOVE_CLASSNAME then

                    print("Found original Gravity Glove - Removing...")
                    
                    for i, child in pairs(entity:GetChildren()) do
                        local classname = child:GetClassname()

                        if classname == AMMO_COUNTER_CLASSNAME then

                            if not CheckForGloriousGloves() then
                                print("Found ammo counter - preserving...")
                                child:SetParent(Input.GetHandRenderable(controller), "grabbity_glove")
                                ammoCounter = child

                                print("Generating health status replacement...")
                                healthStatus = HealthStatus(Input.GetHandRenderable(controller), HEARTS_OFFSET, HEARTS_ANGLE_OFFSET, "grabbity_glove")
                            end

                        elseif classname == FLASHLIGHT_CLASSNAME then

                            if not CheckForGloriousGloves() then
                                print("Found flashlight - preserving...")
                                child:SetParent(Input.GetHandRenderable(controller), "grabbity_glove")
                            end

                        else
                            print("Found non-essential entity \"" .. classname .. "\" - removing...")
                            child:RemoveSelf()
                        end
                    end
                    
                    entity:RemoveSelf()

                    deleted = true

                end
            end
        end
    end
    
    return deleted

end



function Configure (behaviour)

    if not IsValidEntity(gloves.left) and not IsValidEntity(gloves.right) then
    
        print("Spawning in custom Gravity Gloves")

        local tProperties = {
            targetname = "glorious_glove_detector" .. UniqueString() .. "left";
            vscripts = "gloves/detector";
            --spawnflags = CreateSpawnflags( {1} );    -- Not sure what "Always transmit to client (ignore PVS)" means, but I'm assuming I want this to be a clientside entity? <- Or not, causes save/load crashes...
        }

        gloves.left = SpawnEntityFromTableSynchronous("info_target", tProperties)
        tProperties.targetname = "glorious_glove_detector" .. UniqueString() .. "right"
        gloves.right = SpawnEntityFromTableSynchronous("info_target", tProperties)

        EntFireByHandle(thisEntity, gloves.left, "RunScriptCode", "InitializeGlove(Input.LEFT)")
        EntFireByHandle(thisEntity, gloves.right, "RunScriptCode", "InitializeGlove(Input.RIGHT)")
    
    end

    EntFireByHandle(thisEntity, gloves.left, "RunScriptCode", "ConfigureBehaviour(" .. behaviour .. "(glove))")
    EntFireByHandle(thisEntity, gloves.right, "RunScriptCode", "ConfigureBehaviour(" .. behaviour .. "(glove))")

end



-- Removes any salvaged/recreated glove components (ammo counter, health status), halts automatic replacement, and respawns the default Gravity Gloves
function RevertGravityGloves ()

    if controllers.left or controllers.right then

        print("Reverting to default Gravity Gloves...") -- Glorious Glove removal currently handled in gloves/core.lua
        
        if healthStatus then healthStatus:Remove() end
        if IsValidEntity(ammoCounter) then 
            print("Removing ammo counter")
            ammoCounter:RemoveSelf()
        end
        
        SEARCH_INTERVAL = nil

        RespawnGravityGloves()

    end

end



-- Respawns the default Gravity Gloves, preserving the current inventory configuration and allowing the current flashlight to be replaced if it is present
function RespawnGravityGloves ()

    local tProperties = {
        targetname = "respawn_gravity_gloves";
        equip_on_mapstart = 0;
        grabbitygloves = 1;
        itemholder = 0; -- Why does the current itemholder value get overwritten, but other parameters don't?
        flashlight = 0;
    }

    for i, controller in pairs(controllers) do
        for i, child in pairs(controller:GetChildren()) do
            local classname = child:GetClassname()
            if classname == ITEM_HOLDER_CLASSNAME then
                print("Preserving wrist pocket")
                tProperties.itemholder = 1
            elseif classname == FLASHLIGHT_CLASSNAME then
                tProperties.flashlight = 1
                print("Removing and preserving flashlight")
                child:RemoveSelf()
            elseif classname == AMMO_COUNTER_CLASSNAME then
                print("Removing ammo counter")
                child:RemoveSelf()
            end
        end
    end

    print("Respawning original Gravity Gloves")

    local equip = SpawnEntityFromTableSynchronous("info_hlvr_equip_player", tProperties)
    EntFireByHandle(thisEntity, equip, "EquipNow")
    EntFireByHandle(thisEntity, equip, "Kill", "", FrameTime())

end



-- When the user switches to a non-weapon (hand or multitool), show resin count; otherwise show ammo
function UpdateAmmoCounter (eventInfo)
    if IsValidEntity(ammoCounter) then
        if (eventInfo["item"] == "hand_use_controller"
         or eventInfo["item"] == "hlvr_multitool" ) then
            ammoCounter:SetBodygroup(AMMO_BODYGROUP, 0)
            ammoCounter:SetBodygroup(RESIN_BODYGROUP, 1)
        else
            ammoCounter:SetBodygroup(RESIN_BODYGROUP, 0)
            ammoCounter:SetBodygroup(AMMO_BODYGROUP, 1)
        end
    end
end



-- Little event listeners that watch for Gravity Glove particle-related events, keeps track of whether or not default particles are currently rendering
function GloveIsActive (eventInfo)
    if eventInfo["hand_is_primary"] then
        gloveIsActive[1] = true
    else
        gloveIsActive[2] = true
    end
end

function GloveIsInactive (eventInfo)
    if eventInfo["hand_is_primary"] then
        gloveIsActive[1] = false
    else
        gloveIsActive[2] = false
    end
    gloveActiveTime = Time()
end
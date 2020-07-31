require "gloves/core"

-- Expected to be attached to the templated detector entity



-- TODO: Turns out moving physics triggers calling script functions are expensive, even only at 5 times per second.  Oops.
--       Managed to work in Entities:FindAllInSphere() instead of using a trigger, but replaced trigger with info_target to avoid complete rework
-- TODO: Allow for dynamic saving and loading, rather than brute-force reinitialization of default behaviours with each load



glove = nil     -- Needs to be global so it can be accessed by RunScriptCode, but worried about global conflicts with such a generic name

local eventList = {}



function Activate ()
    thisEntity:SetThink(FallbackInitialization, "GloriousGloveDetectorInitializationDelay", 1.2)    -- Delay needs to be greater than gloves/integration/replace_gravity_gloves.lua's INITIALIZATION_DELAY
end



-- Hack; using it for reloading a save
function FallbackInitialization ()
    if glove == nil then
        --print("Glove not initialized! This probably happened because a save was loaded, breaking the expected replacement flow.")
        --print("Overriding with default Glorious Glove behaviours. If you aren't modding the Glorious Gloves then this shouldn't be a problem.")
        print("Glove not initialized! Not sure why this happened, but we'll go ahead and remove it to reduce clutter.")
        thisEntity:RemoveSelf()

        --[[ Cleanup old Glorious Glove entities
        for i, child in pairs(Input.GetController(Input.LEFT):GetChildren()) do
            if child:GetName():match("glorious_glove_.*_hand_.*") then
                print("Found old Glorious Glove LEFT \"hand\" entity - removing...")
                child:RemoveSelf()  -- I don't like this brute force
            end
        end
        for i, child in pairs(Input.GetController(Input.RIGHT):GetChildren()) do
            if child:GetName():match("glorious_glove_.*_hand_.*") then
                print("Found old Glorious Glove RIGHT \"hand\" entity - removing...")
                child:RemoveSelf()
            end
        end--]]

        --InitializeGlove(Input.GetHandSelection(thisEntity:GetMoveParent())) -- Apparently something causes the move parent to be dissociated after initialization
        --EntFireByHandle(thisEntity, thisEntity, "RunScriptCode", "ConfigureBehaviour(Punt(glove))")
        --EntFireByHandle(thisEntity, thisEntity, "RunScriptCode", "ConfigureBehaviour(Levitate(glove))", 1/30)
        --EntFireByHandle(thisEntity, thisEntity, "RunScriptCode", "ConfigureBehaviour(Grabbity(glove))", 2/30)
    end
end



function InitializeGlove (handSelection)
    Glove.Print("Detection volume entity initializing...")
    glove = Glove(handSelection, thisEntity)
    eventList = {
        ListenToGameEvent("player_picked_up_flashlight", RemoveGlove, nil),
        ListenToGameEvent("change_level_activated", RemoveGlove, nil),
    }
end

function ConfigureBehaviour (behaviour)
    glove:AddBehaviour(behaviour)
end

function RemoveGlove ()
    if glove then
        for i, event in pairs(eventList) do
            --StopListeningToGameEvent(event) -- Woah, scripts still execute even if their hosting entity is removed...
            -- ^ And apparently this disables the other glove from removing itself?
            eventList[i] = nil
        end
        glove:RemoveGlove()
        glove = nil
    end
end



function EnableGlove ()
    if glove then
        glove:Enable()
    end
end
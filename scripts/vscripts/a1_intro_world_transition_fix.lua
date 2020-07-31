require "/customutils"



function Activate ()

    print("Replacing problematic level change with addon map command...")

    local problem = Entities:FindByName(nil, "command_change_level")
    if problem then problem:RemoveSelf() end    -- If only life were that easy

    local relay = Entities:FindByName(nil, "relay_stun_player")
    AddEntityOutput(relay, "OnTrigger", thisEntity, "CallScriptFunction", "ChangeLevel", 1.5)

    print("Done.")

end



function ChangeLevel ()
    SendToConsole("addon_play a1_intro_world_2")
end
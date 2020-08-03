local unsupportedMapList = {
    --"a5_vault",
    "a5_ending",
}

local gameEvent = nil



local function SpawnEntityOnce (classname, tProperties)
    if (#Entities:FindAllByName(tProperties.targetname) <= 0) then
        print("\"" .. tProperties.targetname .. "\" not found - creating...")
        SpawnEntityFromTableAsynchronous(classname, tProperties, nil, nil)
    end
end



local function GlovesInit ()

    Convars:RegisterConvar("glorious_gloves_verbose", "0", "Enables significantly verbose output from various Glorious Gloves scripts", 0)

    local currentMap = GetMapName()
    local isSupportedMap = true
    for _, map in pairs(unsupportedMapList) do
        if map == currentMap then isSupportedMap = false break end
    end

    if isSupportedMap then

        print("Initializing Glorious Glove setup entities...")

        SpawnEntityOnce("logic_script", {
            targetname = "glorious_gloves_initializer";
            vscripts = "gloves/integration/replace_gravity_gloves";
        } )
        SpawnEntityOnce("filter_damage_type", {
            targetname = "block_scripted_sequence_physics_damage";
            vscripts = "gloves/integration/fix_zombie_scripted_sequences";
            Negated = 1;
            damagetype = 1;
        } )

    else
        print("Map \"" .. currentMap .. "\" is not supported by the Glorious Gloves mod at this time.")
    end

    if gameEvent then StopListeningToGameEvent(gameEvent) end

end



gameEvent = ListenToGameEvent("player_activate", GlovesInit, nil)
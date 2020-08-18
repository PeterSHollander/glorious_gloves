local unsupportedMapList = {
    --"a5_vault",
    "a5_ending",
}

local gameEvents = {}



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

    for _, gameEvent in pairs(gameEvents) do StopListeningToGameEvent(gameEvent) end

end



-- Apparently the second game event listener you register in the same frame (probably of the same name) doesn't actually register its function, but all subsequent listeners do?
-- So as to protect not disabling a second game event listener in another subsequently executed script, we should register a second game event listener that calls an empty function, thereby blocking that unregisterable listener from being used
-- And to protect our own function from not being the second disabled game event, we should have our first game event listener call an empty function
-- Thus we need to call our function in the third game event listener, as that guarantees it will be called no matter the situation.  So janky.
gameEvents = {
    ListenToGameEvent("player_activate", function() end, nil),
    ListenToGameEvent("player_activate", function() end, nil),
    ListenToGameEvent("player_activate", GlovesInit, nil),
}
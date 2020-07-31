require "/customutils"



local SCRIPTED_SEQUENCE_SEARCH_RADIUS = 180
local ZOMBIE_HEALTH_BUFFER = 1000000

patchedZombieList = {}  -- Global for RunScriptCode access
zombieHealth = {}



-- A band-aid to prevent most scripted-sequence zombies from corrupting hands' grabbing functionality when killed with physics objects (Source 2 engine bug)
-- NOTE: Only applies this fix to zombies that are within 180 units of a scripted sequence, and assumes the two are associated
--       If a zombie without a scripted sequence is near a scripted sequence, these "wires will cross", so to speak... Zombie should still be damaged, just with the manual bullet-damage code instead

function Activate()
    print("Searching for zombies near scripted sequences to perform fixup...")
    -- We need to do this in a Thinker because not all zombies spawn in at level start
    thisEntity:SetThink(function()
        local zombies = Entities:FindAllByClassname("npc_zombie")
        for _, zombie in pairs(zombies) do
            local alreadyFixed = false
            for _, patchedZombie in pairs(patchedZombieList) do
                if zombie == patchedZombie then alreadyFixed = true break end
            end
            if not alreadyFixed then
                local scriptedSequence = Entities:FindByClassnameNearest("scripted_sequence", zombie:GetAbsOrigin(), SCRIPTED_SEQUENCE_SEARCH_RADIUS)
                if IsValidEntity(scriptedSequence) then
                    if zombie:GetHealth() < ZOMBIE_HEALTH_BUFFER / 3 then   -- If not, then it implies that we've already applied the damage increase and entity outputs to this zombie
                        print("Found zombie near scripted sequence - diverting physics damage until sequence is completed...")
                        local zombieIndex = #patchedZombieList + 1
                        --AddEntityOutput(scriptedSequence, "OnCancelSequence", zombie, "SetDamageFilter")
                        --EntFireByHandle(thisEntity, zombie, "SetDamageFilter", thisEntity:GetName())

                        --AddEntityOutput(scriptedSequence, "OnCancelSequence", zombie, "physdamagescale", "1")
                        --EntFireByHandle(thisEntity, zombie, "physdamagescale", "0.1")

                        AddEntityOutput(scriptedSequence, "OnCancelSequence", zombie, "RunScriptCode",
                            "if 0 < thisEntity:GetHealth() then\n" .. -- Oof, can't use ">" in RunScriptCode on an AddOutput since that's the delimiter for the next parameter
                                "thisEntity:SetHealth(thisEntity:GetHealth() - " .. tostring(ZOMBIE_HEALTH_BUFFER) .. ")\n" ..
                            "end")

                        AddEntityOutput(zombie, "OnDamaged", thisEntity, "RunScriptCode", "ZombieTookDamage(" .. tostring(zombieIndex) .. ")")
                        zombie:SetHealth(zombie:GetHealth() + ZOMBIE_HEALTH_BUFFER)
                        patchedZombieList[zombieIndex] = zombie
                        zombieHealth[zombieIndex] = zombie:GetHealth()
                    end
                end
            end
        end
        return 0.5
    end, "ContinueSearchingForScriptedSequenceZombies")
end



-- TODO: Spaghetti code
function ZombieTookDamage (index)
    local zombie = patchedZombieList[index]
    if IsValidEntity(zombie) then
        local currentHealth = zombie:GetHealth()
        if (currentHealth > 0
        and currentHealth > ZOMBIE_HEALTH_BUFFER / 3   -- TODO: magic number
        and currentHealth - ZOMBIE_HEALTH_BUFFER <= 0 ) then
            local damageAmount = zombieHealth[index] - currentHealth
            zombie:SetHealth(zombieHealth[index] - ZOMBIE_HEALTH_BUFFER)
            -- Apparently CreateDamageInfo makes AddOutput string invalid?  Doin' it here instead.
            -- TODO: Add impact vector
            local damageInfo = CreateDamageInfo(thisEntity, Entities:GetLocalPlayer(), Vector(0, 0, 0), Vector(0, 0, 0), damageAmount, DMG_BULLET)
            zombie:TakeDamage(damageInfo)
            DestroyDamageInfo(damageInfo)
        else
            zombieHealth[index] = zombie:GetHealth()
        end
    end
end
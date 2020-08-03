require "device/input"
require "gloves/lib/validity"
require "gloves/lib/motion"
require "gloves/lib/gesture"
require "gloves/behaviours/grabbity"
require "/customutils"

local CustomDebug = require "/debug"



Levitate = class(

    {
        COMFORTABLE_DISTANCE = 15;--8;
        MAX_DISTANCE_BUFFER = 2;
        MAX_LEVITATION_SPEED = 650;
        DISCONNECT_DELAY = 0.5;
        TELEPORT_UPDATE_DELAY = 0.05;

        MANHACK_UPDATE_INTERVAL = 1 / 144;

        HAPTIC_LEVITATE;

        PARTICLE_BEAM;
        PARTICLE_BEAM_1;
        PARTICLE_BEAM_2;
        PARTICLE_BEAM_3;



        levitateValidity;
        grabbityValidity;

        hasTether;
        tetherIsValid;

        entityOffset;
        manhackEventList;



        constructor = function (self, glove)

            print("Initializing \"Levitate\" behaviour...")

            self.levitateValidity = Validity( {
                minDistance = 0;    --7 -- Be careful with 0 as distance; right now levitate will ONLY work on glove.tether.movingEntity, not by just closing your hand
                maxDistance = 52.5 + self.MAX_DISTANCE_BUFFER;
                maxMass = 300;
                minSize = 4;
                minIncidence = 0.25;
                ignoreClass = {
                    "npc_.+",
                    "prop_door_rotating_physics",
                    "prop_animinteractable",
                    --"func_.+",
                    --"shatterglass_shard",
                };
                ignoreModel = {
                    -- Physics constrained items:
                    ".*drawer.*",
                    ".+_handle.*",
                    ".*cabinet.*",
                    ".*door.*",
                    ".*piano.*",
                    ".*dumpster.*",
                    ".*hazmat_crate_lid.*",
                    --".*combine_memory_tank.*",
                    -- Ragdolls:
                    ".*zombie.*",
                    ".*antlion.*",
                    ".*headcrab.*",
                    ".*combine_grunt.*",
                    ".*combine_captain.*",
                    ".*combine_soldier.*",
                    ".*combine_suppressor.*",
                    ".*citizen.*",
                    ".*worker.*",
                    ".*metrocop_choreo.*",
                };
                allowModelOverride = {
                    ".*gib.*",
                    ".*armored_headcrab_shell_prop.*",
                    ".*hazmat_worker_.+",
                };
            } )

            self.levitateValidity.maxSize = 2 * ((self.levitateValidity.maxDistance - self.MAX_DISTANCE_BUFFER) - self.COMFORTABLE_DISTANCE)

            self.grabbityValidity = Validity(Grabbity.VALIDITY_OVERRIDE)

            self.disconnectTime = 0

            self.HAPTIC_LEVITATE = HapticSequence(glove.UPDATE_INTERVAL, 0.4, 1/123)

            self.PARTICLE_BEAM = ParticleSystem(Levitate.PARTICLE_BEAM_NAME)
            --self.PARTICLE_BEAM_1 = ParticleSystem(Levitate.PARTICLE_BEAM_NAME)
            --self.PARTICLE_BEAM_2 = ParticleSystem(Levitate.PARTICLE_BEAM_NAME)
            --self.PARTICLE_BEAM_3 = ParticleSystem(Levitate.PARTICLE_BEAM_NAME)
            
            self.PARTICLE_BEAM:Create( {
                -- Don't parent particles directly to hand entities!  Causes save/load crashes
                [0] = ParticleSystem.ControlPoint();
                [1] = ParticleSystem.ControlPoint();
                [2] = ParticleSystem.ControlPoint();
                [3] = ParticleSystem.ControlPoint();
                [4] = ParticleSystem.ControlPoint();
                [5] = ParticleSystem.ControlPoint();
            } );

            self.manhackEventList = {}
            
        end;



        -- TODO: Add targeting vs tethering?
        -- TODO: Ignore entity if player tries teleporting?
        -- TODO: Smooth out entity motion
        DispatchBehaviour = function (self, glove)
            ---[[
            if (glove.motion.handIsClosed
            and IsValidEntity(glove.tether.movingEntity) ) then

                if (self.levitateValidity:GetValidity(glove.hand, glove.tether.movingEntity) > 0
                and glove.motion.time - glove.tether.moveTime >= Levitate.GRABBITY_DELAY
                and glove.motion.time - glove.motion.handClosedTime >= Levitate.HAND_CLOSE_GRABBITY_DELAY ) then
                    glove:PrintVerbose("Grabbity-pulled entity is valid for mid-air Levitation")
                    glove.tether:Tether(glove, glove.tether.movingEntity)
                    return true
                end

            elseif self.hasTether then

                if (self.levitateValidity:GetValidity(glove.hand, glove.tether.tetheredEntity) <= 0) then
                    if self.tetherIsValid then
                        glove:PrintVerbose("Levitation tether stopped being valid - waiting to disconnect...")
                        glove.hand:SetThink(function() self:UntetherDelay(glove) end, "UntetherDelay", self.DISCONNECT_DELAY)
                        self.tetherIsValid = false
                    end
                else
                    self.tetherIsValid = true
                end

            end
            --]]
            return false
            
        end;

        
        
        Levitate = function (self, glove, interval)
            ---[[
            local entity = glove.tether.tetheredEntity

            if glove.enabled and self.hasTether and IsValidEntity(entity) then

                interval = interval or glove.UPDATE_INTERVAL

                local player = Entities:GetLocalPlayer()
                self.entityOffset = player:TransformPointWorldToEntity(entity:GetAbsOrigin())

                local idealDistance
                if (entity:GetClassname() == "npc_manhack") then
                    idealDistance = self.levitateValidity.maxDistance - self.MAX_DISTANCE_BUFFER
                else
                    local absBounds = entity:GetBoundingMaxs() - entity:GetBoundingMins()
                    local size = math.max(absBounds.x, math.max(absBounds.y, absBounds.z))
                    idealDistance = size / 2 + self.COMFORTABLE_DISTANCE
                end

                local deltaPos = (glove.hand:GetAbsOrigin() + glove.hand:GetForwardVector() * idealDistance) - entity:GetCenter()
                local currentVelocity = GetPhysVelocity(entity)
                local desiredVelocity = deltaPos / interval
                desiredVelocity = min(desiredVelocity:Length(), self.MAX_LEVITATION_SPEED) * desiredVelocity:Normalized()
                local targetVelocity = desiredVelocity - currentVelocity
                
                entity:ApplyAbsVelocityImpulse(targetVelocity)
                SetPhysAngularVelocity(entity, glove.motion.angularVelocity)
                
                self.HAPTIC_LEVITATE:Fire(glove.hand)   -- TODO: not necessarily consistent with Levitate interval

                return interval

            end
            --]]
            glove:PrintVerbose("Levitation no longer has a valid tether")

            self:OnUntether(glove)

            return nil
            
        end;



        OnTether = function (self, glove)
            if (self.levitateValidity:GetValidity(glove.hand, glove.tether.tetheredEntity) > 0
            --and (self.grabbityValidity:GetValidity(glove.hand, glove.tether.tetheredEntity) <= 0
            --  or glove.tether.tetheredEntity == glove.tether.movingEntity) ) then
            and glove.tether.tetheredEntity == glove.tether.movingEntity) then
                glove:PrintVerbose("Tether is valid for Levitation - Levitating...")
                self:SpawnTether(glove)
                glove.tether:Untarget(glove)
                glove.alreadyFired = true
                self.hasTether = true
                glove.tether.movingEntity = nil
                if glove.tether.tetheredEntity:GetClassname() == "npc_manhack" then
                    self:ResetManhackEvents()
                    self.manhackEventList = {
                        ListenToGameEvent("player_teleport_start", function() self:DisableManhack(glove.tether.tetheredEntity) end, nil);
                        ListenToGameEvent("player_teleport_finish", function() self:ResetManhackEvents(glove.tether.tetheredEntity) end, nil);
                    }
                end
                glove.hand:SetThink(function() return self:Levitate(glove) end, "Levitating" .. glove.IDENTIFIER)
                return true
            else
                self:OnUntether(glove)
                return false
            end
        end;


        
        OnUntether = function (self, glove)
            if self.hasTether then
                glove:PrintVerbose("Levitation tether has been disconnected")
                self:ResetManhackEvents()
                glove:StopLoop("PhysCannon.HoldLp")
                if glove.motion.handState == Gesture.HAND_OPENING then
                    glove:PlaySound("PhysCannon.Drop")  -- Should it also play if your tether bends too far away?
                end
                self.hasTether = false
            end
        end;



        UntetherDelay = function (self, glove)
            --if (self.levitateValidity:GetValidity(glove.hand, glove.tether.tetheredEntity) <= 0
            if not self.tetherIsValid then
                glove:PrintVerbose("Levitation tether is still invalid - disconnecting")
                glove.tether:Untether(glove)
                glove.alreadyFired = true
            else
                glove:PrintVerbose("Levitation tether is valid again, no need to disconnect")
            end
        end;



        SpawnTether = function (self, glove)
            
            glove:PrintVerbose("Spawning Levitation tether")
            
            local entity = glove.tether.tetheredEntity

            local handSelection = Input.GetHandSelection(glove.hand)
            local handRenderable = Input.GetHandRenderable(handSelection)
            local backOfHand = handRenderable:GetRightVector()
            if (handSelection == Input.LEFT) then backOfHand = -backOfHand end
            ---[[
            -- Don't parent particles directly to hand entities!  Causes save/load crashes?
            self.PARTICLE_BEAM:SetControlPoint(0, glove.hand, handRenderable:GetAbsOrigin() + backOfHand * 4 + handRenderable:GetUpVector() * 1.5, nil, true);    -- Placeholder until I make a model
            self.PARTICLE_BEAM:SetControlPoint(1, glove.hand, handRenderable:GetAbsOrigin() + backOfHand * 3 - handRenderable:GetUpVector() * 1.5, nil, true);
            self.PARTICLE_BEAM:SetControlPoint(2, glove.hand, handRenderable:GetAbsOrigin() - backOfHand * 2.5 + handRenderable:GetUpVector() * 3, nil, true);
            self.PARTICLE_BEAM:SetControlPoint(3, entity, entity:GetCenter() + backOfHand * 0.1 + handRenderable:GetUpVector() * 0.1, nil, true);
            self.PARTICLE_BEAM:SetControlPoint(4, entity, entity:GetCenter() + backOfHand * 0.1 - handRenderable:GetUpVector() * 0.1, nil, true);
            self.PARTICLE_BEAM:SetControlPoint(5, entity, entity:GetCenter() - backOfHand * 0.1, nil, true);
            --]]
            local particles = {
                self.PARTICLE_BEAM:EnableParticleSystem(),
            }
                --[[
                self.PARTICLE_BEAM_1:Create( {
                    [0] = ParticleSystem.ControlPoint(glove.hand, handRenderable:GetAbsOrigin() + backOfHand * 4 + handRenderable:GetUpVector() * 1.5, nil, true);
                    [1] = ParticleSystem.ControlPoint(entity, entity:GetCenter() + backOfHand * 0.1 + handRenderable:GetUpVector() * 0.1, nil, true);
                } );
                self.PARTICLE_BEAM_2:Create( {   -- Placeholder until I make a model
                    [0] = ParticleSystem.ControlPoint(glove.hand, handRenderable:GetAbsOrigin() + backOfHand * 3 - handRenderable:GetUpVector() * 1.5, nil, true);
                    [1] = ParticleSystem.ControlPoint(entity, entity:GetCenter() + backOfHand * 0.1 - handRenderable:GetUpVector() * 0.1, nil, true);
                } );
                self.PARTICLE_BEAM_3:Create( {
                    [0] = ParticleSystem.ControlPoint(glove.hand, handRenderable:GetAbsOrigin() - backOfHand * 2.5 + handRenderable:GetUpVector() * 3, nil, true);
                    [1] = ParticleSystem.ControlPoint(entity, entity:GetCenter() - backOfHand * 0.1, nil, true);
                } );
                --]]
            
            glove:PlaySound("PhysCannon.Pickup")
            glove:PlaySound("PhysCannon.HoldLp", true)

            glove.hand:SetThink(function() return self:MaintainTether(glove, entity, particles) end, "MaintainLevitationBeam" .. self.PARTICLE_BEAM.IDENTIFIER)
            --]]
        end;



        MaintainTether = function (self, glove, entity, particles)

            if not glove.enabled
            or not self.hasTether
            or glove.tether.tetheredEntity ~= entity then

                glove:PrintVerbose("Levitation tether is no longer valid - removing...")

                for i, particle in pairs(particles) do
                    particle:DisableParticleSystem()--false, 0.5) -- Does it cause save/load crashes without immediate destroy? (not necessarily?)
                end
    
                return nil

            end

            self.HAPTIC_LEVITATE:Fire(glove.hand)

            return Levitate.RENDER_INTERVAL

        end;
        --]]


        DisableManhack = function (self, manhack)
            -- TODO: fix
            Glove.Print("Disabling Manhack for teleport while levitating")
            --EntFireByHandle(manhack, manhack, "BecomeTemporaryRagdoll")
        end;

        ResetManhackEvents = function (self, manhack)
            if IsValidEntity(manhack) then
                Glove.Print("Enabling Manhack after teleporting")
                --EntFireByHandle(manhack, manhack, "StopTemporaryRagdoll", "", self.DISCONNECT_DELAY)
            end
            for i, event in pairs(self.manhackEventList) do
                StopListeningToGameEvent(event)
                self.manhackEventList[i] = nil
            end
        end;



        RemoveBehaviour = function (self)
            print("Removing \"Levitate\" behaviour...")
            for i, event in pairs(self.manhackEventList) do
                StopListeningToGameEvent(event)
                self.manhackEventList[i] = nil
            end
        end;
    },

    {
        __class__name = "Levitate";

        RENDER_INTERVAL = 0.05;
        GRABBITY_DELAY = 0.25;
        HAND_CLOSE_GRABBITY_DELAY = 0.21;

        PARTICLE_BEAM_NAME = "particles/choreo/dog_grav_hand.vpcf";
    },

    nil
)



Levitate.Precache = function (context)
    print("Precaching \"Levitate\" resources")
    PrecacheResource("soundfile", "soundevents/soundevents_weapon_physcannon.vsndevts", context)
    PrecacheResource("particle", Levitate.PARTICLE_BEAM_NAME, context)
end
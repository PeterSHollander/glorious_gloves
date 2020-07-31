require "gloves/behaviours/grabbity"

local CustomDebug = require "/debug"



Punt = class (

    {
        GESTURE_COOLDOWN = 0.67;

        PUNT_FORCE = 5000000;                   -- The force punting will exert on the object, in footpounds I guess? Foot-kilograms...?
        PUNT_MAX_SPEED = 1000;                  -- Most entities will probably be subject to this speed cap.
        PUNT_MASS_INCREASE_DURATION = 1.2;
        PUNT_DRYFIRE_DURATION = 0.1;
        HEADCRAB_PUNT_SPEED = 500;
        ANTLION_PUNT_SPEED = 220;
        BOARD_PUNT_SPEED = 2500;
        PADLOCK_PUNT_SPEED = 1500;
        DOOR_PUNT_SPEED = 400;
        PUSH_SPEED_MULTIPLIER = 5;

        EXPLODE_UPDATE_INTERVAL = 0.025;
        MANHACK_UPDATE_INTERVAL = 0.01;
        EXPLODE_DURATION = 5;
        MANHACK_DURATION = 0.6;
        EXPLODE_DECELERATION_THRESHOLD = 10000;
        MANHACK_DECELERATION_THRESHOLD = 35000;
        EXPLODE_VELOCITY_SLEEP = 10;

        PARTICLE_SHOCK;



        puntValidity;
        pushValidity;
        puntAutotargetValidity;

        puntAngleOffset;

        gesture;
        gestureTime;

        headcrabDamage;
        padlockDamage;
        manhackDamage;
        flippedAntlions;



        constructor = function (self, glove)

            print("Initializing \"Punt\" behaviour...")

            -- TODO: Do we need an accurate damage force?
            self.headcrabDamage = CreateDamageInfo(Entities:GetLocalPlayer(), glove.hand, Vector(0, 0, 0), Vector(0, 0, 0), 5, DMG_PHYSGUN)
            self.padlockDamage = CreateDamageInfo(Entities:GetLocalPlayer(), glove.hand, Vector(0, 0, 0), Vector(0, 0, 0), 5, DMG_BULLET)
            self.manhackDamage = CreateDamageInfo(Entities:GetLocalPlayer(), glove.hand, Vector(0, 0, 0), Vector(0, 0, 0), 100, DMG_BULLET)
            self.antlionDamage = CreateDamageInfo(Entities:GetLocalPlayer(), glove.hand, Vector(0, 0, 0), Vector(0, 0, 0), Punt.ANTLION_HEALTH, DMG_PHYSGUN)
            self.flippedAntlions = {}

            self.puntValidity = Validity( {
                minDistance = 10;
                maxDistance = 200;
                minMass = 0.2;
                maxMass = 5000;
                maxSize = 750;
                minIncidence = 0.8;
                requireCentre = false;  -- Not implemented yet
                scaleMassWithDistance = true;  -- Also scales valid size with distance
                ignoreClass = {
                    "player",
                    "npc_.+",
                    "prop_animinteractable",
                };
                allowClassOverride = {
                    "npc_manhack",
                    "npc_headcrab.*",
                    "npc_antlion.*",
                };
                ignoreModel = {
                    ".*doorhandle.*",
                    ".*zombie.*",
                    ".*combine_grunt.*",
                    ".*combine_captain.*",
                    ".*combine_soldier.*",
                    ".*combine_suppressor.*",
                    ".*citizen.*",
                    ".*worker.*",
                    ".*metrocop_choreo.*",
                };
                allowModelOverride = {
                    ".*citizens_female_upper_cotton_jacket_hanging.*",
                    ".*hazmat_worker_.+",
                };
                importantClass = {
                    "npc_antlion.*",
                    "npc_headcrab.*",
                    "npc_manhack",
                    --"prop_door_rotating_physics",
                };
                importantModel = {
                    ".*industrial_board_%d%d.vmdl",
                    ".*padlock%d%d%da.*",
                    -- barrels?
                    -- grenades?
                };
            } )

            self.pushValidity = self.puntValidity:Copy( {
                maxDistance = glove.detector.LENGTH;
                scaleMassWithDistance = false;
            } )

            self.puntAutotargetValidity = Validity( {
                minDistance = 0;
                maxDistance = 5000;
                maxMass = 5000;
                maxSize = 5000;
                minIncidence = 0.9;
                angleOffset = QAngle(3, -5, 0);
                requireCentre = false;
                ignoreClass = {
                    ".*",
                };
                allowClassOverride = {
                    "npc_.*"
                };
                allowModelOverride = {

                };
            } )
            
            if Input.GetHandSelection(glove.hand) == Input.RIGHT then self.puntAutotargetValidity.angleOffset.y = -self.puntAutotargetValidity.angleOffset.y end

            self.gesture = Gesture( {
                handState = Gesture.HAND_CLOSED;
                motionType = Gesture.MOTION_ACCELERATION;
                motionDirection = Gesture.MOTION_INCREASING;
                --useVelocityDirection = true;
                motionThreshold = 775;
                minMotionIncidence = 0.8;
            } )

            -- Flip the yaw if this is the right hand, as the palm is now towards the negative y-axis
            local angleOffset = QAngle(Grabbity.GESTURE_ANGLE_OFFSET_THUMB, Grabbity.GESTURE_ANGLE_OFFSET_PALM, 0)
            if (Input.GetHandSelection(glove.hand) == Input.RIGHT) then angleOffset.y = -angleOffset.y end
            
            self.grabbityGesture = Gesture(Grabbity.GESTURE)
            self.grabbityGesture.angleOffset = angleOffset
            
            self.PARTICLE_SHOCK = ParticleSystem("particles/weapon_fx/gg_electric_zap.vpcf")

            self.PARTICLE_SHOCK:Create( {
                [0] = ParticleSystem.ControlPoint();
                [1] = ParticleSystem.ControlPoint();
            } );

            self.gestureTime = Time()

        end;



        DispatchBehaviour = function (self, glove)
            
            if (self.gesture:IsGesturing(glove.motion)
            and not self.grabbityGesture:IsGesturing(glove.motion)
            and glove.motion.time - self.gestureTime >= self.GESTURE_COOLDOWN ) then

                glove:PrintVerbose("Punt gesture recognized")

                local entity = nil
                local delay = 0
                
                if IsValidEntity(glove.tether.tetheredEntity) then
                --if self.puntValidity:GetValidity(glove.hand, glove.tether.tetheredEntity) > 0 then
                    entity = glove.tether.tetheredEntity
                else
                    entity = self.puntValidity:FilterBestEntity(glove.hand, glove.detector.entityList)
                end

                glove.tether:Untether(glove)
                
                if self.puntValidity:GetValidity(glove.hand, entity) > 0 then

                    glove:PrintVerbose("Punt target is within range, Punting...")

                    delay = self:InteractWithEntity(glove, entity)

                    entity:SetThink(function() self:Punt(glove, entity) end, "GloriousGlove" .. glove.IDENTIFIER .. "PuntDelay", delay)

                else

                    glove:PrintVerbose("Punt target is not within range")

                    if not IsValidEntity(entity) then
                        entity = self.pushValidity:FilterBestEntity(glove.hand, glove.detector.entityList)
                    end

                    if entity then

                        glove:PrintVerbose("Punt-push target is within range, Pushing...")

                        delay = self:InteractWithEntity(glove, entity)
    
                        entity:SetThink(function() self:Push(glove, entity) end, "GloriousGlove" .. glove.IDENTIFIER .. "PuntDelay", delay)
    
                    end

                    glove:PlaySound("PhysCannon.DryFire")
                    Punt.HAPTIC_DRYFIRE:Fire(glove.hand)

                end
                
                self.gestureTime = glove.motion.time
                glove.alreadyFired = true

                return true

            end
        end;



        Punt = function (self, glove, entity)

            self:SpawnShock(glove, entity)  -- Spawn shock at the start of Punt so that if we kill/break it without a delay, the shock still renders

            local classname = entity:GetClassname()
            local modelName = entity:GetModelName()

            local puntSpeed = self.PUNT_FORCE / entity:GetMass() * glove.UPDATE_INTERVAL
            if classname == "npc_manhack" then  -- Don't cap manhack speed as pathfinding resists punting
                glove:PrintVerbose("Punt target is Manhack - watching for impact")
                self:WatchForImpactManhack(glove, entity, "Break")
            elseif classname:match("npc_headcrab.*") then
                glove:PrintVerbose("Punt target is Headcrab - damaging")
                self.headcrabDamage:SetDamagePosition(entity:GetCenter())
                entity:SetThink(function() entity:TakeDamage(self.headcrabDamage) end, "WaitToTakeDamage", 1/30)
                puntSpeed = self.HEADCRAB_PUNT_SPEED
            elseif modelName:match(".*padlock%d%d%da.*") then
                glove:PrintVerbose("Punt target is padlock - damaging")
                self.padlockDamage:SetDamagePosition(entity:GetCenter())
                entity:SetThink(function() entity:TakeDamage(self.padlockDamage) end, "WaitToTakeDamage", 1/30)
                puntSpeed = self.PADLOCK_PUNT_SPEED
            elseif classname:match("npc_antlion.*") then
                glove:PrintVerbose("Punt target is Antlion - flipping")
                if entity:GetGraphParameter("b_flip") then
                    glove:PrintVerbose("Antlion is flipped - damaging")
                    self.antlionDamage:SetDamage(0.5 * (Punt.ANTLION_HEALTH / Punt.MASS_MULTIPLIER.NORMAL) * Punt.MassMultiplier())    -- Update every time in case the user changes difficulty mid-game
                    self.antlionDamage:SetDamagePosition(entity:GetCenter())
                    entity:SetThink(function() entity:TakeDamage(self.antlionDamage) end, "WaitToTakeDamage", 1/30)
                end
                EntFireByHandle(glove.hand, entity, "SetAnimgraphParameter", "b_flip=true")
                entity:SetBodygroup(7, 1)
                entity:RegisterAnimTagListener(function(tag)
                    if tag == "Finished_Flip" then
                        glove:PrintVerbose("Antlion finished flip, disabling punt damage")
                        EntFireByHandle(glove.hand, entity, "SetAnimgraphParameter", "b_flip=false")
                        entity:SetBodygroup(7, 0)   -- TODO: Will reset pulsing abdomen even if the antlion is dismembered
                        entity:UnregisterAnimTagListener(nil)
                    end
                end)
                --[[ -- TakeDamage() does not dismember antlions
                local tRaycast = {
                    startpos = glove.hand:GetCenter();
                    endpos = entity:GetCenter();
                    ignore = Entities:GetLocalPlayer();
                    --mask = ?
                }
                TraceLine(tRaycast)
                if tRaycast.hit then
                    print("Damaging Antlion")
                    self.antlionDamage:SetDamagePosition(tRaycast.pos)
                    self.antlionDamage:SetDamageForce((tRaycast.endpos - tRaycast.startpos):Normalized() * 600)
                    CustomDebug.DrawOrigin(tRaycast.pos, glove.hand:GetForwardVector(), glove.hand:GetRightVector(), glove.hand:GetUpVector(), 3, true, 5)
                    entity:SetThink(function() entity:TakeDamage(self.antlionDamage) end, "WaitToTakeDamage", 1/30)
                end
                --]]

                puntSpeed = self.ANTLION_PUNT_SPEED
            elseif modelName:match(".*industrial_board_%d%d.vmdl") then
                glove:PrintVerbose("Punt target is board - breaking")
                puntSpeed = self.BOARD_PUNT_SPEED
                EntFireByHandle(glove.hand, entity, "Break", "", 1/30)
            elseif classname:match("prop_door_rotating_physics") then
                glove:PrintVerbose("Punt target is door - capping speed")
                puntSpeed = self.DOOR_PUNT_SPEED
            else
                puntSpeed = math.min(puntSpeed, self.PUNT_MAX_SPEED)
                entity = self:PrepareIfExplosive(entity, glove)
                glove:PrintVerbose("Increasing mass to do more physics damage")
                self:TemporarilyIncreaseMass(entity)    -- To do more phys damage TODO: depending on difficulty
            end

            -- TODO: Should the orientation reference be set from handToEntity rather than hand direction?
            local targetEntity = self.puntAutotargetValidity:FilterBestEntity(entity, glove.detector.entityList, glove.hand:GetAngles())
            local puntDirection
            if IsValidEntity(targetEntity) then
                glove:PrintVerbose("Punt autotarget (" .. targetEntity:GetClassname() .. ") found")
                puntDirection = targetEntity:GetCenter() - entity:GetCenter()
            else
                puntDirection = ApplyAngleOffset(entity, self.puntAutotargetValidity.angleOffset, glove.hand:GetForwardVector(), glove.hand:GetUpVector())
            end
            local puntVelocity = puntSpeed * puntDirection

            entity:ApplyAbsVelocityImpulse(puntVelocity)

        end;



        Push = function (self, glove, entity)

            local entityVelocity = glove.motion.force / entity:GetMass() * self.PUNT_DRYFIRE_DURATION
            local handToEntity = entity:GetCenter() - glove.hand:GetAbsOrigin()
            local entitySpeed = math.min(entityVelocity:Length(), glove.motion.velocity:Length() * self.PUSH_SPEED_MULTIPLIER)
            entityVelocity = entitySpeed * handToEntity:Normalized()

            entity:ApplyAbsVelocityImpulse(entityVelocity)

        end;



        SpawnShock = function (self, glove, entity)
            
            glove:PrintVerbose("Spawning Punt shock")
            
            local entity = entity or glove.tether.tetheredEntity

            self.PARTICLE_SHOCK:SetControlPoint(0, glove.hand, nil, QAngle(0, 0, 0), true);   -- 0 angles so the electricity arcs vertically (TODO: arc angle still parented to hand)
            self.PARTICLE_SHOCK:SetControlPoint(1, entity, entity:GetCenter(), nil, true);
            
            local particles = {
                self.PARTICLE_SHOCK:EnableParticleSystem(),
            }

            glove:PlaySound("PhysCannon.Launch")
            Punt.HAPTIC_LAUNCH:Fire(glove.hand)

            glove.hand:SetThink(function() self:RemoveShock(particles) end, "WaitToDelete" .. self.PARTICLE_SHOCK.IDENTIFIER .. "PuntShock", 0.5)

        end;

        RemoveShock = function (self, particles)
            Glove.Print("Removing Punt shock particle system")
            for i, particle in pairs(particles) do
                particle:DisableParticleSystem()
            end
        end;



        InteractWithEntity = function (self, glove, entity)
            local delay = 0
            if entity:GetClassname() == "prop_door_rotating_physics" then
                glove:PrintVerbose("Punted entity is door - Interacting and delaying")
                EntFireByHandle(glove.hand, entity, "GravityGunPull")--"InteractStart")
                --delay = 1/60    -- TODO: Do we need InteractStart since we're using RetractLatch now?
                --EntFireByHandle(glove.hand, entity, "RetractLatch", "", delay)
                delay = Grabbity.DOOR_PULL_DELAY
                --EntFireByHandle(glove.hand, entity, "InteractStop", "", delay + Grabbity.DOOR_PULL_DELAY)
            elseif entity:GetModelName():find("oildrum001") then
                glove:PrintVerbose("Punted entity is oil drum - Interacting and delaying just in case motion is disabled")
                EntFireByHandle(glove.hand, entity, "EnableMotion") -- Annoying overhead to ensure you can punt the instructive barrels in a2_pistol out of the way
                delay = 1/30
            end
            return delay
        end;



        TemporarilyIncreaseMass = function (self, entity)
            local multiplier = Punt.MassMultiplier()
            entity:SetMass(entity:GetMass() * multiplier)
            entity:SetThink(function() self:RevertMass(entity, multiplier) end, "TemporarilyIncreaseMass" .. UniqueString(), self.PUNT_MASS_INCREASE_DURATION)
        end;

        RevertMass = function (self, entity, multiplier)
            Glove.Print("Reverting Punted entity's mass to its original value")
            entity:SetMass(entity:GetMass() / multiplier)
        end;



        PrepareIfExplosive = function (self, entity, glove)

            for i, model in pairs(Punt.EXPLOSIVE_MODELS) do
                if (entity:GetModelName() == model) then
                    glove:PrintVerbose("Punted entity is explosive - watching for impact")
                    self:WatchForImpact(entity, "Break")
                end
            end

            for i, classname in pairs(Punt.GRENADE_CLASSNAMES) do
                if (entity:GetClassname() == classname) then
                    glove:PrintVerbose("Punted entity is grenade - respawning and watching for impact")
                    entity:FireOutput("OnExplode", entity, entity, {}, 0)   -- TODO: Confirm this fires before deleting? Also this will fire when you launch, not when it explodes
                    local origin = entity:GetAbsOrigin()
                    local angles = entity:GetAngles()
                    local scale = tostring(entity:GetAbsScale())
                    local velocity = GetPhysVelocity(entity)
                    local angularVelocity = GetPhysAngularVelocity(entity)
                    local tProperties = {
                        targetname = entity:GetName();
                        origin = tostring(origin.x) .." ".. tostring(origin.y) .." ".. tostring(origin.z);
                        angles = tostring(angles.x) .." ".. tostring(angles.y) .." ".. tostring(angles.z);
                        scales = scale .." ".. scale .." ".. scale
                    }
                    entity:RemoveSelf()
                    entity = SpawnEntityFromTableSynchronous(classname, tProperties)
                    entity:ApplyAbsVelocityImpulse(velocity)
                    SetPhysAngularVelocity(entity, angularVelocity)
                    self:WatchForImpact(entity, "ArmGrenade", "0.01")
                end
            end

            return entity

        end;



        WatchForImpact = function (self, entity, action, parameter)

            local refs = {
                prevVelocity = GetPhysVelocity(entity);
                duration = self.EXPLODE_DURATION;
            }
            entity:SetThink(function() return self:CalculateDeceleration(entity, refs, action, parameter) end, "WatchForImpact", self.EXPLODE_UPDATE_INTERVAL)

        end;



        CalculateDeceleration = function (self, entity, refs, action, parameter)

            local currentVelocity = GetPhysVelocity(entity)
            local acceleration = (currentVelocity - refs.prevVelocity) / self.EXPLODE_UPDATE_INTERVAL

            if (acceleration:Length() > self.EXPLODE_DECELERATION_THRESHOLD
            and currentVelocity:Length() < refs.prevVelocity:Length()) then
                Glove.Print("Punted explosive entity has decelerated significantly - exploding")
                EntFireByHandle(entity, entity, action, parameter)
                return nil
            elseif (currentVelocity:Length() < self.EXPLODE_VELOCITY_SLEEP or refs.duration <= 0) then
                Glove.Print("Punted explosive entity has come to rest without decelerating signicantly - stopping watching for deceleration")
                return nil
            else
                refs.prevVelocity = currentVelocity
                refs.duration = refs.duration - self.EXPLODE_UPDATE_INTERVAL
                return self.EXPLODE_UPDATE_INTERVAL
            end
            
        end;



        WatchForImpactManhack = function (self, glove, entity, action, parameter)
            local refs = {
                glove = glove;
                prevPosition = entity:GetAbsOrigin();
                prevVelocity = Vector(0, 0, 0);
                duration = self.MANHACK_DURATION
            }
            entity:SetThink(function() return self:CalculateDecelerationManhack(entity, refs, action, parameter) end, "WatchForImpact", self.MANHACK_UPDATE_INTERVAL)
        end;



        -- Manhacks jitter because they're not just physics objects.  GetPhysVelocity will report inconsistently.  Calculate velocity ourselves.
        CalculateDecelerationManhack = function (self, entity, refs, action, parameter)

            if (refs.glove.tether.tetheredEntity ~= entity) then    -- In case you want to grab it back, that shouldn't break the manhack

                local currentVelocity = (entity:GetAbsOrigin() - refs.prevPosition) / refs.glove.UPDATE_INTERVAL
                local acceleration = (currentVelocity - refs.prevVelocity) / refs.glove.UPDATE_INTERVAL

                if (acceleration:Length() > self.MANHACK_DECELERATION_THRESHOLD
                and currentVelocity:Length() < refs.prevVelocity:Length()) then
                    Glove.Print("Punted Manhack has decelerated significantly - breaking")
                    --EntFireByHandle(entity, entity, action, parameter)
                    entity:TakeDamage(self.manhackDamage)
                    return nil
                elseif (currentVelocity:Length() < self.EXPLODE_VELOCITY_SLEEP or refs.duration <= 0) then
                    Glove.Print("Punted Manhack has stabilized without decelerating significantly - stopping watching for impact")
                    return nil
                else
                    refs.prevVelocity = currentVelocity
                    refs.prevPosition = entity:GetAbsOrigin()
                    refs.duration = refs.duration - refs.glove.UPDATE_INTERVAL
                    return refs.glove.UPDATE_INTERVAL
                end

            end

            return nil
            
        end;



        RemoveBehaviour = function (self)
            print("Removing \"Punt\" behaviour...")
            DestroyDamageInfo(self.headcrabDamage)
            DestroyDamageInfo(self.padlockDamage)
            DestroyDamageInfo(self.manhackDamage)
            DestroyDamageInfo(self.antlionDamage)
        end;
    },

    {
        __class__name = "Punt";

        MASS_MULTIPLIER = {
            STORY = 10;      -- 1 knocked hit on Antlion; 1 cardboard box hit on Zombie; 1 plaster can hit on Heavy Soldier
            EASY = 1.5;        -- 1 knocked hit on Antlion; 1 plaster can hit on Zombie; 1 barrel hit on Heavy Soldier
            NORMAL = 0.5;    -- 2 knocked hits on Antlion; 1 (close) barrel hit on Zombie; 2 barrel hits on Combine
            HARD = 0.25;     -- 4 knocked hits on Antlion; 2 barrel hits on Zombie; 3 barrel hits on Combine
        };
        DIFFICULTY = {
            STORY = 0;
            EASY = 1;
            NORMAL = 2;
            HARD = 3;
        };
        ANTLION_HEALTH = 95;

        -- Haven't figured out how to access KeyValue prop data yet, so we're just gonna brute force the explosive objects
        EXPLOSIVE_MODELS = {
            "models/props/explosive_jerrican_1.vmdl",
            "models/props/propane_canister_001/explosive_propane_canister_001.vmdl",
            "models/props_c17/oildrum001_explosive.vmdl",
        };
        GRENADE_CLASSNAMES = {
            "item_hlvr_grenade_frag",
        };
        WATCH_FOR_IMPACT_LABEL = "WatchForImpact";

        HAPTIC_LAUNCH = HapticSequence(0.263, 1, 1/438);--1/74);    -- 1/74 is less than the framerate, and since it fires less than all the other maxed-out haptics, it feels a lot weaker
        HAPTIC_DRYFIRE = HapticSequence(0.078, 0.36, 1/382);
    },

    nil
)



Punt.MassMultiplier = function ()
    local difficulty = Convars:GetInt("skill")
    if difficulty == Punt.DIFFICULTY.STORY then
        return Punt.MASS_MULTIPLIER.STORY
    elseif difficulty == Punt.DIFFICULTY.EASY then
        return Punt.MASS_MULTIPLIER.EASY
    elseif difficulty == Punt.DIFFICULTY.HARD then
        return Punt.MASS_MULTIPLIER.HARD
    else
        return Punt.MASS_MULTIPLIER.NORMAL
    end
end



Punt.Precache = function (context)
    print("Precaching \"Punt\" resources")
    PrecacheResource("soundfile", "soundevents/soundevents_weapon_physcannon.vsndevts", context)
    PrecacheResource("particle", "particles/weapon_fx/gg_electric_zap.vpcf", context)
end
require "device/input"
require "gloves/lib/gesture"
require "gloves/lib/validity"
require "gloves/lib/motion"
require "/customutils"

local CustomDebug = require "/debug"



Grabbity = class(

    {
        TARGET_LOST_DELAY = 0.5;
        TETHER_LOST_DELAY = 0.05;

        MIN_AIR_TIME = 0.4;
        MAX_AIR_TIME = 1.0;
        TOO_HEAVY_MIN_AIR_TIME = 0.12;
        TOO_HEAVY_MAX_AIR_TIME = 0.45;
        TOO_HEAVY_MAX_AIR_TIME_TARGET = 2.0;
        MAX_ACCELERATION = 750;
        FORCE_IMPULSE_DURATION = 0.1;
        MANHACK_UPDATE_INTERVAL = 1 / 90;  -- TODO: Make dependant on framerate?
        
        HIGHLIGHT_ALPHA = 1;
        TETHER_ALPHA = 1;
        TETHER_ALTERNATE_ALPHA = 1;
        TETHER_EMBER_EMISSION_RATE = 1;
        TETHER_EMBER_ALPHA = 1;

        HAPTIC_TETHER;

        PARTICLE_HIGHLIGHTS;
        PARTICLE_TETHER;
        PARTICLE_EMBERS;



        gesture;
        targetValidity;
        tetherValidity;

        hasTarget;
        hasTether;

        targetIndicator;

        eventList;

        enabled;
        nearVortEnergy;



        constructor = function (self, glove)

            print("Initializing \"Grabbity\" behaviour...")

            self.targetIndicator = false
            self.hasTarget = false
            self.hasTether = false

            self.enabled = true
            self.nearVortEnergy = false

            local validityOverride = Grabbity.VALIDITY_OVERRIDE
            self.targetValidity = glove.tether.targetValidity:Copy(validityOverride)

            validityOverride.maxDistance = self.targetValidity.maxDistance + Tether.TETHER_DISTANCE_BUFFER;
            validityOverride.minIncidence = 0.5;
            self.tetherValidity = glove.tether.tetherValidity:Copy(validityOverride)

            -- Flip the yaw if this is the right hand, as the palm is now towards the negative y-axis
            local angleOffset = QAngle(Grabbity.GESTURE_ANGLE_OFFSET_THUMB, Grabbity.GESTURE_ANGLE_OFFSET_PALM, 0)
            if (Input.GetHandSelection(glove.hand) == Input.RIGHT) then angleOffset.y = -angleOffset.y end
            
            self.gesture = Gesture(Grabbity.GESTURE)
            self.gesture.angleOffset = angleOffset

            self.HAPTIC_TETHER = HapticSequence(glove.UPDATE_INTERVAL, 0.01, 0.05)--1/393)

            self.PARTICLE_HIGHLIGHTS = {
                -- 20 particle systems should be enough; certainly more than a user would ever notice
                ParticleSystem("particles/weapon_fx/grabbity_gloves.vpcf");
                ParticleSystem("particles/weapon_fx/grabbity_gloves.vpcf");
                ParticleSystem("particles/weapon_fx/grabbity_gloves.vpcf");
                ParticleSystem("particles/weapon_fx/grabbity_gloves.vpcf");
                ParticleSystem("particles/weapon_fx/grabbity_gloves.vpcf");
                ParticleSystem("particles/weapon_fx/grabbity_gloves.vpcf");
                ParticleSystem("particles/weapon_fx/grabbity_gloves.vpcf");
                ParticleSystem("particles/weapon_fx/grabbity_gloves.vpcf");
                ParticleSystem("particles/weapon_fx/grabbity_gloves.vpcf");
                ParticleSystem("particles/weapon_fx/grabbity_gloves.vpcf");
                ParticleSystem("particles/weapon_fx/grabbity_gloves.vpcf");
                ParticleSystem("particles/weapon_fx/grabbity_gloves.vpcf");
                ParticleSystem("particles/weapon_fx/grabbity_gloves.vpcf");
                ParticleSystem("particles/weapon_fx/grabbity_gloves.vpcf");
                ParticleSystem("particles/weapon_fx/grabbity_gloves.vpcf");
                ParticleSystem("particles/weapon_fx/grabbity_gloves.vpcf");
                ParticleSystem("particles/weapon_fx/grabbity_gloves.vpcf");
                ParticleSystem("particles/weapon_fx/grabbity_gloves.vpcf");
                ParticleSystem("particles/weapon_fx/grabbity_gloves.vpcf");
                ParticleSystem("particles/weapon_fx/grabbity_gloves.vpcf");
            }
            self.PARTICLE_TETHER = ParticleSystem("particles/weapon_fx/gravity_glove_hand_rope.vpcf")
            self.PARTICLE_EMBERS = ParticleSystem("particles/weapon_fx/gravity_glove_hand_bits.vpcf")
            
            self.PARTICLE_TETHER:Create( {
                [1] = ParticleSystem.ControlPoint();
                [10] = ParticleSystem.ControlPoint(); -- What does this CP do? It's only used in "Calculate Vector Attribute - Normal"
                [11] = ParticleSystem.ControlPoint();
                [20] = ParticleSystem.ControlPoint(nil, Vector(self.TETHER_ALTERNATE_ALPHA, 0, 0));
                [22] = ParticleSystem.ControlPoint(nil, Vector(self.TETHER_ALPHA, 0, 0));
            } );
            self.PARTICLE_EMBERS:Create( {
                [0] = ParticleSystem.ControlPoint();--nil, nil, QAngle(0, 0, 0));
                [1] = ParticleSystem.ControlPoint();
                [11] = ParticleSystem.ControlPoint();
                [20] = ParticleSystem.ControlPoint(nil, Vector(self.TETHER_EMBER_EMISSION_RATE, 0, 0));
                [22] = ParticleSystem.ControlPoint(nil, Vector(self.TETHER_EMBER_ALPHA, 0, 0))
            } );

            self.eventList = {
                ListenToGameEvent("item_pickup", function(context) self:CheckPickup(context, glove) end, nil)  -- What's the purpose of the third parameter, set nil here?
            }

            glove.hand:SetThink(function() return self:WatchForVortEnergy(glove) end, "Watching" .. glove.IDENTIFIER .. "ForGrabbity" .. UniqueString() .. "VortEnergy")
            
        end;



        DispatchBehaviour = function (self, glove)

            if self.enabled then

                if self.hasTether then
                    if (self.tetherValidity:GetValidity(glove.hand, glove.tether.tetheredEntity) <= 0) then
                        glove:PrintVerbose("Grabbity tether has become invalid")
                        self:OnUntether(glove)
                        glove.alreadyFired = true
                    end
                end

                if not glove.alreadyFired then

                    if glove.tether.tetheredEntity then

                        local forwardReference = glove.tether.tetheredEntity:GetCenter() - glove.hand:GetAbsOrigin()

                        --[[
                        local forward = ApplyAngleOffset(nil, self.gesture.angleOffset, glove.motion.angles:Forward(), glove.motion.angles:Up())
                        CustomDebug.DrawCone(glove.hand:GetAbsOrigin(), forward, glove.hand:GetUpVector(), self.gesture.maxMotionIncidence, 10, 255, 0, 0, true, glove.UPDATE_INTERVAL)
                        forward = ApplyAngleOffset(nil, self.gesture.angleOffset, forwardReference, glove.motion.angles:Up())
                        CustomDebug.DrawCone(glove.hand:GetAbsOrigin(), forward, glove.hand:GetUpVector(), self.gesture.maxMotionIncidence, 10, 127, 0, 0, true, glove.UPDATE_INTERVAL)
                        --]]

                        if (self.gesture:IsGesturing(glove.motion, forwardReference))
                        and (glove.tether.tetheredEntity:GetCenter() - glove.hand:GetCenter()):Length() > self.tetherValidity.minDistance then
                            glove:PrintVerbose("Grabbity gesture recognized")
                            self:AccelerateToHand(glove)
                            glove.alreadyFired = true
                            return true
                        end
                    end
                end
            end

            return false

        end;



        AccelerateToHand = function (self, glove, interval)
            
            interval = interval or glove.UPDATE_INTERVAL

            glove.tether.movingEntity = nil

            if glove.tether.tetheredEntity then

                glove:PrintVerbose("Glove is tethered, determining Grabbity pull style")

                glove.tether.movingEntity = glove.tether.tetheredEntity
                glove.tether.moveTime = Time()
                local parent = glove.tether.movingEntity:GetMoveParent()
                
                local oneshot = false

                -- Gnarly way to brute force letting the user grab items off of NPCs and ragdolls
                -- Probably breaks some achievements, I/O, and game events
                glove.tether.movingEntity = self:RespawnIfItemAttachment(glove.tether.movingEntity, glove)
                
                local delay = 0
                local refs = { increment = 0 }
                local aggressiveVelocity = false

                local handToEntity = glove.tether.movingEntity:GetCenter() - glove.hand:GetAbsOrigin()
                
                if GetPhysVelocity(glove.tether.movingEntity) == Vector(0, 0, 0) then
                    glove:PrintVerbose("Grabbity entity is stationary - Interacting and delaying just in case motion is disabled")
                    EntFireByHandle(glove.hand, glove.tether.movingEntity, "EnableMotion") -- Annoying overhead to ensure you can grab the few resin that are stuck in xen goop
                    delay = FrameTime()
                end

                if self.hasTether then

                    glove:PrintVerbose("Tether is valid for Grabbity, accelerating to hand")

                    local distanceFactor = (handToEntity:Length() - self.tetherValidity.minDistance) / (self.tetherValidity.maxDistance - self.tetherValidity.minDistance)

                    refs.initialVelocity = true
                    refs.duration = Lerp(distanceFactor, self.MIN_AIR_TIME, self.MAX_AIR_TIME);
                    
                    -- TODO: Clean
                    local entityClassname = glove.tether.movingEntity:GetClassname()
                    if entityClassname == "prop_reviver_heart" then
                        local batteryPost = Entities:FindByModelWithin(nil, "models/props_combine/combine_battery/combine_battery_post.vmdl", glove.tether.movingEntity:GetCenter(), 50)
                        if IsValidEntity(batteryPost) then
                            local trigger = Entities:FindByClassnameNearest("trigger_multiple", glove.tether.movingEntity:GetCenter(), 10)
                            if IsValidEntity(trigger) then
                                local heart = glove.tether.movingEntity
                                local origin = heart:GetAbsOrigin()
                                local angles = heart:GetAngles()
                                local scale = tostring(heart:GetAbsScale())
                                local tProperties = {
                                    targetname = heart:GetName();
                                    origin = tostring(origin.x) .." ".. tostring(origin.y) .." ".. tostring(origin.z);
                                    angles = tostring(angles.x) .." ".. tostring(angles.y) .." ".. tostring(angles.z);
                                    scales = scale .." ".. scale .." ".. scale;
                                }
                                glove.tether.movingEntity:RemoveSelf()
                                glove.tether.movingEntity = SpawnEntityFromTableSynchronous("prop_reviver_heart", tProperties)
                                trigger:FireOutput("OnEndTouch", glove.tether.movingEntity, trigger, nil, 0)
                                glove:PrintVerbose("Grabbity entity is lightning dog heart near battery post - releasing and delaying velocity impulse")
                                --glove.tether.movingEntity:SetAbsOrigin(glove.tether.movingEntity:GetAbsOrigin() + (glove.hand:GetCenter() - glove.tether.movingEntity:GetCenter()):Normalized() * 7)
                                --EntFireByHandle(glove.hand, glove.tether.movingEntity, "SetAttachedToSocket", "0")
                                --EntFireByHandle(glove.hand, glove.tether.movingEntity, "ClearParent", "", 0)
                                --EntFireByHandle(glove.hand, glove.tether.movingEntity, "EnableMotion", "", 0/30)
                                --EntFireByHandle(glove.hand, glove.tether.movingEntity, "Wake", "", 0/30)
                                --delay = 2/30
                                aggressiveVelocity = true
                            end
                        end
                    elseif entityClassname == "point_vort_energy" then
                        --print("Vort energy is currently unsupported by the Glorious Gloves!")
                    end

                    glove:PlaySound("Grabbity.Grab")
                    Grabbity.HAPTIC_GRAB:Fire(glove.hand)

                    local entity = glove.tether.movingEntity
                    local parentName = nil if parent then parentName = parent:GetClassname() end
                    local tInfo = {
                        ["userid"] = Entities:GetLocalPlayer():GetUserID();
                        ["entindex"] = entity:GetEntityIndex();
                        ["item"] = entity:GetClassname();
                        ["item_name"] = entity:GetName();
                        ["hand_is_primary"] = (Input.GetHandSelection(glove.hand) == Input.RIGHT); -- TODO: support left hand dominance
                        ["vr_tip_attachment"] = Input.GetEventHandSelection(glove.hand);
                        ["wasparentedto"] = parentName;
                    }

                    FireGameEvent("grabbity_glove_pull", tInfo)

                else

                    glove:PrintVerbose("Tether is not valid for Grabbity, lazily pulling to hand")

                    local distanceFactor = (handToEntity:Length() - glove.tether.tetherValidity.minDistance) / (glove.tether.tetherValidity.maxDistance - glove.tether.tetherValidity.minDistance)
                    local massFactor = (glove.tether.movingEntity:GetMass() - glove.tether.tetherValidity.minMass) / (glove.tether.tetherValidity.maxMass - glove.tether.tetherValidity.minMass)
                    local durationFactor = (massFactor * massFactor + distanceFactor * distanceFactor) / 2
                    
                    refs.initialVelocity = false
                    refs.durationTarget = Lerp(durationFactor, self.TOO_HEAVY_MAX_AIR_TIME, self.TOO_HEAVY_MAX_AIR_TIME_TARGET);
                    refs.duration = Lerp(1 - durationFactor, self.TOO_HEAVY_MIN_AIR_TIME, self.TOO_HEAVY_MAX_AIR_TIME);
                    
                    if glove.tether.movingEntity:GetClassname() == "prop_door_rotating_physics" then
                        glove:PrintVerbose("Grabbity entity is door - calling interaction I/O and delaying velocity impulse")
                        EntFireByHandle(glove.hand, glove.tether.movingEntity, "InteractStart")
                        delay = Grabbity.DOOR_PULL_DELAY
                    end
                    
                    glove:GlowClaws()
                    glove:PlaySound("PhysCannon.TooHeavy")

                    Grabbity.HAPTIC_TOO_HEAVY:Fire(glove.hand)

                end

                if (glove.tether.movingEntity:GetClassname() == "npc_manhack") then
                    glove:PrintVerbose("Grabbity entity is Manhack - increasing update interval")
                    interval = self.MANHACK_UPDATE_INTERVAL
                    aggressiveVelocity = true
                end

                if glove.tether.movingEntity:GetClassname() == "item_hlvr_clip_shotgun_single" then
                    local shells = Entities:FindAllByClassnameWithin("item_hlvr_clip_shotgun_single", glove.tether.movingEntity:GetCenter(), Grabbity.SHOTGUN_SHELL_SEARCH_RADIUS)
                    glove:PrintVerbose("Grabbity target is shotgun shell - also grabbitying " .. #shells - 1 .. " nearby")
                    for _, shell in pairs(shells) do
                        local shellRefs = {
                            initialVelocity = refs.initialVelocity;
                            duration = refs.duration;
                            durationTarget = refs.durationTarget;
                            increment = refs.increment;
                        }
                        shell:SetThink(function() return self:ApplyVelocityImpulse(glove, shell, shellRefs, interval, aggressiveVelocity, true) end, "AcceleratingToHandOverwritable", delay)
                    end
                else
                    glove.tether.movingEntity:SetThink(function() return self:ApplyVelocityImpulse(glove, glove.tether.movingEntity, refs, interval, aggressiveVelocity) end, "AcceleratingToHandOverwritable", delay)
                end

                glove.lastBehaviourTime = glove.motion.time

                self.targetIndicator = false
                glove.tether:Untether(glove)

            else
                glove:PrintVerbose("Unable to Grabbity-pull entity to hand when glove is not tethered!")
            end
        end;



        ApplyVelocityImpulse = function (self, glove, entity, refs, interval, aggressiveVelocity, movingEntityOverride)

            -- TODO: I didn't think I needed this.
            if IsValidEntity(entity) then

                local velocityScaler = refs.velocityScaler or 1
                local durationTarget = refs.durationTarget or refs.duration - refs.increment
                

                if (glove.enabled
                and (glove.tether.movingEntity == entity or movingEntityOverride) ) then

                    if refs.increment < refs.duration then

                        local distance = glove.hand:GetAbsOrigin() - entity:GetCenter()
                        local currentVelocity = GetPhysVelocity(entity)
                        local desiredVelocity = distance / durationTarget - Motion.GRAVITY * durationTarget / 2
                        local targetVelocity = desiredVelocity - currentVelocity

                        
                        -- Ugh.  Brute forcing there to be no cap on manhack pull speed.  Their pathfinding is fighting velocity setters.
                        if refs.initialVelocity and aggressiveVelocity then
                            refs.initialVelocity = true
                        elseif not refs.initialVelocity then
                            targetVelocity = math.min(targetVelocity:Length(), self.MAX_ACCELERATION * interval) * targetVelocity:Normalized()
                        else
                            glove:PrintVerbose("Initial Grabbity velocity applied, capping all future velocities")
                            refs.initialVelocity = false
                        end

                        entity:ApplyAbsVelocityImpulse(targetVelocity * velocityScaler)

                        --[[
                        DebugDrawLine(entity:GetCenter(), entity:GetCenter() + targetVelocity * interval, 191, 191, 191, true, 2)
                        --]]

                        refs.increment = refs.increment + interval

                        return interval

                    elseif refs.increment < durationTarget then

                        refs.increment = durationTarget
                        return durationTarget - refs.increment

                    end

                    glove:PrintVerbose("Grabbity pull time has expired without any interruptions")

                else
                    glove:PrintVerbose("Grabbity pull has been interrupted")
                end

                if entity:GetClassname() == "prop_door_rotating_physics" then
                    glove:PrintVerbose("Grabbity was pulling door - calling InteractStop I/O after a slight delay")
                    EntFireByHandle(glove.hand, entity, "InteractStop", "", Grabbity.DOOR_PULL_DELAY)
                end

            else
                glove:PrintVerbose("Cannot apply Grabbity velocity when requested entity is not valid!")
            end

            glove:PrintVerbose("Grabbity pull is complete, de-referencing glove's movingEntity")

            glove.tether.movingEntity = nil

            return nil

        end;



        RespawnIfItemAttachment = function (self, entity, glove)

            local parent = entity:GetMoveParent()
            if parent then
                local parentClassname = parent:GetClassname()
                if parentClassname:match("npc_.+") or parentClassname == "prop_ragdoll" then

                    glove:PrintVerbose("Grabbity entity parent satisfies criteria of potentially being a character - checking if item attachment...")

                    local entityClassname = entity:GetClassname()
                    for i, classname in pairs(Validity.ITEM_ATTACHMENT_CLASSNAMES) do
                        if string.match(entityClassname, classname) then

                            glove:PrintVerbose("Grabbity entity is valid attachment (" .. classname .. "), respawning")

                            local origin = entity:GetAbsOrigin()
                            local angles = entity:GetAngles()
                            local scale = tostring(entity:GetAbsScale())
                            local tProperties = {
                                targetname = entity:GetName();
                                origin = tostring(origin.x) .." ".. tostring(origin.y) .." ".. tostring(origin.z);
                                angles = tostring(angles.x) .." ".. tostring(angles.y) .." ".. tostring(angles.z);
                                scales = scale .." ".. scale .." ".. scale;
                            }
            
                            entity:RemoveSelf()
                            entity = SpawnEntityFromTableSynchronous(entityClassname, tProperties)

                            break

                        end
                    end
                else
                    glove:PrintVerbose("Grabbity entity parent is not a character, no need to respawn")
                end
            end

            return entity

        end;



        OnTarget = function (self, glove)
            if self.enabled then
                if (self.targetValidity:GetValidity(glove.hand, glove.tether.targetEntity) > 0) then
                    glove:PrintVerbose("Target is valid for Grabbity")
                    self:SpawnHighlight(glove, glove.tether.targetEntity)
                    self.hasTarget = true
                    return true
                else
                    self:OnUntarget(glove)
                    if IsValidEntity(glove.tether.targetEntity) and not IsValidEntity(glove.tether.tetheredEntity) then
                        -- TODO: Is this unsafe?  Should probably be associated with ValidateTarget in Tether or something
                        --       ^ Regardless of safety, I'm not comfortable with this constant isolated loop
                        glove.hand:SetThink(function() self:OnTarget(glove) end, "GrabbityTarget" .. UniqueString() .. "Validation", glove.UPDATE_INTERVAL)
                    end
                end
            end
            return false
        end;

        OnTether = function (self, glove)
            if self.enabled then
                if (self.tetherValidity:GetValidity(glove.hand, glove.tether.tetheredEntity) > 0) then
                    glove:PrintVerbose("Tether is valid for Grabbity")
                    --[[print(glove.tether.tetheredEntity:GetRenderAlpha())
                    print(glove.tether.tetheredEntity:GetRenderColor())
                    print(glove.tether.tetheredEntity:GetClassname())
                    print(glove.tether.tetheredEntity:GetModelName())
                    print(glove.tether.tetheredEntity:GetName())
                    print(glove.tether.tetheredEntity:GetAbsScale())
                    print(glove.tether.tetheredEntity:GetMass())--]]
                    self:SpawnTether(glove)
                    if (glove.tether.tetheredEntity ~= glove.tether.movingEntity) then
                        glove.tether.movingEntity = nil
                    end
                    self.hasTether = true
                    return true
                else
                    self:OnUntether(glove)
                    return false
                end
            end
        end;

        OnUntarget = function (self, glove)
            if self.hasTarget then
                glove:PrintVerbose("Grabbity target was lost")
                glove.hand:SetThink(function() self:TargetLostDelay(glove) end, "ResettableTargetingTimer", self.TARGET_LOST_DELAY)
                self.hasTarget = false
            end
        end;

        OnUntether = function (self, glove)
            if self.hasTether then
                glove:PrintVerbose("Grabbity tether was disconnected")
                glove.hand:SetThink(function() self:TargetLostDelay(glove) end, "ResettableTargetingTimer", self.TETHER_LOST_DELAY)
                self.hasTether = false
            end
        end;



        TargetLostDelay = function (self, glove)
            if (self.targetIndicator == true
            and self.targetValidity:GetValidity(glove.hand, glove.tether.targetEntity) <= 0
            and self.tetherValidity:GetValidity(glove.hand, glove.tether.tetheredEntity) <= 0 ) then
                if glove.enabled then
                    glove:CloseClaws()
                end
                self.targetIndicator = false
            end
        end;



        SpawnHighlight = function (self, glove, entity)

            local particles = {}

            -- prop_ragdolls seem to highlight without regard for orientation, so we'll just not highlight those?
            if entity:GetClassname() ~= "prop_ragdoll" then

                glove:PrintVerbose("Spawning Grabbity highlight")

                -- Ugh had too many problems with trying to use one particle system class with highlighting
                -- hope there aren't memory leaks
                --self.PARTICLE_HIGHLIGHT = ParticleSystem("particles/weapon_fx/grabbity_gloves.vpcf")

                local available = 0
                for i, system in pairs(self.PARTICLE_HIGHLIGHTS) do
                    if system.available then available = i break end
                end

                if available > 0 then
                    glove:PrintVerbose("Grabbity highlight is using particle system " .. available)
                    particles = {
                        self.PARTICLE_HIGHLIGHTS[available]:Create( {
                            [0] = ParticleSystem.ControlPoint(entity);
                            [1] = ParticleSystem.ControlPoint(entity);
                            [2] = ParticleSystem.ControlPoint(nil, Vector(entity:GetAbsScale(), self.HIGHLIGHT_ALPHA, 0));
                        }, true )
                    }

                end
                
                if not self.targetIndicator then
                    glove:OpenClaws()
                    self.targetIndicator = true
                end

            else
                glove:PrintVerbose("Unable to spawn Grabbity highlight on a prop_ragdoll")
            end

            local ref = { entIndex = entity:GetEntityIndex(); }
            if particles[1] then
                particles[1].particleSystem:SetThink(function() return self:MaintainHighlight(glove, entity, particles, ref) end, "MaintainHighLight")
            end
            
            local tInfo = {
                ["userid"] = Entities:GetLocalPlayer():GetUserID();
                ["entindex"] = entity:GetEntityIndex();
                ["hand_is_primary"] = (Input.GetHandSelection(glove.hand) == Input.GetPrimaryHand());
                ["vr_tip_attachment"] = Input.GetEventHandSelection(glove.hand);
            }

            FireGameEvent("grabbity_glove_highlight_start", tInfo)

        end;



        MaintainHighlight = function (self, glove, entity, particles, ref)

            if not glove.enabled
            or not self.enabled
            or (not self.hasTarget and not self.hasTether)
             or ((self.targetValidity:GetValidity(glove.hand, entity) <= 0 or glove.tether.targetEntity ~= entity)
             and (self.tetherValidity:GetValidity(glove.hand, entity) <= 0 or glove.tether.tetheredEntity ~= entity) ) then
                
                glove:PrintVerbose("Grabbity highlight is no longer valid - removing...")

                for i, particle in pairs(particles) do
                    particle:DisableParticleSystem(true, 0, true)
                end
                
                local tInfo = {
                    ["userid"] = Entities:GetLocalPlayer():GetUserID();
                    ["entindex"] = ref.entIndex;
                    ["hand_is_primary"] = (Input.GetHandSelection(glove.hand) == Input.GetPrimaryHand());
                    ["vr_tip_attachment"] = Input.GetEventHandSelection(glove.hand);
                }

                FireGameEvent("grabbity_glove_highlight_stop", tInfo)

                self:OnTarget(glove)    -- To loop checking if target becomes grabbity valid

                return nil

            end

            return Grabbity.RENDER_INTERVAL

        end;



        SpawnTether = function (self, glove)

            glove:PrintVerbose("Spawning Grabbity tether")
            
            local entity = glove.tether.tetheredEntity

            local angleOffset = self.tetherValidity.angleOffset
            angleOffset = QAngle(-angleOffset.x, -angleOffset.y, -angleOffset.z)    -- Why do I need to negate this?

            -- TODO: Fade alpha out as tether reaches disconnect angle?
            self.PARTICLE_TETHER:SetControlPoint(1, entity, entity:GetCenter(), nil, true);
            self.PARTICLE_TETHER:SetControlPoint(10);--glove.hand); -- What does this CP do? It's only used in "Calculate Vector Attribute - Normal"
            self.PARTICLE_TETHER:SetControlPoint(11, glove.hand, nil, RotateOrientation(glove.hand:GetAngles(), angleOffset), true);
            self.PARTICLE_TETHER:SetControlPoint(20, nil, Vector(self.TETHER_ALTERNATE_ALPHA, 0, 0));
            self.PARTICLE_TETHER:SetControlPoint(22, nil, Vector(self.TETHER_ALPHA, 0, 0));
            
            self.PARTICLE_EMBERS:SetControlPoint(0);--nil, nil, QAngle(0, 0, 0));
            self.PARTICLE_EMBERS:SetControlPoint(1, entity, entity:GetCenter(), nil, true);
            self.PARTICLE_EMBERS:SetControlPoint(11, glove.hand, nil, nil, true);
            self.PARTICLE_EMBERS:SetControlPoint(20, nil, Vector(self.TETHER_EMBER_EMISSION_RATE, 0, 0));
            self.PARTICLE_EMBERS:SetControlPoint(22, nil, Vector(self.TETHER_EMBER_ALPHA, 0, 0))
            
            local particles = { 
                self.PARTICLE_TETHER:EnableParticleSystem(),
                self.PARTICLE_EMBERS:EnableParticleSystem(),
            }

            glove:PlaySound("Grabbity.HoverPing")
            Grabbity.HAPTIC_TETHER_PING:Fire(glove.hand)    -- TODO: Does this fire with MaintainTether running?
            glove:PlaySound("Grabbity.BeamLp", true)

            local ref = { entityIndex = entity:GetEntityIndex() }
            glove.hand:SetThink(function() return self:MaintainTether(glove, entity, particles, ref) end, "MaintainTether" .. self.PARTICLE_TETHER.IDENTIFIER)
            
            local tInfo = {
                ["userid"] = Entities:GetLocalPlayer():GetUserID();
                ["entindex"] = entity:GetEntityIndex();
                ["hand_is_primary"] = (Input.GetHandSelection(glove.hand) == Input.GetPrimaryHand());
                ["vr_tip_attachment"] = Input.GetEventHandSelection(glove.hand);
            }

            FireGameEvent("grabbity_glove_locked_on_start", tInfo)

        end;



        MaintainTether = function (self, glove, entity, particles, ref)

            if not glove.enabled or not self.enabled
            or not self.hasTether
            or glove.tether.tetheredEntity ~= entity then

                glove:PrintVerbose("Grabbity tether is no longer valid - removing...")

                for i, particle in pairs(particles) do
                    particle:DisableParticleSystem()
                end

                glove:StopLoop("Grabbity.BeamLp", true)
                glove:PlaySound("Grabbity.HoverPingEnd")

                local tInfo = {
                    ["userid"] = Entities:GetLocalPlayer():GetUserID();
                    ["entindex"] = ref.entityIndex;
                    ["hand_is_primary"] = (Input.GetHandSelection(glove.hand) == Input.GetPrimaryHand());
                    ["vr_tip_attachment"] = Input.GetEventHandSelection(glove.hand);
                    ["highlight_active"] = (glove.tether.targetEntity == entity);
                }
    
                FireGameEvent("grabbity_glove_locked_on_stop", tInfo)
    
                return nil

            end

            self.HAPTIC_TETHER:Fire(glove.hand)

            return Grabbity.RENDER_INTERVAL

        end;



        CheckPickup = function (self, pickupInfo, glove)

            if (pickupInfo["vr_tip_attachment"] == Input.GetEventHandSelection(glove.hand)
            and IsValidEntity(glove.tether.movingEntity)) then

                -- Not garaunteed to be correct; could pick up another nameless entity of the same class
                if (pickupInfo["item"] == glove.tether.movingEntity:GetClassname()
                and pickupInfo["item_name"] == glove.tether.movingEntity:GetName()) then

                    glove:PrintVerbose("User probably caught moving Grabbity entity")

                    local tCatchInfo = {}
                    tCatchInfo["userid"] = Entities:GetLocalPlayer():GetUserID()
                    tCatchInfo["entindex"] = glove.tether.movingEntity:GetEntityIndex()
                    tCatchInfo["item"] = glove.tether.movingEntity:GetClassname()
                    tCatchInfo["hand_is_primary"] = (Input.GetHandSelection(glove.hand) == Input.GetPrimaryHand())
                    tCatchInfo["vr_tip_attachment"] = Input.GetEventHandSelection(glove.hand)

                    FireGameEvent("grabbity_glove_catch", tCatchInfo)

                end

                glove.tether.movingEntity = nil

            end
        end;
        
        
        
        WatchForVortEnergy = function (self, glove)
            local vortEnergy = Entities:FindAllByClassnameWithin("point_vort_energy", Entities:GetLocalPlayer():GetCenter(), 416)
            if not self.nearVortEnergy and #vortEnergy > 0 then
                print("User is nearing Vort Energy - Disabling Glorious Glove Grabbity behaviour!")
                self.enabled = false
                self:OnUntarget(glove)
                self:OnUntether(glove)
                for i, event in pairs(self.eventList) do
                    StopListeningToGameEvent(event)
                    self.eventList[i] = nil
                end
                self.eventList = {
                    ListenToGameEvent("grabbity_glove_pull", function(context) self:ListenToGrabbityEvent(context, glove) end, nil)
                }
                self.nearVortEnergy = true
            elseif self.nearVortEnergy and #vortEnergy <= 0 then
                print("User has left the area with Vort Energy - restoring Glorious Gloves Grabbity behaviour")
                self.enabled = true
                for i, event in pairs(self.eventList) do
                    StopListeningToGameEvent(event)
                    self.eventList[i] = nil
                end
                self.eventList = {
                    ListenToGameEvent("item_pickup", function(context) self:CheckPickup(context, glove) end, nil)  -- What's the purpose of the third parameter, set nil here?
                }
                self.nearVortEnergy = false
            end
            return 1
        end;

        ListenToGrabbityEvent = function (self, context, glove)
            if (context["vr_tip_attachment"] == Input.GetEventHandSelection(glove.hand)) then
                glove:PrintVerbose("Default grabbity observed for glove (" .. Input.GetHandSelection(glove.hand) .. ")")
                glove.tether.movingEntity = EntIndexToHScript(context["entindex"])
                glove.tether.moveTime = Time()
            end
        end;



        RemoveBehaviour = function (self, glove)
            print("Removing \"Grabbity\" behaviour...")
            for i, event in pairs(self.eventList) do
                StopListeningToGameEvent(event)
                self.eventList[i] = nil
            end
            glove.tether.movingEntity = nil
        end;

    },

    {
        __class__name = "Grabbity";

        GESTURE_ANGLE_OFFSET_THUMB = -30;
        GESTURE_ANGLE_OFFSET_PALM = 40;

        TETHER_DISTANCE_BUFFER = 10;
        TETHER_ANGLE_OFFSET_THUMB = 20;
        TETHER_ANGLE_OFFSET_PALM = -20;

        RENDER_INTERVAL = 0.05;
        DOOR_PULL_DELAY = 1 / 30;   -- TODO Make this one frame length
        SHOTGUN_SHELL_SEARCH_RADIUS = 12;

        VALIDITY_OVERRIDE = {
            minDistance = 18;--25;
            maxDistance = 400;
            maxMass = 55;--50
            maxSize = 80;--72;
            scaleMassWithDistance = true;
            ignoreClass = {
                "prop_door_rotating_physics",
                "prop_animinteractable",
                "func_.+",
                "shatterglass_shard",
            };
            ignoreModel = {
                -- Should "inherit" the ingnored model names in Tether since it wouldn't be able to tether to them in the first place?
                -- Physics constrained items:
                ".*drawer.*",
                ".+_handle.*",
                ".*cabinet.*",
                ".*door.*",
                ".*piano.*",
                ".*dumpster.*",
                ".*hazmat_crate_lid.*",
                --".*combine_memory_tank.*",
            };
            ignoreItemAttachments = false;
        };

        GESTURE = Gesture( {
            handState = Gesture.HAND_CLOSED;
            motionType = Gesture.MOTION_ACCELERATION;
            motionDirection = Gesture.MOTION_INCREASING;
            useVelocityDirection = true;
            motionThreshold = 650;
            maxMotionIncidence = -0.2;
        } );

        HAPTIC_GRAB = HapticSequence(0.073, 0.7, 1/56);
        HAPTIC_TOO_HEAVY = HapticSequence(0.073, 0.2, 1/56);
        HAPTIC_TETHER_PING = HapticSequence(0.1, 0.2, 1/393);
    },

    nil

)



Grabbity.Precache = function (context)
    print("Precaching \"Grabbity\" resources")
    -- TODO: Precache grabbity sound events, even though they're already populated?
    PrecacheResource("soundfile", "soundevents/soundevents_weapon_physcannon.vsndevts", context)
    PrecacheResource("particle", "particles/weapon_fx/grabbity_gloves.vpcf", context)
    PrecacheResource("particle", "particles/gravity_glove_hand_rope_electric.vpcf", context)--"particles/weapon_fx/gravity_glove_hand_rope.vpcf", context)
    PrecacheResource("particle", "particles/weapon_fx/gravity_glove_hand_bits.vpcf", context)
end
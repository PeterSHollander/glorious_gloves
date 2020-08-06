-- A cleanly packaged function which permanently adds an output to an entity (creates a permanent unique name for said entity if it is nameless)
function AddEntityOutput (outputEntity, outputName, outputTarget, action, parameter, delay, fireOnce)
    
    parameter = parameter or ""
    delay = delay or 0
    fireOnce = fireOnce or false
    
    local maxTimesToFire = -1 if fireOnce then maxTimesToFire = 1 end

    local target
    if type(outputTarget) == "string" then
        target = outputTarget
    else
        target = outputTarget:GetName()
        if target == "" then
            target = UniqueString()
            outputTarget:SetEntityName(target)
        end
    end
    
    local output = outputName ..">".. target ..">".. action ..">".. parameter ..">".. delay ..">".. maxTimesToFire
    EntFireByHandle(outputEntity, outputEntity, "AddOutput", output)

end



function CreateSpawnflags (flags)

    local spawnflags = 0

    for _, flag in pairs(flags) do
        spawnflags = spawnflags + (2 ^ flag)
    end

    return tostring(spawnflags)

end



-- NOTE: If using for hands, be sure to account for left hand "right" vector facing palm, while right hand "right" vector faces the back of the hand
function ApplyAngleOffset (entity, offset, forward, up)

    forward = forward or entity:GetForwardVector()
    up = up or entity:GetUpVector()

    -- Apply angleOffset as (pitch, yaw, roll)
    forward = forward:Normalized()
    up = up:Normalized()
    local right = forward:Cross(up):Normalized()

    -- angleOffset roll goes unused as it will not effect incidence; yaw is NOT dynamically applied based on pitch
    forward = forward + math.tan(math.rad(offset.x)) * up
    forward = forward + math.tan(math.rad(offset.y)) * right
    
    return forward:Normalized()

end



-- Tried using ParticleManager:CreateParticle() and ParticleManager:SetParticleControlEnt(),
-- but I'd get a hard & silent crash when trying to set control points from "empty" entities (info_particle_target, info_target, logic_script, etc)
-- So this is my chunky workaround.  Manually spawning in the particle system and populating that produces the desired result
ParticleSystem = class(

    {

        IDENTIFIER;
        PARTICLE_NAME;
        UNNAMED_CONTROL_POINT;

        particleSystem;
        controlPoints;
        eventList;

        available;
        markedForDestruction;



        constructor = function (self, particleName)

            self.IDENTIFIER = UniqueString()
            self.PARTICLE_NAME = particleName
            self.UNNAMED_ENTITY = "unnamed_particle_" .. self.IDENTIFIER .. "entity_"
            self.available = true

            self.eventList = {
                ListenToGameEvent("change_level_activated", function() self:DisableParticleSystem(true) end, nil);
                ListenToGameEvent("player_opened_game_menu", function() self:DisableParticleSystem(true) end, nil); -- Doesn't get called because game is paused when it fires?
            }

        end;



        -- Keep the same particle system class, only deleting and recreating the particle entities each time to avoid memory leaks?  See DisableParticleSystem for more info
        Create = function (self, tControlPoints, startEnabled)

            startEnabled = startEnabled or false

            --self:DisableParticleSystem(true, nil, true) -- ensures no leftover particles -- DEPRECATED?
            self.markedForDestruction = false
            self.available = false

            ParticleSystem.Print("Creating \"" .. self.PARTICLE_NAME .. self.IDENTIFIER .. "\" particle system from control points")

            self.controlPoints = tControlPoints

            local tParticleProperties = {
                targetname = "fx" .. self.IDENTIFIER .. self.PARTICLE_NAME;
                effect_name = self.PARTICLE_NAME;
                start_active = startEnabled;
                cpoint0 = self:FixName(0);
                cpoint1 = self:FixName(1);
                cpoint2 = self:FixName(2);
                cpoint3 = self:FixName(3);
                cpoint4 = self:FixName(4);
                cpoint5 = self:FixName(5);
                cpoint6 = self:FixName(6);
                cpoint7 = self:FixName(7);
                cpoint8 = self:FixName(8);
                cpoint9 = self:FixName(9);
                cpoint10 = self:FixName(10);
                cpoint11 = self:FixName(11);
                cpoint12 = self:FixName(12);
                cpoint13 = self:FixName(13);
                cpoint14 = self:FixName(14);
                cpoint15 = self:FixName(15);
                cpoint16 = self:FixName(16);
                cpoint17 = self:FixName(17);
                cpoint18 = self:FixName(18);
                cpoint19 = self:FixName(19);
                cpoint20 = self:FixName(20);
                cpoint21 = self:FixName(21);
                cpoint22 = self:FixName(22);
                cpoint23 = self:FixName(23);
                cpoint24 = self:FixName(24);
                cpoint25 = self:FixName(25);
                cpoint26 = self:FixName(26);
                cpoint27 = self:FixName(27);
                cpoint28 = self:FixName(28);
                cpoint29 = self:FixName(29);
                cpoint30 = self:FixName(30);
                cpoint31 = self:FixName(31);
                cpoint32 = self:FixName(32);
                cpoint33 = self:FixName(33);
                cpoint34 = self:FixName(34);
                cpoint35 = self:FixName(35);
                cpoint36 = self:FixName(36);
                cpoint37 = self:FixName(37);
                cpoint38 = self:FixName(38);
                cpoint39 = self:FixName(39);
                cpoint40 = self:FixName(40);
                cpoint41 = self:FixName(41);
                cpoint42 = self:FixName(42);
                cpoint43 = self:FixName(43);
                cpoint44 = self:FixName(44);
                cpoint45 = self:FixName(45);
                cpoint46 = self:FixName(46);
                cpoint47 = self:FixName(47);
                cpoint48 = self:FixName(48);
                cpoint49 = self:FixName(49);
                cpoint50 = self:FixName(50);
                cpoint51 = self:FixName(51);
                cpoint52 = self:FixName(52);
                cpoint53 = self:FixName(53);
                cpoint54 = self:FixName(54);
                cpoint55 = self:FixName(55);
                cpoint56 = self:FixName(56);
                cpoint57 = self:FixName(57);
                cpoint58 = self:FixName(58);
                cpoint59 = self:FixName(59);
                cpoint60 = self:FixName(60);
                cpoint61 = self:FixName(61);
                cpoint62 = self:FixName(62);
                cpoint63 = self:FixName(63);
            }

            self.particleSystem = SpawnEntityFromTableSynchronous("info_particle_system", tParticleProperties)
            --SpawnEntityFromTableAsynchronous("info_particle_system", tParticleProperties, nil, self.particleSystem)

            return self

        end;



        FixName = function (self, index)

            local entity = self.controlPoints[index]

            if IsValidEntity(entity) then

                local name = entity:GetName()
                
                if name == ParticleSystem.CONTROL_POINT_NAME then
                    -- Control point was procedurally generated, so let's make the name unique
                    name = self.IDENTIFIER .. ParticleSystem.CONTROL_POINT_NAME .. tostring(index)
                elseif name == "" then
                    -- Control point is a nameless entity; give a name
                    name = self.UNNAMED_ENTITY .. tostring(index)
                elseif not name:find(self.IDENTIFIER) then
                    name = name .. self.IDENTIFIER
                end

                entity:SetEntityName(name)

                return name

            end

            return nil

        end;



        SetControlPoint = function (self, index, entity, origin, angles, manualFollow, attachment)
            ParticleSystem.ConfigureControlPoint(self.controlPoints[index], entity, origin, angles, manualFollow, attachment)
        end;



        EnableParticleSystem = function (self, delay)
            if IsValidEntity(self.particleSystem) then
                EntFireByHandle(self.particleSystem, self.particleSystem, "Start", "", delay)
            end
            return self
        end;



        -- NOTE: BE CAREFUL WITH DESTROY
        --       It would appear repeatedly creating and destroying particle systems causes save/load crashes!
        --       Use Disable/EnableParticleSystem whenever possible!
        --        ^ Maybe... Issue may have actually been due to the haptic thinkers?
        DisableParticleSystem = function (self, immediate, delay, destroy)

            if IsValidEntity(self.particleSystem) then-- and not self.markedForDestruction then

                delay = delay or 0

                if immediate then
                    local output = "Stop" if destroy then output = "DestroyImmediately" end
                    ParticleSystem.Print("Disabling \"" .. self.PARTICLE_NAME .. "\" immediately (\"" .. output .. "\")")
                    EntFireByHandle(self.particleSystem, self.particleSystem, output, "", delay)
                    delay = delay + ParticleSystem.IMMEDIATE_DESTROY_DELAY
                else
                    ParticleSystem.Print("Disabling \"" .. self.PARTICLE_NAME .. "\" gently")
                    EntFireByHandle(self.particleSystem, self.particleSystem, "StopPlayEndCap", "", delay)
                    delay = delay + ParticleSystem.WAIT_FOR_FADEOUT_DELAY
                end

                if destroy and not self.markedForDestruction then
                    local refs = {
                        particleSystem = self.particleSystem;
                        controlPoints = self.controlPoints;
                    }
                    refs.particleSystem:SetThink(function() self:DelayedDestroy(refs) end, "WaitingToDestroyParticle" .. self.IDENTIFIER, delay)
                    self.markedForDestruction = true
                end

            end
        end;



        -- Actually removes the particle system and procedurally generated control point entities once the halting I/O has been dispatched and presumably executed.
        DelayedDestroy = function (self, refs)
                
            for i, controlPoint in pairs(refs.controlPoints) do

                if IsValidEntity(controlPoint) then
                    
                    local controlPointName = controlPoint:GetName()
                    if controlPointName:find(ParticleSystem.CONTROL_POINT_NAME) then
                        ParticleSystem.Print("Removing particle " .. self.IDENTIFIER .. " control point")
                        controlPoint:RemoveSelf()
                    elseif controlPointName:find(self.UNNAMED_ENTITY) then
                        ParticleSystem.Print("Reverting particle " .. self.IDENTIFIER .. " entity to be nameless")
                        controlPoint:SetEntityName("")
                    elseif controlPointName:find(self.IDENTIFIER) then
                        local originalName = controlPoint:GetName():gsub(self.IDENTIFIER, "")
                        controlPoint:SetEntityName(originalName)
                        ParticleSystem.Print("Reverted particle " .. self.IDENTIFIER .. " entity name to \"" .. controlPoint:GetName() .. "\"")
                    end
                end
            end

            if IsValidEntity(refs.particleSystem) then

                ParticleSystem.Print("Removing \"" .. self.PARTICLE_NAME .. self.IDENTIFIER .. "\" particle system")

                refs.particleSystem:RemoveSelf()

            end

            self.available = true

        end;

    },

    {
        __class__name = "ParticleSystem";

        -- TODO: Set based on FPS; if the delay is faster than the framerate, then you risk the destroy being called in the same frame as the particle stop I/O
        IMMEDIATE_DESTROY_DELAY = 1 / 20;
        WAIT_FOR_FADEOUT_DELAY = 10;

        CONTROL_POINT_NAME = "control_point_";
        FOLLOW_UPDATE_INTERVAL = 1 / 144;
    },

    nil

)



-- Creates a generically-named info_particle_target (control point) entity with options for parenting and offset values
ParticleSystem.ControlPoint = function (entity, origin, angles, manualFollow, attachment)

    if origin or angles or manualFollow or not IsValidEntity(entity) then

        local tPointProperties = { targetname = ParticleSystem.CONTROL_POINT_NAME }
        local controlPoint = SpawnEntityFromTableSynchronous("info_particle_target", tPointProperties)

        entity = ParticleSystem.ConfigureControlPoint(controlPoint, entity, origin, angles, manualFollow, attachment)

    else
        ParticleSystem.Print("Particle control point already populated, not overwriting")
    end

    return entity;

end;



ParticleSystem.ConfigureControlPoint = function (controlPoint, parent, origin, angles, manualFollow, attachment)

    if IsValidEntity(parent) then
        origin = origin or parent:GetAbsOrigin()
        angles = angles or parent:GetAngles()
    else
        origin = origin or Vector(0, 0, 0)
        angles = angles or QAngle(0, 0, 0)
    end

    controlPoint:SetAbsOrigin(origin)
    controlPoint:SetAngles(angles.x, angles.y, angles.z)

    if IsValidEntity(parent) then
        if manualFollow then

            local worldOffset = origin - parent:GetAbsOrigin();

            local refs = {
                offset = Vector (
                    worldOffset:Dot(parent:GetForwardVector()),
                    worldOffset:Dot(parent:GetRightVector()),
                    worldOffset:Dot(parent:GetUpVector()) );
                angleOffset = RotationDelta(parent:GetAngles(), angles);
            }

            controlPoint:SetThink(function() return ParticleSystem.Follow(controlPoint, parent, refs) end, "OverwritableParticleControlPointFollow")

        else
            attachment = attachment or ""
            controlPoint:SetParent(parent, attachment)
        end
    end

    return controlPoint

end;



-- Manual follow function that leaves the entity where it is if its parent becomes invalid; a lot safer than parenting for particle systems, it would seem
ParticleSystem.Follow = function (entity, parent, refs)

    if not IsValidEntity(entity) or not IsValidEntity(parent) then
        return nil
    end

    local offset = refs.offset.x * parent:GetForwardVector() + refs.offset.y * parent:GetRightVector() + refs.offset.z * parent:GetUpVector()

    entity:SetAbsOrigin(parent:GetAbsOrigin() + offset)
    local angles = RotateOrientation(parent:GetAngles(), refs.angleOffset)
    entity:SetAngles(angles.x, angles.y, angles.z)

    return ParticleSystem.FOLLOW_UPDATE_INTERVAL

end;



ParticleSystem.Print = function (message)
    if Convars:GetBool("glorious_gloves_verbose") then
        print("GGVerbose>" .. message)
    end
end;
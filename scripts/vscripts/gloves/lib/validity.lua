local CustomDebug = require "/debug"



Validity = class(

    {

        minDistance;
        maxDistance;
        minMass;
        maxMass;
        minSize;
        maxSize;
        minIncidence;
        maxIncidence;
        angleOffset;
        requireCentre;          -- TODO
        scaleMassWithDistance;  -- Also scales valid size with distance
        ignoreClass;
        allowClassOverride;
        ignoreModel;
        allowModelOverride;
        importantClass;
        importantModel;
        ignoreItemAttachments;



        -- TODO: Set up hand input parameter, alter angleOffset accordingly
        constructor = function (self, tValidity)

            tValidity = tValidity or {}

            self.minDistance = tValidity.minDistance or Validity.DEFAULT_MIN_DISTANCE
            self.maxDistance = tValidity.maxDistance or Validity.DEFAULT_MAX_DISTANCE
            self.minMass = tValidity.minMass or Validity.DEFAULT_MIN_MASS
            self.maxMass = tValidity.maxMass or Validity.DEFAULT_MAX_MASS
            self.minSize = tValidity.minSize or Validity.DEFAULT_MIN_SIZE
            self.maxSize = tValidity.maxSize or Validity.DEFAULT_MAX_SIZE
            self.minIncidence = tValidity.minIncidence or Validity.DEFAULT_MIN_INCIDENCE
            self.maxIncidence = tValidity.maxIncidence or Validity.DEFAULT_MAX_INCIDENCE
            self.angleOffset = tValidity.angleOffset or Validity.DEFAULT_ANGLE_OFFSET
            self.requireCentre = tValidity.requireCentre or Validity.DEFAULT_REQUIRE_CENTRE
            self.scaleMassWithDistance = tValidity.scaleMassWithDistance or Validity.DEFAULT_SCALE_MASS_WITH_DISTANCE
            self.ignoreClass = tValidity.ignoreClass or Validity.DEFAULT_IGNORE_CLASS
            self.allowClassOverride = tValidity.allowClassOverride or Validity.DEFAULT_ALLOW_CLASS_OVERRIDE
            self.ignoreModel = tValidity.ignoreModel or Validity.DEFAULT_IGNORE_MODEL
            self.allowModelOverride = tValidity.allowModelOverride or Validity.DEFAULT_ALLOW_MODEL_OVERRIDE
            self.importantClass = tValidity.importantClass or Validity.DEFAULT_IMPORTANT_CLASS
            self.importantModel = tValidity.importantModel or Validity.DEFAULT_IMPORTANT_MODEL
            self.ignoreItemAttachments = tValidity.ignoreItemAttachments

            if self.ignoreItemAttachments == nil then self.ignoreItemAttachments = true end

        end;



        -- Returns the most valid entity for this validity from the provided entityList
        FilterBestEntity = function (self, origin, entityList, orientation)

            local mostValidEntity = nil
            local bestValidity = 0

            for i, entity in pairs(entityList) do
                if IsValidEntity(entity) then

                    local validity = self:GetValidity(origin, entity, true, orientation)

                    if (validity > bestValidity) then
                        mostValidEntity = entity
                        bestValidity = validity
                    end
                else
                    entityList[i] = nil
                end
            end

            return mostValidEntity

        end;



        -- Returns the validity value for a single entity
        -- TODO: No longer raycasting in Validity, but rather in gloves/detection_sphere.lua
        GetValidity = function (self, origin, entity, raycast, orientation)

            if IsValidEntity(entity) then

                raycast = raycast or false

                local originPos = origin:GetCenter()
                local entityPos = entity:GetCenter()
                local originToEntity = entityPos - originPos
                local distance = originToEntity:Length()
                local mass = entity:GetMass()
                local size = (entity:GetBoundingMaxs() - entity:GetBoundingMins()):Length() * entity:GetAbsScale()

                -- TODO: Make "forward" be based on how far away the hand is from the body (closer to body, tilt detection cone forward towards palm)
                local forwardReference
                if orientation then
                    forwardReference = ApplyAngleOffset(origin, self.angleOffset, orientation:Forward(), orientation:Up())
                else
                    forwardReference = ApplyAngleOffset(origin, self.angleOffset)
                end
                
                local incidence = forwardReference:Dot(originToEntity:Normalized())
                local incidenceFactor = (incidence - self.minIncidence) / (self.maxIncidence - self.minIncidence)
                local distanceFactor = (distance - self.minDistance) / (self.maxDistance - self.minDistance)

                local maxMass = self.maxMass
                local maxSize = self.maxSize
                if (self.scaleMassWithDistance) then
                    maxMass = Lerp(1 - distanceFactor * distanceFactor, self.minMass, self.maxMass)
                    maxSize = Lerp(1 - distanceFactor * distanceFactor, self.minSize, self.maxSize)
                end 

                --[[
                -- TODO: Register Convar for debug rendering
                local filter = ".*%.%d%d"
                local text = "Inc: " .. tostring(incidenceFactor + 0.0001):match(filter) .. "  Dst: " .. tostring(distanceFactor + 0.0001):match(filter)
                if mass then text = text .. "  Mass: " .. tostring(mass + 0.0001):match(filter) end
                for i, classname in pairs(self.importantClass) do
                    if string.match(entity:GetClassname(), classname) then text = text .. "  (Priority)" end
                end
                if Input.GetHandSelection(origin) == Input.RIGHT then text = "\n\n" .. text end
                DebugDrawText(entity:GetCenter(), text, true, 1/48)
                --]]

                -- TODO: Implement requireCentre
                if (distance > self.minDistance
                and distance < self.maxDistance
                and mass > self.minMass
                and mass < maxMass
                and size > self.minSize
                and size < maxSize
                and incidence >= self.minIncidence
                and incidence <= self.maxIncidence ) then

                    local entityClassname = entity:GetClassname()
                    local entityModelName = entity:GetModelName()

                    if self.ignoreItemAttachments then
                        local parent = entity:GetMoveParent()
                        if IsValidEntity(parent) then
                            local parentClassname = parent:GetClassname()
                            if (parentClassname:match("npc_.+") or parentClassname == "prop_ragdoll") then
                                for i, classname in pairs(Validity.ITEM_ATTACHMENT_CLASSNAMES) do
                                    if entityClassname:match(classname) then return 0 end
                                end
                            end
                        end
                    end

                    local important = false
                    local override = false

                    for i, classname in pairs(self.importantClass) do
                        if string.match(entityClassname, classname) then important = true override = true break end
                    end

                    for i, modelName in pairs(self.importantModel) do
                        if entityModelName:match(modelName) then important = true override = true break end
                    end

                    if not override then
                        for i, classname in pairs(self.allowClassOverride) do
                            if string.match(entityClassname, classname) then override = true break end
                        end

                        for i, modelName in pairs(self.allowModelOverride) do
                            if string.match(entityModelName, modelName) then override = true break end
                        end
                    end

                    if not override then
                        for i, classname in pairs(self.ignoreClass) do
                            if string.match(entityClassname, classname) then return 0 end
                        end
                        
                        for i, modelName in pairs(self.ignoreModel) do
                            if string.match(entityModelName, modelName) then return 0 end
                        end
                    end

                    if raycast then
                        -- Raycasting in detection sphere now, no need to do it here anymore
                        --if not Validity.RaycastToEntity(origin, entity) then return 0 end
                    end

                    -- If we made it to this point, then the entity is eligible to be considered for this validity; calculate validity based on incidence and distance
                    local validity = Validity.INCIDENCE_WEIGHT * incidenceFactor + (1 - Validity.INCIDENCE_WEIGHT) * distanceFactor

                    if important then validity = Validity.IMPORTANT_CLASSNAME_WEIGHT + (1 - Validity.IMPORTANT_CLASSNAME_WEIGHT) * validity end

                    --DebugDrawText(entity:GetCenter(), "\nValdity: " .. tostring(validity + 0.0001):match(filter), true, 1/48)

                    return validity

                end

                --[[
                local text = "\nInvalid"
                if Input.GetHandSelection(origin) == Input.RIGHT then text = "\n\n" .. text end
                DebugDrawText(entity:GetCenter(), text, true, 1/48)
                --]]

            end

            return 0

        end;



        Copy = function(self, tOverride)

            tOverride = tOverride or {}

            return Validity( {
                minDistance = tOverride.minDistance or self.minDistance;
                maxDistance = tOverride.maxDistance or self.maxDistance;
                minMass = tOverride.minMass or self.minMass;
                maxMass = tOverride.maxMass or self.maxMass;
                minSize = tOverride.minSize or self.minSize;
                maxSize = tOverride.maxSize or self.maxSize;
                minIncidence = tOverride.minIncidence or self.minIncidence;
                maxIncidence = tOverride.maxIncidence or self.maxIncidence;
                angleOffset = tOverride.angleOffset or self.angleOffset;
                requireCentre = tOverride.requireCentre or self.requireCentre;
                scaleMassWithDistance = tOverride.scaleMassWithDistance or self.scaleMassWithDistance;
                ignoreClass = tOverride.ignoreClass or self.ignoreClass;
                allowClassOverride = tOverride.allowClassOverride or self.allowClassOverride;
                ignoreModel = tOverride.ignoreModel or self.ignoreModel;
                allowModelOverride = tOverride.allowModelOverride or self.allowModelOverride;
                importantClass = tOverride.importantClass or self.importantClass;
                importantModel = tOverride.importantModel or self.importantModel;
                ignoreItemAttachments = tOverride.ignoreItemAttachments or self.ignoreItemAttachments;
            } )

        end;

    },

    {
        __class__name = "Validity";

        INCIDENCE_WEIGHT = 0.72;
        IMPORTANT_CLASSNAME_WEIGHT = 0.45;

        DEFAULT_MIN_DISTANCE = 0;
        DEFAULT_MAX_DISTANCE = 400;
        DEFAULT_MIN_MASS = 0;
        DEFAULT_MAX_MASS = 25;
        DEFAULT_MIN_SIZE = 0;
        DEFAULT_MAX_SIZE = 72;
        DEFAULT_MIN_INCIDENCE = -1;
        DEFAULT_MAX_INCIDENCE = 1;
        DEFAULT_ANGLE_OFFSET = QAngle(0, 0, 0); -- TODO: Cone should really be centered on the base angle offset anyway
        DEFAULT_REQUIRE_CENTRE = true;
        DEFAULT_SCALE_MASS_WITH_DISTANCE = false;
        DEFAULT_IGNORE_CLASS = {
            "player",
            "npc_.+",
        };
        DEFAULT_ALLOW_CLASS_OVERRIDE = {
            "npc_manhack",
        };
        -- TODO: Please let there be a way to determine if an object has physics constraints so I don't have to brute force this
        DEFAULT_IGNORE_MODEL = {
            ".*doorhandle.*",
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
        DEFAULT_ALLOW_MODEL_OVERRIDE = {
            ".*gib.*",
            ".*citizens_female_upper_cotton_jacket_hanging.*",
            ".*armored_headcrab_shell_prop.*",
            ".*gland.*",
            ".*hazmat_worker_.+",
        };
        DEFAULT_IMPORTANT_CLASS = {
            "item_.+",
            "prop_reviver_heart",
            "npc_manhack",
            "prop_door_rotating_physics",
            "point_vort_energy",
        };
        DEFAULT_IMPORTANT_MODEL = {
            ".*keycard_%d%d%d.*",
            ".*padlock%d%d%da.*",
            --".*hat_construction.*",
            --".*respirator_.*",
            --".*mask.*",
            ".*explosive.*",
            ".*drum.*",
            ".*barrel_plastic_1.vmdl",
            ".*barrel_plastic_1_open.vmdl",
            ".*/plastic_container_.+",
            ".*wood_crate.*",
            ".*industrial_board_%dd.vmdl",
        };

        ITEM_ATTACHMENT_CLASSNAMES = {
            "item_hlvr_clip_energygun",
            "item_hlvr_clip_rapidfire",
            "item_hlvr_clip_shotgun_single",
            "item_hlvr_clip_shotgun_shells_pair",
            "item_hlvr_clip_shotgun_multiple",
            "item_healthvial",
            "item_hlvr_grenade_frag",
            "item_hlvr_crafting_currency_small",
            "item_hlvr_crafting_currency_large",
            --"npc_manhack_attached", -- Heh, should you be allowed to grab this? :) <- Nope, not functional
        };
    },

    nil

)


        
-- Checks if origin has direct line-of-sight to entity
Validity.RaycastToEntity = function (origin, entity)

    local isValid = false

    local tRaycast = {
        startpos = origin:GetCenter();
        endpos = entity:GetCenter();
        ignore = Entities:GetLocalPlayer();
        --mask = ?;
    }

    if TraceLine(tRaycast) then
        if tRaycast.hit then
            if (tRaycast.enthit == entity) then
                -- Raycast hit the target entity unimpeded
                isValid = true
            else
                -- Raycast hit another entity before reaching this target
            end
        else
            -- Looks like we didn't hit anything, but the entity's centre is within our ideal cone.  Probably a hollow collider then?  Consider it valid.
            isValid = true
        end
    else
        Warning("Raycast for " .. entity:GetClassname() .. " not successfully performed!\n")
    end

    --[[
    -- TODO: Register with Convar
    local color = Vector(191, 0, 0) if isValid then color = Vector(0, 127, 0) end
    DebugDrawLine(tRaycast.startpos, tRaycast.endpos, color.x, color.y, color.z, false, 1 / 48)
    --]]

    return isValid
    
end
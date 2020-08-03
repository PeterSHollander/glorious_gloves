require "/customutils"

local CustomDebug = require "/debug"



DetectionSphere = class(

    {

        RADIUS;             -- The radius of the detection sphere
        FORWARD_OFFSET;     -- How far forward or back the the sphere's EDGE should be in relation to its parent (the hand)
        UPDATE_INTERVAL;
        SPHERE_STEPS;

        -- Legacy variables
        FOV;
        INCIDENCE_AT_MAX_ANGLE;
        LENGTH;
        trigger;    -- Not a trigger anymore.

        entityList;         -- The list of entities currently detected by this volume



        constructor = function (self, hand, trigger, radius, forwardOffset, updateInterval)

            Glove.Print("Detection cone class initializing...")

            self.entityList = {}    -- Gotta declare the table in the constructor, otherwise the table is shared across all instances

            self.RADIUS = radius or DetectionSphere.DEFAULT_RADIUS
            self.SPHERE_STEPS = 5
            self.LENGTH = self.RADIUS * 2   -- Deprecated, see below

            local currentMap = GetMapName()
            for _, mapName in pairs(DetectionSphere.REDUCED_RADIUS_MAP_NAME) do
                if mapName == currentMap then
                    self.RADIUS = self.RADIUS / DetectionSphere.REDUCED_RADIUS_FACTOR
                    print("Map \"" .. currentMap .. "\" has been hard-coded to use a reduced range for the Glorious Gloves (from " .. tostring(self.LENGTH) .. " to " .. tostring(2 * self.RADIUS) .. ") to avoid performance issues")
                end
            end

            self.FORWARD_OFFSET = forwardOffset or DetectionSphere.DEFAULT_FORWARD_OFFSET
            self.UPDATE_INTERVAL = updateInterval or (FrameTime() * 3)--DetectionSphere.DEFAULT_UPDATE_INTERVAL

            -- TODO: Deprecated, move to support sphere in all files rather than cone
            self.FOV = 40
            self.INCIDENCE_AT_MAX_ANGLE = math.cos(math.rad(self.FOV / 2));
            self.trigger = trigger
            --self.trigger:SetParent(hand, "")

            local sphereOffset = self.RADIUS + self.FORWARD_OFFSET
            hand:SetThink(function() return self:UpdateEntityList(hand, sphereOffset) end, "GloriousGloveDetectionSphere" .. UniqueString())
            
        end;



        UpdateEntityList = function (self, hand, sphereOffset)

            -- TODO: Combine into one table
            self.entityList = {}
            self.validIncidenceList = {}

            -- Perform a telescopic sphere search.
            -- Radii have to be larger in the earlier search steps because *apparently* Entities:FindAllInSphere doesn't account for entity scales!
            -- So if something is scaled down to 0.5, then that means it requires a search TWICE as far as something that's at its native scaling!
            -- I balance functionality with performance here
            -- TODO: Now that we're telescoping, we don't need to have a giant search sphere centered in our cone length;
            --       Change this over so the radius of the sphere is tending towards the radius of the cone, along the entire length of the cone
            local index = 0
            local increment = 1 / self.SPHERE_STEPS
            local i = 0
            while i < 1 do
                i = i + increment
                local origin = hand:GetCenter() + sphereOffset * (i * i) * hand:GetForwardVector()
                local radius = self.RADIUS * (i * i) * (2 - (i - increment))    -- Doubles initial radius and scales back incrementally; smaller-scaled entities will be ignored at longer ranges.
                --CustomDebug.DrawOrigin(origin, hand:GetForwardVector(), hand:GetRightVector(), hand:GetUpVector(), 4, true, self.UPDATE_INTERVAL)
                --DebugDrawLine(origin, origin + hand:GetUpVector() * radius, 255, 255, 255, true, self.UPDATE_INTERVAL)
                local entities = Entities:FindAllInSphere(origin, radius)
                index = self:PopulatePrimaryEntityList(hand, entities, index)
            end

            --DebugDrawLine(hand:GetCenter(), hand:GetCenter() + ApplyAngleOffset(hand, QAngle(self.FOV / 2, 0, 0)) * self.LENGTH, 255, 127, 0, true, self.UPDATE_INTERVAL)

            return self.UPDATE_INTERVAL

        end;



        PopulatePrimaryEntityList = function (self, hand, partialEntityList, index)

            -- We filter entities out of the detection volume here manually instead of using a Validity instance to very specifically control & optimize what is filtered
            local currentIndex = 0
            for i, entity in pairs(partialEntityList) do
                --CustomDebug.DrawEntityOrigin(entity, 4, true, self.UPDATE_INTERVAL)
                -- Prefilter unwanted entity classes
                local allow = false
                local entityClassname = entity:GetClassname()
                for _, classname in pairs(DetectionSphere.ALLOW_CLASSNAME) do
                    if entityClassname:match(classname) then allow = true break end
                end
                if allow then
                    local handToEntity = entity:GetCenter() - hand:GetCenter()
                    local incidence = hand:GetForwardVector():Dot(handToEntity:Normalized())    -- TODO: Allow for offset here, as we no longer are using Validity for incidence calculations
                    -- Prefilter entities that aren't within the desired cone and you don't have line-of-sight to, saves on CPU overhead later
                    if (incidence >= self.INCIDENCE_AT_MAX_ANGLE
                    and (Validity.RaycastToEntity(hand, entity)
                      or entityClassname:match("point_vort_energy")) ) then   -- TODO: mask out debris in raycast
                        self.validIncidenceList[index + i] = incidence
                        self.entityList[index + i] = entity
                        --DebugDrawLine(hand:GetCenter(), entity:GetCenter(), 0, 255, 0, true, self.UPDATE_INTERVAL)
                    else
                        --DebugDrawLine(hand:GetCenter(), entity:GetCenter(), 0, 0, 255, true, self.UPDATE_INTERVAL)
                    end
                   
                else
                    --print(entityClassname)
                    --DebugDrawLine(hand:GetCenter(), entity:GetCenter(), 255, 0, 0, true, self.UPDATE_INTERVAL)
                end
                currentIndex = i
            end

            --DebugDrawLine(hand:GetCenter(), hand:GetCenter() + hand:GetForwardVector() * 10, 255, 0, 0, true, self.UPDATE_INTERVAL)

            return index + currentIndex

        end;
    },

    {
        __class__name = "DetectionSphere";

        DEFAULT_RADIUS          = 405;
        DEFAULT_FORWARD_OFFSET  = -10;
        DEFAULT_UPDATE_INTERVAL = 0.05;

        ALLOW_CLASSNAME = {
            ".*physic.*",
            "item_.+",
            "prop_reviver_heart",
            "npc_headcrab.*",
            "npc_antlion.*",
            "npc_manhack.*",
            "prop_ragdoll",
            "point_vort_energy",
        };

        REDUCED_RADIUS_MAP_NAME = {
            "a3_hotel_lobby_basement",
            "a3_hotel_underground_pit",
            "a3_hotel_interior_rooftop",
        };
        REDUCED_RADIUS_FACTOR = 2;
    },

    nil
)
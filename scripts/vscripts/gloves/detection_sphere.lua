require "/customutils"



DetectionSphere = class(

    {

        RADIUS;             -- The radius of the detection sphere
        FORWARD_OFFSET;     -- How far forward or back the the sphere's EDGE should be in relation to its parent (the hand)
        UPDATE_INTERVAL;

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

            self.entityList = Entities:FindAllInSphere(hand:GetAbsOrigin() + sphereOffset * hand:GetForwardVector(), self.RADIUS)
            self.validIncidenceList = {}

            -- We filter entities out of the detection volume here manually instead of using a Validity instance to very specifically control & optimize what is filtered
            for i, entity in pairs(self.entityList) do
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
                    and Validity.RaycastToEntity(hand, entity) ) then   -- TODO: mask out debris in raycast
                        self.validIncidenceList[i] = incidence
                    else
                        self.entityList[i] = nil
                    end
                   
                else
                    --print(entityClassname)
                    self.entityList[i] = nil
                end
            end

            --DebugDrawLine(hand:GetCenter(), hand:GetCenter() + hand:GetForwardVector() * 10, 255, 0, 0, true, self.UPDATE_INTERVAL)

            return self.UPDATE_INTERVAL

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
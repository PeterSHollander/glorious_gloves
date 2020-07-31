HealthStatus = class(

    {
        health;

        lowHeart;
        midHeart;
        highHeart;



        -- Creates 3 red glowy blobs that shrink in size depending on player health; serves as a temporary replacement for the default health status indicator
        constructor = function (self, parent, offset, angleOffset, attachment)
            
            if offset then offset = Vector(offset.x, offset.y, offset.z) else offset = Vector(0, 0, 0) end
            angleOffset = angleOffset or QAngle(0, 0, 0)
            attachment = attachment or ""
            
            local tProperties = {
                disableshadows = 1;
                model = HealthStatus.HEART_MODELNAME;
                disablereceiveshadows = 1;
                spawnflags = CreateSpawnflags( { 8, 9 } );
                renderamt = 191;
                rendercolor = "255 0 0";
                ScriptedMovement = 1;
                forcenpcexclude = 1;
            }
            
            -- TODO: Would love these "hearts" to all be parented to a single removable entity; but seemingly can't parent a prop_dynamic to a non-modelled entity (at least info_target had caused crashes upon unloading)            
            self.lowHeart = SpawnEntityFromTableSynchronous("prop_dynamic", tProperties)
            self.midHeart = SpawnEntityFromTableSynchronous("prop_dynamic", tProperties)
            self.highHeart = SpawnEntityFromTableSynchronous("prop_dynamic", tProperties)

            self.lowHeart:SetEntityName(HealthStatus.ENTITY_NAME .. "_low")
            self.lowHeart:SetParent(parent, attachment)

            self.midHeart:SetEntityName(HealthStatus.ENTITY_NAME .. "_mid")
            self.midHeart:SetParent(parent, attachment)

            self.highHeart:SetEntityName(HealthStatus.ENTITY_NAME .. "_high")
            self.highHeart:SetParent(parent, attachment)

            -- TODO: Confirm this orients correctly for left-hand dominant users?
            local angles = RotateOrientation(angleOffset, HealthStatus.HEART_ROTATION)
            if Input.GetPrimaryHand() == Input.LEFT then
                offset.y = -offset.y
            end

            self.lowHeart:SetLocalAngles(angles.x, angles.y, angles.z)
            self.lowHeart:SetLocalOrigin(offset - angleOffset:Forward() * HealthStatus.HEART_SPACING)

            self.midHeart:SetLocalAngles(angles.x, angles.y, angles.z)
            self.midHeart:SetLocalOrigin(offset)
            
            self.highHeart:SetLocalAngles(angles.x, angles.y, angles.z)
            self.highHeart:SetLocalOrigin(offset + angleOffset:Forward() * HealthStatus.HEART_SPACING)
                       
            -- I don't like the asymmetry of lowHeart being the one to run the UpdateStatus function
            self.lowHeart:SetThink(function() return self:UpdateStatus() end, "UpdateHealthStatus")
            
        end;



        UpdateStatus = function (self)

            local currentHealth = Entities:GetLocalPlayer():GetHealth()
            if self.health ~= currentHealth then

                self.health = currentHealth

                self:SetHeartScale(self.lowHeart, 0, 1/3)
                self:SetHeartScale(self.midHeart, 1/3, 2/3)
                self:SetHeartScale(self.highHeart, 2/3, 1)

            end

            return HealthStatus.UPDATE_INTERVAL

        end;



        SetHeartScale = function (self, entity, minHealth, maxHealth)
            local healthFactor = (self.health - minHealth * HealthStatus.MAX_HEALTH) / (maxHealth * HealthStatus.MAX_HEALTH - minHealth * HealthStatus.MAX_HEALTH)
            entity:SetAbsScale(Clamp(healthFactor, HealthStatus.MIN_SCALE, 1) * HealthStatus.MAX_SCALE)
        end;



        Remove = function (self)
            print("Removing health status")
            if IsValidEntity(self.lowHeart) then self.lowHeart:RemoveSelf() end
            if IsValidEntity(self.midHeart) then self.midHeart:RemoveSelf() end
            if IsValidEntity(self.highHeart) then self.highHeart:RemoveSelf() end
        end;
    },

    {
        __class__name = "HealthStatus";
        
        ENTITY_NAME = "glorious_glove_health_status";
        HEART_MODELNAME = "models/particle/sin_sphere.vmdl";

        UPDATE_INTERVAL = 0.1;
        MAX_HEALTH = 100;
        MIN_SCALE = 0.001;
        MAX_SCALE = 0.2;
        HEART_SPACING = 0.48;
        HEART_ROTATION = QAngle(0, 113, 0);
    },

    nil
)



HealthStatus.Precache = function (context)
    PrecacheModel(HealthStatus.HEART_MODELNAME, context)
end
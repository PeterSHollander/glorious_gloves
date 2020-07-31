require "device/input"
require "gloves/lib/validity"

local CustomDebug = require "/debug"



Tether = class(

    {

        targetValidity;
        targetEntity;

        tetherValidity;
        tetheredEntity;
        -- TODO: Currently only use movingEntity for Grabbity, and exposing it here so Levitate can listen; messy
        movingEntity;
        moveTime;



        -- TODO: Generalize? Currently all baked-in values for core tether only

        constructor = function (self, glove)

            self.targetEntity = nil
            self.tetheredEntity = nil
            self.movingEntity = nil

            self.targetValidity = Validity( {
                maxDistance = glove.detector.LENGTH;
                maxMass = 250;
                maxSize = 200;
                minIncidence = glove.INCIDENCE_AT_MAX_ANGLE;
                ignoreItemAttachments = false;
            } )

            local angleOffset = QAngle(Tether.TETHER_ANGLE_OFFSET_THUMB, Tether.TETHER_ANGLE_OFFSET_PALM, 0)
            if Input.GetHandSelection(glove.hand) == Input.RIGHT then angleOffset.y = -angleOffset.y end

            self.tetherValidity = self.targetValidity:Copy( {
                minDistance = 0;
                maxDistance = self.targetValidity.maxDistance + Tether.TETHER_DISTANCE_BUFFER;
                minIncidence = -1;
                angleOffset = angleOffset;
            } )

        end;



        Target = function (self, glove)
            
            local wasTargeting = self.targetEntity
            self.targetEntity = self.targetValidity:FilterBestEntity(glove.hand, glove.detector.entityList)

            --[[
            if self.targetEntity then CustomDebug.DrawEntityBoundingBox(self.targetEntity, 255, 191, 127, false, glove.UPDATE_INTERVAL) end
            --]]

            if wasTargeting ~= self.targetEntity then

                if self.targetEntity then

                    glove:PrintVerbose("New Glove target found")
                    
                    for i, behaviour in pairs(glove.behaviours) do
                        if behaviour.OnTarget then if behaviour:OnTarget(glove) then
                            glove:PrintVerbose("Glove behaviour [" .. i .. "] successfully targetted")
                            break
                        end end
                    end

                else
                    self:Untarget(glove)
                end
            end
        end;



        Tether = function (self, glove, entity)

            self.tetheredEntity = entity or self.targetEntity

            if IsValidEntity(self.tetheredEntity) then

                glove:PrintVerbose("Glove tethered")
                
                for i, behaviour in pairs(glove.behaviours) do
                    if behaviour.OnTether then if behaviour:OnTether(glove) then
                        glove:PrintVerbose("Glove behaviour [" .. i .. "] successfully tethered")
                        break
                    end end
                end

            end
        end;



        Untarget = function (self, glove)

            if self.targetEntity then

                glove:PrintVerbose("Glove target lost")
                
                self.targetEntity = nil

                for i, behaviour in pairs(glove.behaviours) do
                    if behaviour.OnUntarget then behaviour:OnUntarget(glove) end
                end

            end

        end;



        Untether = function (self, glove)

            if self.tetheredEntity then

                glove:PrintVerbose("Glove tether disconnected")

                self.tetheredEntity = nil
                
                for i, behaviour in pairs(glove.behaviours) do
                    if behaviour.OnUntether then behaviour:OnUntether(glove) end
                end

            end

        end;



        ValidateTether = function (self, glove)

            if self.tetheredEntity then

                if (self.tetherValidity:GetValidity(glove.hand, self.tetheredEntity) <= 0) then
                    glove:PrintVerbose("Glove tether no longer valid")
                    self:Untether(glove)
                end

                if self.targetEntity then

                    if (self.targetValidity:GetValidity(glove.hand, self.targetEntity) <= 0) then
                        glove:PrintVerbose("Glove target no longer valid")
                        self:Untarget(glove)
                    end

                end

                --[[
                if IsValidEntity(self.tetheredEntity) then
                    CustomDebug.DrawEntityBoundingBox(self.tetheredEntity, 255, 127, 0, false, glove.UPDATE_INTERVAL, 0.2)
                    DebugDrawLine(glove.hand:GetAbsOrigin(), self.tetheredEntity:GetCenter(), 255, 127, 0, false, glove.UPDATE_INTERVAL)
                end
                --]]

            end
        end;

    },

    {
        __class__name = "Tether";

        TETHER_DISTANCE_BUFFER = 10;
        RENDER_INTERVAL = 1 / 144;

        -- TODO: Currently setting these offsets to accomodate grabbity tether cutoff, shouldn't be dependant on that
        TETHER_ANGLE_OFFSET_THUMB = 0; -- -20;
        TETHER_ANGLE_OFFSET_PALM = 0; -- 20;
    },

    nil

)
require "device/input"
require "device/haptics"
require "gloves/detection_sphere"
require "gloves/lib/motion"
require "gloves/lib/tether"
require "gloves/lib/validity"
require "gloves/lib/gesture"
require "gloves/behaviours/grabbity"
require "gloves/behaviours/levitate"
require "gloves/behaviours/punt"

local CustomDebug = require "/debug"



Glove = class(

    {
        UPDATE_INTERVAL;
        IDENTIFIER;
        INCIDENCE_AT_MAX_ANGLE;

        enabled;

        hand;
        model;
        detector;
        tether;
        behaviours;

        motion;

        eventList;



        -- TODO: Manage model, health status, ammo counter, etc here instead of in gloves/integration/replace_gravity_gloves.lua?



        constructor = function (self, handSelection, trigger, radius, forwardOffset, updateInterval)

            print("Initializing custom Gravity Glove (" .. handSelection .. ")...")
            
            self.IDENTIFIER = UniqueString()

            self.alreadyFired = false
            
            self.hand = self:CreateHand(handSelection, trigger)
            --self.model = self:CreateModel(handSelection)
            self.detector = DetectionSphere(self.hand, trigger, radius, forwardOffset)
            self.behaviours = {}
            self:CheckForWeapon(handSelection)

            self.UPDATE_INTERVAL = updateInterval or Glove.DEFAULT_UPDATE_INTERVAL
            self.INCIDENCE_AT_MAX_ANGLE = math.cos(math.rad(self.detector.FOV / 2));

            self.tether = Tether(self)
            self.motion = Motion(self.hand)

            self.hand:SetThink(function() return self:BaseGloveLogic() end, "GloveUpdate" .. self.IDENTIFIER .. tostring(handSelection))

            self.eventList = {
                ListenToGameEvent("player_opened_game_menu", function(context) self:Disable(context) end, nil);
                ListenToGameEvent("player_closed_game_menu", function(context) self:Enable(context) end, nil);
                ListenToGameEvent("item_pickup", function(context) self:Disable(context, true) end, nil);
                ListenToGameEvent("item_released", function(context) self:Enable(context) end, nil);
                ListenToGameEvent("weapon_switch", function(context) self:OnWeaponSwitch(context) end, nil);
            }
            
        end;



        BaseGloveLogic = function (self)

            self.motion:Update(self.hand)

            --[[
            local trigger = self.detector.trigger
            DebugDrawLine(trigger:GetAbsOrigin(), trigger:GetAbsOrigin() + trigger:GetForwardVector() * self.detector.LENGTH, 0, 127, 85, false, self.UPDATE_INTERVAL)
            CustomDebug.DrawCone(trigger:GetAbsOrigin(), trigger:GetForwardVector(), trigger:GetUpVector(), self.INCIDENCE_AT_MAX_ANGLE, self.detector.LENGTH, 0, 191, 127, false, self.UPDATE_INTERVAL)
            --]]

            if self.enabled then

                if (self.motion.handState == Gesture.HAND_OPEN) then
                    self.tether:Target(self)
                elseif (self.motion.handState == Gesture.HAND_CLOSING) then
                    self:PrintVerbose("Glove hand is closing")
                    self.tether:Tether(self)
                elseif (self.motion.handState == Gesture.HAND_CLOSED) then
                    self.tether:ValidateTether(self)
                elseif (self.motion.handState == Gesture.HAND_OPENING) then
                    self:PrintVerbose("Glove hand is opening")
                    self.alreadyFired = false
                    self.tether:Untether(self)
                    self.tether:Target(self)
                end

                for i, behaviour in pairs(self.behaviours) do
                    if behaviour:DispatchBehaviour(self) then
                        self:PrintVerbose("Glove behaviour [" .. i .. "] successfully executed")
                        break
                    end
                end

            end

            return self.UPDATE_INTERVAL

        end;


        
        CheckForWeapon = function (self, handSelection)
            if (handSelection == Input.GetPrimaryHand()) then
                self:PrintVerbose("Glove hand is primary - enabling glove if weapon is not equipped")
                local playerProxy = SpawnEntityFromTableSynchronous("logic_playerproxy", {} )
                AddEntityOutput(playerProxy, "OnWeaponNotActive", self.detector.trigger, "CallScriptFunction", "EnableGlove")
                EntFireByHandle(self.hand, playerProxy, "TestWeaponActive", "", 1/30)
                EntFireByHandle(self.hand, playerProxy, "Kill", "", 1)
            else
                self:Enable()
            end
        end;



        CreateHand = function (self, handSelection, hand)

            Glove.Print("Creating Glove hand (" .. handSelection .. ") entity")

            --[[local hand = SpawnEntityFromTableSynchronous("info_target", {
                targetname = "glorious_glove" .. self.IDENTIFIER .. "hand_" .. handSelection;
                spawnflags = {
                    [1] = 1;
                };
            } )--]]
            
            hand:SetEntityName("glorious_glove" .. self.IDENTIFIER .. "hand_" .. handSelection)

            local angles = QAngle(-Glove.HAND_ANGLE_OFFSET_THUMB, -Glove.HAND_ANGLE_OFFSET_PALM, 0)     -- Why do I need to negate my angles here?
            if handSelection == Input.RIGHT then angles.y = -angles.y end

            local handRenderable = Input.GetHandRenderable(handSelection)
            angles = RotateOrientation(handRenderable:GetAngles(), angles)

            hand:SetAbsOrigin(handRenderable:GetAbsOrigin())
            hand:SetAngles(angles.x, angles.y, angles.z)
            hand:SetParent(handRenderable, "grabbity_glove")

            return hand

        end;



        CreateModel = function (self, handSelection)

            self:PrintVerbose("Creating Glove model")

            local tProperties = {
                targetname = "glorious_glove" .. self.IDENTIFIER .. "model_" .. handSelection;
                model = "models/hands/grabbity_glove_model.vmdl";
                ScriptedMovement = 1;
                updatechildren = 1;
                use_animgraph = 1;
                forcenpcexclude = 1;
            }

            if handSelection == Input.RIGHT then tProperties.scales = "1 -1 1" end

            local model = SpawnEntityFromTableSynchronous("prop_dynamic", tProperties)
            local attach = model:ScriptLookupAttachment("attach_origin")
            model:SetParent(Input.GetHandRenderable(handSelection), "grabbity_glove") -- Can't parent to our hand (an info_target), as a prop_dynamic needs to parent to another model-based entity it would seem
            model:SetLocalOrigin(Vector(0, 0, 0))
            local angles = Vector(0, 0, 0)
            model:SetLocalAngles(angles.x, angles.y, angles.z)
            
            return model

        end;


        
        PlaySound = function (self, soundEvent, loop)
            loop = loop or false
            if loop then
                self:StopActiveLoop()
                self.activeLoop = soundEvent
            end
            self:PrintVerbose("Playing \"" .. soundEvent .. "\" on Glove")
            EmitSoundOn(soundEvent, self.hand)
        end;

        -- TODO: This is quick & dirty - assumes there will only ever be one loop playing
        StopLoop = function (self, soundEvent)
            if soundEvent == self.activeLoop then
                self:StopActiveLoop()
            end
        end;

        StopActiveLoop = function (self)
            if self.activeLoop ~= nil then
                self:PrintVerbose("Stopping active loop \"" .. self.activeLoop .. "\" on Glove")
                StopSoundOn(self.activeLoop, self.hand)
            end
        end;



        OpenClaws = function (self)
            self:PrintVerbose("Opening claws on Glove")
            self:PlaySound("PhysCannon.ClawsOpen")
            Glove.HAPTIC_CLAWS_OPEN:Fire(self.hand)
        end;

        CloseClaws = function (self)
            self:PrintVerbose("Closing claws on Glove")
            self:PlaySound("PhysCannon.ClawsClose")
            Glove.HAPTIC_CLAWS_CLOSE:Fire(self.hand)
        end;

        GlowClaws = function (self)
            self:PrintVerbose("Glowing claws on Glove")
            -- TODO: Particle glow, needs model
        end;



        AddBehaviour = function (self, behaviour)
            self.behaviours[#self.behaviours + 1] = behaviour
        end;



        Enable = function (self, eventInfo)
            if (eventInfo == nil
             or eventInfo["vr_tip_attachment"] == Input.GetEventHandSelection(self.hand)
             or eventInfo["vr_tip_attachment"] == nil) then
                self:PrintVerbose("Glove is enabled")
                self.enabled = true
            end
        end;

        Disable = function (self, eventInfo, checkForRelease)
            checkForRelease = checkForRelease or false
            if (eventInfo == nil
             or eventInfo["vr_tip_attachment"] == Input.GetEventHandSelection(self.hand)
             or eventInfo["vr_tip_attachment"] == nil) then
                self:PrintVerbose("Glove is disabled")
                self.tether:Untether(self)
                self.tether:Untarget(self)
                self.alreadyFired = false
                self.enabled = false
                if checkForRelease then
                    -- TODO: This is a hack, item_released event does not fire if the item is forced out of the player's hand / destroyed
                    self:PrintVerbose("Watching if hand releases item, in case it doesn't fire a game event")
                    local useGrip = Input.GetDigitalAction(Input.USE_GRIP, self.hand)
                    self.hand:SetThink(function() return self:WatchForRelease(useGrip) end, "WatchingIfHandReleasesObject")
                end
            end
        end;

        WatchForRelease = function (self, useGrip)
            local interval = 0.1
            if self.enabled then
                self:PrintVerbose("Glove is enabled; no need to watch for release anymore")
                return nil
            elseif not Input.GetDigitalAction(Input.USE_REQ, self.hand) then
                if useGrip then
                    if Input.GetDigitalAction(Input.USE_GRIP, self.hand) then
                        return interval
                    end
                end
                self:PrintVerbose("Observed hand input releasing held item")
                self:Enable()
                return nil
            end
            return interval
        end;

        OnWeaponSwitch = function (self, eventInfo)
            if (Input.GetHandSelection(self.hand) == Input.GetPrimaryHand()) then
                if (eventInfo["item"] ~= "hand_use_controller") then
                    self:PrintVerbose("Weapon switched to non-hand")
                    self:Disable(eventInfo)
                else
                    self:PrintVerbose("Weapon switched to hand")
                    self:Enable(eventInfo)
                end
            end
        end;



        PrintVerbose = function (self, message)
            if Glove.VERBOSE then
                local hand = "Unknown"
                if Input.GetHandSelection(self.hand) == Input.LEFT then hand = "Left"
                elseif Input.GetHandSelection(self.hand) == Input.RIGHT then hand = "Right" end
                print("GGVerbose>" .. hand .. " (" .. self.IDENTIFIER .. "): " .. message)
            end
        end;



        -- TODO: This feels very sloppy. Good thing I'm not using it except for reverting the gloves at the end of a level?
        RemoveGlove = function (self)
            print("Removing Glorious Glove " .. self.IDENTIFIER .. "...")
            self.UPDATE_INTERVAL = nil
            self:Disable()
            for i, event in pairs(self.eventList) do
                StopListeningToGameEvent(event)
                self.eventList[i] = nil
            end
            for i, behaviour in pairs(self.behaviours) do
                if behaviour.RemoveBehaviour then behaviour:RemoveBehaviour(self) end
            end
            self.detector.entityList = {}
            if IsValidEntity(self.detector.trigger) then
                self:PrintVerbose("Removing detector trigger")
                self.detector.trigger:RemoveSelf() end
            if IsValidEntity(self.model) then
                self:PrintVerbose("Removing glove model")
                self.model:RemoveSelf() end
            if IsValidEntity(self.hand) then
                self:PrintVerbose("Removing hand entity")
                self.hand:RemoveSelf() end
            self.tether.targetEntity = nil
            self.tether.tetheredEntity = nil
            print("Glorious Glove " .. self.IDENTIFIER .. " removal complete")
            -- TODO: Remove the class instances as well? How?
        end;

    },

    {
        __class__name = "Glove";
        
        VERBOSE = true;

        DEFAULT_UPDATE_INTERVAL = 1 / 48;

        HAND_ANGLE_OFFSET_THUMB = -7;
        HAND_ANGLE_OFFSET_PALM = 7;

        HAPTIC_CLAWS_OPEN = HapticSequence(0.15, 0.034, 1/126);--0.87
        HAPTIC_CLAWS_CLOSE = HapticSequence(0.085, 0.01, 1/500);--0.73
    },

    nil

)



Glove.Print = function (message)
    if Glove.VERBOSE then
        print("GGVerbose>" .. message)
    end
end
require "device/input"
require "gloves/lib/gesture"



Motion = class(

    {

        ARM_MASS = 12;  -- TODO: Reevaluate values based on arm mass; I had assumed this was in pounds, but I believe Valve uses kilograms (because who needs measurement system consistency?)



        handState;
        handIsClosed;
        handClosedTime;

        velocity;
        acceleration;
        force;

        angles;
        angularVelocity;

        time;



        constructor = function (self, hand)
            self.handIsClosed = Input.GetDigitalAction(Input.GRAV_GLOVE_LOCK_REQ, hand)
            self.velocity = Input.GetController(hand):GetVelocity()
            self.angles = hand:GetAngles()
            self.time = Time()
            self.handClosedTime = self.time
        end;



        Update = function (self, hand)
            self:UpdateHandState(hand)
            self:UpdateMotion(hand)
        end;



        UpdateHandState = function (self, hand)
            
            local handWasClosed = self.handIsClosed
            self.handIsClosed = Input.GetDigitalAction(Input.GRAV_GLOVE_LOCK_REQ, hand)
            
            if (self.handIsClosed) then
                if (handWasClosed) then
                    self.handState = Gesture.HAND_CLOSED
                else
                    self.handState = Gesture.HAND_CLOSING
                    self.handClosedTime = Time()
                end
            else
                if (handWasClosed) then
                    self.handState = Gesture.HAND_OPENING
                else
                    self.handState = Gesture.HAND_OPEN
                end
            end

        end;



        UpdateMotion = function (self, hand)

            local time = Time()
            local updateInterval = time - self.time
            self.time = time
            
            local prevVelocity = self.velocity
            self.velocity = Input.GetController(hand):GetVelocity()
            self.acceleration = (self.velocity - prevVelocity) / updateInterval
            self.force = self.ARM_MASS * self.acceleration

            -- These values are pitch, yaw, roll around the world axes (around y, around z, around x, I think) in degrees
            local prevAngles = self.angles
            self.angles = hand:GetAngles()
            -- This returns an axis-of-rotation vector, multiplied by the angle rotated in degrees
            local angularVelocityDegrees = RotationDeltaAsAngularVelocity(prevAngles, self.angles) / updateInterval
            -- Convert from degrees to radians (and updated the wiki to reflect this standard)
            self.angularVelocity = Vector(
                math.rad(angularVelocityDegrees.x),
                math.rad(angularVelocityDegrees.y),
                math.rad(angularVelocityDegrees.z) )

        end;



        ApplyForce = function (self, entity, duration, maxAcceleration)

            duration = duration or Motion.DEFUALT_FORCE_DURATION
            maxAcceleration = maxAcceleration or Motion.DEFAULT_MAX_ACCELERATION

            local speed = math.max(self.force:Length() / entity:GetMass() * duration, maxAcceleration * duration)
            local velocity = speed * self.velocity:Normalized()

            entity:ApplyAbsVelocityImpulse(velocity)

            --DebugDrawLine(entity:GetCenter(), entity:GetCenter() + velocity * duration, 191, 191, 191, true, 2)

        end;

    },

    {
        __class__name = "Motion";

        GRAVITY = Vector(0, 0, -32) * 12;   -- ft/s/s
        DEFAULT_FORCE_DURATION = 0.1;
        DEFAULT_MAX_ACCELERATION = 750
    },

    nil
    
)
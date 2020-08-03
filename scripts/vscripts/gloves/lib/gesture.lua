Gesture = class(

    {

        handState;
        motionType;
        motionDirection;
        relativeTo;
        useVelocityDirection;
        velocityDirectionFactor;
        motionThreshold;
        minMotionIncidence;
        maxMotionIncidence;
        angleOffset;



        constructor = function (self, tGesture)
            self.handState = tGesture.handState or Gesture.HAND_ANY
            self.motionType = tGesture.motionType or Gesture.MOTION_NONE
            self.motionDirecton = tGesture.motionDirection or Gesture.MOTION_ANY
            self.relativeTo = tGesture.relativeTo or nil
            self.useVelocityDirection = tGesture.useVelocityDirection or false
            self.velocityDirectionFactor = tGesture.velocityDirectionFactor or 1
            self.motionThreshold = tGesture.motionThreshold or Gesture.THRESHOLD_NONE
            self.minMotionIncidence = tGesture.minMotionIncidence or Gesture.BACKWARD
            self.maxMotionIncidence = tGesture.maxMotionIncidence or Gesture.FORWARD
            self.angleOffset = tGesture.angleOffset or Gesture.OFFSET_NONE
        end;



        IsGesturing = function (self, motion, forwardReference, upReference, requireFacingMotion)    -- requireFacingMotion means both the forward vector (with angle offset) and the motion vector (with angle offset) must satisfy incidence

            forwardReference = forwardReference or motion.angles:Forward()
            upReference = upReference or motion.angles:Up()

            forwardReference = ApplyAngleOffset(nil, self.angleOffset, forwardReference, upReference)

            local motionVector = Vector(0, 0, 0)
            if (self.motionType == Gesture.MOTION_VELOCITY) then motionVector = motion.velocity
            elseif (self.motionType == Gesture.MOTION_ACCELERATION) then motionVector = motion.acceleration
            elseif (self.motionType == Gesture.MOTION_FORCE) then motionVector = motion.force:Length()
            elseif (self.motionType == Gesture.MOTION_ANGULAR_VELOCITY) then motionVector = motion.angularVelocity end

            if (self.motionType == Gesture.MOTION_ACCELERATION or self.motionType == Gesture.MOTION_FORCE) then

                if (motionVector:Dot(motion.velocity) < 0) then
                    if (self.motionDirection == Gesture.MOTION_INCREASING) then
                        motionVector = Vector(0, 0, 0)
                    end
                else
                    if (self.motionDirection == Gesture.MOTION_DECREASING) then
                        motionVector = Vector(0, 0, 0)
                    end
                end

                if self.useVelocityDirection then
                    motionVector = motionVector * (1 - self.velocityDirectionFactor) + (motionVector:Length() * motion.velocity:Normalized()) * self.velocityDirectionFactor
                end

            end

            if ((motion.handState == self.handState or self.handState == Gesture.HAND_ANY)
            and motionVector:Length() >= self.motionThreshold) then

                local motionIncidence = forwardReference:Dot(motionVector:Normalized())

                if (motionIncidence >= self.minMotionIncidence
                and motionIncidence <= self.maxMotionIncidence) then

                    if requireFacingMotion then

                        forwardReference = ApplyAngleOffset(nil, self.angleOffset, motion.angles:Forward(), motion.angles:Up())
                        motionIncidence = forwardReference:Dot(motionVector:Normalized())
                        if (motionIncidence >= self.minMotionIncidence
                        and motionIncidence <= self.maxMotionIncidence) then

                            return true

                        end
                        
                    else

                        return true

                    end
                end
            end

            return false

        end;

    },

    {
        __class__name = "Gesture";

        THRESHOLD_NONE = 0;

        MOTION_NONE = 0;
        MOTION_VELOCITY = 1;
        MOTION_ACCELERATION = 2;
        MOTION_FORCE = 3;
        MOTION_ANGULAR_VELOCITY = 4;

        MOTION_ANY = 0;
        MOTION_INCREASING = 1;
        MOTION_DECREASING = 2;

        HAND_ANY = 0;
        HAND_OPENING = 1;
        HAND_OPEN = 2;
        HAND_CLOSING = 3;
        HAND_CLOSED = 4;

        FORWARD = 1;
        BACKWARD = -1;

        OFFSET_NONE = QAngle(0, 0, 0)
    },

    nil

)
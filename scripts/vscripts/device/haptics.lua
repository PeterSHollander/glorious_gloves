HapticSequence = class(

    {

        IDENTIFIER;

        duration;
        pulseWidth_us;
        pulseInterval;



        constructor = function (self, duration, pulseStrength, pulseInterval)

            self.IDENTIFIER = UniqueString()

            self.duration = duration or 0.5

            pulseInterval = pulseInterval or 0.01

            -- NOTE: Think function intervals cannot exceed framerate!
            self.pulseInterval = math.min(FrameTime(), pulseInterval)   -- TODO: How reliable is FrameTime() for getting the *target* framerate?
            
            pulseStrength = pulseStrength or 0.1
            pulseStrength = Clamp(pulseStrength, 0, 1)
            pulseStrength = pulseStrength * pulseStrength

            self.pulseWidth_us = 0
            if pulseStrength > 0 then
                self.pulseWidth_us = Lerp(pulseStrength, HapticSequence.MIN_PULSE_WIDTH, HapticSequence.MAX_PULSE_WIDTH)
            end

        end;



        Fire = function (self, hand)

            local controller = Input.GetController(hand)

            local ref = {
                increment = 0;
                prevTime = Time();
            }
   
            -- NOTE: Having this Thinker have a UniqueString() in its name caused save/load crashes after calling it 100+ times.
            --       Giving it a constant name that is overwritable allows would appear to have quelled this issue?
            controller:SetThink(function()
                controller:FireHapticPulsePrecise(self.pulseWidth_us)
                if ref.increment < self.duration then
                    local currentTime = Time()
                    ref.increment = ref.increment + (currentTime - ref.prevTime)
                    ref.prevTime = currentTime
                    return self.pulseInterval
                else return nil end
            end, "Fire" .. self.IDENTIFIER .. "Haptic", 0)

        end;

    },

    {
        __class__name = "HapticSequence";

        MIN_PULSE_WIDTH = 1;
        MAX_PULSE_WIDTH = 30;
    },

    nil
)
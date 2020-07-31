-- TODO: Legacy "class" structure - refactor as a Valve class

local CustomDebug = {}



    function CustomDebug.DrawOrigin (entity, length, interval)

        local origin = entity:GetAbsOrigin()
        DebugDrawLine(origin, origin + entity:GetForwardVector() * length, 255, 0, 0, true, interval)
        DebugDrawLine(origin, origin + entity:GetRightVector() * length, 0, 255, 0, true, interval)
        DebugDrawLine(origin, origin + entity:GetUpVector() * length, 0, 0, 255, true, interval)

        return interval

    end



    function CustomDebug.DrawArc (startPos, endPos, arcHeight, arcDirection, segments, r, g, b, ztest, duration)
        -- I don't feel like thinking about this one, so let's just rip it from the physics arc
        local airTime = 1

        local timeIncrement = airTime / segments
        local time = timeIncrement
        local previousPos = startPos
        local acceleration = -arcDirection:Normalized() * arcHeight

        local desiredVelocity = (endPos - startPos) / airTime - (acceleration * airTime) / 2.0

        while (time <= airTime) do
            local currentPos = desiredVelocity * time + acceleration * time * time / 2.0 + startPos
            DebugDrawLine(previousPos, currentPos, r, g, b, ztest, duration)
            previousPos = currentPos
            time = time + timeIncrement
        end
    end



    function CustomDebug.DrawPhysicsArc(startPos, initialVelocity, acceleration, duration, segments)

        local timeIncrement = duration / segments
        local time = timeIncrement
        local previousPos = startPos

        while time < duration do
            local currentPos = initialVelocity * time + acceleration * time * time / 2.0 + startPos
            DebugDrawLine(previousPos, currentPos, 255, 0, 0, false, 2.0)
            previousPos = currentPos
            time = time + timeIncrement
        end

    end



    function CustomDebug.DrawCircle (origin, forward, up, radius, r, g, b, ztest, duration)
        -- TODO
    end



    function CustomDebug.DrawCone (origin, forward, up, incidence, length, r, g, b, ztest, duration)

        local incidentHypoteneus = math.abs(1 / incidence)
        local incidentOffset = math.sqrt(incidentHypoteneus * incidentHypoteneus - 1)

        forward = forward:Normalized()
        if (incidence < 0) then forward = -forward end
        up = (up - up:Dot(forward) / forward:Dot(forward) * forward):Normalized()
        local right = forward:Cross(up):Normalized()

        -- TODO: Do this procedurally, please
        DebugDrawLine(origin, origin + (forward + up * incidentOffset) * length, r, g, b, ztest, duration)
        DebugDrawLine(origin, origin + (forward - up * incidentOffset) * length, r, g, b, ztest, duration)
        DebugDrawLine(origin, origin + (forward + right * incidentOffset) * length, r, g, b, ztest, duration)
        DebugDrawLine(origin, origin + (forward - right * incidentOffset) * length, r, g, b, ztest, duration)

        DebugDrawLine(origin, origin + (forward + (up + right):Normalized() * incidentOffset) * length, r, g, b, ztest, duration)
        DebugDrawLine(origin, origin + (forward - (up + right):Normalized() * incidentOffset) * length, r, g, b, ztest, duration)
        DebugDrawLine(origin, origin + (forward + (up - right):Normalized() * incidentOffset) * length, r, g, b, ztest, duration)
        DebugDrawLine(origin, origin + (forward - (up - right):Normalized() * incidentOffset) * length, r, g, b, ztest, duration)


    end



    function CustomDebug.DrawEntityBoundingBox (entity, r, g, b, ztest, duration, offset)
        offset = offset or 0
        CustomDebug.DrawBoxDirectional(entity:GetAbsOrigin(), entity:GetBoundingMins() - Vector(1, 1, 1) * offset, entity:GetBoundingMaxs() + Vector(1, 1, 1) * offset, entity:GetForwardVector(), entity:GetRightVector(), entity:GetUpVector(), r, g, b, ztest, duration)
    end



    function CustomDebug.DrawEntityOrigin (entity, length, ztest, duration)
        CustomDebug.DrawOrigin(entity:GetAbsOrigin(), entity:GetForwardVector(), entity:GetRightVector(), entity:GetUpVector(), length, ztest, duration)
    end



    function CustomDebug.DrawOrigin(origin, forward, right, up, length, ztest, duration)
        DebugDrawLine(origin, origin + forward * length, 255, 0, 0, ztest, duration)
        DebugDrawLine(origin, origin + right * length, 0, 255, 0, ztest, duration)
        DebugDrawLine(origin, origin + up * length, 0, 0, 255, ztest, duration)
    end



    function CustomDebug.DrawBoxDirectional(origin, localMins, localMaxes, forward, right, up, r, g, b, ztest, duration)
        
        local edge = Vector(localMins.x, localMins.y, localMins.z)

        local i = 0 while (i < 2) do i = i + 1
            
            edge.y = localMins.y
            local j = 0 while (j < 2) do j = j + 1

                edge.z = localMins.z
                local k = 0 while (k < 2) do k = k + 1
                    
                    if (i == 1) then DebugDrawLine(
                        origin + localMins.x * forward + edge.y * right + edge.z * up,
                        origin + localMaxes.x * forward + edge.y * right + edge.z * up,
                        r, g, b, ztest, duration)
                    end
                    if (j == 1) then DebugDrawLine(
                        origin + edge.x * forward + localMins.y * right + edge.z * up,
                        origin + edge.x * forward + localMaxes.y * right + edge.z * up,
                        r, g, b, ztest, duration)
                    end
                    if (k == 1) then DebugDrawLine(
                        origin + edge.x * forward + edge.y * right + localMins.z * up,
                        origin + edge.x * forward + edge.y * right + localMaxes.z * up,
                        r, g, b, ztest, duration)
                    end
                    edge.z = localMaxes.z
                end
                edge.y = localMaxes.y
            end
            edge.x = localMaxes.x
        end

    end



return CustomDebug
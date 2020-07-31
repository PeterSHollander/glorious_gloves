Input = class(

    {
        -- TODO: Should I bother using a class since it's all "constants" and "static" functions?
    },

    {
        __class__name = "Input";

        LEFT  = 0;
        RIGHT = 1;
        
        -- TODO: Are the literals always left = 1 and right = 0?
        LEFT_LITERAL  = 1;
        RIGHT_LITERAL = 0;

        -- I'm so glad that the integer representing left and right is so consistent
        LEFT_TIP_ATTACHMENT = 2;
        RIGHT_TIP_ATTACHMENT = 1;

        TOGGLE_MENU_REQ       = 0;
        MENU_INTERACT_REQ     = 1;
        MENU_DISMISS_REQ      = 2;
        USE_REQ               = 3;
        USE_GRIP              = 4;
        SHOW_INVENTORY_REQ    = 5;
        GRAV_GLOVE_LOCK_REQ   = 6;
        FIRE_REQ              = 7;
        ALT_FIRE              = 8;
        RELOAD_REQ            = 9;
        EJECT_MAGAZING_REQ    = 10;
        SLIDE_RELEASE_REQ     = 11;
        OPEN_CHAMBER_REQ      = 12;
        TOGGLE_LASER_SIGHT    = 13;
        TOGGLE_BURST_FIRE_REQ = 14;
        TOGGLE_HEALTH_PEN_REQ = 15;
        ARM_GRENADE_REQ       = 16;
        ARM_XEN_GRENADE_REQ   = 17;
        TELEPORT_REQ          = 18;
        TURN_LEFT             = 19;
        TURN_RIGHT            = 20;
        MOVE_BACK             = 21;
        WALK                  = 22;
        JUMP                  = 23;
        MANTLE                = 24;
        CROUCH_TOGGLE         = 25;
        STAND_TOGGLE          = 26;
        ADJUST_HEIGHT         = 27;

        HAND_CURL           = 0;
        TRIGGER_PULL        = 1;
        SQUEEZE_XEN_GRENADE = 2;
        TELEPORT_TURN_REQ   = 3;
        CONTINUOUS_TURN     = 4;

        CONTROLLER_CLASSNAME      = "hl_prop_vr_hand";
        HAND_RENDERABLE_CLASSNAME = "hlvr_prop_renderable_glove";

        PRIMARY_LEFT_HAND_COMMAND = "hlvr_left_hand_primary";
    },

    nil
)



function Input.GetHandRenderable (hand)

    local controller = Input.GetController(hand)

    if IsValidEntity(controller) then

        for i, child in pairs(controller:GetChildren()) do
            if (child:GetClassname() == Input.HAND_RENDERABLE_CLASSNAME) then
                return child
            end
        end

        Warning(Input.HAND_RENDERABLE_CLASSNAME .. " not found from controller!  Returning the controller itself instead.")

        return controller

    else
        Warning("Controller not found from provided input (" .. tostring(hand) .. ")!")
        return nil
    end

end;



function Input.GetController (hand)

    if (type(hand) == "number"
    and hand == Input.LEFT or hand == Input.RIGHT) then

        local player = Entities:GetLocalPlayer()
        local VRPlayer = player:GetHMDAvatar()
        
        if IsValidEntity(VRPlayer) then
            return VRPlayer:GetVRHand(hand)
        else
            Warning("VR Player not found in Input.GetController()!\n")
            return nil
        end

    elseif IsValidEntity(hand) then

        local classname = hand:GetClassname()

        if (classname == Input.CONTROLLER_CLASSNAME) then
            return hand
        elseif (classname ~= Input.HAND_RENDERABLE_CLASSNAME) then
            hand = hand:GetMoveParent()
        end

        if IsValidEntity(hand) then
            local controller = hand:GetMoveParent()
            if IsValidEntity(controller) then
                return controller
            end
        end

        Warning("Provided \"hand\" entity (" .. hand:GetClassname() .. ") in Input.GetController() does not have valid parent(s)!\n")
        return nil

    else
        Warning("Invalid input type (" .. type(hand) .. ") provided to Input.GetController()!\n")
        return nil
    end

    Warning("Input.GetController(" .. type(hand) .. ") failed to return a value!\n")

end



function Input.GetLiteralHandSelection (hand)
    
    local controller = Input.GetController(hand)
    
    if IsValidEntity(controller) then
        return controller:GetLiteralHandType()
    else
        Warning("Unable to get literal hand selection from invalid controller (" .. type(hand) .. ") in Input.GetLiteralHandSelection()!\n")
        return nil
    end
    
end



function Input.GetHandSelection (hand)
    local literalHand = Input.GetLiteralHandSelection(hand)
    if (literalHand == Input.LEFT_LITERAL) then return Input.LEFT end
    if (literalHand == Input.RIGHT_LITERAL) then return Input.RIGHT end
    Warning("Provided hand (" .. type(hand) .. ") does not match any expected hand selection in Input.GetHandSelection()!\n")
    return nil
end



function Input.GetEventHandSelection (hand)
    local literalHand = Input.GetLiteralHandSelection(hand)
    if (literalHand == Input.LEFT_LITERAL) then return Input.LEFT_TIP_ATTACHMENT end
    if (literalHand == Input.RIGHT_LITERAL) then return Input.RIGHT_TIP_ATTACHMENT end
    Warning("Provided hand (" .. type(hand) .. ") does not match any expected hand selection in Input.GetEventHandSelection()!\n")
    return nil
end



function Input.GetPrimaryHand ()
    if Convars:GetBool(Input.PRIMARY_LEFT_HAND_COMMAND) then
        return Input.LEFT
    else
        return Input.RIGHT
    end
end



function Input.GetDigitalAction (action, hand)
    return Entities:GetLocalPlayer():IsDigitalActionOnForHand(Input.GetLiteralHandSelection(hand), action)
end

function Input.GetAnalogAction (action, hand)
    return Entities:GetLocalPlayer():GetAnalogActionPositionForHand(Input.GetLiteralHandSelection(hand), action)
end
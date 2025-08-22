gdebug.log_info("Birdbox: main")
local mod = game.mod_runtime[game.current_mod]

local storage = game.mod_storage[game.current_mod]
mod.storage = storage

local you = gapi.get_avatar()
local blind_flag = JsonFlagId.new("BLIND")
local head = BodyPartTypeIntId.new(BodyPartTypeId.new("head"))
local marked_for_death = false
local sees_birdbox = false

local messages = {
    "Your eyes catch a shape that isn\'t there--no outline, no shadow, only a wrongness. Your lungs seize as if the world itself has clamped down on your ribs. The last thought isn\'t yours at all.",
    "Something stirs at the edge of your mind, too vast to comprehend, too intimate to ignore. The instant you notice it, your will shatters like glass.",
    "There\'s no sound, no motion--only a presence, pressing against your skull, peeling open the parts of you that were never meant to be touched. You stop resisting.",
    "The world folds inward. Sight, sound, thought--everything you are turns inside out. What remains doesn\'t belong to you anymore.",
    "Your eyes betray you. What they show isn\'t form, but a truth so jagged it guts the mind. The last thing you feel is relief, because the struggle is finally over.",
    "The air thickens. The silence is suffocating, pregnant with an unseen enormity. Something looks back at you from nowhere, and your body obeys.",
    "You glimpse a flicker--impossible angles, endless depth. Understanding blooms for a heartbeat too long, and in that moment, you are already gone.",
    "You hear your mother\'s voice, warm and familiar: \"It\'s okay, you can rest now.\" You almost smile as the cold slips over you.",
    "Someone calls your name--your partner, laughing, the way they used to before the world ended. The sound fills you, drowning out the silence. You follow the laughter until there\'s nothing left of you.",
    "A hand touches your shoulder, gentle, familiar. You turn and see the one you lost, smiling as though death never touched them. Their lips move: \"Come with me.\" And you do.",
    "The monster doesn\'t wear a face--it wears their face. The one you swore you\'d never forget. For one beautiful, unbearable moment, they are alive again, and you give yourself over to it.",
    "Your father\'s voice steadies you: \"You\'ve fought enough. Let me take it from here.\" The reassurance unravels your last threads of fear. You close your eyes, and he takes you away.",
    "You see your family waiting in the doorway of a home that no longer exists, arms open, smiling, whole. Every instinct screams, but love is louder."
}


-- Hack because I couldn't figure out how to properly use mon ids ¯\_(ツ)_/¯
local custom_monster_names = {
    mon_birdbox = "birdbox",
    mon_feral_cultist = "feral cultist"
}

local timers = {
    strangle = TimePoint.from_turn(0),
    death = TimePoint.from_turn(0)
}

-- Helper: Reset a named timer
local function reset_timer(name)
    timers[name] = TimePoint.from_turn(0)
end

-- Helper: Set a named timer to a specific TimePoint
local function set_timer(name, timepoint)
    timers[name] = timepoint
end

-- Helper: Is a named timer active and expired?
local function is_timer_expired(name)
    return timers[name] ~= TimePoint.from_turn(0) and timers[name] <= gapi.current_turn()
end

-- Helper: Is a named timer scheduled (set, but not yet expired)?
local function is_timer_scheduled(name)
    return timers[name] ~= TimePoint.from_turn(0) and timers[name] > gapi.current_turn()
end

-- Helper: Check player's line of sight to any enemy
local function check_enemy_los(name)
    local creatures = {}
    for _, creature in ipairs(you:get_visible_creatures(60)) do
        if creature:get_name() == name then
            creatures[#creatures + 1] = creature
        end
    end

    return creatures
end

-- Birdbox creature effect
local function commit()
    reset_timer("strangle")

    -- Monsters can technically be visible without being seen if they're super close
    local item_worn = you:all_items_with_flag(blind_flag, true)
    -- If wearing a blindfold, cancel any scheduled strangle and exit while informing player
    for _, item in ipairs(item_worn) do
        if you:is_wearing(item) then
            return
        end
    end

    if mod.sees_birdbox then
        mod.get_hallucination_message()
        set_timer("death", gapi.current_turn() + TimeDuration.from_seconds(5))
        marked_for_death = true
    end
end

function mod.get_hallucination_message()
    gapi.add_msg(MsgType.critical, messages[math.random(#messages)])
end

local function die()
    local methods = { "You strangle yourself!", "You repeatedly slam your head into the ground!", "You claw out your own eyes and bleed to death!" }
    for _, item in ipairs(you:all_items(true)) do
        if item:is_gun() and item:ammo_remaining() > 0 then
            item:ammo_consume(1, you:get_pos_ms())
            table.insert(methods, "You shoot yourself in the head with your " .. item:display_name(1) .. "!")
        end
        if item:is_melee(DamageType.DT_BASH) then
            table.insert(methods, "You bash yourself in the head with your " .. item:display_name(1) .. " repeatedly!")
        end
        if item:is_melee(DamageType.DT_STAB) then
            table.insert(methods, "You stab yourself in the stomach with your " .. item:display_name(1) .. "!")
        end
        if item:is_melee(DamageType.DT_CUT) then
            table.insert(methods, "You slice your neck with your " .. item:display_name(1) .. "!")
        end
    end
    gapi.add_msg(MsgType.bad, methods[math.random(#methods)])

    -- Handle actual player death here.
    you:set_all_parts_hp_cur(0)
    reset_timer("death")
    reset_timer("strangle")
    marked_for_death = false
end

-- Helper: Handles all timer updates for organization.
function mod.update_timers()
    -- If the timer has expired, trigger the death effect
    if is_timer_expired("death") then
        die()
        return
    end

    -- If the timer has expired, trigger the strangle effect
    if is_timer_expired("strangle") then
        commit()
        return
    end
end

local function handle_birdbox(creature, wearing_protection, using_item, timer_name, timer_duration, msg_type, msg_text, effect_time, hallucinate, mark_death)
    if wearing_protection then
        return true
    end

    if not is_timer_scheduled(timer_name) then
        if hallucinate then
            mod.get_hallucination_message()
        end
        if msg_text then
            gapi.add_msg(msg_type, msg_text)
        end
        if effect_time then
            you:add_effect(EffectTypeId.new("visuals"), effect_time)
        end
        set_timer(timer_name, gapi.current_turn() + timer_duration)
        if mark_death then
            marked_for_death = true
        end
    end

    return true
end

local function handle_birdbox_warning(creature, wearing_protection)
    if wearing_protection then
        return true
    end

    -- Near death experience effect
    you:add_effect(EffectTypeId.new("visuals"), TimeDuration.from_minutes(10))
    gapi.add_msg(MsgType.critical, "Your vision blurs! You can feel your retina being distorted!")
    return true
end

-- Handles the feral cultist's attempt to pull down the player's blindfold. Doesn't work on welding masks. (or modded stuff, may make it possible)
local function handle_feral_cultist_blindfold_grab(creature, cfg)
    if not cfg.using_item then
        return
    end
    -- RNG roll determines the outcome
    local roll = gapi.rng(1, 100)
    -- Actual attack
    if creature:sees(you) then
        if cfg.using_item:get_type() == ItypeId.new("blindfold") and roll < 50 then
            gapi.add_msg(MsgType.bad, "The feral cultist pulls down your " .. cfg.using_item:display_name(1) .. "!")
            cfg.using_item:convert(ItypeId.new("blindfold_raised"))
        else
            gapi.add_msg(MsgType.bad, "The feral cultist attempts to pull down your " .. cfg.using_item:display_name(1) .. " but fails!")
        end
    end
end

-- Generic handler for a list of creatures and a handler config
local function handle_creatures(creatures, handler_cfg)
    for _, creature in ipairs(creatures) do
        if handler_cfg.fn(creature, handler_cfg) then
            return true
        end
    end

    return false
end

-- Handler configs for each enemy effect type
local monster_handlers = {
    {
        -- Monster handlers: controls distance they act upon the player and what function they call when close
        creatures_fn = function() return you:get_visible_creatures(4) end,
        fn = function(creature, cfg)
            -- Birdbox, Level 1 distance: no time to cover face or move out of sight
            if creature:get_name() == custom_monster_names.mon_birdbox then
                handle_birdbox(
                    creature,
                    cfg.wearing_protection,
                    cfg.using_item,
                    "strangle",
                    TimeDuration.from_seconds(15),
                    MsgType.bad,
                    "You see something... wrong. It's painful attempting to comprehend it, but so beautiful.",
                    TimeDuration.from_minutes(30),
                    false, false
                )
            end

            -- Feral cultist: blindfold grab.
            if creature:get_name() == custom_monster_names.mon_feral_cultist then
                handle_feral_cultist_blindfold_grab(
                    creature,
                    cfg
                )
            end
        end
    },
    {
        creatures_fn = function() return you:get_visible_creatures(45) end,
        fn = function(creature, cfg)
            -- Birdbox, Level 2 distance: apply death countdown if they can't get to cover
            if creature:get_name() == custom_monster_names.mon_birdbox then
                return handle_birdbox(
                    creature,
                    cfg.wearing_protection,
                    cfg.using_item,
                    "strangle",
                    TimeDuration.from_seconds(15),
                    MsgType.bad,
                    "You see something... wrong. It's painful attempting to comprehend it, but so beautiful.",
                    TimeDuration.from_minutes(30),
                    false, false
                )
            end
        end
    },
    {
        creatures_fn = function() return you:get_visible_creatures(60) end,
        fn = function(creature, cfg)
            -- Birdbox, Level 3 distance: warn player they are getting too close
            if creature:get_name() == custom_monster_names.mon_birdbox then
                handle_birdbox_warning(
                    creature,
                    cfg.wearing_protection
                )
            end
        end
    }
}

-- Runs every turn
function mod.main()
    -- Do timer logic
    mod.update_timers()

    -- If player is dead or marked for death, exit early and don't handle monsters, only timers
    if you:get_hp() <= 0 or marked_for_death then
        return
    end

    -- Check birdbox sight (here so it runs every turn)
    local birdboxes_in_sight = check_enemy_los(custom_monster_names.mon_birdbox)
    if #birdboxes_in_sight > 0 then
        mod.sees_birdbox = true
    else
        mod.sees_birdbox = false
        if is_timer_scheduled("strangle") then
            reset_timer("strangle")
            gapi.add_msg(MsgType.good, "You avert your eyes just in time.")
        end
    end
    
    -- Grab values for monster handlers
    local using_item = nil
    local wearing_protection = false
    local item_worn = you:all_items_with_flag(blind_flag, true)

    for _, item in ipairs(item_worn) do
        if you:is_wearing(item) then
            using_item = item
            wearing_protection = true
        end
    end

    -- Pass shared state to each monster handler config
    for _, handler_cfg in ipairs(monster_handlers) do
        handler_cfg.wearing_protection = wearing_protection
        handler_cfg.using_item = using_item
        local creatures = handler_cfg.creatures_fn()
        if #creatures > 0 and handle_creatures(creatures, handler_cfg) then
            return
        end
    end
end
-- ============================================================================
-- ADVANCED FEATURES: Airstop HC + LC Breaker + Quick Retreat
-- ============================================================================

local bit = require("bit")
local vector = require('vector')
local ent = require('gamesense/entity')
local csgo_weapons = require('gamesense/csgo_weapons')

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================
local math_sin, math_cos, math_rad = math.sin, math.cos, math.rad

local function angle_to_forward(angle_x, angle_y)
    local sy = math_sin(math_rad(angle_y))
    local cy = math_cos(math_rad(angle_y))
    local sp = math_sin(math_rad(angle_x))
    local cp = math_cos(math_rad(angle_x))
    return cp * cy, cp * sy, -sp
end

local function entity_is_ready(ent)
    return globals.curtime() >= entity.get_prop(ent, 'm_flNextAttack')
end

local function entity_can_fire(ent)
    return globals.curtime() >= entity.get_prop(ent, 'm_flNextPrimaryAttack')
end

-- ============================================================================
-- REFERENCES
-- ============================================================================
local refs = {
    -- Airstop HC
    air_strafe = ui.reference('Misc', 'Movement', 'Air strafe'),
    weapon_type = ui.reference("RAGE", "Weapon type", "Weapon type"),
    hitchance = ui.reference("RAGE", "Aimbot", "Minimum hit chance"),
    
    -- LC Breaker
    dt_checkbox = ui.reference("RAGE", "aimbot", "Double tap"),
    dt_mode = select(2, ui.reference("RAGE", "aimbot", "Double tap")),
    dt_limit = ui.reference("RAGE", "aimbot", "Double tap fake lag limit"),
    
    -- Quick Retreat
    quickpeek_key = select(2, ui.reference("RAGE", "Other", "Quick peek assist")),
    fakelag_limit = ui.reference("AA", "Fake lag", "Limit")
}

-- ============================================================================
-- MASTER UI
-- ============================================================================
local master_enable = ui.new_checkbox("LUA", "B", "🎯 Enable Advanced Features")

-- ============================================================================
-- 1. AIRSTOP HC
-- ============================================================================
local air_label = ui.new_label("LUA", "B", "─────── Airstop HC (SSG08) ───────")
local air_enable = ui.new_checkbox("LUA", "B", "Enable Airstop HC")
local air_hotkey = ui.new_hotkey("LUA", "B", "Airstop Hotkey", false)
local air_distance = ui.new_slider("LUA", "B", "Max Distance", 1, 2000, 350, true, "u")
local air_hc_enable = ui.new_checkbox("LUA", "B", "Override Hitchance")
local air_hc_hotkey = ui.new_hotkey("LUA", "B", "HC Hotkey", false)
local air_hc_value = ui.new_slider("LUA", "B", "In-air HC %", 0, 100, 50, true, "%", 1, {[0] = "Off"})
local air_mix_enable = ui.new_checkbox("LUA", "B", "Mix Indicators")
local air_mix_color = ui.new_color_picker("LUA", "B", "Mix Color", 0, 255, 255, 255)

-- ============================================================================
-- 2. LC BREAKER
-- ============================================================================
local lc_label = ui.new_label("LUA", "B", "─────── LC Breaker ───────")
local lc_enable = ui.new_checkbox("LUA", "B", "Enable LC Breaker")
local lc_hotkey = ui.new_hotkey("LUA", "B", "LC Breaker Hotkey", false)
local lc_ticks = ui.new_slider("LUA", "B", "Self Peek Prediction Ticks", 1, 7, 3, true, "t")

-- ============================================================================
-- 3. QUICK RETREAT
-- ============================================================================
local qr_label = ui.new_label("LUA", "B", "─────── Quick Retreat ───────")
local qr_enable = ui.new_checkbox("LUA", "B", "Enable Quick Retreat")
local qr_req_qp = ui.new_checkbox("LUA", "B", "Only active with Quick Peek")
local qr_logic = ui.new_multiselect("LUA", "B", "Logic Options", 
    "Preserve last weapon", 
    "Require Fakelag"
)
local qr_delay = ui.new_slider("LUA", "B", "Unsheathe Delay", 0, 15, 7, true, "t")

-- ============================================================================
-- DATA STORAGE
-- ============================================================================

-- Airstop HC
local air_prediction_data = { flags = 0, velocity = vector() }
local air_prev_strafe = nil
local air_hc_original = nil
local air_hc_overridden = nil
local cl_sidespeed = cvar.cl_sidespeed
local FL_ONGROUND = bit.lshift(1, 0)

-- LC Breaker
local lc_last_toggle_time = 0
local lc_last_debug_time = 0
local lc_toggle_interval = 0
local lc_current_mode_index = 0
local lc_modes = {"Toggle", "On hotkey", "Off"}
local lc_local_player = nil
local lc_dt_charged = false

-- Quick Retreat
local qr_valid_weapons = {
    [40] = true, -- SSG08
    [9]  = true  -- AWP
}
local qr_vars = {
    active = false,
    switch_tick = 0,
    last_weapon_cmd = nil
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- === AIRSTOP HC HELPERS ===
local function air_restore_strafe()
    if air_prev_strafe ~= nil then
        ui.set(refs.air_strafe, air_prev_strafe)
        air_prev_strafe = nil
    end
end

local function air_restore_hc()
    if air_hc_original ~= nil then
        local prev_wpn_type = ui.get(refs.weapon_type)
        ui.set(refs.weapon_type, "SSG 08")
        ui.set(refs.hitchance, air_hc_original)
        ui.set(refs.weapon_type, prev_wpn_type)
        air_hc_original = nil
        air_hc_overridden = nil
    end
end

local function air_autostop(cmd, minimum)
    local lp = entity.get_local_player()
    if lp == nil then
        return air_restore_strafe()
    end

    local velocity = air_prediction_data.velocity
    local speed = velocity:length2d()

    if minimum ~= nil and speed < minimum then
        return air_restore_strafe()
    end

    local direction = vector(velocity:angles())
    local real_view = vector(client.camera_angles())

    direction.y = real_view.y - direction.y
    local forward = vector(angle_to_forward(direction.x, direction.y))

    local negative_side_move = -cl_sidespeed:get_float()
    local negative_direction = negative_side_move * forward

    if air_prev_strafe == nil then
        air_prev_strafe = ui.get(refs.air_strafe)
    end

    ui.set(refs.air_strafe, false)
    cmd.in_speed = 1
    cmd.forwardmove = negative_direction.x
    cmd.sidemove = negative_direction.y
end

local function is_air_active()
    return ui.get(master_enable) and ui.get(air_enable) and ui.get(air_hotkey)
end

local function is_air_hc_active()
    return ui.get(master_enable) and ui.get(air_enable) and ui.get(air_hc_enable) and ui.get(air_hc_hotkey)
end

-- === LC BREAKER HELPERS ===
local function toticks(t)
    return math.floor(t / globals.tickinterval())
end

local function lc_check_charge()
    if not lc_local_player then return end
    local m_nTickBase = entity.get_prop(lc_local_player, 'm_nTickBase')
    local client_latency = client.latency()
    local shift = math.floor(m_nTickBase - globals.tickcount() - 3 - toticks(client_latency) * .5 + .5 * (client_latency * 10))
    local wanted = -14 + (ui.get(refs.dt_limit) - 1) + 3
    lc_dt_charged = shift <= wanted
end

local function lc_is_self_peekable()
    local me = entity.get_local_player()
    if not me or not entity.is_alive(me) then return false end
    
    local enemies = entity.get_players(true)
    local my_velocity = { entity.get_prop(me, "m_vecVelocity") }
    local my_origin = { entity.get_prop(me, "m_vecOrigin") }
    local tick_interval = globals.tickinterval()
    local predicted_ticks = ui.get(lc_ticks)
    
    local predicted_my_pos = {
        my_origin[1] + my_velocity[1] * tick_interval * predicted_ticks,
        my_origin[2] + my_velocity[2] * tick_interval * predicted_ticks,
        my_origin[3] + my_velocity[3] * tick_interval * predicted_ticks
    }
    
    for i = 1, #enemies do
        local enemy = enemies[i]
        if entity.is_alive(enemy) then
            local enemy_velocity = { entity.get_prop(enemy, "m_vecVelocity") }
            local enemy_origin = { entity.get_prop(enemy, "m_vecOrigin") }
            
            local predicted_enemy_pos = {
                enemy_origin[1] + enemy_velocity[1] * tick_interval * predicted_ticks,
                enemy_origin[2] + enemy_velocity[2] * tick_interval * predicted_ticks,
                enemy_origin[3] + enemy_velocity[3] * tick_interval * predicted_ticks
            }
            
            for hitbox = 0, 18 do
                local my_hitbox_x, my_hitbox_y, my_hitbox_z = entity.hitbox_position(me, hitbox)
                if my_hitbox_x then
                    local predicted_my_hitbox = {
                        my_hitbox_x + my_velocity[1] * tick_interval * predicted_ticks,
                        my_hitbox_y + my_velocity[2] * tick_interval * predicted_ticks,
                        my_hitbox_z + my_velocity[3] * tick_interval * predicted_ticks
                    }
                    
                    local _, damage = client.trace_bullet(enemy, predicted_enemy_pos[1], predicted_enemy_pos[2], predicted_enemy_pos[3], predicted_my_hitbox[1], predicted_my_hitbox[2], predicted_my_hitbox[3])
                    
                    if damage >= 1 then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- === QUICK RETREAT HELPERS ===
local function qr_get_weapon_idx(ent)
    if not ent then return nil end
    local idx = entity.get_prop(ent, "m_iItemDefinitionIndex")
    if not idx then return nil end
    return bit.band(idx, 0xFFFF)
end

local function qr_is_option_active(opt_name)
    local opts = ui.get(qr_logic)
    for i=1, #opts do
        if opts[i] == opt_name then return true end
    end
    return false
end

local function qr_get_console_name(idx)
    if idx == 40 then return "weapon_ssg08" end
    if idx == 9 then return "weapon_awp" end
    return "slot1"
end

local function qr_restore_weapon()
    if qr_vars.last_weapon_cmd then
        client.exec("use " .. qr_vars.last_weapon_cmd)
    else
        client.exec("slot1")
    end
end

local function qr_on_reset()
    qr_vars.active = false
    qr_vars.switch_tick = 0
    qr_vars.last_weapon_cmd = nil
end

-- ============================================================================
-- AIRSTOP HC - LOGIC
-- ============================================================================

-- Predict Command
client.set_event_callback('predict_command', function(cmd)
    if not ui.get(master_enable) or not ui.get(air_enable) then return end
    
    local lp = entity.get_local_player()
    if lp == nil then return end

    local flags = entity.get_prop(lp, 'm_fFlags')
    local velocity = vector(entity.get_prop(lp, 'm_vecVelocity[0]'), entity.get_prop(lp, 'm_vecVelocity[1]'), entity.get_prop(lp, 'm_vecVelocity[2]'))
    air_prediction_data = { flags = flags, velocity = velocity }
end)

-- Setup Command (Autostop)
client.set_event_callback('setup_command', function(cmd)
    if not is_air_active() then
        air_restore_strafe()
        return
    end

    local lp = entity.get_local_player()
    local threat = client.current_threat()

    if lp == nil or threat == nil then
        return air_restore_strafe()
    end

    local wpn = entity.get_player_weapon(lp)
    if wpn == nil or not entity_is_ready(lp) or not entity_can_fire(wpn) then
        return air_restore_strafe()
    end

    local classname = entity.get_classname(wpn)
    if classname ~= 'CWeaponSSG08' then
        return air_restore_strafe()
    end

    local origin = vector(entity.get_origin(lp))
    local pos = vector(entity.get_origin(threat))
    local distance = pos:dist(origin)
    local max_distance = ui.get(air_distance)

    if distance > max_distance then
        return air_restore_strafe()
    end

    local animstate = ent(lp):get_anim_state()

    if animstate == nil or animstate.on_ground then
        return air_restore_strafe()
    end

    local is_scoped = entity.get_prop(lp, 'm_bIsScoped') ~= 0
    local data = csgo_weapons(wpn)
    local max_speed = is_scoped and data.max_player_speed_alt or data.max_player_speed
    max_speed = max_speed * 0.34

    local local_eye = vector(client.eye_position())
    local enemy_head = vector(ent(threat):hitbox_position(0))
    local _, damage = client.trace_bullet(lp, local_eye.x, local_eye.y, local_eye.z, enemy_head.x, enemy_head.y, enemy_head.z)

    if damage < 1 or cmd.buttons % 2 == 1 then
        return air_restore_strafe()
    end

    air_autostop(cmd, max_speed)
end)

-- ============================================================================
-- LC BREAKER - LOGIC
-- ============================================================================
client.set_event_callback("paint", function()
    -- Airstop HC Indicators + HC Override
    if ui.get(master_enable) and ui.get(air_enable) then
        local lp = entity.get_local_player()
        if lp ~= nil and entity.is_alive(lp) then
            local wpn_ent = entity.get_player_weapon(lp)
            local is_ssg08 = wpn_ent ~= nil and entity.get_classname(wpn_ent) == 'CWeaponSSG08'

            if is_ssg08 then
                local air_active = is_air_active()
                local hc_active = is_air_hc_active()
                local mix_active = ui.get(air_mix_enable) and air_active and hc_active

                if air_active and not mix_active then
                    renderer.indicator(255, 255, 255, 255, "Airstop")
                end

                if hc_active and not mix_active then
                    renderer.indicator(255, 255, 255, 255, "HC")
                end

                if mix_active then
                    local r, g, b, a = ui.get(air_mix_color)
                    renderer.indicator(r, g, b, a, "Airstop HC")
                end
            end
        end
        
        -- HC Override Logic
        if is_air_hc_active() then
            local me = entity.get_local_player()
            if me ~= nil and entity.is_alive(me) then
                local wpn_ent = entity.get_player_weapon(me)
                if wpn_ent ~= nil then
                    local classname = entity.get_classname(wpn_ent)
                    if classname == 'CWeaponSSG08' then
                        local flags = entity.get_prop(me, "m_fFlags")
                        local on_ground = bit.band(flags, FL_ONGROUND) == FL_ONGROUND

                        if not on_ground then
                            local value = ui.get(air_hc_value)
                            if value ~= 0 then
                                local prev_wpn_type = ui.get(refs.weapon_type)
                                ui.set(refs.weapon_type, "SSG 08")
                                local current_hc = ui.get(refs.hitchance)
                                if air_hc_overridden == nil or air_hc_overridden ~= value then
                                    air_hc_original = current_hc
                                    ui.set(refs.hitchance, value)
                                    air_hc_overridden = value
                                end
                                ui.set(refs.weapon_type, prev_wpn_type)
                            end
                        else
                            air_restore_hc()
                        end
                    else
                        air_restore_hc()
                    end
                else
                    air_restore_hc()
                end
            else
                air_restore_hc()
            end
        else
            air_restore_hc()
        end
    end

    -- LC Breaker Logic
    if ui.get(master_enable) and ui.get(lc_enable) then
        local now = globals.realtime()
        local activated = ui.get(lc_hotkey)
        
        lc_local_player = entity.get_local_player()
        if not lc_local_player or not entity.is_alive(lc_local_player) then return end
        
        lc_check_charge()
        
        ui.set(refs.dt_checkbox, true)
        
        local condition_met = lc_is_self_peekable() and lc_dt_charged
        
        if activated then
            renderer.indicator(220, 220, 220, 255, "LC Breaker")
        end

        if activated and condition_met then
            if now - lc_last_toggle_time >= lc_toggle_interval then
                lc_current_mode_index = (lc_current_mode_index + 1) % #lc_modes
                local current_mode = lc_modes[lc_current_mode_index + 1]
                ui.set(refs.dt_mode, current_mode)
                lc_last_toggle_time = now
            end
        else
            ui.set(refs.dt_mode, "Toggle")
            lc_current_mode_index = 0
            lc_last_toggle_time = now
        end
    end
end)

-- ============================================================================
-- QUICK RETREAT - LOGIC
-- ============================================================================

-- Aim Fire
client.set_event_callback("aim_fire", function(e)
    if not ui.get(master_enable) or not ui.get(qr_enable) then return end

    if ui.get(qr_req_qp) and not ui.get(refs.quickpeek_key) then
        return
    end

    local me = entity.get_local_player()
    if not me or not entity.is_alive(me) then return end

    local wpn_ent = entity.get_player_weapon(me)
    local wpn_idx = qr_get_weapon_idx(wpn_ent)
    
    if not wpn_idx or not qr_valid_weapons[wpn_idx] then
        return
    end

    if qr_is_option_active("Require Fakelag") then
        if ui.get(refs.fakelag_limit) <= 0 then return end 
    end

    if qr_is_option_active("Preserve last weapon") then
        qr_vars.last_weapon_cmd = qr_get_console_name(wpn_idx)
    else
        qr_vars.last_weapon_cmd = "slot1"
    end

    client.delay_call(0.05, function()
        if not entity.is_alive(me) then return end

        if ui.get(qr_req_qp) and not ui.get(refs.quickpeek_key) then
            return
        end

        client.exec("use weapon_knife")
        qr_vars.active = true
        qr_vars.switch_tick = globals.tickcount()
    end)
end)

-- Run Command
client.set_event_callback("run_command", function(c)
    if not qr_vars.active then return end

    local me = entity.get_local_player()
    if not me or not entity.is_alive(me) then 
        qr_vars.active = false 
        return 
    end

    if ui.get(qr_req_qp) and not ui.get(refs.quickpeek_key) then
        qr_restore_weapon()
        qr_vars.active = false
        return
    end

    local delay_ticks = ui.get(qr_delay)
    local current_tick = globals.tickcount()

    if current_tick >= qr_vars.switch_tick + delay_ticks then
        qr_restore_weapon()
        qr_vars.active = false
    end
end)

-- ============================================================================
-- UI VISIBILITY MANAGEMENT
-- ============================================================================
local function update_ui_visibility()
    local master = ui.get(master_enable)
    
    -- Airstop HC
    ui.set_visible(air_label, master)
    ui.set_visible(air_enable, master)
    local air_on = master and ui.get(air_enable)
    ui.set_visible(air_hotkey, air_on)
    ui.set_visible(air_distance, air_on)
    ui.set_visible(air_hc_enable, air_on)
    local air_hc_on = air_on and ui.get(air_hc_enable)
    ui.set_visible(air_hc_hotkey, air_hc_on)
    ui.set_visible(air_hc_value, air_hc_on)
    ui.set_visible(air_mix_enable, air_on)
    ui.set_visible(air_mix_color, air_on and ui.get(air_mix_enable))
    
    -- LC Breaker
    ui.set_visible(lc_label, master)
    ui.set_visible(lc_enable, master)
    local lc_on = master and ui.get(lc_enable)
    ui.set_visible(lc_hotkey, lc_on)
    ui.set_visible(lc_ticks, lc_on)
    
    -- Quick Retreat
    ui.set_visible(qr_label, master)
    ui.set_visible(qr_enable, master)
    local qr_on = master and ui.get(qr_enable)
    ui.set_visible(qr_req_qp, qr_on)
    ui.set_visible(qr_logic, qr_on)
    ui.set_visible(qr_delay, qr_on)
end

-- Callbacks
ui.set_callback(master_enable, update_ui_visibility)
ui.set_callback(air_enable, update_ui_visibility)
ui.set_callback(air_hc_enable, update_ui_visibility)
ui.set_callback(air_mix_enable, update_ui_visibility)
ui.set_callback(lc_enable, update_ui_visibility)
ui.set_callback(qr_enable, update_ui_visibility)

update_ui_visibility()

-- ============================================================================
-- CLEANUP EVENTS
-- ============================================================================
client.set_event_callback("round_start", qr_on_reset)

client.set_event_callback("player_death", function(e)
    if client.userid_to_entindex(e.userid) == entity.get_local_player() then 
        qr_on_reset()
    end
end)

client.set_event_callback("shutdown", function()
    air_restore_strafe()
    air_restore_hc()
end)

client.log("[✓] Advanced Features loaded!")
client.log("[✓] Airstop HC + LC Breaker + Quick Retreat")
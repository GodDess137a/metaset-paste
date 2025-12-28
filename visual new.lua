-- ============================================================================
-- MASTER TOGGLE + 5 NEW FEATURES (COMPLETE - NO BUGS)
-- ============================================================================

local ffi = require("ffi")
local bit = require("bit")

-- ============================================================================
-- FFI DEFINITIONS
-- ============================================================================
ffi.cdef[[
    typedef struct {
        char         __pad_0x0000[0x1cd];
        bool         hide_vm_scope;
    } ccsweaponinfo_t;
]]

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================
local function vtable_thunk(index, typestring)
    return function(instance)
        local t = ffi.typeof(typestring)
        local fnptr = ffi.cast(t, ffi.cast('void***', instance)[0][index])
        return function(...)
            return fnptr(instance, ...)
        end
    end
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

-- ============================================================================
-- REFERENCES & CVARS
-- ============================================================================
local refs = {
    minimum_damage = ui.reference("RAGE", "Aimbot", "Minimum damage"),
    damage_override = {ui.reference("RAGE", "Aimbot", "Minimum damage override")},
    aimbot_enabled = ui.reference("RAGE", "Aimbot", "Enabled")
}

-- ============================================================================
-- MASTER UI
-- ============================================================================
local master_enable = ui.new_checkbox("LUA", "A", "Enable Master Toggle")

-- ============================================================================
-- 1. VIEWMODEL IN SCOPE
-- ============================================================================
local vm_label = ui.new_label("LUA", "A", "─── Viewmodel in Scope ───")
local vm_enable = ui.new_checkbox("LUA", "A", "Show viewmodel in scope")

-- Viewmodel Setup
local vm_match = client.find_signature("client_panorama.dll", "\x8B\x35\xCC\xCC\xCC\xCC\xFF\x10\x0F\xB7\xC0")
if not vm_match then
    client.error_log("Viewmodel signature not found")
end

local vm_weaponsystem_raw = nil
local vm_get_weapon_info = nil

if vm_match then
    vm_weaponsystem_raw = ffi.cast("void****", ffi.cast("char*", vm_match) + 2)[0]
    vm_get_weapon_info = vtable_thunk(2, "ccsweaponinfo_t*(__thiscall*)(void*, unsigned int)")(vm_weaponsystem_raw)
end

-- ============================================================================
-- 2. AIM LOG
-- ============================================================================
local al_label = ui.new_label("LUA", "A", "─── Aim Log ───")
local al_enable = ui.new_checkbox("LUA", "A", "Enable Hit Logs")
local al_hit_color = ui.new_color_picker("LUA", "A", "Hit Color", 47, 202, 159, 255)
local al_miss_color = ui.new_color_picker("LUA", "A", "Miss Color", 255, 100, 100, 255)
local al_duration = ui.new_slider("LUA", "A", "Log Duration", 1, 10, 4, true, "s")
local al_console = ui.new_checkbox("LUA", "A", "Console Logs")

local al_hitgroup_names = {
    [0] = "generic", [1] = "head", [2] = "chest", [3] = "stomach",
    [4] = "left arm", [5] = "right arm", [6] = "left leg", [7] = "right leg",
    [8] = "neck", [9] = "?", [10] = "gear"
}

local al_logs = {}
local al_shot_data = {}
local al_max_logs = 5

-- ============================================================================
-- 3. FAKELAG INDICATOR
-- ============================================================================
local fl_label = ui.new_label("LUA", "A", "─── Fakelag Indicator ───")
local fl_enable = ui.new_checkbox("LUA", "A", "Enable Fakelag Indicator")

local fl_old_choke = 0
local fl_to_draw = {0, 0, 0, 0, 0}

-- ============================================================================
-- 4. DAMAGE MARKER + HITMARKER
-- ============================================================================
local dm_label = ui.new_label("LUA", "A", "─── Damage Marker ───")
local dm_enable = ui.new_checkbox("LUA", "A", "Enable Damage Marker")
local dm_duration = ui.new_slider("LUA", "A", "Display Duration", 1, 10, 4, true, "s")
local dm_speed = ui.new_slider("LUA", "A", "Speed", 1, 8, 2)
local dm_def_label = ui.new_label("LUA", "A", "Default color")
local dm_def_color = ui.new_color_picker("LUA", "A", "Default color", 255, 255, 255, 255)
local dm_head_label = ui.new_label("LUA", "A", "Head color")
local dm_head_color = ui.new_color_picker("LUA", "A", "Head color", 149, 184, 6, 255)
local dm_nade_label = ui.new_label("LUA", "A", "Nade color")
local dm_nade_color = ui.new_color_picker("LUA", "A", "Nade color", 255, 179, 38, 255)
local dm_knife_label = ui.new_label("LUA", "A", "Knife color")
local dm_knife_color = ui.new_color_picker("LUA", "A", "Knife color", 255, 255, 255, 255)
local dm_minus = ui.new_checkbox("LUA", "A", "Show (-)")

-- Hitmarker
local hm_enable = ui.new_checkbox("LUA", "A", "Enable Hitmarker")
local hm_color = ui.new_color_picker("LUA", "A", "Hitmarker color", 255, 225, 225, 255)

local dm_displays = {}
local dm_hitgroup_names = {"generic", "head", "chest", "stomach", "left arm", "right arm", "left leg", "right leg", "neck", "?", "gear"}

local hm_shot_data = {}
local hm_memory = {}

-- ============================================================================
-- 5. DAMAGE INDICATOR (CROSSHAIR)
-- ============================================================================
local di_label = ui.new_label("LUA", "A", "─── Damage Indicator ───")
local di_enable = ui.new_checkbox("LUA", "A", "Enable Crosshair Indicator")

local di_scr_w, di_scr_h = client.screen_size()
local di_cx, di_cy = di_scr_w / 2, di_scr_h / 2

local di_anim = {
    dmg = 0,
    alpha = 0,
    ovr_state = 0
}

-- ============================================================================
-- VIEWMODEL IN SCOPE - LOGIC
-- ============================================================================
local function vm_run_command()
    if not ui.get(master_enable) or not ui.get(vm_enable) then return end
    if not vm_get_weapon_info then return end
    
    local local_player = entity.get_local_player()
    if not local_player or not entity.is_alive(local_player) then return end

    local weapon = entity.get_player_weapon(local_player)
    if not weapon then return end

    local w_id = entity.get_prop(weapon, "m_iItemDefinitionIndex")
    if w_id == nil then return end

    local res = vm_get_weapon_info(w_id)
    if res then
        res.hide_vm_scope = false
    end
end

-- ============================================================================
-- AIM LOG - LOGIC (FIX: فرمت صحیح لاگ)
-- ============================================================================
local function al_get_hitgroup_name(hitgroup)
    return al_hitgroup_names[hitgroup] or "?"
end

local function al_add_log(text, is_hit)
    table.insert(al_logs, {
        text = text,
        time = globals.realtime(),
        is_hit = is_hit
    })
    
    if #al_logs > al_max_logs then
        table.remove(al_logs, 1)
    end
end

local function al_on_aim_fire(e)
    if not ui.get(master_enable) or not ui.get(al_enable) then return end
    al_shot_data[e.id] = { tick = e.tick }
end

local function al_on_aim_hit(e)
    if not ui.get(master_enable) or not ui.get(al_enable) then return end
    
    local target_name = entity.get_player_name(e.target)
    local hitgroup = al_get_hitgroup_name(e.hitgroup)
    local damage = e.damage
    local health_remaining = entity.get_prop(e.target, "m_iHealth") or 0
    
    if health_remaining < 0 then health_remaining = 0 end
    
    local backtrack_ticks = 0
    if al_shot_data[e.id] and al_shot_data[e.id].tick then
        backtrack_ticks = globals.tickcount() - al_shot_data[e.id].tick
    end
    
    local log_data = {
        type = "hit",
        parts = {
            {text = "Hit ", colored = false},
            {text = target_name, colored = true},
            {text = " in the ", colored = false},
            {text = hitgroup, colored = true},
            {text = " for ", colored = false},
            {text = tostring(damage), colored = true},
            {text = " damage (", colored = false},
            {text = tostring(health_remaining), colored = true},
            {text = " health remaining) [bt: ", colored = false},
            {text = tostring(backtrack_ticks), colored = true},
            {text = "]", colored = false}
        }
    }
    
    al_add_log(log_data, true)
    
    if ui.get(al_console) then
        print(string.format("Hit %s in the %s for %d damage (%d health remaining) [bt: %d]",
            target_name, hitgroup, damage, health_remaining, backtrack_ticks))
    end
    
    al_shot_data[e.id] = nil
end

local function al_on_aim_miss(e)
    if not ui.get(master_enable) or not ui.get(al_enable) then return end
    
    local target_name = entity.get_player_name(e.target)
    local hitgroup = al_get_hitgroup_name(e.hitgroup)
    local reason = e.reason
    local hitchance = math.floor(e.hit_chance + 0.5)
    
    local backtrack_ticks = 0
    if al_shot_data[e.id] and al_shot_data[e.id].tick then
        backtrack_ticks = globals.tickcount() - al_shot_data[e.id].tick
    end
    
    local log_data = {
        type = "miss",
        parts = {
            {text = "Missed ", colored = false},
            {text = target_name, colored = true},
            {text = " in the ", colored = false},
            {text = hitgroup, colored = true},
            {text = " due to ", colored = false},
            {text = reason, colored = true},
            {text = " (", colored = false},
            {text = tostring(hitchance) .. "%", colored = true},
            {text = " hitchance) [bt: ", colored = false},
            {text = tostring(backtrack_ticks), colored = true},
            {text = "]", colored = false}
        }
    }
    
    al_add_log(log_data, false)
    
    if ui.get(al_console) then
        print(string.format("Missed %s in the %s due to %s (%d%% hitchance) [bt: %d]",
            target_name, hitgroup, reason, hitchance, backtrack_ticks))
    end
    
    al_shot_data[e.id] = nil
end

local function al_on_paint()
    if not ui.get(master_enable) or not ui.get(al_enable) then return end
    
    local screen_x, screen_y = client.screen_size()
    local center_x = screen_x / 2
    local start_y = screen_y / 2 + 250
    
    local current_time = globals.realtime()
    local duration = ui.get(al_duration)
    
    local hit_r, hit_g, hit_b = ui.get(al_hit_color)
    local miss_r, miss_g, miss_b = ui.get(al_miss_color)
    
    local offset = 0
    for i = #al_logs, 1, -1 do
        local log = al_logs[i]
        local time_alive = current_time - log.time

        if time_alive > duration then
            table.remove(al_logs, i)
        else
            local alpha = 255
            if time_alive < 0.3 then
                alpha = (time_alive / 0.3) * 255
            elseif time_alive > (duration - 0.5) then
                alpha = ((duration - time_alive) / 0.5) * 255
            end
            
            local r, g, b
            if log.is_hit then
                r, g, b = hit_r, hit_g, hit_b
            else
                r, g, b = miss_r, miss_g, miss_b
            end
            
            local total_width = 0
            for _, part in ipairs(log.text.parts) do
                local w = renderer.measure_text(nil, part.text)
                total_width = total_width + w
            end
            
            local current_x = center_x - (total_width / 2)
            local y = start_y + offset
            
            for _, part in ipairs(log.text.parts) do
                local text_r, text_g, text_b
                if part.colored then
                    text_r, text_g, text_b = r, g, b
                else
                    text_r, text_g, text_b = 255, 255, 255
                end
                
                -- Shadow
                renderer.text(current_x + 1, y + 1, 0, 0, 0, alpha, "", 0, part.text)
                -- Main text
                renderer.text(current_x, y, text_r, text_g, text_b, alpha, "", 0, part.text)
                
                local w = renderer.measure_text(nil, part.text)
                current_x = current_x + w
            end
            
            offset = offset + 15
        end
    end
end

-- ============================================================================
-- FAKELAG INDICATOR - LOGIC
-- ============================================================================
local function fl_on_paint()
    if not ui.get(master_enable) or not ui.get(fl_enable) then return end
    
    renderer.indicator(220, 220, 220, 255, string.format('%i-%i-%i-%i-%i', 
        fl_to_draw[5], fl_to_draw[4], fl_to_draw[3], fl_to_draw[2], fl_to_draw[1]))
end

local function fl_setup_command(cmd)
    if not ui.get(master_enable) or not ui.get(fl_enable) then return end
    
    if cmd.chokedcommands < fl_old_choke then
        for i = 1, 4 do
            fl_to_draw[i] = fl_to_draw[i + 1]
        end
        fl_to_draw[5] = fl_old_choke
    end
    
    fl_old_choke = cmd.chokedcommands
end

-- ============================================================================
-- DAMAGE MARKER - LOGIC
-- ============================================================================
local function dm_hitbox_c(hitgroup)
    local hitbox_map = {
        [1] = 0,  -- head
        [2] = 5,  -- chest
        [3] = 3,  -- stomach
        [4] = 14, -- left arm
        [5] = 15, -- right arm
        [6] = 8,  -- left leg
        [7] = 9,  -- right leg
        [8] = 1   -- neck
    }
    return hitbox_map[hitgroup] or 0
end

local function dm_on_player_hurt(e)
    if not ui.get(master_enable) or not ui.get(dm_enable) then return end
    
    local userid, attacker, damage = e.userid, e.attacker, e.dmg_health
    if not userid or not attacker or not damage then return end
    if client.userid_to_entindex(attacker) ~= entity.get_local_player() then return end

    local player = client.userid_to_entindex(userid)
    local x, y, z = entity.get_prop(player, "m_vecOrigin")
    if not x or not y or not z then return end
    
    local voZ = entity.get_prop(player, "m_vecViewOffset[2]") or 0
    table.insert(dm_displays, {damage, globals.realtime(), x, y, z + voZ, e})
end

local function dm_on_paint(ctx)
    if not ui.get(master_enable) or not ui.get(dm_enable) then return end
    
    local dm_displays_new = {}
    local max_time_delta = ui.get(dm_duration) / 2
    local speed = ui.get(dm_speed) / 3
    local realtime = globals.realtime()
    local max_time = realtime - max_time_delta / 2
    
    for i = 1, #dm_displays do
        local display = dm_displays[i]
        local damage, time, x, y, z, e = display[1], display[2], display[3], display[4], display[5], display[6]
        local r, g, b, a = ui.get(dm_def_color)

        if time > max_time then
            local sx, sy = client.world_to_screen(ctx, x, y, z)
 
            if e.hitgroup == 1 then
                r, g, b = ui.get(dm_head_color)
            end

            local wpn = e.weapon
            if wpn == "hegrenade" or wpn == "inferno" then
                r, g, b = ui.get(dm_nade_color)
            elseif wpn == "knife" then
                r, g, b = ui.get(dm_knife_color)
            end
            
            local prefix = ui.get(dm_minus) and "-" or ""
            
            if (time - max_time) < 0.7 then
                a = (time - max_time) / 0.7 * 255
            end
 
            if sx and sy then
                client.draw_text(ctx, sx, sy, r, g, b, a, "cb", 0, prefix .. damage)
            end
            table.insert(dm_displays_new, {damage, time, x, y, z + 0.4 * speed, e})
        end
    end
 
    dm_displays = dm_displays_new
end

-- ============================================================================
-- HITMARKER - LOGIC
-- ============================================================================
local function hm_paint()
    if not ui.get(master_enable) or not ui.get(hm_enable) then return end
    
    local r, g, b = ui.get(hm_color)
    for tick, data in pairs(hm_shot_data) do
        if data.draw then
            if globals.curtime() >= data.time then
                data.alpha = data.alpha - 3
            end
            
            if data.alpha <= 0 then
                data.alpha = 0
                data.draw = false
            end

            local sx, sy = renderer.world_to_screen(data.x, data.y, data.z)
            if sx then
                renderer.line(sx + 1, sy + 1, sx + 4, sy + 4, r, g, b, data.alpha)
                renderer.line(sx - 1, sy + 1, sx - 4, sy + 4, r, g, b, data.alpha)
                renderer.line(sx + 1, sy - 1, sx + 4, sy - 4, r, g, b, data.alpha)
                renderer.line(sx - 1, sy - 1, sx - 4, sy - 4, r, g, b, data.alpha)
            end
        end
    end
end

local function hm_aim_fire(e)
    if not ui.get(master_enable) or not ui.get(hm_enable) then return end
    
    local t_x, t_y, t_z = entity.hitbox_position(e.target, dm_hitbox_c(e.hitgroup))
    local aboba, aboba1, aboba2 = client.eye_position()
    
    hm_memory[1] = {
        t_x = t_x, t_y = t_y, t_z = t_z,
        aboba = aboba, aboba1 = aboba1, aboba2 = aboba2
    }
end

local function hm_aim_hit(e)
    if not ui.get(master_enable) or not ui.get(hm_enable) then return end
    if not hm_memory[1] then return end
    
    local h_x, h_y, h_z
    if entity.is_alive(e.target) then
        h_x, h_y, h_z = entity.hitbox_position(e.target, dm_hitbox_c(e.hitgroup))
    else
        h_x, h_y, h_z = hm_memory[1].t_x, hm_memory[1].t_y, hm_memory[1].t_z
    end
    
    hm_shot_data[globals.tickcount()] = {
        time = globals.curtime() + 3,
        alpha = 255,
        draw = true,
        x = h_x, y = h_y, z = h_z,
        x1 = hm_memory[1].aboba,
        y1 = hm_memory[1].aboba1,
        z1 = hm_memory[1].aboba2
    }
end

-- ============================================================================
-- DAMAGE INDICATOR (CROSSHAIR) - LOGIC
-- ============================================================================
local function di_on_paint()
    if not ui.get(master_enable) or not ui.get(di_enable) then return end
    
    local lp = entity.get_local_player()
    if not lp or not entity.is_alive(lp) then
        di_anim.alpha = 0
        return
    end

    local is_overriding = false
    if refs.damage_override[2] then
        is_overriding = ui.get(refs.damage_override[2])
    end
    
    local min_damage = ui.get(refs.minimum_damage)
    local target_damage = min_damage

    if is_overriding and refs.damage_override[3] then
        target_damage = ui.get(refs.damage_override[3])
    end

    local ft = globals.frametime() * 20
    
    di_anim.dmg = lerp(di_anim.dmg, target_damage, ft * 0.5)
    di_anim.ovr_state = lerp(di_anim.ovr_state, is_overriding and 1 or 0, ft * 0.5)
    
    local should_show = not client.key_state(0x09)
    di_anim.alpha = lerp(di_anim.alpha, should_show and 1 or 0, ft * 0.5)

    if di_anim.alpha < 0.01 then return end
    
    local display_dmg = math.floor(di_anim.dmg + 0.5)
    local text_str
    
    if display_dmg == 0 then
        text_str = "A"
    elseif not is_overriding and display_dmg > 100 then
        text_str = "+" .. tostring(display_dmg)
    else
        text_str = tostring(display_dmg)
    end

    local default_alpha = 150
    local override_alpha = 255 
    
    local current_alpha_intensity = lerp(default_alpha, override_alpha, di_anim.ovr_state)
    local final_alpha = current_alpha_intensity * di_anim.alpha

    renderer.text(di_cx + 4, di_cy + 4, 255, 255, 255, final_alpha, "-", 0, text_str)
end

local function di_on_paint_ui()
    di_scr_w, di_scr_h = client.screen_size()
    di_cx, di_cy = di_scr_w / 2, di_scr_h / 2
end

-- ============================================================================
-- UI VISIBILITY
-- ============================================================================
local function update_ui_visibility()
    local master = ui.get(master_enable)
    
    -- 1. Viewmodel
    ui.set_visible(vm_label, master)
    ui.set_visible(vm_enable, master)
    
    -- 2. Aim Log
    ui.set_visible(al_label, master)
    ui.set_visible(al_enable, master)
    local al_on = master and ui.get(al_enable)
    ui.set_visible(al_hit_color, al_on)
    ui.set_visible(al_miss_color, al_on)
    ui.set_visible(al_duration, al_on)
    ui.set_visible(al_console, al_on)
    
    -- 3. Fakelag
    ui.set_visible(fl_label, master)
    ui.set_visible(fl_enable, master)
    
    -- 4. Damage Marker
    ui.set_visible(dm_label, master)
    ui.set_visible(dm_enable, master)
    local dm_on = master and ui.get(dm_enable)
    ui.set_visible(dm_duration, dm_on)
    ui.set_visible(dm_speed, dm_on)
    ui.set_visible(dm_def_label, dm_on)
    ui.set_visible(dm_def_color, dm_on)
    ui.set_visible(dm_head_label, dm_on)
    ui.set_visible(dm_head_color, dm_on)
    ui.set_visible(dm_nade_label, dm_on)
    ui.set_visible(dm_nade_color, dm_on)
    ui.set_visible(dm_knife_label, dm_on)
    ui.set_visible(dm_knife_color, dm_on)
    ui.set_visible(dm_minus, dm_on)
    ui.set_visible(hm_enable, master)
    ui.set_visible(hm_color, master and ui.get(hm_enable))
    
    -- 5. Damage Indicator
    ui.set_visible(di_label, master)
    ui.set_visible(di_enable, master)
end

ui.set_callback(master_enable, update_ui_visibility)
ui.set_callback(al_enable, update_ui_visibility)
ui.set_callback(dm_enable, update_ui_visibility)
ui.set_callback(hm_enable, update_ui_visibility)

update_ui_visibility()

-- ============================================================================
-- EVENTS
-- ============================================================================
client.set_event_callback("run_command", vm_run_command)
client.set_event_callback("aim_fire", al_on_aim_fire)
client.set_event_callback("aim_hit", al_on_aim_hit)
client.set_event_callback("aim_miss", al_on_aim_miss)
client.set_event_callback("setup_command", fl_setup_command)
client.set_event_callback("player_hurt", dm_on_player_hurt)
client.set_event_callback("aim_fire", hm_aim_fire)
client.set_event_callback("aim_hit", hm_aim_hit)

client.set_event_callback("paint", function(ctx)
    al_on_paint()
    fl_on_paint()
    hm_paint()
    di_on_paint()
    dm_on_paint(ctx)
end)

client.set_event_callback("paint_ui", di_on_paint_ui)

client.set_event_callback("round_start", function()
    hm_shot_data = {}
    hm_memory = {}
end)

client.log("[✓] Visual Features loaded successfully!")
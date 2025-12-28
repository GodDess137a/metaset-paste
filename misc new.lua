-- ============================================================================
-- MASTER TOGGLE + 8 FEATURES (COMPLETE FIX)
-- ============================================================================

local bit = require("bit")
local vector = require("vector")
local ffi = require("ffi")
local csgo_weapons = require('gamesense/csgo_weapons')
local chat_module = require("gamesense/chat")
local localize_module = require("gamesense/localize")

-- ============================================================================
-- FFI DEFINITIONS
-- ============================================================================
ffi.cdef[[
    typedef struct {
        char pad_0[0x14];
        int m_nFlags;
        char pad_1[0x10];
        void* m_pParent;
        int m_nValue;
        float m_fValue;
        char* m_pszString;
    } ConVar;

    struct animation_layer_t {
        char  pad_0000[20];
        uint32_t m_nOrder;
        uint32_t m_nSequence;
        float m_flPrevCycle;
        float m_flWeight;
        float m_flWeightDeltaRate;
        float m_flPlaybackRate;
        float m_flCycle;
        void *m_pOwner;
        char  pad_0038[4];
    };

    struct animstate_t1 {
        char pad[3];
        char m_bForceWeaponUpdate;
        char pad1[91];
        void* m_pBaseEntity;
        void* m_pActiveWeapon;
        void* m_pLastActiveWeapon;
        float m_flLastClientSideAnimationUpdateTime;
        int m_iLastClientSideAnimationUpdateFramecount;
        float m_flAnimUpdateDelta;
        float m_flEyeYaw;
        float m_flPitch;
        float m_flGoalFeetYaw;
        float m_flCurrentFeetYaw;
        float m_flCurrentTorsoYaw;
        float m_flUnknownVelocityLean;
        float m_flLeanAmount;
        char pad2[4];
        float m_flFeetCycle;
        float m_flFeetYawRate;
        char pad3[4];
        float m_fDuckAmount;
        float m_fLandingDuckAdditiveSomething;
        char pad4[4];
        float m_vOriginX;
        float m_vOriginY;
        float m_vOriginZ;
        float m_vLastOriginX;
        float m_vLastOriginY;
        float m_vLastOriginZ;
        float m_vVelocityX;
        float m_vVelocityY;
        char pad5[4];
        float m_flUnknownFloat1;
        char pad6[8];
        float m_flUnknownFloat2;
        float m_flUnknownFloat3;
        float m_flUnknown;
        float m_flSpeed2D;
        float m_flUpVelocity;
        float m_flSpeedNormalized;
        float m_flFeetSpeedForwardsOrSideWays;
        float m_flFeetSpeedUnknownForwardOrSideways;
        float m_flTimeSinceStartedMoving;
        float m_flTimeSinceStoppedMoving;
        bool m_bOnGround;
        bool m_bInHitGroundAnimation;
        char m_pad[2];
        float m_flJumpToFall;
        float m_flTimeSinceInAir;
        float m_flLastOriginZ;
        float m_flHeadHeightOrOffsetFromHittingGroundAnimation;
        float m_flStopToFullRunningFraction;
        char pad7[4];
        float m_flMagicFraction;
        char pad8[60];
        float m_flWorldForce;
        char pad9[462];
        float m_flMaxYaw;
    };
]]

-- ============================================================================
-- REFERENCES & CVARS
-- ============================================================================
local refs = {
    rage_enable = { ui.reference("RAGE", "Aimbot", "Enabled") },
    weapon_type = ui.reference("Rage", "Weapon type", "Weapon type"),
    doubletap = { ui.reference("RAGE", "Aimbot", "Double tap") },
    fakeduck = ui.reference("RAGE", "Other", "Duck peek assist"),
    onshot_aa = { ui.reference("AA", "Other", "On shot anti-aim") },
    custom_events = ui.reference("MISC", "Settings", "Allow custom game events"),
    max_unlag = ui.reference("MISC", "Settings", "sv_maxunlag2"),
    max_ticks = ui.reference("MISC", "Settings", "sv_maxusrcmdprocessticks2"),
    clock_corr = ui.reference("MISC", "Settings", "sv_clockcorrection_msecs2"),
    hold_aim = ui.reference("MISC", "Settings", "sv_maxusrcmdprocessticks_holdaim")
}

local sv_maxunlag = cvar.sv_maxunlag
local cvar_snd_setmixer = cvar.snd_setmixer
local cvar_con_filter_enable = cvar.con_filter_enable
local cvar_con_filter_text = cvar.con_filter_text

-- ============================================================================
-- MASTER UI
-- ============================================================================
local master_enable = ui.new_checkbox("LUA", "A", "Enable Master Toggle")

-- ============================================================================
-- 1. CUSTOM WEAPON SOUNDS
-- ============================================================================
local cws_label = ui.new_label("LUA", "A", "─── Custom Weapon Sounds ───")
local cws_enable = ui.new_checkbox("LUA", "A", "Enable Custom Sounds")

local cws_data = {
    previous_ammo = 0,
    previous_fire = 0,
    was_enabled = false
}

local fsIface = ffi.cast(ffi.typeof("void***"), client.create_interface("filesystem_stdio.dll", "VFileSystem017"))
local fsFind = ffi.cast("const char*(__thiscall*)(void*, const char*, int*)", fsIface[0][32])

local function fileExists(filePath)
    local out = ffi.new("int[1]")
    return fsFind(fsIface, filePath, out) ~= ffi.NULL
end

local function restore_weapon_sounds()
    cvar_snd_setmixer:invoke_callback("Weapons1", "vol", "0.7")
    cvar_snd_setmixer:invoke_callback("FoleyWeapons", "vol", "0.7")
    cvar_snd_setmixer:invoke_callback("AllWeapons", "vol", "1.0")
    cvar_snd_setmixer:invoke_callback("DistWeapons", "vol", "0.7")
    cvar_snd_setmixer:invoke_callback("WeaponReload", "vol", "0.7")
end

local function play_custom_sound()
    local is_enabled = ui.get(cws_enable)
    
    if not is_enabled and cws_data.was_enabled then
        restore_weapon_sounds()
        cws_data.was_enabled = false
        return
    end
    
    if not is_enabled then return end
    
    cws_data.was_enabled = true

    local lp = entity.get_local_player()
    if not lp then return end

    local weapon = entity.get_player_weapon(lp)
    if not weapon or not csgo_weapons(weapon).is_gun then return end

    local weaponName = csgo_weapons(weapon).name:gsub("%s+", "")
    local path = "sound/customweaponsounds/" .. weaponName .. ".wav"

    if not fileExists(path) then
        client.error_log("Custom sound not found: " .. path)
        return
    end

    cvar_snd_setmixer:invoke_callback("Weapons1", "vol", "0")
    client.exec("play customweaponsounds/" .. weaponName)
end

local function enable_sv_cheats()
    if not ui.get(cws_enable) then return end
    
    local ICvar = client.create_interface("vstdlib.dll", "VEngineCvar007")
    local findVar = ffi.cast("void*(__thiscall*)(void*, const char*)", ffi.cast("void***", ICvar)[0][15])
    local sv_cheats = ffi.cast("ConVar*", findVar(ICvar, "sv_cheats"))
    
    sv_cheats.m_nFlags = bit.band(sv_cheats.m_nFlags, bit.bnot(0x8000))
    sv_cheats.m_nValue = 1
    sv_cheats.m_fValue = 1.0
end

-- ============================================================================
-- 2. ENEMY TEAM CHAT REVEALER
-- ============================================================================
local etc_label = ui.new_label("LUA", "A", "─── Enemy Team Chat ───")
local etc_enable = ui.new_checkbox("LUA", "A", "Reveal enemy teamchat")

local game_state_api = panorama.open().GameStateAPI
local last_location_time = {}

local function on_player_say(event)
    if not ui.get(master_enable) or not ui.get(etc_enable) then return end
    
    local entity_index = client.userid_to_entindex(event.userid)
    
    if not entity_index or not entity.is_enemy(entity_index) then return end
    if game_state_api.IsSelectedPlayerMuted(game_state_api.GetPlayerXuidStringFromEntIndex(entity_index)) then return end
    if cvar.cl_mute_enemy_team and cvar.cl_mute_enemy_team:get_int() == 1 then return end
    if cvar.cl_mute_all_but_friends_and_party and cvar.cl_mute_all_but_friends_and_party:get_int() == 1 then return end

    client.delay_call(0.2, function()
        if last_location_time[entity_index] ~= nil and math.abs(globals.realtime() - last_location_time[entity_index]) < 0.4 then return end

        local location_name = entity.get_prop(entity_index, "m_szLastPlaceName")
        local team_letter = entity.get_prop(entity.get_player_resource(), "m_iTeam", entity_index) == 2 and "T" or "CT"
        local is_alive = entity.is_alive(entity_index)
        local status = is_alive and "Loc" or "Dead"
        local location_string = location_name ~= "" and location_name or "UI_Unknown"

        chat_module.print_player(entity_index, localize_module(("Cstrike_Chat_%s_%s"):format(team_letter, status), {
            s1 = entity.get_player_name(entity_index),
            s2 = event.text,
            s3 = localize_module(location_string)
        }))
    end)
end

local function on_player_location_update(event)
    if not ui.get(master_enable) or not ui.get(etc_enable) then return end
    
    local entity_index = event.entity
    if not entity_index or not entity.is_enemy(entity_index) then return end
    last_location_time[entity_index] = globals.realtime()
end

-- ============================================================================
-- 3. MAGNET MELEE
-- ============================================================================
local mm_label = ui.new_label("LUA", "A", "─── Magnet Melee ───")
local mm_enable = ui.new_checkbox("LUA", "A", "Enable Melee Magnet")
local mm_options = ui.new_multiselect("LUA", "A", "Melee options", "Zeus magnet", "Knife magnet", "Forwards AA on knife")

local zeus_id = 31

local function find_closest_enemy(eye_pos)
    local min_dist = 40000
    local closest_enemy, closest_pos
    local enemies = entity.get_players(true)

    for i = 1, #enemies do
        local enemy = enemies[i]
        local enemy_pos = vector(entity.get_origin(enemy))
        local dist_sq = enemy_pos:distsqr(eye_pos)

        if dist_sq < min_dist and not plist.get(enemy, "Add to whitelist") then
            min_dist = dist_sq
            closest_enemy = enemy
            closest_pos = enemy_pos
        end
    end

    return closest_enemy, closest_pos
end

local function on_mm_setup_command(cmd)
    if not ui.get(master_enable) or not ui.get(mm_enable) then return end
    
    local local_player = entity.get_local_player()
    local local_weapon = entity.get_player_weapon(local_player)

    if local_weapon then
        local eye_pos = vector(client.eye_position())
        local closest_enemy, closest_pos = find_closest_enemy(eye_pos)

        if closest_enemy then
            local fraction, hit_entity = client.trace_line(local_player, eye_pos.x, eye_pos.y, eye_pos.z, closest_pos.x, closest_pos.y, closest_pos.z)

            if fraction >= 1 or hit_entity == closest_enemy then
                local pitch, yaw = eye_pos:to(closest_pos):angles()
                
                local selected = ui.get(mm_options)

                if entity.get_classname(local_weapon) == "CKnife" then
                    for i=1, #selected do
                        if selected[i] == "Knife magnet" then
                            if bit.band(entity.get_prop(local_player, "m_fFlags"), 1) ~= 1 then
                                cmd.move_yaw = yaw
                                cmd.forwardmove = 450
                            end
                            break
                        end
                    end
                elseif entity.get_prop(local_weapon, "m_iItemDefinitionIndex") == zeus_id then
                    for i=1, #selected do
                        if selected[i] == "Zeus magnet" then
                            cmd.move_yaw = yaw
                            cmd.forwardmove = 450
                            break
                        end
                    end
                end

                local enemy_weapon = entity.get_player_weapon(closest_enemy)

                if enemy_weapon and entity.get_classname(enemy_weapon) == "CKnife" then
                    for i=1, #selected do
                        if selected[i] == "Forwards AA on knife" then
                            cmd.yaw = yaw
                            cmd.pitch = 89
                            break
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- 4. FAST RECHARGE
-- ============================================================================
local fr_label = ui.new_label("LUA", "A", "─── Fast Recharge ───")
local fr_enable = ui.new_checkbox("LUA", "A", "Enable Fast Recharge")

local recharge_state = {
    last_tick = globals.tickcount(),
    interval = 14
}

local function handle_fast_recharge(cmd)
    if not ui.get(master_enable) or not ui.get(fr_enable) then return end

    local lp = entity.get_local_player()
    if not lp or not entity.is_alive(lp) then return end

    local dt_on = ui.get(refs.doubletap[1]) and ui.get(refs.doubletap[2]) and not ui.get(refs.fakeduck)
    local hs_on = ui.get(refs.onshot_aa[1]) and ui.get(refs.onshot_aa[2]) and not ui.get(refs.fakeduck)

    local weapon = entity.get_player_weapon(lp)
    if not weapon then
        ui.set(refs.rage_enable[2], "Always on")
        return
    end

    recharge_state.interval = csgo_weapons(weapon).is_revolver and 17 or 14

    if dt_on or hs_on then
        if globals.tickcount() >= recharge_state.last_tick + recharge_state.interval then
            ui.set(refs.rage_enable[2], "Always on")
        else
            ui.set(refs.rage_enable[2], "On hotkey")
        end
    else
        recharge_state.last_tick = globals.tickcount()
        ui.set(refs.rage_enable[2], "Always on")
    end
end

-- ============================================================================
-- 5. PING SPIKE
-- ============================================================================
local ps_label = ui.new_label("LUA", "A", "─── Ping Spike ───")
local ps_mode = ui.new_combobox("LUA", "A", "Ping spike mode", "Off", "Low", "Medium", "High", "Customizable")
local ps_custom = ui.new_slider("LUA", "A", "Custom ping value", 0, 1000, 200, true, "ms")

local ps_ptr = nil
local ps_initialized = false

local function ps_init()
    if ps_initialized then return true end
    
    local proxy_addr = client.find_signature("client.dll", string.char(0x51, 0xC3))
    if not proxy_addr then return false end
    
    local get_mod_add_patern = client.find_signature("client.dll", string.char(0xC6, 0x06, 0x00, 0xFF, 0x15, 0xCC, 0xCC, 0xCC, 0xCC, 0x50))
    if not get_mod_add_patern then return false end
    
    local get_mod_add_addr = ffi.cast("void***", ffi.cast("char*", get_mod_add_patern) + 5)[0][0]
    local get_mod_add_proxy = ffi.cast("uintptr_t (__thiscall*)(void*, const char*)", proxy_addr)
    
    local get_proc_add_patern = client.find_signature("client.dll", string.char(0x50, 0xFF, 0x15, 0xCC, 0xCC, 0xCC, 0xCC, 0x85, 0xC0, 0x0F, 0x84, 0xCC, 0xCC, 0xCC, 0xCC, 0x6A, 0x00))
    if not get_proc_add_patern then return false end
    
    local get_proc_add_addr = ffi.cast("void***", ffi.cast("char*", get_proc_add_patern) + 3)[0][0]
    local get_proc_add_proxy = ffi.cast("uintptr_t (__thiscall*)(void*, uintptr_t, const char*)", proxy_addr)
    
    local kernel32_addr = get_mod_add_proxy(get_mod_add_addr, "kernel32.dll")
    if not kernel32_addr then return false end
    
    local VirtualProtect_addr = get_proc_add_proxy(get_proc_add_addr, kernel32_addr, "VirtualProtect")
    if not VirtualProtect_addr then return false end
    
    local VirtualProtect_proxy = ffi.cast("bool (__thiscall*)(uintptr_t, void*, uintptr_t, uintptr_t, uintptr_t*)", proxy_addr)
    local addr = 0x43467EDC
    ps_ptr = ffi.cast("uint32_t*", addr)
    
    local old_protect = ffi.new("uintptr_t[1]")
    ps_initialized = VirtualProtect_proxy(VirtualProtect_addr, ffi.cast("void*", addr), 1, 0x40, old_protect)
    return ps_initialized
end

ps_init()

local ps_reset = ui.new_button("LUA", "A", "Reset ping spike", function()
    if ps_ptr and ps_initialized then
        ps_ptr[0] = 5
    end
    sv_maxunlag:set_float(0.005)
    pcall(function() ui.set(refs.max_unlag, 5) end)
    ui.set(ps_mode, "Off")
    client.log("Reset to 5ms")
end)

local ping_presets = {
    ["Off"] = 5,
    ["Low"] = 60,
    ["Medium"] = 120,
    ["High"] = 200
}

local function apply_ping(value)
    if value < 200 then
        pcall(function() ui.set(refs.max_unlag, 200) end)
        sv_maxunlag:set_float(0.200)
    else 
        pcall(function() ui.set(refs.max_unlag, value) end)
        sv_maxunlag:set_float(value / 1000)
    end
    
    if ps_ptr and ps_initialized then
        ps_ptr[0] = value
    end
end

local function update_ping_settings()
    if not ui.get(master_enable) then return end
    
    local mode = ui.get(ps_mode)
    local is_custom = mode == "Customizable"
    
    if mode == "Off" then
        apply_ping(5)
    elseif is_custom then
        apply_ping(ui.get(ps_custom))
    else
        local preset_value = ping_presets[mode]
        if preset_value then apply_ping(preset_value) end
    end
end

-- ============================================================================
-- 6. UNHIDE CVARS
-- ============================================================================
local uc_label = ui.new_label("LUA", "A", "─── Unhide Cvars ───")
local uc_enable = ui.new_checkbox("LUA", "A", "Unhide Cvars")

-- ذخیره وضعیت اولیه
local uc_original_visibility = {
    max_unlag = false,
    max_ticks = false,
    clock_corr = false,
    hold_aim = false
}

local function update_unhide_visibility()
    if not ui.get(master_enable) then return end
    
    local show = ui.get(uc_enable)

    if refs.custom_events then
        ui.set_visible(refs.custom_events, true)
        if show then ui.set(refs.custom_events, true) end
    end

    if refs.max_unlag then ui.set_visible(refs.max_unlag, show) end
    if refs.max_ticks then ui.set_visible(refs.max_ticks, show) end
    if refs.clock_corr then ui.set_visible(refs.clock_corr, show) end
    if refs.hold_aim then ui.set_visible(refs.hold_aim, show) end
end

-- ============================================================================
-- 7. WORLD SOUND (FIX COMPLETE: Weapons و Reload هیچ تداخلی ندارن)
-- ============================================================================
local ws_label = ui.new_label("LUA", "A", "─── World Sound ───")
local ws_enable = ui.new_checkbox("LUA", "A", "Sound volume modifiers")

local mixers_list = {
    "Footsteps",
    "Weapons",
    "Reload Sounds",
    "Bomb Sounds",
    "Ambient & Effects",
    "Music & Radio",
}

-- ✅ FIX: Weapons و Reload Sounds کاملاً جدا شدن
local mixers_names = {
    ["Footsteps"] = { 
        ["GlobalFootsteps"] = 1.00, 
        ["PlayerFootsteps"] = 0.13 
    },
    ["Weapons"] = { 
        ["Weapons1"] = 0.70,
        ["AllWeapons"] = 1.00, 
        ["DistWeapons"] = 0.70
        -- ✅ FoleyWeapons حذف شد
    },
    ["Reload Sounds"] = { 
        ["WeaponReload"] = 0.70,
        ["FoleyWeapons"] = 0.70  -- ✅ فقط Reload کنترل میکنه
    },
    ["Bomb Sounds"] = { 
        ["Bomb"] = 1.00, 
        ["C4"] = 1.00, 
        ["C4Foley"] = 1.00 
    },
    ["Ambient & Effects"] = {
        ["Ambient"] = 0.25, 
        ["Explosions"] = 1.00, 
        ["ExplosionsDecay"] = 1.60, 
        ["Grenades"] = 1.00,
        ["BulletImpacts"] = 1.00, 
        ["BulletImpactsDistant"] = 0.70, 
        ["Player"] = 1.00, 
        ["PlayerDeath"] = 1.00,
        ["PlayerPain"] = 1.00, 
        ["Death"] = 1.00, 
        ["UI"] = 0.50, 
        ["MainUI"] = 0.50, 
        ["Physics"] = 0.80,
        ["PhysicsImpacts"] = 0.60, 
        ["Damage"] = 1.00
    },
    ["Music & Radio"] = {
        ["SelectedMusic"] = 0.60, 
        ["BuyMusic"] = 0.80, 
        ["Music"] = 1.00, 
        ["DuckingMusix"] = 0.80,
        ["Radio"] = 0.20, 
        ["Bot"] = 0.20, 
        ["Dialog"] = 0.1, 
        ["Commander"] = 0.30, 
        ["Survival"] = 1.00,
        ["Voice"] = 1.00, 
        ["VoiceComms"] = 1.00
    }
}

-- ذخیره مقادیر default برای restore
local ws_default_values = {
    ["GlobalFootsteps"] = 1.00,
    ["PlayerFootsteps"] = 0.13,
    ["Weapons1"] = 0.70,
    ["AllWeapons"] = 1.00,
    ["DistWeapons"] = 0.70,
    ["WeaponReload"] = 0.70,
    ["FoleyWeapons"] = 0.70,
    ["Bomb"] = 1.00,
    ["C4"] = 1.00,
    ["C4Foley"] = 1.00,
    ["Ambient"] = 0.25,
    ["Explosions"] = 1.00,
    ["ExplosionsDecay"] = 1.60,
    ["Grenades"] = 1.00,
    ["BulletImpacts"] = 1.00,
    ["BulletImpactsDistant"] = 0.70,
    ["Player"] = 1.00,
    ["PlayerDeath"] = 1.00,
    ["PlayerPain"] = 1.00,
    ["Death"] = 1.00,
    ["UI"] = 0.50,
    ["MainUI"] = 0.50,
    ["Physics"] = 0.80,
    ["PhysicsImpacts"] = 0.60,
    ["Damage"] = 1.00,
    ["SelectedMusic"] = 0.60,
    ["BuyMusic"] = 0.80,
    ["Music"] = 1.00,
    ["DuckingMusix"] = 0.80,
    ["Radio"] = 0.20,
    ["Bot"] = 0.20,
    ["Dialog"] = 0.1,
    ["Commander"] = 0.30,
    ["Survival"] = 1.00,
    ["Voice"] = 1.00,
    ["VoiceComms"] = 1.00
}

local ws_modifier = {}

for i=1, #mixers_list do
    local mixer = mixers_list[i]
    ws_modifier[mixer] = ui.new_slider("LUA", "A", mixer .. " volume", 0, 1000, 100, true, "%", 1, {[0] = "Muted"})
end

local function disable_console_output(block, ...)
    local con_filter_enable_prev, con_filter_text_prev = cvar_con_filter_enable:get_int(), cvar_con_filter_text:get_string()
    cvar_con_filter_enable:set_raw_int(1)
    cvar_con_filter_text:set_string("___")

    xpcall(block, client.error_log, ...)

    cvar_con_filter_enable:set_raw_int(con_filter_enable_prev)
    cvar_con_filter_text:set_string(con_filter_text_prev)
end

local function update_mixers(mixer_name)
    if not ui.get(master_enable) or not ui.get(ws_enable) then return end
    
    local mixers = mixer_name ~= nil and {mixer_name} or mixers_list

    disable_console_output(function()
        for i=1, #mixers do
            local mixer = mixers[i]
            local mixer_data = mixers_names[mixer]
            local current_value = ui.get(ws_modifier[mixer])
            local modifier = current_value * 0.01

            for mixer_current_name, mixer_default_volume in pairs(mixer_data) do
                cvar_snd_setmixer:invoke_callback(mixer_current_name, "vol", tostring(mixer_default_volume * modifier))
            end
        end
    end)
end

-- ✅ تابع restore کردن همه صداها به حالت default
local function restore_all_sounds()
    disable_console_output(function()
        for mixer_name, default_vol in pairs(ws_default_values) do
            cvar_snd_setmixer:invoke_callback(mixer_name, "vol", tostring(default_vol))
        end
    end)
end

for i=1, #mixers_list do
    local mixer = mixers_list[i]
    ui.set_callback(ws_modifier[mixer], function()
        update_mixers(mixer)
    end)
end

-- ============================================================================
-- 8. CUSTOM ANIMATIONS
-- ============================================================================
local ca_label = ui.new_label("LUA", "A", "─── Custom Animations ───")
local ca_enable = ui.new_checkbox("LUA", "A", "Enable Animations")
local ca_options = ui.new_multiselect("LUA", "A", "Animation types", {
    "pitch on land", "fallen legs", "moonwalk", "air walk",
    "blind", "fake walk", "earthquake", "slide", "fake duck", "smoothing"
})

local entity_list_ptr = ffi.typeof('void***')
local i_client_entity_list = client.create_interface('client.dll', 'VClientEntityList003')
local raw_ientitylist = ffi.cast(entity_list_ptr, i_client_entity_list)
local get_client_entity = ffi.cast('void*(__thiscall*)(void*, int)', raw_ientitylist[0][3])

local ca_globals = {
    in_speed = false,
    landing = false
}

local function contains(table, element)
    for i = 1, #table do
        if table[i] == element then return true end
    end
    return false
end

local function get_animation_layer(entity_ptr, layer_index)
    layer_index = layer_index or 1
    entity_ptr = ffi.cast(ffi.typeof('void***'), entity_ptr)
    return ffi.cast('struct animation_layer_t**', ffi.cast('char*', entity_ptr) + 0x2990)[0][layer_index]
end

local function apply_custom_animations(player_entity)
    if not ui.get(master_enable) or not ui.get(ca_enable) then return end
    
    local raw_player = get_client_entity(raw_ientitylist, player_entity)
    local player_ptr = ffi.cast(ffi.typeof('void***'), raw_player)
    local animstate_ptr = ffi.cast("char*", player_ptr) + 0x9960
    local animstate = ffi.cast("struct animstate_t1**", animstate_ptr)[0]
    
    if raw_player == nil or animstate == nil then return end
    
    local selected_anims = ui.get(ca_options)
    
    if contains(selected_anims, "pitch on land") then
        if animstate.m_bInHitGroundAnimation and animstate.m_flHeadHeightOrOffsetFromHittingGroundAnimation > 0.101 and 
           animstate.m_bOnGround and not client.key_state(0x20) then
            entity.set_prop(player_entity, 'm_flPoseParameter', 0.5, 12)
            ca_globals.landing = true
        else
            ca_globals.landing = false
        end
    end
    
    if contains(selected_anims, "fallen legs") then entity.set_prop(player_entity, "m_flPoseParameter", 1, 6) end
    if contains(selected_anims, "moonwalk") then entity.set_prop(player_entity, 'm_flPoseParameter', 0, 7) end
    
    if contains(selected_anims, "air walk") then
        if vector(entity.get_prop(player_entity, 'm_vecVelocity')):length2d() > 1.5 then
            local ANIMATION_LAYER_MOVEMENT_MOVE = get_animation_layer(raw_player, 6)
            ANIMATION_LAYER_MOVEMENT_MOVE.m_flWeight = 1
        end
    end
    
    if contains(selected_anims, "blind") then
        local ANIMATION_LAYER_FLASHED = get_animation_layer(raw_player, 9)
        ANIMATION_LAYER_FLASHED.m_nSequence = 224
        ANIMATION_LAYER_FLASHED.m_flWeight = 1
    end
    
    if contains(selected_anims, "fake walk") and ca_globals.in_speed then
        local ANIMATION_LAYER_LEAN = get_animation_layer(raw_player, 12)
        ANIMATION_LAYER_LEAN.m_flWeight = 0
        local ANIMATION_LAYER_MOVEMENT_MOVE = get_animation_layer(raw_player, 6)
        ANIMATION_LAYER_MOVEMENT_MOVE.m_flWeight = 0
    end
    
    if contains(selected_anims, "earthquake") then
        local ANIMATION_LAYER_LEAN = get_animation_layer(raw_player, 12)
        ANIMATION_LAYER_LEAN.m_flWeight = client.random_float(0, 1)
    end
    
    if contains(selected_anims, "slide") then entity.set_prop(player_entity, "m_flPoseParameter", 1, 0) end
    if contains(selected_anims, "fake duck") then entity.set_prop(player_entity, "m_flPoseParameter", 1, 1) end
    if contains(selected_anims, "smoothing") then entity.set_prop(player_entity, "m_flPoseParameter", 0, 2) end
end

-- ============================================================================
-- ✅ تابع RESET همه چیز به حالت عادی
-- ============================================================================
local function reset_everything_to_default()
    -- 1. Custom Weapon Sounds
    restore_weapon_sounds()
    cws_data.was_enabled = false
    
    -- 2. Ping Spike
    if ps_ptr and ps_initialized then ps_ptr[0] = 5 end
    sv_maxunlag:set_float(0.005)
    pcall(function() ui.set(refs.max_unlag, 5) end)
    
    -- 3. Unhide Cvars (مخفی کردن دوباره)
    if refs.max_unlag then ui.set_visible(refs.max_unlag, false) end
    if refs.max_ticks then ui.set_visible(refs.max_ticks, false) end
    if refs.clock_corr then ui.set_visible(refs.clock_corr, false) end
    if refs.hold_aim then ui.set_visible(refs.hold_aim, false) end
    
    -- 4. World Sound (restore default)
    restore_all_sounds()
    
    client.log("All settings restored to default")
end

-- ============================================================================
-- UI VISIBILITY
-- ============================================================================
local function update_ui_visibility()
    local master = ui.get(master_enable)
    
    -- اگر Master خاموش شد → همه چیز رو reset کن
    if not master then
        reset_everything_to_default()
    end
    
    -- 1. Custom Weapon Sounds
    ui.set_visible(cws_label, master)
    ui.set_visible(cws_enable, master)
    
    -- 2. Enemy Team Chat
    ui.set_visible(etc_label, master)
    ui.set_visible(etc_enable, master)
    
    -- 3. Magnet Melee
    ui.set_visible(mm_label, master)
    ui.set_visible(mm_enable, master)
    local mm_on = master and ui.get(mm_enable)
    ui.set_visible(mm_options, mm_on)
    
    -- 4. Fast Recharge
    ui.set_visible(fr_label, master)
    ui.set_visible(fr_enable, master)
    
    -- 5. Ping Spike
    ui.set_visible(ps_label, master)
    ui.set_visible(ps_mode, master)
    ui.set_visible(ps_reset, master)
    local ps_on = master and ui.get(ps_mode) == "Customizable"
    ui.set_visible(ps_custom, ps_on)
    
    -- 6. Unhide Cvars
    ui.set_visible(uc_label, master)
    ui.set_visible(uc_enable, master)
    
    -- 7. World Sound
    ui.set_visible(ws_label, master)
    ui.set_visible(ws_enable, master)
    local ws_on = master and ui.get(ws_enable)
    for i=1, #mixers_list do
        ui.set_visible(ws_modifier[mixers_list[i]], ws_on)
    end
    
    -- 8. Custom Animations
    ui.set_visible(ca_label, master)
    ui.set_visible(ca_enable, master)
    local ca_on = master and ui.get(ca_enable)
    ui.set_visible(ca_options, ca_on)
end

ui.set_callback(master_enable, update_ui_visibility)
ui.set_callback(mm_enable, update_ui_visibility)
ui.set_callback(ps_mode, function()
    update_ui_visibility()
    update_ping_settings()
end)
ui.set_callback(ws_enable, update_ui_visibility)
ui.set_callback(ca_enable, update_ui_visibility)
ui.set_callback(uc_enable, update_unhide_visibility)
ui.set_callback(ps_custom, function()
    if ui.get(ps_mode) == "Customizable" then update_ping_settings() end
end)

ui.set_callback(cws_enable, function()
    if not ui.get(cws_enable) then
        restore_weapon_sounds()
        cws_data.was_enabled = false
    end
end)

update_ui_visibility()
update_unhide_visibility()

-- ============================================================================
-- EVENTS
-- ============================================================================
client.set_event_callback("aim_fire", function()
    if ui.get(master_enable) and ui.get(cws_enable) then play_custom_sound() end
end)

client.set_event_callback("setup_command", function(c)
    if not ui.get(master_enable) then return end
    
    -- Custom Weapon Sounds
    if ui.get(cws_enable) then
        if c.in_attack == 1 then
            local lp = entity.get_local_player()
            if lp then
                local weapon = entity.get_player_weapon(lp)
                if weapon and csgo_weapons(weapon).is_gun then
                    local currentAmmoCount = entity.get_prop(weapon, "m_iClip1")
                    local nextAttack = entity.get_prop(weapon, "m_flNextPrimaryAttack")

                    if cvar.sv_infinite_ammo:get_int() ~= 1 then
                        if currentAmmoCount < cws_data.previous_ammo and nextAttack > globals.curtime() and nextAttack > cws_data.previous_fire then
                            cws_data.previous_fire = nextAttack
                            cws_data.previous_ammo = currentAmmoCount
                            play_custom_sound()
                        else
                            cws_data.previous_ammo = currentAmmoCount
                        end
                    else
                        if nextAttack > globals.curtime() and nextAttack ~= cws_data.previous_fire then
                            cws_data.previous_fire = nextAttack
                            play_custom_sound()
                        end
                    end
                end
            end
        end
    end
    
    -- Magnet Melee
    on_mm_setup_command(c)
    
    -- Fast Recharge
    handle_fast_recharge(c)
    
    -- Custom Animations
    if ui.get(ca_enable) then
        local lp = entity.get_local_player()
        if lp and entity.is_alive(lp) then
            ca_globals.in_speed = bit.band(c.buttons, 131072) > 0
        end
    end
end)

client.set_event_callback("player_say", on_player_say)
client.set_event_callback("player_chat", on_player_location_update)

client.set_event_callback("player_connect_full", function(e)
    if client.userid_to_entindex(e.userid) == entity.get_local_player() then
        if ui.get(master_enable) then
            if ui.get(cws_enable) then
                client.delay_call(3, function()
                    pcall(enable_sv_cheats)
                    client.exec("snd_restart")
                end)
            end
            
            if ui.get(ws_enable) then
                update_mixers()
            end
        end
    end
end)

client.set_event_callback("pre_render", function()
    if not ui.get(master_enable) or not ui.get(ca_enable) then return end
    local lp = entity.get_local_player()
    if lp and entity.is_alive(lp) then apply_custom_animations(lp) end
end)

client.set_event_callback("net_update_end", function()
    if not ui.get(master_enable) or not ui.get(ca_enable) then return end
    local lp = entity.get_local_player()
    if lp and entity.is_alive(lp) then apply_custom_animations(lp) end
end)

client.set_event_callback("shutdown", function()
    reset_everything_to_default()
end)

-- Initialize on load
if ui.get(master_enable) and ui.get(cws_enable) then
    pcall(enable_sv_cheats)
    client.exec("snd_restart")
end

update_ping_settings()
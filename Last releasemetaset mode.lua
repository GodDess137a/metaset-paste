local pui = require "gamesense/pui"
local ffi = require "ffi"
local vector = require "vector"
local bit = require "bit"
local csgo_weapons = require 'gamesense/csgo_weapons'
local chat_module = require "gamesense/chat"
local localize_module = require "gamesense/localize"
local ent = require('gamesense/entity')

-- ════════════════════════════════════════════════════════════════════════════════
-- FFI DEFINITIONS (MERGED FROM ALL SCRIPTS)
-- ════════════════════════════════════════════════════════════════════════════════
ffi.cdef[[
    typedef struct {
        float x;
        float y;
        float z;
    } vec3_t;
    
    typedef struct {
        float x, y, z;
    } Vector3;
    
    typedef void*(__thiscall* get_client_entity_t)(void*, int);
    
    typedef struct {
        char pad_0[0x14];
        int m_nFlags;
        char pad_1[0x10];
        void* m_pParent;
        int m_nValue;
        float m_fValue;
        char* m_pszString;
    } ConVar;
    
    typedef struct {
        char         __pad_0x0000[0x1cd];
        bool         hide_vm_scope;
    } ccsweaponinfo_t;
    
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
    
    typedef struct {
        char pad0[0x60];
        void* pEntity;
        void* pActiveWeapon;
        void* pLastActiveWeapon;
        float m_flLastClientSideAnimationUpdateTime;
        int m_iLastClientSideAnimationUpdateFramecount;
        float m_flEyePitch;
        float m_flEyeYaw;
        float m_flPitch;
        float m_flGoalFeetYaw;
        float m_flCurrentFeetYaw;
        float m_flCurrentTorsoYaw;
        float m_flUnknownVelocityLean;
        float m_flLeanAmount;
        char pad1[4];
        float m_flFeetCycle;
        float m_flFeetYawRate;
        char pad2[4];
        float m_fDuckAmount;
        float m_fLandingDuckAdditiveSomething;
        char pad3[4];
        Vector3 m_vOrigin;
        Vector3 m_vLastOrigin;
        Vector3 m_vVelocity;
        Vector3 m_vVelocityNormalized;
        float m_flVelocityLenght2D;
        float m_flJumpFallVelocity;
        float m_flSpeedNormalized;
        float m_flRunningSpeed;
        float m_flDuckingSpeed;
        float m_flDurationMoving;
        float m_flDurationStill;
        bool m_bOnGround;
        bool m_bHitGroundAnimation;
        float m_flNextLowerBodyYawUpdateTime;
        float m_flTotalTimeInAir;
        float m_flStartJumpZOrigin;
        float m_flAverageSpeedAsFirstFootPlanted;
        float m_flRunningAccelProgress;
        float m_flStrafingAccelProgress;
        char pad4[4];
        float m_flMoveWeight;
        float m_flMaxGroundSpeed;
        char pad5[276];
        float m_flMaxBodyYaw;
        float m_flMinBodyYaw;
    } CCSGOPlayerAnimState;
    
    typedef struct {
        char pad[0x18];
        uint32_t m_nSequence;
        float m_flPrevCycle;
        float m_flWeight;
        float m_flWeightDeltaRate;
        float m_flPlaybackRate;
        float m_flCycle;
        void* m_pOwner;
        char pad1[4];
    } CAnimationLayer;
    
    typedef uintptr_t (__thiscall* GetClientEntity_t)(void*, int);
]]

-- ════════════════════════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ════════════════════════════════════════════════════════════════════════════════
local lerp = {} 
lerp.cache = {} 
lerp.new = function(Name) lerp.cache[Name] = 0 end 
lerp.lerp = function(Name, LerpTo, Speed) 
    if lerp.cache[Name] == nil then lerp.new(Name) end 
    lerp.cache[Name] = lerp.cache[Name] + (LerpTo - lerp.cache[Name]) * (globals.frametime() * Speed) 
    return lerp.cache[Name] 
end

local function lerp_func(a, b, t)
    return a + (b - a) * t
end

local accent = {}
accent.r, accent.g, accent.b = 150, 150, 255

local print = function(...)
    client.color_log(accent.r, accent.g, accent.b, "[GodDess] \0")
    client.color_log(198, 203, 209, ...)
end

local memory = {} 
memory.pattern_scan = function(module, signature, add)
    local buff = ffi.new("char[1024]")
    local c = 0
    for char in string.gmatch(signature, "..%s?") do
        if char == "? " or char == "?? " then
            buff[c] = 0xcc
        else
            buff[c] = tonumber("0x" .. char)
        end
        c = c + 1
    end
    local result = ffi.cast("uintptr_t", client.find_signature(module, ffi.string(buff)))
    if add and tonumber(result) ~= 0 then
        result = ffi.cast("uintptr_t", tonumber(result) + add)
    end
    return result
end

local utilitize = {
    this_call = function(call_function, parameters)
        return function(...)
            return call_function(parameters, ...)
        end
    end,
    entity_list_003 = ffi.cast(ffi.typeof("uintptr_t**"), client.create_interface("client.dll", "VClientEntityList003"))
}
local get_entity_address = utilitize.this_call(ffi.cast("get_client_entity_t", utilitize.entity_list_003[0][3]), utilitize.entity_list_003)

local clamp = function(n, mn, mx)
    if n > mx then return mx elseif n < mn then return mn else return n end
end

local toticks = function(time)
    return math.floor(0.5 + time / globals.tickinterval())
end

local tools = {} 
tools.distance = function(x1, y1, z1, x2, y2, z2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2 + (z2 - z1) ^ 2)
end

tools.rgba_to_hex = function(b,c,d,e)
    return string.format('%02x%02x%02x%02x',b,c,d,e)
end

math.cycle = function(value, cycle_val)
    local result = value % cycle_val
    return result == 0 and cycle_val or result
end

local function vtable_thunk(index, typestring)
    return function(instance)
        local t = ffi.typeof(typestring)
        local fnptr = ffi.cast(t, ffi.cast('void***', instance)[0][index])
        return function(...)
            return fnptr(instance, ...)
        end
    end
end

local function fileExists(filePath)
    local fsIface = ffi.cast(ffi.typeof("void***"), client.create_interface("filesystem_stdio.dll", "VFileSystem017"))
    local fsFind = ffi.cast("const char*(__thiscall*)(void*, const char*, int*)", fsIface[0][32])
    local out = ffi.new("int[1]")
    return fsFind(fsIface, filePath, out) ~= ffi.NULL
end

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

-- Rage/Resolver helpers
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

local function normalize(angle)
    while angle > 180 do angle = angle - 360 end
    while angle < -180 do angle = angle + 360 end
    return angle
end

-- Resolver FFI
local OFFSET_ANIMSTATE = 0x9960
local OFFSET_ANIMLAYER = 0x2990

local entity_list_resolver = ffi.cast("void***", client.create_interface("client_panorama.dll", "VClientEntityList003"))
local get_client_entity_resolver = ffi.cast("GetClientEntity_t", entity_list_resolver[0][3])

local function get_entity_address_resolver(idx)
    if not idx then return nil end
    local addr = get_client_entity_resolver(entity_list_resolver, idx)
    return addr ~= nil and ffi.cast("uintptr_t", addr) or nil
end

local function get_animstate(idx)
    local addr = get_entity_address_resolver(idx)
    if not addr then return nil end
    local state = ffi.cast("CCSGOPlayerAnimState**", addr + OFFSET_ANIMSTATE)[0]
    return state ~= nil and state or nil
end

local function get_layer(idx, layer_idx)
    local addr = get_entity_address_resolver(idx)
    if not addr then return nil end
    local layers = ffi.cast("CAnimationLayer*", addr + OFFSET_ANIMLAYER)
    return layers ~= nil and layers[layer_idx] or nil
end

-- ════════════════════════════════════════════════════════════════════════════════
-- STATES & CONFIG
-- ════════════════════════════════════════════════════════════════════════════════
local temp = {}
local config = {}
local states = {"global", "stand", "slow walk", "move", "duck", "duck move", "air", "air duck"}

-- ════════════════════════════════════════════════════════════════════════════════
-- REFERENCES (MERGED FROM ALL SCRIPTS)
-- ════════════════════════════════════════════════════════════════════════════════
local ref = {
    -- Anti-Aim
    aa_enabled = ui.reference("AA", "Anti-aimbot angles", "Enabled"),
    pitch = { ui.reference("AA", "Anti-aimbot angles", "Pitch") },
    yaw_base = ui.reference("AA", "Anti-aimbot angles", "Yaw base"),
    yaw = { ui.reference("AA", "Anti-aimbot angles", "Yaw") },
    yaw_jitter = { ui.reference("AA", "Anti-aimbot angles", "Yaw jitter") },
    body_yaw = { ui.reference("AA", "Anti-aimbot angles", "Body yaw") },
    freestanding_body_yaw = ui.reference("AA", "Anti-aimbot angles", "Freestanding body yaw"),
    edge_yaw = ui.reference("AA", "Anti-aimbot angles", "Edge yaw"),
    freestanding = { ui.reference("AA", "Anti-aimbot angles", "Freestanding") },
    roll = ui.reference("AA", "Anti-aimbot angles", "Roll"),
    leg_movement = ui.reference("AA", "Other", "Leg movement"),
    
    -- Rage
    rage_enable = { ui.reference("RAGE", "Aimbot", "Enabled") },
    weapon_type = ui.reference("Rage", "Weapon type", "Weapon type"),
    minimum_damage = ui.reference("RAGE", "Aimbot", "Minimum damage"),
    damage_override = {ui.reference("RAGE", "Aimbot", "Minimum damage override")},
    aimbot_enabled = ui.reference("RAGE", "Aimbot", "Enabled"),
    double_tap = { ui.reference("Rage", "Aimbot", "Double tap") },
    onshot_aa = { ui.reference("AA", "Other", "On shot anti-aim") },
    duck_peek_assist = ui.reference("Rage", "Other", "Duck peek assist"),
    slow_motion = { ui.reference("AA", "Other", "Slow motion") },
    fakeduck = ui.reference("RAGE", "Other", "Duck peek assist"),
    air_strafe = ui.reference('Misc', 'Movement', 'Air strafe'),
    hitchance = ui.reference("RAGE", "Aimbot", "Minimum hit chance"),
    dt_checkbox = ui.reference("RAGE", "aimbot", "Double tap"),
    dt_mode = select(2, ui.reference("RAGE", "aimbot", "Double tap")),
    dt_limit = ui.reference("RAGE", "aimbot", "Double tap fake lag limit"),
    quickpeek_key = select(2, ui.reference("RAGE", "Other", "Quick peek assist")),
    fakelag_limit = ui.reference("AA", "Fake lag", "Limit"),
    
    -- Misc
    custom_events = ui.reference("MISC", "Settings", "Allow custom game events"),
    max_unlag = ui.reference("MISC", "Settings", "sv_maxunlag2"),
    max_ticks = ui.reference("MISC", "Settings", "sv_maxusrcmdprocessticks2"),
    clock_corr = ui.reference("MISC", "Settings", "sv_clockcorrection_msecs2"),
    hold_aim = ui.reference("MISC", "Settings", "sv_maxusrcmdprocessticks_holdaim")
}

ui.set(ref.aa_enabled, true)
ui.set(ref.yaw_base, "At targets")

-- CVARS (MERGED)
local sv_maxunlag = cvar.sv_maxunlag
local cvar_snd_setmixer = cvar.snd_setmixer
local cvar_con_filter_enable = cvar.con_filter_enable
local cvar_con_filter_text = cvar.con_filter_text
local cl_sidespeed = cvar.cl_sidespeed
local FL_ONGROUND = bit.lshift(1, 0)

-- ════════════════════════════════════════════════════════════════════════════════
-- MENU STRUCTURE (5 TABS)
-- ════════════════════════════════════════════════════════════════════════════════
local groups = {
    main = pui.group("aa", "anti-aimbot angles"),
}
pui.accent = tools.rgba_to_hex(150, 150, 255, 255)

local menu = {
    enable = groups.main:checkbox("\vGodDess.cc"),
    tab = groups.main:combobox("tab", {"anti-aim", "anti-aim helper", "rage", "visual", "misc"}),
    
    -- ═══════════════════════════════════════════════════════════════
    -- TAB 1: ANTI-AIM
    -- ═══════════════════════════════════════════════════════════════
    antiaim = {
        condition = groups.main:combobox("condition : ", states, false),
        builder = {},
    },
    
    -- ═══════════════════════════════════════════════════════════════
    -- TAB 2: ANTI-AIM HELPER
    -- ═══════════════════════════════════════════════════════════════
    helper = {
        freestand = groups.main:checkbox("freestand", 0x00),
        edge_yaw = groups.main:checkbox("edge yaw", 0x00),
        left = groups.main:checkbox("left ", 0x00),
        right = groups.main:checkbox("right", 0x00),
        forward = groups.main:checkbox("forward", 0x00),
        reset = groups.main:checkbox("reset", 0x00),
    },
    
    -- ═══════════════════════════════════════════════════════════════
    -- TAB 3: VISUAL
    -- ═══════════════════════════════════════════════════════════════
    visual = {

        vm_enable = groups.main:checkbox("Show viewmodel in scope"),
        

        al_enable = groups.main:checkbox("Enable Hit Logs"),
        al_hit_color = groups.main:color_picker("Hit Color", 47, 202, 159, 255),
        al_miss_color = groups.main:color_picker("Miss Color", 255, 100, 100, 255),
        al_duration = groups.main:slider("Log Duration", 1, 10, 4, true, "s"),
        al_console = groups.main:checkbox("Console Logs"),
        

        fl_enable = groups.main:checkbox("Enable Fakelag Indicator"),
        

        dm_enable = groups.main:checkbox("Enable Damage Marker"),
        dm_duration = groups.main:slider("Display Duration", 1, 10, 4, true, "s"),
        dm_speed = groups.main:slider("Speed", 1, 8, 2),
        dm_def_label = groups.main:label("Default color"),
        dm_def_color = groups.main:color_picker("Default color", 255, 255, 255, 255),
        dm_head_label = groups.main:label("Head color"),
        dm_head_color = groups.main:color_picker("Head color", 149, 184, 6, 255),
        dm_nade_label = groups.main:label("Nade color"),
        dm_nade_color = groups.main:color_picker("Nade color", 255, 179, 38, 255),
        dm_knife_label = groups.main:label("Knife color"),
        dm_knife_color = groups.main:color_picker("Knife color", 255, 255, 255, 255),
        dm_minus = groups.main:checkbox("Show (-)"),
        
        hm_enable = groups.main:checkbox("Enable Hitmarker"),
        hm_color = groups.main:color_picker("Hitmarker color", 255, 225, 225, 255),
        

        di_enable = groups.main:checkbox("Enable Crosshair Indicator"),
    },
    
    -- ═══════════════════════════════════════════════════════════════
    -- TAB 4: MISC
    -- ═══════════════════════════════════════════════════════════════
    misc = {
        safehead = groups.main:multiselect("safehead", {"knife", "zeus", "above enemy"}), 
        ladder = groups.main:checkbox("fast ladder"),
        ladder_pitch = groups.main:slider("pitch", -89, 89, 0, 1),
        ladder_yaw = groups.main:slider("yaw ", -180, 180, 0, 1),
        antistab = groups.main:checkbox("anti backstab"),
        bombfix = groups.main:checkbox("bombside e fix", 0x45),
        

        cws_enable = groups.main:checkbox("Enable Custom Sounds"),
        

        etc_enable = groups.main:checkbox("Reveal enemy teamchat"),
        

        mm_enable = groups.main:checkbox("Enable Melee Magnet"),
        mm_options = groups.main:multiselect("Melee options", {"Zeus magnet", "Knife magnet", "Forwards AA on knife"}),
        

        fr_enable = groups.main:checkbox("Enable Fast Recharge"),
        

        ps_mode = groups.main:combobox("Ping spike mode", {"Off", "Low", "Medium", "High", "Customizable"}),
        ps_custom = groups.main:slider("Custom ping value", 0, 1000, 200, true, "ms"),
        ps_reset = groups.main:button("Reset ping spike", function() end),
        

        uc_enable = groups.main:checkbox("Unhide Cvars"),
        

        ws_enable = groups.main:checkbox("Sound volume modifiers"),
        ws_modifier = {},
        
        ca_enable = groups.main:checkbox("Enable Animations"),
        ca_options = groups.main:multiselect("Animation types", {
            "pitch on land", "fallen legs", "moonwalk", "air walk",
            "blind", "fake walk", "earthquake", "slide", "fake duck", "smoothing"
        }),
    },
    
    -- ═══════════════════════════════════════════════════════════════
    -- TAB 5: RAGE (NEW)
    -- ═══════════════════════════════════════════════════════════════
    rage = {
        -- Airstop HC

        air_enable = groups.main:checkbox("Enable Airstop HC"),
        air_hotkey = groups.main:checkbox("Airstop Hotkey", 0x00),
        air_distance = groups.main:slider("Max Distance", 1, 2000, 350, true, "u"),
        air_hc_enable = groups.main:checkbox("Override Hitchance"),
        air_hc_hotkey = groups.main:checkbox("HC Hotkey", 0x00),
        air_hc_value = groups.main:slider("In-air HC %", 0, 100, 50, true, "%", 1, {[0] = "Off"}),
        air_mix_enable = groups.main:checkbox("Mix Indicators"),
        air_mix_color = groups.main:color_picker("Mix Color", 255, 255, 255, 255),
        
        -- LC Breaker

        lc_enable = groups.main:checkbox("Enable LC Breaker"),
        lc_hotkey = groups.main:checkbox("LC Breaker Hotkey", 0x00),
        lc_ticks = groups.main:slider("Self Peek Prediction Ticks", 1, 7, 3, true, "t"),
        
        -- Quick Retreat

        qr_enable = groups.main:checkbox("Enable Quick Retreat"),
        qr_req_qp = groups.main:checkbox("Only active with Quick Peek"),
        qr_logic = groups.main:multiselect("Logic Options", 
            "Preserve last weapon", 
            "Require Fakelag"
        ),
        qr_delay = groups.main:slider("Unsheathe Delay", 0, 15, 7, true, "t"),
        
        -- Resolver
        res_enable = groups.main:checkbox("Enable Resolver"),
        res_baim_multi = groups.main:multiselect("Auto force body aim if", {"HP lower than X value"}),
        res_baim_hp = groups.main:slider("Body aim HP threshold", 0, 100, 50, true, "", 1),
        res_safe_multi = groups.main:multiselect("Auto force safepoint if", {"HP lower than X value", "After X misses"}),
        res_safe_hp = groups.main:slider("Safepoint HP threshold", 0, 100, 50, true, "", 1),
        res_safe_miss = groups.main:slider("Safepoint after misses", 0, 10, 2, true, "", 1),
    },
}

-- ════════════════════════════════════════════════════════════════════════════════
-- CALLBACKS SYSTEM
-- ════════════════════════════════════════════════════════════════════════════════
local callbacks = {}
local update_callbacks = function()
    for k, v in pairs(callbacks) do
        v()
    end
end

-- ════════════════════════════════════════════════════════════════════════════════
-- DEFENSIVE SYSTEM
-- ════════════════════════════════════════════════════════════════════════════════
local defensive = {} 
defensive.defensive_active = false 
defensive.currently_active = false
defensive.db = {}

defensive.is_active = function(self, player, mode)
    if not mode then mode = false end
    if not player then return end

    local idx = entity.get_steam64(player)
    local tickcount = globals.tickcount()
    local sim_time = toticks(entity.get_prop(player, "m_flSimulationTime"))

    self.db[idx] = self.db[idx] and self.db[idx] or {last_sim_time = 0, defensive_until = 0}

    if self.db[idx].last_sim_time == 0 then
        self.db[idx].last_sim_time = sim_time
        return false
    end

    local sim_diff = sim_time - self.db[idx].last_sim_time

    if sim_diff < 0 then
        self.db[idx].defensive_until = globals.tickcount() + math.abs(sim_diff) - toticks(client.latency())
    end
    
    self.db[idx].last_sim_time = sim_time

    local ret = {
        tick = self.db[idx].defensive_until,
        active = self.db[idx].defensive_until > globals.tickcount(),
    }

    return mode and ret or self.db[idx].defensive_until > globals.tickcount()
end

-- ════════════════════════════════════════════════════════════════════════════════
-- FAKELAG DETECTION SYSTEM
-- ════════════════════════════════════════════════════════════════════════════════
local fakelag_detector = {}
fakelag_detector.player_data = {}

fakelag_detector.detect = function(self, player)
    if not player or not entity.is_alive(player) then return false end
    
    local idx = entity.get_steam64(player)
    if not idx then return false end
    
    local sim_time = entity.get_prop(player, "m_flSimulationTime")
    local old_sim_time = entity.get_prop(player, "m_flOldSimulationTime")
    
    if not sim_time or not old_sim_time then return false end
    
    if not self.player_data[idx] then
        self.player_data[idx] = {
            last_sim = sim_time,
            choke_count = 0,
            has_fakelag = false,
            last_check = globals.curtime()
        }
        return false
    end
    
    local data = self.player_data[idx]
    local sim_diff = sim_time - data.last_sim
    
    if sim_diff > globals.tickinterval() * 1.5 then
        data.choke_count = data.choke_count + 1
        data.has_fakelag = true
        data.last_check = globals.curtime()
    else
        if globals.curtime() - data.last_check > 2 then
            data.has_fakelag = false
            data.choke_count = 0
        end
    end
    
    data.last_sim = sim_time
    return data.has_fakelag
end

fakelag_detector.any_enemy_fakelag = function(self)
    local enemies = entity.get_players(true)
    for _, enemy in ipairs(enemies) do
        if self:detect(enemy) then
            return true
        end
    end
    return false
end

-- ════════════════════════════════════════════════════════════════════════════════
-- ANTIAIM SYSTEM
-- ════════════════════════════════════════════════════════════════════════════════
local antiaim = {} 
antiaim.current_state = ""
antiaim.current_state_number = 0
antiaim.defensive_yaw = 0
antiaim.is_on_ground = false
antiaim.delayside = false
antiaim.current_tickcount = 0
antiaim.olddt = false
antiaim.forceupdate = false
antiaim.side1 = "reset"
antiaim.oldside = false
antiaim.defensiveold = false
antiaim.pitchswitch = false
antiaim.jitter_counter = 0
antiaim.jitter_direction = 1
antiaim.last_jitter_tick = 0

antiaim.pitch_jitter = {
    switch = false,
    last_switch_tick = 0
}

antiaim.spin_jitter = {
    switch = false,
    last_tick = 0,
    spin_angle = 0
}

antiaim.update_jitter = function(self, delay_ticks)
    if delay_ticks == 0 then return end
    
    local current_tick = globals.tickcount()
    local actual_delay = delay_ticks
    
    if current_tick - self.last_jitter_tick >= actual_delay then
        self.jitter_direction = self.jitter_direction * -1
        self.last_jitter_tick = current_tick
        self.jitter_counter = self.jitter_counter + 1
    end
end

antiaim.update = function(self, ctx)
    local local_player = entity.get_local_player()
    if not entity.is_alive(local_player) or not local_player then return end
    
    local xv, yv = entity.get_prop(local_player, "m_vecVelocity")
    local flags = entity.get_prop(local_player, "m_fFlags")
    local slow_walk = ui.get(ref.slow_motion[1]) and ui.get(ref.slow_motion[2])
    local ducking = bit.lshift(1, 1)
    local ground = bit.lshift(1, 0)
    local velocity = math.sqrt(xv*xv + yv*yv)
    
    antiaim.is_on_ground = (ctx.in_jump == 0)
    
    local state = function()
        if bit.band(flags, ground) == 1 and velocity < 3 and bit.band(flags, ducking) == 0 then
            self.current_state = "Stand"
            self.current_state_number = 2
        else
            if bit.band(flags, ground) == 1 and velocity > 3 and bit.band(flags, ducking) == 0 and slow_walk then
                self.current_state = "Slow-Walk"
                self.current_state_number = 3
            end
        end
        
        if bit.band(flags, ground) == 1 and velocity > 3 and bit.band(flags, ducking) == 0 and not slow_walk and (ctx.in_jump == 0) then
            self.current_state = "Moving"
            self.current_state_number = 4
        end
        
        if bit.band(flags, ground) == 1 and bit.band(flags, ducking) > 0.9 and menu.antiaim.builder[6].override:get() and velocity > 10 and (ctx.in_jump == 0) then
            self.current_state = "Duck-Move"
            self.current_state_number = 6
        elseif bit.band(flags, ground) == 1 and bit.band(flags, ducking) > 0.9 and (ctx.in_jump == 0) then
            self.current_state = "DUCK"
            self.current_state_number = 5
        end
        
        if bit.band(flags, ground) == 0 and bit.band(flags, ducking) == 0 then
            self.current_state = "Air"
            self.current_state_number = 7
        end
        
        if bit.band(flags, ground) == 0 and bit.band(flags, ducking) > 0.9 then
            self.current_state = "Air+D"
            self.current_state_number = 8
        end
    end
    state()
end

antiaim.handler = function(self, ctx)
    local local_player = entity.get_local_player()
    if not entity.is_alive(local_player) or not local_player then return end
    
    local enemy_has_fakelag = fakelag_detector:any_enemy_fakelag()
    
    local global_enabled = menu.antiaim.builder[1].enable_global and menu.antiaim.builder[1].enable_global:get() or false
    
    local currentstate
    if global_enabled then
        currentstate = 1
    else
        currentstate = (self.current_state_number > 1 and menu.antiaim.builder[self.current_state_number].override:get()) 
            and self.current_state_number or 2
    end
    
    local state = menu.antiaim.builder[currentstate]

    local yaw = 0
    local bodyyaw = math.max(-60, math.min(60, math.floor((entity.get_prop(local_player, "m_flPoseParameter", 11) or 0) * 120 - 60)))
    local side = bodyyaw >= 0 and true or false
    
    local fakeduck = ui.get(ref.duck_peek_assist)
    local fs_active, key = menu.helper.freestand:get_hotkey()
    local doubletap = ui.get(ref.double_tap[1]) and ui.get(ref.double_tap[2]) and not ui.get(ref.fakeduck)
    local hideshots = ui.get(ref.onshot_aa[1]) and ui.get(ref.onshot_aa[2]) and not ui.get(ref.fakeduck)
    local tickbase = (doubletap or hideshots) and not fakeduck
    local lc = tickbase ~= self.olddt and tickbase == false
    local send_packet = ctx.chokedcommands == 0

    self.forceupdate = false

    local is_jitter_mode = state.modifier:get() == "jitter"
    
    if is_jitter_mode then
        self:update_jitter(state.delay_ticks:get())
    end

    -- Pitch
    if state.pitch:get() == "disabled" then
        ui.set(ref.pitch[1], "off")
    elseif state.pitch:get() == "down" then
        ui.set(ref.pitch[1], "minimal")
    elseif state.pitch:get() == "up" then
        ui.set(ref.pitch[1], "up")
    elseif state.pitch:get() == "zero" then
        ui.set(ref.pitch[1], "custom")
        ui.set(ref.pitch[2], 0)
    elseif state.pitch:get() == "custom" then
        ui.set(ref.pitch[1], "custom")
        ui.set(ref.pitch[2], state.pitch_custom:get())
    end
    
    -- Body Yaw
    if is_jitter_mode then
        ui.set(ref.body_yaw[1], "static")
        if enemy_has_fakelag then
            ui.set(ref.body_yaw[2], 0)
        else
            ui.set(ref.body_yaw[2], self.jitter_direction > 0 and 1 or -1)
        end
        self.forceupdate = true
    elseif state.bodyyaw:get() == "jitter" then
        if lc then
            ui.set(ref.body_yaw[1], "static")
            ui.set(ref.body_yaw[2], side and -1 or 1)
            self.forceupdate = true
        elseif ctx.chokedcommands == 0 then
            ui.set(ref.body_yaw[1], "static")
            ui.set(ref.body_yaw[2], side and -1 or 1)
            self.forceupdate = true
        end
    elseif state.bodyyaw:get() == "break" then
        if lc or (self.defensiveold == true and defensive.currently_active == false) then
            ui.set(ref.body_yaw[1], "static")
            ui.set(ref.body_yaw[2], bodyyaw >= 0 and -1 or 1)
            self.forceupdate = true
        elseif globals.tickcount() % state.delay:get() * 2 < state.delay:get() then
            if ctx.chokedcommands == 0 then
                ui.set(ref.body_yaw[1], "static")
                ui.set(ref.body_yaw[2], bodyyaw >= 0 and -1 or 1)
                self.forceupdate = true
            end
        end
    elseif state.bodyyaw:get() == "delayed" then
        if lc or (self.defensiveold == true and defensive.currently_active == false) then
            ui.set(ref.body_yaw[1], "static")
            ui.set(ref.body_yaw[2], bodyyaw >= 0 and -1 or 1)
            self.forceupdate = true
        elseif tickbase then
            if globals.tickcount() > antiaim.current_tickcount + state.delay:get() then
                if ctx.chokedcommands == 0 then
                    antiaim.delayside = not antiaim.delayside
                    antiaim.current_tickcount = globals.tickcount()
                end
            elseif globals.tickcount() < antiaim.current_tickcount then
                antiaim.current_tickcount = globals.tickcount()
            end
            ui.set(ref.body_yaw[1], "static")
            ui.set(ref.body_yaw[2], antiaim.delayside and -1 or 1)
            self.forceupdate = true
        else
            if ctx.chokedcommands == 0 then
                ui.set(ref.body_yaw[1], "static")
                ui.set(ref.body_yaw[2], bodyyaw >= 0 and -1 or 1)
                self.forceupdate = true
            end
        end
    elseif state.bodyyaw:get() == "jitter (skeet)" then
        ui.set(ref.body_yaw[1], "jitter")
        ui.set(ref.body_yaw[2], -1)
        self.forceupdate = true
    elseif state.bodyyaw:get() == "left" then
        ui.set(ref.body_yaw[1], "static")
        ui.set(ref.body_yaw[2], -1)
        self.forceupdate = true
    elseif state.bodyyaw:get() == "right" then
        ui.set(ref.body_yaw[1], "static")
        ui.set(ref.body_yaw[2], 1)
        self.forceupdate = true
    else
        ui.set(ref.body_yaw[1], "static")
        ui.set(ref.body_yaw[2], 0)
        self.forceupdate = true
    end

    -- Yaw
    if state.yaw:get() == "disabled" then
        ui.set(ref.yaw[1], "off")
    elseif state.yaw:get() == "backward" then
        yaw = state.yaw_value:get()
        ui.set(ref.yaw[1], "180")
    elseif state.yaw:get() == "left/right" then
        yaw = (side and state.classic1:get() or state.classic2:get())
        ui.set(ref.yaw[1], "180")
    end

    ui.set(ref.yaw_jitter[1], "off")
    ui.set(ref.yaw_jitter[2], 0)

    -- Modifier
    if is_jitter_mode then
        local jitter_degree = state.mod_slider:get()
        if enemy_has_fakelag then
            yaw = 0
        else
            yaw = yaw + (jitter_degree * self.jitter_direction)
        end
    elseif state.modifier:get() == "center (skeet)" then
        ui.set(ref.yaw_jitter[1], "Center")
        ui.set(ref.yaw_jitter[2], state.mod_slider:get())
    elseif state.modifier:get() == "offset (skeet)" then
        ui.set(ref.yaw_jitter[1], "Offset")
        ui.set(ref.yaw_jitter[2], state.mod_slider:get())
    elseif state.modifier:get() == "random" then
        ui.set(ref.yaw_jitter[1], "random")
        ui.set(ref.yaw_jitter[2], state.mod_slider:get())
    elseif state.modifier:get() == "skitter" then
        ui.set(ref.yaw_jitter[1], "skitter")
        ui.set(ref.yaw_jitter[2], state.mod_slider:get())
    end

    ui.set(ref.freestanding[1], menu.helper.freestand:get()) 
    ui.set(ref.freestanding[2], fs_active and "Always on" or "On hotkey")
    ui.set(ref.edge_yaw, menu.helper.edge_yaw:get_hotkey() and menu.helper.edge_yaw:get())

    if ctx.chokedcommands > 1 then return end
    
    if state.defensive:get() == "always on" and not (self.side1 == "forward" or self.side1 == "left" or self.side1 == "right") then
        ctx.force_defensive = true
    end
    
    local defensive_active = (defensive.currently_active) and not (state.defensive:get() == "-") and ((hideshots or doubletap) and not fakeduck)
    
    if defensive_active ~= self.defensiveold and defensive_active then
        self.pitchswitch = not self.pitchswitch
    end
    
    if defensive_active then
        -- Defensive Pitch
        if state.defensive_pitch:get() == "static" then
            ui.set(ref.pitch[1], "custom")
            ui.set(ref.pitch[2], state.defensive_pitch_ang:get())
        elseif state.defensive_pitch:get() == "jitter" then
            local current_tick = globals.tickcount()
            if current_tick ~= self.pitch_jitter.last_switch_tick then
                self.pitch_jitter.switch = not self.pitch_jitter.switch
                self.pitch_jitter.last_switch_tick = current_tick
            end
            
            ui.set(ref.pitch[1], "custom")
            ui.set(ref.pitch[2], self.pitch_jitter.switch and state.defensive_pitch_ang:get() or state.defensive_pitch_ang2:get())
        elseif state.defensive_pitch:get() == "random" then
            ui.set(ref.pitch[1], "custom")
            ui.set(ref.pitch[2], client.random_int(state.defensive_pitch_ang:get(), state.defensive_pitch_ang2:get()))
        elseif state.defensive_pitch:get() == "spin" then
            ui.set(ref.pitch[1], "custom")
            local spin_progress = (globals.curtime() * state.defensive_pitch_speed:get() * 0.1) % 1
            local pitch_range = state.defensive_pitch_ang2:get() - state.defensive_pitch_ang:get()
            ui.set(ref.pitch[2], state.defensive_pitch_ang:get() + pitch_range * spin_progress)
        elseif state.defensive_pitch:get() ~= "disabled" then
            ui.set(ref.pitch[1], state.defensive_pitch:get())
        end
        
        -- Defensive Yaw
        if state.defensive_yaw:get() == "static" then
            ui.set(ref.yaw_jitter[1], "off")
            ui.set(ref.body_yaw[1], "static")
            ui.set(ref.body_yaw[2], 0)
            ctx.no_choke = true
            self.defensive_yaw = state.defensive_yaw_val:get()
        elseif state.defensive_yaw:get() == "sideways" then
            ui.set(ref.body_yaw[1], "static")
            ui.set(ref.body_yaw[2], 0)
            self.defensive_yaw = globals.tickcount() % 6 > 3 and state.defensive_yaw_val:get() or -state.defensive_yaw_val:get()
            ctx.no_choke = true
        elseif state.defensive_yaw:get() == "random" then
            ui.set(ref.yaw[2], 0)
            ui.set(ref.yaw_jitter[1], "random")
            ui.set(ref.yaw_jitter[2], -180)
            ui.set(ref.body_yaw[1], "static")
            ui.set(ref.body_yaw[2], 0)
            ctx.no_choke = true
        elseif state.defensive_yaw:get() == "move-based" then
            self.defensive_yaw = ctx.sidemove == 0 and 180 or (ctx.sidemove > 0 and 90 or -90)
            ui.set(ref.yaw_jitter[1], "random")
            ui.set(ref.yaw_jitter[2], -90)
            ui.set(ref.body_yaw[1], "static")
            ui.set(ref.body_yaw[2], 0)
            ctx.no_choke = true
        elseif state.defensive_yaw:get() == "spin" then
            ui.set(ref.body_yaw[1], "static")
            ui.set(ref.body_yaw[2], 0)
            self.defensive_yaw = self.defensive_yaw + state.defensive_spin:get()
            if self.defensive_yaw > 180 then self.defensive_yaw = -180 end
            if self.defensive_yaw < -180 then self.defensive_yaw = 180 end
            ui.set(ref.yaw_jitter[1], "off")
            ctx.no_choke = true
        elseif state.defensive_yaw:get() == "jitter" then
            ui.set(ref.body_yaw[1], "static")
            ui.set(ref.body_yaw[2], 0)
            ui.set(ref.yaw_jitter[1], "off")
            self.defensive_yaw = globals.tickcount() % 6 > 3 and state.defensive_yaw_val:get() or state.defensive_yaw_val2:get()
            ctx.no_choke = true
        elseif state.defensive_yaw:get() == "spin jitter" then
            local current_tick = globals.tickcount()
            
            if current_tick - self.spin_jitter.last_tick >= state.defensive_yaw_sj_delay:get() then
                self.spin_jitter.switch = not self.spin_jitter.switch
                self.spin_jitter.last_tick = current_tick
            end
            
            local time_multiplier = 10.0
            local speed_factor = state.defensive_yaw_sj_speed:get() / 10.0
            local spin_progress = (globals.curtime() * time_multiplier * speed_factor) % 1
            
            local angle_range = state.defensive_yaw_sj_angle:get()
            local spin_offset = (spin_progress * angle_range * 2) - angle_range
            
            local jitter_side = self.spin_jitter.switch and 90 or -90
            
            self.defensive_yaw = jitter_side + spin_offset
            
            local desync_value = self.spin_jitter.switch and 60 or -60
            ui.set(ref.body_yaw[1], "static")
            ui.set(ref.body_yaw[2], desync_value > 0 and 1 or -1)
            ui.set(ref.yaw_jitter[1], "off")
            ctx.no_choke = true
        else
            self.defensive_yaw = yaw
        end
    end
    
    if defensive_active then
        if state.defensive_yaw:get() ~= "disabled" then
            ui.set(ref.yaw[2], clamp(self.defensive_yaw, -180, 180))
        else
            if self.forceupdate == true then
                ui.set(ref.yaw[2], clamp(self.defensive_yaw, -180, 180))
            end
        end
    elseif tickbase then
        if self.forceupdate == true then
            ui.set(ref.yaw[2], clamp(yaw, -180, 180))
        end
    elseif not tickbase then
        if self.forceupdate == true then
            ui.set(ref.yaw[2], clamp(yaw, -180, 180))
        end
    end

    self.olddt = tickbase
    self.defensiveold = defensive.currently_active
end

antiaim.bombsite_fix = function(cmd)
    local lplr = entity.get_local_player()
    if lplr == nil or not entity.is_alive(lplr) then return end    
    local bombsite, tmp4 = menu.misc.bombfix:get_hotkey()
    local number = entity.get_player_weapon(lplr)
    local my_weapon = entity.get_classname(number)
    local inbombzone = entity.get_prop(lplr, "m_bInBombZone")
    local team_num = entity.get_prop(lplr, "m_iTeamNum")
    
    local holdbomb = my_weapon == "CC4"
    if menu.misc.bombfix:get() and team_num == 2 and inbombzone == 1 and not holdbomb then
        cmd.in_use = false
        if bombsite then
            ui.set(ref.aa_enabled, false)
        else
            ui.set(ref.aa_enabled, true)
        end
    else
        ui.set(ref.aa_enabled, true)
    end
end

antiaim.manuals = function(self)
    local local_player = entity.get_local_player()
    if not entity.is_alive(local_player) or not local_player then return end
    
    if menu.helper.left:get_hotkey() and menu.helper.left:get() then 
        local bind, key = menu.helper.left:get_hotkey()
        if self.oldside ~= bind then
            if self.side1 == "left" then 
                self.side1 = "reset"
            else
                self.side1 = "left"
            end
        end
        self.oldside = menu.helper.left:get()
    elseif menu.helper.right:get_hotkey() and menu.helper.right:get() then 
        local bind, key = menu.helper.right:get_hotkey()
        if self.oldside ~= bind then
            if self.side1 == "right" then 
                self.side1 = "reset"
            else
                self.side1 = "right"
            end
        end
        self.oldside = menu.helper.right:get()
    elseif menu.helper.forward:get_hotkey() and menu.helper.forward:get() then 
        local bind, key = menu.helper.forward:get_hotkey()
        if self.oldside ~= bind then
            if self.side1 == "forward" then 
                self.side1 = "reset"
            else
                self.side1 = "forward"
            end
        end
        self.oldside = menu.helper.forward:get()
    elseif menu.helper.reset:get_hotkey() and menu.helper.reset:get() then 
        self.side1 = "reset"
    else
        self.oldside = false
    end
    
    if self.side1 == "left" then 
        ui.set(ref.yaw[1], "180")
        ui.set(ref.yaw[2], -90)
        ui.set(ref.body_yaw[1], "static")
        ui.set(ref.body_yaw[2], 0)
        ui.set(ref.yaw_jitter[1], "off")
    elseif self.side1 == "right" then
        ui.set(ref.yaw[1], "180")
        ui.set(ref.yaw[2], 90)
        ui.set(ref.body_yaw[1], "static")
        ui.set(ref.body_yaw[2], 0)
        ui.set(ref.yaw_jitter[1], "off")
    elseif self.side1 == "forward" then
        ui.set(ref.yaw[1], "180")
        ui.set(ref.yaw[2], 180)
        ui.set(ref.body_yaw[1], "static")
        ui.set(ref.body_yaw[2], 0)
        ui.set(ref.yaw_jitter[1], "off")
    end
end

antiaim.safe_head = function(self)
    local local_player = entity.get_local_player()
    if not entity.is_alive(local_player) or not local_player then return end
    local enemy = client.current_threat()
    local lp_x, lp_y, lp_z = entity.hitbox_position(local_player, 7)
    local number = entity.get_player_weapon(local_player)
    local t_x, t_y, t_z = 0, 0, 0
    local my_weapon = entity.get_classname(number)
    
    local distance = 0
    if enemy ~= nil then
        t_x, t_y, t_z = entity.hitbox_position(enemy, 7)
        distance = tools.distance(lp_x, lp_y, lp_z, t_x, t_y, t_z)
    else
        distance = 301
    end
    
    if (antiaim.current_state_number == 8) then
        if menu.misc.safehead:get("knife") and my_weapon == "CKnife" then
            ui.set(ref.pitch[1], "Minimal")
            ui.set(ref.yaw[1], "180")
            ui.set(ref.yaw[2], 0)
            ui.set(ref.yaw_jitter[1], "off")
            ui.set(ref.yaw_jitter[2], 0)
            ui.set(ref.body_yaw[1], "static")
            ui.set(ref.body_yaw[2], 0)
        end
        if menu.misc.safehead:get("zeus") and my_weapon == "CWeaponTaser" then
            ui.set(ref.pitch[1], "Minimal")
            ui.set(ref.yaw[1], "180")
            ui.set(ref.yaw[2], 0)
            ui.set(ref.yaw_jitter[1], "off")
            ui.set(ref.yaw_jitter[2], 0)
            ui.set(ref.body_yaw[1], "static")
            ui.set(ref.body_yaw[2], 0)
        end
    end
    
    if (antiaim.current_state_number == 5 or antiaim.current_state_number == 6) then
        if menu.misc.safehead:get("above enemy") and lp_z - t_z > 50 and enemy ~= nil then
            ui.set(ref.pitch[1], "Minimal")
            ui.set(ref.yaw[1], "180")
            ui.set(ref.yaw[2], 5)
            ui.set(ref.yaw_jitter[1], "off")
            ui.set(ref.yaw_jitter[2], 0)    
            ui.set(ref.body_yaw[1], "static")
            ui.set(ref.body_yaw[2], 0)
        end
    elseif (antiaim.current_state_number == 7 or antiaim.current_state_number == 8) then
        if menu.misc.safehead:get("above enemy") and lp_z - t_z > 130 and enemy ~= nil then
            ui.set(ref.pitch[1], "Minimal")
            ui.set(ref.yaw[1], "180")
            ui.set(ref.yaw[2], 0)
            ui.set(ref.yaw_jitter[1], "off")
            ui.set(ref.yaw_jitter[2], 0)
            ui.set(ref.body_yaw[1], "static")
            ui.set(ref.body_yaw[2], 0)
        end
    end
end

antiaim.get_vector_origin = function(idx)
    local v1, v2, v3 = entity.get_origin(idx)
    return {x = v1, y = v2, z = v3}
end

antiaim.yawto180 = function(yawbruto)
    if yawbruto > 180 then
        return yawbruto - 360
    end
    return yawbruto
end

antiaim.yaw_to_player = function(player, forward)
    local LocalPlayer = entity.get_local_player()
    if not LocalPlayer or not player then return 0 end

    local lOrigin = antiaim.get_vector_origin(LocalPlayer)
    local pOrigin = antiaim.get_vector_origin(player)
    local Yaw = (-math.atan2(pOrigin.x - lOrigin.x, pOrigin.y - lOrigin.y) / 3.14 * 180 + 180) - (forward and 90 or -90)
    
    if Yaw >= 180 then
        Yaw = 360 - Yaw
        Yaw = -Yaw
    end
    Yaw = antiaim.yawto180(Yaw)
    return Yaw
end

antiaim.anti_backstab = function(self, cmd)
    if not menu.misc.antistab:get() then return end
    local local_player = entity.get_local_player()
    if not entity.is_alive(local_player) or not local_player then return end
    
    local cache = {dist = math.huge, ent = nil}

    for _, enemy in pairs(entity.get_players(true)) do
        local lp_x, lp_y, lp_z = entity.hitbox_position(local_player, 7)
        local t_x, t_y, t_z = 0, 0, 0
        local distance = 0
        
        if enemy ~= nil then
            t_x, t_y, t_z = entity.hitbox_position(enemy, 7)
            distance = tools.distance(lp_x, lp_y, lp_z, t_x, t_y, t_z)
        end

        if distance < cache.dist then
            cache.dist = distance
            cache.ent = enemy
        end
    end
    
    if cache.dist < 250 and (cache.ent ~= nil) then
        local enemywep = entity.get_player_weapon(cache.ent)
        if not enemywep then return end
        local wepname = entity.get_classname(enemywep)

        if wepname == "CKnife" then
            cmd.yaw = self.yaw_to_player(cache.ent, true)
        end
    end
end

-- ════════════════════════════════════════════════════════════════════════════════
-- MISC HELPERS
-- ════════════════════════════════════════════════════════════════════════════════
local main = {} 
main.disableladder = {
    "CHEGrenade",
    "CMolotovGrenade",
    "CSmokeGrenade",
    "CDecoyGrenade",
    "CIncendiaryGrenade",
    "CFlashbang",
}

main.ladder = function(self, cmd)
    if not menu.misc.ladder:get() then return end
    local lplr = entity.get_local_player()
    if not lplr or not entity.is_alive(lplr) then return end
    if not (entity.get_prop(lplr, "m_MoveType") == 9) then return end
    
    local pitch, yaw = client.camera_angles()
    local weapon = entity.get_player_weapon(lplr)
    local nade = false
    
    if weapon then
        for i = 1, #main.disableladder do
            if entity.get_classname(weapon) == main.disableladder[i] then
                nade = true
                break
            end
        end
    end
    
    if cmd.forwardmove == 0 then
        ui.set(ref.pitch[1], "custom")
        ui.set(ref.pitch[2], menu.misc.ladder_pitch:get())
        ui.set(ref.yaw[1], "180")
        ui.set(ref.yaw[2], menu.misc.ladder_yaw:get())
    elseif cmd.forwardmove > 0 and not nade then
        if pitch < 45 then
            cmd.pitch = 89
            cmd.in_moveright = true
            cmd.in_moveleft = false
            cmd.in_forward = false
            cmd.in_back = true
            if cmd.sidemove == 0 then
                cmd.yaw = cmd.yaw + 90
            elseif cmd.sidemove < 0 then
                cmd.yaw = cmd.yaw + 150
            elseif cmd.sidemove > 0 then
                cmd.yaw = cmd.yaw + 30
            end
        end
    elseif cmd.forwardmove < 0 and not nade then
        cmd.pitch = 89
        cmd.in_moveright = false
        cmd.in_moveleft = true
        cmd.in_forward = true
        cmd.in_back = false
        if cmd.sidemove == 0 then
            cmd.yaw = cmd.yaw + 90
        elseif cmd.sidemove > 0 then
            cmd.yaw = cmd.yaw + 150
        elseif cmd.sidemove < 0 then
            cmd.yaw = cmd.yaw + 30 
        end
    end
end

-- ════════════════════════════════════════════════════════════════════════════════
-- VISUAL FEATURES (FROM SCRIPT 2)
-- ════════════════════════════════════════════════════════════════════════════════

-- ═══ 1. VIEWMODEL IN SCOPE ═══
local vm_match = client.find_signature("client_panorama.dll", "\x8B\x35\xCC\xCC\xCC\xCC\xFF\x10\x0F\xB7\xC0")
local vm_weaponsystem_raw = nil
local vm_get_weapon_info = nil

if vm_match then
    vm_weaponsystem_raw = ffi.cast("void****", ffi.cast("char*", vm_match) + 2)[0]
    vm_get_weapon_info = vtable_thunk(2, "ccsweaponinfo_t*(__thiscall*)(void*, unsigned int)")(vm_weaponsystem_raw)
end

local function vm_run_command()
    if not menu.enable:get() or not menu.visual.vm_enable:get() then return end
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

-- ═══ 2. AIM LOG ═══
local al_hitgroup_names = {
    [0] = "generic", [1] = "head", [2] = "chest", [3] = "stomach",
    [4] = "left arm", [5] = "right arm", [6] = "left leg", [7] = "right leg",
    [8] = "neck", [9] = "?", [10] = "gear"
}

local al_logs = {}
local al_shot_data = {}
local al_max_logs = 5

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
    if not menu.enable:get() or not menu.visual.al_enable:get() then return end
    al_shot_data[e.id] = { tick = e.tick }
end

local function al_on_aim_hit(e)
    if not menu.enable:get() or not menu.visual.al_enable:get() then return end
    
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
    
    if menu.visual.al_console:get() then
        print(string.format("Hit %s in the %s for %d damage (%d health remaining) [bt: %d]",
            target_name, hitgroup, damage, health_remaining, backtrack_ticks))
    end
    
    al_shot_data[e.id] = nil
end

local function al_on_aim_miss(e)
    if not menu.enable:get() or not menu.visual.al_enable:get() then return end
    
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
    
    if menu.visual.al_console:get() then
        print(string.format("Missed %s in the %s due to %s (%d%% hitchance) [bt: %d]",
            target_name, hitgroup, reason, hitchance, backtrack_ticks))
    end
    
    al_shot_data[e.id] = nil
end

local function al_on_paint()
    if not menu.enable:get() or not menu.visual.al_enable:get() then return end
    
    local screen_x, screen_y = client.screen_size()
    local center_x = screen_x / 2
    local start_y = screen_y / 2 + 250
    
    local current_time = globals.realtime()
    local duration = menu.visual.al_duration:get()
    
    local hit_r, hit_g, hit_b = menu.visual.al_hit_color:get()
    local miss_r, miss_g, miss_b = menu.visual.al_miss_color:get()
    
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
                
                renderer.text(current_x + 1, y + 1, 0, 0, 0, alpha, "", 0, part.text)
                renderer.text(current_x, y, text_r, text_g, text_b, alpha, "", 0, part.text)
                
                local w = renderer.measure_text(nil, part.text)
                current_x = current_x + w
            end
            
            offset = offset + 15
        end
    end
end

-- ═══ 3. FAKELAG INDICATOR ═══
local fl_old_choke = 0
local fl_to_draw = {0, 0, 0, 0, 0}

local function fl_on_paint()
    if not menu.enable:get() or not menu.visual.fl_enable:get() then return end
    
    renderer.indicator(220, 220, 220, 255, string.format('%i-%i-%i-%i-%i', 
        fl_to_draw[5], fl_to_draw[4], fl_to_draw[3], fl_to_draw[2], fl_to_draw[1]))
end

local function fl_setup_command(cmd)
    if not menu.enable:get() or not menu.visual.fl_enable:get() then return end
    
    if cmd.chokedcommands < fl_old_choke then
        for i = 1, 4 do
            fl_to_draw[i] = fl_to_draw[i + 1]
        end
        fl_to_draw[5] = fl_old_choke
    end
    
    fl_old_choke = cmd.chokedcommands
end

-- ═══ 4. DAMAGE MARKER + HITMARKER ═══
local dm_displays = {}
local dm_hitgroup_names = {"generic", "head", "chest", "stomach", "left arm", "right arm", "left leg", "right leg", "neck", "?", "gear"}

local function dm_hitbox_c(hitgroup)
    local hitbox_map = {
        [1] = 0, [2] = 5, [3] = 3, [4] = 14,
        [5] = 15, [6] = 8, [7] = 9, [8] = 1
    }
    return hitbox_map[hitgroup] or 0
end

local function dm_on_player_hurt(e)
    if not menu.enable:get() or not menu.visual.dm_enable:get() then return end
    
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
    if not menu.enable:get() or not menu.visual.dm_enable:get() then return end
    
    local dm_displays_new = {}
    local max_time_delta = menu.visual.dm_duration:get() / 2
    local speed = menu.visual.dm_speed:get() / 3
    local realtime = globals.realtime()
    local max_time = realtime - max_time_delta / 2
    
    for i = 1, #dm_displays do
        local display = dm_displays[i]
        local damage, time, x, y, z, e = display[1], display[2], display[3], display[4], display[5], display[6]
        local r, g, b, a = menu.visual.dm_def_color:get()

        if time > max_time then
            local sx, sy = client.world_to_screen(ctx, x, y, z)
 
            if e.hitgroup == 1 then
                r, g, b = menu.visual.dm_head_color:get()
            end

            local wpn = e.weapon
            if wpn == "hegrenade" or wpn == "inferno" then
                r, g, b = menu.visual.dm_nade_color:get()
            elseif wpn == "knife" then
                r, g, b = menu.visual.dm_knife_color:get()
            end
            
            local prefix = menu.visual.dm_minus:get() and "-" or ""
            
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

-- Hitmarker
local hm_shot_data = {}
local hm_memory = {}

local function hm_paint()
    if not menu.enable:get() or not menu.visual.hm_enable:get() then return end
    
    local r, g, b = menu.visual.hm_color:get()
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
    if not menu.enable:get() or not menu.visual.hm_enable:get() then return end
    
    local t_x, t_y, t_z = entity.hitbox_position(e.target, dm_hitbox_c(e.hitgroup))
    local aboba, aboba1, aboba2 = client.eye_position()
    
    hm_memory[1] = {
        t_x = t_x, t_y = t_y, t_z = t_z,
        aboba = aboba, aboba1 = aboba1, aboba2 = aboba2
    }
end

local function hm_aim_hit(e)
    if not menu.enable:get() or not menu.visual.hm_enable:get() then return end
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

-- ═══ 5. DAMAGE INDICATOR (CROSSHAIR) ═══
local di_scr_w, di_scr_h = client.screen_size()
local di_cx, di_cy = di_scr_w / 2, di_scr_h / 2

local di_anim = {
    dmg = 0,
    alpha = 0,
    ovr_state = 0
}

local function di_on_paint()
    if not menu.enable:get() or not menu.visual.di_enable:get() then return end
    
    local lp = entity.get_local_player()
    if not lp or not entity.is_alive(lp) then
        di_anim.alpha = 0
        return
    end

    local is_overriding = false
    if ref.damage_override[2] then
        is_overriding = ui.get(ref.damage_override[2])
    end
    
    local min_damage = ui.get(ref.minimum_damage)
    local target_damage = min_damage

    if is_overriding and ref.damage_override[3] then
        target_damage = ui.get(ref.damage_override[3])
    end

    local ft = globals.frametime() * 20
    
    di_anim.dmg = lerp_func(di_anim.dmg, target_damage, ft * 0.5)
    di_anim.ovr_state = lerp_func(di_anim.ovr_state, is_overriding and 1 or 0, ft * 0.5)
    
    local should_show = not client.key_state(0x09)
    di_anim.alpha = lerp_func(di_anim.alpha, should_show and 1 or 0, ft * 0.5)

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
    
    local current_alpha_intensity = lerp_func(default_alpha, override_alpha, di_anim.ovr_state)
    local final_alpha = current_alpha_intensity * di_anim.alpha

    renderer.text(di_cx + 4, di_cy + 4, 255, 255, 255, final_alpha, "-", 0, text_str)
end

local function di_on_paint_ui()
    di_scr_w, di_scr_h = client.screen_size()
    di_cx, di_cy = di_scr_w / 2, di_scr_h / 2
end

-- ════════════════════════════════════════════════════════════════════════════════
-- MISC FEATURES (FROM SCRIPT 3)
-- ════════════════════════════════════════════════════════════════════════════════

-- ═══ 1. CUSTOM WEAPON SOUNDS ═══
local cws_data = {
    previous_ammo = 0,
    previous_fire = 0,
    was_enabled = false
}

local function restore_weapon_sounds()
    cvar_snd_setmixer:invoke_callback("Weapons1", "vol", "0.7")
    cvar_snd_setmixer:invoke_callback("FoleyWeapons", "vol", "0.7")
    cvar_snd_setmixer:invoke_callback("AllWeapons", "vol", "1.0")
    cvar_snd_setmixer:invoke_callback("DistWeapons", "vol", "0.7")
    cvar_snd_setmixer:invoke_callback("WeaponReload", "vol", "0.7")
end

local function play_custom_sound()
    local is_enabled = menu.misc.cws_enable:get()
    
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
    if not menu.misc.cws_enable:get() then return end
    
    local ICvar = client.create_interface("vstdlib.dll", "VEngineCvar007")
    local findVar = ffi.cast("void*(__thiscall*)(void*, const char*)", ffi.cast("void***", ICvar)[0][15])
    local sv_cheats = ffi.cast("ConVar*", findVar(ICvar, "sv_cheats"))
    
    sv_cheats.m_nFlags = bit.band(sv_cheats.m_nFlags, bit.bnot(0x8000))
    sv_cheats.m_nValue = 1
    sv_cheats.m_fValue = 1.0
end

-- ═══ 2. ENEMY TEAM CHAT REVEALER ═══
local game_state_api = panorama.open().GameStateAPI
local last_location_time = {}

local function on_player_say(event)
    if not menu.enable:get() or not menu.misc.etc_enable:get() then return end
    
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
    if not menu.enable:get() or not menu.misc.etc_enable:get() then return end
    
    local entity_index = event.entity
    if not entity_index or not entity.is_enemy(entity_index) then return end
    last_location_time[entity_index] = globals.realtime()
end

-- ═══ 3. MAGNET MELEE ═══
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
    if not menu.enable:get() or not menu.misc.mm_enable:get() then return end
    
    local local_player = entity.get_local_player()
    local local_weapon = entity.get_player_weapon(local_player)

    if local_weapon then
        local eye_pos = vector(client.eye_position())
        local closest_enemy, closest_pos = find_closest_enemy(eye_pos)

        if closest_enemy then
            local fraction, hit_entity = client.trace_line(local_player, eye_pos.x, eye_pos.y, eye_pos.z, closest_pos.x, closest_pos.y, closest_pos.z)

            if fraction >= 1 or hit_entity == closest_enemy then
                local pitch, yaw = eye_pos:to(closest_pos):angles()
                
                local selected = menu.misc.mm_options:get()

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

-- ═══ 4. FAST RECHARGE ═══
local recharge_state = {
    last_tick = globals.tickcount(),
    interval = 14
}

local function handle_fast_recharge(cmd)
    if not menu.enable:get() or not menu.misc.fr_enable:get() then return end

    local lp = entity.get_local_player()
    if not lp or not entity.is_alive(lp) then return end

    local dt_on = ui.get(ref.double_tap[1]) and ui.get(ref.double_tap[2]) and not ui.get(ref.fakeduck)
    local hs_on = ui.get(ref.onshot_aa[1]) and ui.get(ref.onshot_aa[2]) and not ui.get(ref.fakeduck)

    local weapon = entity.get_player_weapon(lp)
    if not weapon then
        ui.set(ref.rage_enable[2], "Always on")
        return
    end

    recharge_state.interval = csgo_weapons(weapon).is_revolver and 17 or 14

    if dt_on or hs_on then
        if globals.tickcount() >= recharge_state.last_tick + recharge_state.interval then
            ui.set(ref.rage_enable[2], "Always on")
        else
            ui.set(ref.rage_enable[2], "On hotkey")
        end
    else
        recharge_state.last_tick = globals.tickcount()
        ui.set(ref.rage_enable[2], "Always on")
    end
end

-- ═══ 5. PING SPIKE ═══
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

local ping_presets = {
    ["Off"] = 5,
    ["Low"] = 60,
    ["Medium"] = 120,
    ["High"] = 200
}

local function apply_ping(value)
    if value < 200 then
        pcall(function() ui.set(ref.max_unlag, 200) end)
        sv_maxunlag:set_float(0.200)
    else 
        pcall(function() ui.set(ref.max_unlag, value) end)
        sv_maxunlag:set_float(value / 1000)
    end
    
    if ps_ptr and ps_initialized then
        ps_ptr[0] = value
    end
end

local function update_ping_settings()
    if not menu.enable:get() then return end
    
    local mode = menu.misc.ps_mode:get()
    local is_custom = mode == "Customizable"
    
    if mode == "Off" then
        apply_ping(5)
    elseif is_custom then
        apply_ping(menu.misc.ps_custom:get())
    else
        local preset_value = ping_presets[mode]
        if preset_value then apply_ping(preset_value) end
    end
end

-- ═══ 6. UNHIDE CVARS ═══
local function update_unhide_visibility()
    if not menu.enable:get() then return end
    
    local show = menu.misc.uc_enable:get()

    if ref.custom_events then
        ui.set_visible(ref.custom_events, true)
        if show then ui.set(ref.custom_events, true) end
    end

    if ref.max_unlag then ui.set_visible(ref.max_unlag, show) end
    if ref.max_ticks then ui.set_visible(ref.max_ticks, show) end
    if ref.clock_corr then ui.set_visible(ref.clock_corr, show) end
    if ref.hold_aim then ui.set_visible(ref.hold_aim, show) end
end

-- ═══ 7. WORLD SOUND ═══
local mixers_list = {
    "Footsteps",
    "Weapons",
    "Reload Sounds",
    "Bomb Sounds",
    "Ambient & Effects",
    "Music & Radio",
}

local mixers_names = {
    ["Footsteps"] = { 
        ["GlobalFootsteps"] = 1.00, 
        ["PlayerFootsteps"] = 0.13 
    },
    ["Weapons"] = { 
        ["Weapons1"] = 0.70,
        ["AllWeapons"] = 1.00, 
        ["DistWeapons"] = 0.70
    },
    ["Reload Sounds"] = { 
        ["WeaponReload"] = 0.70,
        ["FoleyWeapons"] = 0.70
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

-- Create sliders AFTER ws_enable checkbox
for i=1, #mixers_list do
    local mixer = mixers_list[i]
    menu.misc.ws_modifier[mixer] = groups.main:slider(mixer .. " volume", 0, 1000, 100, true, "%", 1, {[0] = "Muted"})
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
    if not menu.enable:get() or not menu.misc.ws_enable:get() then return end
    
    local mixers = mixer_name ~= nil and {mixer_name} or mixers_list

    disable_console_output(function()
        for i=1, #mixers do
            local mixer = mixers[i]
            local mixer_data = mixers_names[mixer]
            local current_value = menu.misc.ws_modifier[mixer]:get()
            local modifier = current_value * 0.01

            for mixer_current_name, mixer_default_volume in pairs(mixer_data) do
                cvar_snd_setmixer:invoke_callback(mixer_current_name, "vol", tostring(mixer_default_volume * modifier))
            end
        end
    end)
end

local function restore_all_sounds()
    disable_console_output(function()
        for mixer_name, default_vol in pairs(ws_default_values) do
            cvar_snd_setmixer:invoke_callback(mixer_name, "vol", tostring(default_vol))
        end
    end)
end

-- ═══ 8. CUSTOM ANIMATIONS ═══
local entity_list_ptr = ffi.typeof('void***')
local i_client_entity_list = client.create_interface('client.dll', 'VClientEntityList003')
local raw_ientitylist = ffi.cast(entity_list_ptr, i_client_entity_list)
local get_client_entity = ffi.cast('void*(__thiscall*)(void*, int)', raw_ientitylist[0][3])

local ca_globals = {
    in_speed = false,
    landing = false
}

local function apply_custom_animations(player_entity)
    if not menu.enable:get() or not menu.misc.ca_enable:get() then return end
    
    local raw_player = get_client_entity(raw_ientitylist, player_entity)
    local player_ptr = ffi.cast(ffi.typeof('void***'), raw_player)
    local animstate_ptr = ffi.cast("char*", player_ptr) + 0x9960
    local animstate = ffi.cast("struct animstate_t1**", animstate_ptr)[0]
    
    if raw_player == nil or animstate == nil then return end
    
    local selected_anims = menu.misc.ca_options:get()
    
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

-- ════════════════════════════════════════════════════════════════════════════════
-- RAGE FEATURES (NEW TAB 5)
-- ════════════════════════════════════════════════════════════════════════════════

-- ═══ AIRSTOP HC ═══
local air_prediction_data = { flags = 0, velocity = vector() }
local air_prev_strafe = nil
local air_hc_original = nil
local air_hc_overridden = nil

local function air_restore_strafe()
    if air_prev_strafe ~= nil then
        ui.set(ref.air_strafe, air_prev_strafe)
        air_prev_strafe = nil
    end
end

local function air_restore_hc()
    if air_hc_original ~= nil then
        local prev_wpn_type = ui.get(ref.weapon_type)
        ui.set(ref.weapon_type, "SSG 08")
        ui.set(ref.hitchance, air_hc_original)
        ui.set(ref.weapon_type, prev_wpn_type)
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
        air_prev_strafe = ui.get(ref.air_strafe)
    end

    ui.set(ref.air_strafe, false)
    cmd.in_speed = 1
    cmd.forwardmove = negative_direction.x
    cmd.sidemove = negative_direction.y
end

local function is_air_active()
    return menu.enable:get() and menu.rage.air_enable:get() and menu.rage.air_hotkey:get_hotkey()
end

local function is_air_hc_active()
    return menu.enable:get() and menu.rage.air_enable:get() and menu.rage.air_hc_enable:get() and menu.rage.air_hc_hotkey:get_hotkey()
end

-- ═══ LC BREAKER ═══
local lc_last_toggle_time = 0
local lc_toggle_interval = 0
local lc_current_mode_index = 0
local lc_modes = {"Toggle", "On hotkey", "Off"}
local lc_local_player = nil
local lc_dt_charged = false

local function toticks_rage(t)
    return math.floor(t / globals.tickinterval())
end

local function lc_check_charge()
    if not lc_local_player then return end
    local m_nTickBase = entity.get_prop(lc_local_player, 'm_nTickBase')
    local client_latency = client.latency()
    local shift = math.floor(m_nTickBase - globals.tickcount() - 3 - toticks_rage(client_latency) * .5 + .5 * (client_latency * 10))
    local wanted = -14 + (ui.get(ref.dt_limit) - 1) + 3
    lc_dt_charged = shift <= wanted
end

local function lc_is_self_peekable()
    local me = entity.get_local_player()
    if not me or not entity.is_alive(me) then return false end
    
    local enemies = entity.get_players(true)
    local my_velocity = { entity.get_prop(me, "m_vecVelocity") }
    local my_origin = { entity.get_prop(me, "m_vecOrigin") }
    local tick_interval = globals.tickinterval()
    local predicted_ticks = menu.rage.lc_ticks:get()
    
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

-- ═══ QUICK RETREAT ═══
local qr_valid_weapons = {
    [40] = true,
    [9]  = true
}
local qr_vars = {
    active = false,
    switch_tick = 0,
    last_weapon_cmd = nil
}

local function qr_get_weapon_idx(ent)
    if not ent then return nil end
    local idx = entity.get_prop(ent, "m_iItemDefinitionIndex")
    if not idx then return nil end
    return bit.band(idx, 0xFFFF)
end

local function qr_is_option_active(opt_name)
    local opts = menu.rage.qr_logic:get()
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

-- ═══ RESOLVER ═══
local player_data_resolver = {}

local function init_player_resolver(idx)
    if not player_data_resolver[idx] then
        player_data_resolver[idx] = {
            misses = 0,
            eye_angles = {},
            angle_index = 0,
            last_jitter_detect = 0,
            jitter_confidence = 0,
            body_updates = {},
            eye_deltas = {},
            feet_deltas = {},
            layer_data = {},
            layer_history = {},
            lby_timer = 0,
            lby_next_update = 0,
            standing_time = 0,
            last_velocity = 999,
            last_ground_yaw = 0,
            simtime = 0,
            old_simtime = 0,
            calculated_max_desync = 58,
            desync_delta = 0,
            moving_desync = 0,
            static_desync = 0
        }
    end
    return player_data_resolver[idx]
end

-- Perfect Desync Calculation
local function calculate_perfect_desync(state, velocity, duck_amount)
    if not state then return 58, 58 end
    
    local running = math.max(0, math.min(1, state.m_flRunningSpeed))
    local ducking = math.max(0, math.min(1, state.m_flDuckingSpeed))
    local duck_amt = math.max(0, math.min(1, duck_amount or state.m_fDuckAmount))
    local move_weight = state.m_flMoveWeight or 0
    
    local speed_portion = math.max(0, math.min(1, running))
    local walk_run_transition = state.m_flStrafingAccelProgress or 0
    
    local unk1 = ((walk_run_transition * -0.3) - 0.2) * speed_portion
    local unk2 = unk1 + 1.0
    
    if duck_amt > 0 then
        local duck_speed = speed_portion * duck_amt
        unk2 = unk2 + (duck_speed * (0.5 - unk2))
    end
    
    local modifier = math.max(0.5, math.min(1.0, unk2))
    local max_body = state.m_flMaxBodyYaw or 58
    if max_body < 10 then max_body = 58 end
    
    local moving_desync = max_body * modifier
    local static_desync = max_body
    
    if velocity > 0.1 then
        local speed_factor = math.min(1.0, velocity / 250.0)
        moving_desync = moving_desync * (1.0 - (speed_factor * 0.15))
    end
    
    return moving_desync, static_desync
end

-- Wraith Jitter Detection
local function wraith_jitter_detect(idx, data, state)
    if not state then return false, 0, 0 end
    
    local eye_yaw = state.m_flEyeYaw
    local feet_yaw = state.m_flGoalFeetYaw
    
    data.angle_index = data.angle_index + 1
    local slot = (data.angle_index - 1) % 8
    
    data.eye_angles[slot] = {
        eye = eye_yaw,
        feet = feet_yaw,
        time = globals.curtime()
    }
    
    if data.angle_index < 6 then
        return false, 0, 0
    end
    
    local deltas = {}
    local max_delta = 0
    
    for i = 0, 6 do
        local curr_slot = (data.angle_index - 1 - i) % 8
        local prev_slot = (data.angle_index - 2 - i) % 8
        
        local curr = data.eye_angles[curr_slot]
        local prev = data.eye_angles[prev_slot]
        
        if curr and prev then
            local delta = math.abs(normalize(curr.eye - prev.eye))
            table.insert(deltas, delta)
            max_delta = math.max(max_delta, delta)
        end
    end
    
    if #deltas == 0 then return false, 0, 0 end
    
    local sum = 0
    for _, d in ipairs(deltas) do
        sum = sum + d
    end
    local avg_delta = sum / #deltas
    
    local variance = 0
    for _, d in ipairs(deltas) do
        variance = variance + math.pow(d - avg_delta, 2)
    end
    variance = variance / #deltas
    
    local threshold = 35.0 * math.min(1.5, data.calculated_max_desync / 58.0)
    local is_jitter = (avg_delta > threshold) or (variance > 400)
    
    if is_jitter then
        data.jitter_confidence = math.min(5, data.jitter_confidence + 1)
    else
        data.jitter_confidence = math.max(0, data.jitter_confidence - 1)
    end
    
    if data.jitter_confidence >= 2 then
        local sin_sum, cos_sum = 0, 0
        local count = 0
        
        for i = 0, 7 do
            local angle_data = data.eye_angles[i]
            if angle_data then
                sin_sum = sin_sum + math.sin(math.rad(angle_data.eye))
                cos_sum = cos_sum + math.cos(math.rad(angle_data.eye))
                count = count + 1
            end
        end
        
        if count >= 4 then
            local mean_yaw = math.deg(math.atan2(sin_sum / count, cos_sum / count))
            local current_diff = normalize(state.m_flEyeYaw - mean_yaw)
            local feet_diff = normalize(state.m_flEyeYaw - state.m_flGoalFeetYaw)
            
            local side = 0
            
            if math.abs(current_diff) > 3 then
                side = current_diff > 0 and -1 or 1
            elseif math.abs(feet_diff) > 35 then
                side = feet_diff > 0 and -1 or 1
            else
                local last_two = normalize(data.eye_angles[(data.angle_index - 1) % 8].eye - data.eye_angles[(data.angle_index - 2) % 8].eye)
                side = last_two > 0 and 1 or -1
            end
            
            return true, side, data.jitter_confidence
        end
    end
    
    return false, 0, 0
end

-- Metaset Desync Detection
local function metaset_desync_detect(idx, data, state)
    if not state then return 0, 0 end
    
    local eye_yaw = state.m_flEyeYaw
    local feet_yaw = state.m_flGoalFeetYaw
    local body_prop = entity.get_prop(idx, "m_flPoseParameter", 11)
    
    if not body_prop then return 0, 0 end
    
    local body_yaw = body_prop * 120 - 60
    
    table.insert(data.body_updates, 1, {
        body = body_yaw,
        eye = eye_yaw,
        feet = feet_yaw,
        time = globals.curtime()
    })
    
    if #data.body_updates > 10 then
        table.remove(data.body_updates)
    end
    
    local eye_feet_delta = normalize(eye_yaw - feet_yaw)
    local eye_body_delta = normalize(eye_yaw - body_yaw)
    
    table.insert(data.eye_deltas, 1, eye_feet_delta)
    table.insert(data.feet_deltas, 1, eye_body_delta)
    
    if #data.eye_deltas > 5 then table.remove(data.eye_deltas) end
    if #data.feet_deltas > 5 then table.remove(data.feet_deltas) end
    
    local votes = {left = 0, right = 0}
    local confidence = 0
    
    if math.abs(eye_feet_delta) > 35 then
        if eye_feet_delta > 0 then
            votes.left = votes.left + 3
        else
            votes.right = votes.right + 3
        end
        confidence = confidence + 3
    end
    
    if #data.body_updates >= 3 then
        local body_sum = 0
        for i = 1, math.min(3, #data.body_updates) do
            body_sum = body_sum + data.body_updates[i].body
        end
        local body_avg = body_sum / math.min(3, #data.body_updates)
        
        if math.abs(body_avg) > 15 then
            if body_avg > 0 then
                votes.right = votes.right + 2
            else
                votes.left = votes.left + 2
            end
            confidence = confidence + 2
        end
    end
    
    if #data.eye_deltas >= 3 then
        local consistent = true
        local first_sign = data.eye_deltas[1] > 0
        
        for i = 2, #data.eye_deltas do
            if (data.eye_deltas[i] > 0) ~= first_sign then
                consistent = false
                break
            end
        end
        
        if consistent and math.abs(data.eye_deltas[1]) > 20 then
            if data.eye_deltas[1] > 0 then
                votes.left = votes.left + 1
            else
                votes.right = votes.right + 1
            end
            confidence = confidence + 1
        end
    end
    
    local side = 0
    if votes.left > votes.right and votes.left >= 3 then
        side = -1
    elseif votes.right > votes.left and votes.right >= 3 then
        side = 1
    end
    
    return side, confidence
end

-- Layer Analysis
local function analyze_all_layers(idx, data)
    table.insert(data.layer_history, 1, data.layer_data)
    if #data.layer_history > 3 then
        table.remove(data.layer_history)
    end
    
    data.layer_data = {}
    
    for i = 0, 12 do
        local layer = get_layer(idx, i)
        if layer then
            data.layer_data[i] = {
                seq = layer.m_nSequence,
                cycle = layer.m_flCycle,
                prev_cycle = layer.m_flPrevCycle,
                weight = layer.m_flWeight,
                delta = layer.m_flWeightDeltaRate,
                rate = layer.m_flPlaybackRate
            }
        end
    end
    
    local side = 0
    local method = ""
    local conf = 0
    
    if data.layer_data[3] then
        local l3 = data.layer_data[3]
        
        if l3.seq == 979 then
            return "lby_break", 0, 10
        end
        
        if l3.weight > 0.5 and #data.layer_history > 0 then
            local old_l3 = data.layer_history[1][3]
            if old_l3 then
                local cycle_delta = l3.cycle - old_l3.cycle
                
                if math.abs(cycle_delta) > 0.015 then
                    side = cycle_delta > 0 and 1 or -1
                    conf = conf + 3
                    method = "layer3"
                end
            end
        end
    end
    
    if data.layer_data[6] then
        local l6 = data.layer_data[6]
        
        if l6.weight > 0.4 and #data.layer_history > 0 then
            local old_l6 = data.layer_history[1][6]
            if old_l6 then
                local cycle_delta = l6.cycle - old_l6.cycle
                local rate_change = math.abs(l6.rate - old_l6.rate)
                
                if math.abs(cycle_delta) > 0.01 then
                    local detected = cycle_delta > 0 and 1 or -1
                    
                    if side == 0 then
                        side = detected
                        conf = conf + 2
                    elseif side == detected then
                        conf = conf + 2
                    end
                    
                    if method == "" then method = "layer6" end
                end
                
                if rate_change > 0.1 then
                    conf = conf + 1
                end
            end
        end
    end
    
    if data.layer_data[11] then
        local l11 = data.layer_data[11]
        
        if l11.weight > 0.2 and #data.layer_history > 0 then
            local old_l11 = data.layer_history[1][11]
            if old_l11 then
                local weight_change = l11.weight - old_l11.weight
                
                if math.abs(weight_change) > 0.05 then
                    local detected = weight_change > 0 and 1 or -1
                    
                    if side == 0 then
                        side = detected
                        conf = conf + 1
                    elseif side == detected then
                        conf = conf + 1
                    end
                    
                    if method == "" then method = "layer11" end
                end
            end
        end
    end
    
    if data.layer_data[12] then
        local l12 = data.layer_data[12]
        
        if l12.weight > 0.2 and #data.layer_history > 0 then
            local old_l12 = data.layer_history[1][12]
            if old_l12 then
                local weight_change = l12.weight - old_l12.weight
                
                if math.abs(weight_change) > 0.08 then
                    local detected = weight_change > 0 and 1 or -1
                    
                    if side == detected or side == 0 then
                        if side == 0 then side = detected end
                        conf = conf + 1
                    end
                    
                    if method == "" then method = "layer12" end
                end
            end
        end
    end
    
    if conf >= 2 then
        return method, side, conf
    end
    
    return nil, 0, 0
end

-- LBY Timing
local function perfect_lby_timing(idx, data, state)
    if not state then return false, 0 end
    
    local vx, vy = entity.get_prop(idx, "m_vecVelocity")
    local velocity = math.sqrt(vx*vx + vy*vy)
    local on_ground = bit.band(entity.get_prop(idx, "m_fFlags"), 1) == 1
    local curtime = globals.curtime()
    
    local was_moving = data.last_velocity > 5
    local is_moving = velocity > 5
    
    data.last_velocity = velocity
    
    if was_moving and not is_moving and on_ground then
        data.standing_time = curtime
        data.lby_timer = curtime
        data.lby_next_update = curtime + 0.22
    end
    
    if not was_moving and is_moving then
        data.standing_time = 0
        data.lby_timer = 0
        data.lby_next_update = 0
        return false, 0
    end
    
    if not is_moving and on_ground and data.standing_time > 0 then
        local standing_duration = curtime - data.standing_time
        
        if standing_duration >= 0.22 then
            local body = entity.get_prop(idx, "m_flPoseParameter", 11)
            if body then
                local body_yaw = body * 120 - 60
                
                if math.abs(body_yaw) > 35 then
                    local time_since_last = curtime - data.lby_timer
                    
                    if time_since_last >= 1.05 then
                        data.lby_timer = curtime
                        data.lby_next_update = curtime + 1.1
                        return true, body_yaw
                    elseif standing_duration < 0.3 then
                        return true, body_yaw
                    end
                end
            end
        end
    end
    
    return false, 0
end

-- Main Resolver
local function resolve(idx)
    if not entity.is_alive(idx) or entity.is_dormant(idx) then
        return
    end
    
    local data = init_player_resolver(idx)
    local state = get_animstate(idx)
    
    if not state then return end
    
    data.old_simtime = data.simtime
    data.simtime = entity.get_prop(idx, "m_flSimulationTime")
    
    local vx, vy = entity.get_prop(idx, "m_vecVelocity")
    local velocity = math.sqrt(vx*vx + vy*vy)
    local duck = entity.get_prop(idx, "m_fDuckAmount") or 0
    
    local moving_desync, static_desync = calculate_perfect_desync(state, velocity, duck)
    data.calculated_max_desync = moving_desync
    data.moving_desync = moving_desync
    data.static_desync = static_desync
    
    local yaw = nil
    local method = ""
    
    -- Priority 1: Wraith Jitter
    local is_jitter, jitter_side, jitter_conf = wraith_jitter_detect(idx, data, state)
    if is_jitter and jitter_side ~= 0 and jitter_conf >= 2 then
        yaw = jitter_side * moving_desync
        method = "jitter"
    end
    
    -- Priority 2: LBY Timing
    if not yaw then
        local has_lby, lby_yaw = perfect_lby_timing(idx, data, state)
        if has_lby then
            yaw = lby_yaw
            method = "lby"
        end
    end
    
    -- Priority 3: Layer Analysis
    if not yaw then
        local layer_method, layer_side, layer_conf = analyze_all_layers(idx, data)
        
        if layer_method == "lby_break" then
            local body = entity.get_prop(idx, "m_flPoseParameter", 11)
            if body then
                yaw = body * 120 - 60
                method = "lby_break"
            end
        elseif layer_method and layer_side ~= 0 and layer_conf >= 2 then
            yaw = layer_side * moving_desync
            method = layer_method
        end
    end
    
    -- Priority 4: Metaset Desync
    if not yaw then
        local desync_side, desync_conf = metaset_desync_detect(idx, data, state)
        
        if desync_side ~= 0 and desync_conf >= 3 then
            local desync_amount = velocity < 5 and static_desync or moving_desync
            yaw = desync_side * desync_amount
            method = "desync"
        end
    end
    
    -- Priority 5: Freestanding
    if not yaw then
        local lp = entity.get_local_player()
        if lp then
            local lp_x, lp_y, lp_z = entity.get_prop(lp, "m_vecOrigin")
            local en_x, en_y, en_z = entity.get_prop(idx, "m_vecOrigin")
            
            if lp_x and en_x then
                local yaw_angle = math.deg(math.atan2(en_y - lp_y, en_x - lp_x))
                
                local left_x = en_x + math.cos(math.rad(yaw_angle + 90)) * 40
                local left_y = en_y + math.sin(math.rad(yaw_angle + 90)) * 40
                local right_x = en_x + math.cos(math.rad(yaw_angle - 90)) * 40
                local right_y = en_y + math.sin(math.rad(yaw_angle - 90)) * 40
                
                local left = client.trace_line(idx, en_x, en_y, en_z + 64, left_x, left_y, en_z + 64)
                local right = client.trace_line(idx, en_x, en_y, en_z + 64, right_x, right_y, en_z + 64)
                
                if left and right and math.abs(left - right) > 0.15 then
                    local fs_side = left > right and 1 or -1
                    yaw = fs_side * moving_desync
                    method = "freestand"
                end
            end
        end
    end
    
    -- Fallback: Body yaw
    if not yaw then
        local body = entity.get_prop(idx, "m_flPoseParameter", 11)
        if body then
            yaw = body * 120 - 60
            method = "body"
        end
    end
    
    -- Apply
    if yaw then
        plist.set(idx, "Force body yaw", true)
        plist.set(idx, "Force body yaw value", math.floor(yaw))
        
        local on_ground = bit.band(entity.get_prop(idx, "m_fFlags"), 1) == 1
        if on_ground then
            data.last_ground_yaw = yaw
        end
    else
        plist.set(idx, "Force body yaw", false)
    end
end

-- Body Aim Handler
local function handle_baim(idx)
    local data = player_data_resolver[idx]
    if not data then return end
    
    local hp = entity.get_prop(idx, "m_iHealth")
    if not hp or hp <= 0 then return end
    
    local selected = menu.rage.res_baim_multi:get()
    
    if selected then
        for _, item in ipairs(selected) do
            if item == "HP lower than X value" then
                if hp <= menu.rage.res_baim_hp:get() then
                    plist.set(idx, "Override prefer body aim", "Force")
                else
                    plist.set(idx, "Override prefer body aim", "-")
                end
            end
        end
    else
        plist.set(idx, "Override prefer body aim", "-")
    end
end

-- Safepoint Handler
local function handle_safe(idx)
    local data = player_data_resolver[idx]
    if not data then return end
    
    local hp = entity.get_prop(idx, "m_iHealth")
    if not hp or hp <= 0 then return end
    
    local selected = menu.rage.res_safe_multi:get()
    local should_safe = false
    
    if selected then
        for _, item in ipairs(selected) do
            if item == "HP lower than X value" then
                if hp <= menu.rage.res_safe_hp:get() then
                    should_safe = true
                end
            end
            
            if item == "After X misses" then
                if data.misses >= menu.rage.res_safe_miss:get() then
                    should_safe = true
                end
            end
        end
    end
    
    plist.set(idx, "Override safe point", should_safe and "On" or "-")
end

local function on_miss_resolver(e)
    local target = e.target
    if not target then return end
    
    local data = init_player_resolver(target)
    data.misses = data.misses + 1
end

local function on_hit_resolver(e)
    local target = e.target
    if not target then return end
    
    local data = player_data_resolver[target]
    if data then
        data.misses = 0
    end
end

local function on_death_resolver(e)
    local victim = client.userid_to_entindex(e.userid)
    if victim then
        player_data_resolver[victim] = nil
    end
end

local function reset_all_resolver()
    for i = 1, 64 do
        player_data_resolver[i] = nil
        plist.set(i, "Force body yaw", false)
        plist.set(i, "Override prefer body aim", "-")
        plist.set(i, "Override safe point", "-")
    end
end

-- ════════════════════════════════════════════════════════════════════════════════
-- RESET FUNCTION
-- ════════════════════════════════════════════════════════════════════════════════
local function reset_everything_to_default()
    restore_weapon_sounds()
    cws_data.was_enabled = false
    
    if ps_ptr and ps_initialized then ps_ptr[0] = 5 end
    sv_maxunlag:set_float(0.005)
    pcall(function() ui.set(ref.max_unlag, 5) end)
    
    if ref.max_unlag then ui.set_visible(ref.max_unlag, false) end
    if ref.max_ticks then ui.set_visible(ref.max_ticks, false) end
    if ref.clock_corr then ui.set_visible(ref.clock_corr, false) end
    if ref.hold_aim then ui.set_visible(ref.hold_aim, false) end
    
    restore_all_sounds()
    air_restore_strafe()
    air_restore_hc()
    reset_all_resolver()
    
    client.log("All settings restored to default")
end

-- ════════════════════════════════════════════════════════════════════════════════
-- MENU SETUP (ANTI-AIM BUILDER)
-- ════════════════════════════════════════════════════════════════════════════════
local handles = {}

handles.setupmenu = function()
    for i = 1, #states do
        menu.antiaim.builder[i] = {}
        
        if i == 1 then
            menu.antiaim.builder[i].enable_global = groups.main:checkbox("\v" .. states[i] .. " · \rEnable Global")
        else
            menu.antiaim.builder[i].override = groups.main:checkbox("\v" .. states[i] .. " · \rOverride ")
        end
        
        menu.antiaim.builder[i].pitch = groups.main:combobox("\v" .. states[i] .. " · \rpitch \v", {"disabled", "down", "up", "zero", "custom"})
        menu.antiaim.builder[i].pitch_custom = groups.main:slider("\v" .. states[i] .. " · \rpitch value \v", -89, 89, 0, true, "°", 1)
        
        menu.antiaim.builder[i].yaw = groups.main:combobox("\v" .. states[i] .. " · \ryaw \v ", {"disabled", "backward", "left/right"})
        menu.antiaim.builder[i].yaw_value = groups.main:slider("\n\n\n\n\n\n\n\n", -180, 180, 0)
        menu.antiaim.builder[i].classic1 = groups.main:slider("\v" .. states[i] .. " · \r[l|r] \v ", -180, 180, 0)
        menu.antiaim.builder[i].classic2 = groups.main:slider("\n\n\n\n\n\n\n\n\n", -180, 180, 0)
        
        menu.antiaim.builder[i].modifier = groups.main:combobox("\v" .. states[i] .. " · \rmodifier \v ", {
            "off", "jitter", "random", "skitter", "center (skeet)", "offset (skeet)"
        })
        menu.antiaim.builder[i].mod_slider = groups.main:slider("\n\n\n\n\n\n\n\n\n\n", 0, 90, 0, true, "°", 1)
        
        menu.antiaim.builder[i].delay_ticks = groups.main:slider("\v" .. states[i] .. " · \rdelay ticks \v ", 2, 17, 2, true, "t", 1)
        
        menu.antiaim.builder[i].bodyyaw = groups.main:combobox("\v" .. states[i] .. " · \rbodyyaw \v ", {
            "off", "jitter", "left", "right", "delayed", "break", "jitter (skeet)"
        })
        menu.antiaim.builder[i].delay = groups.main:slider("\v" .. states[i] .. " · \rdelay \v ", 2, 64, 0, true, "t", 1)
        
        menu.antiaim.builder[i].defensive = groups.main:combobox("\v" .. states[i] .. " · \rdefensive \v ", {"-", "on peek", "always on"})
        
        menu.antiaim.builder[i].defensive_pitch = groups.main:combobox("\v" .. states[i] .. " · \rdefensive pitch \v ", {
            "disabled", "static", "jitter", "random", "spin"
        })
        menu.antiaim.builder[i].defensive_pitch_ang = groups.main:slider("\n\n\n\n\n\n\n\n\n\n\n", -89, 89, -89, true, "°", 1)
        menu.antiaim.builder[i].defensive_pitch_ang2 = groups.main:slider("\n\n\n\n\n\n\n\n\n\n\n\n", -89, 89, -89, true, "°", 1)
        menu.antiaim.builder[i].defensive_pitch_speed = groups.main:slider("\n\n\n\n\n\n\n\n\n\n\n\n\n", -50, 50, 20, true, "", 0.1)
        
        menu.antiaim.builder[i].defensive_yaw = groups.main:combobox("\v" .. states[i] .. " · \rdefensive yaw \v ", {
            "disabled", "static", "jitter", "sideways", "random", "spin", "move-based", "spin jitter"
        })
        menu.antiaim.builder[i].defensive_spin = groups.main:slider("\n\n\n\n\n\n\n\n\n\n\n\n\n\n", -60, 60, 0, true, "°", 1)
        menu.antiaim.builder[i].defensive_yaw_val = groups.main:slider("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n", -180, 180, 0, true, "°", 1)
        menu.antiaim.builder[i].defensive_yaw_val2 = groups.main:slider("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n", -180, 180, 0, true, "°", 1)
        
        menu.antiaim.builder[i].defensive_yaw_sj_angle_label = groups.main:label("\v" .. states[i] .. " · \rspin angle")
        menu.antiaim.builder[i].defensive_yaw_sj_angle = groups.main:slider("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n", 0, 360, 180, true, "°", 1)
        
        menu.antiaim.builder[i].defensive_yaw_sj_delay_label = groups.main:label("\v" .. states[i] .. " · \rjitter delay")
        menu.antiaim.builder[i].defensive_yaw_sj_delay = groups.main:slider("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n", 0, 14, 0, true, "t", 1)
        
        menu.antiaim.builder[i].defensive_yaw_sj_speed_label = groups.main:label("\v" .. states[i] .. " · \rspin speed")
        menu.antiaim.builder[i].defensive_yaw_sj_speed = groups.main:slider("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n", -50, 50, 20, true, "", 0.1)
    end
    
    -- Dependencies setup (بخش های مربوط به depend را هم دقیق میزنیم)
    for i = 1, #states do
        local base_conditions = {
            {menu.enable, true}, 
            {menu.tab, "anti-aim"},
            {menu.antiaim.condition, states[i]}
        }
        
        if i == 1 then
            menu.antiaim.builder[i].enable_global:depend({menu.enable, true}, {menu.tab, "anti-aim"}, {menu.antiaim.condition, states[i]})
            
            local override_condition = {{menu.antiaim.builder[i].enable_global, true}}
            
            local function merge_conditions(extra)
                local result = {}
                for _, v in ipairs(base_conditions) do table.insert(result, v) end
                for _, v in ipairs(override_condition) do table.insert(result, v) end
                if extra then
                    for _, v in ipairs(extra) do table.insert(result, v) end
                end
                return result
            end
            
            menu.antiaim.builder[i].pitch:depend(unpack(merge_conditions()))
            menu.antiaim.builder[i].pitch_custom:depend(unpack(merge_conditions({{menu.antiaim.builder[i].pitch, "custom"}})))
            
            menu.antiaim.builder[i].yaw:depend(unpack(merge_conditions()))
            menu.antiaim.builder[i].yaw_value:depend(unpack(merge_conditions({{menu.antiaim.builder[i].yaw, "backward"}})))
            menu.antiaim.builder[i].classic1:depend(unpack(merge_conditions({{menu.antiaim.builder[i].yaw, "left/right"}})))
            menu.antiaim.builder[i].classic2:depend(unpack(merge_conditions({{menu.antiaim.builder[i].yaw, "left/right"}})))
            
            menu.antiaim.builder[i].modifier:depend(unpack(merge_conditions()))
            menu.antiaim.builder[i].mod_slider:depend(unpack(merge_conditions({{menu.antiaim.builder[i].modifier, "off", true}})))
            menu.antiaim.builder[i].delay_ticks:depend(unpack(merge_conditions({{menu.antiaim.builder[i].modifier, "jitter"}})))
            
            menu.antiaim.builder[i].bodyyaw:depend(unpack(merge_conditions({{menu.antiaim.builder[i].modifier, "jitter", true}})))
            menu.antiaim.builder[i].delay:depend(unpack(merge_conditions({{menu.antiaim.builder[i].bodyyaw, "delayed", "break"}})))
            
            menu.antiaim.builder[i].defensive:depend(unpack(merge_conditions()))
            menu.antiaim.builder[i].defensive_pitch:depend(unpack(merge_conditions({{menu.antiaim.builder[i].defensive, "on peek", "always on"}})))
            menu.antiaim.builder[i].defensive_pitch_ang:depend(unpack(merge_conditions({
                {menu.antiaim.builder[i].defensive, "on peek", "always on"}, 
                {menu.antiaim.builder[i].defensive_pitch, "static", "jitter", "random", "spin"}
            })))
            menu.antiaim.builder[i].defensive_pitch_ang2:depend(unpack(merge_conditions({
                {menu.antiaim.builder[i].defensive, "on peek", "always on"}, 
                {menu.antiaim.builder[i].defensive_pitch, "jitter", "random", "spin"}
            })))
            menu.antiaim.builder[i].defensive_pitch_speed:depend(unpack(merge_conditions({
                {menu.antiaim.builder[i].defensive, "on peek", "always on"}, 
                {menu.antiaim.builder[i].defensive_pitch, "spin"}
            })))
            
            menu.antiaim.builder[i].defensive_yaw:depend(unpack(merge_conditions({{menu.antiaim.builder[i].defensive, "on peek", "always on"}})))
            menu.antiaim.builder[i].defensive_yaw_val:depend(unpack(merge_conditions({
                {menu.antiaim.builder[i].defensive, "on peek", "always on"}, 
                {menu.antiaim.builder[i].defensive_yaw, "static", "sideways", "jitter"}
            })))
            menu.antiaim.builder[i].defensive_yaw_val2:depend(unpack(merge_conditions({
                {menu.antiaim.builder[i].defensive, "on peek", "always on"}, 
                {menu.antiaim.builder[i].defensive_yaw, "jitter"}
            })))
            menu.antiaim.builder[i].defensive_spin:depend(unpack(merge_conditions({
                {menu.antiaim.builder[i].defensive, "on peek", "always on"}, 
                {menu.antiaim.builder[i].defensive_yaw, "spin"}
            })))
            
            local spin_jitter_base = merge_conditions({
                {menu.antiaim.builder[i].defensive, "on peek", "always on"}, 
                {menu.antiaim.builder[i].defensive_yaw, "spin jitter"}
            })
            
            menu.antiaim.builder[i].defensive_yaw_sj_angle_label:depend(unpack(spin_jitter_base))
            menu.antiaim.builder[i].defensive_yaw_sj_angle:depend(unpack(spin_jitter_base))
            menu.antiaim.builder[i].defensive_yaw_sj_delay_label:depend(unpack(spin_jitter_base))
            menu.antiaim.builder[i].defensive_yaw_sj_delay:depend(unpack(spin_jitter_base))
            menu.antiaim.builder[i].defensive_yaw_sj_speed_label:depend(unpack(spin_jitter_base))
            menu.antiaim.builder[i].defensive_yaw_sj_speed:depend(unpack(spin_jitter_base))
            
        else
            menu.antiaim.builder[i].override:depend({menu.enable, true}, {menu.tab, "anti-aim"}, {menu.antiaim.condition, states[i]})
            
            local override_condition = {{menu.antiaim.builder[i].override, true}}
            
            local function merge_conditions(extra)
                local result = {}
                for _, v in ipairs(base_conditions) do table.insert(result, v) end
                for _, v in ipairs(override_condition) do table.insert(result, v) end
                if extra then
                    for _, v in ipairs(extra) do table.insert(result, v) end
                end
                return result
            end
            
            menu.antiaim.builder[i].pitch:depend(unpack(merge_conditions()))
            menu.antiaim.builder[i].pitch_custom:depend(unpack(merge_conditions({{menu.antiaim.builder[i].pitch, "custom"}})))
            
            menu.antiaim.builder[i].yaw:depend(unpack(merge_conditions()))
            menu.antiaim.builder[i].yaw_value:depend(unpack(merge_conditions({{menu.antiaim.builder[i].yaw, "backward"}})))
            menu.antiaim.builder[i].classic1:depend(unpack(merge_conditions({{menu.antiaim.builder[i].yaw, "left/right"}})))
            menu.antiaim.builder[i].classic2:depend(unpack(merge_conditions({{menu.antiaim.builder[i].yaw, "left/right"}})))
            
            menu.antiaim.builder[i].modifier:depend(unpack(merge_conditions()))
            menu.antiaim.builder[i].mod_slider:depend(unpack(merge_conditions({{menu.antiaim.builder[i].modifier, "off", true}})))
            menu.antiaim.builder[i].delay_ticks:depend(unpack(merge_conditions({{menu.antiaim.builder[i].modifier, "jitter"}})))
            
            menu.antiaim.builder[i].bodyyaw:depend(unpack(merge_conditions({{menu.antiaim.builder[i].modifier, "jitter", true}})))
            menu.antiaim.builder[i].delay:depend(unpack(merge_conditions({{menu.antiaim.builder[i].bodyyaw, "delayed", "break"}})))
            
            menu.antiaim.builder[i].defensive:depend(unpack(merge_conditions()))
            menu.antiaim.builder[i].defensive_pitch:depend(unpack(merge_conditions({{menu.antiaim.builder[i].defensive, "on peek", "always on"}})))
            menu.antiaim.builder[i].defensive_pitch_ang:depend(unpack(merge_conditions({
                {menu.antiaim.builder[i].defensive, "on peek", "always on"}, 
                {menu.antiaim.builder[i].defensive_pitch, "static", "jitter", "random", "spin"}
            })))
            menu.antiaim.builder[i].defensive_pitch_ang2:depend(unpack(merge_conditions({
                {menu.antiaim.builder[i].defensive, "on peek", "always on"}, 
                {menu.antiaim.builder[i].defensive_pitch, "jitter", "random", "spin"}
            })))
            menu.antiaim.builder[i].defensive_pitch_speed:depend(unpack(merge_conditions({
                {menu.antiaim.builder[i].defensive, "on peek", "always on"}, 
                {menu.antiaim.builder[i].defensive_pitch, "spin"}
            })))
            
            menu.antiaim.builder[i].defensive_yaw:depend(unpack(merge_conditions({{menu.antiaim.builder[i].defensive, "on peek", "always on"}})))
            menu.antiaim.builder[i].defensive_yaw_val:depend(unpack(merge_conditions({
                {menu.antiaim.builder[i].defensive, "on peek", "always on"}, 
                {menu.antiaim.builder[i].defensive_yaw, "static", "sideways", "jitter"}
            })))
            menu.antiaim.builder[i].defensive_yaw_val2:depend(unpack(merge_conditions({
                {menu.antiaim.builder[i].defensive, "on peek", "always on"}, 
                {menu.antiaim.builder[i].defensive_yaw, "jitter"}
            })))
            menu.antiaim.builder[i].defensive_spin:depend(unpack(merge_conditions({
                {menu.antiaim.builder[i].defensive, "on peek", "always on"}, 
                {menu.antiaim.builder[i].defensive_yaw, "spin"}
            })))
            
            local spin_jitter_base = merge_conditions({
                {menu.antiaim.builder[i].defensive, "on peek", "always on"}, 
                {menu.antiaim.builder[i].defensive_yaw, "spin jitter"}
            })
            
            menu.antiaim.builder[i].defensive_yaw_sj_angle_label:depend(unpack(spin_jitter_base))
            menu.antiaim.builder[i].defensive_yaw_sj_angle:depend(unpack(spin_jitter_base))
            menu.antiaim.builder[i].defensive_yaw_sj_delay_label:depend(unpack(spin_jitter_base))
            menu.antiaim.builder[i].defensive_yaw_sj_delay:depend(unpack(spin_jitter_base))
            menu.antiaim.builder[i].defensive_yaw_sj_speed_label:depend(unpack(spin_jitter_base))
            menu.antiaim.builder[i].defensive_yaw_sj_speed:depend(unpack(spin_jitter_base))
        end
    end
    
    -- Tab dependencies
    menu.tab:depend({menu.enable, true})
    menu.antiaim.condition:depend({menu.enable, true}, {menu.tab, "anti-aim"})
    
    -- TAB 2: ANTI-AIM HELPER
    menu.helper.freestand:depend({menu.enable, true}, {menu.tab, "anti-aim helper"})
    menu.helper.edge_yaw:depend({menu.enable, true}, {menu.tab, "anti-aim helper"})
    menu.helper.left:depend({menu.enable, true}, {menu.tab, "anti-aim helper"})
    menu.helper.right:depend({menu.enable, true}, {menu.tab, "anti-aim helper"})
    menu.helper.forward:depend({menu.enable, true}, {menu.tab, "anti-aim helper"})
    menu.helper.reset:depend({menu.enable, true}, {menu.tab, "anti-aim helper"})
    
    -- TAB 3: RAGE
    menu.rage.air_enable:depend({menu.enable, true}, {menu.tab, "rage"})
    menu.rage.air_hotkey:depend({menu.enable, true}, {menu.tab, "rage"}, {menu.rage.air_enable, true})
    menu.rage.air_distance:depend({menu.enable, true}, {menu.tab, "rage"}, {menu.rage.air_enable, true})
    menu.rage.air_hc_enable:depend({menu.enable, true}, {menu.tab, "rage"}, {menu.rage.air_enable, true})
    menu.rage.air_hc_hotkey:depend({menu.enable, true}, {menu.tab, "rage"}, {menu.rage.air_enable, true}, {menu.rage.air_hc_enable, true})
    menu.rage.air_hc_value:depend({menu.enable, true}, {menu.tab, "rage"}, {menu.rage.air_enable, true}, {menu.rage.air_hc_enable, true})
    menu.rage.air_mix_enable:depend({menu.enable, true}, {menu.tab, "rage"}, {menu.rage.air_enable, true})
    menu.rage.air_mix_color:depend({menu.enable, true}, {menu.tab, "rage"}, {menu.rage.air_enable, true}, {menu.rage.air_mix_enable, true})
    
    menu.rage.lc_enable:depend({menu.enable, true}, {menu.tab, "rage"})
    menu.rage.lc_hotkey:depend({menu.enable, true}, {menu.tab, "rage"}, {menu.rage.lc_enable, true})
    menu.rage.lc_ticks:depend({menu.enable, true}, {menu.tab, "rage"}, {menu.rage.lc_enable, true})
    
    menu.rage.qr_enable:depend({menu.enable, true}, {menu.tab, "rage"})
    menu.rage.qr_req_qp:depend({menu.enable, true}, {menu.tab, "rage"}, {menu.rage.qr_enable, true})
    menu.rage.qr_logic:depend({menu.enable, true}, {menu.tab, "rage"}, {menu.rage.qr_enable, true})
    menu.rage.qr_delay:depend({menu.enable, true}, {menu.tab, "rage"}, {menu.rage.qr_enable, true})

    menu.rage.res_enable:depend({menu.enable, true}, {menu.tab, "rage"})
    menu.rage.res_baim_multi:depend({menu.enable, true}, {menu.tab, "rage"}, {menu.rage.res_enable, true})
    menu.rage.res_baim_hp:depend({menu.enable, true}, {menu.tab, "rage"}, {menu.rage.res_enable, true})
    menu.rage.res_safe_multi:depend({menu.enable, true}, {menu.tab, "rage"}, {menu.rage.res_enable, true})
    menu.rage.res_safe_hp:depend({menu.enable, true}, {menu.tab, "rage"}, {menu.rage.res_enable, true})
    menu.rage.res_safe_miss:depend({menu.enable, true}, {menu.tab, "rage"}, {menu.rage.res_enable, true})


     -- TAB 4: VISUAL

    menu.visual.vm_enable:depend({menu.enable, true}, {menu.tab, "visual"})
    

    menu.visual.al_enable:depend({menu.enable, true}, {menu.tab, "visual"})
    menu.visual.al_hit_color:depend({menu.enable, true}, {menu.tab, "visual"}, {menu.visual.al_enable, true})
    menu.visual.al_miss_color:depend({menu.enable, true}, {menu.tab, "visual"}, {menu.visual.al_enable, true})
    menu.visual.al_duration:depend({menu.enable, true}, {menu.tab, "visual"}, {menu.visual.al_enable, true})
    menu.visual.al_console:depend({menu.enable, true}, {menu.tab, "visual"}, {menu.visual.al_enable, true})
    

    menu.visual.fl_enable:depend({menu.enable, true}, {menu.tab, "visual"})
    

    menu.visual.dm_enable:depend({menu.enable, true}, {menu.tab, "visual"})
    menu.visual.dm_duration:depend({menu.enable, true}, {menu.tab, "visual"}, {menu.visual.dm_enable, true})
    menu.visual.dm_speed:depend({menu.enable, true}, {menu.tab, "visual"}, {menu.visual.dm_enable, true})
    menu.visual.dm_def_label:depend({menu.enable, true}, {menu.tab, "visual"}, {menu.visual.dm_enable, true})
    menu.visual.dm_def_color:depend({menu.enable, true}, {menu.tab, "visual"}, {menu.visual.dm_enable, true})
    menu.visual.dm_head_label:depend({menu.enable, true}, {menu.tab, "visual"}, {menu.visual.dm_enable, true})
    menu.visual.dm_head_color:depend({menu.enable, true}, {menu.tab, "visual"}, {menu.visual.dm_enable, true})
    menu.visual.dm_nade_label:depend({menu.enable, true}, {menu.tab, "visual"}, {menu.visual.dm_enable, true})
    menu.visual.dm_nade_color:depend({menu.enable, true}, {menu.tab, "visual"}, {menu.visual.dm_enable, true})
    menu.visual.dm_knife_label:depend({menu.enable, true}, {menu.tab, "visual"}, {menu.visual.dm_enable, true})
    menu.visual.dm_knife_color:depend({menu.enable, true}, {menu.tab, "visual"}, {menu.visual.dm_enable, true})
    menu.visual.dm_minus:depend({menu.enable, true}, {menu.tab, "visual"}, {menu.visual.dm_enable, true})
    
    menu.visual.hm_enable:depend({menu.enable, true}, {menu.tab, "visual"})
    menu.visual.hm_color:depend({menu.enable, true}, {menu.tab, "visual"}, {menu.visual.hm_enable, true})
    

    menu.visual.di_enable:depend({menu.enable, true}, {menu.tab, "visual"})
    
    -- TAB 5: MISC
    menu.misc.safehead:depend({menu.enable, true}, {menu.tab, "misc"})
    menu.misc.ladder:depend({menu.enable, true}, {menu.tab, "misc"})
    menu.misc.ladder_pitch:depend({menu.enable, true}, {menu.tab, "misc"}, {menu.misc.ladder, true})
    menu.misc.ladder_yaw:depend({menu.enable, true}, {menu.tab, "misc"}, {menu.misc.ladder, true})
    menu.misc.antistab:depend({menu.enable, true}, {menu.tab, "misc"})
    menu.misc.bombfix:depend({menu.enable, true}, {menu.tab, "misc"})
    

    menu.misc.cws_enable:depend({menu.enable, true}, {menu.tab, "misc"})

    menu.misc.etc_enable:depend({menu.enable, true}, {menu.tab, "misc"})
    

    menu.misc.mm_enable:depend({menu.enable, true}, {menu.tab, "misc"})
    menu.misc.mm_options:depend({menu.enable, true}, {menu.tab, "misc"}, {menu.misc.mm_enable, true})
    

    menu.misc.fr_enable:depend({menu.enable, true}, {menu.tab, "misc"})
    

    menu.misc.ps_mode:depend({menu.enable, true}, {menu.tab, "misc"})
    menu.misc.ps_reset:depend({menu.enable, true}, {menu.tab, "misc"})
    menu.misc.ps_custom:depend({menu.enable, true}, {menu.tab, "misc"}, {menu.misc.ps_mode, "Customizable"})
    

    menu.misc.uc_enable:depend({menu.enable, true}, {menu.tab, "misc"})
    
    -- FIXED: World Sound dependencies (منوهای worldsound زیر checkbox ws_enable)
    menu.misc.ws_enable:depend({menu.enable, true}, {menu.tab, "misc"})
    for i=1, #mixers_list do
        menu.misc.ws_modifier[mixers_list[i]]:depend({menu.enable, true}, {menu.tab, "misc"}, {menu.misc.ws_enable, true})
    end

    menu.misc.ca_enable:depend({menu.enable, true}, {menu.tab, "misc"})
    menu.misc.ca_options:depend({menu.enable, true}, {menu.tab, "misc"}, {menu.misc.ca_enable, true})
end

handles.gmb = function(active, item)
    local trigger = not item
    
    if active == true then
        ui.set_visible(ref.aa_enabled, trigger)
        ui.set_visible(ref.pitch[1], trigger)
        ui.set_visible(ref.pitch[2], trigger)
        ui.set_visible(ref.yaw_base, trigger)
        ui.set_visible(ref.yaw[1], trigger)
        ui.set_visible(ref.yaw[2], trigger)
        ui.set_visible(ref.yaw_jitter[1], trigger)
        ui.set_visible(ref.yaw_jitter[2], trigger)
        ui.set_visible(ref.body_yaw[1], trigger)
        ui.set_visible(ref.body_yaw[2], trigger)
        ui.set_visible(ref.freestanding_body_yaw, trigger)
        ui.set_visible(ref.edge_yaw, trigger)
        ui.set_visible(ref.freestanding[1], trigger)
        ui.set_visible(ref.freestanding[2], trigger)
        ui.set_visible(ref.roll, trigger)
    else
        ui.set_visible(ref.aa_enabled, true)
        ui.set_visible(ref.pitch[1], true)
        ui.set_visible(ref.pitch[2], true)
        ui.set_visible(ref.yaw_base, true)
        ui.set_visible(ref.yaw[1], true)
        ui.set_visible(ref.yaw[2], true)
        ui.set_visible(ref.yaw_jitter[1], true)
        ui.set_visible(ref.yaw_jitter[2], true)
        ui.set_visible(ref.body_yaw[1], true)
        ui.set_visible(ref.body_yaw[2], true)
        ui.set_visible(ref.freestanding_body_yaw, true)
        ui.set_visible(ref.edge_yaw, true)
        ui.set_visible(ref.freestanding[1], true)
        ui.set_visible(ref.freestanding[2], true)
        ui.set_visible(ref.roll, true)
    end
end

-- ════════════════════════════════════════════════════════════════════════════════
-- CALLBACKS
-- ════════════════════════════════════════════════════════════════════════════════
for i=1, #mixers_list do
    local mixer = mixers_list[i]
    menu.misc.ws_modifier[mixer]:set_callback(function()
        update_mixers(mixer)
    end)
end

menu.misc.ps_reset:set_callback(function()
    if ps_ptr and ps_initialized then
        ps_ptr[0] = 5
    end
    sv_maxunlag:set_float(0.005)
    pcall(function() ui.set(ref.max_unlag, 5) end)
    menu.misc.ps_mode:set("Off")
    client.log("Reset to 5ms")
end)

menu.enable:set_callback(function()
    local enabled = menu.enable:get()
    if not enabled then
        reset_everything_to_default()
    end
end)

menu.misc.ps_mode:set_callback(update_ping_settings)
menu.misc.ps_custom:set_callback(function()
    if menu.misc.ps_mode:get() == "Customizable" then
        update_ping_settings()
    end
end)

menu.misc.uc_enable:set_callback(update_unhide_visibility)

menu.misc.cws_enable:set_callback(function()
    if not menu.misc.cws_enable:get() then
        restore_weapon_sounds()
        cws_data.was_enabled = false
    end
end)

-- ════════════════════════════════════════════════════════════════════════════════
-- EVENT CALLBACKS
-- ════════════════════════════════════════════════════════════════════════════════
client.set_event_callback("net_update_end", function()
    defensive.currently_active = defensive:is_active(entity.get_local_player())
end)

client.set_event_callback("setup_command", function(cmd)
    if not menu.enable:get() then return end
    
    -- Anti-Aim
    antiaim:update(cmd)
    antiaim:handler(cmd)
    antiaim:manuals()
    antiaim.bombsite_fix(cmd)
    antiaim:safe_head()
    antiaim:anti_backstab(cmd)
    main:ladder(cmd)
    
    -- Visual
    vm_run_command()
    fl_setup_command(cmd)
    
    -- Misc
    if menu.misc.cws_enable:get() then
        if cmd.in_attack == 1 then
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
    
    on_mm_setup_command(cmd)
    handle_fast_recharge(cmd)
    
    if menu.misc.ca_enable:get() then
        local lp = entity.get_local_player()
        if lp and entity.is_alive(lp) then
            ca_globals.in_speed = bit.band(cmd.buttons, 131072) > 0
        end
    end
end)

-- Rage Predict Command
client.set_event_callback('predict_command', function(cmd)
    if not menu.enable:get() or not menu.rage.air_enable:get() then return end
    
    local lp = entity.get_local_player()
    if lp == nil then return end

    local flags = entity.get_prop(lp, 'm_fFlags')
    local velocity = vector(entity.get_prop(lp, 'm_vecVelocity[0]'), entity.get_prop(lp, 'm_vecVelocity[1]'), entity.get_prop(lp, 'm_vecVelocity[2]'))
    air_prediction_data = { flags = flags, velocity = velocity }
end)

-- Rage Setup Command
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
    local max_distance = menu.rage.air_distance:get()

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

-- Quick Retreat Events
client.set_event_callback("aim_fire", function(e)
    if not menu.enable:get() or not menu.rage.qr_enable:get() then return end

    if menu.rage.qr_req_qp:get() and not ui.get(ref.quickpeek_key) then
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
        if ui.get(ref.fakelag_limit) <= 0 then return end 
    end

    if qr_is_option_active("Preserve last weapon") then
        qr_vars.last_weapon_cmd = qr_get_console_name(wpn_idx)
    else
        qr_vars.last_weapon_cmd = "slot1"
    end

    client.delay_call(0.05, function()
        if not entity.is_alive(me) then return end

        if menu.rage.qr_req_qp:get() and not ui.get(ref.quickpeek_key) then
            return
        end

        client.exec("use weapon_knife")
        qr_vars.active = true
        qr_vars.switch_tick = globals.tickcount()
    end)
end)

client.set_event_callback("run_command", function(c)
    if not qr_vars.active then return end

    local me = entity.get_local_player()
    if not me or not entity.is_alive(me) then 
        qr_vars.active = false 
        return 
    end

    if menu.rage.qr_req_qp:get() and not ui.get(ref.quickpeek_key) then
        qr_restore_weapon()
        qr_vars.active = false
        return
    end

    local delay_ticks = menu.rage.qr_delay:get()
    local current_tick = globals.tickcount()

    if current_tick >= qr_vars.switch_tick + delay_ticks then
        qr_restore_weapon()
        qr_vars.active = false
    end
end)

client.set_event_callback("paint_ui", function()
    local update = menu.enable:get()
    handles.gmb(true, update)
end)

client.set_event_callback("shutdown", function()
    handles.gmb(false)
    reset_everything_to_default()
end)

client.set_event_callback("player_connect_full", function(e)
    if client.userid_to_entindex(e.userid) == entity.get_local_player() then
        update_callbacks()
        
        if menu.enable:get() then
            if menu.misc.cws_enable:get() then
                client.delay_call(3, function()
                    pcall(enable_sv_cheats)
                    client.exec("snd_restart")
                end)
            end
            
            if menu.misc.ws_enable:get() then
                update_mixers()
            end
        end
    end
end)

-- Visual Events
client.set_event_callback("aim_fire", function(e)
    al_on_aim_fire(e)
    hm_aim_fire(e)
    
    if menu.enable:get() and menu.misc.cws_enable:get() then
        play_custom_sound()
    end
end)

client.set_event_callback("aim_hit", function(e)
    al_on_aim_hit(e)
    hm_aim_hit(e)
    on_hit_resolver(e)
end)

client.set_event_callback("aim_miss", function(e)
    al_on_aim_miss(e)
    on_miss_resolver(e)
end)

client.set_event_callback("player_hurt", dm_on_player_hurt)
client.set_event_callback("player_say", on_player_say)
client.set_event_callback("player_chat", on_player_location_update)
client.set_event_callback("player_death", on_death_resolver)

client.set_event_callback("paint", function(ctx)
    al_on_paint()
    fl_on_paint()
    hm_paint()
    di_on_paint()
    dm_on_paint(ctx)
    
    -- Airstop HC Indicators + HC Override
    if menu.enable:get() and menu.rage.air_enable:get() then
        local lp = entity.get_local_player()
        if lp ~= nil and entity.is_alive(lp) then
            local wpn_ent = entity.get_player_weapon(lp)
            local is_ssg08 = wpn_ent ~= nil and entity.get_classname(wpn_ent) == 'CWeaponSSG08'

            if is_ssg08 then
                local air_active = is_air_active()
                local hc_active = is_air_hc_active()
                local mix_active = menu.rage.air_mix_enable:get() and air_active and hc_active

                if air_active and not mix_active then
                    renderer.indicator(255, 255, 255, 255, "Airstop")
                end

                if hc_active and not mix_active then
                    renderer.indicator(255, 255, 255, 255, "HC")
                end

                if mix_active then
                    local r, g, b, a = menu.rage.air_mix_color:get()
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
                            local value = menu.rage.air_hc_value:get()
                            if value ~= 0 then
                                local prev_wpn_type = ui.get(ref.weapon_type)
                                ui.set(ref.weapon_type, "SSG 08")
                                local current_hc = ui.get(ref.hitchance)
                                if air_hc_overridden == nil or air_hc_overridden ~= value then
                                    air_hc_original = current_hc
                                    ui.set(ref.hitchance, value)
                                    air_hc_overridden = value
                                end
                                ui.set(ref.weapon_type, prev_wpn_type)
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
    if menu.enable:get() and menu.rage.lc_enable:get() then
        local now = globals.realtime()
        local activated = menu.rage.lc_hotkey:get_hotkey()
        
        lc_local_player = entity.get_local_player()
        if not lc_local_player or not entity.is_alive(lc_local_player) then return end
        
        lc_check_charge()
        
        ui.set(ref.dt_checkbox, true)
        
        local condition_met = lc_is_self_peekable() and lc_dt_charged
        
        if activated then
            renderer.indicator(220, 220, 220, 255, "LC Breaker")
        end

        if activated and condition_met then
            if now - lc_last_toggle_time >= lc_toggle_interval then
                lc_current_mode_index = (lc_current_mode_index + 1) % #lc_modes
                local current_mode = lc_modes[lc_current_mode_index + 1]
                ui.set(ref.dt_mode, current_mode)
                lc_last_toggle_time = now
            end
        else
            ui.set(ref.dt_mode, "Toggle")
            lc_current_mode_index = 0
            lc_last_toggle_time = now
        end
    end
    
    -- Resolver
    if menu.enable:get() and menu.rage.res_enable:get() then
        local players = entity.get_players(true)
        
        for _, player in ipairs(players) do
            resolve(player)
            handle_baim(player)
            handle_safe(player)
        end
    end
end)

client.set_event_callback("paint_ui", di_on_paint_ui)

client.set_event_callback("round_start", function()
    hm_shot_data = {}
    hm_memory = {}
    qr_on_reset()
    reset_all_resolver()
end)

client.set_event_callback("round_end", reset_all_resolver)

client.set_event_callback("pre_render", function()
    if not menu.enable:get() or not menu.misc.ca_enable:get() then return end
    local lp = entity.get_local_player()
    if lp and entity.is_alive(lp) then apply_custom_animations(lp) end
end)

client.set_event_callback("net_update_end", function()
    if not menu.enable:get() or not menu.misc.ca_enable:get() then return end
    local lp = entity.get_local_player()
    if lp and entity.is_alive(lp) then apply_custom_animations(lp) end
end)

-- ════════════════════════════════════════════════════════════════════════════════
-- ESP FLAGS (RESOLVER)
-- ════════════════════════════════════════════════════════════════════════════════
client.register_esp_flag("BAIM", 255, 100, 100, function(p)
    return plist.get(p, "Override prefer body aim") == "Force"
end)

client.register_esp_flag("SAFE", 100, 255, 100, function(p)
    return plist.get(p, "Override safe point") == "On"
end)

client.register_esp_flag("RES", 100, 180, 255, function(p)
    return plist.get(p, "Force body yaw")
end)

-- ════════════════════════════════════════════════════════════════════════════════
-- ITEM CRASH FIX
-- ════════════════════════════════════════════════════════════════════════════════
local item_crash_fix do
    local CS_UM_SendPlayerItemFound = 63
    local DispatchUserMessage_t = ffi.typeof [[
        bool(__thiscall*)(void*, int msg_type, int nFlags, int size, const void* msg)
    ]]

    local VClient018 = client.create_interface("client.dll", "VClient018")
    local pointer = ffi.cast("uintptr_t**", VClient018)
    local vtable = ffi.cast("uintptr_t*", pointer[0])

    local size = 0
    while vtable[size] ~= 0x0 do
       size = size + 1
    end

    local hooked_vtable = ffi.new("uintptr_t[?]", size)
    for i = 0, size - 1 do
        hooked_vtable[i] = vtable[i]
    end

    pointer[0] = hooked_vtable
    local oDispatch = ffi.cast(DispatchUserMessage_t, vtable[38])

    local function hkDispatch(thisptr, msg_type, nFlags, size, msg)
        if msg_type == CS_UM_SendPlayerItemFound then
            return false
        end
        return oDispatch(thisptr, msg_type, nFlags, size, msg)
    end

    client.set_event_callback("shutdown", function()
        hooked_vtable[38] = vtable[38]
        pointer[0] = vtable
    end)

    hooked_vtable[38] = ffi.cast("uintptr_t", ffi.cast(DispatchUserMessage_t, hkDispatch))
end

-- ════════════════════════════════════════════════════════════════════════════════
-- INITIALIZE
-- ════════════════════════════════════════════════════════════════════════════════
handles.setupmenu()
config.cfg = pui.setup(menu)

update_callbacks()
update_unhide_visibility()

if menu.enable:get() and menu.misc.cws_enable:get() then
    pcall(enable_sv_cheats)
    client.exec("snd_restart")
end

update_ping_settings()

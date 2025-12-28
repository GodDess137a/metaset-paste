--v2.7 - MENU RESTRUCTURE: Anti-Aim / Anti-Aim Helper / Misc

local pui = require "gamesense/pui"
local ffi = require "ffi"
local vector = require "vector"

-- ===== LERP UTILITY =====
local lerp = {} 
lerp.cache = {} 
lerp.new = function(Name) lerp.cache[Name] = 0 end 
lerp.lerp = function(Name, LerpTo, Speed) 
    if lerp.cache[Name] == nil then lerp.new(Name) end 
    lerp.cache[Name] = lerp.cache[Name] + (LerpTo - lerp.cache[Name]) * (globals.frametime() * Speed) 
    return lerp.cache[Name] 
end

-- ===== ACCENT COLOR =====
local accent = {}
accent.r, accent.g, accent.b = 150, 150, 255

-- ===== PRINT FUNCTION =====
local print = function(...)
    client.color_log(accent.r, accent.g, accent.b, "[metaset] \0")
    client.color_log(198, 203, 209, ...)
end

-- ===== FFI DEFINITIONS =====
ffi.cdef[[
    typedef struct {
        float x;
        float y;
        float z;
    } vec3_t;
    typedef void*(__thiscall* get_client_entity_t)(void*, int);
]]

-- ===== MEMORY UTILITY =====
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

-- ===== UTILITY FUNCTIONS =====
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

-- ===== STATES =====
local temp = {}
local config = {}
local states = {"global", "stand", "slow walk", "move", "duck", "duck move", "air", "air duck"}

-- ===== REFERENCES =====
local ref = {
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
    double_tap = { ui.reference("Rage", "Aimbot", "Double tap") },
    onshot_aa = { ui.reference("AA", "Other", "On shot anti-aim") },
    duck_peek_assist = ui.reference("Rage", "Other", "Duck peek assist"),
    slow_motion = { ui.reference("AA", "Other", "Slow motion") },
}

ui.set(ref.aa_enabled, true)
ui.set(ref.yaw_base, "At targets")

-- ===== MENU GROUPS =====
local groups = {
    main = pui.group("aa", "anti-aimbot angles"),
}
pui.accent = tools.rgba_to_hex(150, 150, 255, 255)

-- ===== MENU STRUCTURE (RESTRUCTURED) =====
local menu = {
    enable = groups.main:checkbox("\vmetaset.cc", {150, 150, 255, 255}),
    -- ✅ FIX: تبدیل Slider به ComboBox
    tab = groups.main:combobox("tab", {"anti-aim", "anti-aim helper", "misc"}),
    
    -- ===== TAB 1: ANTI-AIM =====
    antiaim = {
        condition = groups.main:combobox("condition : ", states, false),
        builder = {},
    },
    
    -- ===== TAB 2: ANTI-AIM HELPER =====
    helper = {
        freestand = groups.main:checkbox("freestand", 0x00),
        edge_yaw = groups.main:checkbox("edge yaw", 0x00),
        left = groups.main:checkbox("left ", 0x00),
        right = groups.main:checkbox("right", 0x00),
        forward = groups.main:checkbox("forward", 0x00),
        reset = groups.main:checkbox("reset", 0x00),
    }, 
    
    -- ===== TAB 3: MISC =====
    misc = {
        safehead = groups.main:multiselect("safehead", {"knife", "zeus", "above enemy"}), 
        ladder = groups.main:checkbox("fast ladder"),
        ladder_pitch = groups.main:slider("pitch", -89, 89, 0, 1),
        ladder_yaw = groups.main:slider("yaw ", -180, 180, 0, 1),
        antistab = groups.main:checkbox("anti backstab"),
        bombfix = groups.main:checkbox("bombside e fix", 0x45),
    },
}

-- ===== CALLBACKS =====
local callbacks = {}
local update_callbacks = function()
    for k, v in pairs(callbacks) do
        v()
    end
end

-- ===== DEFENSIVE SYSTEM =====
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

-- ===== FAKELAG DETECTION SYSTEM =====
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

-- ===== ANTIAIM SYSTEM =====
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

-- ===== JITTER VARIABLES =====
antiaim.jitter_counter = 0
antiaim.jitter_direction = 1
antiaim.last_jitter_tick = 0

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

-- ===== DEFENSIVE PITCH JITTER VARIABLES =====
antiaim.pitch_jitter = {
    switch = false,
    last_switch_tick = 0
}

-- ===== DEFENSIVE SPIN JITTER VARIABLES =====
antiaim.spin_jitter = {
    switch = false,
    last_tick = 0,
    spin_angle = 0
}

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
    local doubletap = ui.get(ref.double_tap[1]) and ui.get(ref.double_tap[2])
    local hideshots = ui.get(ref.onshot_aa[1]) and ui.get(ref.onshot_aa[2])
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
        -- ===== DEFENSIVE PITCH =====
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
        
        -- ===== DEFENSIVE YAW =====
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

-- ===== MAIN HELPERS =====
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

-- ===== HANDLES =====
local handles = {}

handles.setupmenu = function()
    for i = 1, #states do
        menu.antiaim.builder[i] = {}
        
        if i == 1 then
            menu.antiaim.builder[i].enable_global = groups.main:checkbox("\v" .. states[i] .. " · \rEnable Global")
        else
            menu.antiaim.builder[i].override = groups.main:checkbox("\v" .. states[i] .. " · \rOverride ")
        end
        
        -- Pitch
        menu.antiaim.builder[i].pitch = groups.main:combobox("\v" .. states[i] .. " · \rpitch \v", {"disabled", "down", "up", "zero", "custom"})
        menu.antiaim.builder[i].pitch_custom = groups.main:slider("\v" .. states[i] .. " · \rpitch value \v", -89, 89, 0, true, "°", 1)
        
        -- Yaw
        menu.antiaim.builder[i].yaw = groups.main:combobox("\v" .. states[i] .. " · \ryaw \v ", {"disabled", "backward", "left/right"})
        menu.antiaim.builder[i].yaw_value = groups.main:slider("\n\n\n\n\n\n\n\n", -180, 180, 0)
        menu.antiaim.builder[i].classic1 = groups.main:slider("\v" .. states[i] .. " · \r[l|r] \v ", -180, 180, 0)
        menu.antiaim.builder[i].classic2 = groups.main:slider("\n\n\n\n\n\n\n\n\n", -180, 180, 0)
        
        -- Modifier
        menu.antiaim.builder[i].modifier = groups.main:combobox("\v" .. states[i] .. " · \rmodifier \v ", {
            "off", "jitter", "random", "skitter", "center (skeet)", "offset (skeet)"
        })
        menu.antiaim.builder[i].mod_slider = groups.main:slider("\n\n\n\n\n\n\n\n\n\n", 0, 90, 0, true, "°", 1)
        
        -- Delay ticks
        menu.antiaim.builder[i].delay_ticks = groups.main:slider("\v" .. states[i] .. " · \rdelay ticks \v ", 2, 17, 2, true, "t", 1)
        
        -- Body Yaw
        menu.antiaim.builder[i].bodyyaw = groups.main:combobox("\v" .. states[i] .. " · \rbodyyaw \v ", {
            "off", "jitter", "left", "right", "delayed", "break", "jitter (skeet)"
        })
        menu.antiaim.builder[i].delay = groups.main:slider("\v" .. states[i] .. " · \rdelay \v ", 2, 64, 0, true, "t", 1)
        
        -- ===== DEFENSIVE =====
        menu.antiaim.builder[i].defensive = groups.main:combobox("\v" .. states[i] .. " · \rdefensive \v ", {"-", "on peek", "always on"})
        
        -- DEFENSIVE PITCH
        menu.antiaim.builder[i].defensive_pitch = groups.main:combobox("\v" .. states[i] .. " · \rdefensive pitch \v ", {
            "disabled", "static", "jitter", "random", "spin"
        })
        menu.antiaim.builder[i].defensive_pitch_ang = groups.main:slider("\n\n\n\n\n\n\n\n\n\n\n", -89, 89, -89, true, "°", 1)
        menu.antiaim.builder[i].defensive_pitch_ang2 = groups.main:slider("\n\n\n\n\n\n\n\n\n\n\n\n", -89, 89, -89, true, "°", 1)
        menu.antiaim.builder[i].defensive_pitch_speed = groups.main:slider("\n\n\n\n\n\n\n\n\n\n\n\n\n", -50, 50, 20, true, "", 0.1)
        
        -- DEFENSIVE YAW
        menu.antiaim.builder[i].defensive_yaw = groups.main:combobox("\v" .. states[i] .. " · \rdefensive yaw \v ", {
            "disabled", "static", "jitter", "sideways", "random", "spin", "move-based", "spin jitter"
        })
        menu.antiaim.builder[i].defensive_spin = groups.main:slider("\n\n\n\n\n\n\n\n\n\n\n\n\n\n", -60, 60, 0, true, "°", 1)
        menu.antiaim.builder[i].defensive_yaw_val = groups.main:slider("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n", -180, 180, 0, true, "°", 1)
        menu.antiaim.builder[i].defensive_yaw_val2 = groups.main:slider("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n", -180, 180, 0, true, "°", 1)
        
        -- SPIN JITTER PARAMETERS
        menu.antiaim.builder[i].defensive_yaw_sj_angle_label = groups.main:label("\v" .. states[i] .. " · \rspin angle")
        menu.antiaim.builder[i].defensive_yaw_sj_angle = groups.main:slider("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n", 0, 360, 180, true, "°", 1)
        
        menu.antiaim.builder[i].defensive_yaw_sj_delay_label = groups.main:label("\v" .. states[i] .. " · \rjitter delay")
        menu.antiaim.builder[i].defensive_yaw_sj_delay = groups.main:slider("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n", 0, 14, 0, true, "t", 1)
        
        menu.antiaim.builder[i].defensive_yaw_sj_speed_label = groups.main:label("\v" .. states[i] .. " · \rspin speed")
        menu.antiaim.builder[i].defensive_yaw_sj_speed = groups.main:slider("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n", -50, 50, 20, true, "", 0.1)
    end
    
    -- ✅ FIX: Dependencies با ComboBox Index
    for i = 1, #states do
        local base_conditions = {
            {menu.enable, true}, 
            {menu.tab, "anti-aim"},  -- ✅ تغییر از 1 به "anti-aim"
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
            
            -- Pitch
            menu.antiaim.builder[i].pitch:depend(unpack(merge_conditions()))
            menu.antiaim.builder[i].pitch_custom:depend(unpack(merge_conditions({{menu.antiaim.builder[i].pitch, "custom"}})))
            
            -- Yaw
            menu.antiaim.builder[i].yaw:depend(unpack(merge_conditions()))
            menu.antiaim.builder[i].yaw_value:depend(unpack(merge_conditions({{menu.antiaim.builder[i].yaw, "backward"}})))
            menu.antiaim.builder[i].classic1:depend(unpack(merge_conditions({{menu.antiaim.builder[i].yaw, "left/right"}})))
            menu.antiaim.builder[i].classic2:depend(unpack(merge_conditions({{menu.antiaim.builder[i].yaw, "left/right"}})))
            
            -- Modifier
            menu.antiaim.builder[i].modifier:depend(unpack(merge_conditions()))
            menu.antiaim.builder[i].mod_slider:depend(unpack(merge_conditions({{menu.antiaim.builder[i].modifier, "off", true}})))
            menu.antiaim.builder[i].delay_ticks:depend(unpack(merge_conditions({{menu.antiaim.builder[i].modifier, "jitter"}})))
            
            -- Body Yaw
            menu.antiaim.builder[i].bodyyaw:depend(unpack(merge_conditions({{menu.antiaim.builder[i].modifier, "jitter", true}})))
            menu.antiaim.builder[i].delay:depend(unpack(merge_conditions({{menu.antiaim.builder[i].bodyyaw, "delayed", "break"}})))
            
            -- Defensive
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
            
            -- Pitch
            menu.antiaim.builder[i].pitch:depend(unpack(merge_conditions()))
            menu.antiaim.builder[i].pitch_custom:depend(unpack(merge_conditions({{menu.antiaim.builder[i].pitch, "custom"}})))
            
            -- Yaw
            menu.antiaim.builder[i].yaw:depend(unpack(merge_conditions()))
            menu.antiaim.builder[i].yaw_value:depend(unpack(merge_conditions({{menu.antiaim.builder[i].yaw, "backward"}})))
            menu.antiaim.builder[i].classic1:depend(unpack(merge_conditions({{menu.antiaim.builder[i].yaw, "left/right"}})))
            menu.antiaim.builder[i].classic2:depend(unpack(merge_conditions({{menu.antiaim.builder[i].yaw, "left/right"}})))
            
            -- Modifier
            menu.antiaim.builder[i].modifier:depend(unpack(merge_conditions()))
            menu.antiaim.builder[i].mod_slider:depend(unpack(merge_conditions({{menu.antiaim.builder[i].modifier, "off", true}})))
            menu.antiaim.builder[i].delay_ticks:depend(unpack(merge_conditions({{menu.antiaim.builder[i].modifier, "jitter"}})))
            
            -- Body Yaw
            menu.antiaim.builder[i].bodyyaw:depend(unpack(merge_conditions({{menu.antiaim.builder[i].modifier, "jitter", true}})))
            menu.antiaim.builder[i].delay:depend(unpack(merge_conditions({{menu.antiaim.builder[i].bodyyaw, "delayed", "break"}})))
            
            -- Defensive
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
    
    -- TAB 3: MISC
    menu.misc.safehead:depend({menu.enable, true}, {menu.tab, "misc"})
    menu.misc.ladder:depend({menu.enable, true}, {menu.tab, "misc"})
    menu.misc.ladder_pitch:depend({menu.enable, true}, {menu.tab, "misc"}, {menu.misc.ladder, true})
    menu.misc.ladder_yaw:depend({menu.enable, true}, {menu.tab, "misc"}, {menu.misc.ladder, true})
    menu.misc.antistab:depend({menu.enable, true}, {menu.tab, "misc"})
    menu.misc.bombfix:depend({menu.enable, true}, {menu.tab, "misc"})
end

-- ✅ FIX: مخفی کردن کامل منوی AA
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

-- ===== EVENT CALLBACKS =====
client.set_event_callback("net_update_end", function()
    defensive.currently_active = defensive:is_active(entity.get_local_player())
end)

client.set_event_callback("setup_command", function(cmd)
    if not menu.enable:get() then return end
    
    antiaim:update(cmd)
    antiaim:handler(cmd)
    antiaim:manuals()
    main:ladder(cmd)
    antiaim.bombsite_fix(cmd)
    antiaim:safe_head()
    antiaim:anti_backstab(cmd)
end)

client.set_event_callback("paint_ui", function()
    local update = menu.enable:get()
    handles.gmb(true, update)
end)

client.set_event_callback("shutdown", function()
    handles.gmb(false)
end)

client.set_event_callback("player_connect_full", function(e)
    if client.userid_to_entindex(e.userid) == entity.get_local_player() then
        update_callbacks()
    end
end)

-- ===== INITIALIZE =====
handles.setupmenu()
config.cfg = pui.setup(menu)

-- ===== ITEM CRASH FIX =====
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

update_callbacks()

print("✅ Metaset v2.7 loaded!")
print("✅ ComboBox Tab System")
print("✅ AA Menu Hide System - Complete")
-- ============================================================================
-- ULTIMATE RESOLVER - WRAITH + METASET EXACT METHODS
-- Perfect Jitter + Perfect Desync + Perfect Layer Analysis
-- ============================================================================

local ffi = require("ffi")
local bit = require("bit")

-- ============================================================================
-- FFI DEFINITIONS
-- ============================================================================
ffi.cdef[[
    typedef struct {
        float x, y, z;
    } Vector3;
    
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

-- ============================================================================
-- OFFSETS
-- ============================================================================
local OFFSET_ANIMSTATE = 0x9960
local OFFSET_ANIMLAYER = 0x2990

-- ============================================================================
-- INTERFACES
-- ============================================================================
local entity_list = ffi.cast("void***", client.create_interface("client_panorama.dll", "VClientEntityList003"))
local get_client_entity = ffi.cast("GetClientEntity_t", entity_list[0][3])

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================
local function get_entity_address(idx)
    if not idx then return nil end
    local addr = get_client_entity(entity_list, idx)
    return addr ~= nil and ffi.cast("uintptr_t", addr) or nil
end

local function get_animstate(idx)
    local addr = get_entity_address(idx)
    if not addr then return nil end
    local state = ffi.cast("CCSGOPlayerAnimState**", addr + OFFSET_ANIMSTATE)[0]
    return state ~= nil and state or nil
end

local function get_layer(idx, layer_idx)
    local addr = get_entity_address(idx)
    if not addr then return nil end
    local layers = ffi.cast("CAnimationLayer*", addr + OFFSET_ANIMLAYER)
    return layers ~= nil and layers[layer_idx] or nil
end

local function normalize(angle)
    while angle > 180 do angle = angle - 360 end
    while angle < -180 do angle = angle + 360 end
    return angle
end

local function approach_angle(target, value, speed)
    local delta = normalize(target - value)
    
    if delta > speed then
        value = value + speed
    elseif delta < -speed then
        value = value - speed
    else
        value = target
    end
    
    return normalize(value)
end

-- ============================================================================
-- UI
-- ============================================================================
local ui_main = ui.new_checkbox("LUA", "B", "Enable Features")
local ui_resolver = ui.new_checkbox("LUA", "B", "Enable Resolver")
local ui_baim_multi = ui.new_multiselect("LUA", "B", "Auto force body aim if", {"HP lower than X value"})
local ui_baim_hp = ui.new_slider("LUA", "B", "Body aim HP threshold", 0, 100, 50, true, "", 1)
local ui_safe_multi = ui.new_multiselect("LUA", "B", "Auto force safepoint if", {"HP lower than X value", "After X misses"})
local ui_safe_hp = ui.new_slider("LUA", "B", "Safepoint HP threshold", 0, 100, 50, true, "", 1)
local ui_safe_miss = ui.new_slider("LUA", "B", "Safepoint after misses", 0, 10, 2, true, "", 1)

-- ============================================================================
-- DATA STORAGE
-- ============================================================================
local player_data = {}

local function init_player(idx)
    if not player_data[idx] then
        player_data[idx] = {
            misses = 0,
            
            -- Jitter (Wraith exact)
            eye_angles = {},
            angle_index = 0,
            last_jitter_detect = 0,
            jitter_confidence = 0,
            
            -- Desync tracking (Metaset exact)
            body_updates = {},
            eye_deltas = {},
            feet_deltas = {},
            
            -- Layer perfect tracking
            layer_data = {},
            layer_history = {},
            
            -- LBY
            lby_timer = 0,
            lby_next_update = 0,
            standing_time = 0,
            last_velocity = 999,
            
            -- State
            last_ground_yaw = 0,
            simtime = 0,
            old_simtime = 0,
            
            -- Desync calculation
            calculated_max_desync = 58,
            desync_delta = 0,
            moving_desync = 0,
            static_desync = 0
        }
    end
    return player_data[idx]
end

-- ============================================================================
-- PERFECT DESYNC CALCULATION (METASET + HYSTERIA EXACT)
-- ============================================================================
local function calculate_perfect_desync(state, velocity, duck_amount)
    if not state then return 58, 58 end
    
    -- Get base values
    local running = math.max(0, math.min(1, state.m_flRunningSpeed))
    local ducking = math.max(0, math.min(1, state.m_flDuckingSpeed))
    local duck_amt = math.max(0, math.min(1, duck_amount or state.m_fDuckAmount))
    local move_weight = state.m_flMoveWeight or 0
    
    -- Speed as portion of walk/run
    local speed_portion = math.max(0, math.min(1, running))
    
    -- Walking speed factor (affects desync)
    local walk_run_transition = state.m_flStrafingAccelProgress or 0
    
    -- Base desync modifier (from game code)
    -- unk1 = ((m_flStrafingAccelProgress * -0.3) - 0.2) * speed_as_portion_of_walk_run
    local unk1 = ((walk_run_transition * -0.3) - 0.2) * speed_portion
    local unk2 = unk1 + 1.0
    
    -- Duck modifier (reduces desync)
    if duck_amt > 0 then
        local duck_speed = speed_portion * duck_amt
        unk2 = unk2 + (duck_speed * (0.5 - unk2))
    end
    
    -- Clamp to valid range
    local modifier = math.max(0.5, math.min(1.0, unk2))
    
    -- Get max body yaw from animstate
    local max_body = state.m_flMaxBodyYaw or 58
    if max_body < 10 then max_body = 58 end
    
    -- Calculate moving desync
    local moving_desync = max_body * modifier
    
    -- Static desync (when standing still)
    local static_desync = max_body
    
    -- Additional calculations for moving
    if velocity > 0.1 then
        -- Speed factor
        local speed_factor = math.min(1.0, velocity / 250.0)
        
        -- Movement reduces max desync
        moving_desync = moving_desync * (1.0 - (speed_factor * 0.15))
    end
    
    return moving_desync, static_desync
end

-- ============================================================================
-- WRAITH JITTER DETECTION (EXACT METHOD)
-- ============================================================================
local function wraith_jitter_detect(idx, data, state)
    if not state then return false, 0, 0 end
    
    local eye_yaw = state.m_flEyeYaw
    local feet_yaw = state.m_flGoalFeetYaw
    
    -- Store angles in circular buffer
    data.angle_index = data.angle_index + 1
    local slot = (data.angle_index - 1) % 8
    
    data.eye_angles[slot] = {
        eye = eye_yaw,
        feet = feet_yaw,
        time = globals.curtime()
    }
    
    -- Need at least 6 samples
    if data.angle_index < 6 then
        return false, 0, 0
    end
    
    -- Calculate all deltas
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
    
    -- Calculate average delta
    local sum = 0
    for _, d in ipairs(deltas) do
        sum = sum + d
    end
    local avg_delta = sum / #deltas
    
    -- Calculate variance
    local variance = 0
    for _, d in ipairs(deltas) do
        variance = variance + math.pow(d - avg_delta, 2)
    end
    variance = variance / #deltas
    
    -- Jitter threshold (dynamic based on desync)
    local threshold = 35.0 * math.min(1.5, data.calculated_max_desync / 58.0)
    
    -- Detect jitter: high average delta OR high variance
    local is_jitter = (avg_delta > threshold) or (variance > 400)
    
    if is_jitter then
        data.jitter_confidence = math.min(5, data.jitter_confidence + 1)
    else
        data.jitter_confidence = math.max(0, data.jitter_confidence - 1)
    end
    
    if data.jitter_confidence >= 2 then
        -- Calculate side using Wraith's circular mean
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
            
            -- Calculate feet-eye relationship
            local feet_diff = normalize(state.m_flEyeYaw - state.m_flGoalFeetYaw)
            
            local side = 0
            
            -- Method 1: Difference from mean
            if math.abs(current_diff) > 3 then
                side = current_diff > 0 and -1 or 1
            -- Method 2: Feet relationship
            elseif math.abs(feet_diff) > 35 then
                side = feet_diff > 0 and -1 or 1
            -- Method 3: Last two deltas
            else
                local last_two = normalize(data.eye_angles[(data.angle_index - 1) % 8].eye - data.eye_angles[(data.angle_index - 2) % 8].eye)
                side = last_two > 0 and 1 or -1
            end
            
            return true, side, data.jitter_confidence
        end
    end
    
    return false, 0, 0
end

-- ============================================================================
-- METASET DESYNC DETECTION (EXACT METHOD)
-- ============================================================================
local function metaset_desync_detect(idx, data, state)
    if not state then return 0, 0 end
    
    local eye_yaw = state.m_flEyeYaw
    local feet_yaw = state.m_flGoalFeetYaw
    local body_prop = entity.get_prop(idx, "m_flPoseParameter", 11)
    
    if not body_prop then return 0, 0 end
    
    local body_yaw = body_prop * 120 - 60
    
    -- Store body updates
    table.insert(data.body_updates, 1, {
        body = body_yaw,
        eye = eye_yaw,
        feet = feet_yaw,
        time = globals.curtime()
    })
    
    if #data.body_updates > 10 then
        table.remove(data.body_updates)
    end
    
    -- Calculate deltas
    local eye_feet_delta = normalize(eye_yaw - feet_yaw)
    local eye_body_delta = normalize(eye_yaw - body_yaw)
    
    -- Store deltas
    table.insert(data.eye_deltas, 1, eye_feet_delta)
    table.insert(data.feet_deltas, 1, eye_body_delta)
    
    if #data.eye_deltas > 5 then table.remove(data.eye_deltas) end
    if #data.feet_deltas > 5 then table.remove(data.feet_deltas) end
    
    -- Metaset voting system
    local votes = {left = 0, right = 0}
    local confidence = 0
    
    -- Vote 1: Eye-Feet delta (strongest indicator)
    if math.abs(eye_feet_delta) > 35 then
        if eye_feet_delta > 0 then
            votes.left = votes.left + 3
        else
            votes.right = votes.right + 3
        end
        confidence = confidence + 3
    end
    
    -- Vote 2: Body yaw consistency
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
    
    -- Vote 3: Delta consistency
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
    
    -- Determine winner
    local side = 0
    if votes.left > votes.right and votes.left >= 3 then
        side = -1
    elseif votes.right > votes.left and votes.right >= 3 then
        side = 1
    end
    
    return side, confidence
end

-- ============================================================================
-- ADVANCED LAYER ANALYSIS (3, 6, 11, 12)
-- ============================================================================
local function analyze_all_layers(idx, data)
    -- Store old data
    table.insert(data.layer_history, 1, data.layer_data)
    if #data.layer_history > 3 then
        table.remove(data.layer_history)
    end
    
    -- Get current layers
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
    
    -- Layer 3: Adjust layer (LBY break detection)
    if data.layer_data[3] then
        local l3 = data.layer_data[3]
        
        -- Sequence 979 = LBY break
        if l3.seq == 979 then
            return "lby_break", 0, 10
        end
        
        -- Check weight and cycle changes
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
    
    -- Layer 6: Movement layer
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
                
                -- Playback rate change adds confidence
                if rate_change > 0.1 then
                    conf = conf + 1
                end
            end
        end
    end
    
    -- Layer 11: Strafe layer
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
    
    -- Layer 12: Lean layer
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

-- ============================================================================
-- PERFECT LBY TIMING
-- ============================================================================
local function perfect_lby_timing(idx, data, state)
    if not state then return false, 0 end
    
    local vx, vy = entity.get_prop(idx, "m_vecVelocity")
    local velocity = math.sqrt(vx*vx + vy*vy)
    local on_ground = bit.band(entity.get_prop(idx, "m_fFlags"), 1) == 1
    local curtime = globals.curtime()
    
    -- Track velocity changes
    local was_moving = data.last_velocity > 5
    local is_moving = velocity > 5
    
    data.last_velocity = velocity
    
    -- Started standing still
    if was_moving and not is_moving and on_ground then
        data.standing_time = curtime
        data.lby_timer = curtime
        data.lby_next_update = curtime + 0.22 -- First update at 0.22
    end
    
    -- Started moving
    if not was_moving and is_moving then
        data.standing_time = 0
        data.lby_timer = 0
        data.lby_next_update = 0
        return false, 0
    end
    
    -- Check if standing still
    if not is_moving and on_ground and data.standing_time > 0 then
        local standing_duration = curtime - data.standing_time
        
        -- LBY update timing: 0.22, 1.32, 2.42, etc.
        if standing_duration >= 0.22 then
            local body = entity.get_prop(idx, "m_flPoseParameter", 11)
            if body then
                local body_yaw = body * 120 - 60
                
                if math.abs(body_yaw) > 35 then
                    -- Check if near update time (within 0.15s window)
                    local time_since_last = curtime - data.lby_timer
                    
                    if time_since_last >= 1.05 then -- 1.1s interval with tolerance
                        data.lby_timer = curtime
                        data.lby_next_update = curtime + 1.1
                        return true, body_yaw
                    elseif standing_duration < 0.3 then -- First update
                        return true, body_yaw
                    end
                end
            end
        end
    end
    
    return false, 0
end

-- ============================================================================
-- MAIN RESOLVER
-- ============================================================================
local function resolve(idx)
    if not entity.is_alive(idx) or entity.is_dormant(idx) then
        return
    end
    
    local data = init_player(idx)
    local state = get_animstate(idx)
    
    if not state then return end
    
    -- Update simulation time
    data.old_simtime = data.simtime
    data.simtime = entity.get_prop(idx, "m_flSimulationTime")
    
    -- Get velocity and duck
    local vx, vy = entity.get_prop(idx, "m_vecVelocity")
    local velocity = math.sqrt(vx*vx + vy*vy)
    local duck = entity.get_prop(idx, "m_fDuckAmount") or 0
    
    -- Calculate perfect desync
    local moving_desync, static_desync = calculate_perfect_desync(state, velocity, duck)
    data.calculated_max_desync = moving_desync
    data.moving_desync = moving_desync
    data.static_desync = static_desync
    
    local yaw = nil
    local method = ""
    
    -- Priority 1: Wraith Jitter Detection
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
    
    -- Priority 4: Metaset Desync Detection
    if not yaw then
        local desync_side, desync_conf = metaset_desync_detect(idx, data, state)
        
        if desync_side ~= 0 and desync_conf >= 3 then
            -- Use static desync if standing still
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
        
        -- Save for air resolver
        local on_ground = bit.band(entity.get_prop(idx, "m_fFlags"), 1) == 1
        if on_ground then
            data.last_ground_yaw = yaw
        end
    else
        plist.set(idx, "Force body yaw", false)
    end
end

-- ============================================================================
-- BODY AIM
-- ============================================================================
local function handle_baim(idx)
    local data = player_data[idx]
    if not data then return end
    
    local hp = entity.get_prop(idx, "m_iHealth")
    if not hp or hp <= 0 then return end
    
    local selected = ui.get(ui_baim_multi)
    
    if selected then
        for _, item in ipairs(selected) do
            if item == "HP lower than X value" then
                if hp <= ui.get(ui_baim_hp) then
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

-- ============================================================================
-- SAFEPOINT
-- ============================================================================
local function handle_safe(idx)
    local data = player_data[idx]
    if not data then return end
    
    local hp = entity.get_prop(idx, "m_iHealth")
    if not hp or hp <= 0 then return end
    
    local selected = ui.get(ui_safe_multi)
    local should_safe = false
    
    if selected then
        for _, item in ipairs(selected) do
            if item == "HP lower than X value" then
                if hp <= ui.get(ui_safe_hp) then
                    should_safe = true
                end
            end
            
            if item == "After X misses" then
                if data.misses >= ui.get(ui_safe_miss) then
                    should_safe = true
                end
            end
        end
    end
    
    plist.set(idx, "Override safe point", should_safe and "On" or "-")
end

-- ============================================================================
-- UI VISIBILITY
-- ============================================================================
local function update_ui()
    local main = ui.get(ui_main)
    
    ui.set_visible(ui_resolver, main)
    ui.set_visible(ui_baim_multi, main)
    ui.set_visible(ui_safe_multi, main)
    
    local baim_sel = ui.get(ui_baim_multi)
    local show_baim = false
    
    if baim_sel and main then
        for _, item in ipairs(baim_sel) do
            if item == "HP lower than X value" then
                show_baim = true
                break
            end
        end
    end
    ui.set_visible(ui_baim_hp, show_baim)
    
    local safe_sel = ui.get(ui_safe_multi)
    local show_hp, show_miss = false, false
    
    if safe_sel and main then
        for _, item in ipairs(safe_sel) do
            if item == "HP lower than X value" then
                show_hp = true
            end
            if item == "After X misses" then
                show_miss = true
            end
        end
    end
    ui.set_visible(ui_safe_hp, show_hp)
    ui.set_visible(ui_safe_miss, show_miss)
end

-- ============================================================================
-- EVENTS
-- ============================================================================
local function on_miss(e)
    local target = e.target
    if not target then return end
    
    local data = init_player(target)
    data.misses = data.misses + 1
end

local function on_hit(e)
    local target = e.target
    if not target then return end
    
    local data = player_data[target]
    if data then
        data.misses = 0
    end
end

local function on_death(e)
    local victim = client.userid_to_entindex(e.userid)
    if victim then
        player_data[victim] = nil
    end
end

local function reset_all()
    for i = 1, 64 do
        player_data[i] = nil
        plist.set(i, "Force body yaw", false)
        plist.set(i, "Override prefer body aim", "-")
        plist.set(i, "Override safe point", "-")
    end
end

-- ============================================================================
-- MAIN LOOP
-- ============================================================================
local function on_paint()
    if not ui.get(ui_main) then return end
    
    local players = entity.get_players(true)
    
    for _, player in ipairs(players) do
        if ui.get(ui_resolver) then
            resolve(player)
        end
        
        handle_baim(player)
        handle_safe(player)
    end
end

-- ============================================================================
-- REGISTER
-- ============================================================================
ui.set_callback(ui_main, update_ui)
ui.set_callback(ui_resolver, update_ui)
ui.set_callback(ui_baim_multi, update_ui)
ui.set_callback(ui_safe_multi, update_ui)

client.set_event_callback("paint", on_paint)
client.set_event_callback("aim_miss", on_miss)
client.set_event_callback("aim_hit", on_hit)
client.set_event_callback("player_death", on_death)
client.set_event_callback("round_start", reset_all)
client.set_event_callback("round_end", reset_all)

-- ESP
client.register_esp_flag("BAIM", 255, 100, 100, function(p)
    return plist.get(p, "Override prefer body aim") == "Force"
end)

client.register_esp_flag("SAFE", 100, 255, 100, function(p)
    return plist.get(p, "Override safe point") == "On"
end)

client.register_esp_flag("RES", 100, 180, 255, function(p)
    return plist.get(p, "Force body yaw")
end)

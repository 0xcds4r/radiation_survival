--[[
////////////////////////////////////////////////////////////////////////////////
//  
//  FILE:   "scripts/world.lua"
//  BY:     0xcds4r / MihailRis
//  FOR:    Radiation Survival Mod
//  ON:     16 Mar 2025
//  WHAT:   Core logic. Handles block breaking, radiation levels,
//          3D text display, particle effects, and health damage based on altitude.
//          + Now includes experience system for leveling up via block breaking.
//
////////////////////////////////////////////////////////////////////////////////
]]

print("-----------------------------------------------------")
print("          RADIATION SURVIVAL MOD                  ")
print("          Version 1.1-DEMO                        ")
print("          Powered by VoxelCore                    ")
print("          Inspired by MihailRis/base_survival     ")
print("-----------------------------------------------------")
print(" Survive the wasteland. Watch your health.        ")
print(" Radiation is your enemy. Stay low or perish.     ")
print("-----------------------------------------------------")

local base_util = require "base:util"
local gamemodes = require "gamemodes"

local breaking_blocks = {}
local radiation_levels = {} 
local text_ids = {}      
local particle_emitters = {}
local player_data = {}  
local initialized_players = {}  
_G.player_data = player_data 

local EXP_PER_BLOCK = 10   
local BASE_MAX_EXP = 100      
local EXP_GROWTH_FACTOR = 1.5 

local function get_durability(id)
    local durability = block.properties[id]["base:durability"]
    if durability ~= nil then
        return durability
    end
    if block.get_model(id) == "X" then
        return 0.0
    end
    return 5.0
end

local function stop_breaking(target)
    events.emit("radiation_survival:stop_destroy", pid, target)
    target.breaking = false
end

function etostring(tbl)
    local result = "{"
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            result = result .. k .. "=" .. table.tostring(v) .. ", "
        else
            result = result .. k .. "=" .. tostring(v) .. ", "
        end
    end
    return result .. "}"
end

function on_world_save()
    -- todo
end

function on_world_open()
    events.on("radiation_survival:gamemodes.set", function(pid, name)
        local entity = entities.get(player.get_entity(pid))
        if entity then
            entity:set_enabled("radiation_survival:health", name == "survival")
        end
    end)
    rules.create("keep-inventory", false)

    events.on("radiation_survival:clear_radiation_text", function(pid)
        if text_ids[pid] then
            gfx.text3d.hide(text_ids[pid])
            text_ids[pid] = nil
        end
        if particle_emitters[pid] and gfx.particles.is_alive(particle_emitters[pid]) then
            gfx.particles.stop(particle_emitters[pid])
            particle_emitters[pid] = nil
        end
    end)
    
    print("Radiation survival loaded with experience system")
end

local function tick_breaking(pid, tps)
    if player.get_entity(pid) == 0 then
        return
    end
    local gamemode = gamemodes.get(pid).current
    if gamemode ~= "survival" then
        return
    end
    local target = breaking_blocks[pid]
    if not target then
        target = {breaking=false}
        breaking_blocks[pid] = target
    end

    if input.is_active("player.destroy") then
        local x, y, z = player.get_selected_block(pid)
        local blockid = x and block.get(x, y, z)
        if target.breaking then
            if blockid ~= target.id or 
                x ~= target.x or y ~= target.y or z ~= target.z then
                return stop_breaking(target)
            end
        end
        if blockid == nil or blockid == 0 then
            return
        end
        
        local speed = 1.0 / math.max(get_durability(blockid), 1e-5)
        local power = 1.0
        local invid, slot = player.get_inventory(pid)
        local itemid, _ = inventory.get(invid, slot)
        local tool = item.properties[itemid]["radiation_survival:tool"]
        if tool and tool.type == "breaker" then
            local material = tool.materials[block.material(blockid)]
            if material then
                power = power * material.speed
            end
        end
        speed = speed * power

        if not target.breaking then
            target.breaking = true
            target.id = blockid
            target.x = x
            target.y = y
            target.z = z
            target.tick = 0
            target.progress = 0.0
            target.power = power
            events.emit("radiation_survival:start_destroy", pid, target)
        end

        target.progress = target.progress + (1.0/tps) * speed
        target.power = power
        target.tick = target.tick + 1
        if target.progress >= 1.0 then
            if x and y and z and pid then
                block.destruct(x, y, z, pid)
                if not player.is_infinite_items(pid) then
                    inventory.use(invid, slot)
                end
            end
            return stop_breaking(target)
        end
        events.emit("radiation_survival:progress_destroy", pid, target)
    elseif target.wrapper then
        stop_breaking(target)
    end
end

function on_player_tick(pid, tps)
    local player_uid = player.get_entity(pid)
    if player_uid == 0 then
        return
    end

    if not initialized_players[pid] then
        if not player_data[player_uid] then
            player_data[player_uid] = {
                level = 1,
                experience = 0,
                max_experience = BASE_MAX_EXP
            }
        end
        initialized_players[pid] = true
        print("Player " .. pid .. " initialized with UID: " .. player_uid)
    end

    tick_breaking(pid, tps)

    radiation_levels[pid] = radiation_levels[pid] or 0
    
    local cam = cameras.get("core:first-person")
    local player_pos = cam:get_pos()
    local dir = cam:get_front()
    local height = player_pos[2]
    
    if height < 50 then
        radiation_levels[pid] = 0
    elseif height <= 100 then
        radiation_levels[pid] = math.round((height - 50) * 2)
    else
        radiation_levels[pid] = 100
    end
    local radiation_level = radiation_levels[pid]

    local gamemode = gamemodes.get(pid).current
    if gamemode ~= "survival" then
        return
    end
    events.emit("radiation_survival:radiation_update", pid, radiation_level)
    
    local distance = 3.0
    local offset = {0.0, 0.55, 0}
    local text_pos = {
        player_pos[1] + dir[1] * distance + offset[1],
        player_pos[2] + dir[2] * distance + offset[2],
        player_pos[3] + dir[3] * distance + offset[3]
    }
    local normalized_radiation = radiation_level / 100
    local red_value = math.clamp(2 * (0.5 - math.abs(normalized_radiation - 0.5)), 0, 1)
    local green_value = math.clamp(2 * math.abs(normalized_radiation - 0.5), 0, 1)
    local color = {
        green_value,
        red_value,
        0,
        1
    }
    local preset = {
        display = "xy_free_billboard",
        color = color,
        scale = 0.05 / distance,
        render_distance = 64,
        xray_opacity = 0.5
    }
    
    if text_ids[pid] then
        gfx.text3d.set_pos(text_ids[pid], text_pos)
        gfx.text3d.set_text(text_ids[pid], "Radiation: " .. radiation_level)
        gfx.text3d.update_settings(text_ids[pid], preset)
    else
        text_ids[pid] = gfx.text3d.show(text_pos, "Radiation: " .. radiation_level, preset)
    end
    
    if radiation_level > 50 then
        if not particle_emitters[pid] or not gfx.particles.is_alive(particle_emitters[pid]) then
            local particle_preset = {
                texture = "radiation_fog",
                count = 20,
                lifetime = 3.0,
                velocity = {0, 0.5, 0},
                acceleration = {0, -2, 0},
                size = {0.5, 0.5, 0.5},
                spawn_spread = {1, 0.5, 1},
                color = {0.5, 1, 0.5, 0.8}
            }
            particle_emitters[pid] = gfx.particles.emit(player_pos, 20, particle_preset)
            health = gamemodes.get_player_health(pid)
            if health ~= nil then
                health.damage(radiation_level * 0.045)
            end
        else
            gfx.particles.set_origin(particle_emitters[pid], player_pos)
        end
    elseif particle_emitters[pid] and gfx.particles.is_alive(particle_emitters[pid]) then
        gfx.particles.stop(particle_emitters[pid])
        particle_emitters[pid] = nil
    end
end

function on_block_breaking(id, x, y, z, pid)
    local target = breaking_blocks[pid]
    if not target or not target.breaking then
        tick_breaking(pid, 20)
    end
end

function on_block_broken(id, x, y, z, pid)
    if pid == -1 then
        return
    end
    if gamemodes.get(pid).current ~= "survival" then
        return
    end
    local loot_table = base_util.block_loot(id)
    for _, loot in ipairs(loot_table) do
        base_util.drop({x + 0.5, y + 0.5, z + 0.5}, loot.item, loot.count, loot.data)
    end
    
    local player_uid = player.get_entity(pid)
    local cam = cameras.get("core:first-person")
    local pos = cam:get_pos()
    print("Block broken by player " .. pid .. " with UID: " .. player_uid)
    if player_uid ~= 0 then
        if not player_data[player_uid] then
            print("Warning: player_data[" .. player_uid .. "] not initialized")
            player_data[player_uid] = {level = 1, experience = 0, max_experience = BASE_MAX_EXP}
        end
        local data = player_data[player_uid]
        local current_exp = data.experience
        local max_exp = data.max_experience
        local level = data.level
        
        current_exp = current_exp + EXP_PER_BLOCK
        print("Experience increased: " .. current_exp .. "/" .. max_exp .. " for UID: " .. player_uid)
        
        while current_exp >= max_exp do
            current_exp = current_exp - max_exp
            level = level + 1
            max_exp = math.floor(BASE_MAX_EXP * (EXP_GROWTH_FACTOR ^ (level - 1)))
            data.level = level
            data.max_experience = max_exp
            audio.play_stream_2d(
                "sounds/events/level_up.ogg",
                1.0,
                1.0
            )
            print("Level up! New level: " .. level .. ", New max_exp: " .. max_exp)
        end
        
        data.experience = current_exp
        
        local env = gui.get_env("radiation_survival:experience_bar")
        if env and env.set_experience then
            env.set_experience(player_uid, current_exp, max_exp, level)
        else
            print("Error: Could not update experience HUD for UID: " .. player_uid)
        end
    else
        print("Error: Invalid player UID: " .. player_uid)
    end
end

function on_world_quit()
    for pid in pairs(radiation_levels) do
        if text_ids[pid] then
            text_ids[pid] = nil
        end
        if particle_emitters[pid] and gfx.particles.is_alive(particle_emitters[pid]) then
            gfx.particles.stop(particle_emitters[pid])
            particle_emitters[pid] = nil
        end
    end
    radiation_levels = {}
    breaking_blocks = {}
    player_data = {}
    initialized_players = {}
end
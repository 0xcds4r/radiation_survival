--[[
////////////////////////////////////////////////////////////////////////////////
//  
//  FILE:   "scripts/hud.lua"
//  BY:     0xcds4r / MihailRis
//  FOR:    Radiation Survival Mod
//  ON:     16 Mar 2025
//  WHAT:   Handles HUD elements, audio effects, and player death visuals.
//          Manages health bar, ambient sounds, Geiger counter, and block destruction feedback.
//          + Now includes experience bar management.
//
////////////////////////////////////////////////////////////////////////////////
]]

local gamemodes = require "gamemodes"
local survival_hud = require "survival_hud"
local exp_hud = require "exp_hud"

local death_ambient
local death_ambient2
local isdead = false
local geiger_sound = nil
local ambient_sound = nil

function on_hud_open()
    events.on("radiation_survival:gamemodes.set", function(playerid, name)
        if name == "survival" then
            hud.open_permanent("radiation_survival:health_bar")
            hud.open_permanent("radiation_survival:experience_bar")
            local entity = entities.get(player.get_entity(playerid))
            if not entity then
                return
            end
            local health = entity:get_component("radiation_survival:health")
            survival_hud.set_health(health.get_health())

            if playerid == hud.get_player() and not ambient_sound then
                ambient_sound = audio.play_stream_2d(
                    "sounds/ambient/ambience.ogg", 1.0, 0.3, "ambient", true
                )
            end
        else
            hud.close("radiation_survival:health_bar")
            hud.close("radiation_survival:experience_bar")
            if ambient_sound ~= nil then
                audio.stop(ambient_sound)
                ambient_sound = nil
            end
            if geiger_sound ~= nil then
                audio.stop(geiger_sound)
                geiger_sound = nil
            end
            events.emit("radiation_survival:clear_radiation_text", playerid)
        end
    end)
    events.on("radiation_survival:health.set", function(entity, health)
        if entity:get_uid() == player.get_entity(hud.get_player()) then
            survival_hud.set_health(health)
        end
    end)

    console.add_command("gamemode player:sel=$obj.id name:str=''", 
    "Set game mode",
    function (args, kwargs)
        local pid = args[1] or hud.get_player()
        local name = args[2]
        if #name == 0 then
            return "current game mode is ["..gamemodes.get(pid).current.."]"
        end
        if gamemodes.exists(name) then
            gamemodes.set(pid, name)
            return "set game mode to ["..name.."]"
        else
            return "error: game mode ["..name.."] does not exists"
        end
    end)

    events.on("radiation_survival:start_destroy", function(pid, target)
        target.wrapper = gfx.blockwraps.wrap(
            {target.x, target.y, target.z}, "cracks/cracks_0"
        )
    end)

    events.on("radiation_survival:progress_destroy", function(pid, target)
        local x = target.x
        local y = target.y
        local z = target.z
        gfx.blockwraps.set_texture(target.wrapper, string.format(
            "cracks/cracks_%s", math.floor(target.progress * 11)
        ))
        if target.tick % 4 == 0 then
            local material = block.materials[block.material(target.id)]
            audio.play_sound(
                target.power >= 1.2 and
                    material.hitSound or
                    material.stepsSound, 
                x + 0.5, y + 0.5, z + 0.5,
                1.0, 0.9 + math.random() * 0.2, "regular"
            )
            local cam = cameras.get("core:first-person")
            local front = cam:get_front()
            local ray = block.raycast(cam:get_pos(), front, 64.0)
            gfx.particles.emit(ray.endpoint, 4, {
                lifetime=1.0,
                spawn_interval=0.0001,
                explosion={3, 3, 3},
                velocity=vec3.add(vec3.mul(front, -1.0), {0, 0.5, 0}),
                texture="blocks:"..block.get_textures(target.id)[1],
                random_sub_uv=0.1,
                size={0.1, 0.1, 0.1},
                size_spread=0.2,
                spawn_shape="box",
                collision=true
            })
        end
    end)

    events.on("radiation_survival:stop_destroy", function(pid, target)
        gfx.blockwraps.unwrap(target.wrapper)
    end)

    events.on("radiation_survival:player_death", function(pid, just_happened)
        if just_happened then
            local pos = cameras.get(player.get_camera(pid)):get_pos()
            audio.play_sound(
                "events/huge_damage",
                pos[1], pos[2], pos[3],
                1.0, 
                0.8 + math.random() * 0.4, 
                "regular"
            )
        end
        if pid ~= hud.get_player() then
            return
        end
        isdead = true
        exp_hud.on_death()
        hud.close_inventory()
        if just_happened then
            local px, py, pz = player.get_pos(pid)
            player.set_pos(pid, px, py - 0.7, pz)
        end
        gui.alert("You are dead", function ()
            player.set_pos(pid, player.get_spawnpoint(pid))
            player.set_rot(pid, 0, 0, 0)
            player.set_entity(pid, -1)
            menu:reset()

            audio.stop(death_ambient)
            death_ambient = nil
            audio.stop(death_ambient2)
            death_ambient2 = nil

            isdead = false

            if geiger_sound ~= nil then
                audio.stop(geiger_sound)
                geiger_sound = nil
            end
        end)
        death_ambient = audio.play_stream_2d(
            "sounds/ambient/death.ogg", 1.0, 0.5, "ambient", true
        )
        death_ambient2 = audio.play_stream_2d(
            "sounds/ambient/radiation.ogg", 1.0, 1.0, "ambient", true
        )
    end)
    events.on("radiation_survival:player_damage", function(pid, points)
        if pid ~= hud.get_player() then
            return
        end
        audio.play_sound_2d(
            "events/damage", 0.5, 1.0 + math.random() * 0.4, "regular"
        )
        local x, y, z = player.get_rot(pid)
        player.set_rot(pid, x, y, math.random() < 0.5 and 13 or -13)
    end)
    events.on("radiation_survival:radiation_update", function(pid, radiation_level)
        if pid ~= hud.get_player() then
            return
        end
        if radiation_level > 50 then
            if not geiger_sound then
                geiger_sound = audio.play_stream_2d(
                    "sounds/ambient/geyger.ogg", 1.0, 0.5, "ambient", true
                )
            end
        elseif geiger_sound then
            audio.stop(geiger_sound)
            geiger_sound = nil
        end
    end)
end

function on_hud_render()
    local pid = hud.get_player()
    if gamemodes.is_dead(pid) then
        if not isdead then
            events.emit("radiation_survival:player_death", pid)
        end
        local rx, ry, rz = player.get_rot(pid)
        local t = time.delta() * 75
        player.set_rot(pid, rx, ry, rz * (1.0 - t) + 45 * t)
    else
        local x, y, z = player.get_rot(pid)
        local dt = math.min(time.delta() * 12, 1.0)
        player.set_rot(pid, x, y, z * (1.0 - dt)) 
    end
end

function on_hud_close()
    if death_ambient then
        audio.stop(death_ambient)
        death_ambient = nil
    end
    if death_ambient2 then
        audio.stop(death_ambient2)
        death_ambient2 = nil
    end
    if geiger_sound then
        audio.stop(geiger_sound)
        geiger_sound = nil
    end
    if ambient_sound then
        audio.stop(ambient_sound)
        ambient_sound = nil
    end
end
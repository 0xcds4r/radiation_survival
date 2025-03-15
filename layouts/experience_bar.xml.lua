--[[
////////////////////////////////////////////////////////////////////////////////
//  
//  FILE:   "layouts/experience_bar.xml.lua"
//  BY:     0xcds4r
//  FOR:    Radiation Survival Mod
//  ON:     16 Mar 2025
//  WHAT:   Manages the experience bar display.
//          Updates HUD trackbar and level label based on player experience values.
//
////////////////////////////////////////////////////////////////////////////////
]]

local player_data = _G.player_data
local player_uid = nil
local exp_hud = require "exp_hud"

function set_experience(uid, exp, max_exp, level)
    if not document then
        print("Error: HUD document not available")
        return
    end
    document.experience_bar.max = max_exp
    document.experience_bar.value = exp
    document.level_label.text = "Lv " .. level
    print("Experience HUD updated: " .. exp .. "/" .. max_exp .. ", Level: " .. level)
end

function exp_hud.on_death()
    local pid = hud.get_player()
    player_uid = player.get_entity(pid)
    if player_uid and player_data[player_uid] then
        local data = player_data[player_uid]
        set_experience(player_uid, 0, 100, 1)
    else
        print("Error: No player_uid or player_data for UID: " .. (player_uid or "nil"))
    end
end

function on_open()
    local pid = hud.get_player()
    player_uid = player.get_entity(pid)
    if player_uid and player_data[player_uid] then
        local data = player_data[player_uid]
        set_experience(player_uid, data.experience, data.max_experience, data.level)
        print("Experience HUD initialized for UID: " .. player_uid)
    else
        print("Error: No player_uid or player_data for UID: " .. (player_uid or "nil"))
    end
end
-- BallDrop
-- by BigTuna76
-- A Lua Script for the Stand mod menu for GTA5
-- A silly utility that unleashed hordes of oversized soccer balls
-- Special thanks to hexarobi for allowing me to steal much of the content of this script
-- https://github.com/bigtuna/stand-lua-balldrop

local SCRIPT_VERSION = "0.1"
local AUTO_UPDATE_BRANCHES = {
    { "main", {}, "More stable, but updated less often.", "main", },
    { "dev", {}, "Cutting edge updates, but less stable.", "dev", },
}
local SELECTED_BRANCH_INDEX = 2
local selected_branch = AUTO_UPDATE_BRANCHES[SELECTED_BRANCH_INDEX][1]

---
--- Auto-Updater Lib Install
---

-- Auto Updater from https://github.com/hexarobi/stand-lua-auto-updater
local status, auto_updater = pcall(require, "auto-updater")
if not status then
    local auto_update_complete = nil util.toast("Installing auto-updater...", TOAST_ALL)
    async_http.init("raw.githubusercontent.com", "/hexarobi/stand-lua-auto-updater/main/auto-updater.lua",
            function(result, headers, status_code)
                local function parse_auto_update_result(result, headers, status_code)
                    local error_prefix = "Error downloading auto-updater: "
                    if status_code ~= 200 then util.toast(error_prefix..status_code, TOAST_ALL) return false end
                    if not result or result == "" then util.toast(error_prefix.."Found empty file.", TOAST_ALL) return false end
                    filesystem.mkdir(filesystem.scripts_dir() .. "lib")
                    local file = io.open(filesystem.scripts_dir() .. "lib\\auto-updater.lua", "wb")
                    if file == nil then util.toast(error_prefix.."Could not open file for writing.", TOAST_ALL) return false end
                    file:write(result) file:close() util.toast("Successfully installed auto-updater lib", TOAST_ALL) return true
                end
                auto_update_complete = parse_auto_update_result(result, headers, status_code)
            end, function() util.toast("Error downloading auto-updater lib. Update failed to download.", TOAST_ALL) end)
    async_http.dispatch() local i = 1 while (auto_update_complete == nil and i < 40) do util.yield(250) i = i + 1 end
    if auto_update_complete == nil then error("Error downloading auto-updater lib. HTTP Request timeout") end
    auto_updater = require("auto-updater")
end
if auto_updater == true then error("Invalid auto-updater lib. Please delete your Stand/Lua Scripts/lib/auto-updater.lua and try again") end

local auto_update_config = {
    source_url="https://raw.githubusercontent.com/bigtuna/stand-lua-balldrop/main/BallDrop.lua",
    script_relpath=SCRIPT_RELPATH,
    switch_to_branch=selected_branch,
    verify_file_begins_with="--",
    check_interval=604800,
    dependencies={}
}

-- local update_success
-- if config.auto_update then
--     update_success = auto_updater.run_auto_update(auto_update_config)
-- end

util.require_natives(1651208000)

local config = {
    ball_lifetime = 20000,
    hail_delay = 100,
    max_rain_distance = 3,
    min_rain_height = 1,
    max_rain_height = 30
}

local spawned_objects = {}

local ball_models = {
    "stt_prop_stunt_soccer_sball",
    "stt_prop_stunt_soccer_lball",
    "stt_prop_stunt_soccer_ball"
}

local function get_random_ball()
    return ball_models[math.random(1, #ball_models)]
end

local function get_drop_range()
    return {
        x_max=config.max_rain_distance, y_max=config.max_rain_distance, z_max=config.max_rain_height,
        x_min=config.max_rain_distance * -1, y_min=config.max_rain_distance * -1, z_min=config.min_rain_height,
    }
end

local function load_hash(hash)
    STREAMING.REQUEST_MODEL(hash)
    while not STREAMING.HAS_MODEL_LOADED(hash) do
        util.yield()
    end
end

local function delete_spawned_object(spawned_object)
    if spawned_object.pilot_handle then
        entities.delete_by_handle(spawned_object.pilot_handle)
    end
    entities.delete_by_handle(spawned_object.handle)
end

local function cleanup_spawned_objects()
    local current_time = util.current_time_millis()
    for i, spawned_object in pairs(spawned_objects) do
        local lifetime = current_time - spawned_object.spawn_time
        local allowed_lifetime = config.ball_lifetime
        if spawned_object.ttl ~= nil then
            allowed_lifetime = spawned_object.ttl
        end
        if lifetime > allowed_lifetime then
            delete_spawned_object(spawned_object)
            table.remove(spawned_objects, i)
            if spawned_object.respawn_function then
                spawned_object.respawn_function(spawned_object.pid)
            end
        end
    end
end

local function spawn_object_at_pos(pos, model, ttl)
    local pickup_hash = util.joaat(model)
    load_hash(pickup_hash)
    local pickup_pos = v3.new(pos.x, pos.y, pos.z)
    local pickup = entities.create_object(pickup_hash, pickup_pos)
    ENTITY.SET_ENTITY_COLLISION(pickup, true, true)
    ENTITY.APPLY_FORCE_TO_ENTITY_CENTER_OF_MASS(
        pickup, 5, 0, 0, 1,
        true, false, true, true
    )
    table.insert(spawned_objects, { handle=pickup, spawn_time=util.current_time_millis(), ttl=ttl})
end

local function nearby_position(pos, range)
    if range == nil then
        range = {
            x_max=1, y_max=1, z_max=1,
            x_min=-1, y_min=-1, z_min=0,
        }
    end
    return {
        x=pos.x + math.random(range.x_min, range.x_max),
        y=pos.y + math.random(range.y_min, range.y_max),
        z=pos.z + math.random(range.z_min, range.z_max),
    }
end

local function ball_drop(position, range, model, ttl)
    local spawn_position = position
    if range then
        spawn_position = nearby_position(position, range)
    end
    if model == nil then
        model = get_random_ball()
    end
    spawn_object_at_pos(spawn_position, model, ttl)
end

local function ball_drop_player(pid, range)
    ball_drop(players.get_position(pid), range)
end

local function ball_drop_vehicle(vehicle, range)
    ball_drop(ENTITY.GET_ENTITY_COORDS(vehicle), range)
end

local function balldrop_player(pid)
    ball_drop_player(pid, get_drop_range())
end

menu.action(menu.my_root(), "Drop the Ball", {"balldrop"}, "Drop a single ball", function()
    ball_drop(players.get_position(players.user()), get_drop_range())
end)

menu.toggle_loop(menu.my_root(), "Unleash the Chaos", {"ballhail"}, "Drop all the balls", function()
    balldrop_player(players.user())
    util.yield(config.hail_delay)
end)

player_menu_actions = function(pid)
    menu.divider(menu.player_root(pid), "Balls!")

    menu.action(menu.player_root(pid), "Drop the Ball", {"balldrop"}, "", function()
        balldrop_player(pid)
    end)

    menu.toggle_loop(menu.player_root(pid), "Unleash Chaos", {"ballhail"}, "", function()
        balldrop_player(pid)
        util.yield(config.hail_delay)
    end)

end
players.on_join(player_menu_actions)
players.dispatch_on_join()


local options_menu = menu.list(menu.my_root(), "Options")

menu.slider(options_menu, "Ball Drop Delay", {}, "The time between each ball drop", 30, 500, config.hail_delay, 10, function (value)
    config.hail_delay = value
end)

menu.slider(options_menu, "Ball Lifetime", {}, "How long a dropped ball should live before being despawned", 500, 60000, config.ball_lifetime, 250, function (value)
    config.ball_lifetime = value
end)

menu.slider(options_menu, "Ball Distance", {}, "Max distance of balls from the player", 1, 20, config.max_rain_distance, 1, function (value)
    config.max_rain_distance = value
end)
menu.slider(options_menu, "Max Ball Height", {}, "Max height of balls", 1, 30, config.max_rain_distance, 1, function (value)
    config.max_rain_height = value
end)
menu.slider(options_menu, "Min Ball Height", {}, "Min height of balls", 0, 20, config.min_rain_height, 1, function (value)
    config.min_rain_height = value
end)

---
--- Script Meta
---

local script_meta_menu = menu.list(menu.my_root(), "Script Meta")

menu.divider(script_meta_menu, SCRIPT_NAME:gsub(".lua", ""))
menu.readonly(script_meta_menu, "Version", SCRIPT_VERSION)
--menu.hyperlink(script_meta_menu, "Source", "https://github.com/bigtuna/stand-lua-ballchaos", "View source on Github")


util.create_tick_handler(function()
    if spawned_objects then
        cleanup_spawned_objects()
    end
    return true
end)


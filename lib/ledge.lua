local setmetatable, require, error =
    setmetatable, require, error

local ngx_get_phase = ngx.get_phase

local tbl_copy = require("ledge.util").table.copy

local fixed_field_metatable = require("ledge.util").mt.fixed_field_metatable
local get_fixed_field_metatable_proxy = require("ledge.util").mt.get_fixed_field_metatable_proxy


local _M = {
    _VERSION = '1.29.3',
}


local params = setmetatable({
    -- Default Redis metadata connection params
    redis_params = setmetatable({
        connect_timeout = 500,      -- (ms)
        read_timeout = 5000,        -- (ms)
        keeapalive_timeout = 60000, -- (ms)
        keepalive_poolsize = 30,
        redis_connector = {
            url = "redis://127.0.0.1:6379/0",
        },
        qless_db = 2,
    }, fixed_field_metatable),

    -- Default storage driver params
    storage_driver = require("ledge.storage.redis"),
    storage_params = setmetatable({
        connect_timeout = 500,      -- (ms)
        read_timeout = 5000,        -- (ms)
        keeapalive_timeout = 60000, -- (ms)
        keepalive_poolsize = 30,
        redis_connector = {
            url = "redis://127.0.0.1:6379/3",
        },
    }, fixed_field_metatable),
}, fixed_field_metatable)


local function set(param, value)
    if ngx_get_phase() ~= "init" then
        error("attempt to set params outside of the 'init' phase", 2)
    else
        if type(value) == "table" then
            -- Apply defaults to this table, in case of gaps in the user
            -- supplied value
            params[param] = setmetatable(
                value,
                get_fixed_field_metatable_proxy(params[param])
            )
        else
            params[param] = value
        end
    end
end
_M.set = set


local function get(param)
    local v = params[param]
    -- Config is immutable directly, so always return by value
    if type(v) == "table" then
        return tbl_copy(v)
    else
        return v
    end
end
_M.get = get


local function create_worker(config)
    return require("ledge.worker").new(config)
end
_M.create_worker = create_worker


local function create_handler(config)
    return { run = function() return nil end }
end
_M.create_handler = create_handler


local function create_redis_connection()
end
_M.create_redis_connection = create_redis_connection


local function close_redis_connection(redis)
end
_M.close_redis_connection = close_redis_connection


local function create_storage_connection()
end
_M.create_storage_connection = create_storage_connection


local function close_storage_connection(storage)
end
_M.close_storage_connection = close_storage_connection


return setmetatable(_M, fixed_field_metatable)

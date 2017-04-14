local ffi = require "ffi"

local type, next, setmetatable, getmetatable =
        type, next, setmetatable, getmetatable

local str_gmatch = string.gmatch
local tbl_insert = table.insert
local co_create = coroutine.create
local co_status = coroutine.status
local co_resume = coroutine.resume
local math_floor = math.floor
local ffi_cdef = ffi.cdef
local ffi_new = ffi.new
local ffi_string = ffi.string
local C = ffi.C


ffi_cdef[[
typedef unsigned char u_char;
u_char * ngx_hex_dump(u_char *dst, const u_char *src, size_t len);
int RAND_pseudo_bytes(u_char *buf, int num);
]]


local _M = {
    _VERSION = "1.28.3",
    string = {},
    table = {},
    mt = {},
    coroutine = {},
}


local function randomhex(len)
    local len = math_floor(len / 2)

    local bytes = ffi_new("uint8_t[?]", len)
    C.RAND_pseudo_bytes(bytes, len)
    if not bytes then
        return nil, "error getting random bytes via FFI"
    end

    local hex = ffi_new("uint8_t[?]", len * 2)
    C.ngx_hex_dump(hex, bytes, len)
    return ffi_string(hex, len * 2)
end
_M.string.randomhex = randomhex


local function tbl_copy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[tbl_copy(orig_key)] = tbl_copy(orig_value)
        end
        setmetatable(copy, tbl_copy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end
_M.table.copy = tbl_copy


-- A metatable which prevents undefined fields from being created / accessed
local fixed_field_metatable = {
    __index =
        function(t, k)
            error("field " .. tostring(k) .. " does not exist", 3)
        end,
    __newindex =
        function(t, k, v)
            error("attempt to create new field " .. tostring(k), 3)
        end,
}
_M.mt.fixed_field_metatable = fixed_field_metatable


-- Returns a metatable with fixed fields (as above), which when applied to a
-- table will provide default values via the provided `proxy`. E.g:
--
-- defaults = { a = 1, b = 2, c = 3 }
-- t = setmetatable({ b = 4 }, get_fixed_field_metatable_proxy(defaults))
--
-- `t` now gives: { a = 1, b = 4, c = 3 }
--
-- @param   table   proxy table
-- @return  table   metatable
local function get_fixed_field_metatable_proxy(proxy)
    return {
        __index =
            function(t, k)
                local proxy_v = proxy[k]
                if not proxy_v then
                    error("field " .. tostring(k) .. " does not exist", 3)
                else
                    return proxy_v
                end
            end,
        __newindex =
            function(t, k, v)
                local proxy_v = proxy[k]
                if not proxy_v then
                    error("attempt to create new field " .. tostring(k), 3)
                else
                    return rawset(t, k, v)
                end
            end,
    }
end
_M.mt.get_fixed_field_metatable_proxy = get_fixed_field_metatable_proxy


local function str_split(str, delim)
    if not str or not delim then return nil end
    local it, err = str_gmatch(str, "([^"..delim.."]+)")
    if it then
        local output = {}
        while true do
            local m, err = it()
            if not m then
                break
            end
            tbl_insert(output, m)
        end
        return output
    end
end
_M.string.split = str_split


local function co_wrap(func)
    local co = co_create(func)
    if not co then
        return nil, "could not create coroutine"
    else
        return function(...)
            if co_status(co) == "suspended" then
                return select(2, co_resume(co, ...))
            else
                return nil, "can't resume a " .. co_status(co) .. " coroutine"
            end
        end
    end
end
_M.coroutine.wrap = co_wrap


return _M

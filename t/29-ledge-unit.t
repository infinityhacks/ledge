use Test::Nginx::Socket;
use Cwd qw(cwd);

plan tests => repeat_each() * (blocks() * 2) + 1;

my $pwd = cwd();

$ENV{TEST_LEDGE_REDIS_DATABASE} |= 2;
$ENV{TEST_LEDGE_REDIS_QLESS_DATABASE} |= 3;
$ENV{TEST_USE_RESTY_CORE} ||= 'nil';
$ENV{TEST_COVERAGE} ||= 0;

our $HttpConfig = qq{
lua_package_path "$pwd/../lua-ffi-zlib/lib/?.lua;$pwd/../lua-resty-redis-connector/lib/?.lua;$pwd/../lua-resty-qless/lib/?.lua;$pwd/../lua-resty-http/lib/?.lua;$pwd/../lua-resty-cookie/lib/?.lua;$pwd/lib/?.lua;/usr/local/share/lua/5.1/?.lua;;";

init_by_lua_block {
    if $ENV{TEST_COVERAGE} == 1 then
        jit.off()
        require("luacov.runner").init()
    end

    local ledge = require("ledge")

    ledge.set("redis_params", {
        redis_connection = {
            db = $ENV{TEST_LEDGE_REDIS_DATABASE},
        },
        qless_db = $ENV{TEST_LEDGE_REDIS_QLESS_DATABASE},
    })
}

init_worker_by_lua_block {
    require("ledge").create_worker():run()
}

}; # HttpConfig


our $HttpConfigTest3 = qq{
lua_package_path "$pwd/../lua-ffi-zlib/lib/?.lua;$pwd/../lua-resty-redis-connector/lib/?.lua;$pwd/../lua-resty-qless/lib/?.lua;$pwd/../lua-resty-http/lib/?.lua;$pwd/../lua-resty-cookie/lib/?.lua;$pwd/lib/?.lua;/usr/local/share/lua/5.1/?.lua;;";
init_by_lua_block {
    if $ENV{TEST_COVERAGE} == 1 then
        jit.off()
        require("luacov.runner").init()
    end

    -- Set the error so we can trap it later
    local ledge = require("ledge")
    ok, err = pcall(ledge.set, "foo", "bar")
}

}; # HttpConfigTest3

no_long_string();
no_diff();
run_tests();


__DATA__
=== TEST 1: Load module without errors.
--- http_config eval: $::HttpConfig
--- config
location /ledge_1 {
    content_by_lua_block {
        assert(require("ledge"))
    }
}
--- request
GET /ledge_1
--- no_error_log
[error]


=== TEST 2: Module cannot be externally modified
--- http_config eval: $::HttpConfig
--- config
location /ledge_2 {
    content_by_lua_block {
        local ledge = require("ledge")
        ledge.foo = "bar"
    }
}
--- request
GET /ledge_2
--- error_log
attempt to create new field foo
--- error_code: 500


=== TEST 3: Non existent params cannot be set
--- http_config eval: $::HttpConfigTest3
--- config
location /ledge_4 {
    content_by_lua_block {
        error(err)
    }
}
--- request
GET /ledge_4
--- error_log
attempt to create new field foo
--- error_code: 500


=== TEST 4: Params cannot be set outside of init
--- http_config eval: $::HttpConfig
--- config
location /ledge_4 {
    content_by_lua_block {
        local ledge = require("ledge")
        ledge.set("foo", bar)
    }
}
--- request
GET /ledge_4
--- error_log
attempt to set params outside of the 'init' phase
--- error_code: 500


=== TEST 5: Table param values are returned by value
--- http_config eval: $::HttpConfig
--- config
location /ledge_5 {
    content_by_lua_block {
        local redis_params = require("ledge").get("redis_params")
        ngx.say(redis_params.connect_timeout)

        -- Change by value
        redis_params.connect_timeout = 10
        ngx.say(redis_params.connect_timeout)

        -- Original is unmodified
        ngx.say(require("ledge").get("redis_params").connect_timeout)
    }
}
--- request
GET /ledge_5
--- response_body
500
10
500
--- no_error_log
[error]
--- error_code: 200

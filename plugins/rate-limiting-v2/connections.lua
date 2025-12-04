local redis = require "resty.redis"
local kong = kong

local redis_host = os.getenv("REDIS_HOST") or "localhost"
local redis_port = os.getenv("REDIS_PORT") or 6379
local redis_keepalive = os.getenv("REDIS_KEEPALIVE") or 30000

local sock_opts = {
    pool = "rate-limiting-v2",
    pool_size = 8,
}

return {
    get_redis_connection = function(conf)
        local redis_connect_timeout = conf.redis_connect_timeout
        local redis_write_timeout = conf.redis_write_timeout
        local redis_read_timeout = conf.redis_read_timeout

        local red = redis:new()
        red:set_timeouts(redis_connect_timeout, redis_write_timeout, redis_read_timeout)

        local ok, err = red:connect(redis_host, redis_port, sock_opts)
        if not ok then
            kong.log.err("failed to connect to Redis: ", err)
            return nil, err
        end

        return red
    end,
    set_keepalive = function(red)
        local ok, err = red:set_keepalive(redis_keepalive)
        if not ok then
            kong.log.err("failed to set Redis keepalive: ", err)
            return nil, err
        end

        return ok
    end,
}

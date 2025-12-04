local timestamp = require "kong.tools.timestamp"
local EXPIRATION = require "kong.plugins.rate-limiting-v2.expiration"
local connections = require "kong.plugins.rate-limiting-v2.connections"
local utils = require "kong.plugins.rate-limiting-v2.utils"

local kong = kong
local shm = ngx.shared.kong_rate_limiting_counters
local fmt = string.format

local function get_local_key(conf, identifier, period_date)
    local service_id, route_id = utils.get_service_and_route_ids(conf)
    return fmt("ratelimit:%s:%s:%s:%s:%s", route_id, service_id, identifier, period_date, conf.period)
end

local function get_limit_exceeded_key(conf, identifier, period_date)
    local service_id, route_id = utils.get_service_and_route_ids(conf)
    return fmt("ratelimit_limit_exceeded:%s:%s:%s:%s:%s", route_id, service_id, identifier, period_date, conf.period)
end

local function is_limit_exceeded(conf, identifier, period_date)
    local limit_exceeded_key = get_limit_exceeded_key(conf, identifier, period_date)
    local limit_exceeded, _ = shm:get(limit_exceeded_key)

    if not limit_exceeded then
        return nil
    else
        return conf.limit + 1
    end

end

local function set_limit_exceeded_flag(conf, redis_hit_count, identifier, period_date)
    local limit_exceeded_key = get_limit_exceeded_key(conf, identifier, period_date)
    if redis_hit_count > conf.limit then
        local ok, err = shm:set(limit_exceeded_key, true, EXPIRATION[conf.period])
        if not ok then
            kong.log.err("Could not set rate-limiting exceeded flag in shm: ", err)
            return nil, err
        end
        return ok
    end
end

local function batch_update_redis(conf, cache_key, period)
    local red, err = connections.get_redis_connection(conf)
    if not red then
        return nil, err
    end

    local redis_hit_count, incr_err = red:incrby(cache_key, conf.batch_size)
    if not redis_hit_count then
        kong.log.err("Could not increment counter for period '", period, "' ", incr_err)
        return nil, incr_err
    end

    if redis_hit_count == conf.batch_size then
        red:expire(cache_key, EXPIRATION[period])
    end

    local success, shm_err = shm:set(cache_key, redis_hit_count, EXPIRATION[period])
    if not success then
        kong.log.err("Could not set rate-limiting counter in SHM for period '", period, "': ", shm_err)
        return nil, shm_err
    end

    local _, _ = connections.set_keepalive(red)
end

return {
    ["local"] = {
        increment = function(conf, identifier, current_timestamp)
            local periods = timestamp.get_timestamps(current_timestamp)
            local cache_key = get_local_key(conf, identifier, periods[conf.period])
            local node_hit_count, err = shm:incr(cache_key, 1, 0, EXPIRATION[conf.period])
            if not node_hit_count then
                kong.log.err("Could not increment counter for period '", conf.period, "' ", err)
                return nil, err, 1
            end
            return node_hit_count
        end,
    },
    ["redis"] = {
        increment = function(conf, identifier, current_timestamp)
            local red, err = connections.get_redis_connection(conf)
            if not red then
                return nil, err, 1
            end

            local periods = timestamp.get_timestamps(current_timestamp)
            local hit_count = is_limit_exceeded(conf, identifier, periods[conf.period])
            if hit_count then
                return hit_count
            end
            local cache_key = get_local_key(conf, identifier, periods[conf.period])
            local redis_hit_count, incr_err = red:incrby(cache_key, 1)
            if not redis_hit_count then
                kong.log.err("Could not increment counter for period '", conf.period, "' ", incr_err)
                return nil, incr_err, 1
            end
            if redis_hit_count == 1 then
                red:expire(cache_key, EXPIRATION[conf.period])
            end

            set_limit_exceeded_flag(conf, redis_hit_count, identifier, periods[conf.period])
            local _, _ = connections.set_keepalive(red)
            return redis_hit_count
        end,
    },
    ["batch-redis"] = {
        increment = function(conf, identifier, current_timestamp)
            local periods = timestamp.get_timestamps(current_timestamp)
            local hit_count = is_limit_exceeded(conf, identifier, periods[conf.period])
            if hit_count then
                return hit_count
            end

            local cache_key = get_local_key(conf, identifier, periods[conf.period])
            local node_hit_count, err = shm:incr(cache_key, 1, 0, EXPIRATION[conf.period])
            if not node_hit_count then
                kong.log.err("Could not set rate-limiting counter in SHM for period '", conf.period, "': ", err)
                return nil, err, 1
            end

            set_limit_exceeded_flag(conf, node_hit_count, identifier, periods[conf.period])

            -- Update Redis if batch completed
            if node_hit_count % conf.batch_size == 0 then
                local _, batch_update_err = batch_update_redis(conf, cache_key, conf.period)
                if batch_update_err then
                    return nil, batch_update_err, conf.batch_size
                end
            end
            return node_hit_count
        end,
    },
}

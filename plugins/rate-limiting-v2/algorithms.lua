local policies = require "kong.plugins.rate-limiting-v2.policies"
local connections = require "kong.plugins.rate-limiting-v2.connections"
local utils = require "kong.plugins.rate-limiting-v2.utils"
local kong = kong
local fmt = string.format
local time = ngx.time

local get_leaky_bucket_key = function(conf, identifier)
    local service_id, route_id = utils.get_service_and_route_ids(conf)
    return fmt("ratelimit:%s:%s:%s", route_id, service_id, identifier)
end

return {
    ["leaky-bucket"] = {
        increment = function(conf, identifier)
            local red, err = connections.get_redis_connection(conf)

            if not red then
                return nil, err, 1
            end

            local cache_key = get_leaky_bucket_key(conf, identifier)
            local current_usage, incr_err = red:incrby(cache_key, 1)

            if incr_err then
                kong.log.err("Could not increment counter for identifier '", identifier, "' ", incr_err)
                return nil, incr_err, 1
            end

            local _, _ = connections.set_keepalive(red)

            return current_usage
        end,
        decrement = function(conf, identifier, decrement_by)
            local red, err = connections.get_redis_connection(conf)

            if not red then
                return nil, err
            end

            local cache_key = get_leaky_bucket_key(conf, identifier)
            local redis_hit_count, decr_err = red:decrby(cache_key, decrement_by)

            if decr_err then
                kong.log.err("Could not decrement counter for identifier '", identifier, "' ", decr_err)
                return nil, decr_err
            end

            local _, _ = connections.set_keepalive(red)
            return redis_hit_count
        end,
    },
    ["fixed-window"] = {
        increment = function(conf, identifier)
            local current_timestamp = time() * 1000

            local current_usage, err, err_count = policies[conf.policy].increment(conf, identifier, current_timestamp)
            if err then
                return nil, err, err_count
            end

            return current_usage
        end,
    },
}

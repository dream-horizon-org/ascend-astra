local algorithms = require "kong.plugins.rate-limiting-v2.algorithms"

local kong = kong
local ngx = ngx
local timer_at = ngx.timer.at
local tostring = tostring

local EMPTY = {}

local RateLimitingV2Handler = {
    PRIORITY = 960,
    VERSION = "1.0.0",
    DECREMENT_FAILURES = {},
}

local RATE_LIMITING_ERROR = "rate_limiting.error"
local COUNTER_TYPE = "c"
local FIXED_WINDOW_ALGORITHM = "fixed-window"
local TAG_KEY_CAUSE = "cause"
local COLON = ":"
local CAUSE_NO_IDENTIFIER = "no-identifier"
local CAUSE_INCREMENT_FAILED = "increment-failed"
local TAG_KEY_ALGORITHM = "algorithm"

local CONTENT_TYPE = "Content-Type"

local function set_metric(tags, stat_name, stat_type, stat_value, sample_rate)
    if kong.ctx.shared.logger_metrics == nil then
        kong.ctx.shared.logger_metrics = {}
    end

    table.insert(kong.ctx.shared.logger_metrics, {
        tags = tags,
        stat_name = stat_name,
        stat_type = stat_type,
        stat_value = stat_value,
        sample_rate = sample_rate,
    })
end

local function get_identifier(conf)
    local identifier

    if conf.limit_by == "service" then
        identifier = (kong.router.get_service() or EMPTY).id
    elseif conf.limit_by == "header" then
        identifier = kong.request.get_header(conf.header_name)
    end

    if not identifier then
        return nil, "No rate-limiting identifier found in request"
    end

    return identifier
end

local function increment_counter(conf, identifier)
    local usage = {}
    local stop
    local limit = conf.limit
    local current_usage, err, err_count = algorithms[conf.algorithm].increment(conf, identifier)
    if err then
        kong.ctx.shared.rate_limit.err_count = err_count
        return nil, nil, err
    end
    current_usage = current_usage or 0
    local remaining = limit - current_usage

    usage[conf.period] = {
        limit = conf.limit,
        remaining = remaining,
    }

    if current_usage > limit then
        stop = true
    end

    return usage, stop
end

local function decrement_counter(premature, conf, identifier, decrement_by)
    if premature then
        return
    end

    local current_usage, err = algorithms[conf.algorithm].decrement(conf, identifier, decrement_by)
    if err then
        -- Todo: Maybe change the metric name to something else, as this is specific to leaky
        RateLimitingV2Handler.DECREMENT_FAILURES[identifier] = decrement_by
        kong.log.err("failed to decrement counter: ", tostring(err))
        return nil, err
    end

    return current_usage
end

function RateLimitingV2Handler:access(conf)
    kong.ctx.shared.rate_limit = {}

    local identifier, err = get_identifier(conf)

    if err then
        set_metric({
            TAG_KEY_CAUSE .. COLON .. CAUSE_NO_IDENTIFIER,
        }, RATE_LIMITING_ERROR, COUNTER_TYPE, 1, 1)
        kong.log.err(err)
        return
    end

    local usage, stop, incr_err = increment_counter(conf, identifier)
    if incr_err then
        set_metric({
            TAG_KEY_CAUSE .. COLON .. CAUSE_INCREMENT_FAILED,
            TAG_KEY_ALGORITHM .. COLON .. conf.algorithm,
        }, RATE_LIMITING_ERROR, COUNTER_TYPE, kong.ctx.shared.rate_limit.err_count, 1)
        kong.log.err("failed to get usage: ", tostring(incr_err))
        return
    end

    if usage and stop then
        set_metric({}, "rate_limit.dropped", COUNTER_TYPE, 1, 1)
        local status = conf.status_code
        local content = conf.body
        return kong.response.exit(status, content, {
            [CONTENT_TYPE] = conf.content_type,
        })
    end
    set_metric({}, "rate_limit.allowed", COUNTER_TYPE, 1, 1)
end

function RateLimitingV2Handler:log(conf)
    local identifier, err = get_identifier(conf)

    if err then
        return
    end

    if conf.algorithm == FIXED_WINDOW_ALGORITHM then
        return
    end

    if kong.ctx.shared.rate_limit.err_count then
        return
    end
    if RateLimitingV2Handler.DECREMENT_FAILURES[identifier] == nil then
        RateLimitingV2Handler.DECREMENT_FAILURES[identifier] = 0
    end
    local previous_errors = RateLimitingV2Handler.DECREMENT_FAILURES[identifier]
    RateLimitingV2Handler.DECREMENT_FAILURES[identifier] = 0
    local decrement_by = previous_errors + 1
    local _, _ = timer_at(0, decrement_counter, conf, identifier, decrement_by)

end

return RateLimitingV2Handler

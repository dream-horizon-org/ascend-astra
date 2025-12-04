local json_safe = require "cjson.safe"

local ConditionalReqTerminationHandler = {}
ConditionalReqTerminationHandler.PRIORITY = 8001
ConditionalReqTerminationHandler.VERSION = "1.0.0"

--- If this plugin is enabled, it checks the query parameters of the request and
--- terminates the request with a specified response if the conditions are met.
function ConditionalReqTerminationHandler:access(conf)
    local query_params = kong.request.get_query()
    local query_param_value = tonumber(query_params[conf.query_param_key])

    if query_params and query_param_value ~= nil then
        if (conf.operator == "==" and query_param_value == conf.query_param_value) or
          (conf.operator == ">" and query_param_value > conf.query_param_value) or
          (conf.operator == "<" and query_param_value < conf.query_param_value) then
            return kong.response.exit(conf.response_status_code, json_safe.decode(conf.response_json))
        end
    end
end

return ConditionalReqTerminationHandler

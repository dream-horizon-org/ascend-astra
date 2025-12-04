local typedefs = require "kong.db.schema.typedefs"
local json_safe = require "cjson.safe"

local function json_validator(conf)
    local response_json, err1 = json_safe.decode(conf.response_json)
    if response_json == nil then
        return false, "Invalid response_json: " .. err1
    end
    return true
end

return {
    name = "conditional-req-termination",
    fields = {
        {
            consumer = typedefs.no_consumer,
        },
        {
            protocols = typedefs.protocols_http,
        },
        {
            config = {
                type = "record",
                fields = {
                    {
                        query_param_key = {
                            type = "string",
                            required = true,
                            default = "pageNum",
                        },
                    },
                    {
                        operator = {
                            type = "string",
                            one_of = {
                                "==",
                                ">",
                                "<",
                            },
                            default = ">",
                        },
                    },
                    {
                        query_param_value = {
                            type = "number",
                            required = true,
                            default = 10,
                        },
                    },
                    {
                        response_status_code = {
                            type = "number",
                            required = true,
                            default = 420,
                        },
                    },
                    {
                        response_json = {
                            type = "string",
                            required = true,
                            default = "{\"error\": {\"message\": \"You can check the list of all the participating teams soon after the match begins.\",\"cause\": \"Request error\",\"code\": \"REQUEST_VALIDATION_VIOLATION\"}}",
                        },
                    },
                },
                custom_validator = json_validator,
            },
        },
    },
}

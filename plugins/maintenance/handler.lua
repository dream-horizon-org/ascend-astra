local kong = kong

local DEFAULT_RESPONSE = {
    [401] = "Unauthorized",
    [404] = "Not found",
    [405] = "Method not allowed",
    [500] = "An unexpected error occurred",
    [502] = "Bad Gateway",
    [503] = "Service unavailable",
}

local MaintenanceHandler = {}

MaintenanceHandler.PRIORITY = 11000
MaintenanceHandler.VERSION = "2.0.1"

--- If this plugin is enabled, it blocks all requests except those in exclude_paths
--- and sends the response as configured
function MaintenanceHandler:access(conf)
    if conf.exclude_paths ~= nil then
        for _, path in pairs(conf.exclude_paths) do
            if path == kong.request.get_path() then
                return
            end
        end
    end

    local status = conf.status_code
    local content = conf.body

    if content then
        local headers = {
            ["Content-Type"] = conf.content_type,
        }

        return kong.response.exit(status, content, headers)
    end

    local message = conf.message or DEFAULT_RESPONSE[status]
    return kong.response.exit(status, message and {
        message = message,
    } or nil)
end

return MaintenanceHandler

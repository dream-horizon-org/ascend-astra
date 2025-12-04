local StripHeadersHandler = {}

StripHeadersHandler.PRIORITY = 8000
StripHeadersHandler.VERSION = "1.0.0"

local function starts_with(str, start)
    return str:sub(1, #start) == start
end

--- If this plugin is enabled, it will strip all headers that start with a prefix from the request
function StripHeadersHandler:access(conf)
    for header, _ in pairs(kong.request.get_headers()) do
        for _, prefix in pairs(conf.strip_headers_with_prefixes) do
            if starts_with(header, prefix) then
                kong.log.debug("Clearing sensitive header: " .. header)
                kong.service.request.clear_header(header)
            end
        end
    end
end

return StripHeadersHandler

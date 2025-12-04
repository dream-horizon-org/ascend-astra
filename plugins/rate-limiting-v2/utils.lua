local EMPTY_UUID = "00000000-0000-0000-0000-000000000000"

return {
    get_service_and_route_ids = function(conf)
        conf = conf or {}

        local service_id = conf.service_id
        local route_id = conf.route_id

        if not service_id then
            service_id = EMPTY_UUID
        end

        if not route_id then
            route_id = EMPTY_UUID
        end

        return service_id, route_id
    end,
}

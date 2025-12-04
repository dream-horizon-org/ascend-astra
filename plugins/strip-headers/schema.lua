local typedefs = require "kong.db.schema.typedefs"

return {
    name = "strip-headers",
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
                        strip_headers_with_prefixes = {
                            type = "array",
                            required = true,
                            elements = {
                                type = "string",
                            },
                        },
                    },
                },
            },
        },
    },
}

local typedefs = require "kong.db.schema.typedefs"

return {
    name = "rate-limiting-v2",
    fields = {
        {
            protocols = typedefs.protocols_http,
        },
        {
            config = {
                type = "record",
                fields = {
                    {
                        algorithm = {
                            type = "string",
                            default = "fixed-window",
                            len_min = 0,
                            one_of = {
                                "fixed-window",
                                "leaky-bucket",
                            },
                        },
                    },
                    {
                        period = {
                            type = "string",
                            default = "minute",
                            len_min = 0,
                            one_of = {
                                "second",
                                "minute",
                                "hour",
                                "day",
                            },
                        },
                    },
                    {
                        limit = {
                            type = "number",
                            gt = 0,
                            required = true,
                        },
                    },
                    {
                        limit_by = {
                            type = "string",
                            default = "service",
                            one_of = {
                                "service",
                                "header",
                            },
                        },
                    },
                    {
                        header_name = typedefs.header_name,
                    },
                    {
                        policy = {
                            type = "string",
                            default = "batch-redis",
                            len_min = 0,
                            one_of = {
                                "redis",
                                "batch-redis",
                                "local",
                            },
                        },
                    },
                    {
                        batch_size = {
                            type = "integer",
                            gt = 1,
                            default = 10,
                        },
                    },
                    {
                        status_code = {
                            type = "integer",
                            required = true,
                            default = 429,
                            between = {
                                100,
                                599,
                            },
                        },
                    },
                    {
                        content_type = {
                            type = "string",
                            required = true,
                            default = "application/json",
                            len_min = 0,
                        },
                    },
                    {
                        body = {
                            type = "string",
                            len_min = 0,
                            required = true,
                            default = "{\"message\": \"API rate limit exceeded\"}",
                        },
                    },
                    {
                        redis_write_timeout = {
                            type = "integer",
                            default = 10,
                        },
                    },
                    {
                        redis_read_timeout = {
                            type = "integer",
                            default = 10,
                        },
                    },
                    {
                        redis_connect_timeout = {
                            type = "integer",
                            default = 10,
                        },
                    },
                },
            },
        },
    },
    entity_checks = {
        {
            conditional = {
                if_field = "config.policy",
                if_match = {
                    eq = "batch-redis",
                },
                then_field = "config.batch_size",
                then_match = {
                    required = true,
                },
            },
        },
        {
            conditional = {
                if_field = "config.limit_by",
                if_match = {
                    eq = "header",
                },
                then_field = "config.header_name",
                then_match = {
                    required = true,
                },
            },
        },
        {
            conditional = {
                if_field = "config.algorithm",
                if_match = {
                    eq = "fixed-window",
                },
                then_field = "config.policy",
                then_match = {
                    required = true,
                },
            },
        },
    },
}

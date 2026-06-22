return {
    {
        "folke/snacks.nvim",
        opts = {
            explorer = {},
            picker = {
                sources = {
                    explorer = {
                        hidden = true,
                        ignored = true,
                    },
                },
            },
        },
    },
    {
        "CopilotC-Nvim/CopilotChat.nvim",
        dependencies = {
            { "nvim-lua/plenary.nvim", branch = "master" },
        },
        opts = {
            model = "claude-sonnet-4.6",
            trusted_tools = { "file", "glob", "grep" },
        },
    },
}

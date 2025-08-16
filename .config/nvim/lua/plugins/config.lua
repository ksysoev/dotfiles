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
    { "ThePrimeagen/vim-be-good" },
    {
        "CopilotC-Nvim/CopilotChat.nvim",
        dependencies = {
            { "nvim-lua/plenary.nvim", branch = "master" }, -- for curl, log and async functions
        },
        opts = {
            model = "claude-sonnet-4",
            -- See Configuration section for options
        },
        -- See Commands section for default commands if you want to lazy load on them
    },
}

-- duet.nvim. With a checkout at ~/Documents/Dev/duet.nvim, Neovim runs whatever branch
-- is checked out there; without one, lazy.nvim installs it from GitHub (see `dev` in
-- lua/config/lazy.lua) and :Lazy update pulls the latest main.
-- Keys follow the ones the LazyVim sidekick extra used, under <leader>a.

-- Pick an agent and open it (sidekick's "Select CLI").
local function select_agent()
  local agents = require("duet.agents").list()
  vim.ui.select(agents, { prompt = "duet agent" }, function(choice)
    if choice then
      require("duet").open(choice)
    end
  end)
end

return {
  {
    "ksysoev/duet.nvim",
    dev = true,
    cmd = "Duet",
    opts = {
      -- Verbose log while developing: :lua vim.cmd.edit(require("duet.log").path())
      log_level = "debug",
    },
    -- stylua: ignore
    keys = {
      { "<leader>a", "", desc = "+ai", mode = { "n", "v" } },
      { "<c-.>", function() require("duet").open() end, desc = "Duet Focus", mode = { "n", "t", "i", "x" } },
      { "<leader>aa", function() require("duet").toggle() end, desc = "Duet Toggle" },
      { "<leader>as", select_agent, desc = "Duet Select Agent" },
      { "<leader>ad", function() require("duet").close() end, desc = "Duet Hide" },
      -- Paste into the agent's prompt without submitting, like sidekick did.
      { "<leader>at", "<Cmd>Duet! send {this}<CR>", desc = "Send This", mode = { "n", "x" } },
      { "<leader>af", "<Cmd>Duet! send {file}<CR>", desc = "Send File" },
      { "<leader>av", "<Cmd>Duet! send {selection}<CR>", desc = "Send Visual Selection", mode = { "x" } },
      { "<leader>ap", "<Cmd>Duet! ask<CR>", desc = "Duet Select Prompt", mode = { "n", "x" } },
    },
  },
}

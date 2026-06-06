return {
  {
    "nvim-neotest/neotest",
    opts = {
      adapters = {
        ["neotest-golang"] = {
          -- Set your preferred default timeout duration here (e.g., "60s", "5m")
          go_test_args = { "-v", "-race", "-count=1", "-timeout=30s" },
        },
      },
    },
  },
}

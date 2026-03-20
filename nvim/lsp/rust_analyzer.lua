-- Must return a plain table. Do NOT call vim.lsp.config() here.
return {
  cmd = { "rust-analyzer" },
  filetypes = { "rust" },
  root_markers = { "Cargo.toml", "rust-project.json", ".git" },
  settings = {
    ["rust-analyzer"] = {
      check = {
        command = "clippy",
      },
      cargo = {
        allFeatures = true,
      },
    },
  },
}


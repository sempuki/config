-- init.lua -- Ryan McDougall (modern Neovim 0.11)
--
-- Plugin replacements:
--   chrisbra/matchit         → built-in (Neovim default)
--   vim-scripts/gtags.vim    → native LSP + Telescope (go-to-ref, symbols)
--   bfrg/vim-cpp-modern      → nvim-treesitter (syntax highlighting)
--   vim-syntastic/syntastic  → native LSP diagnostics
--   rhysd/vim-clang-format   → conform.nvim (formatting)
--   easymotion/vim-easymotion→ flash.nvim (defaults)
--   mileszs/ack.vim          → Telescope live_grep (ripgrep)
--   neovim/nvim-lspconfig    → native vim.lsp.config + lsp/*.lua files
--   ctags generation         → LSP handles symbols natively
--
-- Kept as-is:
--   tpope/vim-fugitive       → still the best Git plugin
--   tpope/vim-rhubarb        → GitHub integration for fugitive
--   derekwyatt/vim-fswitch   → no clearly better Lua alternative
--
-- LSP server configs are defined inline via vim.lsp.config()
--
-- Neovim 0.11 default LSP keymaps (no config needed):
--   grn  → vim.lsp.buf.rename()
--   gra  → vim.lsp.buf.code_action()
--   grr  → vim.lsp.buf.references()
--   gri  → vim.lsp.buf.implementation()
--   gO   → vim.lsp.buf.document_symbol()
--   K    → vim.lsp.buf.hover()
--   C-s  → vim.lsp.buf.signature_help() (insert mode)

-------------------------------------------------------------------------------
-- Leader (must be set before lazy.nvim)
-------------------------------------------------------------------------------

vim.g.mapleader = ","

-------------------------------------------------------------------------------
-- Bootstrap lazy.nvim
-------------------------------------------------------------------------------

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-------------------------------------------------------------------------------
-- Plugins
-------------------------------------------------------------------------------

require("lazy").setup({

  ---- Git ----

  { "tpope/vim-fugitive" },
  { "tpope/vim-rhubarb" },

  ---- Header/source switching ----

  { "derekwyatt/vim-fswitch" },

  ---- Treesitter (replaces vim-cpp-modern and all syntax plugins) ----

  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").setup({})
      -- Install parsers (no-op if already installed)
      require("nvim-treesitter").install({
        "c", "cpp", "rust",
        "lua", "proto", "json", "yaml", "bash", "markdown", "markdown_inline",
      })
      -- Enable treesitter highlighting + indentation on file open
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "c", "cpp", "rust", "lua", "proto", "json", "yaml", "bash", "markdown" },
        callback = function(ev)
          pcall(vim.treesitter.start, ev.buf)
          vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },

  ---- Autocompletion ----

  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
    },
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        sources = cmp.config.sources(
          { { name = "nvim_lsp" } },
          { { name = "buffer" }, { name = "path" } }
        ),
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<C-n>"] = cmp.mapping.select_next_item(),
          ["<C-p>"] = cmp.mapping.select_prev_item(),
          ["<C-u>"] = cmp.mapping.scroll_docs(-4),
          ["<C-d>"] = cmp.mapping.scroll_docs(4),
        }),
      })
    end,
  },

  ---- Formatting (replaces vim-clang-format) ----

  {
    "stevearc/conform.nvim",
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          c = { "clang-format" },
          cpp = { "clang-format" },
          proto = { "clang-format" },
          rust = { "rustfmt" },
          lua = { "stylua" },
        },
      })

      -- Format on save for C/C++/proto/rust
      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = { "*.c", "*.h", "*.cc", "*.hh", "*.cpp", "*.hpp", "*.proto", "*.rs" },
        callback = function(ev)
          require("conform").format({ bufnr = ev.buf, timeout_ms = 500, lsp_format = "fallback" })
        end,
      })
    end,
  },

  ---- Telescope (replaces ack.vim, gtags grep) ----

  {
    "nvim-telescope/telescope.nvim",
    branch = "master",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    config = function()
      local telescope = require("telescope")
      telescope.setup({
        defaults = {
          layout_strategy = "horizontal",
          layout_config = { prompt_position = "top" },
          sorting_strategy = "ascending",
        },
      })
      telescope.load_extension("fzf")
    end,
  },

  ---- Claude Code (IDE integration) ----

  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    lazy = false, -- must load eagerly to start the WebSocket server
    opts = {},
    keys = {
      { "<Leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
      { "<Leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
      { "<Leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
      { "<Leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
      { "<Leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
      { "<Leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
      { "<Leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
      { "<Leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
    },
  },

  ---- Flash (replaces easymotion) ----

  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end,
        desc = "Flash jump" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end,
        desc = "Flash treesitter select" },
    },
  },
})

-------------------------------------------------------------------------------
-- Colorscheme
-------------------------------------------------------------------------------

vim.cmd.colorscheme("slatemine")
vim.opt.termguicolors = true

-------------------------------------------------------------------------------
-- Options
-------------------------------------------------------------------------------

vim.opt.autowriteall = true
vim.opt.undofile = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smarttab = true
vim.opt.cindent = true
vim.opt.cinoptions = ":0,g0,N-s"
vim.opt.ruler = true
vim.opt.number = true
vim.opt.hlsearch = true
vim.opt.wildmode = { "longest", "full" }
vim.opt.scrolloff = 5
vim.opt.matchpairs:append("<:>")
vim.opt.guioptions:remove({ "t", "T" })
vim.opt.errorbells = false
vim.opt.visualbell = true
vim.opt.signcolumn = "yes"

-- Rounded borders on all floating windows (hover, diagnostics, etc.)
vim.o.winborder = "rounded"

-------------------------------------------------------------------------------
-- Swap and undo directories
-------------------------------------------------------------------------------

local swap_dir = vim.fn.expand("~/.vim/swap")
local undo_dir = vim.fn.expand("~/.vim/undo")

if vim.fn.isdirectory(swap_dir) == 0 then vim.fn.mkdir(swap_dir, "p") end
if vim.fn.isdirectory(undo_dir) == 0 then vim.fn.mkdir(undo_dir, "p") end

vim.opt.directory = { swap_dir, ".", vim.fn.expand("~/tmp"), "/var/tmp" }
vim.opt.undodir = { undo_dir, ".", vim.fn.expand("~/tmp"), "/var/tmp" }

-------------------------------------------------------------------------------
-- Path for :find
-------------------------------------------------------------------------------

vim.opt.path = { ".", "", "./tests", "src", "include", "/usr/include/", "/usr/include/c++/src" }

-------------------------------------------------------------------------------
-- FSwitch configuration
-------------------------------------------------------------------------------

vim.g.fsnonewfiles = 1

local fswitch_group = vim.api.nvim_create_augroup("FSwitchExtensions", { clear = true })

local fswitch_rules = {
  { "*.hh",  "cc",   "reg:/include/src/,reg:/include.*/src/,../src,impl" },
  { "*.cc",  "hh,h", "reg:/src/include/,reg:|src|include/**|,../include,../" },
  { "*.hpp", "cpp",  "reg:/include/src/,reg:/include.*/src/,../src,impl" },
  { "*.cpp", "hpp",  "reg:/src/include/,reg:|src|include/**|,../include,../" },
}

for _, rule in ipairs(fswitch_rules) do
  vim.api.nvim_create_autocmd("BufEnter", {
    group = fswitch_group,
    pattern = rule[1],
    callback = function()
      vim.b.fswitchdst = rule[2]
      vim.b.fswitchlocs = rule[3]
    end,
  })
end

-------------------------------------------------------------------------------
-- Native LSP setup (Neovim 0.11)
--
-- Server configs live in ~/.config/nvim/lsp/*.lua
-- Each file must return a plain table (NOT call vim.lsp.config).
-- Neovim auto-discovers them by filename.
-------------------------------------------------------------------------------

vim.lsp.enable({ "clangd", "rust_analyzer", "lua_ls" })

-------------------------------------------------------------------------------
-- LSP Diagnostics appearance
-------------------------------------------------------------------------------

vim.diagnostic.config({
  virtual_text = { spacing = 4, prefix = "●" },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})

-------------------------------------------------------------------------------
-- LSP Keymaps (on attach)
--
-- Neovim 0.11 provides these defaults automatically:
--   K    → hover
--   grn  → rename
--   gra  → code action
--   grr  → references
--   gri  → implementation
--   gO   → document symbols
--   C-s  → signature help (insert mode)
--
-- We add a few extras and wire Telescope into some of them.
-------------------------------------------------------------------------------

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local buf = ev.buf
    local opts = { buffer = buf }
    local telescope = require("telescope.builtin")

    -- Ensure tagfunc uses LSP (makes :tjump work via LSP)
    vim.bo[buf].tagfunc = "v:lua.vim.lsp.tagfunc"

    -- Go-to-definition (replaces ctag <Leader>t / tjump)
    vim.keymap.set("n", "gd", telescope.lsp_definitions, opts)

    -- References via Telescope (enhances built-in grr with fuzzy picker)
    vim.keymap.set("n", "<Leader>r", telescope.lsp_references, opts)

    -- Document symbols via Telescope (replaces Gtags -f %)
    vim.keymap.set("n", "<Leader>f", telescope.lsp_document_symbols, opts)

    -- Workspace symbols (replaces Gtags -g for global search)
    vim.keymap.set("n", "<Leader>g", telescope.lsp_workspace_symbols, opts)

    -- Diagnostics navigation (replaces syntastic loc-list jumping)
    vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
    vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
    vim.keymap.set("n", "<Leader>d", vim.diagnostic.open_float, opts)

    -- Format on request (replaces = → gq clang-format mapping)
    vim.keymap.set({ "n", "v" }, "=", function()
      require("conform").format({ bufnr = buf })
    end, opts)
  end,
})

-------------------------------------------------------------------------------
-- Keymaps -- General
-------------------------------------------------------------------------------

local map = vim.keymap.set

-- Save buffer
map("n", "<Leader>w", "<Esc><C-c>:w<CR>", { silent = true })

-- Cancel highlighting
map("n", "<C-c>", "<C-c>:nohl<CR>", { silent = true })

-- Ergonomic escape
map({ "n", "v", "o" }, "<C-e>", "<Esc>")
map({ "i", "c" }, "<C-e>", "<C-c>")

-- Ergonomic centering
map("n", "<Home>", "zz")

-- Additional scrolling
map("n", "<Backspace>", "<PageUp>")
map("n", "<Space>", "<PageDown>")

-- Yank/Put to/from system clipboard
map({ "v", "n" }, "<Leader>y", '"+y')
map({ "v", "n" }, "<Leader>p", '"+p')

-------------------------------------------------------------------------------
-- Keymaps -- Buffer/Window management
-------------------------------------------------------------------------------

map("n", "<C-n>", "<C-W>w", { silent = true })
map("n", "<C-p>", "<C-W>W", { silent = true })
map("n", "<C-x>", ":bdelete!<CR>", { silent = true })
map("n", "<Leader>e", ":edit ")
map("n", "<Leader>b", ":buffer ")
map("n", "<Leader>B", ":buffer! # | bdelete! #<CR>")
map("n", "]b", ":bnext<CR>")
map("n", "[b", ":bprevious<CR>")

-------------------------------------------------------------------------------
-- Keymaps -- Tab management
-------------------------------------------------------------------------------

map("n", "]t", ":tabnext<CR>")
map("n", "[t", ":tabprevious<CR>")

-------------------------------------------------------------------------------
-- Keymaps -- Quickfix window
-------------------------------------------------------------------------------

map("n", "<Leader>q", ":botright copen<CR>")
map("n", "<Leader>Q", ":cclose<CR>")
map("n", "]q", ":cnext<CR>")
map("n", "[q", ":cprevious<CR>")

-------------------------------------------------------------------------------
-- Keymaps -- Location window
-------------------------------------------------------------------------------

map("n", "<Leader>l", ":lopen<CR>")
map("n", "<Leader>L", ":lclose<CR>")
map("n", "]l", ":lnext<CR>")
map("n", "[l", ":lprevious<CR>")

-------------------------------------------------------------------------------
-- Keymaps -- Editing helpers
-------------------------------------------------------------------------------

-- Insert newline above
map("n", "<C-j>", "O<Esc>j")

-- Toggle header/source
map("n", "<C-a>", ":FSHere<CR>", { silent = true })

-- Jump to BUILD file
map("n", "<Leader><Leader>b", ":find BUILD*<CR>", { silent = true })

-- Jump to test file
map("n", "<Leader><Leader>u", ":find %:t:r_test.%:e<CR>", { silent = true })

-- Ctag jumping (kept as fallback alongside LSP gd)
map("n", "<Leader>t", ":tjump ")

-------------------------------------------------------------------------------
-- Keymaps -- Telescope (replaces ack.vim, extends searching)
-------------------------------------------------------------------------------

local telescope_builtin = function(name)
  return function() require("telescope.builtin")[name]() end
end

-- Replaces <C-g> :Ack (grep word under cursor)
map("n", "<C-g>", function()
  require("telescope.builtin").grep_string()
end)

-- Live grep (replaces :Ack for freeform searching)
map("n", "<Leader><Leader>g", telescope_builtin("live_grep"))

-- Find files
map("n", "<Leader><Leader>f", telescope_builtin("find_files"))

-- Buffers (enhances <Leader>b)
map("n", "<Leader><Leader>e", telescope_builtin("buffers"))

-- Search+replace word under cursor (kept from original)
map("n", "<Leader>s", [[:%s/\<<C-r><C-w>\>//gc<Left><Left><Left>]])

-------------------------------------------------------------------------------
-- Keymaps -- Hex editing
-------------------------------------------------------------------------------

map("n", "<Leader>h", ":%!xxd -g1<CR>")
map("n", "<Leader>H", ":%!xxd -r<CR>:set bin<CR>:write<CR>:set nobin<CR>")

-------------------------------------------------------------------------------
-- Keymaps -- Spell check
-------------------------------------------------------------------------------

map("n", "<Leader>k", ":setlocal spell<CR>")
map("n", "<Leader>K", ":setlocal nospell<CR>")

-------------------------------------------------------------------------------
-- Keymaps -- Make and run
-------------------------------------------------------------------------------

map("n", "<Leader><Leader>m", ":make %:r |cwindow<CR>")
map("n", "<Leader><Leader>r", ":!./%:r <CR>")

-------------------------------------------------------------------------------
-- Neovim terminal configuration
-------------------------------------------------------------------------------

vim.opt.scrollback = 100000

map("n", "<C-\\><C-t>", "<C-\\><C-n>:set nonumber | term<CR>")
map("n", "<C-\\><C-s>", "<C-\\><C-n>:set nonumber | split +term<CR>")
map("n", "<C-\\><C-v>", "<C-\\><C-n>:set nonumber | vsplit +term<CR>")
map("t", "<C-e><C-e>", "<C-\\><C-n>")
map("t", "<C-n>", "<C-\\><C-n><C-w>wi")
map("t", "<C-p>", "<C-\\><C-n><C-w>Wi")
map("t", "<C-PageUp>", "<C-\\><C-n>:tabnext<CR>")
map("t", "<C-PageDown>", "<C-\\><C-n>:tabprev<CR>")
map("t", "<PageUp>", "<C-\\><C-n><PageUp>")
map("t", "<PageDown>", "<C-\\><C-n><PageDown>")

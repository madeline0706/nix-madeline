{ inputs, ... }: {
  # A beginner-friendly Neovim, configured entirely through Nix via nixvim.
  # Everything here maps onto normal Neovim concepts, so it doubles as a way to
  # learn vim: the comments explain what each piece does.
  flake.homeModules.nixvim = { pkgs, lib, ... }:
  let
    # visual.nvim is our own from-scratch plugin (see ./visual-nvim). It's pure
    # Lua, so packaging is just dropping the source tree onto the runtimepath.
    visual-nvim = pkgs.vimUtils.buildVimPlugin {
      pname = "visual-nvim";
      version = "0.1";
      src = ./visual-nvim;
    };
  in {
    imports = [ inputs.nixvim.homeModules.nixvim ];

    # visual.nvim's browser graph/note panel is styled in Terminus — the same
    # font used everywhere else (installed via base's `terminus_font`), so nothing
    # new is pulled in. fontconfig just needs to expose the HM-profile fonts to
    # the browser.
    fonts.fontconfig.enable = true;

    programs.nixvim = {
      enable = true;

      # We drive nixvim with our own nixpkgs (pinned via the flake `follows`),
      # so pin the module's nixpkgs source explicitly to match. Silences the
      # "nixpkgs.source default affected by follows" evaluation warning.
      nixpkgs.source = inputs.nixpkgs;

      # Make `vi`/`vim` open Neovim too, so muscle memory works.
      viAlias = true;
      vimAlias = true;

      # The leader key is a prefix for custom shortcuts. Space is the common
      # modern default and is easy to reach. Used below as "<leader>".
      globals.mapleader = " ";
      globals.maplocalleader = " ";

      # Editor options (`:set` in vim, `:h <name>` for docs on any of these).
      opts = {
        number = true;         # Show the current line's absolute number...
        relativenumber = true; # ...and other lines relative to it (helps with 5j/3k motions).

        expandtab = true;      # Insert spaces instead of tab characters.
        shiftwidth = 2;        # Size of an indent.
        tabstop = 2;           # How many columns a <Tab> counts for.
        smartindent = true;    # Auto-indent new lines sensibly.

        wrap = false;          # Don't soft-wrap long lines.
        scrolloff = 8;         # Keep 8 lines visible above/below the cursor.
        signcolumn = "yes";    # Always show the left gutter (avoids text jumping).

        ignorecase = true;     # Searches are case-insensitive...
        smartcase = true;      # ...unless you type a capital letter.

        termguicolors = false; # Use the terminal's 16 ANSI colors (matches the foot theme).
        clipboard = "unnamedplus"; # Share yank/paste with the system clipboard.

        undofile = true;       # Persist undo history across sessions.
      };

      # Plugins. Each `enable = true` pulls the plugin in and applies sensible
      # defaults; `settings` (where present) maps to the plugin's Lua setup.
      plugins = {
        web-devicons.enable = true; # Filetype icons used by the plugins below.

        # which-key: after you press <leader> (or any prefix), a popup shows the
        # available follow-up keys. Invaluable while you're still learning.
        which-key.enable = true;

        # Fuzzy finder for files, text, buffers, help, etc.
        telescope = {
          enable = true;
          keymaps = {
            "<leader>ff" = { action = "find_files"; options.desc = "Find files"; };
            "<leader>fg" = { action = "live_grep"; options.desc = "Search in files"; };
            "<leader>fb" = { action = "buffers"; options.desc = "Open buffers"; };
            "<leader>fh" = { action = "help_tags"; options.desc = "Search help"; };
          };
        };

        # Better syntax highlighting and code-aware motions.
        treesitter.enable = true;

        # File-tree sidebar, toggled with <leader>e below.
        nvim-tree.enable = true;

        # A tidy statusline at the bottom.
        lualine.enable = true;

        # Git change markers in the sign column + inline hunk info.
        gitsigns.enable = true;

        # `gcc` to comment a line, `gc` in visual mode for a selection.
        comment.enable = true;

        # Auto-close brackets and quotes as you type.
        nvim-autopairs.enable = true;
      };

      # A lightweight personal wiki over a directory of markdown notes:
      # [[wikilinks]] plus a self-hosted, Obsidian-style graph view in the
      # browser (:Visual). Added as a raw plugin and configured with setup() below.
      extraPlugins = [ visual-nvim ];

      # ripgrep powers telescope's live_grep. visual.nvim needs nothing extra:
      # its web server is libuv (bundled with Neovim) and the graph is vanilla JS.
      extraPackages = [ pkgs.ripgrep ];

      # `root` is where notes live; `gf` follows a [[wikilink]] under the cursor,
      # and :Visual serves the note graph on a random port and opens the browser.
      extraConfigLua = ''
        require("visual").setup({
          root = vim.fn.expand("~/notes"),
          extensions = { "md", "markdown", "txt" },
        })
      '';

      # Custom key mappings. `mode` is the vim mode: "n" = normal, "v" = visual.
      keymaps = [
        {
          mode = "n";
          key = "<leader>e";
          action = "<cmd>NvimTreeToggle<CR>";
          options.desc = "Toggle file explorer";
        }
        {
          mode = "n";
          key = "<leader>w";
          action = "<cmd>w<CR>";
          options.desc = "Save file";
        }
        {
          mode = "n";
          key = "<leader>v";
          action = "<cmd>Visual<CR>";
          options.desc = "Open note graph in browser";
        }
        {
          mode = "n";
          key = "<Esc>";
          action = "<cmd>nohlsearch<CR>";
          options.desc = "Clear search highlight";
        }
        # Move the current line/selection up and down with Alt-j / Alt-k.
        {
          mode = "n";
          key = "<A-j>";
          action = "<cmd>m .+1<CR>==";
          options.desc = "Move line down";
        }
        {
          mode = "n";
          key = "<A-k>";
          action = "<cmd>m .-2<CR>==";
          options.desc = "Move line up";
        }
      ];
    };
  };
}

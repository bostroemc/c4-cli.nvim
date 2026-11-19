THIS REPO IS IN PRE-ALPHA STATUS.  


# c4-cli.nvim

Neovim plugin for the CODESYS 4 command line interface (c4-cli). 

## ✨ Features

* **Feature 1:** Minimal wrapper around the c4-cli.

## 📋 Requirements

* Neovim **>= 0.12.0**
* CODESYS 4

## 📦 Installation

Install with [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "bostroemc/c4-cli.nvim",
  -- Optional: lazy-load on specific filetypes or commands
  opts = {
  },
}
```

## ⚙️ Configuration

`c4-cli.nvim` comes with the following default options. If you use `lazy.nvim` with `opts = {}`, `setup()` is called automatically. Otherwise, call `require("my-plugin").setup()` manually.

```lua
require("c4-cli.nvim").setup({
  -- Default settings
  enabled = true,
  timeout = 5000,
  keymaps = {
  },
})
```

## 🚀 Usage

### Commands

| Command | Description |
| :--- | :--- |

### Default Keymaps

| Mode | Keymap | Action |
| :--- | :--- | :--- |

## 🤝 Contributing


## 📄 License


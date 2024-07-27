## My simple discord rich presence plugin for neovim

#### Start it with
```lua
require("disc").setup()
```


## Config Example:

```lua
require("disc").setup({
    timeout = 3000,

    client_id = "1219918645770059796", -- discord application id

    details = "some details",
    state = "some state",

    large_image_text = "large image",
    large_image = "https://large_image.com", -- should be valid img
    small_image_text = "small image",
    small_image = "https://small_image.com",

    buttons = {
        {
            label = "label on first button",
            url = "https://example.com"
        },
        {
            label = "label on second button",
            url = "https://example.com"
        }
    }
})
```

## Commands

- `:DiscDisconnect` disconnect form discord
- `:DiscReconnect` to connect/reconnect to discord

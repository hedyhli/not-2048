local old_conf = require("lspconfig").lua_ls.manager.config
require("lspconfig").lua_ls.setup({
    settings = {
        Lua = {
            -- https://github.com/LuaCATS/love2d
            workspace = { library = { "./love2d" } },
            telemetry = { enable = false },
            completion = {
                callSnippets = "Replace"
            },
        },
    },
    on_attach = old_conf.on_attach,
    capabilities = old_conf.capabilities,
    handlers = old_conf.handlers,
    flags = {
      debounce_text_changes = 150,
    }
})

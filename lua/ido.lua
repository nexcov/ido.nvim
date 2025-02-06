vim.api.nvim_create_augroup("IdoCmds", {})

local function get_ido_format(list)
    local str = '{'
    for i, v in ipairs(list) do
        str = str .. v
        if i < #list then str = str .. " | " end
    end
    return str .. '}'
end

local Ido = {}
Ido.__index = Ido

function Ido:new(items, prompt)
    local new = setmetatable({}, self)
    new.items = items or { "foo", "bar" }
    new.selected = new.items[1] or nil
    new.prompt = prompt or "Ido :"
    return new
end

function Ido:create_buf()
    self.buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("swapfile", false, { buf = self.buf })
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = self.buf })
end

function Ido:set_keymaps()
    vim.keymap.set('i', '<Esc>', function() vim.cmd('bd!') end, { buffer = self.buf, noremap = true, silent = true })
    vim.keymap.set('i', '<CR>', function() self:enter() end, { buffer = self.buf, noremap = true, silent = true })
    vim.keymap.set('i', '<Space>', function() self:enter() end, { buffer = self.buf, noremap = true, silent = true })

    vim.keymap.set('i', '<TAB>', function() 
        vim.cmd('normal dd')
        self:print_format()
        vim.api.nvim_put({ self.selected }, 'c', false, false)
    end, { buffer = self.buf, noremap = true, silent = true })
end

function Ido:print_format()
    local cur_col = vim.api.nvim_win_get_cursor(self.win)[2]
    local input = vim.api.nvim_buf_get_text(self.buf, 0, 0, 0, cur_col, {})[1]
    local fzf = vim.fn.matchfuzzy(self.items, input)
    self.selected = fzf[1]
    local str = ''
    if #fzf >= 1 then str = get_ido_format(fzf)
    elseif #input >= 1 then str = '[No match]'
    else str = get_ido_format(self.items) self.selected = self.items[1] end
    vim.api.nvim_buf_set_text(self.buf, 0, cur_col, 0, -1, { str })
end

function Ido:set_autocmds()
    vim.api.nvim_create_autocmd({ "BufLeave" }, {
        group = "IdoCmds",
        buffer = self.buf,
        callback = function()
            vim.cmd("bd! " .. self.buf)
        end
    })
    vim.api.nvim_create_autocmd({ "TextChangedI" }, {
        group = "IdoCmds",
        buffer = self.buf,
        callback = function()
            self:print_format()
        end
    })
end

function Ido:enter()
    if self.selected ~= nil then
        print('Selected: '..self.selected)
    else
        print("Nothing selected")
    end
    vim.cmd('bd! ' .. self.buf)

end

function Ido:set_prompt_exmark(virt_text)
    virt_text = virt_text or self.prompt
    self.extmark_p = vim.api.nvim_buf_set_extmark(self.buf, self.ns, 0, 0, {
        id = self.extmark_p,
        virt_text = {{ virt_text, "GruberDarkerRed" }},
        virt_text_pos = 'inline',
        right_gravity = false,
    })
end

function Ido:mount()
    self:create_buf()
    self:set_autocmds()
    self:set_keymaps()

    local win_opt = {
        relative = "editor", anchor = "SW",
        width = vim.go.columns - 2, height = 1,
        row = vim.go.lines - 2, col = 0,
        style = "minimal", border = "rounded",
    }

    self.win = vim.api.nvim_open_win(self.buf, true, win_opt)
    self.ns = vim.api.nvim_create_namespace("IdoPromptProc");
    vim.api.nvim_put({get_ido_format(self.items)}, 'c', false, false)
    vim.api.nvim_win_set_cursor(self.win, { 1, 0 })
    self:set_prompt_exmark(self.prompt)
    vim.cmd('startinsert')
end

return Ido

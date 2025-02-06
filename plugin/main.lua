local Ido = require('ido')

local function get_files_in_path(path)
    local files = {}
    local fs = vim.uv.fs_scandir(path, nil)
    local name, type = vim.uv.fs_scandir_next(fs)
    while name do
        table.insert(files, {name, type})
        name, type = vim.uv.fs_scandir_next(fs)
    end
    return files
end

local function classify_files(files)
    local r = {}
    for i, v in ipairs(files) do
        if v[2] == 'directory' then
            r[i] = v[1] .. '/'
        else
            r[i] = v[1]
        end
    end
    return r
end

-- TODO: Manage completion print and feature outside ido format (Ido)
-- TODO: completion
-- TODO: highlight
-- TODO: Print current dir in prompt virtual text (fd)
-- TODO: on [No match] ask to create file
vim.api.nvim_create_user_command("Ido",
    function(opt)
        local ido = Ido:new()
        if opt.fargs[1] == 'fd' then
            ido.items = classify_files(get_files_in_path(vim.fn.getcwd()))
            ido.prompt = 'Find file: '

            local home = os.getenv('HOME')
            ido.cwd = vim.fn.getcwd()..'/'
            -- Override enter function
            ido.enter = function(self)
                if self.selected ~= nil  then
                    if self.selected:sub(-1) ~= '/' then
                        vim.cmd('bd! ', self.buf)
                        vim.fn.chdir(self.cwd)
                        vim.cmd("edit " .. self.selected .. " | stopinsert")
                    else
                        self.cwd = self.cwd..self.selected
                        self.items = classify_files(get_files_in_path(self.cwd))
                        vim.cmd('normal dd')
                        self:print_format()
                        self:set_prompt_exmark(self.prompt..' '..self.cwd:gsub(os.getenv('HOME'), '~'))
                    end
                else
                    local cur_col = vim.api.nvim_win_get_cursor(self.win)[2]
                    local input = vim.api.nvim_buf_get_text(self.buf, 0, 0, 0, cur_col, {})[1]
                    vim.api.nvim_command('e '..self.cwd..input)
                    print('No file "'..input..'" found created instead!')
                    vim.fn.chdir(self.cwd)
                end
            end

            ido:mount()
            ido:set_prompt_exmark(ido.prompt..' '..ido.cwd:gsub(os.getenv('HOME'), '~'))
            -- Navigate file system
            vim.keymap.set('i', '<BS>', function() 
                local cur_col = vim.api.nvim_win_get_cursor(ido.win)[2]
                if cur_col > 0 then 
                    vim.api.nvim_command('normal! X')
                else
                    ido.cwd = ido.cwd:gsub("([^/]+/)$", '')
                    ido.items = classify_files(get_files_in_path(ido.cwd))
                    vim.cmd('normal dd')
                    ido:print_format()
                    ido:set_prompt_exmark(ido.prompt..' '..ido.cwd:gsub(os.getenv('HOME'), '~'))
                end
            end, { buffer = ido.buf })
            -- Open CWD 
            vim.keymap.set('i', '<C-d>',
                function() 
                    if ido.selected ~= nil then
                        vim.api.nvim_command('e '..ido.cwd..' | stopinsert')
                    end
                end
                , { buffer = ido.buf } )
            -- Open splits
            vim.keymap.set('i', '<C-v>',
                function() 
                    if ido.selected ~= nil then
                        vim.api.nvim_command('vps | e '..ido.selected)
                    end
                end
                , { buffer = ido.buf } )
            vim.keymap.set('i', '<C-x>',
                function() 
                    if ido.selected ~= nil then
                        vim.api.nvim_command('sp | e '..ido.selected)
                    end
                end
                , { buffer = ido.buf } )
        elseif opt.fargs[1] == 'buf' then
            local bufs = {}
            local bufs_n = {}
            for _, v in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_get_option(v, 'buflisted') then
                    table.insert(bufs_n, vim.api.nvim_buf_get_name(v):match('([^/]+)$'))
                    bufs[vim.api.nvim_buf_get_name(v):match('([^/]+)$')] = v
                end
            end
            ido.items = bufs_n
            ido.prompt = 'Buffers: '
            ido.enter = function(self)
                if self.selected ~= nil then
                    vim.api.nvim_command('buffer '..bufs[self.selected])
                end
            end
            vim.keymap.set('i', '<C-v>',
                function() 
                    if ido.selected ~= nil then
                        vim.api.nvim_command('vps | buffer '..bufs[self.selected])
                    end
                end
                , { buffer = ido.buf } )
            vim.keymap.set('i', '<C-x>',
                function() 
                    if ido.selected ~= nil then
                        vim.api.nvim_command('sp | buffer '..bufs[self.selected])
                    end
                end
                , { buffer = ido.buf } )
            ido:mount()
        end

    end,
    { nargs = 1 })

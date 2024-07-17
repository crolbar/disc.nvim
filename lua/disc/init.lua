local disc = {}

local struct = require 'disc.deps.struct'

function disc:call(opcode, payload)
    self.pipe:read_start( function (read_err, chunk)
        if read_err then
            print("read err")
        elseif chunk then
            print("Connected")
            --local message = chunk:match("({.+)")
            --self.decode_json(message, function (_, body)
            --    print("e: " .. body)
            --end)
        end
    end)

    self.encode_json(payload, function(_, body)
        local msg = struct.pack('<ii', opcode, #body) .. body

        self.pipe:write(msg, function(write_err)
            if write_err then
                print("write err")
            else
                print("wrote msg")
            end
        end)
    end)
end

function disc:set_activity(activity)
    if not self.pipe then
        self.waiting_activity = { activity = activity }
    else
        local payload = {
            cmd = 'SET_ACTIVITY',
            nonce = '-',
            args = {
                activity = activity,
                pid = vim.loop:os_getpid()
            }
        }

        self:call(1, payload)
    end
end

function disc:setup()
    local id = "1219918645770059796";
    local socket = "/run/user/1000/discord-ipc-0"
    local pipe = assert(vim.loop.new_pipe(false))

    pipe:connect(socket, function(err)
        if err then
            pipe:close()
        else
            self.pipe = pipe

            local payload = {
                client_id = id,
                v = 1
            }

            self:call(0, payload)

            if self.waiting_activity then
                self:set_activity(self.waiting_activity.activity)
            end
        end
    end)

    self.SET("s1")
    self.SET("s2")
    self.SET("s3")


    vim.api.nvim_create_user_command('O', 'lua package.loaded.disc.SET("state2")', { nargs = 0 })
    vim.api.nvim_create_autocmd('ExitPre', {
        callback = function()
            self:disconnect()
        end
    })
end

function disc:disconnect()
    if self.pipe then
        self.pipe:close()
    end
end

function disc.SET(state)
    local current_file = vim.api.nvim_buf_get_name(0)

    local filename = "New File"
    local extension = ""

    if current_file then
        filename = current_file:match("([^/]+)$")
        extension = current_file:match("^.+(%..+)$")
    end

    local small_image = 'https://raw.githubusercontent.com/crolbar/disc/master/res/vim.png'

    if extension == '.lua' then
        small_image = 'https://raw.githubusercontent.com/crolbar/disc/master/res/lua.png'
    elseif extension == '.rs' then
        small_image = 'https://raw.githubusercontent.com/crolbar/disc//master/res/rust.png'
    end

    disc:set_activity({
        assets = {
            large_image = 'https://raw.githubusercontent.com/crolbar/yuki/master/imgs/Yuki-v0.1-1.jpg',
            large_text = 'the keyboard',
            small_image = small_image,
            small_text = 'the lang'
        },
        details = "In " .. filename,
        state = state,
        timestamps = {
            start = os.time(),
        },
        buttons = {
            {
                label = 'the keyboard',
                url = 'https://github.com/crolbar/yuki'
            },
            {
                label = 'this dumbass',
                url = 'https://github.com/crolbar'
            }
        }
    })
end

function disc.decode_json(t, callback)
    vim.schedule(function()
        callback(
            pcall(function()
                return vim.fn.json_decode(t)
            end)
        )
    end)
end

function disc.encode_json(t, callback)
    vim.schedule(function()
        callback(
            pcall(function()
                return vim.fn.json_encode(t)
            end)
        )
    end)
end

return disc

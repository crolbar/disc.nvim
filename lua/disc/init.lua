local disc = {}


local default_config = {
    timeout = 1500,

    large_image_text = "the keyboard",
    small_image_text = "the lang",
}

local struct = require 'disc.deps.struct'

function disc:call(opcode, payload)
    self.encode_json(payload, function(_, enc_payload)
        local msg = struct.pack('<ii', opcode, #enc_payload) .. enc_payload

        self.pipe:write(msg, function(write_err)
            if write_err then
                print("Write err: ", write_err)
            else
                print("Wrote msg to Discord.")

                self.pipe:read_start(function (read_err, read_msg)
                    if read_err then
                        print("Read err: " .. read_err)
                    elseif read_msg then
                        local message = read_msg:match("({.+)")

                        self.decode_json(message, function (_, body)

                            if body.evt == vim.NIL then
                                print("Connected to Discord.")
                            elseif body.evt == "ERROR" then
                                print("Error recieved from discorod: " .. body.data.message)
                            end

                            if self.callback_activity then
                                self:update_activity()
                                self.callback_activity = nil;
                            end
                        end)
                    end
                end)
            end
        end)
    end)
end

function disc:get_payload(activity)
    return {
        cmd = 'SET_ACTIVITY',
        nonce = '-',
        args = {
            activity = activity,
            pid = vim.loop:os_getpid()
        }
    }
end

function disc:update_activity()
    self:call(1,
        self:get_payload(
            self.callback_activity or self:get_activity()
        )
    )
end

function disc:connect()
    if self.pipe then
        self:disconnect()
        self.pipe = nil
    end

    local id = "1219918645770059796";
    local socket = "/run/user/1000/discord-ipc-0"
    local pipe = assert(vim.loop.new_pipe(false))

    pipe:connect(socket, function(err)
        if err then
            pipe:close()
            print("Could not connect with discord ipc. E: " .. err)
        else
            self.pipe = pipe
            local payload = {
                client_id = id,
                v = 1
            }

            self:call(0, payload)
        end
    end)

    self.start_time = os.time()
    self.callback_activity = self:get_activity()

    self.timer = vim.loop.new_timer()
    self.timer:start(0, self.config.timeout, vim.schedule_wrap(
        function()
            self:update_activity()
        end)
    )
end

function disc:setup(user_config)
    self.config = vim.tbl_deep_extend("force", default_config, user_config or {})

    self:connect()

    vim.api.nvim_create_user_command('DiscReconnect', 'lua package.loaded.disc:connect()', { nargs = 0 })
    vim.api.nvim_create_user_command('DiscDisconnect', 'lua package.loaded.disc:disconnect()', { nargs = 0 })

    vim.api.nvim_create_autocmd('ExitPre', {
        callback = function()
            self:disconnect()
        end
    })
end

function disc:disconnect()
    if self.pipe and not self.pipe:is_closing() then
        self.timer:stop()
        self.pipe:close()
    end
end

function disc:get_activity()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local current_file = vim.api.nvim_buf_get_name(0)

    local filename = "New File"
    local extension = ""

    local small_image = 'https://raw.githubusercontent.com/crolbar/disc.nvim/master/res/vim.png'

    if #current_file > 0 then
        filename = current_file:match("([^/]+)$")
        extension = current_file:match("^.+(%..+)$")
        if extension == '.lua' then
            small_image = 'https://raw.githubusercontent.com/crolbar/disc.nvim/master/res/lua.png'
        elseif extension == '.rs' then
            small_image = 'https://raw.githubusercontent.com/crolbar/disc.nvim/master/res/rust.png'
        end
    end


    return {
        assets = {
            large_image = 'https://raw.githubusercontent.com/crolbar/yuki/master/imgs/Yuki-v0.1-1.jpg',
            large_text = self.config.large_image_text,
            small_image = small_image,
            small_text = self.config.small_image_text,
        },
        details = "In " .. "yourmom",
        state = "Editing: `" .. filename .. "` at: " .. cursor[1] .. ":" .. cursor[2]+1,
        timestamps = {
            start = self.start_time,
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
    }
end

function disc.decode_json(t, callback)
    vim.schedule(function()callback(
        pcall(function()
            return vim.fn.json_decode(t)
        end)
    )end)
end

function disc.encode_json(t, callback)
    vim.schedule(function()callback(
        pcall(function()
            return vim.fn.json_encode(t)
        end)
    )end)
end

return disc

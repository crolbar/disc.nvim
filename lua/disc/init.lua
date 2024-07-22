local disc = {}

local function dec_hex(num)
    local hex = {}

    local quotient = math.floor(num / 16)
    local rem = num % 16
    table.insert(hex, 1, rem)

    while quotient ~= 0 do
        rem = quotient % 16
        quotient = math.floor(quotient / 16)
        table.insert(hex, 1, rem)
    end

    if #hex % 2 ~= 0 then
        table.insert(hex, 1, 0)
    end

    return hex
end

local function to_le_bytes(num)
    local function hex_dec(hex)
        local dec = 0;
        for i = 1, #hex do
            dec = dec + (
                hex[(#hex - i) + 1]
                * math.pow(16, i - 1)
            )
        end
        return dec
    end

    local hex = dec_hex(num)


    local le = {}

    for i = 1, 4 do
        if hex[i + #le] ~= nil then
            table.insert(le, 1,
                string.char(
                    hex_dec(
                        {
                            hex[i + #le],
                            hex[i + #le + 1]
                        }
                    )
                )
            )
        else
            table.insert(le, string.char(0))
        end
    end

    return table.concat(le)
end

local default_config = {
    timeout = 1500,

    large_image_text = "the keyboard",
    small_image_text = "the lang",
}

function disc:call(opcode, payload)
    self.encode_json(payload, function(_, enc_payload)
        local msg = to_le_bytes(opcode) .. to_le_bytes(#enc_payload) .. enc_payload

        self.pipe:write(msg, function(write_err)
            if write_err then
                print("Write err: ", write_err)
            else
                if self.callback_activity then
                    print("Wrote msg to Discord.")
                end

                self.pipe:read_start(function (read_err, read_msg)
                    if read_err then
                        print("Read err: " .. read_err)
                    elseif read_msg then
                        local message = read_msg:match("({.+)")

                        self.decode_json(message, function (_, body)

                            if body.evt == vim.NIL then
                                if self.callback_activity then
                                    self:update_activity()
                                    self.callback_activity = nil;

                                    print("Connected to Discord.")
                                end
                            elseif body.evt == "ERROR" then
                                print("Error recieved from discorod: " .. body.data.message)
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
            if self.timer then
                self.timer:stop()
            end
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
            if self.pipe then
                self:update_activity()
            end
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

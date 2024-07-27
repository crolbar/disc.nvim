local disc = {}

CLIENT_ID = "1219918645770059796";

local default_config = {
    timeout = 2000,                 -- num - how much time between updates

    details = nil,                  -- string 
    state = nil,                    -- string

    large_image = nil,              -- url
    large_image_text = "Vim btw",   -- string
    small_image = nil,              -- url
    small_image_text = nil,         -- stirng
    buttons = nil,
    -- if one will show two the default (show repo) and the specified one
    -- if two will overwrite the default
    -- exampl:
    --buttons = {
    --    {
    --        label = "first",
    --        url = "https://crolbar.com/"
    --    },
    --    {
    --        label = "sec",
    --        url = "https://crolbar.com/"
    --    }
    --}
}

function disc:call(opcode, payload)
    self.encode_json(payload, function(_, enc_payload)
        local to_le_bytes = require("disc.encode")
        local msg = to_le_bytes(opcode) .. to_le_bytes(#enc_payload) .. enc_payload

        self.pipe:write(msg, function(write_err)
            if write_err then
                self:disconnect()
                print("Write err: ", write_err)
            else
                if self.callback_activity then
                    print("Wrote msg to Discord.")
                end

                self.pipe:read_start(function (read_err, read_msg)
                    if read_err then
                        self:disconnect()
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
                                self:disconnect()
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

    local cmd = "ss -lx | grep -o '[^ ]*discord[^ ]*' | head -n 1"
    local socket = vim.trim(vim.fn.system(cmd));

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
                client_id = CLIENT_ID,
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

function disc.setup(user_config)
    disc.config = vim.tbl_deep_extend("force", default_config, user_config or {})

    disc:connect()

    vim.api.nvim_create_user_command('DiscReconnect', 'lua package.loaded.disc:connect()', { nargs = 0 })
    vim.api.nvim_create_user_command('DiscDisconnect', 'lua package.loaded.disc:disconnect()', { nargs = 0 })

    vim.api.nvim_create_autocmd('ExitPre', {
        callback = function()
            disc:disconnect()
        end
    })
end

function disc:disconnect()
    if self.pipe and not self.pipe:is_closing() then
        self.timer:stop()
        self.pipe:close()
    end
end

local function get_img_txt(filename, extension)
    local extensions = require("disc.langs")

    local img_name = extensions[extension]
    local txt = nil
    if extension == '.toml' and filename == 'Cargo.toml' then
        img_name = 'cargo'
        txt = 'cargo'
    elseif string.match(filename, "git") then
        img_name = "git"
        txt = filename
    elseif img_name then
        if img_name == "c" then
            txt = "clang"
        elseif img_name == "r" then
            txt = "r "
        else
            txt = img_name
        end
    else
        img_name = 'text'
        txt = filename or 'text'
    end

    return {
        img = string.format('https://raw.githubusercontent.com/crolbar/disc.nvim/master/res/%s.png', img_name),
        txt = txt or 'text'
    }
end


function disc:get_activity()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local curr_file = vim.api.nvim_buf_get_name(0)
    local curr_dir = vim.fn.getcwd()

    local filename = "New File"
    local repo_name = curr_dir:match("([^/]+)$")

    local default_image = 'https://raw.githubusercontent.com/crolbar/disc.nvim/master/res/vim.png'
    local small_image = nil
    local small_image_text = nil

    if #curr_file > 0 then
        if string.match(curr_file, "^oil://") then
            filename = "Oil"
        else
            filename = curr_file:match("([^/]+)$")
            local extension = curr_file:match("^.+(%..+)$")
            local un = get_img_txt(filename, extension)
            small_image = un.img
            small_image_text = un.txt
        end
    end


    local state = string.format([[Editing: `%s` at: %d:%d]], filename, cursor[1], cursor[2]+1)

    local activity = {
        details = self.config.details or ("In " .. repo_name),
        state = self.config.state or state,
        timestamps = {
            start = self.start_time,
        },
        assets = {
            large_image = self.config.large_image or default_image,
            large_text = self.config.large_image_text
        }
    }

    if small_image then
        activity.assets.small_image = self.config.small_image or small_image
        activity.assets.small_text = self.config.small_image_text or small_image_text
    end

    local cmd = "cd " .. curr_dir:gsub("\"", "\\\"") .. " && " .. "git config --get remote.origin.url"
    local repo_url = vim.trim(vim.fn.system(cmd));
    if repo_url and #repo_url > 0 then
        activity.details = self.config.details or ("In " .. repo_url:match("([^/]+)$"))

        if self.config.buttons then
            if #self.config.buttons == 2 then
                activity.buttons = self.config.buttons
            elseif #self.config.buttons == 1 then
                activity.buttons = {
                    {
                        label = 'Repository',
                        url = repo_url
                    },
                    {
                        label = self.config.buttons[1].label,
                        url = self.config.buttons[1].url
                    }
                }
            end
        else
            activity.buttons = self.config.buttons or {
                {
                    label = 'Repository',
                    url = repo_url
                }
            }
        end
    else
        activity.buttons = self.config.buttons;
    end

    return activity
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

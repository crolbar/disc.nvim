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

return function (num)
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

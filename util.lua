local util = {}

function util:countToWatermelon(count)
    if count == 0 then
        return "🐣"
    end

    local ret = ""
    local rem = count

    while rem > 0 do
        if rem >= 8 then
            ret = ret .. "🍉" 
            rem = rem - 8
        elseif rem >= 4 then
            ret = ret .. "🍍" 
            rem = rem - 4
        elseif rem >= 2 then
            ret = ret .. "🍊" 
            rem = rem - 2
        elseif rem >= 1 then
            ret = ret .. "🍒"
            rem = rem - 1
        end
    end

    return ret
end

return util

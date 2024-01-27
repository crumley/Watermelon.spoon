

local util = require("./util")

function assert( expect, actual, message )
    if expect ~= actual then
        print("FAIL: " .. (message or "") )
        print("   expected: '" .. (expect or "") .. "'")
        print("     actual: '" .. (actual or "") .. "'")
        os.exit(-1)
    end
end


assert(util:countToWatermelon(0), "🐣")
assert(util:countToWatermelon(1), "🍒")
assert(util:countToWatermelon(2), "🍊")
assert(util:countToWatermelon(3), "🍊🍒")
assert(util:countToWatermelon(4), "🍍")
assert(util:countToWatermelon(5), "🍍🍒")
assert(util:countToWatermelon(6), "🍍🍊")
assert(util:countToWatermelon(7), "🍍🍊🍒")
assert(util:countToWatermelon(8), "🍉")
assert(util:countToWatermelon(9), "🍉🍒")
assert(util:countToWatermelon(10), "🍉🍊")

print("PASS!!!")

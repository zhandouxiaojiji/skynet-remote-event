local skynet = require "skynet"
local revent = require "revent.revent"

require "skynet.manager"

local M = {}
function M.service1()
    skynet.start(function ()
        print "test service1"
        local CMD = {
            register = revent.register,
            unregister = revent.unregister,
            wait = revent.wait,
        }
        skynet.dispatch("lua", function (_, _, cmd, ...)
            local func = assert(CMD[cmd], cmd)
            func(...)
        end)
        skynet.name("service1", skynet.self())
        skynet.fork(function ()
            while true do
                skynet.sleep(100)
                print("pub event1")
                revent.pub("event1", 123, "abc", true)
                if math.random(2) == 1 then
                    revent.pub("event1", "cache test") -- 测试连续发送
                end
                print("pub event2")
                revent.pub("event2", "aaaaaaaaaaaaaaaaa")
            end
        end)
    end)
end

function M.service2()
    skynet.start(function ()
        print "test service2"
        local event_agent1 = revent.sub(nil, "service1", "event1", function (...)
            print("event1 callback", ...)
        end)
        local event_agent2 = revent.sub(nil, "service1", "event2", function (...)
            print("event2 callback", ...)
        end)

        skynet.timeout(500, function ()
            revent.unsub(event_agent1)
        end)
        skynet.timeout(1000, function ()
            revent.unsub(event_agent2)
        end)
    end)
end

return M
local skynet = require "skynet"
local cluster = require "skynet.cluster"
local revent = require "revent.revent"

require "skynet.manager"

local conf = {
    cluster1 = "127.0.0.1:8001",
    cluster2 = "127.0.0.1:8002"
}

local M = {}
function M.cluster1()
    skynet.start(function ()
        print "test cluster2 service1"
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
        cluster.reload(conf)
        cluster.open"cluster1"

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

function M.cluster2()
    skynet.start(function ()
        print "test cluster2 service2"
        cluster.reload(conf)
        cluster.open"cluster2"

        local event_agent1 = revent.sub("cluster1", "service1", "event1", function (...)
            print("event1 callback", ...)
        end)
        local event_agent2 = revent.sub("cluster1", "service1", "event2", function (...)
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
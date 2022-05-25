local skynet = require "skynet"
local service_event = require "revent.service_event"

require "skynet.manager"

local M = {}
function M.service1()
    skynet.start(function ()
        print "test service1"
        local CMD = {
            register = service_event.register,
            unregister = service_event.unregister,
            wait = service_event.wait,
        }
        skynet.dispatch("lua", function (_, _, cmd, ...)
            print("recv cmd", cmd, ...)
            local func = assert(CMD[cmd], cmd)
            func(...)
        end)
        skynet.name("service1", skynet.self())
        skynet.fork(function ()
            while true do
                skynet.sleep(100)
                print("pub event1")
                service_event.pub("event1", 123, "abc", true)
            end
        end)
    end)
end

function M.service2()
    skynet.start(function ()
        print "test service2"
        local event_agent = service_event.sub("service1", "event1", function (...)
            print("event1 callback", ...)
        end)
        skynet.timeout(500, function ()
            service_event.unsub(event_agent)
        end)
    end)
end

return M
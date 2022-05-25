# skynet 服务间的消息订阅与派发
利用协程挂起简单的实现了服务间的消息订阅与派发(包括集群内)，订阅者按需订阅或取消，事件的派发者无需再关心往哪里投递消息。

# 原理
A服务向B订阅事件，skynet.call调用B服务，B服务skynet.wait挂起当前协程，等到需要派发事件时再skynet.wakeup唤醒协程，通过skynet.retpack把消息回复给A服务，A服务处理完消息后，再重复这个流程。

# 进程内使用
```lua
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
```

# 跨节点使用
```lua
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
```

# TODO
+ 异常处理
+ 处理超时订阅者
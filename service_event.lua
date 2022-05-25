local skynet = require "skynet"

local tinsert = table.insert
local tunpack = table.unpack

local M = {}

-- 订阅方
function M.sub(service, event, callback_func)
    assert(callback_func)
    local agent = {
        id = nil,
        service = service,
        event = event,
    }
    agent.id = skynet.call(service, "lua", "register", event)
    skynet.fork(function ()
        while agent.watching do
            local args = skynet.call(service, "lua", "wait", event)
            for _, arg in ipairs(args) do
                callback_func(tunpack(arg))
            end
        end
    end)
    return agent
end

function M.unsub(agent)
    agent.watching = false
    skynet.call(agent.service, "lua", "unregister", agent.id)
end


-- 派发方
local event2agents = {}
local id2agent = {}
local auto_id = 0
local function get_agents(event)
    local agents = event2agents[event] or {}
    event2agents[event] = agents
    return agents
end
function M.register(event)
    assert(event)
    local agents = get_agents(event)
    auto_id = auto_id + 1
    local agent = {
        id = auto_id,
        event = event,
        args = {},
    }
    agents[agent.id] = agent
    id2agent[agent.id] = agent
    skynet.retpack(agent.id)
end

function M.unregister(id)
    local agent = assert(id2agent[id], id)
    id2agent[id] = nil
    local agents = event2agents[agent.event]
    agents[id] = nil
end

function M.wait(id)
    local agent = assert(id2agent[id], id)
    if #agent.args > 0 then
        skynet.retpack(agent.args)
        return
    end
    agent.co = coroutine.running()
    skynet.wait()
    skynet.retpack(agent.args)
    agent.args = {}
    agent.co = nil
end

function M.pub(event, ...)
    local agents = event2agents[event]
    if not agents then
        return
    end
    for _, agent in pairs(agents) do
        tinsert(agent.args, {...})
        skynet.wakeup(agent.co)
    end
end

return M
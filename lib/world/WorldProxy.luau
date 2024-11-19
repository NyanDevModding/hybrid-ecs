--[=[
    @class WorldProxy

    Act as a proxy of world in a system or anything outside of hybrid-ecs.

    Wrap the world for an use in general. It tracks if there is any hypothesis
    and call method from it instead of the world's ones.
]=]
local WorldProxy = {}
WorldProxy.__index = WorldProxy

export type WorldProxy = typeof(WorldProxy.new())

type World = typeof(require(script.Parent.World).new())

function WorldProxy.new(world : World)
    return setmetatable({
        _world = world,
    }, WorldProxy)
end

function WorldProxy.openHypothesis(self : WorldProxy, newHypothesis)
    return self._world:openHypothesis(newHypothesis)
end

function WorldProxy.closeHypothesis(self : WorldProxy)
    return self._world:closeHypothesis()
end

function WorldProxy.isBuildingHypothesis(self : WorldProxy)
    return self._world:isBuildingHypothesis()
end

function WorldProxy.resetListenerHypothesis(self : WorldProxy)
    return self._world:resetListenerHypothesis()
end

function WorldProxy.setQueryCache(self : WorldProxy, queryCache)
    return self._world:setQueryCache(queryCache)
end

function WorldProxy.getStorageSize(self : WorldProxy)
    return self._world:getStorageSize()
end

function WorldProxy.copyIdProvider(self : WorldProxy)
    return self._world:copyIdProvider()
end

function WorldProxy.spawnAt(self : WorldProxy, entityId : number, componentDict)
    -- in case an hypothesis is listening for the changes of world
    if self:isBuildingHypothesis() then
        return self._world:getListenerHypothesis():spawnAt(entityId, componentDict)
    end

    return self._world:spawnAt(entityId, componentDict)
end

function WorldProxy.getNextId(self : WorldProxy)
    return self._world:getNextId()
end

function WorldProxy.spawn(self : WorldProxy, components)
    -- in case an hypothesis is listening for the changes of world
    if self:isBuildingHypothesis() then
        return self._world:getListenerHypothesis():spawn(components)
    end

    return self._world:spawn(components)
end

function WorldProxy.despawn(self : WorldProxy, entityId : number)
    -- in case an hypothesis is listening for the changes of world
    if self:isBuildingHypothesis() then
        return self._world:getListenerHypothesis():despawn(entityId)
    end

    return self._world:despawn(entityId)
end

function WorldProxy.get(self : WorldProxy, entityId)
    -- in case an hypothesis is listening for the changes of world
    if self:isBuildingHypothesis() then
        return self._world:getListenerHypothesis():get(entityId)
    end

    return self._world:get(entityId)
end

function WorldProxy.contains(self : WorldProxy, entityId : number)
    -- in case an hypothesis is listening for the changes of world
    if self:isBuildingHypothesis() then
        return self._world:getListenerHypothesis():contains(entityId)
    end

    return self._world:contains(entityId)
end

function WorldProxy.insert(self : WorldProxy, entityId : number, componentName : string, component)
    -- in case an hypothesis is listening for the changes of world
    if self:isBuildingHypothesis() then
        return self._world:getListenerHypothesis():insert(entityId, componentName, component)
    end

    return self._world:insert(entityId, componentName, component)
end

function WorldProxy.remove(self : WorldProxy, entityId : number, componentName : string)
    -- in case an hypothesis is listening for the changes of world
    if self:isBuildingHypothesis() then
        return self._world:getListenerHypothesis():remove(entityId, componentName)
    end

    return self._world:remove(entityId, componentName)
end

function WorldProxy.getComponent(self : WorldProxy, entityId : number, componentName : string)
    -- in case an hypothesis is listening for the changes of world
    if self:isBuildingHypothesis() then
        return self._world:getListenerHypothesis():getComponent(entityId, componentName)
    end

    return self._world:getComponent(entityId, componentName)
end

function WorldProxy.startCaching(self : WorldProxy)
    return self._world:startCaching()
end

function WorldProxy.stopCaching(self : WorldProxy)
    return self._world:stopCaching()
end

function WorldProxy.addLoop(self : WorldProxy, loop)
    return self._world:addLoop(loop)
end

function WorldProxy.getQueryIterator(self : WorldProxy, archetype : {string}?)
    return self._world:getQueryIterator(archetype)
end

function WorldProxy.query(self : WorldProxy, ...)
    -- in case an hypothesis is listening for the changes of world
    if self:isBuildingHypothesis() then
        return self._world:getListenerHypothesis():query(...)
    end

    return self._world:query(...)
end

function WorldProxy.readQuery(self : WorldProxy, ...)
    -- in case an hypothesis is listening for the changes of world
    if self:isBuildingHypothesis() then
        return self._world:getListenerHypothesis():readQuery(...)
    end

    return self._world:readQuery(...)
end

function WorldProxy.breakQuery(self : World)
    -- in case an hypothesis is listening for the changes of world
    if self:isBuildingHypothesis() then
        return self._world:getListenerHypothesis():breakQuery()
    end

    return self._world:breakQuery()
end

function WorldProxy.getRawWorld(self : WorldProxy)
    return self._world
end

return WorldProxy
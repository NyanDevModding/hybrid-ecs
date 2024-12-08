local Component = require(script.Parent.Component)
local RegisteredComponent = require(script.Parent.RegisteredComponent)
local EntityMirror = require(script.Parent.Parent.world.EntityMirror)

--[=[
    @class Supervisor
    @extend Component

    The Supervisor is a special component that store informations about its
    entity. It can return a mirror of it. It is created by a WorldLike object
    and when hypothetized or committed, its world is updated to the new one.

    The reference to the supervised entity is retrieved by storing a
    reference to the world and the entity's id.

    :::caution:::
    The stored world is a low-level world, not a proxy.
]=]
local Supervisor = table.clone(Component)
Supervisor.__index = Supervisor

Supervisor.NAME = "supervisor"
Supervisor.REGISTERED = RegisteredComponent.new(
    Supervisor.NAME,
    function(world : {}, entityId : number)
        return Supervisor.new(world, entityId)
    end
)

export type Supervisor = typeof(Supervisor.new())

function Supervisor.new(world : {}, entityId : number)
    return setmetatable({
        _world = world,
        _entityId = entityId
    }, Supervisor)
end

--[=[
    @within Supervisor
    @function get
    @return EntityMirror -- a mirror of the supervised entity

    Get the supervised entity's mirror.
]=]
function Supervisor.get(self : Supervisor): EntityMirror.EntityMirror
    return self._world:get(self._entityId)
end

--[=[
    @within Supervisor
    @function setWorld
    @param world World? -- the world where is now located the entity

    Set the supervised entity's world
]=]
function Supervisor.setWorld(self : Supervisor, world : {}?)
    self._world = world
end

--[=[
    @within Supervisor
    @function getEntityId
    @return number -- the id of the supervised entity

    Get the supervised entity's id
]=]
function Supervisor.getEntityId(self : Supervisor)
    return self._entityId
end

--[=[
    @within Supervisor
    @function setEntityId
    @param entityId number -- the new id of the supervised entity

    Set a new id for the supervised entity
]=]
function Supervisor.setEntityId(self : Supervisor, newId : number)
    self._entityId = newId
end

--[=[
    @within Supervisor
    @function isNull

    Check if the supervisor is always supervising.
]=]
function Supervisor.isNull(self : Supervisor)
    return self._world == nil or self._entityId == nil
end

--[=[
    @within Supervisor
    @function check

    Check if the supervisor is null and if it is, then destroy it.
]=]
function Supervisor.check(self : Supervisor)
    if self:isNull() then
        self:destroy()
        return false
    end
    return true
end

function Supervisor.formatClone(self : Supervisor, clone : Supervisor)
    Component.formatClone(self, clone)

    clone:setEntityId(self._entityId)
    clone:setWorld(self._world)
end

function Supervisor.clone(self : Supervisor)
    local clone = Supervisor.new(self._world, self._entityId)
    self:formatClone(clone)
    return clone
end

function Supervisor.onRemoved(self : Supervisor)
    self:destroy()
end

--[=[
    @within Supervisor
    @function destroy

    Destroy the reference
]=]
function Supervisor.destroy(self : Supervisor)
    self._world = nil
    self._entityId = nil
end

Supervisor.NULL = Supervisor.new()

return Supervisor
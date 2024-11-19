local Component = require(script.Parent.Parent.component.Component)

local HypothesisWorldInterface = require(script.Parent.HypothesisWorldInterface)
local WorldTypes = require(script.Parent.WorldTypes)

-- types
type component = Component.Component
type defaultComponentInstance = WorldTypes.defaultComponentInstance
type entity = WorldTypes.entity
type HypothesisWorldInterface = HypothesisWorldInterface.HypothesisWorldInterface

--[=[
    @class EntityMirror

    Let you read an entity but protect it from being modified. The components
    can be modified but you have to call specific method to entirely replace
    them or remove them.

    :::caution
        An entityMirror should never be stored, it is meant to instant consumation
        and usage, only the cache can store it as it is safed by method inner to
        world.
        if you store it in a variable, be aware to nil it before you create any
        function in that scope as a function stores its env and preserves the
        entityMirror if its in a variable.
    :::
]=]
local EntityMirror = {}
EntityMirror.__index = EntityMirror

export type EntityMirrorClass = typeof(EntityMirror)
export type EntityMirror = typeof(EntityMirror.new())

--[=[
    @within EntityMirror
    @function new
    @param world HypothesisWorldInterface -- the world where the entity is located
    @param entityId number -- the id of the entity to mirror
    @param entity {[string]: {[any] : any}} -- the entity to mirror
    @return EntityMirror instance

    Create a new entityMirror for the provided entity
]=]
function EntityMirror.new(world : HypothesisWorldInterface, entityId : number, entity : entity)
    return setmetatable({
        world = world,
        id = entityId,
        -- this is why mirrors should **never** be stored : the entity will
        -- not be garbage collected if its not in the world anymore.
        _entity = entity
    }, EntityMirror)
end

--[=[
    @within EntityMirror
    @function getComponent
    @param componentType component -- the type of component to get

    Return the component stored as the name of the provided componentType
]=]
function EntityMirror.getComponent(self : EntityMirror, componentName : string)
    return self._entity[componentName]
end

--[=[
    @within EntityMirror
    @function insert
    @param componentinstance componentInstance -- the component to add

    Call the world:insert method on the mirrored entity
]=]
function EntityMirror.insert(self : EntityMirror, component : component)
    self.world:insert(self.id, component)
end

--[=[
    @within EntityMirror
    @function remove
    @param componentType component -- the type of component to remove

    Call the world:remove method on the mirrored entity
]=]
function EntityMirror.remove(self : EntityMirror, componentName : string)
    self.world:remove(self.id, componentName)
end

--[=[
    @within EntityMirror
    @function iterate
    @return typeof(pairs(entity)) -- a iterable result

    Let you iterate over the components of the entity.

    ```lua
    for componentName, componentInstance in entity:iterate() do
        -- some work about components
    end
    ```
]=]
function EntityMirror.iterate(self : EntityMirror)
    return pairs(self._entity)
end

--[=[
    @within EntityMirror
    @function terminate

    Destroy the mirror entity and stops reflecting the entity
]=]
function EntityMirror.terminate(self : EntityMirror)
    self.id = nil
    self._entity = nil
    self.world = nil
    setmetatable(self, nil)
end

--[=[
    @within EntityMirror
    @function despawn

    Despawn the entity that is mirrored by this mirror and erminate it.
]=]
function EntityMirror.despawn(self : EntityMirror)
    self.world:despawn(self.id)
    self:terminate()
end

function EntityMirror.__index(entityMirror : EntityMirror, index : any)
    if EntityMirror[index] then
        return EntityMirror[index]
    elseif entityMirror._entity[index] then
        -- literaly returns the componentInstance because in hecs,
        -- componentInstances are modifiable.
        return entityMirror._entity[index]
    end
    return nil
end

function EntityMirror.__iter(entityMirror : EntityMirror)
    return next, entityMirror._entity
end

return EntityMirror
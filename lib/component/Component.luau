local ComponentReference = require(script.Parent.ComponentReference)

--[=[
    @class Component
    @abstract
]=]
local Component = {}
Component.__index = Component

Component.NULL_REFERENCE = ComponentReference.NULL

export type ComponentClass = typeof(Component)
export type Component = typeof(Component.new())

function Component.extend(self : ComponentClass)
    return table.clone(self)
end

-- (no need to call this constructor from a child constructor as it does not
-- do anything and won't)
function Component.new()
    return setmetatable({}, Component)
end

--[=[
    @within Component
    @function formatClone
    @param clone Component -- the cloned component to format

    Alter the data of a clone in creation.
]=]
function Component.formatClone()
end

--[=[
    @within Component
    @function clone

    Return a copy of the component
]=]
function Component.clone(self : Component)
    local clone = getmetatable(self).new()
    self:formatClone(clone)

    return clone
end

--[=[
    @within Component
    @function hasReference

    Check if the component already have a reference created.
]=]
function Component.hasReference(self : Component)
    return self._reference ~= nil
end

--[=[
    @within Component
    @function getReference

    Return the ComponentReference of the component that will be nulled when
    this component is removed.
]=]
function Component.getReference(self : Component)
    if self._reference == nil then
        self._reference = ComponentReference.new(self)
    end
    return self._reference
end

--[=[
    @within Component
    @function onReplacing
    @param other Component -- the other component that replaces this one
    @param componentName string -- the name of the removed component
    @param entityId number -- the entity where was located the component
    @param world World -- the world where was located the component

    This listener method is called when the component is removed from its
    entity or world.
]=]
function Component.onReplacing(self : Component, other : Component, _ : string, _ : number, _) : ComponentReference.ComponentReference<Component>
    -- update the reference to point to the new component.
    if self._reference ~= nil then
        self._reference:update(other:getReference())
    end
end

--[=[
    @within Component
    @function onRemoved
    @param componentName string -- the name of the removed component
    @param entityId number -- the entity where was located the component
    @param world World -- the world where was located the component

    This listener method is called when the component is removed from its
    entity or world.
]=]
function Component.onRemoved(self : Component, _ : string, _ : number, _)
    if self._reference ~= nil then
        self._reference:destroy()
    end
end

--[=[
    @within Component
    @function destroy

    Destroy the component and clear its reference.
]=]
function Component.destroy(self : Component)
    if self._reference ~= nil then
        self._reference:destroy()
    end
end

-- function Component.toJson()
-- end

return Component
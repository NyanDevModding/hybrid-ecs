--[=[
    @class ComponentReference

    The ComponentReference is an object that can be stored anywhere and that
    stores a reference to an entity. The component is retrieved by calling
    :get() and this reference is set to nil when the component is removed
    from the world.

    A component stores its reference as the reference field and it can be got
    by calling :getReference on any component.
]=]
local ComponentReference = {}
ComponentReference.__index = ComponentReference

export type ComponentReference<T> = {
    get : (self : ComponentReference<T>) -> T?,
    set : (self : ComponentReference<T>, component : T) -> T,
    destroy : (self : ComponentReference<T>) -> nil
} & typeof(ComponentReference.new())

function ComponentReference.new(component : {}?)
    return setmetatable({
        component = component
    }, ComponentReference)
end

--[=[
    @within ComponentReference
    @function isNull
    @return boolean -- if the component is null

    Check if the reference is null. This happens when the referenced
    component is removed. Thus, the get() method returns nil.
]=]
function ComponentReference.isNull(self : ComponentReference<any>)
    if self._updated ~= nil then
        return self._updated:isNull()
    end

    return self.component == nil
end

--[=[
    @within ComponentReference
    @function get
    @return Component? -- the referenced component

    Return the referenced component, nil if it has been removed.
]=]
function ComponentReference.get(self : ComponentReference<any>)
    if self._updated ~= nil then
        return self._updated:get()
    end

    return self.component
end

-- #Why update system in reference ??

-- The problem with having only one ComponentReference to a component is that
-- we can't properly insert a component on top of another (inserting a
-- component in an entity where there is already a component for this name).
-- Thus, replacing one with another will end up getting separated
-- references on the same component and as we can't get the watchers of this
-- reference, we can't tell them to swap on only one of the component. The
-- solution is to update a reference to point to the other reference. A crawler
-- janitor should crawl throught a world, replacing null references by the NULL
-- reference and transforming low version of references to their updated
-- version.


--[=[
    @within ComponentReference
    @function update
    @param updated ComponentReference -- the updated version of the reference

    Update the reference to point to another. This method is used while fusing references.
]=]
function ComponentReference.update(self : ComponentReference<any>, updated : ComponentReference<any>)
    if self._updated ~= nil then
        return self._updated:update(updated)
    end

    self._updated = updated
    self.component = nil
end

--[=[
    @within ComponentReference
    @function isUpdated
    @return boolean -- if the reference is updated

    Return if the reference is updated.
]=]
function ComponentReference.isUpdated(self : ComponentReference<any>)
    return self._updated ~= nil
end

--[=[
    @within ComponentReference
    @function getUpdated
    @return ComponentReference -- the updated version

    Return the updated version of the reference.
]=]
function ComponentReference.getUpdated(self : ComponentReference<any>)
    return self._updated
end

--[=[
    @within ComponentReference
    @function destroy

    Destroy the reference, thus, all the component pointing to this referenc
    see it as null.
]=]
function ComponentReference.destroy(self : ComponentReference<any>)
    if self._updated ~= nil then
        return self._updated:destroy()
    end

    self.component = nil
end

ComponentReference.NULL = ComponentReference.new(nil)

return ComponentReference
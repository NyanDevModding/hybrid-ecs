--[=[
    @class Component
    @abstract
]=]
local Component = {}
Component.__index = Component

export type ComponentClass = typeof(Component)
export type Component = typeof(Component.new())

-- local ABSTRACT_METHOD_ERROR = "The method : %s called in the Component child is " ..
--     "abstract.\nPlease check that you did override it in the child object."

-- local function markAsAbstract(methodName : string?)
--     error(string.format(
--         ABSTRACT_METHOD_ERROR,
--         methodName or "unknown?"
--     ))
-- end

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
    @function makeHypothesis
    @param entityId number -- the id of the entity where the component
    is located
    @param componentName string -- the name of the component to create an
    hypothethic version from
    @param hypothesis WorldHypothesis -- the hypothesis that ask to hypothtize
    this component
    @param hypothesisMerger HypothesisMerger -- the merger where the the
    component can acquire data
    @return Component -- the hypothetized component

    Return a component's clone for an hypothesis. This method is called when the
    hypothesis needs to shadow some component of the world. It is useful when
    the component need to know some data from the merger to prevent the merge
    from leading to bugs.

    e.i. : The CompositeComponent override this method to give proper numeros
    to new multiplied component to prevent them from being merged with others
    in the merger as they could get the same numero.
]=]
function Component.makeHypothesis(self : Component, _, _, _, _)
    return self:clone()
end

--[=[
    @within Component
    @function fuse

    Fuse another component into this component. It should always merge the
    other component into the this one.

    Used while merging 2 components of the same type from 2 hypothesis

    It adds the other component's fields to its if they are nil.
]=]
function Component.fuseWith(self : Component, other : Component)
    -- dirty way, pls override it.
    for k, v in pairs(other) do
        if self[k] == nil then
            self[k] = v
        end
    end
end

--[=[
    @within Component
    @function clone

    Return a copy of the component
]=]
function Component.clone(self : Component)
    return table.clone(self)
end

-- function Component.toJson()
-- end

return Component
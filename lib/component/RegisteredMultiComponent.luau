local RegisteredComponent = require(script.Parent.RegisteredComponent)
local CompositeComponent = require(script.Parent.CompositeComponent)

--[=[
    @class RegisteredMultiComponent
    @extend RegisteredComponent

    Store a name for a component and its builder (a lambda function that
    returns a component)
]=]
local RegisteredMultiComponent = table.clone(RegisteredComponent)
RegisteredMultiComponent.__index = RegisteredMultiComponent

export type RegisteredMultiComponent = typeof(RegisteredMultiComponent.new())

local DEFAULT_COMPOSITE_BUILDER = function(concreteBuilder, components)
    return CompositeComponent.new(concreteBuilder, components)
end

function RegisteredMultiComponent.new<component>(
    name : string,
    builder : (...any) -> component,
    compositeBuilder : (
        (builder : (...any) -> component, ...any)
        -> CompositeComponent.CompositeComponent
    )?
)
    local instance = RegisteredComponent.new(name, builder)
    instance.compositeBuilder = compositeBuilder
    return setmetatable(instance, RegisteredMultiComponent)
end

function RegisteredMultiComponent.buildComposite(self : RegisteredMultiComponent, ... : any)
    return (
        if
            self.compositeBuilder ~= nil
        then
            self.compositeBuilder(self.builder, ...)
        else
            DEFAULT_COMPOSITE_BUILDER(self.builder, ...)
    )
end

return RegisteredMultiComponent
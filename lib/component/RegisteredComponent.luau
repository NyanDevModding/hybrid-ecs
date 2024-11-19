--[=[
    @class RegisteredComponent

    Store a name for a component and its builder (a lambda function that call
    that returns a component)
]=]
local RegisteredComponent = {}
RegisteredComponent.__index = RegisteredComponent

export type RegisteredComponent = typeof(RegisteredComponent.new())

function RegisteredComponent.new(name : string, builder : (...any) -> {any})
    return setmetatable({
        name = name,
        builder = builder
    }, RegisteredComponent)
end

function RegisteredComponent.getName(self : RegisteredComponent)
    return self.name
end

function RegisteredComponent.build(self : RegisteredComponent, ...)
    return self.builder(...)
end

function RegisteredComponent.__call(self : RegisteredComponent, ...)
    return self:build(...)
end

return RegisteredComponent
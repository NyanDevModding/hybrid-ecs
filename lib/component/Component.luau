local ComponentHandler = require(script.Parent.ComponentHandler)

local Component = {}
Component.__index = Component

export type ComponentClass = typeof(Component)
export type Component = typeof(Component.new())
type componentInstance = typeof(Component.new().__call()) & defaultHandler
export type genericComponent<standardData, handler> = componentInstance & standardData & handler

local ERROR_PATCH_NIL = (
    "seems like you forgot to provide replacing data to "
    .. "patch. If you want to clone the component, consider using the clone "
    .. "method"
)

Component._defaultComponentHandler = ComponentHandler.new({
    clone = function(self : componentInstance)
        local component = getmetatable(self)
        -- as table.clone does not clone the metatable
        return component(table.clone(self))
    end,
    patch = function(self : componentInstance, replacingData : {[any] : any})
        assert(replacingData ~= nil, ERROR_PATCH_NIL)
        local component = getmetatable(self)

        -- as table.clone does not preserve the metatable
        local newData = table.clone(self)
        for dataName, data in pairs(replacingData) do
            newData[dataName] = data
        end

        return component(newData)
    end
})
type defaultHandler = typeof(Component._defaultComponentImplementation)

-- check for metamethod in the handler and propagate them to the component.
local function _propagateHandlerMetamethods(component : Component)
    for methodName, method in pairs(component.handler.implementation) do
        local start, finish = string.find(methodName, "__")
        if start == 1 and finish == 2 then
            component[methodName] = method
        end
    end
end

--[=[
    @within Component
    @function new
    @param name string -- the name of the component
    @param defaultData {[any] : any}? -- the default data of the component
    @param handler {[string] : (...any) -> any} -- the secondary index of the
    component instance
    @return Component -- the new component

    Create a new component with a name, its defaultData and a facultative
    handler. The handler is the secondary index of the component, it means that
    the instances of this component will have access to its methods.

    ```lua
    -- creation of the component
    local HEALTH = Component.new("health", {value = 100})
    -- you can add an handler for a more oop approach, just add the handler as
    -- the third argument

    -- instanciation of a component
    local componentInstance = HEALTH({value = 200}) -- or HEALTH:create({value = 200})
    ```
]=]
function Component.new(name : string, defaultData : {any}?, handler : ComponentHandler.ComponentHandler?)
    -- propagate default method to the handler
    if handler ~= nil then
        handler:include(Component._defaultComponentHandler.implementation)
    else
        handler = Component._defaultComponentHandler
    end

    local component = setmetatable({
        name = name,
        defaultData = defaultData,
        handler = handler,
        -- prepare the index in prevision of the moment the component will be
        -- instanciated
        __index = handler.implementation
    }, Component)
    _propagateHandlerMetamethods(component)

    return component
end

--[=[
    @within Component
    @function create
    @param datas {any} -- the data to create the component with.

    Create a new componentInstance to store in an entity, its metatable is the
    component.
]=]
function Component.create(self : Component, datas : {any}?)
    if datas ~= nil then
        datas = table.clone(datas)
        -- replace nil data with default if defaultData exists
        if self.defaultData ~= nil then
            for dataName, data in pairs(self.defaultData) do
                if datas[dataName] == nil then
                    datas[dataName] = data
                end
            end
        end
    elseif self.defaultData ~= nil then
        -- no provided data (datas = nil) and ddefaultData defined
        datas = table.clone(self.defaultData)
    else
        -- no provided datas and no defaultData -> empty component
        datas = {}
    end

    return setmetatable(datas, self)
end

function Component.__call(self : Component, datas : {any})
    return self:create(datas)
end

return Component
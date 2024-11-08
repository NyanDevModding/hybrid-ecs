--[=[
    @class ComponentHandler

    A ComponentHandler is the implementation of a component object, it is
    passed during the creation of the component and basically acts as its
    methods.

    You can define **metamethods** in your handler, it will affect the
    component, for example, if you define the *__tostring* method, then
    *tostring(yourComponentInstance)* will call it
]=]
local ComponentHandler = {}
ComponentHandler.__index = ComponentHandler

export type ComponentHandlerClass = typeof(ComponentHandler)
export type ComponentHandler = typeof(ComponentHandler.new())

local ERROR_HANDLER_METHOD_NAME_NOT_STRING = "Provided name for "
    .. "ComponentHandler is not a string :\n    Expected a string\n    "
    .. "Received : %s"
local ERROR_HANDLER_METHOD_NOT_FUNCTION = "Provided method for ComponentHandler"
    .. "is not a function :\n   For %s\n   Expected a function\n    Received a %s"

--[=[
    @within ComponentHandler
    @function new
    @param methods {(...any) -> any} -- the methods to implement in the
    Componenthandler
    @return ComponentHandler

    Creates a new componentHandler.

    A ComponentHandler is the implementation of a component object, it is
    passed during the creation of the component and basically acts as its
    methods.

    You can define **metamethods** in your handler, it will affect the
    component, for example, if you define the *__tostring* method, then
    *tostring(yourComponentInstance)* will call it
]=]
function ComponentHandler.new(methods : {string : (self : any, ...any) -> any}?)
    return setmetatable({
        implementation = methods or {},
        _implements = {}
    },ComponentHandler)
end

--[=[
    @within ComponentHandler
    @function merge
    @param someHandler ComponentHandler -- the first handler to merge
    @param otherHandler ComponentHandler -- the second handler to merge
    @param ... ComponentHandler -- any other additional handler to merge
    @return ComponentHandler

    Create a new componentHandler from the fusion of the implementation of two
    others.
]=]
function ComponentHandler.merge(someHandler : ComponentHandler, otherHandler : ComponentHandler, ... : ComponentHandler)
    -- merge all the other componentHandlers
    if #{...} > 0 then
        otherHandler = ComponentHandler.merge(otherHandler, ...)
    end

    local fuseImplementation = table.clone(otherHandler.implementation)
    for methodName, method in someHandler do
        fuseImplementation[methodName] = method
    end

    local componentHandler = ComponentHandler.new(fuseImplementation)

    -- as it is a constructor function, I consider myself able to access
    -- private fields of provided objects (that doesn't make sens but
    -- OPTIMIZATION)
    for _, interface in ipairs(someHandler._implements) do
        componentHandler:implement(interface)
    end
    for _, interface in ipairs(otherHandler._implements) do
        componentHandler:implement(interface)
    end

    return componentHandler
end

--[=[
    @within ComponentHandler
    @function add
    @param methodName string -- the name of the method to add
    @param method (...any) -> any -- the method
    @return ComponentHandler

    Add a method in the component, return itself so it's chainable
]=]
function ComponentHandler.add(self : ComponentHandler, methodName : string,method : (...any) -> any)
    -- check if methodName and method are ok
    assert(
        type(methodName) == "string",
        string.format(
            ERROR_HANDLER_METHOD_NAME_NOT_STRING,
            type(methodName)
        )
    )
    assert(
        type(method) == "function",
        string.format(
            ERROR_HANDLER_METHOD_NOT_FUNCTION,
            methodName,
            type(method)
        )
    )

    self.implementation[methodName] = method
    return self
end

--[=[
    @within ComponentHandler
    @function include
    @param mixin {[string] : (...any) -> any} -- the mixin to include
    @return ComponentHandler

    Add all the methods from a mixin in the component, return itself so it's
    chainable
]=]
function ComponentHandler.include(self : ComponentHandler, mixin : {[string] : (...any) -> any})
    for methodName, method in pairs(mixin) do
        self:add(methodName, method)
    end
    return self
end

--[=[
    @within ComponentHandler
    @function implement
    @param interface {isImplementing : (t : {any}) -> boolean} -- the interface
    to implement
    @return ComponentHandler

    Implement the interface, check if it is implementing its methods and then
    stores it in its _implements list.

    The interface should comport a method called isImplementing.

    You can always use an Adapter design pattern I think (like a table with a
    method isImplementing() that iterate over the interface)
]=]
function ComponentHandler.implement(self : ComponentHandler, interface : {isImplementing : (t : {any}) -> boolean})
    assert(
        interface:isImplementedBy(self.implementation),
        "The componentHandler is not implementing the provided interface."
    )

    -- checks if the implementation is already marked and mark it if it isn't
    for _, implementing in ipairs(self._implements) do
        if implementing == interface then
            return
        end
    end
    table.insert(self._implements, interface)
    return self
end

--[=[
    @within ComponentHandler
    @function isImplementing
    @param interface {any} -- the interface to check
    @return boolean

    Check if a reference to this interface is stored in _implements and if not,
    check if all the methods of the interface are implemented inside the
    handler.
]=]
function ComponentHandler.isImplementing(self :ComponentHandler, interface)
    for _, implemented in ipairs(self._implements) do
        if implemented == interface then
            return true
        end
    end

    if interface:isImplementedBy(self.implementation) then
        return true
    end

    return false
end

--[=[
    @within ComponentHandler
    @function iterate
    @return typeof(pairs())

    Return an iterable pairs that iterates over the methods of the handler
]=]
function ComponentHandler.iterate(self : ComponentHandler)
    return pairs(self.implementation)
end

--[=[
    @within ComponentHandler
    @function __iter

    Return an iterable pairs that iterates over the methods of the handler
]=]
function ComponentHandler.__iter(self : ComponentHandler)
    return next, self.implementation
end

--[=[
    @within ComponentHandler
    @function __newindex

    Add the method to the implementation, This metamethod lets you create an
    handler as if it was a class

    ```lua
    -- inside a ModuleScript
    local SomeHandler = ComponentHandler.new()

    function SomeHandler.someMethod(self : genericComponent<any, any>)
        -- some operation
    end

    return SomeHandler
    ```
]=]
function ComponentHandler.__newindex(t : ComponentHandler, index : string, method : (self : any, ...any) -> any)
    t:add(index, method)
end

return ComponentHandler
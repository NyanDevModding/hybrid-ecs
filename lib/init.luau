local WorldFactory  = require(script.world.WorldFactory)
local Loop = require(script.Loop)
local Component = require(script.component.Component)
local ComponentMultiplicator = require(script.component.ComponentMultiplicator)
local ComponentHandler = require(script.component.ComponentHandler)
local EntityLink = require(script.EntityLink)

local WorldInterfaceModule = require(script.world.WorldInterface)

local newComponent = function(name : string, defaultData : {any}, handler : {[string] : (...any) -> any})
    return Component.new(name, defaultData, handler)
end

local newComponentMultiplicator = function(name : string, defaultData : {any}, handler : {[string] : (...any) -> any})
    return ComponentMultiplicator.new(name, defaultData, handler)
end

local newHandler = function(methods : {(self : Component.Component, ...any) -> any}?)
    return ComponentHandler.new(methods)
end

export type World = WorldInterfaceModule.WorldInterface
export type Loop = Loop.Loop
export type Component = Component.Component
export type ComponentMultiplicator = ComponentMultiplicator.ComponentMultiplicator

--[=[
    @class Hybrid

    Hybrid-ecs library, mainly based on matter-ecs, it is an a more object
    oriented ecs (basically, components have now methods.)

    Call Hybrid.WorldFactory.createWorld() to create a new world

    I KNOW THAT THIS IS NOT THE PRINCIPE OF AN ECS
    I know that it leads to a not full implementation by systems but yeah
    use matter, this library is bad
    nah its not that bad but idk
    yeah its bad
    ITS MY FIRST LIBRARY
    IVE MADE IT WITH MY HEART
    LOST MY SOUL ON THOSE .SPEC.LUAU
    I need to take a shower
]=]
local Hybrid = {}

--[=[
    @within Hybrid
    @prop WorldFactory WorldFactory
]=]
Hybrid.WorldFactory = WorldFactory

--[=[
    @within Hybrid
    @prop Loop Loop
]=]
Hybrid.Loop = Loop

--[=[
    @within Hybrid
    @function component
    @param name string -- the name of the component
    @param defaultData {[any] : any} -- the default data of the component
    @param handler {[string] : (...any) -> any} -- the secondary index of the
    component instance
    @return Component -- the new component

    Create a new component with a name, its defaultData and a facultative
    handler. the handler is the secondary index of the component, it means that
    the instances of this component will have access to its methods.

    ```lua
    -- creation of the component
    local HEALTH = Hybrid.component("health", {value = 100})
    -- you can add an handler for a more oop approach, just add the handler as
    -- the third argument

    -- instanciation of a component
    local componentInstance = HEALTH({value = 110}) -- or HEALTH:create({value = 110})
    ```
]=]
Hybrid.component = newComponent

--[=[
    @within Hybrid
    @function multicomponent
    @param name string -- the name of the componentMultiplicator
    @param defaultData {[any] : any} -- the default data of the componentMultiplicator
    @param handler {[string] : (...any) -> any} -- the secondary index of the
    component instance
    @return ComponentMultiplicator -- the new componentMultiplicator

    Create a new componentMultiplicator with a name, its defaultData and a
    facultative handler. the handler is the secondary index of the component,
    it means that the instances of this component will have access to its
    methods.

    The component multiplicator lets you create different component of the same
    type, just like slots, you would have slot_1 and slot_2 in a single entity
    instead of an entire inventory component that cant be composed with
    others components.

    To get a specific component, just stores its numero like : ```lua
    inputData.inputNumber = 5``` if there is an inputSlot which numero is 5.

    ```lua
    -- creation of the componentMultiplicator
    local HEALTH = Hybrid.multicomponent("health", {value = 100})
    -- you can add an handler for a more oop approach, just add the handler as
    -- the third argument

    -- instanciation of a component
    local componentInstance = HEALTH(1)({value = 110}) -- or HEALTH(1):create({value = 110})
    ```
]=]
Hybrid.multicomponent = newComponentMultiplicator

--[=[
    @within Hybrid
    @function Handler
    @param methods methods : {(self : Component.Component, ...any) -> any}? --
    the methods of the handler, it can be nil
    @return ComponentHandler

    Create a new componentHandler, used in an entity to give it methods oop
    properties.

    A good manner to declare an handler, is by defining it as if it was a
    class :

    ```lua
    -- in a ModulScript named "Somehandler"
    local SomeHandler = Hybrid.Handler()

    function SomeHandler.someOperation(self : componentInstance)
        -- some operation
    end

    return SomeHandler
    ```
]=]
Hybrid.Handler = newHandler

--[=[
    @within Hybrid
    @class EntityLink

    The entityLinks provide a securised and encapsulated way to store a
    reference from an entity to another. They contain several method to
    manipulate the reference and 2 hooks to catch when something happens.

    An entityLink should be stored as a field of a component :
    componentInstance
    ├ link1 : EntityLink
    └ link2 : EntityLink

    ```lua
    -- 2 times setup
    local entity = world:spawn({
        someComponent({
            -- component fields
        })
    })
    entity:insert(someComponent:patch({
        link = Entitylink.new(entity.id)
    }))
    ```
]=]
Hybrid.EntityLink = EntityLink

return table.freeze(Hybrid)
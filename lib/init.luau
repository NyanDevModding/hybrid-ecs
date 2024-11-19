local WorldFactory  = require(script.world.WorldFactory)
local EntityMirror  = require(script.world.EntityMirror)
local Loop = require(script.Loop)
local Component = require(script.component.Component)
local CompositeComponent = require(script.component.CompositeComponent)
local RegisteredComponent = require(script.component.RegisteredComponent)
local RegisteredMultiComponent = require(script.component.RegisteredMultiComponent)
local EntityLink = require(script.EntityLink)

local WorldInterfaceModule = require(script.world.WorldInterface)

local registerComponent = function(name : string, builder : (...any) -> {})
    return RegisteredComponent.new(name, builder)
end

local registerCompositeComponent = function(
    name : string, builder : (...any) -> {},
    compositeBuilder: ((builder : () -> any, ...any) 
    -> CompositeComponent.CompositeComponent)?
)
    return RegisteredMultiComponent.new(name, builder, compositeBuilder)
end

export type World = WorldInterfaceModule.WorldInterface
export type EntityMirror = EntityMirror.EntityMirror
export type Loop = Loop.Loop
export type Component = Component.Component

--[=[
    @class Hybrid

    Hybrid-ecs library, mainly based on matter-ecs, it is an a more object
    oriented ecs (basically, components have now methods.)

    Call Hybrid.WorldFactory.createWorld() to create a new world

    I KNOW THAT THIS IS NOT THE PRINCIPE OF AN ECS
    I know that it leads to a not full implementation by systems but yeah
    use matter, this library is bad
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
    @param builder (...any) -> Component -- the builder method of the component
    @return RegisteredComponent

    Create a new componentBuilder with a name and a builder method.

    ```lua
    -- the component's class
    local Health = require("Health")

    -- creation of the component factory
    local HEALTH = Hybrid.component(
        "health",
        function(value)
            Health.new(value or 100)
        end
    )

    -- instanciation of a component
    local componentInstance = HEALTH(110) -- or HEALTH:create(110)
    ```

    Storing components should be done by requiring the Components class
    inside of a function.

    ```lua
    -- Components.luau
    local ComponentsRegistry = {}

    function ComponentsRegistry.buildRegistry()
        local Health = require("Health")

        ComponentsRegistry.HEALTH = Hybrid.component(
            "health",
            function(value)
                return Health.new(value)
            end
        )
    end

    return ComponentsRegistry
    ```

    As it allows both module to store reference to each other.
    The Component child class just mustn't build the registry, it will be
    performed by another module like build.luau or idk
]=]
Hybrid.component = registerComponent

--[=[
    @within Hybrid
    @function component
    @param name string -- the name of the component
    @param builder (...any) -> Component -- the builder method of the component
    @param compositeBuilder compositeBuilder: ((builder : () -> any, ...any)
    -> CompositeComponent.CompositeComponent)? -- the builder of the composite
    component
    @return RegisteredMultiComponent

    You can register a multiComponent, a component that itself stores
    some components of a same type.

    ```lua
    -- Components.luau
    local ComponentsRegistry = {}

    function ComponentsRegistry.buildRegistry()
        local Slot = require("Slot")

        ComponentsRegistry.SLOT = Hybrid.multiComponent(
            "health",
            function(value)
                return Slot.new(value)
            end
        )
    end

    return ComponentsRegistry
    ```
    By default, the compositeBuilder returns a CompositeComponent. You can
    extend this class to return your own CompositeComponent
]=]
Hybrid.multiComponent = registerCompositeComponent

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

--[=[
    @within Hybrid
    @prop Component

    Abstract class component, to inherit to create a child component class
    like so :
    ```lua
    local Hybrid = require("Hybrid")
    local Component = Hybrid.Component

    local SubComponent = Hybrid.Component:extend()
    -- override parent's methods etc.

    -- this method is located in the class, this means that it is also
    -- inherited :
    local SubComponent = require("SubComponent")

    local DeepSubComponent = SubComponent:extend()
    -- override parent's methods
    ```
]=]
Hybrid.Component = Component

--[=[
    @within Hybrid
    @prop CompositeComponent

    The multiComponent class, can be extended to create some child
    multiComponent.
]=]
Hybrid.CompositeComponent = CompositeComponent

return table.freeze(Hybrid)
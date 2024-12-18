# Hybrid Ecs
4.0.3
the API is subject to change
Reverting the uselessly enormous hypothesis system as it leads to bug and isn't useful 😔

Hybrid ecs is an oop "ecs" partially based on the [Matter](https://github.com/matter-ecs/matter) interface.
IT ISN'T AN ECS MY BAD
ecs tend to separate data from actual code (this ecs does the exact opposite)

⚠ **ATTENTION!!** This library only got tested with bad testez scripts and is subject to change a lot. I've been making it initially for my game but it has not yet been so much tested. In addition, it is absolutely not well optimized ⚠

## Installation
If I remember to do it, I should post this program on wally as nyandev/hybrid-ecs

## What is Hybrid-ecs

### Chunk-based
Hybrid ecs, unlike matter, works on a chunk-based storage, prefering the entity getting to the component getting, this means that the world:get() method returns an entity. Actually, it does not returns exactly an entity but its mirror. An *EntityMirror* stores the entity as one of its private field and provides methods to change its components, keeping track of changes and protecting the entity.

### OOP ?
Another thing that differentiate Hybrid from Matter is that, in matter, a change in a component implies changing the entire component. In Hybrid, component are actually changeable as wanted, in addition, they are actual objects that inherit from the *Component* class and override its method.

```lua
-- In SubComponent.luau
local Hybrid = require("Hybrid")
local Component = Hybrid.Component

local SubComponent = Component:extend()

function SubComponent.new(value)
    local instance = Component.new()
    setmetatable(instance, SubComponent)
    instance.value = value
    return instance
end

function SubCompoponent.getValue(self : SubComponent)
    -- some operation
end

function SubCompoponent.clone(self : SubComponent)
    -- override some parent operation
end

return SubComponent
```

And you will need to register components in a Components.luau enum like so :
```lua
-- In Components.luau
local ComponentsRegistry = {}

-- This method wrap up the requires of this script so it can be required by
-- the Component classes and later be built by an external script.
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
You can see that components are registered with a ``name`` and a ``builder`` method, a function that returns a new instance of a specific Component. This name should always be bound to that component interface. You can thus consider exporting some ``types`` outside of the enum.

### Serialized changes in query
Query is performed in a serialized manner. Every query is executed one after the other.

### Component Referencing only
The purpose of this Library is to never store any reference to the world in any component (as in this case changes are difficult to track).
As I can't imagine all the parameters that we would have to pass to any method of a component (like ``component:doSomething(world, entityId, componentName, actualParameters)``). And using memory to store a world reference, an entityId and a componentName in each component is just not possible.
Components must reference others by storing a ComponentReference :

```lua
-- In SomeComponent
-- SomeComponent extending Component

function SomeComponent.new(otherComponent)
    return setmetatable({
        otherComponent = otherComponent:getReference()
    }, SomeComponent)
end

function SomeComponent.someOperation(self)
    local other = self.otherComponent:get()

    -- check if the component is still here
    if other == nil then
        return
    end

    -- else
    -- do some operation
end
```
The Referencing system is already implemented in the Component class and is component replacing proof. This means that inserting a component at a name where there is already one in the entity with thus different references pointing to each one will end with only one reference pointing to the fusion resulting component.
You will have to check ComponentReference validity, if it is still in the world by calling ``:isNull()`` on it.

Nevertheless, some component have to modify others components in an entity. They need to have access to this entity. Fortunately, the *Supervisor* exists. It is a special component that you insert in an entity by calling a ``world:supervise(entityId)`` and that stores a reference to its entity's id and that can return the mirror of its entity. You just have to store a reference to this component and call on it ``:get()`` to get the component and again ``:get()``to get the EntityMirror.

## Getting Started
To get started, you should create, as in matter, a World, some systems and a loop (⚠ the loop object is subject to changes as it may be replaced by methods idk). As oop code in ecs is the main purpose of this library, you shouldn't have a lot of systems but a lot of handlers.

```lua
local Hybrid = require("hybrid")

local world = Hybrid.World.new()
```

You can then start creating your Components.luau enum, your component class tree and your systems.

## Coming progress
- I'll manage someday to write a json converter for the world to turn into a json obviously
- I also will optimize some goofy classes like DefaultQueryCache (see how I applied composition on it to let you code your own queryCache)
- Adding a documentation with moonwave or full-moon i forgot (I've already made all the special doc comments things)
- Recode the loop system as the actual one isn't so powerful
- Benchmark this program so I can optimize it (I don't have the money for the benchmarker)
- Add a crawler that checks for memory leaks in the world storage (like enormous ComponentReference update stack)
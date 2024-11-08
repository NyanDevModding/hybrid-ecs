# Hybrid Ecs
0.1.0.0

Hybrid ecs is a simple oop ecs partially based on the [Matter](https://github.com/matter-ecs/matter) interface.

⚠ **ATTENTION!!** This library only got tested with bad testez scripts and is subject to change a lot. I've been making it initially for my game but it has not yet been so much tested. In addition, it is absolutely not well optimized ⚠

## Installation
If I remember to do it, I should post this program on wally as nyandev/hybrid-ecs

## What is Hybrid-ecs

### Chunk-based
Hybrid ecs, unlike matter, works on a chunk-based storage, prefering the entity getting to the component getting, this means that the world:get() method returns an entity. Actually, it does not returns exactly an entity but its mirror. An EntityMirror stores the entity as one of its private field and provides methods to change its components, keeping track of changes and protecting the entity.

### OOP ?
Another thing that differentiate Hybrid from Matter is that, in matter, a change in a component implies changing the entire component. In Hybrid, component are actually changeable as wanted, this means that there is no queryChanged matter thing. But, Hybrid as mentionned earlier is an 'oop' ecs, this means that component are equipped with an interface and methods. This is implemented by handlers that you create almost like classes and pass as an argument to the Component.new() method. It is thus highly recommended to describe implicit fields and interface as a lua or emmylua type like so :

```lua
-----
-- In ComponentStandardTypes.luau
export type someComponentFields = {
    _someField : number
}

-----
-- In SomeComponentHandler.luau
local StandardTypesModule = require("someComponentFields")
type standardType = StandardTypesModule.someComponentFields

export type SomeComponentHandler = typeof(SomeComponentHandler)
export type SomeComponent = standardType & SomeComponentHandler & Handler.defaultHandler -- default handler define the default component methods : patch and clone
-- define the actual handler

-----
-- In Components.luau
export type SomeComponent = SomeComponentHandler.SomeComponent
Components.local SOME_COMPONENT = Component.new(
    "some",
    {}, -- defaultData
    SomeComponentHandler
)
```
or you can also define the standard type directly inside of the handler.

### Deferred change Query
As in Matter, Hybrid has a deferred change library. This means that calling a :query() method alter the behaviour of the world and does not modify the world but instead store the changes in something called an hypothesis that will then be merged into a merger that will be commited to the world at the end of the query. This system implies that every iteration of a query is executed on the same world state, the changes made in an iteration won't be in the next one, but will be merged in at the end of the for loop.  
In addition, the query are nestable, this signifies that a first query will open an hypothesis as mentionned earlier but a second query will create an hypothesis on top of the first one, ISNT THAT MERVELLOUS ?? (lost my mind coding this).  
And to finish with the hypothesis system, of course, the changes are dinamically stored, as the hypothesis alters the behaviour of world, it also alters its getting method that now return things from the Hypothesis. With all of this, you almost don't have to care about anything (don't mind :breakQuery()), you just have to know that each iteration start on the same world state. (so basically breakQuery prevents a `break` call, out of a query, to screw everything up because the hypothesis close is normally performed at the last iteration of a query, so when break is called, the hypothesis stays and breaks everything, you must call breakQuery before break)

## Getting Started
To get started, you should create, as in matter, a World, some systems and a loop (⚠ the loop object is subject to changes as it may be replaced by methods idk). As oop code in ecs is the main purpose of this library, you shouldn't have a lot of systems but a lot of handlers.

```lua
local Hybrid = require("hybrid")

local world = Hybrid.WorldFactory.createWorld()
```

Hybrid uses a WorldFactory because instanciating a new world requires wrapping it into a proxy (the proxy is basically the actual class that alters the actions of World by checking if it is actually building an hypothesis).

## Coming progress
- I'll manage someday to write a json converter for the world to turn into a json obviously
- I also will optimize some goofy classes like DefaultQueryCache (see how I applied composition on it to let you code your own queryCache)
- Adding a documentation with moonwave or full-moon i forgot (I've already made all the special doc comments things)
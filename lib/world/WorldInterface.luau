-- type used outside of the library, the surface type of world.

local Component = require(script.Parent.Parent.component.Component)
local RegisteredComponent = require(script.Parent.Parent.component.RegisteredComponent)
local EntityMirror = require(script.Parent.EntityMirror)

local WorldTypes = require(script.Parent.WorldTypes)
local QueryCacheInterfaceModule = require(script.Parent.query_cache.QueryCacheInterface)
local IdProviderInterfaceModule = require(script.Parent.id_provider.IdProviderInterface)

type Component = Component.Component
type Supervisor = typeof(require(script.Parent.Parent.component.Supervisor).new())
type RegisteredComponent = RegisteredComponent.RegisteredComponent

type entity = WorldTypes.entity
export type EntityMirror = EntityMirror.EntityMirror

type QueryCacheInterface = QueryCacheInterfaceModule.QueryCacheInterface
type IdProviderInterface = IdProviderInterfaceModule.IdProviderInterface
type WorldHypothesis = typeof(require(script.Parent.hypothesis.WorldHypothesis).new())

-- implemented by WorldProxy

export type WorldInterface = {
    chunkSize : number,

    new : (chunkSize : number?, queryCache : QueryCacheInterface?, idProvider : IdProviderInterface?) -> WorldInterface,
    openHypothesis : (self : WorldInterface, newHypothesis : any) -> nil,
    closeHypothesis : (self : WorldInterface) -> nil,
    isBuildingHypothesis : (self : WorldInterface) -> boolean,
    getListenerHypothesis : (self : WorldInterface) -> WorldHypothesis,
    resetListenerHypothesis : (self : WorldInterface) -> nil,
    setQueryCache : (self : WorldInterface, queryCache : QueryCacheInterface) -> WorldInterface,
    getStorageSize : (self : WorldInterface) -> number,
    spawnAt : (self : WorldInterface, entityId : number, componentDict : {[string] : Component}) -> nil,
    spawn : (self : WorldInterface, componentDict : {[string] : Component}) -> number,
    despawn : (self : WorldInterface, entityId : number) -> nil,
    get : (self : WorldInterface, entityId : number) -> EntityMirror?,
    contains : (self : WorldInterface, entityId : number) -> boolean,
    insert : (self : WorldInterface, entityId : number, componentName : string, component : Component) -> nil,
    supervise : (self : WorldInterface, entityId : number) -> Supervisor,
    remove : (self : WorldInterface, entityId : number, componentName : string) -> nil,
    getComponent : (self : WorldInterface, entityId : number, componentName : string) -> Component?,
    getQueryIterator : (self : WorldInterface, archetype : {string}?) -> {number},
    query : (self : WorldInterface, ...RegisteredComponent) -> (() -> number),
    readQuery : (self : WorldInterface, ...RegisteredComponent) -> (() -> number),
    breakQuery : (self : WorldInterface) -> nil,
    getRawWorld : (self : WorldInterface) -> WorldInterface
}

return {}
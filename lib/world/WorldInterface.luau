-- type used outside of the library, the surface type of world.

local Component = require(script.Parent.Parent.component.Component)
local EntityMirror = require(script.Parent.EntityMirror)
local WorldHypothesis = require(script.Parent.hypothesis.WorldHypothesis)

local WorldTypes = require(script.Parent.WorldTypes)
local QueryCacheInterfaceModule = require(script.Parent.query_cache.QueryCacheInterface)
local IdProviderInterfaceModule = require(script.Parent.id_provider.IdProviderInterface)

type component = Component.Component
type defaultComponentInstance = WorldTypes.defaultComponentInstance

type entity = WorldTypes.entity
export type EntityMirror = EntityMirror.EntityMirror

type QueryCacheInterface = QueryCacheInterfaceModule.QueryCacheInterface
type IdProviderInterface = IdProviderInterfaceModule.IdProviderInterface
type WorldHypothesis = WorldHypothesis.WorldHypothesis

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
    spawnAt : (self : WorldInterface, entityId : number, componentList : {component}) -> nil,
    spawn : (self : WorldInterface, components : {component}) -> number,
    despawn : (self : WorldInterface, entityId : number) -> nil,
    get : (self : WorldInterface, entityId : number) -> EntityMirror,
    contains : (self : WorldInterface, entityId : number) -> boolean,
    insert : (self : WorldInterface, entityId : number, component : component) -> nil,
    remove : (self : WorldInterface, entityId : number, componentType : component) -> nil,
    getComponent : (self : WorldInterface, entityId : number, componentType : component) -> defaultComponentInstance,
    startCaching : (self : WorldInterface) -> nil,
    stopCaching : (self : WorldInterface) -> nil,
    addLoop : (self : WorldInterface, loop : any) -> nil,
    query : (self : WorldInterface, ...component) -> (() -> number),
    readQuery : (self : WorldInterface, ...component) -> (() -> number),
    breakQuery : (self : WorldInterface) -> nil,
    getRawWorld : (self : WorldInterface) -> WorldInterface
}

return {}
local Component = require(script.Parent.Parent.Parent.component.Component)

type component = Component.Component
type defaultComponentInstance = Component.genericComponent<any, {(...any) -> any}>
type entity = {[string] : defaultComponentInstance}

export type QueryCacheInterface = {
    isCached : (self : QueryCacheInterface, components : {[number] : component}) -> boolean,
    -- returns a list of all the cached entity ids
    getCached : (self : QueryCacheInterface, components : {[number] : component}) -> {number}?,
    lifecycleCache : (self : QueryCacheInterface) -> any,
    cacheArchetype : (self : QueryCacheInterface, components : {[number] : component}, concernedEntityIds : {number}) -> any,
    uncacheArchetype : (self : QueryCacheInterface, components : {[number] : component}) -> any,
    notifyCacheSpawnedEntity : (self : QueryCacheInterface, entityId : number, entity : entity) -> any,
    notifyCacheDespawnedEntity : (self : QueryCacheInterface, entityId : number, entity : entity) -> any,
    notifyCacheEntityComponentInserted : (self : QueryCacheInterface, entityId : number, components : {component}, component : component) -> any,
    notifyCacheEntityComponentRemoved : (self : QueryCacheInterface, entityId : number, components : {component}, component : component) -> any,
    clearCache : (self : QueryCacheInterface) -> any
}

return {}
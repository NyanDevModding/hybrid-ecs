local Component = require(script.Parent.Parent.Parent.component.Component)

type Component = Component.Component
type defaultComponentInstance = Component.Component
type entity = {[string] : defaultComponentInstance}

export type QueryCacheInterface = {
    isCached : (self : QueryCacheInterface, components : {string}) -> boolean,
    -- returns a list of all the cached entity ids
    getCached : (self : QueryCacheInterface, components : {string}) -> {number}?,
    lifecycleCache : (self : QueryCacheInterface) -> any,
    cacheArchetype : (self : QueryCacheInterface, components : {string}, concernedEntityIds : {number}) -> any,
    uncacheArchetype : (self : QueryCacheInterface, components : {string}) -> any,
    notifyCacheSpawnedEntity : (self : QueryCacheInterface, entityId : number, entity : entity) -> any,
    notifyCacheDespawnedEntity : (self : QueryCacheInterface, entityId : number, entity : entity) -> any,
    notifyCacheEntityComponentInserted : (self : QueryCacheInterface, entityId : number, components : {string}, component : Component) -> any,
    notifyCacheEntityComponentRemoved : (self : QueryCacheInterface, entityId : number, components : {string}, component : Component) -> any,
    clearCache : (self : QueryCacheInterface) -> any
}

return {}
local Component = require(script.Parent.Parent.component.Component)
local WorldTypes = require(script.Parent.WorldTypes)

local IdProviderInterfaceModule = require(script.Parent.id_provider.IdProviderInterface)

type EntityMirror = typeof(require(script.Parent.EntityMirror))
-- type EntityMirror = EntityMirror.EntityMirror
type component = Component.Component

type defaultComponentInstance = WorldTypes.defaultComponentInstance
type entity = WorldTypes.entity

type IdProviderInterface = IdProviderInterfaceModule.IdProviderInterface

-- the interface of a world implemented by the World and the WorldHypothesis
-- as they can both be used in an entitymirror
export type HypothesisWorldInterface = {
    getNextId : (self : HypothesisWorldInterface) -> number,
    openHypothesis : (self : HypothesisWorldInterface, hypothesis : HypothesisWorldInterface) -> nil,
    closeHypothesis : (self : HypothesisWorldInterface) -> nil,
    resetListenerHypothesis : (self : HypothesisWorldInterface) -> nil,
    copyIdProvider : (self : HypothesisWorldInterface) -> IdProviderInterface,
    spawnAt : (self : HypothesisWorldInterface, entityId : number, componentList : {defaultComponentInstance}) -> nil,
    spawn : (self : HypothesisWorldInterface, components : {defaultComponentInstance}) -> number,
    despawn : (self : HypothesisWorldInterface, entityId : number) -> nil,
    get : (self : HypothesisWorldInterface, entityId : number) -> EntityMirror,
    contains : (self : HypothesisWorldInterface, entityId : number) -> boolean,
    insert : (self : HypothesisWorldInterface, entityId : number, component : defaultComponentInstance) -> nil,
    remove : (self : HypothesisWorldInterface, entityId : number, componentType : component) -> nil,
    getComponent : (self : HypothesisWorldInterface, entityId : number, componentType : component) -> defaultComponentInstance,
    getQueryIterator : (self : HypothesisWorldInterface, archetype : {component}?) -> {number},
    query : (self : HypothesisWorldInterface, ...component) -> (() -> number),
    readQuery : (self : HypothesisWorldInterface, ...component) -> (() -> number),
    breakQuery : (self : HypothesisWorldInterface) -> nil,
}

return {}
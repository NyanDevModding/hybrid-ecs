local Component = require(script.Parent.Parent.component.Component)
local RegisteredComponent = require(script.Parent.Parent.component.RegisteredComponent)
local WorldTypes = require(script.Parent.WorldTypes)

local IdProviderInterfaceModule = require(script.Parent.id_provider.IdProviderInterface)

type EntityMirror = typeof(require(script.Parent.EntityMirror).new())
-- type EntityMirror = EntityMirror.EntityMirror
type Component = Component.Component
type Supervisor = typeof(require(script.Parent.Parent.component.Supervisor).new())
type RegisteredComponent = RegisteredComponent.RegisteredComponent

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
    spawnAt : (self : HypothesisWorldInterface, entityId : number, componentDict : {[string] : Component}) -> nil,
    spawn : (self : HypothesisWorldInterface, componentDict : {[string] : Component}) -> number,
    despawn : (self : HypothesisWorldInterface, entityId : number) -> nil,
    get : (self : HypothesisWorldInterface, entityId : number) -> EntityMirror?,
    contains : (self : HypothesisWorldInterface, entityId : number) -> boolean,
    insert : (self : HypothesisWorldInterface, entityId : number, componentName : string, component : Component) -> nil,
    supervise : (self : HypothesisWorldInterface, entityId : number) -> Supervisor,
    remove : (self : HypothesisWorldInterface, entityId : number, componentName : string) -> nil,
    getComponent : (self : HypothesisWorldInterface, entityId : number, componentType : RegisteredComponent) -> defaultComponentInstance,
    getQueryIterator : (self : HypothesisWorldInterface, archetype : {string}?) -> {number},
    query : (self : HypothesisWorldInterface, ...RegisteredComponent) -> (() -> number),
    readQuery : (self : HypothesisWorldInterface, ...RegisteredComponent) -> (() -> number),
    breakQuery : (self : HypothesisWorldInterface) -> nil,
}

return {}
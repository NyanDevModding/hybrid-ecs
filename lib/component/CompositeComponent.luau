local Component = require(script.Parent.Component)

local CompositeComponent = table.clone(Component)
CompositeComponent.__index = CompositeComponent

export type CompositeComponent = typeof(CompositeComponent.new())

function CompositeComponent.new<component>(concreteComponentBuilder : (...any) -> component, components : {[number] : component}?)
    local instance = setmetatable({
        _concreteComponentBuilder = concreteComponentBuilder,
        _multiplied = {} :: {component},
        _lastNumero = 0
    }, CompositeComponent)

    if components == nil then
        return instance
    end

    for numero, component in pairs(components) do
        instance:insertAt(numero, component)
    end
    return instance
end

function CompositeComponent._getEmptyNumero(self : CompositeComponent)
    local emptyNumero = 1
    for _, _ in ipairs(self._multiplied) do
        emptyNumero += 1
    end
    return emptyNumero
end

--[=[
    @within CompositeComponent
    @function createAt
    @param numero number -- the numero of the multiplied component
    @param ...any -- the arguments passed to the builder constructor

    Create a component in the composite at the provided numero.
]=]
function CompositeComponent.createAt(self : CompositeComponent, numero : number, ... : any)
    self._multiplied[numero] = self._concreteComponentBuilder(...)

    if numero > self._lastNumero then
        self._lastNumero = numero
    end
end

--[=[
    @within CompositeComponent
    @function create
    @param ...any -- the arguments passed to the builder constructor
    @return number -- the numero where the component is located

    Create a component in the composite and return the numero.
]=]
function CompositeComponent.create(self : CompositeComponent, ... : any)
    local emptyNumero = self:_getEmptyNumero()

    self:createAt(emptyNumero, ...)
    return emptyNumero
end

--[=[
    @within CompositeComponent
    @function insertAt
    @param numero number -- the numero of the multiplied component
    @param component Component -- the component to insert in the composite
    (It **must** be a component that matches the type provided to the
    RegisteredMultiComponent)

    Insert the given component in the composite at the provided numero.
]=]
function CompositeComponent.insertAt(self : CompositeComponent, numero : number, component : Component.Component)
    self._multiplied[numero] = component

    if numero > self._lastNumero then
        self._lastNumero = numero
    end
end

--[=[
    @within insert
    @function createAt
    @param component Component -- the component to insert in the composite
    (It **must** be a component that matches the type provided to the
    RegisteredMultiComponent)
    @return number -- the numero where the component is located

    Insert a component in the composite and return its numero.
]=]
function CompositeComponent.insert(self : CompositeComponent, component : Component.Component)
    local emptyNumero = self:_getEmptyNumero()
    self:insertAt(emptyNumero, component)
    return emptyNumero
end

--[=[
    @within CompositeComponent
    @function removeAt
    @param numero number -- the numero of the component to remove

    Remove the multiplied component at the provided numero and remove the
    compositeComponent from the entity if there is no
    MultipliedComponentRemaining.

    :::caution:::
    Each time you call this method, you should also check if the composite
    is empty and so, if it should be removed.
]=]
function CompositeComponent.removeAt(self : CompositeComponent, numero : number, componentName : string, entityId : number, world)
    local component = self._multiplied[numero]
    self._multiplied[numero] = nil
    component:onRemoved(componentName, entityId, world)

    if numero < self._lastNumero then
        return
    end

    -- calculate the last numero of the composite component
    local lastNumero
    for i = numero, 1, -1 do
        if self._multiplied[i] then
            lastNumero = i
            break
        end
    end

    -- if it was the last then consider checking it outside of the method call
    if lastNumero == nil then
        return
    end

    -- if it wasn't nil then replace the old lastNumero by the new one
    self._lastNumero = lastNumero
end

--[=[
    @within CompositeComponent
    @function get
    @param numero number -- the numero of the multiplied component to get
    @return Component? -- the multiplied component

    Return the multiplied component located at the provided numero.
]=]
function CompositeComponent.get(self : CompositeComponent, numero : number)
    return self._multiplied[numero]
end

--[=[
    @within CompositeComponent
    @function getNumero
    @param component Component -- the component located at this numero
    @return numero? -- the numero of the component object

    Return the numero of a multiplied component.
]=]
function CompositeComponent.getNumero(self : CompositeComponent, component : Component.Component)
    for numero, composed in self:iterate() do
        if composed == component then
            return numero
        end
    end

    return nil
end

--[=[
    @within CompositeComponent
    @function getSize()
    @return number -- the number of component in the composite

    Return the number of multiplied components.
]=]
function CompositeComponent.getSize(self : CompositeComponent)
    local size = 0
    for _, _ in self:iterate() do
        size += 1
    end
    return size
end

--[=[
    @within CompositeComponent
    @function isEmpty
    @return boolean -- if the composite is empty or not

    Return if the composite component is empty or not (used to check if it
    should be deleted).
]=]
function CompositeComponent.isEmpty(self : CompositeComponent)
    return self:getSize() == 0
end

--[=[
    @within CompositeComponent
    @function isEmpty
    @param componentName string -- the name of the component
    @param entityId number -- the id of the entity where is located the
    composite
    @param world World -- the world where is located the entity
    @return boolean -- if it has been removed

    Check if the Composite is empty and remove it from the world if it is.
]=]
function CompositeComponent.check(self : CompositeComponent, componentName : string, entityId : number, world)
    if not self:isEmpty() then
        return true
    end
    world:remove(entityId, componentName)
    return false
end

--[=[
    @within CompositeComponent
    @function iterate
    @return (...) -> any, any -- an iterator function

    Return an iterator function to iterate over all the multiplied components.
]=]
function CompositeComponent.iterate(self : CompositeComponent)
    return pairs(self._multiplied)
end

--[=[
    @within CompositeComponent
    @function clear

    Clear all the components of the composite.
]=]
function CompositeComponent.clear(self : CompositeComponent, componentName : string, entityId : number, world)
    for numero in pairs(self._multiplied) do
        self:removeAt(numero, componentName, entityId, world)
    end
end

function CompositeComponent.formatClone(self : CompositeComponent, clone : CompositeComponent)
    Component.formatClone(self, clone)

    for numero, component in self:iterate() do
        clone:insertAt(numero, component:clone())
    end

    return clone
end

function CompositeComponent.clone(self : CompositeComponent)
    local clone = getmetatable(self).new(self._concreteComponentBuilder)
    self:formatClone(clone)
    return clone
end

function CompositeComponent.onRemoved(self : CompositeComponent)
    Component.onRemoved(self)
    self:destroy()
end

function CompositeComponent.destroy(self : CompositeComponent)
    Component.destroy(self)
    table.clear(self._multiplied)
    self._multiplied = nil
    self._concreteComponentBuilder = nil
end

return CompositeComponent
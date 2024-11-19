local Component = require(script.Parent.Component)

local CompositeComponent = table.clone(Component)
CompositeComponent.__index = CompositeComponent

export type CompositeComponent = typeof(CompositeComponent.new())

CompositeComponent.BLANK = {"blank"}

function CompositeComponent.new<component>(concreteComponentBuilder : (...any) -> component, components : {[number] : component}?)
    local instance = setmetatable({
        _concreteComponentBuilder = concreteComponentBuilder,
        _multplied = {} :: {component},
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
    for _, _ in ipairs(self._multplied) do
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
    self._multplied[numero] = self._concreteComponentBuilder(...)

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
    self._multplied[numero] = component

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
    is empty and, so, id it should be removed.
]=]
function CompositeComponent.removeAt(self : CompositeComponent, numero : number)
    self._multplied[numero] = nil

    if numero < self._lastNumero then
        return
    end

    -- calculate the last numero of the composite component
    local lastNumero
    for i = numero, 1, -1 do
        if self._multplied[i] then
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
    return (
        if self._multplied[numero] == CompositeComponent.BLANK
        then nil
        else self._multplied[numero]
    )
end

--[=[
    @within CompositeComponent
    @function getSize()
    @return number -- the number of component in the composite

    Return the number of multiplied components.

    This method does not count BLANK.
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
    @param world WorldInterface -- the world where is located the entity

    Check if the Composite is empty and remove it from the world if it is.
]=]
function CompositeComponent.check(self : CompositeComponent, componentName : string, entityId : number, world)
    if self:isEmpty() then
        world:remove(entityId, componentName)
    end
    self:forceClear()
    self._multplied = nil
    self._concreteComponentBuilder = nil
end

--[=[
    @within CompositeComponent
    @function _nextValidNumero
    @param componentName nextNumero -- the last numero, from which the
    method searches
    @return number -- the numero of the next id where there is 

    Check if the Composite is empty and remove it from the world if it is.
]=]
function CompositeComponent._nextValidNumero(self : CompositeComponent, nextNumero : number)
    if self._multplied[nextNumero] ~= nil and self._multplied[nextNumero] ~= CompositeComponent.BLANK then
        return nextNumero
    end

    return self:_nextValidNumero(nextNumero + 1)
end

--[=[
    @within CompositeComponent
    @function iterate
    @return (...) -> any, any -- an iterator function

    Return an iterator function to iterate over all the multiplied components.

    Does not iterate if the component is BLANK.
]=]
function CompositeComponent.iterate(self : CompositeComponent)
    local numero = 0

    return function ()
        while true do
            numero += 1
            if numero <= self._lastNumero then
                if self._multplied[numero] ~= nil
                and self._multplied[numero] ~= CompositeComponent.BLANK
                then
                    return numero, self._multplied[numero]
                end
            else
                return
            end
        end
    end
end

--[=[
    @within CompositeComponent
    @function forceIterate
    @return (...) -> any, any -- an iterator function

    Iterate over any element of the composite, including blank. This method is
    used while propagating numero usage data to an hypothesis.
]=]
function CompositeComponent.forceIterate(self : CompositeComponent)
    return pairs(self._multplied)
end

--[=[
    @within CompositeComponent
    @function iterate
    @param numero number -- the numero to make blank

    Set a component numero to blank so the create or insert methods can't
    create a component here, preventing any bug to appear while fusing 2
    CompositeComponent.
]=]
function CompositeComponent.makeBlank(self : CompositeComponent, numero : number)
    self._multplied[numero] = CompositeComponent.BLANK
end

--[=[
    @within CompositeComponent
    @function iterate
    @param numero number -- the numero to make blank

    Remove every blank position in the CompositeComponent.
]=]
function CompositeComponent.clearBlank(self : CompositeComponent)
    for numero, component in pairs(self._multplied) do
        if component == CompositeComponent.BLANK then
            self._multplied[numero] = nil
        end
    end
end

--[=[
    @within CompositeComponent
    @function concreteClear

    Clear the Composite component and just let the blank values.
]=]
function CompositeComponent.concreteClear(self : CompositeComponent)
    for numero, component in pairs(self._multplied) do
        if component ~= CompositeComponent.BLANK then
            self:removeAt(numero)
        end
    end
end

--[=[
    @within CompositeComponent
    @function clear

    Clear all the components of the composite and all the BLANK values.

    :::caution:::
    if you are in a query, you **must** call the concreteClear method that
    won't delete the BLANK values and thus keep the merger datas that prevent
    bugs.
]=]
function CompositeComponent.forceClear(self : CompositeComponent)
    table.clear(self._multplied)
end

function CompositeComponent.makeHypothesis(self : CompositeComponent, entityId : number, componentName : string, _, hypothesisMerger)
    local hypothetic = self:clone()

    local mergedEntity = hypothesisMerger:get(entityId)

    -- if it is not yet merged then just clone it
    if mergedEntity == nil or mergedEntity[componentName] == nil then
        return hypothetic
    end

    -- replace used things in merged by blank/unknown object (not nil but
    -- recognizable by the method fuseWith)
    for componentNumero, _ in mergedEntity[componentName]:forceIterate() do
        if self._multplied[componentNumero] == nil then
            hypothetic:makeBlank(componentNumero)
        end
    end

    return hypothetic
end

function CompositeComponent.fuseWith(self : CompositeComponent, other : CompositeComponent)
    -- when u call create, it lets a gap (blank value) in the numeros if these numeros in
    -- the gaps are used in the merger
    for numero, component in other:iterate() do
        if self._multplied[numero] ~= nil and self._multplied[numero] ~= CompositeComponent.BLANK then
            self._multplied[numero]:fuseWith(component)
        else
            self._multplied[numero] = component:clone()
        end
    end
end

function CompositeComponent.clone(self : CompositeComponent)
    local newComponent = CompositeComponent.new(self._concreteComponentBuilder)
    local numero = 0
    while numero <= self._lastNumero do
        numero += 1
        local component = self._multplied[numero]

        if self._multplied[numero] ~= nil then
            if component == CompositeComponent.BLANK then
                newComponent:makeBlank(numero)
                continue
            end

            newComponent:insertAt(numero, component:clone())
        end
    end

    return newComponent
end

return CompositeComponent
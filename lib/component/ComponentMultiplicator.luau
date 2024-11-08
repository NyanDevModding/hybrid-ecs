local Component = require(script.Parent.Component)

local ComponentMultiplicator = {}
ComponentMultiplicator.__index = ComponentMultiplicator

export type ComponentMultiplicatorClass = typeof(ComponentMultiplicator)
export type ComponentMultiplicator = typeof(ComponentMultiplicator.new())

--[=[
    @within ComponentMultiplicator
    @function new
    @param name string -- the name of the component
    @param defaultData {any} -- the defaultData
    @param handler ComponentHandler -- the componenHandler of the component

    create a new ComponentMultiplicator instance

    A ComponentMultiplicator let you have several component from the same type
    in a single entity.

    It stores data about the component and replicates it at runtime whenever we
    need it.

    The created components have number to identify them.

    ```lua
    local someComponentMultiplicator = ComponentMultiplicator.new("some")

    local newComponent = someComponentMultiplicator(5)({
        -- the data pf the component
    })
    -- this returns a componentInstance of the component n°5 ("some_5")
    ```
]=]
function ComponentMultiplicator.new(name : string, defaultData : {any}, handler : any)
    return setmetatable({
        name = name,
        defaultData = defaultData,
        handler = handler,
        size = 0,
        _components = {},
    }, ComponentMultiplicator)
end

--[=[
    @within ComponentMultiplicator
    @function has
    @param number number -- the numero of the component
    @return boolean -- if the component of numero exists

    if a component does not exist, return nil and do not create one as get would do
]=]
function ComponentMultiplicator.has(self : ComponentMultiplicator, number : number)
    return (self._components[number] ~= nil)
end

--[=[
    @within ComponentMultiplicator
    @function get
    @param number number --the numero of the component
    @return Component typeof(Matter.component) -- returned component

    Return the associated duplicated component of the number
]=]
function ComponentMultiplicator.get(self : ComponentMultiplicator, number : number)
    if self._components[number] then
        return self._components[number]
    else
        self._components[number] = Component.new(self.name .. "_" .. number, self.defaultData, self.handler)
        self.size += 1
        return self._components[number]
    end
end

--[=[
    @within ComponentMultiplicator
    @function getNameOf
    @param number number --the numero of the component
    @return string -- the name of the component

    Return the name of a component for its numero.
]=]
function ComponentMultiplicator.getNameOf(self : ComponentMultiplicator, number : number)
    return self.name .. "_" .. tostring(number)
end

--[=[
    @within ComponentMultiplicator
    @function iterate
    @return typeof(pairs())

    Let you iterate of the different duplicated components with the
    pairs function because _components are private.

    ```lua
    -- num is the numero of the component
    for num, component in componentMultiplicator:iterate() do
        -- do something
    end
    ```
]=]
function ComponentMultiplicator.iterate(self : ComponentMultiplicator)
    return pairs(self._components)
end

function ComponentMultiplicator.__tostring(self : ComponentMultiplicator)
    return self.name
end

function ComponentMultiplicator.__call(self : ComponentMultiplicator, number : number)
    return self:get(number)
end

return ComponentMultiplicator
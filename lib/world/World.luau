local Component = require(script.Parent.Parent.component.Component)

local DefaultQueryCache = require(script.Parent.query_cache.DefaultQueryCache)
local SimpleIdProvider = require(script.Parent.id_provider.SimpleIdProvider)

local EntityMirror = require(script.Parent.EntityMirror)
local WorldHypothesis = require(script.Parent.hypothesis.WorldHypothesis)
local WorldHypothesisMerger = require(script.Parent.hypothesis.WorldHypothesisMerger)

local WorldInterfaceModule = require(script.Parent.WorldInterface)
local WorldTypes = require(script.Parent.WorldTypes)
local QueryCacheInterfaceModule = require(script.Parent.query_cache.QueryCacheInterface)
local IdProviderInterfaceModule = require(script.Parent.id_provider.IdProviderInterface)

--[=[
    @class World : HypothesisWorldInterface

    A world is a storage for entities that store themselves components. You can
    create entity by calling the method :spawn and a new world and insert
    component by calling :insert with the entity id or by calling :get and
    :insert on the provided entityMirror.

    An *EntityMirror* is an object that stores a reference to an entity, it
    should *never* be stored as it would prevent the entity from being garbage
    collected.

    In Hybrid ECS, components are changeable, there is no queryChanged so they
    are not supposed to be immutable. Nevertheless, entities are, you have to
    call methods to insert or remove entity as the changes are observed by the
    queryCache. Same for the component themselves, changing their data is ok
    but you have to call world method to insert or remove them.
]=]
local World = {}
World.__index = World

World.DefaultQueryCache = DefaultQueryCache

-- types --
export type WorldClass = typeof(World)
export type World = typeof(World.new())

type component = Component.Component
type defaultComponentInstance = WorldTypes.defaultComponentInstance

type entity = WorldTypes.entity
export type EntityMirror = EntityMirror.EntityMirror

type storageChunk = WorldTypes.storageChunk
type storage = WorldTypes.storage

type QueryCacheInterface = QueryCacheInterfaceModule.QueryCacheInterface
type IdProviderInterface = IdProviderInterfaceModule.IdProviderInterface

type WorldHypothesis = WorldHypothesis.WorldHypothesis

type WorldInterface = WorldInterfaceModule.WorldInterface

local function assertRightEntityId(entityId : number)
    assert(
        entityId > 0 and entityId % 1 == 0 ,
        "please, provide a number belonging to the natural numbers, excepted 0 (entityId > 0)"
    )
end

local function entityContains(entity : entity | EntityMirror, archetype : {component}?)
    if archetype == nil then
        return true
    end

    for _, component in ipairs(archetype) do
        if entity[component.name] == nil then
            return false
        end
    end
    return true
end

local DEFAULT_CHUNK_SIZE = 64

--[=[
    @within World
    @function new
    @param chunkSize number -- the size of a world chunk
    @param queryCache QueryCacheInterface? -- the queryCache to use in the World
    @param idProvider IdProviderInterface? -- the idProiver to use in the World

    Create a new World, mind that you have to pass in the default queryCache if
    you want to optimize the queries :

    ```lua
    -- the DefaultQueryCache is stored as static in World.
    local world = World.new(nil, World.DefaultQueryCache(25))
    ```

    The world field is automatically set to the world.
]=]
function World.new(chunkSize : number?, queryCache : QueryCacheInterface?, idProvider : IdProviderInterface?)
    return setmetatable({
        chunkSize = chunkSize or DEFAULT_CHUNK_SIZE,
        _storage = {},
        _idProvider = idProvider or SimpleIdProvider.new(),

        _caching = false,
        _queryCache = queryCache,

        _buildingHypothesis = false,
        _listenerHypothesis = nil :: WorldHypothesis?,
        _hypothesisStack = {},

        _loops = {}
    }, World)
end

--[=[
    @type World

    @within World
    @function openHypothesis

    Open an hypothesis on the world, it will start to listen for the changes and
    override the method to execute the changes on itself. If the world was
    already building an hypothesis (nested query), then we store it as an old
    hypothesis and we place the new one azs the listener.
]=]
function World.openHypothesis(self : World, newHypothesis : WorldHypothesis)
    -- store the old hypothesis in case we have nested queries
    if self._listenerHypothesis ~= nil then
        self._hypothesisStack[#self._hypothesisStack + 1] = self._listenerHypothesis
    end
    self._listenerHypothesis = newHypothesis

    -- start listening
    self._buildingHypothesis = true
end

--[=[
    @within World
    @function closeHypothesis

    close the actual hypothesis, if we are in a case of a nested query, it
    changes the hypothesis to the old one, else it just stop the hypothesis
    building.
]=]
function World.closeHypothesis(self : World)
    -- 2 possiblilities :
    --  - nested query -> old listener, we replace the top or actual hypothesis
    --  by the oldHypothesis
    --  - bottom query -> last listener, we just stop listening and set it to
    --  nil
    -- remove the listener hypothesis and fetch the old one
    if self._hypothesisStack[1] ~= nil then
        self._listenerHypothesis = self._hypothesisStack[#self._hypothesisStack]
    else
        self._listenerHypothesis = nil
        -- stop listening
    end
    self._buildingHypothesis = false
end

--[=[
    @within World
    @function getListenerHypothesis

    Getter for the listenerHypothesis, it should only be called by the
    wrapper, as it is no use to get a raw hypothesis.
]=]
function World.getListenerHypothesis(self : World)
    return self._listenerHypothesis
end

--[=[
    @within World
    @function resetListenerHypothesis

    Resets the listener of the world, this method is used when a query is
    finished and the programm needs to launch another query so it resets the
    listener hypothesis
]=]
function World.resetListenerHypothesis(self : World)
    self._listenerHypothesis:merge()
    self._listenerHypothesis:reset()
end

--[=[
    @within World
    @function setQueryCache
    @param queryCache QueryCacheInterface -- the queryCache to be used in the
    World

    Set the _queryCache of the world to the given queryCache and set its world
    field to itself

    ```lua
    local world = World.new():setQueryCache(World.DefaultQueryCache.new())
    ```
]=]
function World.setQueryCache(self : World, queryCache : QueryCacheInterface)
    self._queryCache = queryCache
    queryCache.world = self
    return self
end

--[=[
    @within World
    @function getStorageSize
    @return number -- the number of chunk

    Return the number of chunk in the storage of the world
]=]
function World.getStorageSize(self : World)
    local result = 0
    for _, _ in pairs(self._storage) do
        result += 1
    end
    return result
end

--[=[
    @within World
    @function _getLastId
    @return number? -- the last id or nil if the world is cleared

    Return the last ised id of the world.
]=]
function World._getLastId(self : World)
    -- find the numero of the last chunk
    local lastChunkNumero = 0
    for chunkNumero, _ in pairs(self._storage) do
        if chunkNumero > lastChunkNumero then
            lastChunkNumero = chunkNumero
        end
    end

    -- if there is no chunk then return nil
    if lastChunkNumero == 0 then
        return nil
    end

    -- find the last chunk with ids in it
    -- (or the last chunk that isn't nil)
    local lastFilledChunkNumero
    for chunkNumero = lastChunkNumero, 1, -1 do
        -- check if the chunk exists
        if self._storage[chunkNumero] == nil then
            continue
        end

        local isEmpty = true

        -- check if there is some entity
        for _, _ in pairs(self._storage[chunkNumero]) do
            isEmpty = false
            break
        end

        -- if the chunk is filled then break out
        if not isEmpty then
            lastFilledChunkNumero = chunkNumero
            break
        end
    end

    -- if the entire world is clear then return
    if lastFilledChunkNumero == nil then
        return nil
    end

    -- find the last id in the chunk
    local lastEntityId = 0
    for entityId, _ in pairs(self._storage[lastFilledChunkNumero]) do
        if entityId > lastEntityId then
            lastEntityId = entityId
        end
    end

    return lastEntityId + ((lastFilledChunkNumero - 1) * self.chunkSize)
end

local function _getChunkSize(chunk : storageChunk)
    local i = 0
    for _ in pairs(chunk) do
        i += 1
    end
    return i
end

local function _getChunkRelativeId(world : World, chunkNumero : number, entityId : number)
    -- -1 because a chunk is ceiled, this means that #1-64 entities will be in chunk 1 and not 0
    return entityId - (world.chunkSize * (chunkNumero - 1))
end

--[=[
    @within World
    @function _getChunkNumero
    @return entityId -- the id of the entity that can be sored in the chunk to
    this numero.

    Return the numero of the chunk in which the entity at the provided id could be stored.
]=]
function World._getChunkNumero(self : World, entityId : number)
    return math.ceil(entityId / self.chunkSize)
end

--[=[
    @within World
    @function _createChunkAt
    @param chunkNumero number -- the numero where the chunk should be created
    @return storageChunk -- the chunk created

    Create a new chunk and return it.
]=]
function World._createChunkAt(self : World, chunkNumero : number)
    assert(self._storage[chunkNumero] == nil, "Already a chunk at numero : " .. chunkNumero)
    self._storage[chunkNumero] = {}
    return self._storage[chunkNumero]
end

--[=[
    @within World
    @function _removeChunk
    @param chunkNumero number -- the numero of the chunk that should be removed

    Remove an empty chunk and optimize the unusedIds
]=]
function World._removeChunk(self : World, chunkNumero : number)
    local lastChunkNumero = 0
    for storageChunkNumero, _ in pairs(self._storage) do
        if storageChunkNumero > lastChunkNumero then
            lastChunkNumero = storageChunkNumero
        end
    end
    local lastChunk = lastChunkNumero == chunkNumero

    -- if this was the last chunk and if there is always unusedIds then remove
    -- the unusedIds that are located after the last id and move _nextId cursor
    -- to the lastId + 1
    if lastChunk then
        local newNextId = (
            -- this is the last id
            self:_getLastId() or 0
            -- on which we add 1 to get the _nextId
        ) + 1

        self._idProvider:setNextId(newNextId)
    end

    -- actually remove the chunk
    self._storage[chunkNumero] = nil
end

--[=[
    @within World
    @function _makeChunkAt
    @param entityId number -- the id of the entity for which the chunk is created
    @return storageChunk -- the chunk created

    Returns the right chunk for the entity if it exists, else, create a new one
    and return it
]=]
function World._makeChunkAt(self : World, entityId : number)
    local chunkNumero = self:_getChunkNumero(entityId)
    if self._storage[chunkNumero] == nil then
        self:_createChunkAt(chunkNumero)
    end
    return self._storage[chunkNumero]
end

--[=[
    @within World
    @function World.isBuildingHypothesis
    @return boolean -- if the world is building an hypothesis

    Return if the world is building an hypothesis and if it is listening to
    change made to it.
]=]
function World.isBuildingHypothesis(self : World)
    return self._buildingHypothesis
end

--[=[
    @within World
    @function copyIdProvider
    @return IdProviderInterface -- a clone of the idProvider

    Return a clone of the id provider of the world. This method is used by the
    hypothesis and merger to propagate the id-providing-state of the world.
]=]
function World.copyIdProvider(self : World)
    return self._idProvider:clone()
end

--[=[
    @within World
    @function spawnAt
    @param entityId number -- the id to spawn the entity
    @param componentList {componentInstance} -- a list of component instances to
    give to the entity

    Spawn an entity at the provided id with the given list of componentInstances

    ```lua
    world:spawnAt(5, {
        component({value = 5})
    })
    local entity = world:get(5)
    ```
]=]
function World.spawnAt(self : World, entityId : number, componentList : {defaultComponentInstance})
    assertRightEntityId(entityId)
    local chunk = self:_makeChunkAt(entityId)

    local entity = {}
    for _, componentInstance in ipairs(componentList) do
        entity[getmetatable(componentInstance).name] = componentInstance
    end
    chunk[_getChunkRelativeId(self, self:_getChunkNumero(entityId), entityId)] = entity

    self._idProvider:useId(entityId)

    if self._queryCache == nil then
        return
    end

    -- notify the cache about the spawn of the entity
    self._queryCache:notifyCacheSpawnedEntity(entityId, entity)
end

--[=[
    @within World
    @function getNextId
    @return number -- the next entity id

    Return the next entity id from the id provider without modifying it.
]=]
function World.getNextId(self : World)
    return self._idProvider:getNextId()
end

--[=[
    @within World
    @function spawn
    @param entityId number -- the id to spawn the entity
    @param componentList {componentInstance} -- a list of component instances to
    give to the entity
    @return number -- the id of the spawned entity

    Spawn an entity with the given list of componentInstances

    ```lua
    local entity = world:spawn({
        component({value = 5})
    })
    ```
]=]
function World.spawn(self : World, components : {defaultComponentInstance})
    local id = self._idProvider:useNextId()
    self:spawnAt(id, components)
    return id
end

--[=[
    @within World
    @function despawn
    @param entityId number -- the id of the entity to despawn

    Despawn the entity for the given id.
]=]
function World.despawn(self : World, entityId : number)
    local chunkNumero = self:_getChunkNumero(entityId)
    local chunk = self._storage[chunkNumero]
    assert(chunk ~= nil, "the entity you want to despawn does not exist.")

    local entity = chunk[_getChunkRelativeId(self, chunkNumero, entityId)]
    assert(entity ~= nil, "the entity you want to despawn does not exist.")

    chunk[_getChunkRelativeId(self, chunkNumero, entityId)] = nil

    self._idProvider:unuseId(entityId)

    -- if the chunk is empty, remove it
    if _getChunkSize(chunk) == 0 then
        self:_removeChunk(chunkNumero)
    end

    if self._queryCache == nil then
        return
    end

    self._queryCache:notifyCacheDespawnedEntity(entityId, entity)
end

--[=[
    @within World
    @function _rawget
    @param entityId number -- the id of the entity to get
    @return {[string] : {[any] : any}} -- the entity

    Return a raw entity data of the storage.
]=]
function World._rawget(self : World, entityId : number)
    local chunkNumero = self:_getChunkNumero(entityId)
    local chunk = self._storage[chunkNumero]

    if chunk == nil then
        return nil
    end

    return chunk[_getChunkRelativeId(self, chunkNumero, entityId)]
end

--[=[
    @within World
    @function get
    @param entityId number -- the id of the entity to get
    @return EntityMirror -- the mirror of the entity

    Return the mirror of the entity for the provided id.
]=]
function World.get(self : World, entityId)
    local entity = self:_rawget(entityId)
    return EntityMirror.new(self, entityId, entity)
end

--[=[
    @within World
    @function contains
    @param entityId number -- the id where to check if there is an entity
    @return boolean

    Return if the world contains an entity at the provided id.
]=]
function World.contains(self : World, entityId : number)
    local chunkNumero = self:_getChunkNumero(entityId)
    local chunk = self._storage[chunkNumero]
    if chunk == nil then
        return false
    end
    return chunk[_getChunkRelativeId(self, chunkNumero, entityId)] ~= nil
end

--[=[
    @within World
    @function insert
    @param entityId number -- the id of the entity to in which the component is
    inserted
    @param component componentInstance -- the component to insert

    Insert a component at the entity correspounding to the provided id.

    This method can be used to replace an entity's component of the same type,
    in this case, the queryCache won't be notified as the archetype of the
    entity didn't changed.

    ```lua
    world:insert(
        5,
        someComponent({value = 10})
    )
    ```
]=]
function World.insert(self : World, entityId : number, component : defaultComponentInstance)
    local entity = self:_rawget(entityId)
    assert(
        entity ~= nil,
        string.format(
            "Error while inserting the component :\n    - %s" ..
            "in a non-existant entity at \n    - #%i",
            getmetatable(component).name,
            entityId
        )
    )
    local componentType = getmetatable(component)
    -- if we are replacing an existing component then do not notify cache for
    -- component inserted or removed
    -- replaced is whether if the entity is already there or not
    local replaced = entity[componentType.name] ~= nil
    entity[componentType.name] = component

    -- if it is replacing a component from the same type as him, then there has
    -- been no change in the archetype, we can thus return.
    if replaced or self._queryCache == nil then
        return
    end

    local archetype = {}
    for _, entityComponentInstance in pairs(entity) do
        table.insert(archetype, getmetatable(entityComponentInstance))
    end
    self._queryCache:notifyCacheEntityComponentInserted(entityId, archetype, componentType)
end

--[=[
    @within World
    @function remove
    @param entityId number -- the id of the entity from which the component is
    removed
    @param componentType componentType -- the component to remove

    Remove the specified component from an entity.
]=]
function World.remove(self : World, entityId : number, componentType : component)
    local entity = self:_rawget(entityId)
    assert(
        entity[componentType.name] ~= nil,
        "the component you are trying to remove isn't present in the entity"
    )
    entity[componentType.name] = nil

    if self._queryCache == nil then
        return
    end

    local archetype = {}
    for _, entityComponentInstance in pairs(entity) do
        table.insert(archetype, getmetatable(entityComponentInstance))
    end
    self._queryCache:notifyCacheEntityComponentRemoved(entityId, archetype, componentType)
end

--[=[
    @within World
    @function getComponent
    @param entityId number -- the id of the entity to get the component from
    @param componentType component -- the type of the component to get
    @return componentInstance -- the componet to get

    Return a component from an entity.
]=]
function World.getComponent(self : World, entityId : number, componentType : component)
    local entity = self:_rawget(entityId)
    assert(entity ~= nil, "searching for a component of a non existent entity")
    return entity[componentType.name]
end

--[=[
    @within World
    @function startCaching

    Tell the world to start caching.

    When the world is caching, it starts listening when the query method is
    called and cache the concerned archetype of this query.

    This method is automatically called at the beginning of a
    loop but can be called for a :query that is often called and called outside
    of the loop to optimize it.

     ```lua
    world:startCaching()

    -- often used query, outside of a system
    for world:query(someComponents) do
        -- some query work
    end
    
    world:stopCaching()
    ```
]=]
function World.startCaching(self : World)
    self._caching = true
end

--[=[
    @within World
    @function stopCaching

    Tell the world to stop caching.

    This method is automatically called at the end of a loop but can be called
    in a system for a :query that is rarely called to exclude it from an
    useless caching.

    ```lua
    world:stopCaching()

    -- rarely used query, inside of a system
    for world:query(someComponents) do
        -- some query work
    end

    world:startCaching()
    ```
]=]
function World.stopCaching(self : World)
    self._caching = false
end

--[=[
    @within World
    @function addLoop
    @param loop Loop -- the loop to add

    Aggregate the loop with the world.

    A world accepts multiple loops but when a loop is added, it can't be
    removed.
]=]
function World.addLoop(self : World, loop)
    table.insert(self._loops, loop)
end

--[=[
    @within world
    @function _factoryEveryIdQuerier
    @param pool {number} -- the entityId concerned by the query
    @return () -> number -- the iterator function

    This factory method returns the iterator function of a query, it also
    creates the hypothesis and make all the associated work like binding it to
    a merger.

    At each iteration, the hypothesis is merged into its merger and cleared for
    the next iteration.

    No problem with concurrent id use (like 2 different entities spawned at
    the same id and then merged in a same merger) should be spotted because of
    the merger that propagate its idProvider states to the hypothesis at each
    reset of the latter.

    At the end, it closes the hypothesis and commits the merged changes to this
    world.
]=]
function World._factoryEveryIdQuerier(self : World, pool)
    -- allow query in query by recursive hypothesises
    local newMerger = WorldHypothesisMerger.new(self)
    local newHypothesis = WorldHypothesis.new(self, newMerger)
    self:openHypothesis(newHypothesis)

    local index = 0
    return function()
        -- at the beginning of the function as this is called right after an
        -- iteration and the loop operations
        if index >= 1 then
            -- merge the modifications and clear the hypothesis so it is
            -- reusable
            self:resetListenerHypothesis()
        end

        -- the actual iteration
        index = index + 1
        local entityId = pool[index]
        if entityId then
            return entityId
        else
            -- at the end, commit the changes to the associated world (this
            -- world can be another hypothesis in the case of a nested query)
            newMerger:commit()
            self:closeHypothesis()
        end
    end
end

function World._getAllEntitiesIterator(self : World)
    local entityIterator = {}
    for chunkNumero, chunk in pairs(self._storage) do
        for relativeId, _ in pairs(chunk) do
            local entityId = (chunkNumero - 1) * self.chunkSize + relativeId
            table.insert(entityIterator, entityId)
        end
    end
    return entityIterator
end

function World._getRawQueryIterator(self : World, archetype : {component})
    local entityIterator = {}
    for chunkNumero, chunk in pairs(self._storage) do
        for relativeId, entity in pairs(chunk) do
            if entityContains(entity, archetype) then
                local entityId = (chunkNumero - 1) * self.chunkSize + relativeId
                table.insert(entityIterator, entityId)
            end
        end
    end
    return entityIterator
end

-- function World._getCachedIterator(_self : World, _archetype : {component}, pool : {})
--     -- this method isn't useless, when I'll have the motivation to add some
--     -- QueryParameters, with something like you choose a list of components and
--     -- reject any entity with this list of components but with a specific other
--     -- component, this method will become useful as it will sort components.
--     -- (I'll probably redo the DefaultQueryCache in this case)
--     return pool
-- end

-- value only returning iterator factory
local function valueReturningIpairs(t)
    local index = 0

    return function ()
        index += 1
        if t[index] then
            return t[index]
        end
    end
end

--[=[
    @within World
    @function query
    @param archetype {component}? -- the component of the entities to get,
    it can be nil, in this case, it returns a pairs of the entire world.
    @return pairs

    Return a list of entityId correspounding to the provided archetype. For a
    read only query, please use the readQuery() method (query where no change
    is being made)

    :::caution:::
    This method returns an iterator of the actual world, it does not take
    account of any listening hypothesis
]=]
function World.getQueryIterator(self : World, archetype : {component}?)
    -- if the archetype isn't nil (we aren't iterating over all the entities)
    if archetype == nil or #archetype == 0 then
        return self:_getAllEntitiesIterator()
    end

    -- if the world is equipped with a _queryCache
    if self._queryCache ~= nil then
        local pool = self._queryCache:getCached(archetype)
        -- if the query is cached
        if pool ~= nil then
            return pool -- self:_getCachedIterator(archetype, pool)
        end

        -- elseif the world is caching
        if self._caching then
            local entitiesToCache = {}
            for entityId in valueReturningIpairs(self:_getRawQueryIterator(archetype)) do
                table.insert(entitiesToCache, entityId)
            end
            self._queryCache:cacheArchetype(archetype, entitiesToCache)
            return entitiesToCache -- self:_getCachedIterator(archetype, pool)
        end
    end

    return self:_getRawQueryIterator(archetype)
end


--[=[
    @within World
    @function query
    @param ... ...component? -- the component of the entities to get, it can be
    nil, in this case, it returns a pairs of the entire world.
    @return pairs

    Return the result of a pairs() function on a dictionnary of entityIds.

    using this method inside a system is more optimize then using it outside,
    if you are using it outside, consider using the start and stopCaching
    methods

    ```lua
    -- inside a system
    for entityId in world:query(SOME_COMPONENT, SOME_OTHER_COMPONENT) do
        local entity = world:get(entityId)
        -- do some work
    end
    ```

    changes made inside a query are registered in a worldHypothesis and
    committed after all.

    :::caution:::
    You **must** call the world:breakQuery() method if breaking out of a loop
    because else it will start to bug.
]=]
function World.query(self : World, ... : component)
    return self:_factoryEveryIdQuerier(self:getQueryIterator({...}))
end

--[=[
    @within World
    @function query
    @param ... ...component? -- the component of the entities to get, it can be
    nil, in this case, it returns a pairs of the entire world.
    @return () -> number -- return the entityId

    Return an iterator function that iterate over the entity of a provided
    archetype

    Using this method inside a system is more optimize then using it outside,
    if you are using it outside, consider using the start and stopCaching
    methods

    ```lua
    -- inside a system
    for entityId in world:readQuery(SOME_COMPONENT, SOME_OTHER_COMPONENT) do
        local entity = world:get(entityId)
        -- read world data
    end
    ```
]=]
function World.readQuery(self : World, ... : component)
    return valueReturningIpairs(self:getQueryIterator({...}))
end

--[=[
    @within World
    @function breakQuery

    finish the query (when breaking out of it, it merges the hypothsis and
    commit the merger)

    This method should always call the top-nested hypothesis
]=]
function World.breakQuery(self : World)
    self:getListenerHypothesis():breakQuery()
end

return World
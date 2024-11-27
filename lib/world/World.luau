local Component = require(script.Parent.Parent.component.Component)
local Supervisor = require(script.Parent.Parent.component.Supervisor)
local RegisteredComponent = require(script.Parent.Parent.component.RegisteredComponent)

local DefaultQueryCache = require(script.Parent.query_cache.DefaultQueryCache)
local SimpleIdProvider = require(script.Parent.id_provider.SimpleIdProvider)

local EntityMirror = require(script.Parent.EntityMirror)

local WorldTypes = require(script.Parent.WorldTypes)
local QueryCacheInterfaceModule = require(script.Parent.query_cache.QueryCacheInterface)
local IdProviderInterfaceModule = require(script.Parent.id_provider.IdProviderInterface)

--[=[
    @class World

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

type Component = Component.Component
type RegisteredComponent = RegisteredComponent.RegisteredComponent
type defaultComponentInstance = WorldTypes.defaultComponentInstance

type entity = WorldTypes.entity
type EntityMirror = EntityMirror.EntityMirror

type storageChunk = WorldTypes.storageChunk
type storage = WorldTypes.storage

type QueryCacheInterface = QueryCacheInterfaceModule.QueryCacheInterface
type IdProviderInterface = IdProviderInterfaceModule.IdProviderInterface

local function assertRightEntityId(entityId : number)
    assert(
        entityId > 0 and entityId % 1 == 0 ,
        "please, provide a number belonging to the natural numbers, excepted 0 (entityId > 0)"
    )
end

local function entityContains(entity : entity | EntityMirror, archetype : {string}?)
    if archetype == nil then
        return true
    end

    for _, componentName in ipairs(archetype) do
        if entity[componentName] == nil then
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
        _spawnRecorderStack = nil,
        _queryCache = (
            if queryCache == nil then
                DefaultQueryCache.new(20)
            elseif queryCache == false then
                nil
            else
                queryCache
        ),

        _loops = {}
    }, World)
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
    @function copyIdProvider
    @return IdProviderInterface -- a clone of the idProvider

    Return a clone of the id provider of the world.
]=]
function World.copyIdProvider(self : World)
    return self._idProvider:clone()
end

--[=[
    @within World
    @function spawnAt
    @param entityId number -- the id to spawn the entity
    @param componentDict {[string] : Component} -- a dictionnary of component instances to
    give to the entity

    Spawn an entity at the provided id with the given dictionnary of components

    ```lua
    world:spawnAt(5, {
        some_component = component({value = 5})
    })
    local entity = world:get(5)
    ```
]=]
function World.spawnAt(self : World, entityId : number, componentDict : {[string] : Component})
    assertRightEntityId(entityId)
    local chunk = self:_makeChunkAt(entityId)

    local entity = table.clone(componentDict)
    chunk[_getChunkRelativeId(self, self:_getChunkNumero(entityId), entityId)] = entity

    self._idProvider:useId(entityId)

    if self._queryCache == nil then
        return
    end

    -- record it
    if self._spawnRecorderStack ~= nil then
        self:_recordSpawn(entityId)
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
    @param componentDict {[string] : Component} -- a dictionnary of components to
    give to the entity
    @return number -- the id of the spawned entity

    Spawn an entity with the given list of componentInstances

    ```lua
    local entity = world:spawn({
        some_component = component({value = 5})
    })
    ```
]=]
function World.spawn(self : World, componentDict : {[string] : Component})
    local id = self._idProvider:useNextId()
    self:spawnAt(id, componentDict)
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

    -- notify every components (onRemoved())
    for componentName, _ in pairs(entity) do
        self:remove(entityId, componentName)
    end

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

-- the spawn recording system is only used in a case of a nested AllEntities
-- query. (very rare situation actually)
-- it makes sure that spawned entity during an allEntities query won't be
-- counted as part of this query.

function World._startRecordingSpawn(self : World)
    if self._spawnRecorderStack == nil then
        self._spawnRecorderStack = {}
    end
    table.insert(self._spawnRecorderStack, {})
end

function World._stopRecordingSpawn(self : World)
    table.clear(self._spawnRecorderStack[#self._spawnRecorderStack])
    self._spawnRecorderStack[#self._spawnRecorderStack] = nil
    if #self._spawnRecorderStack == 0 then
        self._spawnRecorderStack = nil
        return
    end
end

function World._recordSpawn(self : World, entityId : number)
    for _, t in pairs(self._spawnRecorderStack) do
        table.insert(t, entityId)
    end
end

function World._getRecordedSpawns(self : World)
    if self._spawnRecorderStack == nil then
        return nil
    end

    return self._spawnRecorderStack[#self._spawnRecorderStack]
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
    @param entityId number -- the id of the entity in which the component is
    inserted
    @param componentName string -- the name of the component to insert
    @param component Component -- the component to insert

    Insert a component at the entity correspounding to the provided id.

    This method can be used to replace an entity's component of the same type,
    in this case, the queryCache won't be notified as the archetype of the
    entity didn't changed.

    ```lua
    world:insert(
        5,
        someComponent:getName(),
        someComponent({value = 10})
    )
    ```
]=]
function World.insert(self : World, entityId : number, componentName : string, component : Component)
    local entity = self:_rawget(entityId)
    assert(
        entity ~= nil,
        string.format(
            "Error while inserting the component :\n    - %s" ..
            "in a non-existant entity at \n    - #%i",
            componentName,
            entityId
        )
    )
    -- if we are replacing an existing component then do not notify cache for
    -- component inserted or removed
    -- replaced is whether if the entity is already there or not
    local replaced = entity[componentName] ~= nil

    if replaced then
        -- update the reference to point to the new component
        entity[componentName]:onReplacing(component, componentName, entityId, self)
    end

    entity[componentName] = component

    -- if it is replacing a component from the same type as him, then there has
    -- been no change in the archetype, we can thus return.
    if replaced or self._queryCache == nil then
        return
    end

    local archetype = {}
    for archetypeComponentName, _ in pairs(entity) do
        table.insert(archetype, archetypeComponentName)
    end
    self._queryCache:notifyCacheEntityComponentInserted(entityId, archetype, componentName)
end

--[=[
    @within World
    @function supervise
    @param entityId number -- the id of the entity to supervise
    @return Supervisor -- the supervisor of the entity

    Return a supervisor of an entity, check Supervisor.luau for more info
]=]
function World.supervise(self : World, entityId : number)
    local supervisor = self:getComponent(entityId, Supervisor.REGISTERED:getName())

    -- already supervised
    if supervisor ~= nil then
        return supervisor
    end

    -- create the supervisor
    supervisor = Supervisor.REGISTERED:build(self, entityId)
    self:insert(entityId, Supervisor.REGISTERED:getName(), supervisor)
    return supervisor
end

--[=[
    @within World
    @function remove
    @param entityId number -- the id of the entity from which the component is
    removed
    @param componentName string -- the name of the component to remove

    Remove the specified component from an entity.
]=]
function World.remove(self : World, entityId : number, componentName : string)
    local entity = self:_rawget(entityId)
    local component = entity[componentName]
    assert(
        component ~= nil,
        "the component you are trying to remove isn't present in the entity"
    )
    entity[componentName] = nil
    component:onRemoved(componentName, entityId, self)

    if self._queryCache == nil then
        return
    end

    local archetype = {}
    for _, entityComponentInstance in pairs(entity) do
        table.insert(archetype, getmetatable(entityComponentInstance))
    end
    self._queryCache:notifyCacheEntityComponentRemoved(entityId, archetype, componentName)
end

--[=[
    @within World
    @function getComponent
    @param entityId number -- the id of the entity to get the component from
    @param componentType RegisteredComponent -- the type of the component to get
    @return Component? -- the componet to get

    Return a component from an entity.
]=]
function World.getComponent(self : World, entityId : number, componentName : string)
    local entity = self:_rawget(entityId)
    assert(entity ~= nil, "searching for a component of a non existent entity")
    return entity[componentName]
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

local function getNextValidId(world : World, pool : {number}, index : number)
    index += 1
    if pool[index] == nil then
        return
    end

    if world:contains(pool[index]) then
        return index
    else
        return getNextValidId(world, pool, index)
    end
end

--[=[
    @within world
    @function _factoryEveryIdQuerier
    @param pool {number} -- the entityId concerned by the query
    @return () -> number -- the iterator function

    Return an iterator function that queries over every entities of the world.
]=]
function World._factoryEveryIdQuerier(self : World, pool : {number})
    local index = 0
    return function()
        index = getNextValidId(self, pool, index)
        return pool[index]
    end
end

local function _idSpawnedDuringQuery(world : World, id : number)
    for _, entityId in ipairs(world:_getRecordedSpawns()) do
        if entityId == id then
            return true
        end
    end
    return false
end

function World._factoryEntireWorldQuerier(self : World)
    self:_startRecordingSpawn()
    -- no problem with this as we do not care about any spawned 
    local lastId = self:_getLastId()
    local actualId = 0

    return function ()
        -- checks if we didn't reach the end
        if actualId == lastId then
            self:_stopRecordingSpawn()
            return
        end

        actualId += 1

        -- checks :
        -- • if the world actually contains the entity (if it hasn't been removed in between)
        -- • if we haven't finished the iteration (we reached the end of the world)
        -- • if the entity hadn't been spawned during the query iteration
        -- until it finds an entity that matches andy of these checks
        while true do
            if self:contains(actualId) and not _idSpawnedDuringQuery(self, actualId) then
                break
            end

            actualId += 1

            -- checks if we didn't reach the end
            if actualId == lastId then
                self:_stopRecordingSpawn()
                return
            end
        end

        return actualId
    end
end

function World._getRawQueryIterator(self : World, archetype : {string})
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
    @param archetype {RegisteredComponent}? -- the components of the entities to get,
    it can be nil, in this case, it returns a pairs of the entire world.
    @return pairs

    Return a list of entityId correspounding to the provided archetype. For a
    read only query, please use the readQuery() method (query where no change
    is being made)
]=]
function World.getQueryIterator(self : World, archetype : {string})
    -- if the world is equipped with a _queryCache
    if self._queryCache ~= nil then
        -- create componentName based archetype

        local pool = self._queryCache:getCached(archetype)
        -- if the query is cached
        if pool ~= nil then
            return table.clone(pool) -- self:_getCachedIterator(archetype, pool)
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

local function registeredComponentToNames(t : {RegisteredComponent})
    local result = {}
    for _, registeredComponent in ipairs(t) do
        table.insert(result, registeredComponent:getName())
    end
    return result
end

--[=[
    @within World
    @function query
    @param ... ...RegisteredComponent? -- the component of the entities to get, it can be
    nil, in this case, it returns a pairs of the entire world.
    @return pairs

    Return the result an iterator function that returns every ids of the
    entities which contain the provided archetype

    Using this method inside a system is more optimize then using it outside,
    if you are using it outside and regularly, consider using the start and
    stopCaching methods

    ```lua
    -- inside a system
    for entityId in world:query(SOME_COMPONENT, SOME_OTHER_COMPONENT) do
        local entity = world:get(entityId)
        -- do some work
    end
    ```
]=]
function World.query(self : World, ... : RegisteredComponent)
    local archetype = registeredComponentToNames({...})

    if #archetype == 0 then
        return self:_factoryEntireWorldQuerier()
    end

    return self:_factoryEveryIdQuerier(
        self:getQueryIterator(
            archetype
        )
    )
end

--[=[
    @within World
    @function query
    @param ... ...RegisteredComponent? -- the component of the entities to get, it can be
    nil, in this case, it returns an iterator of the entire world.
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
function World.readQuery(self : World, ... : RegisteredComponent)
    return valueReturningIpairs(
        self:getQueryIterator(
            registeredComponentToNames({...})
        )
    )
end

--[=[
    @within World
    @function breakQuery

    finish the query (when breaking out of it, it merges the hypothsis and
    commit the merger)
]=]
function World.breakQuery(self : World)
    if self._spawnRecorderStack ~= nil then
        table.clear(self._spawnRecorderStack[#self._spawnRecorderStack])
        if #self._spawnRecorderStack == 0 then
            self._spawnRecorderStack = nil
        end
    end
end

return World
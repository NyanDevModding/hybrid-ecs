local RunService = game:GetService("RunService")
local Component = require(script.Parent.Parent.Parent.component.Component)

local DefaultQueryCache = {}
DefaultQueryCache.__index = DefaultQueryCache

type component = Component.Component
type defaultComponentInstance = Component.genericComponent<any, {(...any) -> any}>

type entity = {[string] : defaultComponentInstance}

export type QueryCacheInterface = {}
export type DefaultQueryCache = typeof(DefaultQueryCache.new())

function DefaultQueryCache.new(lifecycleTime : number?)
    local instance = setmetatable({
        lifecycleTime = lifecycleTime or 20,
        lifecycleCooldown = 0,
        _cache = {}
    }, DefaultQueryCache)

    instance._heartbeatConnexion = RunService.Heartbeat:Connect(function()
        -- toggle comment until its debugged as heartbeat connexions make
        -- testez companion die
        -- instance.lifecycleCooldown += 1
        -- if instance.lifecycleCooldown >= instance.lifecycleTime then
        --     instance:lifecycleCache()
        --     instance.lifecycleCooldown = 0
        -- end
    end)

    return instance
end

-- EntityPool

--[=[
    @class EntityPool

    Store as a list the ids of all the entities, correspounding to a specific
    archetype

    It should be red several time per cycle, otherwise it will be cleaned up.
    The entityPool is automatically red by the cachedQuery to iterate over it.

    The lifecycle function is called by the heartbeat method connected during
    the construction of the queryCache.
]=]
local EntityPool = {}
EntityPool.__index = EntityPool

type EntityPoolClass = typeof(EntityPool)
type EntityPool = typeof(EntityPool.new())

do
    function EntityPool.new(queryCache : DefaultQueryCache, components : {component})
        return setmetatable({
            _pool = {},
            _red = true,
            queryCache = queryCache,
            archetype = components
        }, EntityPool)
    end

    function EntityPool.initialize(self : EntityPool, concernedEntityIds : {number})
        -- local archetypeSize = #self.archetype
        -- -- iterate over storage chunks
        -- for _, chunk in ipairs(self.queryCache.world._storage) do
        --     -- iterate over entities in the chunk
        --     for entityId, _entity : entity in pairs(chunk) do
        --         -- iterate over the archetype and checks if the components are
        --         -- included in the entity.
        --         -- if the includedComponentAmount is the same length as the
        --         -- archetypeSize then it means that all the archetype
        --         -- components are included.
        --         local includedComponentAmount = 0
        --         for _, component in ipairs(self.archetype) do
        --             if _entity[component.name] ~= nil then
        --                 includedComponentAmount += 1
        --             end
        --         end

        --         -- add it to the entityPool
        --         if includedComponentAmount == archetypeSize then
        --             self:add(entityId)
        --         end
        --     end
        -- end
        for _, entityId in ipairs(concernedEntityIds) do
            self:add(entityId)
        end
    end

    function EntityPool.read(self : EntityPool)
        self._red = true
        return self._pool
    end

    function EntityPool.add(self : EntityPool, entityId : number)
        table.insert(self._pool, entityId)
    end

    function EntityPool.remove(self : EntityPool, entityId : number)
        for index, value in ipairs(self._pool) do
            if value == entityId then
                table.remove(self._pool, index)
                return
            end
        end
    end

    -- can only be called by a queryCache:uncacheArchetype() or a queryCache:clear()
    function EntityPool.clear(self : EntityPool)
        table.clear(self._pool)
        self._pool = nil
        self.archetype = nil
        self.queryCache = nil
    end

    function EntityPool.onLifecycle(self : EntityPool)
        if not self._red then
            self.queryCache:uncacheArchetype(self.archetype)
            return
        end
        self._red = false
    end
end

-- DefaultQueryCache operations

type cacheElement = {entityPool : EntityPool?, pairs : {[component] : cacheElement}?}
-- componentStack is the path in the _queryCache that leads to the cacheElement
type queryCacheCommandExecute = (self : queryCacheCommandInterface, queryCache : DefaultQueryCache, component : component, cacheElement : cacheElement, componentStack : {[number] : component}) -> any
-- either a simple function or a table with __call defined
type queryCacheCommandInterface = (queryCache : DefaultQueryCache, component : component, cacheElement : cacheElement, componentStack : {[number] : component}) -> any

-- here are some methods that are doubled, this is because sometime we don't
-- want some of the data that provide these methods.
-- REJECT CODE REUSE, EMBRACE BRUT OPTIMIZATION

-- inner work of _executeOnCacheElement
local function _executeOnCacheElementRecursive(cacheElement : cacheElement, components : {component}, stack : {[number] : component}, command : queryCacheCommandInterface, queryCache)
    local continueSearch = #components > 1
    for k, component in ipairs(components) do
        if cacheElement.pairs ~= nil and cacheElement.pairs[component] ~= nil then
            -- if the archetype is finished, this has to be the cacheElement we
            -- are searching for.
            if continueSearch then
                local newComponents = table.clone(components)
                table.remove(newComponents, k)
                -- recursively search for the next components
                table.insert(stack, component)
                local commandResult : any = _executeOnCacheElementRecursive(
                    cacheElement.pairs[component],
                    newComponents,
                    stack,
                    command,
                    queryCache
                )
                newComponents = nil
                if commandResult then
                    return commandResult
                end
                table.remove(stack, #stack)
            else
                -- found the cacheElement
                table.insert(stack, component)
                return command(queryCache, component, cacheElement.pairs[component], stack)
            end
        end
    end
    return nil
end

-- inner work of _executeOnCacheElement but without the stack argument
local function _executeOnCacheElementRecursiveWithoutStack(cacheElement : cacheElement, components : {component}, command : queryCacheCommandInterface, queryCache)
    local continueSearch = #components > 1
    for k, component in ipairs(components) do
        if cacheElement.pairs ~= nil and cacheElement.pairs[component] ~= nil then
            -- if the archetype is finished, this has to be the cacheElement we
            -- are searching for.
            if continueSearch then
                local newComponents = table.clone(components)
                table.remove(newComponents, k)
                -- recursively search for the next components
                local commandResult : any = _executeOnCacheElementRecursiveWithoutStack(
                    cacheElement.pairs[component],
                    newComponents,
                    command,
                    queryCache
                )
                newComponents = nil
                if commandResult then
                    return commandResult
                end
            else
                -- found the cacheElement
                return command(queryCache, component, cacheElement.pairs[component])
            end
        end
    end
    return nil
end

--[=[
    @within QueryCache
    @function _executeOnCacheElement
    @param components {component} -- the archetype on which we execute the
    command
    @param command queryCacheCommandExecute -- the command to execute
    @param needStack boolean -- if it will use the stack, if its nil then it
    will trigger a less charged function
    @return typeof(command()) -- returns what the command returns

    Execute the provided command on the cacheElement that it find in the
    _queryCache for the provided archetype.
    This system is meant for code reuse and flexibility by the use of the
    command design pattern.
]=]
function DefaultQueryCache._executeOnCacheElement(self : DefaultQueryCache, components : {component}, command : queryCacheCommandExecute, needStack : boolean)
    if #components == 1 then
        return command(self, components[1], self._cache[components[1]], if needStack then components else nil)
    end

    -- iterate over the components of the archetype to call the recursive
    -- function on each first components
    for k, component in ipairs(components) do
        if self._cache[component] then
            local result
            local subComponents = table.clone(components)
            table.remove(subComponents, k)
            if needStack then
                result = _executeOnCacheElementRecursive(self._cache[component], subComponents, {}, command, self)
            else
                result = _executeOnCacheElementRecursiveWithoutStack(self._cache[component], subComponents, command, self)
            end
            subComponents = nil

            if result then
                return result
            end
        end
    end
end

-- inner work of _executeOnCache
local function _executeRecursiveOnCache(cacheElement : cacheElement, component : component, stack : {[number] : component}, command : queryCacheCommandInterface, queryCache)
    command(queryCache, component, cacheElement, stack)
    if cacheElement.pairs then
        for pairedComponent, pairedCacheElement in ipairs(cacheElement.pairs) do
            table.insert(stack, pairedComponent)
            _executeRecursiveOnCache(pairedCacheElement, pairedComponent, stack, command, queryCache)
            table.remove(stack, #stack)
        end
    end
end

-- inner work of _executeOnCache but without the stack argument
local function _executeRecursiveOnCacheWithoutStack(cacheElement : cacheElement, component : component, command : queryCacheCommandInterface, queryCache)
    command(queryCache, component, cacheElement)
    if cacheElement.pairs then
        for pairedComponent, pairedCacheElement in ipairs(cacheElement.pairs) do
            _executeRecursiveOnCacheWithoutStack(pairedCacheElement, pairedComponent, command, queryCache)
        end
    end
end

--[=[
    @within QueryCache
    @function _executeOnCache
    @param command queryCacheCommandInterface -- the command to execute
    @param needStack boolean -- if it will use the stack, if its nil then it
    will trigger a less charged function
    @return nil

    Execute the provided command on all the cacheElement that it finds in the
    _queryCache.
]=]
function DefaultQueryCache._executeOnCache(self : DefaultQueryCache, command : queryCacheCommandInterface, needStack : boolean)
    -- iterate over the components on top to call the recursive function on
    -- each of them
    for component, cacheElement in pairs(self._cache) do
        if self._cache[component] then
            if needStack then
                _executeRecursiveOnCache(cacheElement, component, {}, command, self)
            else
                _executeRecursiveOnCacheWithoutStack(cacheElement, component, command, self)
            end
        end
    end
end

-- inner work of _executeOnArchetypeComposite
local function _executeRecursiveOnArchetypeComposites(cacheElement : cacheElement, components : {component}, stack : {[number] : component}, command : queryCacheCommandInterface)
    command(nil, nil, cacheElement, stack)

    -- if there is no pairs then there is no purpose to iterating over archetype.
    if cacheElement.pairs == nil then
        return
    end

    for k, component in ipairs(components) do
        local subCacheElement = cacheElement.pairs[component]
        if subCacheElement ~= nil then
            local subComponents = table.clone(components)
            table.insert(stack, subComponents[k])
            table.remove(subComponents, k)
            _executeRecursiveOnArchetypeComposites(subCacheElement, subComponents, stack, command)
            table.remove(stack, #stack)
            table.clear(subComponents)
        end
    end
end

-- inner work of _executeOnArchetypeComposite without stack
local function _executeRecursiveOnArchetypeCompositesWithoutStack(cacheElement : cacheElement, components : {component}, command : queryCacheCommandInterface)
    command(nil, nil, cacheElement)

    -- if there is no pairs then there is no purpose to iterating over archetype.
    if cacheElement.pairs == nil then
        return
    end

    for k, component in ipairs(components) do
        local subCacheElement = cacheElement.pairs[component]
        if subCacheElement ~= nil then
            local subComponents = table.clone(components)
            table.remove(subComponents, k)
            _executeRecursiveOnArchetypeCompositesWithoutStack(subCacheElement, components, command)
            table.clear(subComponents)
        end
    end
end

--[=[
    @within QueryCache
    @function _executeOnArchetypeComposite
    @param components {component} -- the archetype
    @param command queryCacheCommandInterface -- the command to execute
    @return nil

    This function is used to execute a command on each of the archetypes
    included in the provided archetypes.

    Example : if components = {1, 2}, it will execute the command on the
    cacheElements (if they exist) 1, 2 and 1-2
]=]
function DefaultQueryCache._executeOnArchetypeComposite(self : DefaultQueryCache, components : {component}, command : queryCacheCommandInterface, needStack : boolean)
    for index, component in ipairs(components) do
        -- continue if there is no cacheElement
        if self._cache[component] == nil then
            continue
        end
        local subComponents = table.clone(components)
        table.remove(subComponents, index)
        if needStack then
            local stack = {component}
            _executeRecursiveOnArchetypeComposites(self._cache[component], subComponents, stack, command)
            stack = nil
        else
            _executeRecursiveOnArchetypeCompositesWithoutStack(self._cache[component], subComponents, command)
        end
        table.clear(subComponents)
    end
    return nil
end

-- the set of commands to use with cache-iterating operations; the return of a
-- command is the return of this operation.
--[=[
    @class CacheCommand

    The base class for the command used in the processes of queryCache.
]=]
local CacheCommand = {}
CacheCommand.__index = CacheCommand

local ERROR_NIL_COMMAND_DATA = "command object defined without default data "
    .. "nor explicitData in new method, resulting in memory used for no "
    .. "reason, please consider using a function instead of a cacheCommand "
    .. "object"

do
    function CacheCommand.create(execute : queryCacheCommandExecute, data : {any})
        local cacheCommand = setmetatable({
            execute = execute,
            data = data
        }, CacheCommand)
        cacheCommand.__index = cacheCommand
        cacheCommand.__call = CacheCommand.__call
        return cacheCommand
    end

    function CacheCommand.new(self, explicitData)
        assert(self.data ~= nil or explicitData ~= nil, ERROR_NIL_COMMAND_DATA)

        local command
        if self.data ~= nil then
            command = table.clone(self.data)
            for index, value in explicitData do
                command[index] = value
            end
        else -- if self.data is nil then
            command = table.clone(explicitData)
        end

        return setmetatable(command, self)
    end

    function CacheCommand.__call(self, ...)
        return self:execute(...)
    end
end

--[=[
    @enum _CacheCommandsS

    all the cache commands, can either be a function or a cacheCommand object,
    it must reflect the queryCacheCommandInterface.
]=]
local _CacheCommands : {[string] : queryCacheCommandInterface} = {
    GET_COMMAND = function(_, _, cacheElement) : cacheElement
        return cacheElement
    end,
    UNCACHE_COMMAND = function(queryCache, component, cacheElement, componentStack) : nil
        -- can't if archetype not cached
        if cacheElement == nil then
            return
        end

        -- delete the entityPool
        if cacheElement.entityPool then
            cacheElement.entityPool:clear()
            cacheElement.entityPool = nil
        end

        -- launch the recursive uncache process that delete the parents in the
        -- archetype if they were'nt stocking any data other that this deleted
        -- child
        queryCache:_recursiveUncache(component, cacheElement, componentStack)
    end,
    CLEAR_COMMAND = function(queryCache, _, cacheElement) : nil
        -- delete the entityPool
        if cacheElement.entityPool then
            cacheElement.entityPool:clear()
            cacheElement.entityPool = nil
        end

        -- check for recursivity
        if cacheElement.pairs then
            for _, subCacheElement in pairs(cacheElement.pairs) do
                DefaultQueryCache._CacheCommands.CLEAR_COMMAND(queryCache, nil, subCacheElement)
            end

            -- delete the pairs
            table.clear(cacheElement.pairs)
            cacheElement.pairs = nil
        end
    end,
    -- requires the data entity (the new entity to add to the cache)
    ADD_ENTITY = CacheCommand.create(
        function(self, _, _, cacheElement)
            cacheElement.entityPool:add(self.entityId)
        end,
        nil
    ),
    -- requires the data entity (the new entity to add to the cache)
    REMOVE_ENTITY = CacheCommand.create(
        function(self, _, _, cacheElement)
            cacheElement.entityPool:remove(self.entityId)
        end,
        nil
    ),
    -- used when an entity archetype is modified
    ADD_ENTITY_TO_UNNOTIFIED_CACHE_ELEMENT = CacheCommand.create(
        function(self, _, _, cacheElement, componentStack)
            for _, component in ipairs(componentStack) do
                -- if the added component is present then add the entity to the
                -- pool
                if component == self.component then
                    cacheElement.entityPool:add(self.entityId)
                end
            end
        end,
        nil
    ),
    -- used when an entity archetype is modified
    REMOVE_ENTITY_FROM_UNNOTIFIED_CACHE_ELEMENT = CacheCommand.create(
        function(self, _, _, cacheElement, componentStack)
            for _, component in ipairs(componentStack) do
                -- if the removed component is present then add the entity to
                -- the pool
                if component == self.component then
                    cacheElement.entityPool:remove(self.entityId)
                end
            end
        end,
        nil
    ),
}
DefaultQueryCache._CacheCommands = _CacheCommands

-- inner work of the command UNCACHE
function DefaultQueryCache._recursiveUncache(self : DefaultQueryCache, component, cacheElement, componentStack)
    -- if a cacheElement has no pair nor entityPool, it should be deleted

    -- can't if there is an active entityPool
    if cacheElement.entityPool then
        return
    end

    -- continue if no pairs (null it when there is no pairs)
    -- conserve the cacheElement if it has pairs
    if cacheElement.pairs ~= nil then
        -- check if the cacheElement has pairs
        local isPairsNil = true
        for _ in cacheElement.pairs do
            isPairsNil = false
            break
        end

        if not isPairsNil then
            return -- conserve it
        end
        -- no pairs, just an empty pairs table
        cacheElement.pairs = nil
    end

    -- remove the cacheElement from the storage and check if parent should be
    -- removed :

    -- get the parent by removing the final cacheElement from the archetype
    local parentCacheElementStack = table.clone(componentStack)
    table.remove(parentCacheElementStack, #componentStack)

    -- if the parentCacheElementStack is nil, it means that the cacheElement
    -- is just under the _cache, it has no parent
    if #parentCacheElementStack == 0 then
        self._cache[componentStack[1]] = nil
        return
    end

    -- use the stack of the parent as an archetype
    local parentCacheElement : cacheElement = self:_executeOnCacheElement(parentCacheElementStack, _CacheCommands.GET_COMMAND, false)

    parentCacheElement.pairs[component] = nil

    -- if it stores data, then no use to delete it
    if parentCacheElement.entityPool ~= nil then
        return
    end

    -- checks if the parent wasn't stocking any other data, other that this
    -- deleted child.
    self:_recursiveUncache(
        parentCacheElementStack[#parentCacheElementStack],
        parentCacheElement,
        parentCacheElementStack
    )
end


function DefaultQueryCache.getCached(self : DefaultQueryCache, components : {[number] : component}) : {number}?
    local cacheElement : cacheElement = self:_executeOnCacheElement(
        components,
        _CacheCommands.GET_COMMAND,
        false
    )
    return if cacheElement ~= nil and cacheElement.entityPool~= nil then cacheElement.entityPool:read() else nil
end

-- isCached does not read the cacheElement and so, does not protect it from being cleaned up.
-- if you wanna call read on it, consider using :getCached()
function DefaultQueryCache.isCached(self : DefaultQueryCache, components : {[number] : component}) : boolean
    -- check if the cache element exists and if it has an entityPool (if it
    -- is not in a state where its just part of an archetype definition
    -- throught the cache)
    local cacheElement = self:_executeOnCacheElement(
        components,
        _CacheCommands.GET_COMMAND,
        false
    )

    return if cacheElement == nil
        then
            false
        else (
            if cacheElement.entityPool == nil
            then
                false
            else
                true
        )
end

-- inner work of _heartbeatCache
local function _lifecycleCacheElement(cacheElement : cacheElement)
    -- checks if the cacheElement stores data or is just part of an archetype
    if cacheElement.entityPool then
        cacheElement.entityPool:onLifecycle()
    end

    if cacheElement.pairs then
        for _, pairedCacheElement in pairs(cacheElement.pairs) do
            _lifecycleCacheElement(pairedCacheElement)
        end
    end
end

function DefaultQueryCache.lifecycleCache(self : DefaultQueryCache)
    for _, cacheElement in pairs(self._cache) do
        _lifecycleCacheElement(cacheElement)
    end
end

local function _findPartiallyCachedArchetype(cacheElement : cacheElement, components : {[number] : component})
    local continueSearch = #components > 1
    for k, component in ipairs(components) do
        if cacheElement.pairs ~= nil and cacheElement.pairs[component] ~= nil then
            if continueSearch then
                local newComponents = table.clone(components)
                table.remove(newComponents, k)
                -- recursively search for the next components
                local newCacheElement = _findPartiallyCachedArchetype(
                    cacheElement.pairs[component],
                    newComponents
                )
                if newCacheElement ~= cacheElement then
                    return newCacheElement, newComponents
                end
                newComponents = nil
            else
                -- found the cacheElement
                return cacheElement.pairs[component]
            end
        end
    end
    return cacheElement, components
end

function DefaultQueryCache.cacheArchetype(self : DefaultQueryCache, components : {[number] : component}, cachedEntityIds : {number})
    -- if the first cacheElement doesnt exist then create it
    if self._cache[components[1]] == nil then
        self._cache[components[1]] = {
            -- pairs = (
            --     if components[2] ~= nil then
            --     {}
            --     else
            --     nil
            -- )
        }
    end
    -- store it
    local firstCacheElement = self._cache[components[1]]

    -- if the archetype is already cached then
    -- also means that #components == 1
    if #components == 1 then
        firstCacheElement.entityPool = EntityPool.new(
            self,
            {components[1]}
        )
        firstCacheElement.entityPool:initialize(cachedEntityIds)
        return
    end

    local restComponents = table.clone(components)
    table.remove(restComponents, 1)

    -- use it to find which component of the archetype need to be created and
    -- which part of the archetype already exists.
    --  • cacheElement is the deeper cacheElement found in the archetype cache
    -- storage.
    --  • restComponents stores all the components that need to be instanciated.
    local cacheElement
    cacheElement, restComponents = _findPartiallyCachedArchetype(firstCacheElement, restComponents)

    -- variables for iteration and creation of cache Elements
    local nextCacheElement = cacheElement
    local nextComponents = table.clone(components)
    -- caculate the base archetype for the cacheElement by substracting
    -- the two archetypes
    for _, component in ipairs(restComponents) do
        for k, otherComponent in ipairs(components) do
            if component == otherComponent then
                nextComponents[k] = nil
            end
        end
    end

    -- reorder the table
    for k, component in pairs(nextComponents) do
        if k > #nextComponents then
            nextComponents[#nextComponents + 1] = component
            nextComponents[k] = nil
        end
    end

    if #restComponents > 0 then
        -- create a cacheElement for each component of the archetype
        for _, component in ipairs(restComponents) do
            -- add the component to cacheElement's archetype data
            table.insert(nextComponents, component)
            -- pair the cacheElement with the parent one
            nextCacheElement.pairs = {[component] = {}}
            -- prepare for the next iteration
            nextCacheElement = nextCacheElement.pairs[component]
            -- nextComponents = table.clone(nextComponents)
        end
    end

    -- create the entityPool and initialize it
    nextCacheElement.entityPool = EntityPool.new(self, nextComponents)
    nextCacheElement.entityPool:initialize(cachedEntityIds)
end

function DefaultQueryCache.uncacheArchetype(self : DefaultQueryCache, components : {[number] : component})
    self:_executeOnCacheElement(components, _CacheCommands.UNCACHE_COMMAND, true)
end

function DefaultQueryCache.notifyCacheSpawnedEntity(self : DefaultQueryCache, entityId : number, entity : entity)
    local command = _CacheCommands.ADD_ENTITY:new({entityId = entityId})
    local archetype = {}
    for _, componentInstance in pairs(entity) do
        table.insert(archetype, getmetatable(componentInstance))
    end

    self:_executeOnArchetypeComposite(archetype, command, false)
end

function DefaultQueryCache.notifyCacheDespawnedEntity(self : DefaultQueryCache, entityId : number, entity : entity)
    local command = _CacheCommands.REMOVE_ENTITY:new({entityId = entityId})
    local archetype = {}
    for _, componentInstance in pairs(entity) do
        table.insert(archetype, getmetatable(componentInstance))
    end

    self:_executeOnArchetypeComposite(archetype, command, false)
end

--[=[
    @within QueryCache
    @function _notifyCacheEntityComponentInserted
    @param components {component} -- the archetype of the entity
    @param component component -- the inserted component
    @return nil

    Handles whenever an entity receives a component to redistribute it
    in the right cacheElements
]=]
function DefaultQueryCache.notifyCacheEntityComponentInserted(self : DefaultQueryCache, entityId : number, components : {component}, component : component)
    local command = _CacheCommands.ADD_ENTITY_TO_UNNOTIFIED_CACHE_ELEMENT:new({
        entityId = entityId,
        component = component
    })

    self:_executeOnArchetypeComposite(components, command, true)
end

--[=[
    @within QueryCache
    @function _notifyCacheEntityComponentRemoved
    @param components {component} -- the archetype of the entity
    @param component component -- the removed component
    @return nil

    Handles whenever an entity removes a component to redistribute it
    in the right cacheElements
]=]
function DefaultQueryCache.notifyCacheEntityComponentRemoved(self : DefaultQueryCache, entityId : number, components : {component}, component : component)
    local command = _CacheCommands.REMOVE_ENTITY_FROM_UNNOTIFIED_CACHE_ELEMENT:new({
        entityId = entityId,
        component = component
    })

    self:_executeOnArchetypeComposite(components, command, true)
end

function DefaultQueryCache.clearCache(self : DefaultQueryCache)
    self:_executeOnCache(_CacheCommands.CLEAR_COMMAND, false)
end

return DefaultQueryCache
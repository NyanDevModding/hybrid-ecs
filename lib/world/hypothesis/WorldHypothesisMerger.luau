local HypothesisWorldInterface = require(script.Parent.Parent.HypothesisWorldInterface)
local IdProviderInterfaceModule = require(script.Parent.Parent.id_provider.IdProviderInterface)
local WorldTypes = require(script.Parent.Parent.WorldTypes)

type HypothesisWorldInterface = HypothesisWorldInterface.HypothesisWorldInterface
type IdProviderInterface = IdProviderInterfaceModule.IdProviderInterface
type entity = WorldTypes.entity
type WorldHypothesis = typeof(require(script.Parent.WorldHypothesis).new())

--[=[
    @class WorldHypothesisMerger

    The WorldHypothesisMerger receives changes made during a query from an
    hypothesis and merge them into its storage. It propagates its id provider
    state to a resetting hypothesis as else, there would be concurrent spawn
    bugs (two entities spawned to a same id = unmergeable change).

    It then commits the changes to the subWorld (not the "world" because the
    merged changes can be committed to an hypothesis if we are in a case of
    nested query). The commit happen at the end of a query and is always
    called by the iterator function of the query.
]=]
local WorldHypothesisMerger = {}
WorldHypothesisMerger.__index = WorldHypothesisMerger

local _recycleBin : {WorldHypothesisMerger} = {}
local MAX_RECYCLE_BIN_SIZE = 16

export type WorldHypothesisMergerClass = typeof(WorldHypothesisMerger)
export type WorldHypothesisMerger = typeof(WorldHypothesisMerger.new())

local function entityToComponentList(entity : entity)
    local componentList = {}
    for _, componentInstance in pairs(entity) do
        table.insert(componentList, componentInstance)
    end
    return componentList
end

function WorldHypothesisMerger.new(world : HypothesisWorldInterface)
    -- recycling
    if _recycleBin[1] ~= nil then
        local instance = _recycleBin[#_recycleBin]
        _recycleBin[#_recycleBin] = nil
        instance._world = world
        instance._idProvider = world:copyIdProvider()
        return instance
    end

    return setmetatable({
        _world = world,
        _idProvider = world:copyIdProvider(),
        _mergedStorage = {},
        _despawnStorage = {},
    }, WorldHypothesisMerger)
end

--[=[
    @within WorldHypothesisMerger
    @function copyIdProvider
    @return IdProviderInterface -- the id provider clone

    Return a copy of the id provider of the merger, letting the hypothesis
    acces its data and propagate it.
]=]
function WorldHypothesisMerger.copyIdProvider(self : WorldHypothesisMerger)
    return self._idProvider:clone()
end


--[=[
    @within WorldHypothesisMerger
    @function isMarkedForDeletion
    @param entityId number -- the id of the entity that is checked if its
    deleted by the merged changes

    Check if an entity will be deleted by the subWorld when changes will be
    committed
]=]
function WorldHypothesisMerger.isMarkedForDeletion(self : WorldHypothesis, entityId : number)
    for _, markedId in ipairs(self._despawnStorage) do
        if markedId == entityId then
            return true
        end
    end
    return false
end

-- TODO stuff this method with assertions and error messages
--[=[
    @within WorldHypothesisMerger
    @function mergeIn
    @param hypothesisStorage {[number] : entity} -- the storage of the merged
    hypothesis
    @param hypothesisDespawnStorage {number} -- the despawn storage of the merged
    hypothesis
    @param idProvider IdProviderInterface -- the id provider of the merged
    hypothesis

    :::caution:::
    ** Only called by hypothesis:merge()**

    Merge the changes performed in the hypothesis into this merger.
]=]
function WorldHypothesisMerger.mergeIn(self : WorldHypothesisMerger, hypothesisStorage : {[number] : entity},
    hypothesisDespawnStorage : {number}, idProvider : IdProviderInterface)
    -- merge the changes and catch errors (concurrent changes)
    -- update the nextIds and unusedIds

    -- merge in despawns
    for _, despawnedEntityId in ipairs(hypothesisDespawnStorage) do
        if not self:isMarkedForDeletion(despawnedEntityId) then
            table.insert(self._despawnStorage, despawnedEntityId)
        end
    end

    -- merge in spawns, inserts and removes
    for entityId, changeEntity in pairs(hypothesisStorage) do
        -- merge entities : fuse removals, choose between several
        -- versions of a component and fuse insertions

        if self._mergedStorage[entityId] then
            local worldEntity = self._world:get(entityId)
            local mergedEntity = self._mergedStorage[entityId]

            -- if any component had been inserted or removed, then merge the
            -- change
            -- removals :
            for componentName, _ in worldEntity:iterate() do
                if changeEntity[componentName] == nil and mergedEntity[componentName] == nil then
                    mergedEntity[componentName] = nil
                end
            end

            -- insertions :
            for componentName, componentInstance in pairs(changeEntity) do
                -- also checks if the component hadn't been removed by another
                -- merged hypothesis
                if mergedEntity[componentName] == nil and worldEntity[componentName] == nil then
                    mergedEntity[componentName] = componentInstance
                end
            end
        else
            -- just spawn it in the merger
            self._mergedStorage[entityId] = table.clone(hypothesisStorage[entityId])
        end
    end

    -- propagate IdProvider data
    self._idProvider:recycle()
    self._idProvider = idProvider:clone()
end

--[=[
    @within WorldHypothesisMerger
    @function reset

    Reset the merger for an entirely new use in the world.
]=]
function WorldHypothesisMerger.reset(self : WorldHypothesisMerger)
    table.clear(self._mergedStorage)
    table.clear(self._despawnStorage)
    self._idProvider:recycle()
    self._idProvider = self._world:copyIdProvider()
end

--[=[
    @within WorldHypothesisMerger
    @function commit

    Commit the merged changes to the world of the merger, should be followed
    by a reset.
]=]
function WorldHypothesisMerger.commit(self : WorldHypothesisMerger)
    -- :::caution::: merger can commit to an hypothesis
    -- commit despawn after because the risk is to insert or remove to an
    -- already despawned entity
    -- commit archetype modifications and spawns
    for entityId, entity in pairs(self._mergedStorage) do
        if self._world:contains(entityId) then
            -- archetype modification
            local worldEntity = self._world:get(entityId)
            for componentName, componentInstance in worldEntity:iterate() do
                -- same component, no change
                if entity[componentName] == componentInstance then
                    continue
                end

                -- removed component
                if entity[componentName] == nil then
                    self._world:remove(entityId, getmetatable(componentInstance))
                    continue
                end

                -- if entity[componentName] ~= nil
                self._world:insert(entityId, entity[componentName])
            end

            -- check for entirely new components
            for componentName, _ in pairs(entity) do
                if worldEntity[componentName] == nil then
                    self._world:insert(entityId, entity[componentName])
                end
            end
        else
            -- spawn
            self._world:spawnAt(entityId, entityToComponentList(entity))
        end
    end

    -- commit despawns
    for _, despawnEntityId in ipairs(self._despawnStorage) do
        self._world:despawn(despawnEntityId)
    end
end

--[=[
    @within WorldHypothesisMerger
    @function getNextId

    Return the nextId data of the id provider.
]=]
function WorldHypothesisMerger.getNextId(self : WorldHypothesisMerger)
    return self._idProvider:getNextId()
end

--[=[
    @within WorldHypothesisMerger
    @function recycle

    Recycle the merger and throw it in a recycle bin so it can be reused
    by any world.
]=]
function WorldHypothesisMerger.recycle(self : WorldHypothesisMerger)
    if #_recycleBin < MAX_RECYCLE_BIN_SIZE then
        -- clear it
        table.clear(self._mergedStorage)
        table.clear(self._despawnStorage)
        self._idProvider:recycle()
        self._idProvider = nil
        self._world = nil
        _recycleBin[#_recycleBin + 1] = self
    end
end

return WorldHypothesisMerger
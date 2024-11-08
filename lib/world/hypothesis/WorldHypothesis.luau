local WorldHypothesisMerger = require(script.Parent.WorldHypothesisMerger)
local Component = require(script.Parent.Parent.Parent.component.Component)
local EntityMirror = require(script.Parent.Parent.EntityMirror)

local HypothesisWorldInterfaceModule = require(script.Parent.Parent.HypothesisWorldInterface)
local IdProviderInterfaceModule = require(script.Parent.Parent.id_provider.IdProviderInterface)
local WorldTypes = require(script.Parent.Parent.WorldTypes)

-- types
type component = Component.Component
type defaultComponentInstance = WorldTypes.defaultComponentInstance

type entity = WorldTypes.entity

type EntityMirror = EntityMirror.EntityMirror
type HypothesisWorldInterface = HypothesisWorldInterfaceModule.HypothesisWorldInterface
type IdProviderInterface = IdProviderInterfaceModule.IdProviderInterface
type WorldHypothesisMerger = typeof(require(script.Parent.WorldHypothesisMerger).new())

local WorldHypothesis = {}
WorldHypothesis.__index = WorldHypothesis

local _recycleBin : {WorldHypothesis} = {}
local MAX_RECYCLE_BIN_SIZE = 16

export type WorldHypothesisClass = typeof(WorldHypothesis)
export type WorldHypothesis = typeof(WorldHypothesis.new())

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

-- consider typing WorldHypothesis.new(world:getRawWorld())
function WorldHypothesis.new(world : HypothesisWorldInterface, merger : WorldHypothesisMerger)
    -- recycling
    if _recycleBin[1] ~= nil then
        local instance = _recycleBin[#_recycleBin]
        _recycleBin[#_recycleBin] = nil
        instance._world = world
        instance._merger = merger
        instance._additionalStorage = {} :: {[number] : entity}
        instance._despawnStorage = {} :: {number}
        instance._idProvider = merger:copyIdProvider()
        return instance
    end

    return setmetatable({
        _world = world,
        _merger = merger,
        _additionalStorage = {} :: {[number] : entity},
        _despawnStorage = {} :: {number},
        _idProvider = merger:copyIdProvider()
    }, WorldHypothesis)
end

--[=[
    @within WorldHypothesis
    @function reset

    Reset the hypothesis so it can be reused to store other query data.

    This merhod is often called after a hypothesis:merge() as the datas
    would have just been deleted.
]=]
function WorldHypothesis.reset(self : WorldHypothesis)
    table.clear(self._additionalStorage)
    table.clear(self._despawnStorage)
    self._idProvider:recycle()
    self._idProvider = self._merger:copyIdProvider()
end

--[=[
    @within WorldHypothesis
    @function merge

    Merge the changes made in this hypothesis in the merger.
]=]
function WorldHypothesis.merge(self : WorldHypothesis)
    self._merger:mergeIn(
        self._additionalStorage,
        self._despawnStorage,
        self._idProvider
    )
end

--[=[
    @within World
    @function openHypothesis
    @param hypothesis WorldHypothesis -- the hypothesis to place in listener

    Open a new hypothesis on the root world and place it as a listener, it also
    stores the actual listener to reuse it when the nested query is finished.
]=]
function WorldHypothesis.openHypothesis(self : WorldHypothesis, hypothesis : WorldHypothesis)
    return self._world:openHypothesis(hypothesis)
end

--[=[
    @within World
    @function closeHypothesis

    Close the actual hypothesis of the root world and reuse the stored one on
    the top of the stack to finish the nestedQuery.
]=]
function WorldHypothesis.closeHypothesis(self : WorldHypothesis)
    return self._world:closeHypothesis()
end

--[=[
    @within World
    @function resetListenerHypothesis

    Reset the rootWorld listener, it is used when the query iterator function
    needs to reset the listener and merge the changes.
]=]
function WorldHypothesis.resetListenerHypothesis(self : WorldHypothesis)
    return self._world:resetListenerHypothesis()
end

--[=[
    @within WorldHypothesis
    @function getNextId
    @return number

    Return the next id of the hypothesis.
]=]
function WorldHypothesis.getNextId(self : WorldHypothesis)
    return self._idProvider:getNextId()
end

--[=[
    @within WorldHypothesis
    @function copyIdProvider

    Return the a clone of the idProvider of the hypothesis, this method is
    used to propagate id-providing-data to the merger
]=]
function WorldHypothesis.copyIdProvider(self : WorldHypothesis) : IdProviderInterface
    return self._idProvider:clone()
end

--[=[
    @within WorldHypothesis
    @function spawnAt
    @param entityId number -- the id to spawn the entity
    @param componentList {componentInstance} -- a list of component instances to
    give to the entity

    Listener method of world:spawnAt().
]=]
function WorldHypothesis.spawnAt(self : WorldHypothesis, entityId : number, componentList : {defaultComponentInstance})
    assertRightEntityId(entityId)

    -- if the id is in use, then throw
    if self:contains(entityId) then
        error(
            "trying to spawn an entity when there is already one at the " ..
            "provided id, please despawn it before"
        )
    end

    -- create the entity
    local entity = {}
    for _, componentInstance in ipairs(componentList) do
        entity[getmetatable(componentInstance).name] = componentInstance
    end
    self._additionalStorage[entityId] = entity

    self._idProvider:useId(entityId)
end

--[=[
    @within WorldHypothesis
    @function spawn
    @param entityId number -- the id to spawn the entity
    @param componentList {componentInstance} -- a list of component instances to
    give to the entity
    @return number -- the id of the spawned entity

    Listener method for world:spawn()
]=]
function WorldHypothesis.spawn(self : WorldHypothesis, components : {defaultComponentInstance})
    local id = self._idProvider:useNextId()
    self:spawnAt(id, components)
    return id
end

--[=[
    @within WorldHypothesis
    @function isMarkedForDeletion
    @param entityId number -- the id of the entity that is checked if its
    deleted by the hypothesis

    Check if an entity will be deleted by the hypothesis when changes will be committed
]=]
function WorldHypothesis.isMarkedForDeletion(self : WorldHypothesis, entityId : number)
    for _, markedId in ipairs(self._despawnStorage) do
        if markedId == entityId then
            return true
        end
    end
    return false
end

--[=[
    @within WorldHypothesis
    @function despawn
    @param entityId number -- the id of the entity to despawn

    Listener method for world:despawn().
]=]
function WorldHypothesis.despawn(self : WorldHypothesis, entityId : number)
    assert(
        self:contains(entityId),
        "the entity you want to despawn does not exist."
    )
    local entity = self._additionalStorage[entityId]

    if entity ~= nil then -- if the entity is located in the hypothesis
        -- then just delete it
        self._additionalStorage[entityId] = nil
    else -- if its located in the world
        -- then mark it for deletion
        -- we already know that it isn't already marked thanks to the
        -- assertion at the beginning of the method.
        table.insert(self._despawnStorage, entityId)
    end

    self._idProvider:unuseId(entityId)
end

--[=[
    @within WorldHypothesis
    @function get
    @param entityId number -- the id of the entity to get
    @return EntityMirror -- the mirror of the entity

    Listener method of world:get()
]=]
function WorldHypothesis.get(self : WorldHypothesis, entityId : number)
    if self._additionalStorage[entityId] ~= nil then
        -- return a mirror with the WorldHypothesis as a proxy of the world
        return EntityMirror.new(self, entityId, self._additionalStorage[entityId])
    elseif self._world:contains(entityId) then
        local entityMirror = self._world:get(entityId)
        entityMirror.world = self
        return entityMirror
    end
    return nil
end

--[=[
    @within WorldHypothesis
    @function contains
    @param entityId number -- the id where to check if there is an entity
    @return boolean

    Listener method for world:contains().
]=]
function WorldHypothesis.contains(self : WorldHypothesis, entityId : number)
    if self._additionalStorage[entityId] ~= nil then
        -- if the entity id in the hypothese
        return true
    elseif self._world:contains(entityId) and not self:isMarkedForDeletion(entityId) then
        -- if the entity is in the world and not marked for deletion by the hypothese
        return true
    end
    return false
end

--[=[
    @within WorldHypothesis
    @function _shadowWorldEntity
    @param entityId number -- the id where to check if there is an entity

    Spawn an entity in the Hypothesis storage that will shadow the one at this
    id in the subWorld when calling get or contains.
]=]
function WorldHypothesis._shadowWorldEntity(self : WorldHypothesis, entityId : number)
    -- shadow a world entity by copying it in the hypothetic storage
    local mirror = self:get(entityId)
    local entity = {}
    -- selene: allow(manual_table_clone)
    -- selene does not understand that :iterate returns a pairs result
    for componentName, componentInstance in mirror:iterate() do
        entity[componentName] = componentInstance
    end
    self._additionalStorage[entityId] = entity
end

--[=[
    @within WorldHypothesis
    @function insert
    @param entityId number -- the id of the entity to in which the component is
    inserted
    @param component componentInstance -- the component to insert

    Listener method of world:insert().
]=]
function WorldHypothesis.insert(self : WorldHypothesis, entityId : number, component : defaultComponentInstance)
    -- assert if the entity exist
    assert(
        self:contains(entityId),
        string.format(
            "Error while inserting the component :\n    - %s\n" ..
            "in a non-existant entity at \n    - #%i",
            getmetatable(component).name,
            entityId
        )
    )

    if self._additionalStorage[entityId] == nil then
        self:_shadowWorldEntity(entityId)
    end

    self._additionalStorage[entityId][getmetatable(component).name] = component
end

--[=[
    @within WorldHypothesis
    @function remove
    @param entityId number -- the id of the entity from which the component is
    removed
    @param componentType componentType -- the component to remove

    Listerner method of world:remove()
]=]
function WorldHypothesis.remove(self : WorldHypothesis, entityId : number, componentType : component)
    assert(
        self:contains(entityId) and self:getComponent(entityId, componentType) ~= nil,
        string.format(
            "Error while removing the component :\n    - %s\n" ..
            "for the entity entity at \n    - #%i\n" ..
            "The component isn't present in the entity.",
            componentType.name,
            entityId
        )
    )

    -- execute the removal
    if self._additionalStorage[entityId] == nil then
        self:_shadowWorldEntity(entityId)
    end
    self._additionalStorage[entityId][componentType.name] = nil
end

--[=[
    @within WorldHypothesis
    @function getComponent
    @param entityId number -- the id of the entity to get the component from
    @param componentType component -- the type of the component to get
    @return componentInstance -- the componet to get

    Listener method of world:getComponent().
]=]
function WorldHypothesis.getComponent(self : WorldHypothesis, entityId : number, componentType : component)
    if self._additionalStorage[entityId] then
        return self._additionalStorage[entityId][componentType.name]
    end
    return self._world:getComponent(entityId, componentType)
end

-- check if the id provided by the world:query is still valid in the
-- modifications of the hypothesis
function WorldHypothesis._nextWorldValidId(self : WorldHypothesis, index, subWorldEntityIterator, archetype)
    local nextEntityId = subWorldEntityIterator[index]

    -- if we reached the end of the iteration
    if nextEntityId == nil then
        return nil
    end

    -- entity despawned by the hypothesis
    if self._additionalStorage[nextEntityId] == nil and self:isMarkedForDeletion(nextEntityId) then
        return self:_nextWorldValidId(index + 1, subWorldEntityIterator, archetype)
    end

    -- archetype still valid as it isn't changed in the hypothesis
    -- and not despawned by the hypothesis
    if self._additionalStorage[nextEntityId] == nil then
        return index
    end

    -- entity is modified by the hypothesis and does not contain the
    -- archetype anymore
    if not entityContains(self._additionalStorage[nextEntityId], archetype) then
        return self:_nextWorldValidId(index + 1, subWorldEntityIterator, archetype)
    end

    -- modified by the hypothesis but archetype not altered
    return index
end

--[=[
    @within WorldHypothesis
    @function _factoryEveryIdHypothesisQuerier
    @param archetype {component} -- the archetype provided for query
    @return () -> number -- the iterator function

    Return an iterator function for the provided archetype. This method also
    manage hypothesis and mergers of the query.
]=]
function WorldHypothesis._factoryEveryIdHypothesisQuerier(self : WorldHypothesis, archetype)
    local subWorldEntityIterator = self._world:getQueryIterator(archetype)
    local hypothesisEntityIterator = self:_getAdditionalQueryIterator(archetype)
    -- allow query in query by recursive hypothesises
    local newMerger = WorldHypothesisMerger.new(self)
    local newHypothesis = WorldHypothesis.new(self, newMerger)
    self:openHypothesis(newHypothesis)

    local subWorldIndex = 0
    local hypothesisIndex = 0
    local iteratingOverSubWorld = true
    return function()
        -- at the beginning of the function as this is called right after an
        -- iteration and the loop operations
        if subWorldIndex or 0 >= 1 then
            -- merge the modifications and clear the hypothesis so it is
            -- reusable
            self:resetListenerHypothesis()
        end

        -- the actual iteration*
        local entityId

        -- iterate over the subWorld (an hypothesis in the case of a nested query)
        if iteratingOverSubWorld then
            subWorldIndex += 1
            subWorldIndex = self:_nextWorldValidId(subWorldIndex, subWorldEntityIterator, archetype)
            if subWorldIndex == nil then
                iteratingOverSubWorld = false
            else
                entityId = subWorldEntityIterator[subWorldIndex]
            end
        end

        -- iterate over the hypothesis (the entity with the archetype changed
        -- into the query archetype or simply spawned with the concerned
        -- archetype)
        if not iteratingOverSubWorld then
            hypothesisIndex += 1
            entityId = hypothesisEntityIterator[hypothesisIndex]
        end

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

--[=[
    @within WorldHypothesis
    @function _factoryEveryIdHypothesisQuerier
    @param archetype {component}? -- the archetype provided for query
    @return () -> number -- the iterator function

    Return an iterator function for the provided archetype in the additional
    storage of this hypothesis only.
]=]
function WorldHypothesis._getAdditionalQueryIterator(self : WorldHypothesis, archetype : {component}?)
    local queryIterator = {}
    for entityId, entity in pairs(self._additionalStorage) do
        if archetype == nil or entityContains(entity, archetype) then
            table.insert(queryIterator, entityId)
        end
    end
    return queryIterator
end

--[=[
    @within WorldHypothesis
    @function _factoryEveryIdHypothesisQuerier
    @param archetype : {component} -- the archetype provided
    @return () -> number -- the iterator function

    Return an iterator function for the provided archetype in all the
    subWorlds and the additional storage of the hypothesis
]=]
function WorldHypothesis.getQueryIterator(self : WorldHypothesis, archetype : {component}?)
    local queryIterator = self._world:getQueryIterator(archetype)
    local additionnalQueryIterator = self:_getAdditionalQueryIterator(archetype)
    local listEnd = #queryIterator
    local additionalListEnd = #additionnalQueryIterator
    local nextAdditionalId = 1

    -- check if the id is still valid with hypothesis modifications and nil it
    for index, id in ipairs(queryIterator) do
        if (
            -- if it is still valid in the modifications given by the
            -- hypothesis
            self._additionalStorage[id] ~= nil 
            and
            not entityContains(self._additionalStorage[id], archetype)
        )
        -- or if it is just deleted by the hypothesis
        or
        self:isMarkedForDeletion(id)
        then
            queryIterator[index] = additionnalQueryIterator[nextAdditionalId]
            nextAdditionalId += 1
        end
    end

    -- find the actual end of the list
    for i = listEnd, 1, -1 do
        if queryIterator[i] == nil then
            listEnd = i
        else
            break
        end
    end

    -- ensure that the first element is not nil as it would break the next
    -- alogrithm
    if queryIterator[1] == nil then
        queryIterator[1] = queryIterator[listEnd]
        queryIterator[listEnd] = nil
        listEnd -= 1
    end

    -- fill the holes in the list
    for index, _ in ipairs(queryIterator) do
        local nextValue = queryIterator[index + 1]
        if nextValue == nil then
            -- if there is still additional entity, then replace the entity
            -- with the additional
            if nextAdditionalId <= additionalListEnd then
                queryIterator[index + 1] = additionnalQueryIterator[nextAdditionalId]
                nextAdditionalId += 1
                continue
            end

            -- else, move the last element to this position
            queryIterator[index + 1] = queryIterator[listEnd]
            queryIterator[listEnd] = nil
            listEnd -= 1
        end
    end

    -- finish adding the additional changes from the hypothesis
    while nextAdditionalId <= additionalListEnd do
        queryIterator[listEnd + 1] = additionnalQueryIterator[nextAdditionalId]
        nextAdditionalId += 1
        listEnd += 1
    end

    return queryIterator
end

--[=[
    @within WorldHypothesis
    @function _factoryEveryIdHypothesisQuerier
    @param ... ...component -- the archetype provided
    @return () -> number -- the iterator function

    Listener method of world:query()
]=]
function WorldHypothesis.query(self : WorldHypothesis, ... : component)
    local archetype = {...}

    -- this should fire a nested query in world and change the
    -- _listenerHypothesis by calling the openHypothesis method
    -- The new Hypothesis should have this one as its _world.
    return self:_factoryEveryIdHypothesisQuerier(archetype)
end

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
    @within WorldHypothesis
    @function _factoryEveryIdHypothesisQuerier
    @param ... ...component -- the archetype provided
    @return () -> number -- the iterator function

    Listener method of world:readQuery()
]=]
function WorldHypothesis.readQuery(self : WorldHypothesis, ... : component)
    return valueReturningIpairs(self:getQueryIterator({...}))
end

--[=[
    @within WorldHypothesis
    @function recycle

    Clear the hypothesis and store it in the recycle bin so it is reusable
    and not subject to memory leaks (as an hypoothesis is created at each
    query iteration)
]=]
function WorldHypothesis.recycle(self : WorldHypothesis)
    if #_recycleBin < MAX_RECYCLE_BIN_SIZE then
        -- clear it
        table.clear(self._additionalStorage)
        table.clear(self._despawnStorage)
        self._idProvider:recycle()
        self._idProvider = nil
        self._merger = nil
        self._world = nil
        _recycleBin[#_recycleBin + 1] = self
    end
end

--[=[
    @within WorldHypothesis
    @function breakQuery

    Merge itself and make the merger commit, it should be called when
    the client is breaking out of a query.
]=]
function WorldHypothesis.breakQuery(self : WorldHypothesis)
    -- merge and commit the changes
    self:merge()
    self._merger:commit()
    -- close this hypothesis as we break out of the query
    self:closeHypothesis()
    -- recycle everything
    self._merger:recycle()
    self:recycle()
end

return WorldHypothesis
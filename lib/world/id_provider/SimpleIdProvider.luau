--[=[
    @class SimpleIdProvider

    Provide an id to a descendant of HypothesisWorldInterface (world or hypothesis)
]=]
local SimpleIdProvider = {}
SimpleIdProvider.__index = SimpleIdProvider

export type SimpleIdProviderClass = typeof(SimpleIdProvider)
export type SimpleIdProvider = typeof(SimpleIdProvider.new())

local _recycleBin : {SimpleIdProvider} = {}
local MAX_RECYCLE_BIN_SIZE = 16

function SimpleIdProvider.new()
    -- recycling
    if _recycleBin[1] ~= nil then
        local instance = _recycleBin[#_recycleBin]
        _recycleBin[#_recycleBin] = nil
        instance._nextId = 1
        return instance
    end

    return setmetatable({
        _nextId = 1,
        _unusedIds = {}
    }, SimpleIdProvider)
end

--[=[
    @within SimpleIdProvider
    @function clone
    @return SimpleIdProvider

    Return a clone of the id provider and all its data, this method is used to
    propagate id data among hypothesises and mergers.
]=]
function SimpleIdProvider.clone(self : SimpleIdProvider)
    local clone = SimpleIdProvider.new()
    clone._nextId = self._nextId
    clone._unusedIds = self._unusedIds
    return clone
end

--[=[
    @within SimpleIdProvider
    @function getNextId
    @return number

    Return the nextId of the id provider.
]=]
function SimpleIdProvider.getNextId(self : SimpleIdProvider)
    return self._nextId
end

--[=[
    @within SimpleIdProvider
    @function setNextId
    @param id number -- the new next id

    Change the next id of the id provider.
]=]
function SimpleIdProvider.setNextId(self : SimpleIdProvider, id : number)
    if id > self._nextId then
        for i = self._nextId, id - 1, 1 do
            table.insert(self._unusedIds, i)
        end
        self._nextId = id
    elseif id < self._nextId then
        -- 2 times removing as removing things from a table while iterating
        -- over causes bugs
        local newUnusedIds = {}
        for key, unusedId in ipairs(self._unusedIds) do
            if id > unusedId then
                newUnusedIds[key] = unusedId
            end
        end
        self._unusedIds = newUnusedIds

        self._nextId = id
    end
end

--[=[
    @within SimpleIdProvider
    @function useId
    @param id number -- the id to use

    Make the id provider mark an is as used (not in the unusedIds and under
    the nextId).
]=]
function SimpleIdProvider.useId(self : SimpleIdProvider, id : number)
    self:setNextId(id + 1)
    -- if the entityId was unused then remove it from _unusedIds
    for index, unusedId in ipairs(self._unusedIds) do
        if id == unusedId then
            table.remove(self._unusedIds, index)
            return
        end
    end
end

--[=[
    @within SimpleIdProvider
    @function useNextId
    @return number -- the id to use

    Return the nextId to use, it can be an unsedId or the nextId.
]=]
function SimpleIdProvider.useNextId(self : SimpleIdProvider)
    local id
    if self._unusedIds[1] ~= nil then
        id = self._unusedIds[#self._unusedIds]
        table.remove(self._unusedIds, #self._unusedIds)
    else
        id = self._nextId
        self._nextId += 1
    end
    return id
end

--[=[
    @within SimpleIdProvider
    @function unuseId

    Mark an id as unused.
]=]
function SimpleIdProvider.unuseId(self : SimpleIdProvider, id : number)
    -- the unusedId should never be above or equal to the _nextId.
    -- if the despawned entity was just under the _nextId, then decrease the
    -- _nextId to this value
    if self._nextId == id + 1 then
        self._nextId -= 1
    else
        table.insert(self._unusedIds, id)
    end
end

--[=[
    @within SimpleIdProvider
    @function recycle

    Recycle the id provider (clear it and store it for a later use).
]=]
function SimpleIdProvider.recycle(self : SimpleIdProvider)
    if #_recycleBin < MAX_RECYCLE_BIN_SIZE then
        -- clear it
        self._nextId = nil
        table.clear(self._unusedIds)
        _recycleBin[#_recycleBin + 1] = self
    end
end

return SimpleIdProvider
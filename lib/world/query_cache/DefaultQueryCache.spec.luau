--TODO to entirely recode

local Component = require(script.Parent.Parent.Parent.component.Component)
local DefaultQueryCache = require(script.Parent.DefaultQueryCache)

local function tContains(t, v)
    for _, v1 in pairs(t) do
        if v1 == v then
            return true
        end
    end
    return false
end

-- check if the two table contain the same values, not any more or less
local function tContainStrictSameValue(t1, t2)
    for _, v1 in ipairs(t1) do
        local ok = false
        for _, v2 in ipairs(t2) do
            if v1 == v2 then
                ok = true
                break
            end
        end

        if not ok then
            return false
        end
    end
    for _, v2 in ipairs(t2) do
        local ok = false
        for _, v1 in ipairs(t1) do
            if v1 == v2 then
                ok = true
                break
            end
        end

        if not ok then
            return false
        end
    end
    return true
end

return function ()
    local queryCache : DefaultQueryCache.DefaultQueryCache
    local someEntities = {4, 6, 9}
    local someOtherEntities = {3, 4, 6, 9, 18}

    local SOME_COMPONENT = Component.new("some")
    local OTHER_COMPONENT = Component.new("other")
    local YET_ANOTHER_COMPONENT = Component.new("yet_another")

    beforeEach(function()
        queryCache = DefaultQueryCache.new()
    end)

    describe("DefaultQueryCache", function()
        it("should cache a specific archetype", function()
            -- single component archetype
            queryCache:cacheArchetype({SOME_COMPONENT}, someEntities)

            -- check if it returned the correct table
            expect(tContainStrictSameValue(someEntities, queryCache:getCached({SOME_COMPONENT}))).to.be.equal(true)
        end)
        it("should remove an entity from the storage if its new archetype does not match the cached archetype anymore (removal)", function()
            -- single component archetype
            queryCache:cacheArchetype({SOME_COMPONENT}, someEntities)
            queryCache:notifyCacheEntityComponentRemoved(6, {SOME_COMPONENT}, SOME_COMPONENT)

            expect(tContains(queryCache:getCached({SOME_COMPONENT}), 6)).to.be.equal(false)

            -- multiple component archetype
            queryCache:cacheArchetype({SOME_COMPONENT, OTHER_COMPONENT}, someOtherEntities)
            queryCache:notifyCacheEntityComponentRemoved(9, {SOME_COMPONENT, OTHER_COMPONENT}, OTHER_COMPONENT)

            expect(tContains(queryCache:getCached({SOME_COMPONENT, OTHER_COMPONENT}), 9)).to.be.equal(false)
        end)
        it("should add an entity to the storage if its new archetype matches the component (insertion)", function()
            -- single component archetype
            queryCache:cacheArchetype({SOME_COMPONENT}, someEntities)
            queryCache:notifyCacheEntityComponentInserted(7, {SOME_COMPONENT}, SOME_COMPONENT)

            expect(tContains(queryCache:getCached({SOME_COMPONENT}), 7)).to.be.equal(true)

            -- multiple component archetype
            queryCache:cacheArchetype({SOME_COMPONENT, OTHER_COMPONENT}, someOtherEntities)
            queryCache:notifyCacheEntityComponentInserted(8, {SOME_COMPONENT, OTHER_COMPONENT}, OTHER_COMPONENT)

            expect(tContains(queryCache:getCached({SOME_COMPONENT, OTHER_COMPONENT}), 8)).to.be.equal(true)
        end)
        it("should add a spawned entity that match an archetype", function()
            -- single component archetype
            queryCache:cacheArchetype({SOME_COMPONENT}, someEntities)
            queryCache:cacheArchetype({SOME_COMPONENT, OTHER_COMPONENT}, someOtherEntities)
            queryCache:notifyCacheSpawnedEntity(7, {SOME_COMPONENT()})

            expect(tContains(queryCache:getCached({SOME_COMPONENT}), 7)).to.be.equal(true)
            expect(tContains(queryCache:getCached({SOME_COMPONENT, OTHER_COMPONENT}), 7)).to.be.equal(false)

            -- multiple component archetype
            queryCache:notifyCacheSpawnedEntity(8, {SOME_COMPONENT(), OTHER_COMPONENT(), YET_ANOTHER_COMPONENT()})

            expect(tContains(queryCache:getCached({SOME_COMPONENT}), 8)).to.be.equal(true)
            expect(tContains(queryCache:getCached({SOME_COMPONENT, OTHER_COMPONENT}), 8)).to.be.equal(true)
        end)
        it("should remove a despawned entity from the cache", function()
            local entity = {SOME_COMPONENT(), OTHER_COMPONENT()}

            queryCache:cacheArchetype({SOME_COMPONENT}, someEntities)
            queryCache:cacheArchetype({SOME_COMPONENT, OTHER_COMPONENT}, someOtherEntities)
            queryCache:notifyCacheSpawnedEntity(7, entity)

            expect(tContains(queryCache:getCached({SOME_COMPONENT}), 7)).to.be.equal(true)
            expect(tContains(queryCache:getCached({SOME_COMPONENT, OTHER_COMPONENT}), 7)).to.be.equal(true)

            queryCache:notifyCacheDespawnedEntity(7, entity)

            expect(tContains(queryCache:getCached({SOME_COMPONENT}), 7)).to.be.equal(false)
            expect(tContains(queryCache:getCached({SOME_COMPONENT, OTHER_COMPONENT}), 7)).to.be.equal(false)
        end)
        it("should uncache archetype", function()
            queryCache:cacheArchetype({SOME_COMPONENT}, someEntities)
            queryCache:cacheArchetype({SOME_COMPONENT, OTHER_COMPONENT}, someOtherEntities)

            expect(queryCache:isCached({SOME_COMPONENT, OTHER_COMPONENT})).to.be.equal(true)
            expect(queryCache:isCached({SOME_COMPONENT})).to.be.equal(true)

            queryCache:uncacheArchetype({SOME_COMPONENT})

            expect(queryCache:isCached({SOME_COMPONENT, OTHER_COMPONENT})).to.be.equal(true)
            expect(queryCache:isCached({SOME_COMPONENT})).to.be.equal(false)
        end)
        it("should uncache the archetypes that didn't got red during the lifecycle", function()
            queryCache = DefaultQueryCache.new(5)

            queryCache:cacheArchetype({SOME_COMPONENT}, someEntities)
            queryCache:cacheArchetype({SOME_COMPONENT, OTHER_COMPONENT}, someOtherEntities)

            queryCache:lifecycleCache()
            queryCache:getCached({SOME_COMPONENT})
            queryCache:lifecycleCache()

            expect(queryCache:getCached({SOME_COMPONENT})).to.be.ok()
            expect(queryCache:getCached({SOME_COMPONENT, OTHER_COMPONENT})).never.to.be.ok()
        end)
        it("should return an iterable table containing all the cached entity's ids for an archetype", function()
            queryCache:cacheArchetype({SOME_COMPONENT}, someEntities)

            for _, entityId in ipairs(queryCache:getCached({SOME_COMPONENT})) do
                expect(tContains(someEntities, entityId)).to.be.equal(true)
            end
        end)
        it("should check wether if an archetype is cached or not", function()
            queryCache:cacheArchetype({SOME_COMPONENT}, someEntities)
            queryCache:cacheArchetype({SOME_COMPONENT, OTHER_COMPONENT}, someOtherEntities)

            expect(queryCache:isCached({SOME_COMPONENT})).to.be.equal(true)
            expect(queryCache:isCached({SOME_COMPONENT, OTHER_COMPONENT})).to.be.equal(true)
            expect(queryCache:isCached({SOME_COMPONENT, YET_ANOTHER_COMPONENT})).to.be.equal(false)
        end)
        it("shouldn't read anything when chacking if an archetype is cached (:isCached)", function()
            queryCache:cacheArchetype({SOME_COMPONENT}, someEntities)
            queryCache:cacheArchetype({SOME_COMPONENT, OTHER_COMPONENT}, someOtherEntities)

            expect(queryCache:isCached({SOME_COMPONENT})).to.be.equal(true)
            expect(queryCache:isCached({SOME_COMPONENT, OTHER_COMPONENT})).to.be.equal(true)

            queryCache:lifecycleCache()
            queryCache:lifecycleCache()

            expect(queryCache:isCached({SOME_COMPONENT})).to.be.equal(false)
            expect(queryCache:isCached({SOME_COMPONENT, OTHER_COMPONENT})).to.be.equal(false)
        end)
        it("should clear itself", function()
            queryCache:cacheArchetype({SOME_COMPONENT}, someEntities)
            queryCache:cacheArchetype({SOME_COMPONENT, OTHER_COMPONENT}, someOtherEntities)

            queryCache:clearCache()

            expect(queryCache:isCached({SOME_COMPONENT})).to.be.equal(false)
            expect(queryCache:isCached({SOME_COMPONENT, OTHER_COMPONENT})).to.be.equal(false)
        end)
    end)
end
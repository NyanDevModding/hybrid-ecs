local WorldFactory  = require(script.Parent.WorldFactory)
local Component = require(script.Parent.Parent.component.Component)
local RegisteredComponent = require(script.Parent.Parent.component.RegisteredComponent)
local DefaultQueryCache = require(script.Parent.query_cache.DefaultQueryCache)

local TestComponent = Component:extend()
do
    TestComponent.__index = TestComponent

    function TestComponent.new(v)
        return setmetatable({
            value = v
        }, TestComponent)
    end
end

-- some tests access to the private storage of the world. This is because we
-- need to check that everything is working in there as intended.
return function ()
    local SOME_COMPONENT = RegisteredComponent.new("some", function(v)
        return TestComponent.new(v)
    end)
    local OTHER_COMPONENT = RegisteredComponent.new("other", function(v)
        return TestComponent.new(v)
    end)

    local testWorld
    beforeEach(function()
        testWorld = WorldFactory.createWorld(nil, false)
    end)

    describe("World", function()
        describe("id handling", function()
            -- mainly managed by id provider
            it("should increase over spawns", function()
                expect(testWorld:getNextId()).to.be.equal(1)
                testWorld:spawn({
                    some = SOME_COMPONENT:build()
                })
                expect(testWorld:getNextId()).to.be.equal(2)
            end)
            it("should decrease the nextId by 1 when the id just under it is removed", function()
                testWorld:spawn({
                    some = SOME_COMPONENT:build()
                })
                testWorld:spawn({
                    some = SOME_COMPONENT:build()
                })

                expect(testWorld:getNextId()).to.be.equal(3)

                testWorld:despawn(2)

                expect(testWorld:getNextId()).to.be.equal(2)
            end)
            it("should move the nextId just on top of the new id if it is greater then the latter", function()
                testWorld:spawnAt(58, {
                    some = SOME_COMPONENT:build()
                })

                expect(testWorld:getNextId()).to.be.equal(59)
            end)
            it("should unuse the id on despawn", function()
                testWorld:spawn({
                    some = SOME_COMPONENT:build()
                })
                testWorld:spawn({
                    some = SOME_COMPONENT:build()
                })

                expect(testWorld:getNextId()).to.be.equal(3)

                testWorld:despawn(1)

                expect(testWorld:getNextId()).to.be.equal(3)

                local newId = testWorld:spawn({
                    some = SOME_COMPONENT:build()
                })

                expect(newId).to.be.equal(1)
            end)
            describe("on chunk removing", function()
                it("should remove all the unusedIds greater then the last id", function()
                    testWorld:spawn({
                        some = SOME_COMPONENT:build()
                    })
                    testWorld:spawn({
                        some = SOME_COMPONENT:build()
                    })
                    testWorld:spawn({
                        some = SOME_COMPONENT:build()
                    })
                    testWorld:spawnAt(170, {
                        some = SOME_COMPONENT:build()
                    })
                    testWorld:despawn(2)
                    testWorld:despawn(3)

                    testWorld:despawn(170)

                    -- actual storage-private spec, wouldn't happen if I had
                    -- coded an composition based storage system.
                    expect(testWorld:getRawWorld()._storage[3]).never.to.be.ok()

                    local newId = testWorld:spawn({
                        some = SOME_COMPONENT:build()
                    })
                    expect(newId).to.be.equal(2)
                end)
                it("should move the _nextId just on top of the lastId", function()
                    testWorld:spawnAt(58, {
                        some = SOME_COMPONENT:build()
                    })
                    testWorld:spawnAt(170, {
                        some = SOME_COMPONENT:build()
                    })
                    testWorld:despawn(170)

                    expect(testWorld:getNextId()).to.be.equal(59)
                end)
                it("should not do anything if it is not the last chunk", function()
                    testWorld:spawnAt(58, {
                        some = SOME_COMPONENT:build()
                    })
                    testWorld:spawnAt(170, {
                        some = SOME_COMPONENT:build()
                    })
                    -- this one is created to check if the method had not be
                    -- called, as expected
                    testWorld:spawnAt(190, {
                        some = SOME_COMPONENT:build()
                    })
                    -- these shouldn't modify unusedIds
                    testWorld:despawn(190)
                    testWorld:despawn(58)

                    -- expecting it to not move as it shall be changed only by
                    -- the removing of a chunk and not by the despawning of
                    -- another entity inside the same chunk or the removing of
                    -- another chunk, elsewhere
                    -- the only thing to do is - 1 (191 -> 190) as the _nextId
                    -- is modified by the despawn method when the despawned
                    -- entity's id is just under the _nextId
                    expect(testWorld:getNextId()).to.be.equal(190)
                end)
            end)
        end)
        describe("entity handling", function()
            it("should throw when searching a component in a non existent entity", function()
                expect(function()
                    testWorld:getComponent(1, SOME_COMPONENT)
                end).to.throw()
            end)
            it("should check if the world contains an entity", function()
                testWorld:spawnAt(1, {
                    some = SOME_COMPONENT:build()
                })

                expect(testWorld:contains(1)).to.be.equal(true)
            end)
            describe("spawning", function()
                it("should spawn the entity in the right chunk", function()
                    -- expected to be the 1st of the 1st chunk
                    testWorld:spawnAt(1, {
                        some = SOME_COMPONENT:build()
                    })

                    -- expected to be the 64th of the 1st chunk
                    testWorld:spawnAt(64, {
                        some = SOME_COMPONENT:build()
                    })

                    -- expected to be the 1st of the 2nd chunk
                    testWorld:spawnAt(65, {
                        some = SOME_COMPONENT:build()
                    })

                    -- expected to be the 64th of the 15th chunk
                    testWorld:spawnAt(1024, {
                        some = SOME_COMPONENT:build()
                    })

                    -- expected to be the 42nd of the 2nd chunk
                    testWorld:spawnAt(170, {
                        some = SOME_COMPONENT:build()
                    })

                    local storage = testWorld:getRawWorld()._storage

                    expect(storage[1]).to.be.ok()
                    expect(storage[2]).to.be.ok()
                    expect(storage[16]).to.be.ok()
                    expect(storage[3]).to.be.ok()

                    expect(storage[1][1]).to.be.ok()
                    expect(storage[1][64]).to.be.ok()
                    expect(storage[2][1]).to.be.ok()
                    expect(storage[16][64]).to.be.ok()
                    expect(storage[3][42]).to.be.ok()
                end)
                it("should store a reference to each given componentInstance", function()
                    local component = SOME_COMPONENT:build("data")

                    testWorld:spawnAt(1, {
                        some = component
                    })

                    expect(testWorld:getComponent(1, SOME_COMPONENT:getName())).to.be.equal(component)
                end)
                it("should take an unused id if there is one", function()
                    testWorld:spawnAt(1, {
                        some = SOME_COMPONENT:build()
                    })

                    testWorld:spawnAt(2, {
                        some = SOME_COMPONENT:build()
                    })

                    testWorld:despawn(1)

                    local newEntityId = testWorld:spawn({
                        some = SOME_COMPONENT:build()
                    })

                    expect(newEntityId).to.be.equal(1)
                end)
                it("should throw if the provided entityId isn't valid", function()
                    expect(function()
                        testWorld:spawnAt(-5, OTHER_COMPONENT)
                    end).to.throw()

                    expect(function()
                        testWorld:spawnAt(0, OTHER_COMPONENT)
                    end).to.throw()

                    expect(function()
                        testWorld:spawnAt(55.5, OTHER_COMPONENT)
                    end).to.throw()
                end)
            end)
            describe("despawning", function()
                it("should remove the entity", function()
                    testWorld:spawnAt(1, {
                        some = SOME_COMPONENT:build()
                    })

                    expect(function()
                        testWorld:despawn(1)
                    end).never.to.throw()

                    expect(testWorld:contains(1)).to.be.equal(false)
                end)
                it("should remove the chunk if it's empty", function()
                    testWorld:spawnAt(1, {
                        some = SOME_COMPONENT:build()
                    })

                    testWorld:despawn(1)

                    expect(testWorld:getRawWorld()._storage[1]).never.to.be.ok()
                end)
                it("should throw if the chunk does not exists", function()
                    testWorld:spawnAt(65, {
                        some = SOME_COMPONENT:build()
                    })

                    expect(function()
                        testWorld:despawn(1)
                    end).to.throw()
                end)
                it("should throw if the entity does not exist", function()
                    testWorld:spawnAt(1, {
                        some = SOME_COMPONENT:build()
                    })

                    expect(function()
                        testWorld:despawn(2)
                    end).to.throw()
                end)
            end)
            describe("inserting", function()
                it("should insert component in entity", function()
                    testWorld:spawnAt(1, {
                        some = SOME_COMPONENT:build()
                    })

                    expect(function()
                        testWorld:insert(1, OTHER_COMPONENT:getName(), OTHER_COMPONENT:build())
                    end).never.to.throw()

                    expect(testWorld:get(1).other).to.be.ok()
                end)
                it("should replace the component if it is already present", function()
                    testWorld:spawnAt(1, {
                        some = SOME_COMPONENT:build()
                    })
                    local replacing = SOME_COMPONENT:build()

                    expect(function()
                        testWorld:insert(1, SOME_COMPONENT:getName(), replacing)
                    end).never.to.throw()

                    expect(testWorld:getComponent(1, SOME_COMPONENT:getName())).to.be.equal(replacing)
                end)
            end)
            describe("removing", function()
                it("should remove a component from an entity", function()
                    testWorld:spawnAt(1, {
                        some = SOME_COMPONENT:build()
                    })

                    expect(function()
                        testWorld:remove(1, SOME_COMPONENT:getName())
                    end).never.to.throw()

                    expect(testWorld:getComponent(1, SOME_COMPONENT:getName())).never.to.be.ok()
                end)
                it("should throw if the client is trying to remove an entity that isn't present", function()
                    testWorld:spawnAt(1, {
                        some = SOME_COMPONENT:build()
                    })

                    expect(function()
                        testWorld:remove(1, OTHER_COMPONENT)
                    end).to.throw()
                end)
            end)
        end)
        describe("querying", function()
            it("should return only the id of each entity", function()
                testWorld:spawnAt(1, {
                    some = SOME_COMPONENT:build()
                })

                for _, shouldBeNil in testWorld:query() do
                    expect(shouldBeNil).never.to.be.ok()
                end
            end)
            it("should iterate over present entities", function()
                for i = 1, 5, 1 do
                    testWorld:spawnAt(i, {
                        some = SOME_COMPONENT:build()
                    })
                end
                
                for entityId in testWorld:query() do
                    expect(entityId).to.be.ok()
                end
            end)
            it("should query over all entities when no archetype is provided", function()
                for _ = 1, 10, 1 do
                    testWorld:spawn({
                        some = SOME_COMPONENT:build()
                    })
                end

                print(testWorld:getRawWorld()._storage[1])

                local entityAmount = 0
                for _ in testWorld:query() do
                    entityAmount += 1
                end

                expect(entityAmount).to.be.equal(10)
            end)
            it("should perform a query over the entities of the same component", function()
                local YET_ANOTHER_COMPONENT = RegisteredComponent.new("yet_another", function(v)
                    return TestComponent.new(v)
                end)

                for _ = 1, 5, 1 do
                    testWorld:spawn({
                        some = SOME_COMPONENT:build()
                    })
                    testWorld:spawn({
                        some = SOME_COMPONENT:build(),
                        other = OTHER_COMPONENT:build()
                    })
                end

                -- single component check
                local someEntityAmount = 0
                for entityId in testWorld:query(SOME_COMPONENT) do
                    expect(testWorld:getComponent(entityId, SOME_COMPONENT:getName())).to.be.ok()
                    someEntityAmount += 1
                end
                expect(someEntityAmount).to.be.equal(10)

                -- double components check
                local someAndOtherEntityAmount = 0
                for entityId in testWorld:query(SOME_COMPONENT, OTHER_COMPONENT) do
                    expect(testWorld:getComponent(entityId, SOME_COMPONENT:getName())).to.be.ok()
                    expect(testWorld:getComponent(entityId, OTHER_COMPONENT:getName())).to.be.ok()
                    someAndOtherEntityAmount += 1
                end
                expect(someAndOtherEntityAmount).to.be.equal(5)

                -- absent component check
                local yetAnotherEntityAmount = 0
                for _ in testWorld:query(YET_ANOTHER_COMPONENT) do
                    yetAnotherEntityAmount += 1
                end
                expect(yetAnotherEntityAmount).to.be.equal(0)
            end)
            it("should use the queryCache if it exists", function()
                -- checking with the caching
                testWorld = WorldFactory.createWorld(nil, DefaultQueryCache.new())
                testWorld:startCaching()

                local YET_ANOTHER_COMPONENT = RegisteredComponent.new("yet_another", function(v)
                    return TestComponent.new(v)
                end)

                for _ = 1, 5, 1 do
                    testWorld:spawn({
                        some = SOME_COMPONENT:build()
                    })
                    testWorld:spawn({
                        some = SOME_COMPONENT:build(),
                        other = OTHER_COMPONENT:build()
                    })
                end

                -- do it 2 times so the first time, the world caches
                -- everything and the second time, it uses the cached data
                for _ = 1, 2, 1 do
                    -- single component check
                    local someEntityAmount = 0
                    for entityId in testWorld:query(SOME_COMPONENT) do
                        expect(testWorld:getComponent(entityId, SOME_COMPONENT:getName())).to.be.ok()
                        someEntityAmount += 1
                    end
                    expect(someEntityAmount).to.be.equal(10)

                    -- double components check
                    local someAndOtherEntityAmount = 0
                    for entityId in testWorld:query(SOME_COMPONENT, OTHER_COMPONENT) do
                        expect(testWorld:getComponent(entityId, SOME_COMPONENT:getName())).to.be.ok()
                        expect(testWorld:getComponent(entityId, OTHER_COMPONENT:getName())).to.be.ok()
                        someAndOtherEntityAmount += 1
                    end
                    expect(someAndOtherEntityAmount).to.be.equal(5)

                    -- absent component check
                    local AbsentComponentAmount = 0
                    for _ in testWorld:query(YET_ANOTHER_COMPONENT) do
                        AbsentComponentAmount += 1
                    end
                    expect(AbsentComponentAmount).to.be.equal(0)
                end
            end)
            it("should be possible to break out a query without breaking everything", function()
                testWorld:spawn({some = SOME_COMPONENT:build()})
                testWorld:spawn({some = SOME_COMPONENT:build()})
                
                for _ in testWorld:query(SOME_COMPONENT) do
                    testWorld:breakQuery()
                    break
                end

                expect(testWorld:isBuildingHypothesis()).to.be.equal(false)
            end)
        end)
        describe("queryCaching", function()
            it("should notify the cache about a new entity spawned", function()
                local methodCalled = false

                testWorld = WorldFactory.createWorld(nil, {
                    notifyCacheSpawnedEntity = function()
                        methodCalled = true
                    end
                })
                testWorld:spawn({some = SOME_COMPONENT:build()})

                expect(methodCalled).to.be.equal(true)
            end)
            it("should notify the cache about an entity despawned", function()
                local methodCalled = false

                testWorld = WorldFactory.createWorld(nil, {
                    notifyCacheSpawnedEntity = function()
                    end,
                    notifyCacheDespawnedEntity = function()
                        methodCalled = true
                    end
                })
                testWorld:spawnAt(1, {some = SOME_COMPONENT:build()})
                testWorld:despawn(1)

                expect(methodCalled).to.be.equal(true)
            end)
            it("should notify the cache about a component inserted, unless it replaced one of the same type", function()
                local methodCalled = false

                testWorld = WorldFactory.createWorld(nil, {
                    notifyCacheSpawnedEntity = function()
                    end,
                    notifyCacheEntityComponentInserted = function()
                        methodCalled = true
                    end
                })
                testWorld:spawnAt(1, {some = SOME_COMPONENT:build()})
                testWorld:insert(1, OTHER_COMPONENT:getName(), OTHER_COMPONENT:build())

                expect(methodCalled).to.be.equal(true)
            end)
            it("should notify the cache about a component removed", function()
                local methodCalled = false

                testWorld = WorldFactory.createWorld(nil, {
                    notifyCacheSpawnedEntity = function()
                    end,
                    notifyCacheEntityComponentRemoved = function()
                        methodCalled = true
                    end
                })
                testWorld:spawnAt(1, {some = SOME_COMPONENT:build(), other = OTHER_COMPONENT:build()})
                testWorld:remove(1, SOME_COMPONENT:getName())

                expect(methodCalled).to.be.equal(true)
            end)
        end)
    end)
end
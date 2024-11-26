local WorldFactory  = require(script.Parent.Parent.WorldFactory)
local WorldHypothesis = require(script.Parent.WorldHypothesis)
local WorldHypothesisMerger = require(script.Parent.WorldHypothesisMerger)
local SimpleIdProvider = require(script.Parent.Parent.id_provider.SimpleIdProvider)
local Component = require(script.Parent.Parent.Parent.component.Component)
local RegisteredComponent = require(script.Parent.Parent.Parent.component.RegisteredComponent)

local MAX_REYCLE_BIN_SIZE = 16

local TestComponent = Component:extend()
do
    TestComponent.__index = TestComponent

    function TestComponent.new(v, v2)
        return setmetatable({
            value = v,
            secondValue = v2
        }, TestComponent)
    end

    function TestComponent.getValue(self)
        return self.value
    end

    function TestComponent.getSecondValue(self)
        return self.secondValue
    end

    function TestComponent.formatClone(self, clone)
        clone.value = self.value
        clone.secondValue = self.secondValue
    end
end

local function newMock(returning : any?)
    return setmetatable({
        callStack = {},
        returning = returning,
        wasCalled = function(self, methodName)
            for _, name in ipairs(self.callStack) do
                if name == methodName then
                    return true
                end
            end
            return false
        end
    }, {
        __index = function(self, index)
            return setmetatable({}, {
                __call = function()
                    table.insert(self.callStack, index)
                    return self.returning
                end
            })
        end
    })
end

return function ()
    local subWorldMock = newMock()
    local mergerMock = newMock()
    mergerMock.copyIdProvider = function()
        return SimpleIdProvider.new()
    end
    local testWorld
    local testHypothesis
    local testMerger
    -- test hypothesis but without world + not refreshed each specification
    local hypothesis


    local SOME_COMPONENT = RegisteredComponent.new(
        "some",
        function(v)
            return TestComponent.new(v)
        end
    )
    local OTHER_COMPONENT = RegisteredComponent.new(
        "other",
        function(v)
            return TestComponent.new(v)
        end
    )

    beforeEach(function()
        testWorld = WorldFactory.createWorld(nil, false)
    end)

    describe("WorldHypothesis", function()
        it("should check itself and the world if it contains an entity", function()
            testWorld:spawnAt(1, {some = SOME_COMPONENT:build()})
            testWorld:spawnAt(2, {some = SOME_COMPONENT:build()})

            testMerger = WorldHypothesisMerger.new(testWorld)
            testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

            testHypothesis:spawnAt(3, {some = SOME_COMPONENT:build()})
            testHypothesis:spawnAt(4, {some = SOME_COMPONENT:build()})
            testHypothesis:despawn(2)
            testHypothesis:despawn(4)

            expect(testHypothesis:contains(1)).to.be.equal(true)
            expect(testHypothesis:contains(2)).to.be.equal(false)
            expect(testHypothesis:contains(3)).to.be.equal(true)
            expect(testHypothesis:contains(4)).to.be.equal(false)
        end)
        it("should merge into the merger", function()
            mergerMock = newMock()
            hypothesis = WorldHypothesis.new(subWorldMock, mergerMock)
            hypothesis:merge()
            expect(mergerMock:wasCalled("mergeIn")).to.be.equal(true)
        end)
        it("should call on the subWorld for root world operations", function()
            subWorldMock = newMock()
            hypothesis = WorldHypothesis.new(subWorldMock, mergerMock)

            hypothesis:openHypothesis({})
            subWorldMock:wasCalled("openHypothesis")

            hypothesis:closeHypothesis()
            subWorldMock:wasCalled("closeHypothesis")

            hypothesis:resetListenerHypothesis()
            subWorldMock:wasCalled("resetListenerHypothesis")
        end)
        it("should return a clone of its id provider", function()
            testMerger = WorldHypothesisMerger.new(testWorld)
            hypothesis = WorldHypothesis.new(testWorld, testMerger)

            local first = hypothesis:copyIdProvider()
            local second = hypothesis:copyIdProvider()

            expect(first).never.to.be.equal(second)
            expect(first:getNextId()).to.be.equal(second:getNextId())
        end)
        describe("world-like behaviour", function()
            describe("entity handling", function()
                it("should throw when searching a component in a non existent entity", function()
                    testMerger = WorldHypothesisMerger.new(testWorld)
                    testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                    expect(function()
                        testHypothesis:getComponent(1, SOME_COMPONENT:getName())
                    end).to.throw()
                end)
                it("should check if the world contains an entity", function()
                    testMerger = WorldHypothesisMerger.new(testWorld)
                    testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                    testHypothesis:spawnAt(1, {
                        some = SOME_COMPONENT:build()
                    })

                    expect(testHypothesis:contains(1)).to.be.equal(true)
                end)
                describe("spawning", function()
                    it("should store a reference to each given componentInstance", function()
                        testMerger = WorldHypothesisMerger.new(testWorld)
                        testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                        local component = SOME_COMPONENT:build("data")
    
                        testHypothesis:spawnAt(1, {
                            some = component
                        })
    
                        expect(testHypothesis:getComponent(1, SOME_COMPONENT:getName())).to.be.equal(component)
                    end)
                    it("should take an unused id if there is one", function()
                        testMerger = WorldHypothesisMerger.new(testWorld)
                        testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)
                        
                        testHypothesis:spawnAt(1, {
                            some = SOME_COMPONENT:build()
                        })
    
                        testHypothesis:spawnAt(2, {
                            some = SOME_COMPONENT:build()
                        })
    
                        testHypothesis:despawn(1)
    
                        local newEntityId = testHypothesis:spawn({
                            some = SOME_COMPONENT:build()
                        })
    
                        expect(newEntityId).to.be.equal(1)
                    end)
                    it("should throw if the provided entityId isn't valid", function()
                        testMerger = WorldHypothesisMerger.new(testWorld)
                        testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                        expect(function()
                            testHypothesis:spawnAt(-5, {
                                other = OTHER_COMPONENT:build()
                            })
                        end).to.throw()
    
                        expect(function()
                            testHypothesis:spawnAt(0, {
                                other = OTHER_COMPONENT:build()
                            })
                        end).to.throw()
    
                        expect(function()
                            testHypothesis:spawnAt(55.5, {
                                other = OTHER_COMPONENT:build()
                            })
                        end).to.throw()
                    end)
                end)
                describe("despawning", function()
                    it("should remove the entity", function()
                        testMerger = WorldHypothesisMerger.new(testWorld)
                        testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                        testHypothesis:spawnAt(1, {
                            some = SOME_COMPONENT:build()
                        })
    
                        expect(function()
                            testHypothesis:despawn(1)
                        end).never.to.throw()
    
                        expect(testHypothesis:contains(1)).to.be.equal(false)
                    end)
                    it("should remove the chunk if it's empty", function()
                        testMerger = WorldHypothesisMerger.new(testWorld)
                        testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                        testHypothesis:spawnAt(1, {
                            some = SOME_COMPONENT:build()
                        })
    
                        testHypothesis:despawn(1)
    
                        expect(testHypothesis:contains(1)).to.be.equal(false)
                    end)
                    it("should throw if the entity does not exist", function()
                        testMerger = WorldHypothesisMerger.new(testWorld)
                        testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                        testHypothesis:spawnAt(1, {
                            some = SOME_COMPONENT:build()
                        })
    
                        expect(function()
                            testHypothesis:despawn(2)
                        end).to.throw()
                    end)
                end)
                describe("inserting", function()
                    it("should insert component in entity", function()
                        testMerger = WorldHypothesisMerger.new(testWorld)
                        testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                        testHypothesis:spawnAt(1, {
                            some = SOME_COMPONENT:build()
                        })
    
                        expect(function()
                            testHypothesis:insert(1, OTHER_COMPONENT:getName(), OTHER_COMPONENT:build())
                        end).never.to.throw()
    
                        expect(testHypothesis:get(1).other).to.be.ok()
                    end)
                    it("should replace the component if it is already present", function()
                        testMerger = WorldHypothesisMerger.new(testWorld)
                        testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                        testHypothesis:spawnAt(1, {
                            some = SOME_COMPONENT:build()
                        })
                        local replacing = SOME_COMPONENT:build()
    
                        expect(function()
                            testHypothesis:insert(1, SOME_COMPONENT:getName(), replacing)
                        end).never.to.throw()
    
                        expect(testHypothesis:get(1).some).to.be.equal(replacing)
                    end)
                end)
                describe("removing", function()
                    it("should remove a component from an entity", function()
                        testMerger = WorldHypothesisMerger.new(testWorld)
                        testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                        testHypothesis:spawnAt(1, {
                            some = SOME_COMPONENT:build()
                        })
    
                        expect(function()
                            testHypothesis:remove(1, SOME_COMPONENT:getName())
                        end).never.to.throw()
    
                        expect(testHypothesis:get(1).some).never.to.be.ok()
                    end)
                    it("should throw if the client is trying to remove an entity that isn't present", function()
                        testMerger = WorldHypothesisMerger.new(testWorld)
                        testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                        testHypothesis:spawnAt(1, {
                            some = SOME_COMPONENT:build()
                        })
    
                        expect(function()
                            testHypothesis:remove(1, OTHER_COMPONENT:getName())
                        end).to.throw()
                    end)
                end)
            end)
            describe("querying", function()
                it("should return only the id of each entity", function()
                    testMerger = WorldHypothesisMerger.new(testWorld)
                    testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)
                    
                    testHypothesis:spawnAt(1, {
                        some = SOME_COMPONENT:build()
                    })
    
                    for _, shouldBeNil in testHypothesis:query() do
                        expect(shouldBeNil).never.to.be.ok()
                    end
                end)
                it("should iterate over present entities", function()
                    testMerger = WorldHypothesisMerger.new(testWorld)
                    testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)
                    
                    for i = 1, 5, 1 do
                        testHypothesis:spawnAt(i, {
                            some = SOME_COMPONENT:build()
                        })
                    end
                    
                    for entityId in testHypothesis:query() do
                        expect(entityId).to.be.ok()
                    end
                end)
                it("should query over all entities when no archetype is provided", function()
                    testMerger = WorldHypothesisMerger.new(testWorld)
                    testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                    testWorld:spawnAt(1, {
                        some = SOME_COMPONENT:build()
                    })
                    testWorld:spawnAt(2, {
                        some = SOME_COMPONENT:build()
                    })

                    testMerger = WorldHypothesisMerger.new(testWorld)
                    testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)
                    for _ = 2, 10, 1 do
                        testHypothesis:spawn({
                            some = SOME_COMPONENT:build()
                        })
                    end

                    local entityAmount = 0
                    for _ in testHypothesis:query() do
                        entityAmount += 1
                    end

                    expect(entityAmount).to.be.equal(11)
                end)
                it("should perform a query over the entities of the same component", function()
                    testMerger = WorldHypothesisMerger.new(testWorld)
                    testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                    local YET_ANOTHER_COMPONENT = RegisteredComponent.new(
                        "yet_another",
                        function(v)
                            return TestComponent.new(v)
                        end
                    )

                    for _ = 1, 5, 1 do
                        testWorld:spawn({
                            some = SOME_COMPONENT:build()
                        })
                        testWorld:spawn({
                            some = SOME_COMPONENT:build(),
                            other = OTHER_COMPONENT:build()
                        })
                    end

                    testMerger = WorldHypothesisMerger.new(testWorld)
                    testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                    for _ = 1, 5, 1 do
                        testHypothesis:spawn({
                            some = SOME_COMPONENT:build()
                        })
                        testHypothesis:spawn({
                            some = SOME_COMPONENT:build(),
                            other = OTHER_COMPONENT:build()
                        })
                    end

                    -- single component check
                    local someEntityAmount = 0
                    for entityId in testHypothesis:query(SOME_COMPONENT) do
                        expect(testHypothesis:getComponent(entityId, SOME_COMPONENT:getName())).to.be.ok()
                        someEntityAmount += 1
                    end
                    expect(someEntityAmount).to.be.equal(20)

                    -- double components check
                    local someAndOtherEntityAmount = 0
                    for entityId in testHypothesis:query(SOME_COMPONENT, OTHER_COMPONENT) do
                        expect(testHypothesis:getComponent(entityId, SOME_COMPONENT:getName())).to.be.ok()
                        expect(testHypothesis:getComponent(entityId, OTHER_COMPONENT:getName())).to.be.ok()
                        someAndOtherEntityAmount += 1
                    end
                    expect(someAndOtherEntityAmount).to.be.equal(10)

                    -- absent component check
                    someAndOtherEntityAmount = 0
                    for _ in testHypothesis:query(YET_ANOTHER_COMPONENT) do
                        someAndOtherEntityAmount += 1
                    end
                    expect(someAndOtherEntityAmount).to.be.equal(0)
                end)
            end)
        end)
        it("should recycle the instance", function()
            testMerger = WorldHypothesisMerger.new(testWorld)
            testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

            testHypothesis:recycle()
            local new = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

            expect(testHypothesis).to.be.equal(new)
        end)
        it("should stop reycling at a maximum", function()
            testMerger = WorldHypothesisMerger.new(testWorld)
            testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

            local providers = {}
            for _ = 1, MAX_REYCLE_BIN_SIZE, 1 do
                table.insert(providers, WorldHypothesis.new(testWorld, testMerger))
            end
            for _, provider in providers do
                provider:recycle()
            end

            testHypothesis:recycle()

            local recycled = false

            for _ = 1, MAX_REYCLE_BIN_SIZE, 1 do
                if testHypothesis == WorldHypothesis.new(testWorld, testMerger) then
                    recycled = true
                end
            end

            expect(recycled).to.be.equal(false)
        end)
    end)
end
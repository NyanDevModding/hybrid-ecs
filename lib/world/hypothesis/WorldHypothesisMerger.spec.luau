local WorldFactory  = require(script.Parent.Parent.WorldFactory)
local Component = require(script.Parent.Parent.Parent.component.Component)
local RegisteredComponent = require(script.Parent.Parent.Parent.component.RegisteredComponent)
local WorldHypothesisMerger = require(script.Parent.WorldHypothesisMerger)
local WorldHypothesis = require(script.Parent.WorldHypothesis)

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
end

local MAX_REYCLE_BIN_SIZE = 16

return function ()
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

    local testWorld
    local testHypothesis
    local testMerger

    beforeEach(function()
        testWorld = WorldFactory.createWorld(nil, false)
        testMerger = WorldHypothesisMerger.new(testWorld)
        testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)
    end)

    describe("WorldHypothesisMerger", function()

        it("should check itself and the world if it contains an entity", function()
            testWorld = WorldFactory.createWorld(nil, false)

            testWorld:spawnAt(1, {some = SOME_COMPONENT:build()})
            testWorld:spawnAt(2, {some = SOME_COMPONENT:build()})

            testMerger = WorldHypothesisMerger.new(testWorld)
            testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

            testHypothesis:spawnAt(3, {some = SOME_COMPONENT:build()})
            testHypothesis:spawnAt(4, {some = SOME_COMPONENT:build()})
            testHypothesis:despawn(2)
            testHypothesis:despawn(4)

            testHypothesis:merge()
            testMerger:commit()
            testMerger:reset()

            expect(testWorld:contains(1)).to.be.equal(true)
            expect(testWorld:contains(2)).to.be.equal(false)
            expect(testWorld:contains(3)).to.be.equal(true)
            expect(testWorld:contains(4)).to.be.equal(false)
        end)
        describe("merging", function()
            it("should store entities as despawned", function()
                testWorld = WorldFactory.createWorld(nil, false)

                testWorld:spawnAt(1, {some = SOME_COMPONENT:build()})
                testWorld:spawnAt(2, {some = SOME_COMPONENT:build()})

                testMerger = WorldHypothesisMerger.new(testWorld)
                testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                testHypothesis:despawn(1)
                testHypothesis:despawn(2)

                testHypothesis:merge()
                testMerger:commit()
                testMerger:reset()

                expect(testWorld:contains(1)).to.be.equal(false)
                expect(testWorld:contains(2)).to.be.equal(false)
            end)
            it("shouldn't let a despawn mark be duplicated", function()
                testWorld = WorldFactory.createWorld(nil, false)

                testWorld:spawnAt(1, {some = SOME_COMPONENT:build()})
                testWorld:spawnAt(2, {some = SOME_COMPONENT:build()})

                testMerger = WorldHypothesisMerger.new(testWorld)
                testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)
                
                testHypothesis:despawn(1)
                testHypothesis:merge()
                
                local otherHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)
                
                otherHypothesis:despawn(1)
                otherHypothesis:merge()

                expect(function()
                    testMerger:commit()
                    testMerger:reset()
                end).never.to.throw()

                expect(testWorld:contains(1)).to.be.equal(false)
            end)
            it("should store inserts", function()
                testWorld = WorldFactory.createWorld(nil, false)

                testWorld:spawnAt(1, {some = SOME_COMPONENT:build()})

                testMerger = WorldHypothesisMerger.new(testWorld)
                testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                testHypothesis:insert(1, OTHER_COMPONENT:getName(), OTHER_COMPONENT:build())

                testHypothesis:merge()

                expect(function()
                    testMerger:commit()
                    testMerger:reset()
                end).never.to.throw()

                expect(testWorld:contains(1)).to.be.equal(true)
                expect(testWorld:getComponent(1, SOME_COMPONENT:getName())).to.be.ok()
                expect(testWorld:getComponent(1, OTHER_COMPONENT:getName())).to.be.ok()
            end)
            it("should store replacing inserts", function()
                testWorld = WorldFactory.createWorld(nil, false)

                testWorld:spawnAt(1, {some = SOME_COMPONENT:build(1)})

                testMerger = WorldHypothesisMerger.new(testWorld)
                testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                testHypothesis:insert(1, SOME_COMPONENT:getName(), SOME_COMPONENT:build(2))
                local hypotethisComponent = testHypothesis:getComponent(1, SOME_COMPONENT:getName())

                testHypothesis:merge()

                expect(function()
                    testMerger:commit()
                    testMerger:reset()
                end).never.to.throw()

                expect(testWorld:contains(1)).to.be.equal(true)
                expect(testWorld:getComponent(1, SOME_COMPONENT:getName())).to.be.ok()
                expect(testWorld:getComponent(1, SOME_COMPONENT:getName()):getValue()).to.be.equal(hypotethisComponent:getValue())
            end)
            it("should store removals", function()
                testWorld = WorldFactory.createWorld(nil, false)

                testWorld:spawnAt(1, {some = SOME_COMPONENT:build()})

                testMerger = WorldHypothesisMerger.new(testWorld)
                testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                testHypothesis:remove(1, SOME_COMPONENT:getName())

                testHypothesis:merge()

                expect(function()
                    testMerger:commit()
                    testMerger:reset()
                end).never.to.throw()

                expect(testWorld:contains(1)).to.be.equal(true)
                expect(testWorld:getComponent(1, SOME_COMPONENT:getName())).never.to.be.ok()
            end)
            it("should fuse archetype changes", function()
                testWorld = WorldFactory.createWorld(nil, false)

                testWorld:spawnAt(1, {some = SOME_COMPONENT:build()})

                testMerger = WorldHypothesisMerger.new(testWorld)
                testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                testHypothesis:remove(1, SOME_COMPONENT:getName())
                testHypothesis:merge()

                local secondHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                secondHypothesis:insert(1, OTHER_COMPONENT:getName(), OTHER_COMPONENT:build())
                -- it shouldn't replace the previously removed components
                secondHypothesis:merge()

                expect(function()
                    testMerger:commit()
                    testMerger:reset()
                end).never.to.throw()

                expect(testWorld:getComponent(1, SOME_COMPONENT:getName())).never.to.be.ok()
                expect(testWorld:getComponent(1, OTHER_COMPONENT:getName())).to.be.ok()
            end)
            it("should store spawns", function()
                testHypothesis:spawnAt(1, {some = SOME_COMPONENT:build()})
                testHypothesis:spawn({some = SOME_COMPONENT:build()})

                testHypothesis:merge()

                expect(function()
                    testMerger:commit()
                    testMerger:reset()
                end).never.to.throw()

                expect(testWorld:contains(1)).to.be.equal(true)
                expect(testWorld:contains(2)).to.be.equal(true)
                expect(testWorld:getComponent(1, SOME_COMPONENT:getName())).to.be.ok()
                expect(testWorld:getComponent(2, SOME_COMPONENT:getName())).to.be.ok()
            end)
            it("should not allow concurrent spawns", function()
                testHypothesis:spawnAt(1, {some = SOME_COMPONENT:build()})
                testHypothesis:merge()

                local secondHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)
                secondHypothesis:spawnAt(1, {some = SOME_COMPONENT:build()})

                expect(function()
                    secondHypothesis:merge()
                end).to.throw()
            end)
        end)
        describe("id propagation", function()
            it("should copy its id provider and its data", function()
                local first = testMerger:copyIdProvider()
                local second = testMerger:copyIdProvider()

                expect(first).never.to.be.equal(second)
                expect(first:getNextId()).to.be.equal(second:getNextId())
            end)
            it("should never get concurrent spawns when using the :spawn method", function()
                testHypothesis:spawn({some = SOME_COMPONENT:build()})
                expect(testHypothesis:getNextId()).to.be.equal(2)
                testHypothesis:spawn({some = SOME_COMPONENT:build()})
                expect(testHypothesis:getNextId()).to.be.equal(3)

                testHypothesis:merge()

                local secondTestHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)
                secondTestHypothesis:spawn({some = SOME_COMPONENT:build()})
                expect(secondTestHypothesis:getNextId()).to.be.equal(4)
                secondTestHypothesis:spawn({some = SOME_COMPONENT:build()})
                expect(secondTestHypothesis:getNextId()).to.be.equal(5)

                expect(function()
                    secondTestHypothesis:merge()
                end).never.to.throw()
                expect(testMerger:getNextId()).to.be.equal(5)
                
                expect(function()
                    testMerger:commit()
                    testMerger:reset()
                end).never.to.throw()
                expect(testWorld:getNextId()).to.be.equal(5)
            end)
        end)
        describe("committing", function()
            it("should commit the insertions", function()
                testWorld = WorldFactory.createWorld(nil, false)

                testWorld:spawnAt(1, {some = SOME_COMPONENT:build()})

                testMerger = WorldHypothesisMerger.new(testWorld)
                testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                testHypothesis:insert(1, OTHER_COMPONENT:getName(), OTHER_COMPONENT:build())

                testHypothesis:merge()

                testMerger:commit()
                testMerger:reset()

                expect(testWorld:getComponent(1, SOME_COMPONENT:getName())).to.be.ok()
                expect(testWorld:getComponent(1, OTHER_COMPONENT:getName())).to.be.ok()
            end)
            it("should commit the removals", function()
                testWorld = WorldFactory.createWorld(nil, false)

                testWorld:spawnAt(1, {some = SOME_COMPONENT:build()})

                testMerger = WorldHypothesisMerger.new(testWorld)
                testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                testHypothesis:remove(1, SOME_COMPONENT:getName())

                testHypothesis:merge()

                testMerger:commit()
                testMerger:reset()

                expect(testWorld:getComponent(1, SOME_COMPONENT:getName())).never.to.be.ok()
            end)
            it("should commit the spawns", function()
                testHypothesis:spawnAt(1, {some = SOME_COMPONENT:build()})
                testHypothesis:spawn({some = SOME_COMPONENT:build()})

                testHypothesis:merge()

                testMerger:commit()
                testMerger:reset()

                expect(testWorld:contains(1)).to.be.equal(true)
                expect(testWorld:contains(2)).to.be.equal(true)
                expect(testWorld:getComponent(1, SOME_COMPONENT:getName())).to.be.ok()
                expect(testWorld:getComponent(2, SOME_COMPONENT:getName())).to.be.ok()
            end)
            it("should commit the despawns", function()
                testWorld = WorldFactory.createWorld(nil, false)

                testWorld:spawnAt(1, {some = SOME_COMPONENT:build()})
                testWorld:spawnAt(2, {some = SOME_COMPONENT:build()})

                testMerger = WorldHypothesisMerger.new(testWorld)
                testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)

                testHypothesis:despawn(1)
                testHypothesis:despawn(2)

                testHypothesis:merge()

                testMerger:commit()
                testMerger:reset()

                expect(testWorld:contains(1)).to.be.equal(false)
                expect(testWorld:contains(2)).to.be.equal(false)
            end)
        end)
        it("should recycle the instance", function()
            testMerger:recycle()
            local new = WorldHypothesisMerger.new(testWorld)

            expect(testMerger).to.be.equal(new)
        end)
        it("should stop reycling at a maximum", function()
            local mergers = {}
            for _ = 1, MAX_REYCLE_BIN_SIZE, 1 do
                table.insert(mergers, WorldHypothesisMerger.new(testWorld))
            end
            for _, merger in mergers do
                merger:recycle()
            end

            testMerger:recycle()

            local recycled = false

            for _ = 1, MAX_REYCLE_BIN_SIZE, 1 do
                if testMerger == WorldHypothesisMerger.new(testWorld) then
                    recycled = true
                end
            end

            expect(recycled).to.be.equal(false)
        end)
    end)
end
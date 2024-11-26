local componentFolder = script.Parent.Parent.Parent.component

local Component = require(componentFolder.Component)
local CompositeComponent = require(componentFolder.CompositeComponent)
local RegisteredMultiComponent = require(componentFolder.RegisteredMultiComponent)

local WorldFactory = require(script.Parent.Parent.WorldFactory)
local WorldHypothesis = require(script.Parent.WorldHypothesis)
local WorldHypothesisMerger = require(script.Parent.WorldHypothesisMerger)

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

    function TestComponent.fuseWith(self, other)
        Component.fuseWith(self, other)
        self.value = if self.value ~= nil then self.value else other:getValue()
        self.secondValue = if self.secondValue ~= nil then self.secondValue else other:getSecondValue()
    end
end

return function ()
    local SOME_COMPONENT = RegisteredMultiComponent.new(
        "some",
        function(v, v2)
            return TestComponent.new(v, v2)
        end,
        function(builder, ...)
            return CompositeComponent.new(builder, ...)
        end
    )

    local testWorld
    local testHypothesis
    local testMerger

    beforeEach(function()
        testWorld = WorldFactory.createWorld(nil, false)
    end)

    describe("Numero data propagation", function()
        it("shouldn't create component with the same numero", function()
            local id = testWorld:spawn({
                some = SOME_COMPONENT:buildComposite({
                    SOME_COMPONENT:build()
                })
            })

            testMerger = WorldHypothesisMerger.new(testWorld)

            testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)
            local component : CompositeComponent.CompositeComponent = testHypothesis:getComponent(id, SOME_COMPONENT:getName())
            component:insertAt(3, SOME_COMPONENT:build())
            testHypothesis:merge()
            testHypothesis:recycle()

            testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)
            component = testHypothesis:getComponent(id, SOME_COMPONENT:getName())

            local num = component:insert(SOME_COMPONENT:build())
            expect(num).to.be.equal(2)
            expect(component:get(3)).never.to.be.ok()
            -- should skip 3 (3 should be BLANK)
            num = component:insert(SOME_COMPONENT:build())
            expect(num).to.be.equal(4)
        end)
        it("should allow the creation of components with the same numero with createAt and insertAt", function()
            local id = testWorld:spawn({
                some = SOME_COMPONENT:buildComposite({
                    SOME_COMPONENT:build()
                })
            })

            testMerger = WorldHypothesisMerger.new(testWorld)

            testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)
            local component : CompositeComponent.CompositeComponent = testHypothesis:getComponent(id, SOME_COMPONENT:getName())
            component:insertAt(3, SOME_COMPONENT:build())
            testHypothesis:merge()
            testHypothesis:recycle()

            -- insertAt test
            testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)
            component = testHypothesis:getComponent(id, SOME_COMPONENT:getName())

            expect(function()
                component:insertAt(3, SOME_COMPONENT:build())
            end).never.to.throw()
            expect(component:get(3)).to.be.ok()

            -- createAt test
            testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)
            component = testHypothesis:getComponent(id, SOME_COMPONENT:getName())

            expect(function()
                component:createAt(3)
            end).never.to.throw()
            expect(component:get(3)).to.be.ok()
        end)
    end)
    describe("Merging", function()
        it("should merge every components of each composite", function()
            local c0 = SOME_COMPONENT:build(0)

            local id = testWorld:spawn({
                some = SOME_COMPONENT:buildComposite({
                    c0
                })
            })

            testMerger = WorldHypothesisMerger.new(testWorld)

            local c1, c2, c3 = SOME_COMPONENT:build(1), SOME_COMPONENT:build(2), SOME_COMPONENT:build(3)

            testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)
            local component : CompositeComponent.CompositeComponent = testHypothesis:getComponent(id, SOME_COMPONENT:getName())
            component:insertAt(3, c1)
            testHypothesis:merge()
            testHypothesis:recycle()

            testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)
            component = testHypothesis:getComponent(id, SOME_COMPONENT:getName())

            component:insertAt(1, c2)
            component:insertAt(4, c3)

            expect(function()
                testHypothesis:merge()
                testHypothesis:recycle()
            end).never.to.throw()

            local entity = testMerger:get(id)
            component = entity[SOME_COMPONENT:getName()]

            -- c2 is fused in c0. the changes in c2 are not accepted by the
            -- c0's method
            expect(component:get(1):getValue()).to.be.equal(c0:getValue())
            expect(component:get(3):getValue()).to.be.equal(c1:getValue())
            expect(component:get(4):getValue()).to.be.equal(c3:getValue())
        end)
        it("should fuse component with the same numero", function()
            local id = testWorld:spawn({
                some = SOME_COMPONENT:buildComposite({
                    SOME_COMPONENT:build()
                })
            })

            testMerger = WorldHypothesisMerger.new(testWorld)

            local c1, c2 = SOME_COMPONENT:build(), SOME_COMPONENT:build()
            local c4 = SOME_COMPONENT:build("first")
            local c5 = SOME_COMPONENT:build(nil, "second")

            testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)
            local component : CompositeComponent.CompositeComponent = testHypothesis:getComponent(id, SOME_COMPONENT:getName())
            component:insertAt(3, c1)
            component:insertAt(2, c4)
            testHypothesis:merge()
            testHypothesis:recycle()

            testHypothesis = WorldHypothesis.new(testWorld:getRawWorld(), testMerger)
            component = testHypothesis:getComponent(id, SOME_COMPONENT:getName())

            component:insertAt(1, c2)
            component:insertAt(2, c5)

            expect(function()
                testHypothesis:merge()
                testHypothesis:recycle()
            end).never.to.throw()

            local entity = testMerger:get(id)
            component = entity[SOME_COMPONENT:getName()]

            expect(component:get(1):getValue()).to.be.equal(c2:getValue())
            expect(component:get(3):getValue()).to.be.equal(c1:getValue())
            expect(component:get(2):getValue()).to.be.equal("first")
            expect(component:get(2):getSecondValue()).to.be.equal("second")
        end)
    end)
end
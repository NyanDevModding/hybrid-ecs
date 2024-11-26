local WorldFactory  = require(script.Parent.WorldFactory)
local Component = require(script.Parent.Parent.component.Component)
local RegisteredComponent = require(script.Parent.Parent.component.RegisteredComponent)

local TestComponent = Component:extend()
do
    TestComponent.__index = TestComponent

    function TestComponent.new(v)
        return setmetatable({
            value = v
        }, TestComponent)
    end

    function TestComponent.formatClone(self, clone)
        clone.value = self.value
    end
end

return function ()
    local SOME_COMPONENT = RegisteredComponent.new("some", function(v)
        return TestComponent.new(v)
    end)

    local testWorld
    beforeEach(function()
        testWorld = WorldFactory.createWorld(nil, false)
    end)

    describe("EntityMirror", function()
        it("should store a reference to an entity", function()
            testWorld:spawnAt(1, {
                some = SOME_COMPONENT:build()
            })

            local entity = testWorld:get(1)

            expect(entity._entity).to.be.equal(testWorld:get(1)._entity)
        end)
        it("should index its components", function()
            local component = SOME_COMPONENT:build()
            testWorld:spawnAt(1, {
                some = component
            })

            local entity = testWorld:get(1)

            expect(entity.some).to.be.ok()
        end)
        it("should give access to the entity's components", function()
            local component = SOME_COMPONENT:build()
            testWorld:spawnAt(1, {
                some = component
            })

            local entity = testWorld:get(1)

            expect(entity:getComponent(SOME_COMPONENT:getName())).to.be.equal(component)
        end)
        it("should let the client break the reference", function()
            testWorld:spawnAt(1, {
                some = SOME_COMPONENT:build()
            })

            local entity = testWorld:get(1)

            entity:terminate()

            expect(entity.world).never.to.be.ok()
            expect(entity.id).never.to.be.ok()
            expect(entity._entity).never.to.be.ok()
        end)
        it("should let the client despawn it and terminate", function()
            testWorld:spawnAt(1, {
                some = SOME_COMPONENT:build()
            })

            local entity = testWorld:get(1)

            entity:despawn()

            expect(testWorld:contains(1)).to.be.equal(false)

            expect(entity.world).never.to.be.ok()
            expect(entity.id).never.to.be.ok()
            expect(entity._entity).never.to.be.ok()
        end)
    end)
end
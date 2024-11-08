local WorldFactory  = require(script.Parent.WorldFactory)
local Component = require(script.Parent.Parent.component.Component)

return function ()
    local SOME_COMPONENT = Component.new("some")

    local testWorld
    beforeEach(function()
        testWorld = WorldFactory.createWorld(nil, false)
    end)

    describe("EntityMirror", function()
        it("should store a reference to an entity", function()
            testWorld:spawnAt(1, {
                SOME_COMPONENT()
            })

            local entity = testWorld:get(1)

            expect(entity._entity).to.be.equal(testWorld:get(1)._entity)
        end)
        it("should index its components", function()
            local component = SOME_COMPONENT()
            testWorld:spawnAt(1, {
                component
            })

            local entity = testWorld:get(1)

            expect(entity.some).to.be.ok()
        end)
        it("should give access to the entity's components", function()
            local component = SOME_COMPONENT()
            testWorld:spawnAt(1, {
                component
            })

            local entity = testWorld:get(1)

            expect(entity:getComponent(SOME_COMPONENT)).to.be.equal(component)
        end)
        it("should let the client break the reference", function()
            testWorld:spawnAt(1, {
                SOME_COMPONENT()
            })

            local entity = testWorld:get(1)

            entity:terminate()

            expect(entity.world).never.to.be.ok()
            expect(entity.id).never.to.be.ok()
            expect(entity._entity).never.to.be.ok()
        end)
        it("should let the client despawn it and terminate", function()
            testWorld:spawnAt(1, {
                SOME_COMPONENT()
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
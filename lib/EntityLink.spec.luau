local WorldFactory  = require(script.Parent.world.WorldFactory)
local Component = require(script.Parent.component.Component)
local RegisteredComponent = require(script.Parent.component.RegisteredComponent)
local EntityLink = require(script.Parent.EntityLink)

local EntityLinkComponent = Component:extend()
do
    EntityLinkComponent.__index = EntityLinkComponent

    function EntityLinkComponent.new(link)
        return setmetatable({
            link = link
        }, EntityLinkComponent)
    end
end

local ENTITY_LINK = RegisteredComponent.new("test_entity_link", function(link)
    return EntityLinkComponent.new(link)
end)

return function ()
    describe("EntityLink", function()
        it("should be able to link itself to another", function()
            local someEntityLink = EntityLink.new(1)
            local someOtherEntityLink = EntityLink.new(2)
            
            expect(someEntityLink._otherEntityLink).never.to.be.ok()
            expect(someOtherEntityLink._otherEntityLink).never.to.be.ok()

            someEntityLink:linkWith(someOtherEntityLink)

            expect(someEntityLink._otherEntityLink).to.be.equal(someOtherEntityLink)
            expect(someOtherEntityLink._otherEntityLink).to.be.equal(someEntityLink)
        end)
        it("should be able to unlink", function()
            local someEntityLink = EntityLink.new(1)
            local someOtherEntityLink = EntityLink.new(2)
            someEntityLink:linkWith(someOtherEntityLink)

            someEntityLink:unlinkFrom()

            expect(someEntityLink._otherEntityLink).never.to.be.ok()
            expect(someOtherEntityLink._otherEntityLink).never.to.be.ok()
        end)
        it("should call _onLinked() when linked", function()
            local hookCalled = false
            local someEntityLink = EntityLink.new(1, function()
                hookCalled = true
            end)
            local someOtherEntityLink = EntityLink.new(2)

            someEntityLink:linkWith(someOtherEntityLink)

            expect(hookCalled).to.be.ok()
        end)
        it("should call _onUnlinked() when unlinked", function()
            local hookCalled = false
            local someEntityLink = EntityLink.new(1, nil, function()
                hookCalled = true
            end)
            local someOtherEntityLink = EntityLink.new(2)

            someEntityLink:linkWith(someOtherEntityLink)
            someEntityLink:unlinkFrom()

            expect(hookCalled).to.be.ok()
        end)
        it("should throw when calling individualLink when the other isn't linked", function()
            local someEntityLink = EntityLink.new(1)
            local someOtherEntityLink = EntityLink.new(2)

            expect(function()
                someEntityLink:individualLink(someOtherEntityLink)
            end).to.throw()
        end)
        it("should throw when calling individualUnlink when the other is always linked", function()
            local someEntityLink = EntityLink.new(1)
            local someOtherEntityLink = EntityLink.new(2)
            someEntityLink:linkWith(someOtherEntityLink)

            expect(function()
                someEntityLink:individualUnlink(someOtherEntityLink)
            end).to.throw()
        end)
        it("should return the other entitys's mirror", function()
            -- spawn 2 entities with references by entityLinks
            local world = WorldFactory.createWorld(nil, false)
            world:spawnAt(1, {
                test_entity_link = ENTITY_LINK:build(EntityLink.new(1))
            })
            local someEntity = world:get(1)
            world:spawnAt(2, {
                test_entity_link = ENTITY_LINK:build(EntityLink.new(2))
            })
            local someOtherEntity = world:get(2)

            local someEntityLink = someEntity.test_entity_link.link
            local someOtherEntityLink = someOtherEntity.test_entity_link.link
            someEntityLink:linkWith(someOtherEntityLink)

            local othersMirror = someEntityLink:getOther(world)
            expect(othersMirror.test_entity_link.link).to.be.equal(someOtherEntityLink)
        end)
        -- not yet implemented
        itSKIP("should be convertible to json", function()
        end)
        --not yet implemented
        itSKIP("should be convertible from json", function()
        end)
    end)
end
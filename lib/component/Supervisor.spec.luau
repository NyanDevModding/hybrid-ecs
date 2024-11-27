local Supervisor = require(script.Parent.Supervisor)

return function ()
    local testSupervisor

    beforeEach(function()
        testSupervisor = Supervisor.new({}, 55)
    end)

    it("should ask the world for an entityMirror", function()
        testSupervisor = Supervisor.new({
            get = function(_self, entityId : number)
                expect(entityId).to.be.equal(55)
                return "ok"
            end
        }, 55)

        expect(testSupervisor:get()).to.be.equal("ok")
    end)
    it("should set another world", function()
        testSupervisor = Supervisor.new({
            get = function()
                return "ok"
            end
        }, 55)
        testSupervisor:setWorld({
            get = function(_self, entityId : number)
                expect(entityId).to.be.equal(55)
                return "ok_from_another_world"
            end
        })

        expect(testSupervisor:get()).to.be.equal("ok_from_another_world")
    end)
    it("should store the entityId", function()
        expect(testSupervisor:getEntityId()).to.be.equal(55)
    end)
    it("should set another entityId", function()
        testSupervisor:setEntityId(18)

        expect(testSupervisor:getEntityId()).to.be.equal(18)
    end)
    it("should check if the reference to the entity is valid", function()
        -- +entityId +world
        expect(testSupervisor:isNull()).to.be.equal(false)

        -- -entityId +world
        testSupervisor:setEntityId(nil)
        expect(testSupervisor:isNull()).to.be.equal(true)

        -- -entityId -world
        testSupervisor:setWorld(nil)
        expect(testSupervisor:isNull()).to.be.equal(true)

        -- +entityId -world
        testSupervisor:setEntityId(18)
        expect(testSupervisor:isNull()).to.be.equal(true)
    end)
    it("should destroy itself", function()
        testSupervisor:destroy()

        expect(testSupervisor:getEntityId()).never.to.be.ok()
        expect(testSupervisor:isNull()).to.be.equal(true)
    end)
    it("should check if its null and, in this case, destroy itself", function()
        testSupervisor:setWorld(nil)
        testSupervisor:check()
        
        expect(testSupervisor:getEntityId()).never.to.be.ok()
        expect(testSupervisor:isNull()).to.be.equal(true)
    end)
    it("should clone itself", function()
        local world = {
            get = function ()
                return "ok"
            end
        }
        testSupervisor = Supervisor.new(world, 55)
        local clone : Supervisor.Supervisor = testSupervisor:clone()

        expect(clone:getEntityId()).to.be.equal(testSupervisor:getEntityId())
        expect(clone:get()).to.be.equal("ok")
    end)
    it("should destroy itself on removed", function()
        testSupervisor:onRemoved()

        expect(testSupervisor:getEntityId()).never.to.be.ok()
        expect(testSupervisor:isNull()).to.be.equal(true)
    end)
end
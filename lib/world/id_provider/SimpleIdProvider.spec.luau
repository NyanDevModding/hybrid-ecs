local SimpleIdProvider = require(script.Parent.SimpleIdProvider)

local MAX_REYCLE_BIN_SIZE = 16

return function ()
    local testIdProvider
    beforeEach(function()
        testIdProvider = SimpleIdProvider.new()
    end)

    describe("SimpleIdProvider", function()
        -- this is why setNextId should be used carefully.
        it("should never give a used id when calling :useNextId()", function()
            testIdProvider:setNextId(4)

            testIdProvider:useId(2)

            expect(testIdProvider:useNextId()).never.to.be.equal(2)
            expect(testIdProvider:useNextId()).never.to.be.equal(2)
            expect(testIdProvider:useNextId()).never.to.be.equal(2)
            expect(testIdProvider:useNextId()).never.to.be.equal(2)
        end)
        it("should unuse all the ids between the new and the old next id when the new is greater then the old", function()
            testIdProvider:setNextId(4)

            expect(testIdProvider:useNextId()).never.to.be.equal(4)
            expect(testIdProvider:useNextId()).never.to.be.equal(4)
            expect(testIdProvider:useNextId()).never.to.be.equal(4)
        end)
        it("should remove the ids between the new and old next id in the unusedIds when the new is lower then the old", function()
            testIdProvider:setNextId(6)
            testIdProvider:setNextId(4)

            expect(testIdProvider:useNextId()).never.to.be.equal(5)
            expect(testIdProvider:useNextId()).never.to.be.equal(5)
            expect(testIdProvider:useNextId()).never.to.be.equal(5)
            -- nextId steps but 5 should not be unused.
            expect(testIdProvider:useNextId()).never.to.be.equal(5)
        end)
        it("should use the unusedId in priority", function()
            testIdProvider:setNextId(3)

            expect(testIdProvider:useNextId()).never.to.be.equal(3)
            expect(testIdProvider:useNextId()).never.to.be.equal(3)
        end)
        it("should else use the nextId", function()
            local nextId = testIdProvider:getNextId()
            local id = testIdProvider:useNextId()

            expect(id).to.be.equal(1)
            expect(id).to.be.equal(nextId)
        end)
        it("should elevate the nextId on use", function()
            -- useNextId check
            local nextId = testIdProvider:getNextId()
            testIdProvider:useNextId()

            expect(testIdProvider:getNextId()).to.be.equal(nextId + 1)

            -- useId check
            nextId = testIdProvider:getNextId()
            testIdProvider:useId(nextId)

            expect(testIdProvider:getNextId()).to.be.equal(nextId + 1)
        end)
        it("should let an id be marked as unused", function()
            for i = 1, 5, 1 do
                testIdProvider:useId(i)
            end
            testIdProvider:unuseId(3)

            expect(testIdProvider:useNextId()).to.be.equal(3)
        end)
        it("should lower the nextId if the one just under it is unused", function()
            for i = 1, 4, 1 do
                testIdProvider:useId(i)
            end

            expect(testIdProvider:getNextId()).to.be.equal(5)
            testIdProvider:unuseId(4)
            expect(testIdProvider:getNextId()).to.be.equal(4)
        end)
        it("should recycle the instance", function()
            testIdProvider:recycle()

            local new = SimpleIdProvider.new()

            -- testIdProvider isn't nilled for the purpose of the ref check
            -- on recycle, every refrence to it should be nulled
            expect(testIdProvider).to.be.equal(new)
        end)
        it("should stop reycling at a maximum", function()
            local providers = {}
            for _ = 1, MAX_REYCLE_BIN_SIZE, 1 do
                table.insert(providers, SimpleIdProvider.new())
            end
            for _, provider in providers do
                provider:recycle()
            end

            testIdProvider:recycle()

            local recycled = false

            for _ = 1, MAX_REYCLE_BIN_SIZE, 1 do
                if testIdProvider == SimpleIdProvider.new() then
                    recycled = true
                end
            end

            expect(recycled).to.be.equal(false)
        end)
    end)
end
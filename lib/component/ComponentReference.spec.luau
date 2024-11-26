local ComponentReference = require(script.Parent.ComponentReference)

return function ()
    local referencedMock = {}
    local otherReferenceMock = {}

    local reference

    beforeEach(function()
        reference = ComponentReference.new(referencedMock)
    end)

    it("should store a reference", function()
        expect(reference:get()).to.be.equal(referencedMock)
    end)
    it("should be destroyable", function()
        expect(reference:get()).to.be.ok()
        reference:destroy()

        expect(reference:get()).never.to.be.ok()
    end)
    it("should be checkable wether if it is destroyed or not", function()
        expect(reference:isNull()).to.be.equal(false)
        reference:destroy()

        expect(reference:isNull()).to.be.equal(true)
    end)
    describe("updating", function()
        it("should behave like its updated version", function()
            local updated = ComponentReference.new(otherReferenceMock)
            reference:update(updated)

            expect(reference:get()).to.be.equal(otherReferenceMock)
            expect(reference:getUpdated()).to.be.equal(updated)
            expect(reference:isNull()).to.be.equal(false)

            reference:destroy()

            -- propagated change to updated version
            expect(updated:get()).never.to.be.ok()
            expect(updated:isNull()).to.be.equal(true)
        end)
        it("should check if it is updated", function()
            expect(reference:isUpdated()).to.be.equal(false)
            reference:update(ComponentReference.new(otherReferenceMock))

            expect(reference:isUpdated()).to.be.equal(true)
        end)
    end)
end
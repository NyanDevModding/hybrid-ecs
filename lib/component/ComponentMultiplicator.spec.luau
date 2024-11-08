local ComponentMultiplicator = require(script.Parent.ComponentMultiplicator)

return function ()
    describe("ComponentMultiplicator", function()
        describe("multiplicating", function()
            it("should create a new component if the one to get isn't here ", function()
                local SOME_MULTIPLICATOR = ComponentMultiplicator.new("some")
                SOME_MULTIPLICATOR:get(2)

                expect(SOME_MULTIPLICATOR._components[2]).to.be.ok()
            end)
            it("should call the created component with its number", function()
                local SOME_MULTIPLICATOR = ComponentMultiplicator.new("some")
                local newComponent = SOME_MULTIPLICATOR:get(2)

                expect(newComponent.name).to.be.equal("some_2")
            end)
        end)
        it("should check if a component exists", function()
            local SOME_MULTIPLICATOR = ComponentMultiplicator.new("some")
            SOME_MULTIPLICATOR:get(2)

            expect(SOME_MULTIPLICATOR:has(2)).to.be.equal(true)
            expect(SOME_MULTIPLICATOR:has(1)).to.be.equal(false)
        end)
        it("should return an alreday created component if it exists", function()
            local SOME_MULTIPLICATOR = ComponentMultiplicator.new("some")

            local newComponent = SOME_MULTIPLICATOR:get(1)
            local sameComponent = SOME_MULTIPLICATOR:get(1)

            expect(newComponent).to.be.equal(sameComponent)
        end)
        it("should keep track of the number of created components", function()
            local SOME_MULTIPLICATOR = ComponentMultiplicator.new("some")

            SOME_MULTIPLICATOR:get(2)
            SOME_MULTIPLICATOR:get(3)
            SOME_MULTIPLICATOR:get(4)

            expect(SOME_MULTIPLICATOR.size).to.be.equal(3)
        end)
    end)
end
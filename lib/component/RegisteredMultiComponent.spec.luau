local RegisteredMultiComponent = require(script.Parent.RegisteredMultiComponent)

return function ()
    describe("RegisteredMultiComponent", function()
        it("should store a composite builder provided while contructing", function()
            local builderCalled = false
            local testRegistered = RegisteredMultiComponent.new("some_name", function() end, function()
                builderCalled = true
            end)
            testRegistered:buildComposite()

            expect(builderCalled).to.be.equal(true)
        end)
        it("should pass the arguments to the composite builder", function()
            local first, second, third
            local testRegistered = RegisteredMultiComponent.new("some_name", function() end,
                function(_, arg1, arg2, arg3)
                    first, second, third = arg1, arg2, arg3
                end
            )
            testRegistered:buildComposite("apple", "banana", "peer")

            expect(first).to.be.equal("apple")
            expect(second).to.be.equal("banana")
            expect(third).to.be.equal("peer")
        end)
        it("should pass the normal builder to the composite builder as the first argument", function()
            local concreteBuilder = function()
                return "concrete"
            end
            local testRegistered = RegisteredMultiComponent.new("some_name", concreteBuilder, function(builder)
                expect(builder()).to.be.equal(concreteBuilder())
            end)
            testRegistered:buildComposite()
        end)
        it("should accept a nil composite builder and use the default one", function()
            local testRegistered = RegisteredMultiComponent.new("some_name", function() end)
            expect(function()
                testRegistered:buildComposite()
            end).never.to.throw()
        end)
    end)
end
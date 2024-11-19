local RegisteredComponent = require(script.Parent.RegisteredComponent)

return function ()
    describe("RegisteredComponent", function()
        it("should store a name for the component", function()
            local testRegistered = RegisteredComponent.new("some_name", function() end)
            expect(testRegistered:getName()).to.be.equal("some_name")
        end)
        it("should store a builder provided while contructing", function()
            local builderCalled = false
            local testRegistered = RegisteredComponent.new("some_name", function()
                builderCalled = true
            end)
            testRegistered:build()

            expect(builderCalled).to.be.equal(true)
        end)
        it("should pass the arguments to the builder", function()
            local first, second, third
            local testRegistered = RegisteredComponent.new("some_name", function(arg1, arg2, arg3)
                first, second, third = arg1, arg2, arg3
            end)
            testRegistered:build("apple", "banana", "peer")

            expect(first).to.be.equal("apple")
            expect(second).to.be.equal("banana")
            expect(third).to.be.equal("peer")
        end)
        it("should call the builder on __call", function()
            local builderCalled = false
            local testRegistered = RegisteredComponent.new("some_name", function()
                builderCalled = true
            end)
            testRegistered()

            expect(builderCalled).to.be.equal(true)
        end)
    end)
end
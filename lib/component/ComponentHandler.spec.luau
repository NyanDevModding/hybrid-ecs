local ComponentHandler = require(script.Parent.ComponentHandler)

return function ()
    local someTestHandler
    local otherTestHandler

    beforeEach(function()
        someTestHandler = ComponentHandler.new({
            foo = function()
            end,
            bar = function()
            end
        })

        otherTestHandler = ComponentHandler.new({
            red = function()
            end,
            kir = function()
            end
        })
    end)

    local TestInterface = {
        isImplementedBy = function(self, t)
            for _, name in ipairs(self) do
                if t[name] == nil then
                    return false
                end
            end
            return true
        end
    }
    TestInterface.__index = TestInterface

    local kirTestInterface = setmetatable({
        "kir"
    }, TestInterface)

    describe("ComponentHandler", function()
        it("should define implementation of interface", function()
            expect(function()
                someTestHandler:implement(kirTestInterface)
            end).to.throw()
            
            expect(function()
                otherTestHandler:implement(kirTestInterface)
            end).never.to.throw()

            expect(otherTestHandler:isImplementing(kirTestInterface)).to.be.equal(true)
            expect(otherTestHandler._implements[1]).to.be.equal(kirTestInterface)
        end)
        it("should check if an handler implements an interface when it's not stored", function()
            -- even if the interface is not stored in handler._implements, the
            -- programm still read this handler to see if it implements it.
            expect(otherTestHandler:isImplementing(kirTestInterface)).to.be.equal(true)
        end)
        it("should throw if a methodName isn't a string", function()
            expect(function()
                someTestHandler:add(58, function() end)
            end).to.throw()
        end)
        it("should throw if a method isn't a function", function()
            expect(function()
                someTestHandler:add("someMethod", "this is not a function")
            end).to.throw()
        end)
        it("should allow the build of the handler to work like a class", function()
            local testHandler = ComponentHandler.new()
            function testHandler.someMethod()
            end

            expect(testHandler.implementation.someMethod).to.be.ok()
        end)
        describe("merging", function()
            it("should inherit the methods of the parents", function()
                local mergedHandler = ComponentHandler.merge(someTestHandler, otherTestHandler)

                expect(mergedHandler.implementation.foo).to.be.ok()
                expect(mergedHandler.implementation.bar).to.be.ok()
                expect(mergedHandler.implementation.red).to.be.ok()
                expect(mergedHandler.implementation.kir).to.be.ok()
            end)
            it("should inherit the interfaces of the parents", function()
                otherTestHandler:implement(kirTestInterface)
                local mergedHandler = ComponentHandler.merge(someTestHandler, otherTestHandler)

                expect(mergedHandler._implements[1]).to.be.equal(kirTestInterface)
            end)
            it("should accept more then 2 parents", function()
                local additionalHandler1 = ComponentHandler.new({
                    kee = function()
                    end
                })
                local additionalHandler2 = ComponentHandler.new({
                    feg = function()
                    end
                })

                local mergedHandler = ComponentHandler.merge(
                    someTestHandler,
                    otherTestHandler,
                    additionalHandler1,
                    additionalHandler2
                )

                expect(mergedHandler.implementation.foo).to.be.ok()
                expect(mergedHandler.implementation.bar).to.be.ok()
                expect(mergedHandler.implementation.red).to.be.ok()
                expect(mergedHandler.implementation.kir).to.be.ok()
                expect(mergedHandler.implementation.kee).to.be.ok()
                expect(mergedHandler.implementation.feg).to.be.ok()
            end)
            it("should take the method from the first parent if it is inherited from multiple parents", function()
                local yetAnotherTestHandler = ComponentHandler.new({
                    kir = function()
                        return "success"
                    end
                })

                local mergedHandler = ComponentHandler.merge(yetAnotherTestHandler, otherTestHandler)

                expect(mergedHandler.implementation.kir()).to.be.equal("success")
            end)
            it("shouldn't duplicate implements", function()
                otherTestHandler:implement(kirTestInterface)
                local yetAnotherTestHandler = ComponentHandler.new({
                    kir = function()
                    end
                }):implement(kirTestInterface)

                local mergedHandler = ComponentHandler.merge(otherTestHandler, yetAnotherTestHandler)

                expect(mergedHandler._implements[1]).to.be.equal(kirTestInterface)
                expect(mergedHandler._implements[2]).never.to.be.ok()
            end)
        end)
    end)
end
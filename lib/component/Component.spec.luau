local Component = require(script.Parent.Component)
local ComponentHandler = require(script.Parent.ComponentHandler)

return function ()
    describe("Component", function()
        describe("creating", function()
            it("should inherit the defaultDatas", function()
                local SOME_COMPONENT = Component.new(
                    "some",
                    {someValue = "default"}
                )

                local newComponent = SOME_COMPONENT()

                expect(newComponent.someValue).to.be.equal("default")
            end)
            it("shouldn't replace defined data with their default value", function()
                local SOME_COMPONENT = Component.new(
                    "some",
                    {someValue = "default"}
                )

                local newComponent = SOME_COMPONENT({
                    someValue = "non-default"
                })

                expect(newComponent.someValue).to.be.equal("non-default")
            end)
            it("should clone the data dictionnary", function()
                local SOME_COMPONENT = Component.new(
                    "some",
                    nil
                )

                local dataDict = {
                    data = "something"
                }
                local newComponent = SOME_COMPONENT(dataDict)

                expect(newComponent.data).to.be.equal("something")

                dataDict.data = "something_else"

                expect(newComponent.data).never.to.be.equal("something_else")
            end)
            it("should inherit from the componentIndex", function()
                local SOME_COMPONENT = Component.new(
                    "some"
                )

                local newComponent = SOME_COMPONENT()

                expect(getmetatable(newComponent).__index).to.be.ok()
            end)
            it("should get the component's handler metamethods", function()
                local SOME_COMPONENT = Component.new(
                    "some",
                    nil,
                    ComponentHandler.new({
                        __tostring = function()
                            return "string_component"
                        end
                    })
                )

                local newComponent = SOME_COMPONENT()

                expect(tostring(newComponent)).to.be.equal("string_component")
            end)
        end)
        describe("indexing", function()
            it("should point to the defaultHandler", function()
                local SOME_COMPONENT = Component.new("some")
                local someComponent = SOME_COMPONENT()
                expect(someComponent.patch).to.be.ok()
            end)
            it("should point to the handler", function()
                local handlerCalled = false
                local SOME_COMPONENT = Component.new(
                    "some",
                    nil,
                    ComponentHandler.new({
                        foo = function()
                            handlerCalled = true
                        end
                    })
                )

                expect(function()
                    SOME_COMPONENT():foo()
                end).never.to.throw()

                expect(handlerCalled).to.be.equal(true)
            end)
        end)
        describe("handler managing", function()
            it("should call the handler with self being the component", function()
                local SOME_COMPONENT = Component.new(
                    "some",
                    {handlerCalled = false},
                    ComponentHandler.new({
                        foo = function(self)
                            self.handlerCalled = true
                        end
                    })
                )

                local newComponent = SOME_COMPONENT()

                expect(function()
                    newComponent:foo()
                end).never.to.throw()

                expect(newComponent.handlerCalled).to.be.equal(true)
            end)
        end)
        describe("_defaultComponentImplementation", function()
            it("should allow the client to clone a componentInstance", function()
                local SOME_COMPONENT = Component.new("some")
                local someComponent = SOME_COMPONENT()

                local clone
                expect(function()
                    clone = someComponent:clone()
                end).never.to.throw()

                local same = true
                for k, v in pairs(clone) do
                    if someComponent[k] ~= v then
                        same = false
                    end
                end
                expect(same).to.be.equal(true)
            end)
            it("should allow the client to create a component from another (patch)", function()
                local SOME_COMPONENT = Component.new("some")
                local someComponent = SOME_COMPONENT({
                    a = "first",
                    b = "second"
                })

                local patched
                expect(function()
                    patched = someComponent:patch({
                        b = "not-second",
                        c = "third"
                    })
                end).never.to.throw()

                expect(someComponent.a).to.be.equal("first")
                expect(someComponent.b).to.be.equal("second")
                expect(someComponent.c).never.to.be.ok()

                expect(patched.a).to.be.equal("first")
                expect(patched.b).to.be.equal("not-second")
                expect(patched.c).to.be.equal("third")
            end)
            it("should throw when the given datas for patch are nil", function()
                local SOME_COMPONENT = Component.new("some")
                local someComponent = SOME_COMPONENT()

                expect(function()
                    someComponent:patch()
                end).to.throw()
            end)
        end)
    end)
end
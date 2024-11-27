local Component = require(script.Parent.Component)
local RegisteredComponent = require(script.Parent.RegisteredComponent)

local TestComponent = Component:extend()
do
    TestComponent.__index = TestComponent

    function TestComponent.new(v)
        return setmetatable({
            value = v
        }, TestComponent)
    end

    function TestComponent.getValue(self)
        return self.value
    end

    function TestComponent.formatClone(self, clone)
        clone.value = self.value
    end
end

return function ()
    local SOME_COMPONENT = RegisteredComponent.new(
        "some",
        function(v)
            return TestComponent.new(v)
        end
    )

    describe("Component", function()
        it("should let a child class extend it", function()            
            local child = Component:extend()

            expect(child.clone).to.be.ok()
            expect(child.destroy).to.be.ok()
        end)
        it("should be able to clone itself", function()
            local component = SOME_COMPONENT:build(5)
            local clone = component:clone()

            expect(component:getValue()).to.be.equal(5)
            expect(component:getValue()).to.be.equal(clone:getValue())
        end)
        describe("ComponentReference Integration", function()
            it("should always return a reference", function()
                local component = SOME_COMPONENT:build(55)

                expect(component:getReference()).to.be.ok()
                expect(component:getReference()).to.be.ok()
            end)
            it("should always return the same reference", function()
                local component = SOME_COMPONENT:build(55)

                local ref1, ref2 = component:getReference(), component:getReference()

                expect(ref1).to.be.equal(ref2)
            end)
            it("should reference the component", function()
                local component = SOME_COMPONENT:build(55)

                expect(component:getReference():get()).to.be.equal(component)
            end)
            it("should destroy the reference on destroyed", function()
                local component = SOME_COMPONENT:build(55)
                local ref = component:getReference()
                component:destroy()

                expect(ref:isNull()).to.be.equal(true)
            end)
            it("should point to the new reference on replacing", function()
                local c1 = SOME_COMPONENT:build(55)
                local c2 = SOME_COMPONENT:build(18)

                local ref1 = c1:getReference()
                local ref2 = c2:getReference()
                c1:onReplacing(c2)

                expect(ref2:get():getValue()).to.be.equal(c2:getValue())
                expect(ref1:get():getValue()).to.be.equal(c2:getValue())
            end)
            it("should duplicate the reference on clone", function()
                local c1 = SOME_COMPONENT:build(55)
                local ref1 = c1:getReference()

                local c2 = c1:clone()
                local ref2 = c2:getReference()

                expect(ref1).never.to.be.equal(ref2)
            end)
        end)
    end)
end
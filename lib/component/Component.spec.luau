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
end

return function ()
    local SOME_COMPONENT = RegisteredComponent.new("some", function(v)
        return TestComponent.new(v)
    end)

    describe("Component", function()
        it("should let a child class extend it", function()            
            local child = Component:extend()

            expect(child.clone).to.be.ok()
            expect(child.fuseWith).to.be.ok()
        end)
        it("should be able to clone itself", function()
            local component = SOME_COMPONENT:build(5)
            local clone = component:clone()

            expect(component:getValue()).to.be.equal(5)
            expect(component:getValue()).to.be.equal(clone:getValue())
        end)
    end)
end
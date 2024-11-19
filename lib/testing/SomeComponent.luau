local Component = require(script.Parent.Parent.component.Component)

local TestComponent = Component:extend()
TestComponent.__index = TestComponent

function TestComponent.new(v)
    return setmetatable({
        value = v
    }, TestComponent)
end

return TestComponent
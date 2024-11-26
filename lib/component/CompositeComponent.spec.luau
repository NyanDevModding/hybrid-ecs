local RegisteredMultiComponent = require(script.Parent.RegisteredMultiComponent)
local Component = require(script.Parent.Component)
local CompositeComponent = require(script.Parent.CompositeComponent)

local TestComponent = Component:extend()
do
    TestComponent.__index = TestComponent

    function TestComponent.new(v, v2)
        return setmetatable({
            value = v,
            secondValue = v2,
            removed = false
        }, TestComponent)
    end

    function TestComponent.getValue(self)
        return self.value
    end

    function TestComponent.getSecondValue(self)
        return self.secondValue
    end

    function TestComponent.formatClone(self, clone)
        -- Component.formatClone(self, clone)
        clone.value = self.value
        clone.secondValue = self.secondValue
    end

    function TestComponent.fuseWith(self, other)
        Component.fuseWith(self, other)
        self.value = if self.value ~= nil then self.value else other:getValue()
        self.secondValue = if self.secondValue ~= nil then self.secondValue else other:getSecondValue()
    end

    function TestComponent.onRemoved(self)
        self.removed = true
    end
end

return function ()
    local SOME_COMPONENT = RegisteredMultiComponent.new(
        "some",
        function(v, v2)
            return TestComponent.new(v, v2)
        end,
        function(builder, defaultComponents)
            local composite =  CompositeComponent.new(builder)

            if defaultComponents ~= nil then
                for _, component in ipairs(defaultComponents) do
                    composite:insert(component)
                end
            end

            return composite
        end
    )

    describe("CompositeComponent", function()
        describe("Components Management", function()
            it("should create a component from the builder", function()
                local testComposite = SOME_COMPONENT:buildComposite()
                testComposite:createAt(1, 5)
                testComposite:create(18)

                expect(testComposite:get(1):getValue()).to.be.equal(5)
                expect(testComposite:get(2):getValue()).to.be.equal(18)
            end)
            it("should directly store the components if they are passed to the constructor", function()
                local testComposite = SOME_COMPONENT:buildComposite({
                    SOME_COMPONENT:build(5),
                    SOME_COMPONENT:build(18),
                })

                expect(testComposite:get(1):getValue()).to.be.equal(5)
                expect(testComposite:get(2):getValue()).to.be.equal(18)
            end)
            it("should insert a built component", function()
                local testComposite = SOME_COMPONENT:buildComposite()
                testComposite:insertAt(1, SOME_COMPONENT:build(5))
                testComposite:insert(SOME_COMPONENT:build(18))

                expect(testComposite:get(1):getValue()).to.be.equal(5)
                expect(testComposite:get(2):getValue()).to.be.equal(18)
            end)
            it("should replace the component at a numero on insertion at this numero", function()
                local testComposite = SOME_COMPONENT:buildComposite()

                testComposite:insertAt(1, SOME_COMPONENT:build(5))
                expect(testComposite:get(1):getValue()).to.be.equal(5)

                testComposite:insertAt(1, SOME_COMPONENT:build(18))
                expect(testComposite:get(1):getValue()).to.be.equal(18)
            end)
            it("should use a numero that isn't used", function()
                local testComposite = SOME_COMPONENT:buildComposite()
                testComposite:insertAt(4, SOME_COMPONENT:build(4))

                testComposite:insert(SOME_COMPONENT:build(18))
                testComposite:insert(SOME_COMPONENT:build(19))
                testComposite:insert(SOME_COMPONENT:build(20))
                testComposite:insert(SOME_COMPONENT:build(21))

                expect(testComposite:get(4):getValue()).to.be.equal(4)
                expect(testComposite:get(1):getValue()).to.be.equal(18)
                expect(testComposite:get(2):getValue()).to.be.equal(19)
                expect(testComposite:get(3):getValue()).to.be.equal(20)
                expect(testComposite:get(5):getValue()).to.be.equal(21)
            end)
            it("should check if the composite component is empty", function()
                local testComposite = SOME_COMPONENT:buildComposite()
                testComposite:insertAt(5, SOME_COMPONENT:build())
                testComposite:insertAt(2, SOME_COMPONENT:build())
                testComposite:insertAt(18, SOME_COMPONENT:build())

                expect(testComposite:isEmpty()).to.be.equal(false)
            end)
            it("should remove the component for the provided numero", function()
                local testComposite = SOME_COMPONENT:buildComposite()
                testComposite:insertAt(2, SOME_COMPONENT:build())
                testComposite:insertAt(5, SOME_COMPONENT:build())
                testComposite:insertAt(18, SOME_COMPONENT:build())

                testComposite:removeAt(5)

                expect(testComposite:get(5)).never.to.be.ok()
            end)
            it("should iterate over its components", function()
                local testComposite = SOME_COMPONENT:buildComposite()
                local c1, c2, c3 =  SOME_COMPONENT:build(), SOME_COMPONENT:build(), SOME_COMPONENT:build()
                testComposite:insertAt(2, c1)
                testComposite:insertAt(5, c2)
                testComposite:insertAt(18, c3)

                local check1, check2, check3

                for numero, component in testComposite:iterate() do
                    if numero == 2 then
                        expect(check1).never.to.be.ok()
                        expect(component).to.be.equal(c1)
                        check1 = true
                    elseif numero == 5 then
                        expect(check2).never.to.be.ok()
                        expect(component).to.be.equal(c2)
                        check2 = true
                    elseif numero == 18 then
                        expect(check3).never.to.be.ok()
                        expect(component).to.be.equal(c3)
                        check3 = true
                    else
                        error("not expected numero while iterating over the composite component.")
                    end
                end

                expect(check1).to.be.equal(true)
                expect(check2).to.be.equal(true)
                expect(check3).to.be.equal(true)
            end)
            it("should count its components", function()
                local testComposite = SOME_COMPONENT:buildComposite()
                testComposite:insertAt(2, SOME_COMPONENT:build())
                testComposite:insertAt(5, SOME_COMPONENT:build())
                testComposite:insertAt(18, SOME_COMPONENT:build())

                expect(testComposite:getSize()).to.be.equal(3)
            end)
            it("should get a numero from a component", function()
                local testComposite = SOME_COMPONENT:buildComposite()
                local c1, c2, c3 = SOME_COMPONENT:build(), SOME_COMPONENT:build(), SOME_COMPONENT:build()
                testComposite:insertAt(2, c1)
                testComposite:insertAt(5, c2)
                testComposite:insertAt(18, c3)

                expect(testComposite:getNumero(c1)).to.be.equal(2)
                expect(testComposite:getNumero(c2)).to.be.equal(5)
                expect(testComposite:getNumero(c3)).to.be.equal(18)
            end)
            it("should call the onRemoved method when removing it from the composite", function()
                local testComposite = SOME_COMPONENT:buildComposite()
                local c1, c2, c3 = SOME_COMPONENT:build(), SOME_COMPONENT:build(), SOME_COMPONENT:build()
                testComposite:insertAt(2, c1)
                testComposite:insertAt(5, c2)
                testComposite:insertAt(18, c3)
                expect(c1.removed).to.be.equal(false)
                expect(c2.removed).to.be.equal(false)
                expect(c3.removed).to.be.equal(false)

                testComposite:removeAt(2, nil, nil, nil)

                expect(c1.removed).to.be.equal(true)
                expect(c2.removed).to.be.equal(false)
                expect(c3.removed).to.be.equal(false)

                testComposite:concreteClear()

                expect(c2.removed).to.be.equal(true)
                expect(c3.removed).to.be.equal(true)
            end)
        end)
        describe("Blank system", function()
            it("should store a blank component", function()
                local testComposite = SOME_COMPONENT:buildComposite()
                testComposite:insertAt(2, SOME_COMPONENT:build())
                testComposite:makeBlank(3)

                local num = testComposite:insert(SOME_COMPONENT:build())
                expect(num).to.be.equal(1)

                num = testComposite:insert(SOME_COMPONENT:build())
                expect(num).to.be.equal(4)
            end)
            it("should return nil and not BLANK", function()
                local testComposite = SOME_COMPONENT:buildComposite()
                testComposite:makeBlank(1)

                expect(testComposite:get(1)).never.to.be.ok()
            end)
            it("should ignore it while iterating", function()
                local testComposite = SOME_COMPONENT:buildComposite()
                testComposite:makeBlank(1)
                testComposite:insertAt(2, SOME_COMPONENT:build())
                testComposite:makeBlank(3)
                testComposite:makeBlank(5)

                for numero, _ in testComposite:iterate() do
                    expect(numero).to.be.equal(2)
                end
            end)
            it("should ignore it while calculating the number of components", function()
                local testComposite = SOME_COMPONENT:buildComposite()
                testComposite:insertAt(2, SOME_COMPONENT:build())
                testComposite:makeBlank(3)

                local num = testComposite:insert(SOME_COMPONENT:build())
                expect(num).to.be.equal(1)

                num = testComposite:insert(SOME_COMPONENT:build())
                expect(num).to.be.equal(4)
            end)
            it("should ignore it while calculating if the component is empty", function()
                local testComposite = SOME_COMPONENT:buildComposite()
                testComposite:makeBlank(1)
                testComposite:insertAt(2, SOME_COMPONENT:build())
                testComposite:makeBlank(4)
                testComposite:insertAt(5, SOME_COMPONENT:build())
                testComposite:makeBlank(14)
                testComposite:makeBlank(15)
                testComposite:insertAt(18, SOME_COMPONENT:build())
                testComposite:makeBlank(54)

                expect(testComposite:getSize()).to.be.equal(3)
            end)
            it("should consider it as an used numero while searching for a new numero", function()
                local testComposite = SOME_COMPONENT:buildComposite()
                testComposite:makeBlank(1)
                testComposite:insertAt(2, SOME_COMPONENT:build())
                testComposite:makeBlank(3)
                testComposite:makeBlank(4)
                testComposite:insertAt(5, SOME_COMPONENT:build())

                local num = testComposite:insert(SOME_COMPONENT:build())
                expect(num).to.be.equal(6)
            end)
            it("should clear only blanks", function()
                local testComposite = SOME_COMPONENT:buildComposite()
                testComposite:makeBlank(1)
                testComposite:insertAt(2, SOME_COMPONENT:build())
                testComposite:makeBlank(3)
                testComposite:makeBlank(4)
                testComposite:insertAt(5, SOME_COMPONENT:build())

                local num = testComposite:insert(SOME_COMPONENT:build())
                expect(num).to.be.equal(6)

                testComposite:clearBlank()
                num = testComposite:insert(SOME_COMPONENT:build())
                expect(num).to.be.equal(1)
            end)
        end)
        it("should fuse itself with another composite component", function()
            local firstComposite = SOME_COMPONENT:buildComposite()
            firstComposite:makeBlank(1)
            firstComposite:insertAt(2, SOME_COMPONENT:build())
            firstComposite:insertAt(5, SOME_COMPONENT:build("first"))

            local secondComposite = SOME_COMPONENT:buildComposite()
            secondComposite:insertAt(1, SOME_COMPONENT:build())
            secondComposite:insertAt(3, SOME_COMPONENT:build())
            secondComposite:insertAt(5, SOME_COMPONENT:build(nil, "second"))

            firstComposite:fuseWith(secondComposite)

            expect(firstComposite:get(1)).to.be.ok()
            expect(firstComposite:get(2)).to.be.ok()
            expect(firstComposite:get(3)).to.be.ok()
            expect(firstComposite:get(5):getValue()).to.be.equal("first")
            expect(firstComposite:get(5):getSecondValue()).to.be.equal("second")
        end)
        it("should clear only components and not blank", function()
            local testComposite = SOME_COMPONENT:buildComposite()
            testComposite:makeBlank(1)
            testComposite:insertAt(2, SOME_COMPONENT:build())
            testComposite:insertAt(5, SOME_COMPONENT:build())

            testComposite:concreteClear()
            local num = testComposite:insert(SOME_COMPONENT:build())
            expect(num).to.be.equal(2)
        end)
        it("should clear itself", function()
            local testComposite = SOME_COMPONENT:buildComposite()
            testComposite:makeBlank(1)
            testComposite:insertAt(2, SOME_COMPONENT:build())

            testComposite:forceClear()
            local num = testComposite:insert(SOME_COMPONENT:build())
            expect(num).to.be.equal(1)
            num = testComposite:insert(SOME_COMPONENT:build())
            expect(num).to.be.equal(2)
        end)
        it("should clone itself, all its components and blank values", function()
            local testComposite = SOME_COMPONENT:buildComposite()
            local c1, c2, c3 = SOME_COMPONENT:build(1), SOME_COMPONENT:build(2), SOME_COMPONENT:build(3)
            testComposite:makeBlank(1)
            testComposite:insertAt(2, c1)
            testComposite:insertAt(6, c2)
            testComposite:insertAt(8, c3)

            local clone = testComposite:clone()
            expect(clone:get(2)).never.to.be.equal(c1)
            expect(clone:get(2):getValue()).to.be.equal(c1:getValue())
            expect(clone:get(6)).never.to.be.equal(c2)
            expect(clone:get(6):getValue()).to.be.equal(c2:getValue())
            expect(clone:get(8)).never.to.be.equal(c3)
            expect(clone:get(8):getValue()).to.be.equal(c3:getValue())
            
            local num = clone:insert(SOME_COMPONENT:build())
            expect(testComposite:get(num)).to.be.equal(nil)
            expect(num).to.be.equal(3)
        end)
        it("should remove itself from the world if the check isn't valid", function()
            local mockCalled = false
            local worldMock = {
                remove = function(_, entityId : number, componentName : string)
                    mockCalled = true
                    expect(entityId).to.be.equal(55)
                    expect(componentName).to.be.equal(SOME_COMPONENT:getName())
                end
            }

            local testComposite = SOME_COMPONENT:buildComposite()
            -- some operations
            testComposite:insertAt(1, SOME_COMPONENT:build())
            testComposite:removeAt(1)

            testComposite:check(SOME_COMPONENT:getName(), 55, worldMock)
            expect(mockCalled).to.be.equal(true)
        end)
    end)
end
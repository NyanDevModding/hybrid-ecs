local Loop = require(script.Parent.Loop)

return function ()
    describe("Loop", function()
        it("should throw if begin is called when there is no event bound", function()
            local loop = Loop.new()

            expect(function()
                loop:begin()
            end).to.throw()
        end)
        it("should throw if stop is called when there is no event bound", function()
            -- you should not be able to manage to stop without any event.
            local loop = Loop.new()

            expect(function()
                loop:stop()
            end).to.throw()
        end)
    end)
end
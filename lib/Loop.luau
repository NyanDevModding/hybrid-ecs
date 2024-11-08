--[=[
    @class Loop

    Loop is an object that fires a given list of systems onto a world. It
    ticks depending on the event it is bound to and caches the queries called
    by those systems.
]=]
local Loop = {}
Loop.__index = Loop

export type LoopClass = typeof(Loop)
export type Loop = typeof(Loop.new())

local ERROR_STR_ALREADY_CONNECTED = "The loop on which you called the "
.. "useEvent method is already connected to another event."
local ERROR_STR_NOT_CONNECTED = "The loop on which you called the %s method "
.. "is not connected to any event, please check that you called the useEvent method "
.. "primarly."

local function onEvent(loop : Loop)
    loop.world:startCaching()
    for _, system in ipairs(loop.systems) do
        system(loop.world)
    end
    loop.world:stopCaching()
end

--[=[
    @within Loop
    @function new
    @param world World -- the world on which the systems are called
    @param systems {(world : any) -> nil} -- the systems to call
    @return Loop

    Create a new Loop with the given world and systems.

    Loop is an object that fires a given list of systems onto a world. It
    ticks depending on the event it is bound to and caches the queries called
    by those systems.
]=]
function Loop.new(world, systems : {(world : any) -> nil})
    return setmetatable({
        world = world,
        looping = false,
        systems = systems,
        event = nil,
        eventConnection = nil
    }, Loop)
end

--[=[
    @within Loop
    @function useEvent
    @param event RBXScriptSignal -- the event to
    bind to the loop
    @return Loop

    Bind the loop to the provided event.
]=]
function Loop.useEvent(self : Loop, event : RBXScriptSignal)
    assert(self.event == nil, ERROR_STR_ALREADY_CONNECTED)
    self.event = event
end

--[=[
    @within begin
    @function useEvent

    Launch the loop.
]=]
function Loop.begin(self : Loop)
    assert(self.event ~= nil, string.format(ERROR_STR_NOT_CONNECTED, "start"))
    self.looping = true
    self.eventConnection = self.event:Connect(function()
        onEvent(self)
    end)
end

--[=[
    @within begin
    @function useEvent

    Stop the loop, it can be relaunched at any time.
]=]
function Loop.stop(self : Loop)
    assert(self.eventConnection ~= nil, string.format(ERROR_STR_NOT_CONNECTED, "stop"))
    self.eventConnection:Disconnect()
    self.eventConnection = nil
    self.looping = false
end

return Loop
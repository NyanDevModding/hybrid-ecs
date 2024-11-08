local World = require(script.Parent.world.World)

--[=[
    @class EntityLink

    An EntityLink stores information or a reference to an entityId, this
    encapsulates the reference and thus let the id be changed if the entities
    are moved from a world to another.
]=]
local EntityLink = {}
EntityLink.__index = EntityLink

export type EntityLinkClass = typeof(EntityLink)
export type EntityLink = typeof(EntityLink.new())

local ERROR_STR_NOT_LINKED = "You have to call _linkTo on the entityLink of "
.. "the entity #%i before calling individual unlink on the other. Trying to "
.. "connect to the entityLink of the entity #%i. Please use only the linkWith() method."
local ERROR_STR_NOT_UNLINKED = "You have to call _unlink on the entityLink of "
.. "the entity #%i before calling individual unlink on the other. Trying to "
.. "disconnect from the entityLink of the entity #%i. Please use only the unlink() method."

--[=[
    @within EntityLink
    @function new
    @param entityId number -- the entity that contains the entityLink
    @param onLinked ((self : EntityLink, otherEntityId : number) -> nil)? -- an
    hook that will fire when the entitylink is linked
    @param onUnlinked ((self : EntityLink, otherEntityId : number) -> nil)? --
    an hook that will fire when the entitylink is unlinked
    @return Entitylink -- the new instance

    Create a new EntityLink.

    An EntityLink stores information or a reference to an entityId, this
    encapsulates the reference and thus let the id be changed if the entities
    are moved from a world to another.
]=]
function EntityLink.new(entityId : number,
    onLinked : ((self : EntityLink) -> nil)?,
    onUnlinked : ((self : EntityLink, otherEntityId : number) -> nil)?)

    return setmetatable({
        _entityId = entityId,
        _onLinked = onLinked,
        _onUnlinked = onUnlinked,
        _otherEntityLink = nil :: EntityLink?
    }, EntityLink)
end

--[=[
    @within EntityLink
    @function fromJson

    --TODO

    Create a new EntityLink from a json.
]=]
function EntityLink.fromJson()
end

--[=[
    @within EntityLink
    @function getId
    @return number -- the id of the entity

    Return the id of the entity that contains this entityLink
]=]
function EntityLink.getId(self : EntityLink) : number
    return self._entityId
end

--[=[
    @within EntityLink
    @function getOthersId
    @return number? -- the id of the entity

    Return the id of the other entity, linked to this one.
]=]
function EntityLink.getOthersId(self : EntityLink) : number?
    if self._otherEntityLink == nil then
        return nil
    end

    return self._otherEntityLink:getId()
end

--[=[
    @within EntityLink
    @function getOther
    @param world World -- the world that contains the entities
    @return number? -- the id of the entity

    Return the id of the other entity, linked to this one.
]=]
function EntityLink.getOther(self : EntityLink, world : World.World) : World.EntityMirror
    local othersId = self:getOthersId()
    if othersId == nil then
        return nil
    end
    return world:get(othersId)
end

--[=[
    @within EntityLink
    @function isLinked
    @return boolean -- if the entityLink is in a linked state

    Return if the entityLink is in a linked state or not
]=]
function EntityLink.isLinked(self : EntityLink)
    return self._otherEntityLink ~= nil
end

--[=[
    @within EntityLink
    @function _linkTo
    @param otherEntityLink EntityLink -- the entityLink to link

    Link the entityLink to another entityLink
]=]
function EntityLink._linkTo(self : EntityLink, otherEntityLink : EntityLink)
    if self._otherEntityLink ~= nil then
        self:unlink()
    end

    self._otherEntityLink = otherEntityLink
end

--[=[
    @within EntityLink
    @function individualLink
    @param otherEntityLink EntityLink -- the entityLink to link

    Link the entityLink to another entityLink, asserts if the other is linked
    to it and calls the hook

    :::caution
        this method should only be called from a :linkWith().
    :::
]=]
function EntityLink.individualLink(self : EntityLink, otherEntityLink)
    assert(
        otherEntityLink._otherEntityLink == self,
        string.format(
            ERROR_STR_NOT_LINKED,
            self._entityId,
            otherEntityLink:getId()
        )
    )

    self:_linkTo(otherEntityLink)

    -- calls onLinked
    if self._onLinked ~= nil then
        self:_onLinked()
    end
end

--[=[
    @within EntityLink
    @function linkWith
    @param otherEntityLink EntityLink -- the entityLink to link

    Link both of the entityLinks, itself and the provided one.
]=]
function EntityLink.linkWith(self : EntityLink, otherEntityLink : EntityLink)
    self:_linkTo(otherEntityLink)
    -- link the other entityLink and calls _onLinked on it
    otherEntityLink:individualLink(self)

    -- calls onLinked on itself.
    if self._onLinked ~= nil then
        self:_onLinked()
    end
end

--[=[
    @within EntityLink
    @function _unlink

    Unlink the entityLink from any link.
]=]
function EntityLink._unlink(self : EntityLink)
    self._otherEntityLink = nil
end

--[=[
    @within EntityLink
    @function individualUnlink

    Unlink the entityLink from its linked entityLink, asserts if the other is
    unlinked and calls the hook

    :::caution
        this method should only be called from a :unlinkFrom().
    :::
]=]
function EntityLink.individualUnlink(self : EntityLink)
    local otherEntityLink = self._otherEntityLink
    assert(
        otherEntityLink._otherEntityLink == nil,
        string.format(
            ERROR_STR_NOT_UNLINKED,
            otherEntityLink:getId(),
            self._entityId
        )
    )

    self:_unlink()

    if self._onUnlinked ~= nil then
        self:_onUnlinked(otherEntityLink:getId())
    end
end

--[=[
    @within EntityLink
    @function unlinkFrom

    Link both of the entityLinks.
]=]
function EntityLink.unlinkFrom(self : EntityLink)
    local otherEntityLink = self._otherEntityLink
    self:_unlink()
    -- calls onUnlinked if there is one on the other EntityId
    otherEntityLink:individualUnlink()

    -- calls onUnlinked on itself.
    if self._onUnlinked ~= nil then
        self:_onUnlinked(otherEntityLink:getId())
    end
end

--[=[
    @within EntityLink
    @function toJson

    Create a json of the entityLink.
]=]
function EntityLink.toJson()
end

return EntityLink
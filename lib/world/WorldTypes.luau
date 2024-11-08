local Component = require(script.Parent.Parent.component.Component)

export type defaultComponentInstance = Component.genericComponent<any, {(...any) -> any}>

export type entity = {[string] : defaultComponentInstance}

export type storageChunk = {[number] : entity}
export type storage = {[number] : storageChunk}

return {}
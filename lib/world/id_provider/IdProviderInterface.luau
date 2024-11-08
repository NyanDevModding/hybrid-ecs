export type IdProviderInterface = {
    getNextId : (self : IdProviderInterface) -> number,
    setNextId : (self : IdProviderInterface, id : number) -> nil,
    useId : (self : IdProviderInterface, id : number) -> nil,
    useNextId : (self : IdProviderInterface) -> number,
    unuseId : (self : IdProviderInterface, id : number) -> nil,
    clone : (self : IdProviderInterface) -> IdProviderInterface,
    recycle : (self : IdProviderInterface) -> nil
}

return {}
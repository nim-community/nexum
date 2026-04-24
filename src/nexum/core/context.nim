## Nexum Context — Component instance context and dependency injection.

import std/[tables, json]

type
  Context* = ref object
    parent*: Context
    store*: Table[string, pointer]      ## type-erased for flexibility
    keys*: Table[string, string]        ## metadata keys (e.g., island id)
    jsonStore*: Table[string, JsonNode] ## JSON-serializable props for SSR

proc newContext*(parent: Context = nil): Context =
  Context(parent: parent)

proc set*[T](ctx: Context; key: string; value: T) =
  ctx.store[key] = cast[pointer](value)

proc get*[T](ctx: Context; key: string): T =
  if key in ctx.store:
    return cast[T](ctx.store[key])
  if ctx.parent != nil:
    return ctx.parent.get[:T](key)
  raise newException(KeyError, "Context key not found: " & key)

proc setProp*(ctx: Context; key: string; value: JsonNode) =
  ctx.jsonStore[key] = value

proc propsToJson*(ctx: Context): string =
  result = $ctx.jsonStore

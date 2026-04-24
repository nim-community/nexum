## Helix Macros — @component and @island decorators.

import std/macros

# ---------------------------------------------------------------------------
# @component
# ---------------------------------------------------------------------------

macro component*(p: untyped): untyped =
  ## Marks a proc as a Helix component.
  ## Wraps the body in a fresh Scope so that effects and cleanups
  ## are isolated per component instance.
  expectKind(p, nnkProcDef)
  result = p
  let body = p[^1]
  if body.kind == nnkEmpty:
    return
  # Wrap body in runInScope(newScope())
  let wrapped = newCall(
    ident"runInScope",
    newCall(ident"newScope"),
    newProc(body = body, procType = nnkLambda)
  )
  result[^1] = newStmtList(wrapped)

# ---------------------------------------------------------------------------
# @island
# ---------------------------------------------------------------------------

macro island*(p: untyped): untyped =
  ## Marks a proc as an interactive island.
  ## On the client, registers a hydration factory so that
  ## hydrateDocument() can attach signal bindings to the SSR'd DOM.
  expectKind(p, nnkProcDef)

  # Define the proc normally
  result = newStmtList()
  result.add(p)

  when defined(js):
    let name = $p[0]
    # Register a hydration factory that reuses the existing SSR DOM.
    # It runs the component proc with DOM creation intercepted so that
    # `document.createElement` / `createTextNode` return existing nodes
    # from the SSR tree instead of creating fresh ones. Effects and event
    # listeners are thereby attached directly to the preserved DOM.
    let factory = newProc(
      params = @[newEmptyNode(),
        newIdentDefs(ident"props", ident"JsonNode"),
        newIdentDefs(ident"root", ident"Element")],
      body = newTree(nnkTryStmt,
        newStmtList(
          newCall(ident"startHydration", ident"root"),
          newCall(ident(name))
        ),
        newTree(nnkFinally,
          newStmtList(
            newCall(ident"stopHydration")
          )
        )
      ),
      procType = nnkLambda
    )
    let regCall = newCall(ident"registerIsland", newLit(name), factory)
    result.add(regCall)

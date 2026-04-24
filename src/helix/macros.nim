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
    # Add module-level registration of the hydration factory.
    # For now the factory does a fresh mount (true hydration walk is TODO).
    let factory = newProc(
      params = @[newEmptyNode(),
        newIdentDefs(ident"props", ident"JsonNode"),
        newIdentDefs(ident"root", ident"Element")],
      body = newStmtList(
        newAssignment(
          newDotExpr(ident"root", ident"innerHTML"),
          newCall(ident"cstring", newLit"")
        ),
        newCall(
          newDotExpr(ident"root", ident"appendChild"),
          newCall(ident(name))
        )
      ),
      procType = nnkLambda
    )
    let regCall = newCall(ident"registerIsland", newLit(name), factory)
    result.add(regCall)

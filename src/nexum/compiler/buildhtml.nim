## Nexum Compiler — buildHtml macro
##
## The user-facing macro that turns a DSL block into either DOM code (JS)
## or HTML string code (native).

import std/macros
import parser, analyzer, codegen_client, codegen_server

macro buildHtml*(body: untyped): untyped =
  ## Parses a `buildHtml:` block and generates:
  ## - On JS backend: DOM creation code that returns a `Node`
  ## - On native backend: HTML string building code that returns a `string`
  let ir = parseBuildHtml(body)
  let analysis = analyze(ir)

  let clientCode = genClient(ir, analysis)

  # Server: wrap codegen in a fresh RenderContext and return its buffer
  let serverCode = genServer(ir, analysis)
  var serverWrapped = newStmtList()
  serverWrapped.add(newTree(nnkVarSection,
    newIdentDefs(ident"ctx", ident"RenderContext", newCall(ident"newRenderContext"))
  ))
  for s in serverCode:
    serverWrapped.add(s)
  serverWrapped.add(newDotExpr(ident"ctx", ident"buf"))

  result = newStmtList(
    newTree(nnkWhenStmt,
      newTree(nnkElifBranch,
        newCall("defined", newIdentNode("js")),
        clientCode
    ),
    newTree(nnkElse,
      serverWrapped
    )
  )
  )

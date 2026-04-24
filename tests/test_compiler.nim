## Minimal compile-time test for the Helix compiler layer.
##
## Exercises parser, analyzer, and both codegen paths inside a macro
## so that generated JS-only code never reaches the C backend.

import std/[macros, json]
import helix/compiler/[parser, analyzer, codegen_client, codegen_server]

macro testCompiler() =
  # -----------------------------------------------------------------------
  # 1. Parse a realistic template fragment
  # -----------------------------------------------------------------------
  let ast = quote do:
    tdiv(class = "x", id = "y"):
      span "hello"
      "world"
      MyComp(foo = "bar")

  let ir = parseBuildHtml(ast)
  doAssert ir.kind == nkFragment
  doAssert ir.fragmentChildren.len == 1

  let divNode = ir.fragmentChildren[0]
  doAssert divNode.kind == nkElement
  doAssert divNode.tag == "tdiv"
  doAssert divNode.attrs.len == 2
  doAssert divNode.children.len == 3

  # -----------------------------------------------------------------------
  # 2. Analyze
  # -----------------------------------------------------------------------
  let analysis = analyze(ir)
  doAssert not analysis.hasDynamicText
  doAssert not analysis.hasDynamicAttrs
  doAssert not analysis.hasEvents
  doAssert not analysis.hasIslands

  # -----------------------------------------------------------------------
  # 3. Client codegen produces a statement list
  # -----------------------------------------------------------------------
  let clientCode = genClient(ir, analysis)
  doAssert clientCode.kind == nnkStmtList

  # -----------------------------------------------------------------------
  # 4. Server codegen produces a statement list
  # -----------------------------------------------------------------------
  let serverCode = genServer(ir, analysis)
  doAssert serverCode.kind == nnkStmtList

  # -----------------------------------------------------------------------
  # 5. String concatenation → nkText with textExpr
  # -----------------------------------------------------------------------
  let ast2 = quote do:
    "hello" & name
  let ir2 = parseBuildHtml(ast2)
  doAssert ir2.fragmentChildren.len == 1
  doAssert ir2.fragmentChildren[0].kind == nkText
  doAssert ir2.fragmentChildren[0].textExpr != nil

  # -----------------------------------------------------------------------
  # 6. Uppercase call → nkComponent
  # -----------------------------------------------------------------------
  let ast3 = quote do:
    MyComp(foo = "bar")
  let ir3 = parseBuildHtml(ast3)
  doAssert ir3.fragmentChildren.len == 1
  doAssert ir3.fragmentChildren[0].kind == nkComponent
  doAssert ir3.fragmentChildren[0].compType == "MyComp"

  # -----------------------------------------------------------------------
  # 7. Event attribute → avEvent
  # -----------------------------------------------------------------------
  let ast4 = quote do:
    button(onclick = handler):
      "Click me"
  let ir4 = parseBuildHtml(ast4)
  doAssert ir4.fragmentChildren[0].kind == nkElement
  doAssert ir4.fragmentChildren[0].attrs.len == 1
  doAssert ir4.fragmentChildren[0].attrs[0].kind == avEvent

  # Expand to nothing at the call site
  result = newStmtList()

testCompiler()

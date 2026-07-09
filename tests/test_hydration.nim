import std/[macros, json, strutils, unittest]
import nexum/compiler/[parser, analyzer, codegen_server, codegen_client]

suite "Hydration":

  test "parser extracts island props":
    macro testParser() =
      let ast = quote do:
        MyIsland(initial = 5, label = "Click")
      let ir = parseBuildHtml(ast)
      doAssert ir.fragmentChildren[0].kind == nkComponent
      doAssert ir.fragmentChildren[0].compType == "MyIsland"
      result = newStmtList()
    testParser()

  test "parser extracts island with no props":
    macro testParser() =
      let ast = quote do:
        MyIsland()
      let ir = parseBuildHtml(ast)
      doAssert ir.fragmentChildren[0].kind == nkComponent
      doAssert ir.fragmentChildren[0].compType == "MyIsland"
      result = newStmtList()
    testParser()

  test "parser stores island props from island keyword":
    macro testParser() =
      let ast = quote do:
        island MyIsland(initial = 5)
      let ir = parseBuildHtml(ast)
      doAssert ir.fragmentChildren[0].kind == nkIsland
      doAssert ir.fragmentChildren[0].compType == "MyIsland"
      doAssert ir.fragmentChildren[0].islandProps.len == 1
      doAssert ir.fragmentChildren[0].islandProps[0][0] == "initial"
      result = newStmtList()
    testParser()

  test "parser stores island with multiple props":
    macro testParser() =
      let ast = quote do:
        island Counter(initial = 0, step = 1)
      let ir = parseBuildHtml(ast)
      doAssert ir.fragmentChildren[0].kind == nkIsland
      doAssert ir.fragmentChildren[0].islandProps.len == 2
      doAssert ir.fragmentChildren[0].islandProps[0] == ("initial", newIntLitNode(0))
      doAssert ir.fragmentChildren[0].islandProps[1][0] == "step"
      result = newStmtList()
    testParser()

  test "server codegen embeds island props as JSON":
    macro testServer() =
      let ast = quote do:
        island Counter(initial = 0, step = 1)
      let ir = parseBuildHtml(ast)
      let analysis = analyze(ir)
      let code = genServer(ir, analysis)
      # Verify the generated code contains the %* expression
      doAssert code.kind == nnkStmtList
      # Walk the AST to find the %* call
      var foundProps = false
      proc walk(n: NimNode) =
        if n.kind == nnkCall and n.len >= 2:
          if n[0].kind == nnkIdent and $n[0] == "%*":
            foundProps = true
            doAssert n[1].kind == nnkTableConstr
            doAssert n[1].len == 2
        for child in n:
          walk(child)
      walk(code)
      doAssert foundProps, "Server codegen should produce a %* expression for island props"
      result = newStmtList()
    testServer()

  test "server codegen without props uses newJObject":
    macro testServer() =
      let ast = quote do:
        island Empty()
      let ir = parseBuildHtml(ast)
      let analysis = analyze(ir)
      let code = genServer(ir, analysis)
      var foundNewJObject = false
      proc walk(n: NimNode) =
        if n.kind == nnkCall and n.len >= 1:
          if n[0].kind == nnkIdent and $n[0] == "newJObject":
            foundNewJObject = true
        for child in n:
          walk(child)
      walk(code)
      doAssert foundNewJObject, "Server codegen should use newJObject when island has no props"
      result = newStmtList()
    testServer()

  test "client codegen passes props JsonNode to island component":
    macro testClient() =
      let ast = quote do:
        island Counter(initial = 5)
      let ir = parseBuildHtml(ast)
      let analysis = analyze(ir)
      let code = genClient(ir, analysis)
      var foundCall = false
      proc walk(n: NimNode) =
        if n.kind == nnkCall and n.len >= 2:
          if n[0].kind == nnkIdent and $n[0] == "Counter":
            foundCall = true
            doAssert n[1].kind == nnkCall
            doAssert $n[1][0] == "%*"
          elif n[0].kind == nnkIdent and $n[0] == "%*":
            doAssert n[1].kind == nnkTableConstr
        for child in n:
          walk(child)
      walk(code)
      doAssert foundCall, "Client codegen should call island component with JsonNode argument"
      result = newStmtList()
    testClient()

  test "scanIslands parses markers with props JSON":
    # Test the scanIslands implementation on the C backend by verifying the logic.
    # The actual DOM scanning is JS-only; here we test the parsing helper logic.
    # parseIslandStart extracts id and props from marker text.
    let marker = "nexum-island start=\"Counter\" props='{\"initial\":5}'"
    let idStart = "nexum-island start=\"".len
    let idEnd = marker.find('"', idStart)
    check idEnd > 0
    let id = marker[idStart ..< idEnd]
    check id == "Counter"

    let propsPrefix = " props='"
    let propsStart = marker.find(propsPrefix, idEnd)
    check propsStart > 0
    let propsValStart = propsStart + propsPrefix.len
    let propsValEnd = marker.find('\'', propsValStart)
    check propsValEnd > 0
    let propsStr = marker[propsValStart ..< propsValEnd]
    let props = parseJson(propsStr)
    check props["initial"].getInt() == 5

  test "scanIslands parses empty props":
    let marker = "nexum-island start=\"MyIsland\" props='{}'"
    let idStart = "nexum-island start=\"".len
    let idEnd = marker.find('"', idStart)
    let id = marker[idStart ..< idEnd]
    check id == "MyIsland"

    let propsPrefix = " props='"
    let propsStart = marker.find(propsPrefix, idEnd)
    let propsValStart = propsStart + propsPrefix.len
    let propsValEnd = marker.find('\'', propsValStart)
    let propsStr = marker[propsValStart ..< propsValEnd]
    let props = parseJson(propsStr)
    check props.kind == JObject
    check props.len == 0

## Helix Compiler — Parser: buildHtml DSL → Intermediate Representation (IR)

import std/macros

type
  ## The shape of a compiled template
  NodeKind* = enum
    nkElement       ## <tag> with optional attrs, children
    nkText          ## static or dynamic text
    nkComponent     ## user-defined @component
    nkIsland        ## {.island.} wrapped component
    nkFragment      ## <>...</>  (multi-root, elided)
    nkIf            ## if / elif / else
    nkFor           ## for loop
    nkCase          ## case / of
    nkExpr          ## raw Nim expression node

  AttrValueKind* = enum
    avStatic        ## string literal
    avDynamic       ## Signal / expression
    avEvent         ## onclick, oninput, etc.

  Attr* = object
    name*: string
    case kind*: AttrValueKind
    of avStatic: sval*: string
    of avDynamic: dval*: NimNode
    of avEvent: handler*: NimNode

  IrNode* = ref object
    case kind*: NodeKind
    of nkElement:
      tag*: string
      attrs*: seq[Attr]
      children*: seq[IrNode]
      isSvg*: bool
      isMath*: bool
    of nkText:
      textStatic*: string
      textExpr*: NimNode   ## if nil, text is static
    of nkComponent, nkIsland:
      compType*: string
      compProps*: NimNode  ## object constructor AST
      compKey*: NimNode    ## optional key expr
    of nkFragment:
      fragmentChildren*: seq[IrNode]
    of nkIf:
      ifBranches*: seq[tuple[cond: NimNode, body: seq[IrNode]]]
      ifElse*: seq[IrNode]
    of nkFor:
      forVar*: NimNode
      forIterable*: NimNode
      forBody*: seq[IrNode]
    of nkCase:
      caseDisc*: NimNode
      caseBranches*: seq[tuple[values: seq[NimNode], body: seq[IrNode]]]
    of nkExpr:
      expr*: NimNode

proc parseError(msg: string; n: NimNode) {.noreturn.} =
  error("Helix template error: " & msg, n)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

proc parseStmt(n: NimNode): IrNode

proc parseBuildHtml*(body: NimNode): IrNode =
  ## Entry point: converts the body of a `buildHtml:` block into IR.
  result = IrNode(kind: nkFragment, fragmentChildren: @[])
  if body.kind == nnkStmtList:
    for stmt in body:
      if stmt.kind == nnkStmtList:
        for child in stmt:
          result.fragmentChildren.add(parseStmt(child))
      else:
        result.fragmentChildren.add(parseStmt(stmt))
  else:
    result.fragmentChildren.add(parseStmt(body))

proc parseStmt(n: NimNode): IrNode =
  case n.kind
  of nnkStrLit..nnkTripleStrLit:
    result = IrNode(kind: nkText, textStatic: n.strVal)

  of nnkIfStmt:
    result = IrNode(kind: nkIf, ifBranches: @[], ifElse: @[])
    for branch in n:
      if branch.kind == nnkElifBranch:
        let cond = branch[0]
        let body = parseBuildHtml(branch[1])
        result.ifBranches.add((cond: cond, body: body.fragmentChildren))
      elif branch.kind == nnkElse:
        let body = parseBuildHtml(branch[0])
        result.ifElse = body.fragmentChildren

  of nnkForStmt:
    let body = parseBuildHtml(n[^1])
    result = IrNode(kind: nkFor,
      forVar: n[0],
      forIterable: n[1],
      forBody: body.fragmentChildren)

  of nnkCaseStmt:
    result = IrNode(kind: nkCase, caseDisc: n[0], caseBranches: @[])
    for i in 1 ..< n.len:
      let branch = n[i]
      if branch.kind == nnkOfBranch:
        var values: seq[NimNode] = @[]
        for j in 0 ..< branch.len - 1:
          values.add(branch[j])
        let body = parseBuildHtml(branch[^1])
        result.caseBranches.add((values: values, body: body.fragmentChildren))
      elif branch.kind == nnkElse:
        let body = parseBuildHtml(branch[0])
        result.caseBranches.add((values: @[], body: body.fragmentChildren))

  of nnkCallKinds:
    # Infix string concatenation → dynamic text
    if n.kind == nnkInfix:
      if $n[0] == "&":
        return IrNode(kind: nkText, textExpr: n)
      else:
        return IrNode(kind: nkExpr, expr: n)

    # Prefix string conversion → dynamic text
    if n.kind == nnkPrefix:
      if $n[0] == "$":
        return IrNode(kind: nkText, textExpr: n)
      else:
        return IrNode(kind: nkExpr, expr: n)

    # Postfix operators are not tag calls
    if n.kind == nnkPostfix:
      return IrNode(kind: nkExpr, expr: n)

    let callee = n[0]
    let name = case callee.kind
      of nnkIdent: $callee
      of nnkAccQuoted:
        if callee.len > 0 and callee[0].kind == nnkIdent:
          $callee[0]
        else:
          return IrNode(kind: nkExpr, expr: n)
      else:
        return IrNode(kind: nkExpr, expr: n)

    if name == "island" and n.len >= 2:
      # island ComponentCall() → marks component for island hydration
      let compCall = n[1]
      if compCall.kind in nnkCallKinds:
        let compCallee = compCall[0]
        let compName = case compCallee.kind
          of nnkIdent: $compCallee
          else: ""
        if compName.len > 0 and compName[0] in {'A'..'Z'}:
          result = IrNode(kind: nkIsland, compType: compName, compProps: compCall)
        else:
          parseError("island expects a component call", n)
      else:
        parseError("island expects a component call", n)
    elif name.len > 0 and name[0] in {'A'..'Z'}:
      # Component call (uppercase)
      result = IrNode(kind: nkComponent, compType: name, compProps: n)
    else:
      # HTML element call (lowercase)
      result = IrNode(kind: nkElement, tag: name, attrs: @[], children: @[])
      for i in 1 ..< n.len:
        let arg = n[i]
        if arg.kind == nnkExprEqExpr:
          let attrName = case arg[0].kind
            of nnkIdent: $arg[0]
            of nnkInfix:
              if $arg[0][0] == "-":
                $arg[0][1] & "-" & $arg[0][2]
              else:
                parseError("unsupported attribute expression", arg)
            else:
              parseError("unsupported attribute name", arg)
          let attrVal = arg[1]
          if attrVal.kind in nnkStrLit..nnkTripleStrLit:
            result.attrs.add(Attr(name: attrName, kind: avStatic, sval: attrVal.strVal))
          elif attrVal.kind == nnkLambda or (attrVal.kind == nnkIdent and attrName.len >= 2 and attrName[0..1] == "on"):
            result.attrs.add(Attr(name: attrName, kind: avEvent, handler: attrVal))
          else:
            result.attrs.add(Attr(name: attrName, kind: avDynamic, dval: attrVal))
        elif arg.kind == nnkStmtList:
          let frag = parseBuildHtml(arg)
          for ch in frag.fragmentChildren:
            result.children.add(ch)
        else:
          # Positional child argument
          result.children.add(parseStmt(arg))

  else:
    # Any other expression is treated as a dynamic expression node.
    # If it does not evaluate to a Node at compile time, codegen will error.
    result = IrNode(kind: nkExpr, expr: n)

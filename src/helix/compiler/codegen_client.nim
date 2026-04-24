## Helix Compiler — Client Codegen: IR → DOM + Signal effects.
##
## Generates code like:
##   let n0 = document.createElement("div")
##   let n1 = document.createTextNode("")
##   n0.appendChild(n1)
##   createEffect(proc() = n1.textContent = $count())

import std/[macros, strutils]
import parser, analyzer

type
  ClientGenState* = object
    varCounter*: int

proc nextVar(s: var ClientGenState; prefix = "n"): string =
  result = prefix & $s.varCounter
  inc s.varCounter

proc genNode(ir: IrNode; state: var ClientGenState; parentVar: string;
             stmts: var seq[NimNode]): string =
  case ir.kind
  of nkElement:
    let varName = state.nextVar()
    stmts.add(newLetStmt(
      ident(varName),
      newCall(newDotExpr(ident"document", ident"createElement"), newLit(ir.tag))
    ))

    for at in ir.attrs:
      case at.kind
      of avStatic:
        stmts.add(newCall(
          newDotExpr(ident(varName), ident"setAttr"),
          newLit(at.name), newLit(at.sval)
        ))
      of avDynamic:
        let effectBody = newStmtList(
          newCall(
            newDotExpr(ident(varName), ident"setAttr"),
            newLit(at.name),
            newCall(ident"cstring", newCall(ident"$", at.dval))
          )
        )
        stmts.add(newCall(
          ident"createEffect",
          newProc(body = effectBody, procType = nnkLambda)
        ))
      of avEvent:
        var evName = at.name
        if evName.startsWith("on") and evName.len > 2:
          evName = evName[2..^1]
        stmts.add(newCall(
          newDotExpr(ident(varName), ident"addEventListener"),
          newLit(evName), at.handler
        ))

    for ch in ir.children:
      discard genNode(ch, state, varName, stmts)

    if parentVar != "":
      stmts.add(newCall(
        newDotExpr(ident(parentVar), ident"appendChild"),
        ident(varName)
      ))
    result = varName

  of nkText:
    let varName = state.nextVar()
    if ir.textExpr != nil:
      stmts.add(newLetStmt(
        ident(varName),
        newCall(newDotExpr(ident"document", ident"createTextNode"), newLit"")
      ))
      let effectBody = newStmtList(
        newAssignment(
          newDotExpr(ident(varName), ident"textContent"),
          newCall(ident"$", ir.textExpr)
        )
      )
      stmts.add(newCall(
        ident"createEffect",
        newProc(body = effectBody, procType = nnkLambda)
      ))
    else:
      stmts.add(newLetStmt(
        ident(varName),
        newCall(newDotExpr(ident"document", ident"createTextNode"), newLit(ir.textStatic))
      ))
    if parentVar != "":
      stmts.add(newCall(
        newDotExpr(ident(parentVar), ident"appendChild"),
        ident(varName)
      ))
    result = varName

  of nkExpr:
    let varName = state.nextVar()
    stmts.add(newLetStmt(ident(varName), ir.expr))
    if parentVar != "":
      stmts.add(newCall(
        newDotExpr(ident(parentVar), ident"appendChild"),
        ident(varName)
      ))
    result = varName

  of nkComponent, nkIsland:
    let varName = state.nextVar()
    stmts.add(newLetStmt(ident(varName), ir.compProps))
    if parentVar != "":
      stmts.add(newCall(
        newDotExpr(ident(parentVar), ident"appendChild"),
        ident(varName)
      ))
    result = varName

  of nkFragment:
    if ir.fragmentChildren.len == 0:
      let varName = state.nextVar()
      stmts.add(newLetStmt(
        ident(varName),
        newCall(newDotExpr(ident"document", ident"createComment"), newLit"fragment")
      ))
      if parentVar != "":
        stmts.add(newCall(
          newDotExpr(ident(parentVar), ident"appendChild"),
          ident(varName)
        ))
      result = varName
    elif ir.fragmentChildren.len == 1:
      result = genNode(ir.fragmentChildren[0], state, parentVar, stmts)
    else:
      if parentVar != "":
        # Append all children directly to parent; no wrapper needed
        for i, ch in ir.fragmentChildren:
          let childVar = genNode(ch, state, parentVar, stmts)
          if i == 0:
            result = childVar
      else:
        # No parent — need a DocumentFragment to hold children
        let fragVar = state.nextVar()
        stmts.add(newLetStmt(
          ident(fragVar),
          newCall(newDotExpr(ident"document", ident"createDocumentFragment"))
        ))
        for ch in ir.fragmentChildren:
          discard genNode(ch, state, fragVar, stmts)
        result = fragVar

  of nkIf:
    if parentVar != "":
      let anchorVar = state.nextVar()
      stmts.add(newLetStmt(
        ident(anchorVar),
        newCall(newDotExpr(ident"document", ident"createComment"), newLit"if")
      ))
      stmts.add(newCall(
        newDotExpr(ident(parentVar), ident"appendChild"),
        ident(anchorVar)
      ))
      var ifStmt = newTree(nnkIfStmt)
      for branch in ir.ifBranches:
        var branchStmts: seq[NimNode] = @[]
        for ch in branch.body:
          discard genNode(ch, state, parentVar, branchStmts)
        ifStmt.add(newTree(nnkElifBranch, branch.cond, newStmtList(branchStmts)))
      if ir.ifElse.len > 0:
        var elseStmts: seq[NimNode] = @[]
        for ch in ir.ifElse:
          discard genNode(ch, state, parentVar, elseStmts)
        ifStmt.add(newTree(nnkElse, newStmtList(elseStmts)))
      stmts.add(ifStmt)
      result = anchorVar
    else:
      let fragVar = state.nextVar()
      stmts.add(newLetStmt(
        ident(fragVar),
        newCall(newDotExpr(ident"document", ident"createDocumentFragment"))
      ))
      var ifStmt = newTree(nnkIfStmt)
      for branch in ir.ifBranches:
        var branchStmts: seq[NimNode] = @[]
        for ch in branch.body:
          discard genNode(ch, state, fragVar, branchStmts)
        ifStmt.add(newTree(nnkElifBranch, branch.cond, newStmtList(branchStmts)))
      if ir.ifElse.len > 0:
        var elseStmts: seq[NimNode] = @[]
        for ch in ir.ifElse:
          discard genNode(ch, state, fragVar, elseStmts)
        ifStmt.add(newTree(nnkElse, newStmtList(elseStmts)))
      stmts.add(ifStmt)
      result = fragVar

  of nkFor:
    if parentVar != "":
      let anchorVar = state.nextVar()
      stmts.add(newLetStmt(
        ident(anchorVar),
        newCall(newDotExpr(ident"document", ident"createComment"), newLit"for")
      ))
      stmts.add(newCall(
        newDotExpr(ident(parentVar), ident"appendChild"),
        ident(anchorVar)
      ))
      var forBodyStmts: seq[NimNode] = @[]
      for ch in ir.forBody:
        discard genNode(ch, state, parentVar, forBodyStmts)
      stmts.add(newTree(nnkForStmt, ir.forVar, ir.forIterable, newStmtList(forBodyStmts)))
      result = anchorVar
    else:
      let fragVar = state.nextVar()
      stmts.add(newLetStmt(
        ident(fragVar),
        newCall(newDotExpr(ident"document", ident"createDocumentFragment"))
      ))
      var forBodyStmts: seq[NimNode] = @[]
      for ch in ir.forBody:
        discard genNode(ch, state, fragVar, forBodyStmts)
      stmts.add(newTree(nnkForStmt, ir.forVar, ir.forIterable, newStmtList(forBodyStmts)))
      result = fragVar

  of nkCase:
    if parentVar != "":
      let anchorVar = state.nextVar()
      stmts.add(newLetStmt(
        ident(anchorVar),
        newCall(newDotExpr(ident"document", ident"createComment"), newLit"case")
      ))
      stmts.add(newCall(
        newDotExpr(ident(parentVar), ident"appendChild"),
        ident(anchorVar)
      ))
      var caseStmt = newTree(nnkCaseStmt, ir.caseDisc)
      for branch in ir.caseBranches:
        if branch.values.len == 0:
          var elseStmts: seq[NimNode] = @[]
          for ch in branch.body:
            discard genNode(ch, state, parentVar, elseStmts)
          caseStmt.add(newTree(nnkElse, newStmtList(elseStmts)))
        else:
          var ofBranch = newTree(nnkOfBranch)
          for v in branch.values:
            ofBranch.add(v)
          var branchStmts: seq[NimNode] = @[]
          for ch in branch.body:
            discard genNode(ch, state, parentVar, branchStmts)
          ofBranch.add(newStmtList(branchStmts))
          caseStmt.add(ofBranch)
      stmts.add(caseStmt)
      result = anchorVar
    else:
      let fragVar = state.nextVar()
      stmts.add(newLetStmt(
        ident(fragVar),
        newCall(newDotExpr(ident"document", ident"createDocumentFragment"))
      ))
      var caseStmt = newTree(nnkCaseStmt, ir.caseDisc)
      for branch in ir.caseBranches:
        if branch.values.len == 0:
          var elseStmts: seq[NimNode] = @[]
          for ch in branch.body:
            discard genNode(ch, state, fragVar, elseStmts)
          caseStmt.add(newTree(nnkElse, newStmtList(elseStmts)))
        else:
          var ofBranch = newTree(nnkOfBranch)
          for v in branch.values:
            ofBranch.add(v)
          var branchStmts: seq[NimNode] = @[]
          for ch in branch.body:
            discard genNode(ch, state, fragVar, branchStmts)
          ofBranch.add(newStmtList(branchStmts))
          caseStmt.add(ofBranch)
      stmts.add(caseStmt)
      result = fragVar

proc genClient*(ir: IrNode; analysis: TemplateAnalysis): NimNode =
  ## Returns a Nim AST block that builds the DOM and wires signals.
  var state = ClientGenState()
  var stmts: seq[NimNode] = @[]
  let rootVar = genNode(ir, state, "", stmts)
  result = newStmtList()
  for s in stmts:
    result.add(s)
  result.add(ident(rootVar))

## Nexum Compiler — Server Codegen: IR → fast string builder.
##
## Generates code like:
##   ctx.write("<div class=\"x\">")
##   ctx.writeEscaped($count())
##   ctx.write("</div>")

import std/macros
import parser, analyzer

proc genNode(ir: IrNode; stmts: var seq[NimNode]) =
  case ir.kind
  of nkElement:
    stmts.add(newCall(
      newDotExpr(ident"ctx", ident"write"),
      newLit("<" & ir.tag)
    ))
    for at in ir.attrs:
      case at.kind
      of avStatic:
        stmts.add(newCall(
          newDotExpr(ident"ctx", ident"write"),
          newLit(" " & at.name & "=\"" & at.sval & "\"")
        ))
      of avDynamic:
        stmts.add(newCall(
          newDotExpr(ident"ctx", ident"write"),
          newLit(" " & at.name & "=\"")
        ))
        stmts.add(newCall(
          newDotExpr(ident"ctx", ident"writeEscaped"),
          newCall(ident"$", at.dval)
        ))
        stmts.add(newCall(
          newDotExpr(ident"ctx", ident"write"),
          newLit("\"")
        ))
      of avEvent:
        # Events are client-only; skip on server
        discard
    stmts.add(newCall(
      newDotExpr(ident"ctx", ident"write"),
      newLit(">")
    ))
    for ch in ir.children:
      genNode(ch, stmts)
    stmts.add(newCall(
      newDotExpr(ident"ctx", ident"write"),
      newLit("</" & ir.tag & ">")
    ))

  of nkText:
    if ir.textExpr != nil:
      stmts.add(newCall(
        newDotExpr(ident"ctx", ident"writeEscaped"),
        newCall(ident"$", ir.textExpr)
      ))
    else:
      stmts.add(newCall(
        newDotExpr(ident"ctx", ident"write"),
        newLit(ir.textStatic)
      ))

  of nkExpr:
    stmts.add(newCall(
      newDotExpr(ident"ctx", ident"writeEscaped"),
      newCall(ident"$", ir.expr)
    ))

  of nkComponent:
    stmts.add(newCall(
      newDotExpr(ident"ctx", ident"write"),
      ir.compProps
    ))

  of nkIsland:
    stmts.add(newCall(
      newDotExpr(ident"ctx", ident"writeIslandStart"),
      newLit(ir.compType),
      newCall(ident"newJObject")
    ))
    # Render the island component between markers
    stmts.add(newCall(
      newDotExpr(ident"ctx", ident"write"),
      ir.compProps
    ))
    stmts.add(newCall(
      newDotExpr(ident"ctx", ident"writeIslandEnd"),
      newLit(ir.compType)
    ))

  of nkFragment:
    for ch in ir.fragmentChildren:
      genNode(ch, stmts)

  of nkIf:
    var ifStmt = newTree(nnkIfStmt)
    for branch in ir.ifBranches:
      var branchStmts: seq[NimNode] = @[]
      for ch in branch.body:
        genNode(ch, branchStmts)
      ifStmt.add(newTree(nnkElifBranch, branch.cond, newStmtList(branchStmts)))
    if ir.ifElse.len > 0:
      var elseStmts: seq[NimNode] = @[]
      for ch in ir.ifElse:
        genNode(ch, elseStmts)
      ifStmt.add(newTree(nnkElse, newStmtList(elseStmts)))
    stmts.add(ifStmt)

  of nkFor:
    var forBodyStmts: seq[NimNode] = @[]
    for ch in ir.forBody:
      genNode(ch, forBodyStmts)
    stmts.add(newTree(nnkForStmt, ir.forVar, ir.forIterable, newStmtList(forBodyStmts)))

  of nkCase:
    var caseStmt = newTree(nnkCaseStmt, ir.caseDisc)
    for branch in ir.caseBranches:
      if branch.values.len == 0:
        var elseStmts: seq[NimNode] = @[]
        for ch in branch.body:
          genNode(ch, elseStmts)
        caseStmt.add(newTree(nnkElse, newStmtList(elseStmts)))
      else:
        var ofBranch = newTree(nnkOfBranch)
        for v in branch.values:
          ofBranch.add(v)
        var branchStmts: seq[NimNode] = @[]
        for ch in branch.body:
          genNode(ch, branchStmts)
        ofBranch.add(newStmtList(branchStmts))
        caseStmt.add(ofBranch)
    stmts.add(caseStmt)

proc genServer*(ir: IrNode; analysis: TemplateAnalysis): NimNode =
  ## Returns a Nim AST block that writes HTML into a `ctx: RenderContext`.
  var stmts: seq[NimNode] = @[]
  genNode(ir, stmts)
  result = newStmtList()
  for s in stmts:
    result.add(s)

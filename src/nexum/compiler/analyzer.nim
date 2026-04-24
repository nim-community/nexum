## Nexum Compiler — Analyzer: static/dynamic partitioning & dependency graph.

import parser

type
  ## Analysis result for a template
  TemplateAnalysis* = object
    hasDynamicText*: bool
    hasDynamicAttrs*: bool
    hasEvents*: bool
    hasIslands*: bool
    hasControlFlow*: bool
    # TODO: dependency graph: which signals affect which IR nodes

proc analyze*(ir: IrNode): TemplateAnalysis =
  ## Walks the IR and marks nodes as static or dynamic.
  ## Produces the dependency graph used by codegen.
  case ir.kind
  of nkText:
    if ir.textExpr != nil:
      result.hasDynamicText = true

  of nkElement:
    for at in ir.attrs:
      if at.kind in {avDynamic, avEvent}:
        result.hasDynamicAttrs = true
      if at.kind == avEvent:
        result.hasEvents = true
    for ch in ir.children:
      let childRes = analyze(ch)
      result.hasDynamicText = result.hasDynamicText or childRes.hasDynamicText
      result.hasDynamicAttrs = result.hasDynamicAttrs or childRes.hasDynamicAttrs
      result.hasEvents = result.hasEvents or childRes.hasEvents
      result.hasIslands = result.hasIslands or childRes.hasIslands
      result.hasControlFlow = result.hasControlFlow or childRes.hasControlFlow

  of nkIsland:
    result.hasIslands = true

  of nkIf, nkFor, nkCase:
    result.hasControlFlow = true
    var bodies: seq[seq[IrNode]]
    case ir.kind
    of nkIf:
      for b in ir.ifBranches:
        bodies.add(b.body)
      if ir.ifElse.len > 0:
        bodies.add(ir.ifElse)
    of nkFor:
      bodies.add(ir.forBody)
    of nkCase:
      for b in ir.caseBranches:
        bodies.add(b.body)
    else: discard
    for body in bodies:
      for ch in body:
        let childRes = analyze(ch)
        result.hasDynamicText = result.hasDynamicText or childRes.hasDynamicText
        result.hasDynamicAttrs = result.hasDynamicAttrs or childRes.hasDynamicAttrs
        result.hasEvents = result.hasEvents or childRes.hasEvents
        result.hasIslands = result.hasIslands or childRes.hasIslands
        result.hasControlFlow = result.hasControlFlow or childRes.hasControlFlow

  of nkFragment:
    for ch in ir.fragmentChildren:
      let childRes = analyze(ch)
      result.hasDynamicText = result.hasDynamicText or childRes.hasDynamicText
      result.hasDynamicAttrs = result.hasDynamicAttrs or childRes.hasDynamicAttrs
      result.hasEvents = result.hasEvents or childRes.hasEvents
      result.hasIslands = result.hasIslands or childRes.hasIslands
      result.hasControlFlow = result.hasControlFlow or childRes.hasControlFlow

  else:
    discard

## Nexum Runtime — Thin DOM abstraction for JS target.
## Wraps js/dom with hydration-aware DOM creation.

when not defined(js):
  {.error: "dom.nim targets JS only".}

import js/dom as stdDom

# Re-export types from std/js/dom
export stdDom.Node, stdDom.Element, stdDom.Document, stdDom.Event, stdDom.Window
export stdDom.NodeType, stdDom.ClassList, stdDom.Style, stdDom.BoundingRect
export stdDom.KeyboardEvent, stdDom.MouseEvent, stdDom.UIEvent
export stdDom.TimeOut, stdDom.Interval
export stdDom.AddEventListenerOptions, stdDom.ScrollIntoViewOptions

# Re-export ClassList methods with specific names to avoid ambiguity
proc classListAdd*(e: Element, class: cstring) {.importjs: "#.classList.add(#)".}
proc classListRemove*(e: Element, class: cstring) {.importjs: "#.classList.remove(#)".}
proc classListContains*(e: Element, class: cstring): bool {.importjs: "#.classList.contains(#)".}
proc classListToggle*(e: Element, class: cstring): bool {.importjs: "#.classList.toggle(#)".}

# Re-export globals
export stdDom.document, stdDom.window

# Re-export non-conflicting procs
export stdDom.querySelector, stdDom.querySelectorAll
export stdDom.getElementById
export stdDom.addEventListener, stdDom.removeEventListener
export stdDom.preventDefault, stdDom.stopImmediatePropagation, stdDom.stopPropagation
export stdDom.closest
export stdDom.scrollIntoView
export stdDom.getBoundingClientRect
export stdDom.setTimeout, stdDom.clearTimeout, stdDom.setInterval, stdDom.clearInterval
export stdDom.encodeURIComponent, stdDom.decodeURIComponent
export stdDom.requestAnimationFrame, stdDom.cancelAnimationFrame

# ---------------------------------------------------------------------------
# Hydration mode: intercept DOM creation to reuse existing SSR nodes
# ---------------------------------------------------------------------------

var nexumHydrating*: bool = false
var nexumHydrateQueue*: seq[Node] = @[]
var nexumHydrateIndex*: int = 0

proc startHydration*(root: Element) =
  ## Enter hydration mode for an island root.
  nexumHydrating = true
  nexumHydrateQueue = @[]
  nexumHydrateIndex = 0
  var stack = @[Node(root)]
  while stack.len > 0:
    let n = stack.pop()
    nexumHydrateQueue.add(n)
    for i in countdown(n.childNodes.len - 1, 0):
      stack.add(n.childNodes[i])

proc stopHydration*() =
  ## Exit hydration mode and clean up.
  nexumHydrating = false
  nexumHydrateQueue = @[]
  nexumHydrateIndex = 0

# ---------------------------------------------------------------------------
# Hydration-aware DOM creation wrappers
# ---------------------------------------------------------------------------

proc jsCreateElement(d: Document; tag: cstring): Element {.importjs: "#.createElement(#)".}
proc createElement*(d: Document; tag: cstring): Element =
  if nexumHydrating:
    while nexumHydrateIndex < nexumHydrateQueue.len:
      let n = nexumHydrateQueue[nexumHydrateIndex]
      inc nexumHydrateIndex
      if n.nodeType == ElementNode:
        return cast[Element](n)
  jsCreateElement(d, tag)

proc jsCreateTextNode(d: Document; text: cstring): Node {.importjs: "#.createTextNode(#)".}
proc createTextNode*(d: Document; text: cstring): Node =
  if nexumHydrating:
    while nexumHydrateIndex < nexumHydrateQueue.len:
      let n = nexumHydrateQueue[nexumHydrateIndex]
      inc nexumHydrateIndex
      if n.nodeType == TextNode:
        return n
  jsCreateTextNode(d, text)

proc jsAppendChild(parent, child: Node) {.importjs: "#.appendChild(#)".}
proc appendChild*(parent, child: Node) =
  if nexumHydrating:
    if child.nodeType == CommentNode:
      return
    if child.nodeType == DocumentFragmentNode:
      return
    if child.parentNode == parent:
      return
    if child.parentNode != nil:
      return
  jsAppendChild(parent, child)

proc jsRemoveChild(parent, child: Node) {.importjs: "#.removeChild(#)".}
proc removeChild*(parent, child: Node) =
  jsRemoveChild(parent, child)

proc insertBefore*(parent, newChild, refChild: Node) {.importjs: "#.insertBefore(#, #)".}
proc replaceChild*(parent, newChild, oldChild: Node) {.importjs: "#.replaceChild(#, #)".}

proc setAttr*(e: Element; name, value: cstring) {.importjs: "#.setAttribute(#, #)".}
proc removeAttr*(e: Element; name: cstring) {.importjs: "#.removeAttribute(#)".}
proc getAttr*(e: Element; name: cstring): cstring {.importjs: "#.getAttribute(#)".}
proc className*(e: Element): cstring {.importjs: "#.className".}
proc `className=`*(e: Element; v: cstring) {.importjs: "#.className = #".}

proc textContent*(n: Node): cstring {.importjs: "#.textContent".}
proc `textContent=`*(n: Node; v: cstring) {.importjs: "#.textContent = #".}
proc innerHTML*(e: Element): cstring {.importjs: "#.innerHTML".}
proc `innerHTML=`*(e: Element; v: cstring) {.importjs: "#.innerHTML = #".}

proc target*(ev: Event): Element {.importjs: "#.target".}
proc value*(e: Element): cstring {.importjs: "#.value".}
proc `value=`*(e: Element; v: cstring) {.importjs: "#.value = #".}

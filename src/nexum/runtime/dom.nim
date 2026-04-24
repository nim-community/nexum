## Nexum Runtime — Thin DOM abstraction for JS target.

when not defined(js):
  {.error: "dom.nim targets JS only".}

# Re-export or wrap minimal browser APIs so Nexum does not depend on karax/kdom.

type
  Node* = ref object of RootObj
  Element* = ref object of Node
  Document* = ref object of Node
  Event* = ref object of RootObj
  Window* = ref object of RootObj

var document* {.importjs, nodecl.}: Document
var window* {.importjs, nodecl.}: Window

const
  NodeElement* = 1
  NodeText* = 3
  NodeComment* = 8

# ---------------------------------------------------------------------------
# Hydration mode: intercept DOM creation to reuse existing SSR nodes
# ---------------------------------------------------------------------------

var nexumHydrating*: bool = false
var nexumHydrateQueue*: seq[Node] = @[]
var nexumHydrateIndex*: int = 0

proc childNodes*(n: Node): seq[Node] {.importjs: "#.childNodes".}
proc nodeType*(n: Node): int {.importjs: "#.nodeType".}
proc parentNode*(n: Node): Node {.importjs: "#.parentNode".}

proc startHydration*(root: Element) =
  ## Enter hydration mode for an island root.
  ## Collects all nodes in DFS pre-order so that `createElement`/
  ## `createTextNode` calls can return existing SSR nodes instead of
  ## creating fresh ones.
  nexumHydrating = true
  nexumHydrateQueue = @[]
  nexumHydrateIndex = 0
  var stack = @[Node(root)]
  while stack.len > 0:
    let n = stack.pop()
    nexumHydrateQueue.add(n)
    let children = childNodes(n)
    for i in countdown(children.high, 0):
      stack.add(children[i])

proc stopHydration*() =
  ## Exit hydration mode and clean up.
  nexumHydrating = false
  nexumHydrateQueue = @[]
  nexumHydrateIndex = 0

# ---------------------------------------------------------------------------
# DOM creation wrappers that consume the hydration queue when active
# ---------------------------------------------------------------------------

proc jsCreateElement(d: Document; tag: cstring): Element {.importjs: "#.createElement(#)".}
proc createElement*(d: Document; tag: cstring): Element =
  if nexumHydrating:
    while nexumHydrateIndex < nexumHydrateQueue.len:
      let n = nexumHydrateQueue[nexumHydrateIndex]
      inc nexumHydrateIndex
      if n.nodeType == NodeElement:
        return cast[Element](n)
  jsCreateElement(d, tag)

proc createElementNS*(d: Document; ns, tag: cstring): Element {.importjs: "#.createElementNS(#, #)".}

proc jsCreateTextNode(d: Document; text: cstring): Node {.importjs: "#.createTextNode(#)".}
proc createTextNode*(d: Document; text: cstring): Node =
  if nexumHydrating:
    while nexumHydrateIndex < nexumHydrateQueue.len:
      let n = nexumHydrateQueue[nexumHydrateIndex]
      inc nexumHydrateIndex
      if n.nodeType == NodeText:
        return n
  jsCreateTextNode(d, text)

proc createComment*(d: Document; text: cstring): Node {.importjs: "#.createComment(#)".}
proc createDocumentFragment*(d: Document): Node {.importjs: "#.createDocumentFragment()".}

# ---------------------------------------------------------------------------
# appendChild wrapper that avoids moving existing SSR nodes during hydration
# ---------------------------------------------------------------------------

proc jsAppendChild(parent, child: Node) {.importjs: "#.appendChild(#)".}

proc appendChild*(parent, child: Node) =
  if nexumHydrating:
    # Skip comment anchors (if/for/case markers not present in SSR)
    if child.nodeType == NodeComment:
      return
    # Skip document fragments to avoid moving pooled nodes out of the DOM
    const NodeDocumentFragment = 11
    if child.nodeType == NodeDocumentFragment:
      return
    # Skip if child is already a direct child of parent
    if child.parentNode == parent:
      return
    # Don't move nodes that are already in the document elsewhere
    if child.parentNode != nil:
      return
  jsAppendChild(parent, child)

proc insertBefore*(parent, newChild, refChild: Node) {.importjs: "#.insertBefore(#, #)".}
proc removeChild*(parent, child: Node) {.importjs: "#.removeChild(#)".}
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

proc addEventListener*(e: Element|Window|Document; ev: cstring; handler: proc(ev: Event);
    capture = false) {.importjs: "#.addEventListener(#, #, #)".}
proc removeEventListener*(e: Element|Window|Document; ev: cstring; handler: proc(
    ev: Event)) {.importjs: "#.removeEventListener(#, #)".}

proc querySelector*(d: Document; sel: cstring): Element {.importjs: "#.querySelector(#)".}
proc querySelectorAll*(d: Document; sel: cstring): seq[Element] {.importjs: "#.querySelectorAll(#)".}
proc querySelector*(e: Element; sel: cstring): Element {.importjs: "#.querySelector(#)".}
proc querySelectorAll*(e: Element; sel: cstring): seq[Element] {.importjs: "#.querySelectorAll(#)".}

proc firstChild*(n: Node): Node {.importjs: "#.firstChild".}
proc nextSibling*(n: Node): Node {.importjs: "#.nextSibling".}
proc nodeValue*(n: Node): cstring {.importjs: "#.nodeValue".}
proc `nodeValue=`*(n: Node; v: cstring) {.importjs: "#.nodeValue = #".}

proc target*(ev: Event): Element {.importjs: "#.target".}
proc value*(e: Element): cstring {.importjs: "#.value".}
proc `value=`*(e: Element; v: cstring) {.importjs: "#.value = #".}

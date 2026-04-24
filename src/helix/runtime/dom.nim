## Helix Runtime — Thin DOM abstraction for JS target.

when not defined(js):
  {.error: "dom.nim targets JS only".}

# Re-export or wrap minimal browser APIs so Helix does not depend on karax/kdom.

type
  Node* = ref object of RootObj
  Element* = ref object of Node
  Document* = ref object of Node
  Event* = ref object of RootObj
  Window* = ref object of RootObj

var document* {.importjs, nodecl.}: Document
var window* {.importjs, nodecl.}: Window

proc createElement*(d: Document; tag: cstring): Element {.importjs: "#.createElement(#)".}
proc createElementNS*(d: Document; ns, tag: cstring): Element {.importjs: "#.createElementNS(#, #)".}
proc createTextNode*(d: Document; text: cstring): Node {.importjs: "#.createTextNode(#)".}
proc createComment*(d: Document; text: cstring): Node {.importjs: "#.createComment(#)".}
proc createDocumentFragment*(d: Document): Node {.importjs: "#.createDocumentFragment()".}

proc appendChild*(parent, child: Node) {.importjs: "#.appendChild(#)".}
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

proc addEventListener*(e: Element|Window|Document; ev: cstring; handler: proc(ev: Event); capture = false) {.importjs: "#.addEventListener(#, #, #)".}
proc removeEventListener*(e: Element|Window|Document; ev: cstring; handler: proc(ev: Event)) {.importjs: "#.removeEventListener(#, #)".}

proc querySelector*(d: Document; sel: cstring): Element {.importjs: "#.querySelector(#)".}
proc querySelectorAll*(d: Document; sel: cstring): seq[Element] {.importjs: "#.querySelectorAll(#)".}
proc querySelector*(e: Element; sel: cstring): Element {.importjs: "#.querySelector(#)".}
proc querySelectorAll*(e: Element; sel: cstring): seq[Element] {.importjs: "#.querySelectorAll(#)".}

proc firstChild*(n: Node): Node {.importjs: "#.firstChild".}
proc nextSibling*(n: Node): Node {.importjs: "#.nextSibling".}
proc parentNode*(n: Node): Node {.importjs: "#.parentNode".}
proc childNodes*(n: Node): seq[Node] {.importjs: "#.childNodes".}

proc nodeType*(n: Node): int {.importjs: "#.nodeType".}
proc nodeValue*(n: Node): cstring {.importjs: "#.nodeValue".}
proc `nodeValue=`*(n: Node; v: cstring) {.importjs: "#.nodeValue = #".}

proc target*(ev: Event): Element {.importjs: "#.target".}
proc value*(e: Element): cstring {.importjs: "#.value".}
proc `value=`*(e: Element; v: cstring) {.importjs: "#.value = #".}

const
  NodeElement* = 1
  NodeText* = 3
  NodeComment* = 8

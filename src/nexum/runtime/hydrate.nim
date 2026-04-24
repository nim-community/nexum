## Nexum Runtime — Hydration: scanning SSR markers and attaching signal bindings.
##
## SSR outputs comments like:
##   <!--nexum-island start="Counter_7a3f" props='{...}'-->
##   <button>0</button>
##   <!--nexum-island end="Counter_7a3f"-->
##
## Hydration reads these, finds the root Element, and mounts the island
## without destroying the existing DOM.

when not defined(js):
  {.error: "hydrate.nim targets JS only".}

import std/[json, strutils, options, tables]
import dom

type
  IslandMarker* = object
    id*: string
    props*: JsonNode
    startComment*: Node
    endComment*: Node
    rootElement*: Element

  HydrationError* = object of CatchableError

const
  IslandStartPrefix = "nexum-island start=\""
  IslandEndPrefix = "nexum-island end=\""

# ---------------------------------------------------------------------------
# Marker scanning
# ---------------------------------------------------------------------------

proc parseIslandStart(text: string): Option[IslandMarker] =
  ## Extract id and props from start comment text.
  if not text.startsWith(IslandStartPrefix):
    return none[IslandMarker]()

  let idStart = IslandStartPrefix.len
  let idEnd = text.find('"', idStart)
  if idEnd < 0:
    return none[IslandMarker]()
  let id = text[idStart ..< idEnd]

  let propsPrefix = " props='"
  let propsStart = text.find(propsPrefix, idEnd)
  if propsStart < 0:
    return none[IslandMarker]()

  let propsValStart = propsStart + propsPrefix.len
  let propsValEnd = text.find('\'', propsValStart)
  if propsValEnd < 0:
    return none[IslandMarker]()
  let propsStr = text[propsValStart ..< propsValEnd]

  try:
    let props = parseJson(propsStr)
    some(IslandMarker(id: id, props: props))
  except JsonParsingError:
    none[IslandMarker]()

proc scanIslands*(doc: Document): seq[IslandMarker] =
  ## Walks all comment nodes in the document looking for Nexum markers.
  result = @[]
  var stack: seq[Node] = @[Node(doc)]

  while stack.len > 0:
    let node = stack.pop()
    if node.nodeType == NodeComment:
      let text = $node.nodeValue
      if text.startsWith(IslandStartPrefix):
        let parsed = parseIslandStart(text)
        if parsed.isSome:
          var marker = parsed.get
          marker.startComment = node
          var curr = node.nextSibling
          while curr != nil:
            if curr.nodeType == NodeElement and marker.rootElement == nil:
              marker.rootElement = cast[Element](curr)
            elif curr.nodeType == NodeComment:
              let endText = $curr.nodeValue
              if endText.startsWith(IslandEndPrefix):
                let expected = IslandEndPrefix & marker.id & "\""
                if endText == expected:
                  marker.endComment = curr
                  break
            curr = curr.nextSibling
          if marker.endComment != nil and marker.rootElement != nil:
            result.add(marker)

    let children = node.childNodes
    for i in countdown(children.high, 0):
      stack.add(children[i])

# ---------------------------------------------------------------------------
# Hydration entry
# ---------------------------------------------------------------------------

var islandRegistry: Table[string, proc(props: JsonNode, root: Element)]

proc registerIsland*(id: string; factory: proc(props: JsonNode, root: Element)) =
  islandRegistry[id] = factory

proc hydrateIsland*(marker: IslandMarker) =
  ## Given a marker, runs the island's client bootstrap on the existing DOM.
  ## 1. Deserialize props.
  ## 2. Instantiate component with props.
  ## 3. Walk expected shape vs actual DOM, binding nodes to signals.
  ## 4. Attach event listeners.
  if marker.rootElement == nil:
    return
  let factory = islandRegistry.getOrDefault(marker.id)
  if factory != nil:
    factory(marker.props, marker.rootElement)

proc hydrateDocument*(doc: Document = document) =
  ## Scans and hydrates all islands in the document.
  let islands = scanIslands(doc)
  for im in islands:
    hydrateIsland(im)

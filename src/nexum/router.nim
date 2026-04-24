## Nexum Router — Isomorphic routing (client + server).

import std/[tables, strutils]

# Forward declaration; real VNode type will come from runtime
when defined(js):
  import runtime/dom
  type VNode* = Node
else:
  type VNode* = string ## Placeholder for server-side rendered fragment

type
  RouteHandler* = proc(params: Table[string, string]): VNode {.closure.}
  RouteLoader* = proc(): string {.closure.}

  Route* = object
    path*: string
    segments*: seq[string]   ## path split by "/"
    paramNames*: seq[string] ## param names in order of appearance
    handler*: RouteHandler
    loader*: RouteLoader

  Router* = ref object
    routes*: seq[Route]
    notFound*: RouteHandler

proc defaultNotFound(params: Table[string, string]): VNode =
  when defined(js):
    document.createTextNode(cstring("404 Not Found"))
  else:
    "404 Not Found"

proc newRouter*(): Router =
  Router(routes: @[], notFound: defaultNotFound)

proc addRoute*(r: Router; path: string; handler: RouteHandler; loader: RouteLoader = nil) =
  ## Register a route. Path segments starting with `:` are captured as parameters.
  var segments: seq[string]
  var paramNames: seq[string]
  for segment in path.split('/'):
    segments.add(segment)
    if segment.len > 0 and segment[0] == ':':
      paramNames.add(segment[1 .. ^1])
  r.routes.add(Route(path: path, segments: segments, paramNames: paramNames, handler: handler, loader: loader))

var currentRouteData*: string = "" ## Set by app before calling handler

proc getRouteData*(): string =
  ## Returns the JSON data loaded by the current route's loader.
  ## Empty string if no loader ran.
  currentRouteData

proc match*(r: Router; url: string): (Route, Table[string, string]) =
  ## Match a URL against registered routes. Returns the matched route and captured params.
  let urlSegments = url.split('/')
  for route in r.routes:
    if route.segments.len != urlSegments.len:
      continue
    var params = initTable[string, string]()
    var matched = true
    for i in 0 ..< route.segments.len:
      let seg = route.segments[i]
      if seg.len > 0 and seg[0] == ':':
        params[seg[1 .. ^1]] = urlSegments[i]
      elif seg == "*":
        # wildcard matches any segment
        discard
      elif seg != urlSegments[i]:
        matched = false
        break
    if matched:
      return (route, params)
  return (Route(handler: r.notFound), initTable[string, string]())

# Client-side navigation
when defined(js):
  var onNavigate*: proc(url: string) {.closure.} = nil

  let locationPathname* {.importjs: "document.location.pathname".}: cstring

  proc navigate*(url: string) =
    ## Push state and trigger client-side route handler.
    proc pushState(u: string) {.importjs: "history.pushState(null, '', #)".}
    pushState(url)
    if onNavigate != nil:
      onNavigate(url)

  proc setupPopstateListener*() =
    ## Call once on app startup to handle browser back/forward.
    window.addEventListener(cstring("popstate"), proc(ev: Event) =
      if onNavigate != nil:
        onNavigate($locationPathname)
    )

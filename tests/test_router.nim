import helix
import std/[unittest, tables]

suite "Router":
  test "basic route matching":
    let r = newRouter()
    r.addRoute("/", proc(params: Table[string, string]): string = "home")
    r.addRoute("/about", proc(params: Table[string, string]): string = "about")

    let (route1, _) = r.match("/")
    check route1.handler(initTable[string, string]()) == "home"

    let (route2, _) = r.match("/about")
    check route2.handler(initTable[string, string]()) == "about"

  test "param capture":
    let r = newRouter()
    r.addRoute("/user/:id", proc(params: Table[string, string]): string =
      "user:" & params.getOrDefault("id", "unknown")
    )

    let (route, params) = r.match("/user/42")
    check route.handler(params) == "user:42"

  test "404 fallback":
    let r = newRouter()
    r.addRoute("/", proc(params: Table[string, string]): string = "home")

    let (route, _) = r.match("/missing")
    check route.handler(initTable[string, string]()) == "404 Not Found"

  test "route loader":
    let r = newRouter()
    var loaderCalled = false
    r.addRoute("/data",
      proc(params: Table[string, string]): string =
        "data:" & getRouteData(),
      loader = proc(): string =
        loaderCalled = true
        "{\"count\":42}"
    )

    let (route, _) = r.match("/data")
    check route.loader != nil
    discard route.loader()
    check loaderCalled == true

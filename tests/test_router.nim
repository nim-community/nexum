import helix
import std/[unittest, tables]

suite "Router":
  test "basic route matching":
    let r = newRouter()
    r.addRoute("/", proc(params: Table[string, string]): string = "home")
    r.addRoute("/about", proc(params: Table[string, string]): string = "about")

    let (handler1, _) = r.match("/")
    check handler1(initTable[string, string]()) == "home"

    let (handler2, _) = r.match("/about")
    check handler2(initTable[string, string]()) == "about"

  test "param capture":
    let r = newRouter()
    r.addRoute("/user/:id", proc(params: Table[string, string]): string =
      "user:" & params.getOrDefault("id", "unknown")
    )

    let (handler, params) = r.match("/user/42")
    check handler(params) == "user:42"

  test "404 fallback":
    let r = newRouter()
    r.addRoute("/", proc(params: Table[string, string]): string = "home")

    let (handler, _) = r.match("/missing")
    check handler(initTable[string, string]()) == "404 Not Found"

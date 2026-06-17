import nexum/core/context as ctx_mod
import std/[unittest, json, strutils]

type
  Counter = ref object
    val: int
  Label = ref object
    text: string

suite "Context":
  test "newContext creates empty context":
    let c = ctx_mod.newContext()
    check c.parent == nil

  test "newContext with parent":
    let parent = ctx_mod.newContext()
    let child = ctx_mod.newContext(parent)
    check child.parent == parent

  test "set and get ref type":
    let c = ctx_mod.newContext()
    let cnt = Counter(val: 42)
    ctx_mod.set[Counter](c, "counter", cnt)
    check ctx_mod.get[Counter](c, "counter").val == 42

  test "set and get string via ref":
    let c = ctx_mod.newContext()
    let lbl = Label(text: "nexum")
    ctx_mod.set[Label](c, "label", lbl)
    check ctx_mod.get[Label](c, "label").text == "nexum"

  test "set and get JsonNode":
    let c = ctx_mod.newContext()
    ctx_mod.set[JsonNode](c, "config", %* {"key": "value"})
    check ctx_mod.get[JsonNode](c, "config")["key"].getStr() == "value"

  test "get falls back to parent":
    let parent = ctx_mod.newContext()
    let val = Label(text: "from-parent")
    ctx_mod.set[Label](parent, "value", val)
    let child = ctx_mod.newContext(parent)
    check ctx_mod.get[Label](child, "value").text == "from-parent"

  test "get prefers local over parent":
    let parent = ctx_mod.newContext()
    let pval = Label(text: "parent")
    ctx_mod.set[Label](parent, "value", pval)
    let child = ctx_mod.newContext(parent)
    let cval = Label(text: "child")
    ctx_mod.set[Label](child, "value", cval)
    check ctx_mod.get[Label](child, "value").text == "child"
    check ctx_mod.get[Label](parent, "value").text == "parent"

  test "get raises on missing key":
    let c = ctx_mod.newContext()
    var raised = false
    try:
      discard ctx_mod.get[Counter](c, "missing")
    except KeyError:
      raised = true
    check raised == true

  test "get raises when parent chain exhausted":
    let parent = ctx_mod.newContext()
    let child = ctx_mod.newContext(parent)
    var raised = false
    try:
      discard ctx_mod.get[Counter](child, "missing")
    except KeyError:
      raised = true
    check raised == true

  test "setProp and propsToJson":
    let c = ctx_mod.newContext()
    c.setProp("id", %* 42)
    c.setProp("name", %* "test")
    let j = c.propsToJson()
    check j.contains("42")
    check j.contains("test")

  test "setProp with nested objects":
    let c = ctx_mod.newContext()
    c.setProp("config", %* {"enabled": true, "count": 5})
    let j = c.propsToJson()
    check j.contains("enabled")
    check j.contains("true")

  test "propsToJson empty context":
    let c = ctx_mod.newContext()
    let j = c.propsToJson()
    check j == "{}" or j == "{:}"

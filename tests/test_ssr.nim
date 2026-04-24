import nexum
import nexum/compiler/buildhtml
import std/[unittest, json, strutils]

suite "SSR Renderer":
  test "render context builds string":
    let ctx = newRenderContext()
    ctx.write("<div>")
    ctx.writeEscaped("<script>alert(1)</script>")
    ctx.write("</div>")
    check ctx.buf == "<div>&lt;script&gt;alert(1)&lt;/script&gt;</div>"

  test "island markers":
    let ctx = newRenderContext(RenderOptions(includeIslandMarkers: true))
    ctx.writeIslandStart("Counter_1", %*{"initial": 0})
    ctx.write("<button>0</button>")
    ctx.writeIslandEnd("Counter_1")
    check ctx.buf.contains("nexum-island")
    check ctx.buf.contains("Counter_1")

  test "buildHtml basic element":
    proc Greeting(): auto =
      buildHtml:
        h1: "Hello"
    check Greeting() == "<h1>Hello</h1>"

  test "buildHtml nested elements":
    proc Card(): auto =
      buildHtml:
        `div`(class = "card"):
          h2: "Title"
          p: "Body"
    let html = Card()
    check html.contains("<div class=\"card\">")
    check html.contains("<h2>Title</h2>")
    check html.contains("<p>Body</p>")

  test "buildHtml dynamic text":
    let name = "Nexum"
    proc Greet(): auto =
      buildHtml:
        span: "Hello, " & name
    check Greet() == "<span>Hello, Nexum</span>"

  test "buildHtml if statement":
    let show = true
    proc TestIf(): auto =
      buildHtml:
        if show:
          span: "visible"
        else:
          span: "hidden"
    check TestIf().contains("visible")
    check not TestIf().contains("hidden")

  test "buildHtml for loop":
    proc TestFor(): auto =
      buildHtml:
        ul:
          for i in 1..3:
            li: $i
    let html = TestFor()
    check html.contains("<li>1</li>")
    check html.contains("<li>2</li>")
    check html.contains("<li>3</li>")

  test "buildHtml case statement":
    let color = 2
    proc TestCase(): auto =
      buildHtml:
        case color
        of 1:
          span: "red"
        of 2:
          span: "green"
        else:
          span: "unknown"
    check TestCase().contains("green")

  test "buildHtml component call":
    proc Inner(): auto =
      buildHtml:
        span: "inner"
    proc Outer(): auto =
      buildHtml:
        `div`:
          Inner()
    check Outer().contains("<span>inner</span>")

  test "buildHtml island generates markers":
    proc MyIsland(): auto =
      buildHtml:
        button: "Click"
    proc Page(): auto =
      buildHtml:
        island MyIsland()
    let html = Page()
    check html.contains("nexum-island")
    check html.contains("MyIsland")

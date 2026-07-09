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

  test "buildHtml let inside for loop":
    proc TestLetInFor(): auto =
      let items = @["a", "b", "c"]
      buildHtml:
        ul:
          for i in 0 ..< items.len:
            let item = items[i]
            li: item
    let html = TestLetInFor()
    check html.contains("<li>a</li>")
    check html.contains("<li>b</li>")
    check html.contains("<li>c</li>")

  test "buildHtml let inside if inside for loop":
    proc TestLetInIfInFor(): auto =
      let items = @[(code: "x", amount: 100.0), (code: "y", amount: 0.0)]
      buildHtml:
        `div`(class = "list"):
          for it in items:
            let amt = it.amount
            if amt > 0:
              span(class = "pos"): it.code
            else:
              span(class = "zero"): it.code
    let html = TestLetInIfInFor()
    check html.contains("<span class=\"pos\">x</span>")
    check html.contains("<span class=\"zero\">y</span>")

  test "buildHtml continue inside for loop":
    proc TestContinue(): auto =
      let items = @["a", "b", "skip", "c"]
      buildHtml:
        ul:
          for s in items:
            if s == "skip":
              continue
            li: s
    let html = TestContinue()
    check html.contains("<li>a</li>")
    check html.contains("<li>b</li>")
    check html.contains("<li>c</li>")
    check not html.contains("skip")

  test "buildHtml bare identifier as dynamic text":
    proc TestBareIdent(name: string): auto =
      buildHtml:
        span(class = "x"): name
    check TestBareIdent("hello") == "<span class=\"x\">hello</span>"

  test "buildHtml break inside for loop":
    proc TestBreak(): auto =
      let items = @["a", "b", "stop", "c"]
      buildHtml:
        ul:
          for s in items:
            if s == "stop":
              break
            li: s
    let html = TestBreak()
    check html.contains("<li>a</li>")
    check html.contains("<li>b</li>")
    check not html.contains("<li>c</li>")

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
    proc MyIsland(props: JsonNode): auto =
      buildHtml:
        button: "Click"
    proc Page(): auto =
      buildHtml:
        island MyIsland()
    let html = Page()
    check html.contains("nexum-island")
    check html.contains("MyIsland")

  test "buildHtml island with props embeds JSON in marker":
    proc Counter(props: JsonNode): auto =
      buildHtml:
        button: "Click"
    proc Page(): auto =
      buildHtml:
        island Counter(initial = 5)
    let html = Page()
    check html.contains("nexum-island start=\"Counter\"")
    check html.contains("{\"initial\":5}")

  test "buildHtml island with multiple props":
    proc Widget(props: JsonNode): auto =
      buildHtml:
        span: "Widget"
    proc Page(): auto =
      buildHtml:
        island Widget(label = "hello", step = 3)
    let html = Page()
    check html.contains("{\"label\":\"hello\",\"step\":3}")

  test "buildHtml hyphenated attribute name (infix)":
    proc TestHyphen(): auto =
      buildHtml:
        span(class = "om-timestamp", data-time = "2026-06-17 18:37:13.956608+00"): "now"
    check TestHyphen() == "<span class=\"om-timestamp\" data-time=\"2026-06-17 18:37:13.956608+00\">now</span>"

  test "buildHtml backtick-quoted hyphenated attribute name":
    proc TestHyphenQuoted(): auto =
      buildHtml:
        span(class = "om-timestamp", `data-time` = "v"): "now"
    check TestHyphenQuoted() == "<span class=\"om-timestamp\" data-time=\"v\">now</span>"

  test "writeText escapes only & < > (not \") for text content":
    let ctx = newRenderContext()
    ctx.writeText("a<b>c & d\"e>f")
    check ctx.buf == "a&lt;b&gt;c &amp; d\"e&gt;f"

  test "writeEscaped still escapes \" for attribute values":
    let ctx = newRenderContext()
    ctx.writeEscaped("x\"y<z&w")
    check ctx.buf == "x&quot;y&lt;z&amp;w"

  test "buildHtml text content does not bloat quotes (JSON embedding)":
    let json = "{\"name\":\"A<B&b\"}"
    proc Embed(): auto =
      buildHtml:
        `div`(id = "ssr-x", style = "display:none;"): json
    let html = Embed()
    check html == "<div id=\"ssr-x\" style=\"display:none;\">{\"name\":\"A&lt;B&amp;b\"}</div>"

  test "buildHtml void elements emit no closing tag":
    proc Head(): auto =
      buildHtml:
        link(rel = "stylesheet", href = "/style.css")
        meta(name = "viewport", content = "width=device-width")
        img(src = "/logo.png", alt = "logo")
    let html = Head()
    check html == "<link rel=\"stylesheet\" href=\"/style.css\"><meta name=\"viewport\" content=\"width=device-width\"><img src=\"/logo.png\" alt=\"logo\">"

  test "buildHtml non-void elements still close normally":
    proc Box(): auto =
      buildHtml:
        `div`(class = "box"): "hi"
    check Box() == "<div class=\"box\">hi</div>"

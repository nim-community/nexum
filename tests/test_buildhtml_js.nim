import nexum
import nexum/compiler/buildhtml

proc hello(): auto =
  buildHtml:
    span(class = "hero"):
      h1: "Hello Nexum"
      p: "A compile-time reactive framework"

when defined(js):
  discard hello()

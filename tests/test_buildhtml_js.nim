import helix
import helix/compiler/buildhtml

proc hello(): auto =
  buildHtml:
    span(class="hero"):
      h1: "Hello Helix"
      p: "A compile-time reactive framework"

when defined(js):
  discard hello()

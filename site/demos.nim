## Nexum Site — Interactive Island Demos (dual-target: C + JS)

import nexum
import nexum/compiler/buildhtml

let count = signal(0)

island:
  proc CounterDemo*(props: JsonNode): auto =
    buildHtml:
      `div`(class = "demo-row"):
        h4: "Signal Counter"
        button(onclick = proc(ev: Event) = count.set(count() + 1)): "Clicked "
        span: $count()
        span: " times"

let name = signal("")

island:
  proc BindingDemo*(props: JsonNode): auto =
    buildHtml:
      `div`(class = "demo-row"):
        h4: "Data Binding"
        `div`(class = "demo-input-row"):
          label: "Your name:"
          input(type = "text", oninput = proc(ev: Event) = name.set($cast[Element](ev.target).value))
        p:
          "Hello, " & $name() & "!"
        p(class = "demo-meta"):
          "Characters: " & $name().len

let show = signal(true)

island:
  proc ConditionalDemo*(props: JsonNode): auto =
    buildHtml:
      `div`(class = "demo-row"):
        h4: "Conditional Rendering"
        button(onclick = proc(ev: Event) = show.set(not show())): "Toggle"
        span: " Status: "
        span(class = "demo-highlight"): $(if show(): "✨ Visible!" else: "Hidden")

## Helix Official Site — Client Bundle
##
## Compiles to JS and hydrates interactive islands.

import helix
import helix/compiler/buildhtml

when defined(js):
  # --- Counter demo ---
  let count = signal(0)

  proc CounterDemo(): auto =
    buildHtml:
      `div`(class="demo-row"):
        h4: "Signal Counter"
        button(onclick = proc(ev: Event) = count.set(count() + 1)): "Clicked "
        span: $count()
        span: " times"

  # --- Data binding demo ---
  let name = signal("")

  proc BindingDemo(): auto =
    buildHtml:
      `div`(class="demo-row"):
        h4: "Data Binding"
        `div`(class="demo-input-row"):
          label: "Your name:"
          input(type="text", oninput = proc(ev: Event) = name.set($ev.target.value))
        p:
          "Hello, " & $name() & "!"
        p(class="demo-meta"):
          "Characters: " & $name().len

  # --- Conditional rendering demo ---
  let show = signal(true)

  proc ConditionalDemo(): auto =
    let statusSpan = document.createElement(cstring"span")
    statusSpan.className = cstring"demo-highlight"

    let root = buildHtml:
      `div`(class="demo-row"):
        h4: "Conditional Rendering"
        button(onclick = proc(ev: Event) = show.set(not show())): "Toggle"
        span: " Status: "
        statusSpan

    createEffect(proc() =
      statusSpan.textContent = cstring(if show(): "✨ Visible!" else: "Hidden")
    )
    root

  # --- Mount ---
  let mount = document.querySelector(cstring"#demo-mount")
  if mount != nil:
    mount.innerHTML = ""
    mount.appendChild(CounterDemo())
    mount.appendChild(BindingDemo())
    mount.appendChild(ConditionalDemo())

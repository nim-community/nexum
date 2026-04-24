## Helix Official Site — Built with Helix

import helix
import helix/compiler/buildhtml

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

proc NavLink(href, text: string): auto =
  buildHtml:
    a(class="nav-link", href=href): text

# ---------------------------------------------------------------------------
# Components
# ---------------------------------------------------------------------------

proc HeroSection(): auto =
  buildHtml:
    header(class="hero"):
      `div`(class="hero-pretitle"): "NIM · COMPILE-TIME · REACTIVE"
      h1: "Helix"
      `div`(class="hero-rule"):
        span: "◆"
      p: "A compile-time reactive web framework for Nim."
      span(class="badge"): "Experimental · Design Phase"
      `div`(class="hero-cta"):
        a(href="#quickstart", class="btn-primary"): "Get Started"
        a(href="https://github.com/nim-works/helix", class="btn-secondary"): "GitHub"

proc WhatIsSection(): auto =
  buildHtml:
    section(class="container", id="what-is"):
      h2: "What is Helix"
      p:
        "Helix generates fine-grained DOM updates at compile time using Nim's macro system. " &
        "No virtual DOM. No diffing algorithm. Just precise, signal-driven mutations emitted directly from your templates."
      p:
        "The same component code compiles to both a C server binary emitting HTML strings and a JS client bundle mounting real DOM."
      `div`(class="features-grid"):
        `div`(class="feature-card"):
          h3: "Compile-Time Codegen"
          p: "Templates are parsed into IR and lowered to imperative DOM or string-builder code at compile time."
        `div`(class="feature-card"):
          h3: "Fine-Grained Signals"
          p: "Signal reads auto-track dependencies. Effects rerun only when their sources change, Solid.js-style."
        `div`(class="feature-card"):
          h3: "Isomorphic by Default"
          p: "One source file, two backends. SSR emits HTML; the client hydrates only the islands you mark."
        `div`(class="feature-card"):
          h3: "Zero-JS Static Pages"
          p: "Unmarked components ship zero JavaScript. Only island-marked components are sent to the browser."

proc CodeExample(title: string; code: string): auto =
  buildHtml:
    `div`(class="code-example"):
      `div`(class="code-header"):
        span(class="code-title"): title
        span(class="code-lang"): "Nim"
      `div`(class="code-block"):
        pre:
          code(class="language-nim"): code

proc LiveExample(title, code: string; demoId: string): auto =
  buildHtml:
    `div`(class="example-playground"):
      `div`(class="code-col"):
        CodeExample(title, code)
      `div`(class="demo-col"):
        `div`(class="demo-col-label"): "Live Result"
        `div`(id=demoId)

proc ExamplesSection(): auto =
  buildHtml:
    section(class="container", id="examples"):
      h2: "See It In Action"
      p: "Helix templates look like HTML but compile to zero-overhead DOM operations."

      LiveExample("Reactive signals",
        "let count = signal(0)\n" &
        "\n" &
        "proc Counter(): auto =\n" &
        "  buildHtml:\n" &
        "    button(\n" &
        "      onclick = proc(ev: Event) = count.set(count() + 1)\n" &
        "    ): \"Clicked \" & $count() & \" times\"",
        "demo-counter")

      LiveExample("Data binding",
        "let name = signal(\"\")\n" &
        "\n" &
        "proc Greeting(): auto =\n" &
        "  buildHtml:\n" &
        "    input(\n" &
        "      type = \"text\",\n" &
        "      oninput = proc(ev: Event) =\n" &
        "        name.set($ev.target.value)\n" &
        "    )\n" &
        "    p: \"Hello, \" & $name()",
        "demo-binding")

      LiveExample("Control flow",
        "let show = signal(true)\n" &
        "\n" &
        "proc Conditional(): auto =\n" &
        "  buildHtml:\n" &
        "    if show():\n" &
        "      p: \"Visible!\"\n" &
        "    else:\n" &
        "      p: \"Hidden\"\n" &
        "    for i in 1..3:\n" &
        "      li: $i",
        "demo-conditional")

proc UnderTheHoodSection(): auto =
  buildHtml:
    section(class="container", id="internals"):
      h2: "Under The Hood"
      p: "Three stages. Three layers. One source file. Two compiled outputs."

      h3: "The Pipeline"
      `div`(class="pipeline"):
        `div`(class="pipeline-step"):
          span(class="pipeline-num"): "01"
          h3: "Parse"
          p: "buildHtml DSL is parsed into an intermediate representation at compile time."
        `div`(class="pipeline-arrow"): "→"
        `div`(class="pipeline-step"):
          span(class="pipeline-num"): "02"
          h3: "Analyze"
          p: "The analyzer detects dynamic text, attributes, events, and islands."
        `div`(class="pipeline-arrow"): "→"
        `div`(class="pipeline-step"):
          span(class="pipeline-num"): "03"
          h3: "Codegen"
          p: "Backend-specific codegen emits DOM code (JS) or string builders (C)."

      h3: "The Stack"
      `div`(class="layer-stack"):
        `div`(class="layer layer-app"):
          `div`(class="layer-num"): "1"
          `div`(class="layer-body"):
            h4: "App Layer"
            p: "@component · @page · buildHtml · Signal"
        `div`(class="layer layer-compiler"):
          `div`(class="layer-num"): "2"
          `div`(class="layer-body"):
            h4: "Compiler Layer"
            p: "Parser → Analyzer → Codegen (Client / Server)"
        `div`(class="layer layer-runtime"):
          `div`(class="layer-num"): "3"
          `div`(class="layer-body"):
            h4: "Runtime Layer"
            p: "Signals · DOM Runtime · SSR Renderer · Hydrator"

      p:
        "The parser transforms the "
        code: "buildHtml"
        " DSL into an intermediate representation. " &
        "The analyzer detects dynamic text, attributes, events, and islands. " &
        "Backend-specific codegen emits either DOM creation code (JS) or fast string-building code (C). " &
        "Components marked with "
        code: "@island"
        " are emitted with hydration markers so the client only rehydrates the interactive parts."

proc BenchmarkSection(): auto =
  buildHtml:
    section(class="container", id="benchmarks"):
      h2: "The Numbers"
      p: "Compile-time codegen eliminates the runtime overhead that other frameworks carry."
      `div`(class="benchmark-table-wrap"):
        table(class="benchmark-table"):
          thead:
            tr:
              th: ""
              th: "Runtime"
              th: "VDOM"
              th: "SSR"
              th: "Hydration"
              th: "Lang"
          tbody:
            tr:
              td: "React"
              td: "~40 KB"
              td: "Yes"
              td: "Yes"
              td: "Full"
              td: "JS"
            tr:
              td: "Vue"
              td: "~30 KB"
              td: "Yes"
              td: "Yes"
              td: "Full"
              td: "JS"
            tr:
              td: "Svelte"
              td: "~5 KB"
              td: "No"
              td: "Yes"
              td: "Full"
              td: "JS"
            tr:
              td: "Solid"
              td: "~7 KB"
              td: "No"
              td: "Yes"
              td: "Full"
              td: "JS"
            tr:
              td(class="highlight"): "Helix"
              td(class="highlight"): "0 KB"
              td(class="highlight"): "No"
              td(class="highlight"): "Yes"
              td(class="highlight"): "Islands"
              td(class="highlight"): "Nim"

proc QuickstartSection(): auto =
  buildHtml:
    section(class="container", id="quickstart"):
      h2: "Get Started"
      `div`(class="quickstart"):
        h3: "Install"
        `div`(class="code-snippet"):
          pre: "nimble install helix"
          button(class="copy-btn", data-clipboard="nimble install helix"): "Copy"
        h3: "Define a component"
        `div`(class="code-snippet"):
          pre: "proc greeting(): auto =\n  buildHtml:\n    h1: \"Hello, Helix\""
          button(class="copy-btn", data-clipboard="proc greeting(): auto =\n  buildHtml:\n    h1: \"Hello, Helix\""): "Copy"
        h3: "Render on the server"
        `div`(class="code-snippet"):
          pre: "echo greeting()  # → <h1>Hello, Helix</h1>"
          button(class="copy-btn", data-clipboard="echo greeting()"): "Copy"

proc FooterSection(): auto =
  buildHtml:
    footer(class="container"):
      `div`(class="footer-grid"):
        `div`(class="footer-col"):
          h4: "Helix"
          p: "Compile-time reactive web framework for Nim."
        `div`(class="footer-col"):
          h4: "Resources"
          a(href="#quickstart"): "Get Started"
          a(href="#examples"): "Examples"
          a(href="#internals"): "Internals"
        `div`(class="footer-col"):
          h4: "Community"
          a(href="https://github.com/nim-works/helix"): "GitHub"
          a(href="https://github.com/nim-works/helix/issues"): "Issues"
      `div`(class="footer-bottom"):
        p: "Built with Helix — AGPL-3.0"

# ---------------------------------------------------------------------------
# Page
# ---------------------------------------------------------------------------

proc indexPage*(): auto =
  buildHtml:
    html(lang="en"):
      head:
        meta(charset="utf-8")
        meta(name="viewport", content="width=device-width, initial-scale=1")
        title: "Helix — Compile-time Reactive Web Framework for Nim"
        meta(name="description", content="Helix generates fine-grained DOM updates at compile time. No virtual DOM. Isomorphic by default.")
        link(rel="preconnect", href="https://fonts.bunny.net")
        link(rel="stylesheet", href="https://fonts.bunny.net/css2?family=Shrikhand&family=Source+Sans+3:wght@400;600;700&family=Space+Mono:wght@400;700&display=swap")
        link(rel="stylesheet", href="style.css")
      body:
        nav(class="main-nav"):
          `div`(class="nav-inner"):
            a(href="#", class="nav-brand"):
              span(class="nav-brand-icon"): "◈"
              span(class="nav-brand-text"): "Helix"
            `div`(class="nav-links"):
              NavLink("#what-is", "What is Helix")
              NavLink("#examples", "Examples")
              NavLink("#internals", "Internals")
              NavLink("#quickstart", "Get Started")
              a(href="https://github.com/nim-works/helix", class="nav-link nav-link-gh"): "GitHub"
        HeroSection()
        WhatIsSection()
        ExamplesSection()
        UnderTheHoodSection()
        BenchmarkSection()
        QuickstartSection()
        FooterSection()
        script(src="client.js")
        script(type="text/javascript"):
          """
          // Scroll-triggered section reveals
          (function() {
            var observer = new IntersectionObserver(function(entries) {
              entries.forEach(function(entry) {
                if (entry.isIntersecting) {
                  entry.target.classList.add('visible');
                }
              });
            }, { threshold: 0.1 });
            document.querySelectorAll('section').forEach(function(s) {
              observer.observe(s);
            });
            // Reveal hero immediately
            document.querySelector('header').classList.add('visible');
          })();

          // Copy buttons
          (function() {
            document.querySelectorAll('.copy-btn').forEach(function(btn) {
              btn.addEventListener('click', function() {
                var text = btn.getAttribute('data-clipboard');
                if (navigator.clipboard) {
                  navigator.clipboard.writeText(text);
                }
                var original = btn.textContent;
                btn.textContent = 'Copied!';
                btn.classList.add('copied');
                setTimeout(function() {
                  btn.textContent = original;
                  btn.classList.remove('copied');
                }, 1500);
              });
            });
          })();

          // Nim syntax highlighter
          (function() {
            var keywords = ['proc','func','let','var','const','if','else','elif','for','while','case','of','import','export','when','template','macro','type','object','ref','distinct','concept','return','discard','break','continue','raise','try','except','finally','block','defer','mixin','bind','using','addr','ptr','cast','static','assert','do','yield','asm','converter','iterator','method','enum','tuple','set','seq','array','openArray','range','pointer','cstring','string','int','float','bool','char','byte','void','auto','generic'];
            var keywordRe = new RegExp('\\b(' + keywords.join('|') + ')\\b', 'g');
            document.querySelectorAll('code.language-nim').forEach(function(el) {
              var text = el.textContent;
              var html = text
                .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
                .replace(/("(?:"|[^"])*")/g, '<span class="s">$1</span>')
                .replace(/('[^']*')/g, '<span class="s">$1</span>')
                .replace(/(#.*$)/gm, '<span class="c">$1</span>')
                .replace(/\b(\d+(?:\.\d+)?)\b/g, '<span class="n">$1</span>')
                .replace(keywordRe, '<span class="k">$1</span>')
                .replace(/\b([A-Z][A-Za-z0-9_]*)\b/g, '<span class="f">$1</span>');
              el.innerHTML = html;
            });
          })();
          """

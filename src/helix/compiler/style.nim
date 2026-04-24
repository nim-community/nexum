## Helix Style — Compile-time scoped CSS
##
## Usage:
##   const myStyle = @style """
##     .title { color: var(--accent); }
##   """
##   proc MyComponent(): auto =
##     buildHtml:
##       div(class = myStyle.scope):
##         h1(class = "title"): "Hello"
##
## In your page, inject the CSS into <head>:
##   buildHtml:
##     html(lang="en"):
##       head:
##         style: myStyle.css
##       body:
##         MyComponent()

import std/[macros, strutils, hashes]

type
  StyleBlock* = object
    scope*: string
    css*: string

proc scopeCss*(css, scopeClass: string): string =
  ## Simple CSS scoping: prepend `.scopeClass ` to every top-level selector.
  ## Does not support nested CSS or @media blocks (v1 limitation).
  result = ""
  var depth = 0
  var selectorBuf = ""
  var bodyBuf = ""
  var inString = false
  var stringChar = '\0'

  for c in css:
    if inString:
      if c == stringChar:
        inString = false
      if depth == 0:
        selectorBuf.add(c)
      else:
        bodyBuf.add(c)
      continue

    case c
    of '"', '\'':
      inString = true
      stringChar = c
      if depth == 0:
        selectorBuf.add(c)
      else:
        bodyBuf.add(c)
    of '{':
      inc depth
      if depth == 1:
        bodyBuf.add(c)
      else:
        bodyBuf.add(c)
    of '}':
      dec depth
      bodyBuf.add(c)
      if depth == 0:
        let sel = selectorBuf.strip
        if sel.len > 0:
          for s in sel.split(','):
            let part = s.strip
            if part.len > 0:
              if result.len > 0: result.add("\n")
              result.add(".")
              result.add(scopeClass)
              result.add(" ")
              result.add(part)
              result.add(" ")
              result.add(bodyBuf)
        selectorBuf = ""
        bodyBuf = ""
    else:
      if depth == 0:
        selectorBuf.add(c)
      else:
        bodyBuf.add(c)

  let sel = selectorBuf.strip
  if sel.len > 0 and bodyBuf.len > 0:
    for s in sel.split(','):
      let part = s.strip
      if part.len > 0:
        if result.len > 0: result.add("\n")
        result.add(".")
        result.add(scopeClass)
        result.add(" ")
        result.add(part)
        result.add(" ")
        result.add(bodyBuf)

macro style*(css: static[string]): untyped =
  ## Scopes a CSS block and returns a StyleBlock.
  let h = hash(css) mod 0xFFFFFF
  let scopeClass = "helix-" & toHex(h.int, 6)
  let scoped = scopeCss(css, scopeClass)

  let scopeLit = newLit(scopeClass)
  let cssLit = newLit(scoped)

  # Return: StyleBlock(scope: "...", css: "...")
  result = newTree(nnkObjConstr, ident"StyleBlock",
    newTree(nnkExprColonExpr, ident"scope", scopeLit),
    newTree(nnkExprColonExpr, ident"css", cssLit))

template collectCss*(styles: varargs[StyleBlock]): string =
  ## Concatenates multiple StyleBlock CSS strings.
  var res = ""
  for s in styles:
    res.add(s.css)
    res.add("\n")
  res

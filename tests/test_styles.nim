import unittest, strutils
import nexum/compiler/style

suite "Scoped CSS":
  test "scopeCss basic":
    let css = scopeCss(".title { color: red; }", "Test")
    check css.contains(".Test .title { color: red; }")

  test "scopeCss multiple selectors":
    let css = scopeCss(".title, .btn { color: red; }", "Test")
    check css.contains(".Test .title { color: red; }")
    check css.contains(".Test .btn { color: red; }")

  test "style macro returns StyleBlock":
    const sb = style """
      .title { color: red; }
      .btn { background: blue; }
    """
    check sb.scope.len > 0
    check sb.css.len > 0
    check sb.css.contains("." & sb.scope & " .title { color: red; }")
    check sb.css.contains("." & sb.scope & " .btn { background: blue; }")

  test "collectCss merges blocks":
    const a = style ".x { color: red; }"
    const b = style ".y { color: blue; }"
    let merged = collectCss(a, b)
    check merged.contains("." & a.scope & " .x { color: red; }")
    check merged.contains("." & b.scope & " .y { color: blue; }")

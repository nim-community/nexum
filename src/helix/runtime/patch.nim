## Helix Runtime — Patch / Mount: attaching components to DOM nodes.
##
## Unlike VDOM diff, this is a one-time structural walk to bind
## compiled component shapes to real DOM.

when not defined(js):
  {.error: "patch.nim targets JS only".}

import dom, ../core/signals, ../core/scope

type
  MountPoint* = ref object
    root*: Node
    scope*: Scope

proc mount*(target: Element; builder: proc(): Node): MountPoint =
  ## Replaces target contents with a freshly built DOM subtree.
  target.innerHTML = ""
  let root = builder()
  target.appendChild(root)
  MountPoint(root: root)

proc unmount*(mp: MountPoint) =
  if mp.root != nil and mp.root.parentNode != nil:
    mp.root.parentNode.removeChild(mp.root)
  if mp.scope != nil:
    mp.scope.dispose()
  mp.root = nil
  mp.scope = nil

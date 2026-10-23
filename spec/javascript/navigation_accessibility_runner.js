// Real browser DOM/CSS regressions; the imported controllers are the shipped sources.
document.body.className = "wm page"
document.body.dataset.theme = "dark"
document.body.innerHTML = `
<form id="palette-form"><input id="search" type="search" aria-label="Search" aria-controls="wm-palette"><div id="palette-wrap" hidden><div id="palette-panel"></div></div></form>
<button id="opener">Open files</button>
<div class="sheet-overlay" hidden><div class="sheet" role="dialog" aria-modal="true" aria-label="Files">
<button id="close">Close</button><div id="sheet-body"><nav class="tree">
<input class="filter" type="search" aria-label="Filter paths">
<button class="d" data-level="0" data-path="lib" data-tree-target="row" aria-expanded="true"><span class="c"></span><span class="nm">lib</span><span class="ct">3</span></button>
<a class="f" href="#a" data-level="1" data-path="lib/shared/a.rb" data-tree-target="row" data-owner-keys='[["Shared","model"],["Shared","lib"],["Settings","configuration"]]'><span class="nm">a.rb</span></a>
<a class="f" href="#b" data-level="1" data-path="lib/shared/b.rb" data-tree-target="row" data-owner-keys='[["Shared","lib"]]'><span class="nm">b.rb</span></a>
<a class="f" href="#ghost" data-level="1" data-path="lib/ghost.rb" data-tree-target="row" data-owner-keys='[]'><span class="nm">ghost.rb</span></a>
</nav></div></div></div><button id="outside">Outside</button><pre id="result"></pre>`

const overlay = document.querySelector(".sheet-overlay")
const nav = document.querySelector(".tree")
const filter = nav.querySelector("input")
const close = document.getElementById("close")
const opener = document.getElementById("opener")
const palette = new PaletteController()
Object.assign(palette, { element: document.getElementById("palette-form"), inputTarget: document.getElementById("search"),
  wrapTarget: document.getElementById("palette-wrap"), panelTarget: document.getElementById("palette-panel") })
palette.connect()
const tree = new TreeController()
Object.assign(tree, { element: nav, filterTarget: filter, rowTargets: [...nav.querySelectorAll("[data-tree-target=row]")] })
tree.connect()
const sheet = new SheetController()
Object.assign(sheet, { element: document.body, overlayTarget: overlay, hasOverlayTarget: true,
  bodyTarget: document.getElementById("sheet-body"), closeTarget: close, hasCloseTarget: true })
sheet.connect()
opener.focus()
sheet.open({ currentTarget: opener })
filter.value = "ghost"
tree.filter()
const ghost = nav.querySelector('[data-path="lib/ghost.rb"]')
const unresolvedVisible = ghost.getClientRects().length > 0
const unresolvedCount = nav.querySelector(".d .ct").textContent
filter.value = "shared"
tree.filter()
const files = [...nav.querySelectorAll("a.f")].filter((element) => element.getClientRects().length > 0)
const count = nav.querySelector(".d .ct").textContent
const last = files[files.length - 1]
last.focus()
const forward = new KeyboardEvent("keydown", { key: "Tab", bubbles: true, cancelable: true })
last.dispatchEvent(forward)
const forwardWrapped = document.activeElement === close && forward.defaultPrevented
close.focus()
const backward = new KeyboardEvent("keydown", { key: "Tab", shiftKey: true, bubbles: true, cancelable: true })
close.dispatchEvent(backward)
const backwardWrapped = document.activeElement === last && backward.defaultPrevented
const modalSlash = new KeyboardEvent("keydown", { key: "/", bubbles: true, cancelable: true })
last.dispatchEvent(modalSlash)
const modalShortcutIgnored = document.activeElement === last && palette.wrapTarget.hidden && sheet.isOpen
palette.close()
last.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }))
const restored = overlay.hidden && document.activeElement === opener
const ordinarySlash = new KeyboardEvent("keydown", { key: "/", bubbles: true, cancelable: true })
opener.dispatchEvent(ordinarySlash)
const ordinaryShortcutOpens = document.activeElement === palette.inputTarget && !palette.wrapTarget.hidden && ordinarySlash.defaultPrevented
document.getElementById("result").textContent = JSON.stringify({
  paths: files.map((element) => element.dataset.path), count, unresolvedVisible, unresolvedCount,
  forwardWrapped, backwardWrapped, restored, modalShortcutIgnored, ordinaryShortcutOpens
})

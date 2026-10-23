// Real layout regression for the shipped sheets. Each iframe is an isolated viewport;
// source is synthetic and preserves the CodeView's display:contents row structure.
const widths = [1440, 960, 640, 390]
const mounts = ["/woods", "/catalog/map"]
const lenses = ["written", "effective"]
const failures = []
let cases = 0
const styles = document.getElementById("shipped-styles").textContent

function sourceState(doc) {
  return [...doc.querySelectorAll(".src")].map(row => ({
    text: row.textContent,
    links: [...row.querySelectorAll("a")].map(link => ({
      text: link.textContent, href: link.getAttribute("href"), target: link.dataset.target,
      type: link.dataset.type, kind: link.dataset.kind, name: link.getAttribute("aria-label")
    }))
  }))
}

for (const mount of mounts) for (const lens of lenses) for (const width of widths) {
  const details = { mount, lens, width }
  const frame = document.createElement("iframe")
  frame.style.cssText = `width:${width}px;height:500px;border:0`
  document.body.append(frame)
  const doc = frame.contentDocument
  doc.open()
  doc.write(`<!doctype html><html lang="en"><head></head><body class="wm page" data-theme="dark">
    <div class="body"><div class="main"><div class="cvwrap" role="region" aria-label="Source">
    <div class="cv codeview"><div class="hdr"><b>${lens}</b><span>source</span></div>
    ${lens === "effective" ? '<div class="fold">schema header</div>' : ""}
    <div class="row" style="display:contents"><div class="heat"><i></i></div><div class="ln">1</div><div class="src"></div><div class="mg">a note</div></div>
    <div class="row" style="display:contents"><div class="heat"><i></i></div><div class="ln">2</div><div class="src"></div><div class="mg"></div></div>
    ${lens === "effective" ? '<div class="fold">included from SyntheticConcern</div>' : ""}
    </div></div></div></div></body></html>`)
  doc.close()
  const style = doc.createElement("style")
  style.textContent = styles
  doc.head.append(style)
  const source = doc.querySelector(".src")
  source.append(doc.createTextNode('\tvalue = "é雪"; '))
  for (let i = 0; i < 2; i++) {
    const link = doc.createElement("a")
    link.className = "const"
    link.setAttribute("href", `${mount}/units/service/Synthetic::Target`)
    link.setAttribute("aria-label", "Synthetic::Target (service), verified constant reference")
    Object.assign(link.dataset, { target: "Synthetic::Target", type: "service", kind: "constant" })
    link.textContent = "Synthetic::Target"
    source.append(link, doc.createTextNode(".call; "))
  }
  source.append(doc.createTextNode('"' + "long_field_".repeat(6) + '"\r'))
  doc.querySelectorAll(".src")[1].textContent = "end"
  const initialSource = sourceState(doc)
  const wrap = doc.querySelector(".cvwrap")
  const grid = doc.querySelector(".cv")
  const sticky = [...doc.querySelectorAll(".heat, .ln, .hdr, .fold")]
  const initialX = sticky.map(node => node.getBoundingClientRect().left)
  const check = (ok, reason, evidence) => {
    if (!ok) failures.push({ ...details, reason, ...evidence })
  }
  check(frame.contentWindow.innerWidth === width, "fixture viewport", { actual: frame.contentWindow.innerWidth })
  check([...doc.querySelectorAll(".src")].every(node => frame.contentWindow.getComputedStyle(node).overflowX === "visible"), "source has its own scroll region")
  check(grid.getBoundingClientRect().width >= grid.scrollWidth - 1, "grid does not enclose its overflow tracks", {
    gridWidth: grid.getBoundingClientRect().width, gridScrollWidth: grid.scrollWidth
  })
  for (const fraction of [0.5, 1, 0]) {
    wrap.scrollLeft = (wrap.scrollWidth - wrap.clientWidth) * fraction
    const left = wrap.getBoundingClientRect().left
    const right = wrap.getBoundingClientRect().right
    sticky.forEach((node, index) => {
      const rect = node.getBoundingClientRect()
      check(Math.abs(rect.left - initialX[index]) < 1 && rect.left >= left - 1 && rect.right <= right + 1,
        "sticky cell leaves its visible position", { fraction, cell: node.className, left: rect.left, right: rect.right, wrapperLeft: left, wrapperRight: right })
    })
    check(JSON.stringify(sourceState(doc)) === JSON.stringify(initialSource), "source or anchors changed while scrolling", { fraction })
  }
  cases++
  frame.remove()
}
document.getElementById("result").textContent = JSON.stringify({ cases, failures })

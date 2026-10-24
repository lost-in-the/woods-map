// The page tabs at phone width: the shipped cliff controller and CSS start
// the row scrolled so the current tab is in view (found on the Graph tab at 390).
document.body.className = "wm page"
document.body.dataset.theme = "dark"
document.body.innerHTML = `<div id="frame" style="width:390px">
<nav class="tabs page-tabs hscroll" aria-label="Sections">
<a class="tab" href="#c">Code <span class="cnt">25 loc</span></a><a class="tab" href="#s">Schema <span class="cnt">10</span></a>
<a class="tab" href="#l">Lifecycle <span class="cnt">5</span></a><a class="tab" href="#g" aria-current="page">Graph <span class="cnt">18</span></a>
<a class="tab" href="#h">History <span class="cnt">2</span></a></nav>
<nav class="tabs page-tabs hscroll" id="first" aria-label="Other"><a class="tab" href="#c" aria-current="page">Code</a><a class="tab" href="#s">Schema</a>
<a class="tab" href="#l">Lifecycle</a><a class="tab" href="#g">Graph</a><a class="tab" href="#h">History</a><a class="tab" href="#x">Passage</a></nav>
</div><pre id="result"></pre>`

const [tabs, first] = document.querySelectorAll("nav")
for (const element of [tabs, first]) {
  const cliff = new CliffController()
  cliff.element = element
  cliff.connect()
}
const box = tabs.getBoundingClientRect()
const current = tabs.querySelector('[aria-current="page"]').getBoundingClientRect()
document.getElementById("result").textContent = JSON.stringify({
  overflows: tabs.scrollWidth > tabs.clientWidth,
  currentVisible: current.left >= box.left - 1 && current.right <= box.right + 1,
  firstUnscrolled: first.scrollLeft === 0
})

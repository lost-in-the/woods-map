// The shipped reveal controller over the shipped sheets: the code view's rows are display:contents
// wrappers, so the fragment target has no box and the browser leaves the source where it was.
const rows = Array.from({ length: 120 }, (_, i) => `<div class="row contents" id="L${i + 1}"><div class="heat"><i></i></div><div class="ln">${i + 1}</div><div class="src">line ${i + 1}</div><div class="mg"></div></div>`).join("")
document.body.className = "wm page"
document.body.dataset.theme = "dark"
document.body.innerHTML = `<div style="height:1400px">header</div><div class="cvwrap"><div class="cv codeview">${rows}</div></div><pre id="result"></pre>`

const controller = new RevealController()
controller.element = document.body
controller.connect()

const visible = (id) => {
  const rect = document.querySelector(`#${id} .src`).getBoundingClientRect()
  return rect.top >= 0 && rect.bottom <= innerHeight
}
const settle = () => new Promise((resolve) => setTimeout(resolve, 150))
const result = {}

await settle()
result.initialScrolled = scrollY > 0
result.initialVisible = visible("L53")

location.hash = "#L97"
await settle()
result.hashchangeVisible = visible("L97")

location.hash = "#L2"
await settle()
result.backwardVisible = visible("L2")

location.hash = "#L9999"
await settle()
result.missingIsQuiet = true

document.getElementById("result").textContent = JSON.stringify(result)

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
const changeHash = (hash) => new Promise((resolve) => {
  window.addEventListener("hashchange", resolve, { once: true })
  location.hash = hash
})
const result = {}

// The controller schedules its initial reveal on a frame; elapsed timer time
// does not prove that frame has run, especially under Chromium virtual time.
await new Promise((resolve) => requestAnimationFrame(resolve))
result.initialScrolled = scrollY > 0
result.initialVisible = visible("L53")

await changeHash("#L97")
result.hashchangeVisible = visible("L97")

await changeHash("#L2")
result.backwardVisible = visible("L2")

await changeHash("#L9999")
result.missingIsQuiet = true

document.getElementById("result").textContent = JSON.stringify(result)

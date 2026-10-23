// Execute the shipped filter and fold methods with a minimal DOM interface.
// Native JavaScriptCore via osascript keeps the regression free of Node tooling.
function run(argv) {
  const source = argv[0]
  const data = JSON.parse(argv[1])
  const Tree = new Function("Controller", source.replace(/^import .*$/m, "").replace("export default class", "return class"))(class {})
  const rows = data.rows.map((entry) => {
    const name = { textContent: entry.name, dataset: {}, innerHTML: "" }
    const count = entry.count == null ? null : { textContent: String(entry.count), dataset: {} }
    const chevron = { textContent: "▾" }
    const attributes = { "aria-expanded": "true" }
    return {
      dataset: { path: entry.path, level: String(entry.level), ownerKeys: JSON.stringify(entry.owner_keys || []) },
      classList: { contains: (kind) => kind === (entry.kind === "file" ? "f" : "d") },
      querySelector: (selector) => ({ ".nm": name, ".ct": count, ".c": chevron })[selector],
      setAttribute: (key, value) => { attributes[key] = value },
      getAttribute: (key) => attributes[key],
      hidden: false
    }
  })
  rows.forEach((row, index) => {
    row.previousElementSibling = rows[index - 1]
    row.nextElementSibling = rows[index + 1]
  })
  const controller = new Tree()
  controller.rowTargets = rows
  controller.filterTarget = { value: "" }
  data.queries.forEach((query) => {
    controller.filterTarget.value = query
    controller.filter()
  })
  return JSON.stringify(rows.map((row) => ({
    path: row.dataset.path,
    hidden: row.hidden,
    count: row.querySelector(".ct")?.textContent,
    filtered: row.dataset.filtered
  })))
}

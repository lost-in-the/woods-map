import { Controller } from "@hotwired/stimulus"

// Reading settings (B-15, D-6), per browser. Wrap, font size and the editor
// link live in localStorage (every access wrapped: storage may be absent or
// refused); the lens keeps its own mechanism, the ?lens= redirect that sets
// the server's cookie, so a lens choice here simply follows that link.
// Nothing is guessed from the index: the editor link exists only when this
// browser names an editor and the checkout path it lives in (decisions.md).
//
// Lives on the .wm root, so every page gets the code size and wrap on load;
// the dialog and the editor button exist only on the Code tab.
const KEY = "woods_map.settings"
const SIZES = ["small", "medium", "large"]
const PRESETS = {
  vscode: "vscode://file{path}:{line}",
  cursor: "cursor://file{path}:{line}",
  idea: "idea://open?file={path}&line={line}",
  textmate: "txmt://open?url=file://{path}&line={line}",
  zed: "zed://file{path}:{line}"
}
const UNSAFE = /^\s*(javascript|data|vbscript):/i

function readSettings(storage) {
  try {
    const value = JSON.parse(storage.getItem(KEY) || "{}")
    return value && typeof value === "object" ? value : {}
  } catch (_) { return {} }
}

// The editor URL for an application-relative file and line, or null.
function editorUrl(settings, file, line) {
  const editor = settings.editor || "none"
  const template = editor === "custom" ? (settings.template || "").trim() : PRESETS[editor]
  if (!template || !file) return null
  const root = (settings.root || "").trim().replace(/[\\/]+$/, "")
  if (template.includes("{path}") && !root) return null
  const path = encodeURI(`${root}/${file}`)
  const url = template.replaceAll("{path}", path).replaceAll("{file}", encodeURI(file)).replaceAll("{line}", String(line || 1))
  if (UNSAFE.test(url) || !/^[a-z][a-z0-9+.-]*:/i.test(url)) return null
  return url
}

export default class extends Controller {
  static targets = ["dialog", "form", "editor", "code", "custom", "preview"]

  connect() {
    this.settings = readSettings(this.storage())
    this.apply()
    this.onHash = () => this.refreshEditor()
    window.addEventListener("hashchange", this.onHash)
  }

  disconnect() {
    window.removeEventListener("hashchange", this.onHash)
  }

  storage() {
    try { return window.localStorage } catch (_) { return { getItem: () => null, setItem: () => {} } }
  }

  save() {
    try { this.storage().setItem(KEY, JSON.stringify(this.settings)) } catch (_) {}
  }

  apply() {
    const root = this.element
    if (this.settings.wrap === true) root.dataset.codeWrap = "on"
    else delete root.dataset.codeWrap
    if (SIZES.includes(this.settings.size) && this.settings.size !== "medium") root.dataset.codeSize = this.settings.size
    else delete root.dataset.codeSize
    this.refreshEditor()
  }

  // The Code tab's primary action becomes "In editor at L…" only when this
  // browser has an editor; otherwise "Code at L…" stays.
  refreshEditor() {
    if (!this.hasEditorTarget) return
    const link = this.editorTarget
    const hash = /^#L(\d+)$/.exec(window.location.hash)
    const line = hash ? Number(hash[1]) : Number(link.dataset.line || 1)
    const url = editorUrl(this.settings, link.dataset.file, line)
    link.hidden = !url
    if (url) {
      link.href = url
      link.textContent = `In editor at L${line}`
    } else {
      link.removeAttribute("href")
    }
    if (this.hasCodeTarget) this.codeTarget.hidden = !!url
  }

  open() {
    if (!this.hasDialogTarget || this.dialogTarget.open) return
    this.opener = document.activeElement
    this.fill()
    this.dialogTarget.showModal()
    this.formTarget.querySelector("input:checked, input, select")?.focus()
  }

  close() {
    if (this.hasDialogTarget && this.dialogTarget.open) this.dialogTarget.close()
  }

  restore() {
    if (this.opener?.isConnected) this.opener.focus()
  }

  outside(event) {
    if (event.target !== this.dialogTarget) return
    const box = this.dialogTarget.getBoundingClientRect()
    if (event.clientX < box.left || event.clientX > box.right || event.clientY < box.top || event.clientY > box.bottom) this.close()
  }

  fill() {
    const form = this.formTarget
    const s = this.settings
    form.elements.wrap.checked = s.wrap === true
    for (const radio of form.querySelectorAll("input[name=size]")) radio.checked = radio.value === (SIZES.includes(s.size) ? s.size : "medium")
    form.elements.editor.value = s.editor && (s.editor === "custom" || PRESETS[s.editor]) ? s.editor : "none"
    form.elements.root.value = s.root || ""
    form.elements.template.value = s.template || ""
    this.preview()
  }

  // Every control saves as it changes; the lens follows its own link.
  change(event) {
    const form = this.formTarget
    if (event?.target?.name === "lens") {
      const url = event.target.dataset.url
      if (url) window.location.assign(url)
      return
    }
    this.settings = {
      wrap: form.elements.wrap.checked,
      size: form.querySelector("input[name=size]:checked")?.value || "medium",
      editor: form.elements.editor.value,
      root: form.elements.root.value.trim(),
      template: form.elements.template.value.trim()
    }
    this.save()
    this.apply()
    this.preview()
  }

  preview() {
    const form = this.formTarget
    const editor = form.elements.editor.value
    if (this.hasCustomTarget) this.customTarget.hidden = editor !== "custom"
    if (!this.hasPreviewTarget) return
    const link = this.hasEditorTarget ? this.editorTarget : null
    const sample = link?.dataset.file || "app/models/example.rb"
    const url = editorUrl(this.settings, sample, Number(link?.dataset.line || 1))
    if (editor === "none") this.previewTarget.textContent = "No editor: the Code tab keeps Code at L… as its primary action."
    else if (url) this.previewTarget.textContent = `Opens ${url}`
    else if (editor === "custom" && UNSAFE.test(form.elements.template.value)) this.previewTarget.textContent = "That link scheme is not allowed."
    else this.previewTarget.textContent = editor === "custom" ? "Add a link template with {path} or {file} and {line}." : "Add the checkout path to make the link."
  }
}

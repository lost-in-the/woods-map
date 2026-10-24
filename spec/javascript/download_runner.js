// Real browser regression for the download tool: the shipped controller saves
// the panel's Mermaid text (or the text it is given) as a .mmd file built in
// the browser, without a request. The anchor click and the object URL are
// captured instead of saving to disk.
const saved = []
const blobs = new Map()
URL.createObjectURL = (blob) => { const url = `blob:test/${blobs.size}`; blobs.set(url, blob); return url }
URL.revokeObjectURL = () => {}
HTMLAnchorElement.prototype.click = function () { saved.push({ name: this.download, url: this.href, attached: this.isConnected }) }

function tool(container, filename, text) {
  const button = document.createElement("button")
  container.appendChild(button)
  const controller = new DownloadController()
  Object.assign(controller, { element: button, filenameValue: filename, textValue: text })
  return controller
}

const panel = document.createElement("div")
panel.className = "dia"
panel.innerHTML = '<div class="dh"><span class="tools"></span></div><div class="dw"><pre class="cmd" data-diagram-target="source">erDiagram\n  "posts"</pre></div>'
document.body.appendChild(panel)

tool(panel.querySelector(".tools"), "post-schema.mmd", "").save()
tool(document.body, "postscontroller-create-passage.mmd", "sequenceDiagram\n  A->>B: x\n").save()

Promise.all(saved.map(async (s) => ({ name: s.name, attached: s.attached, text: await blobs.get(s.url).text(), type: blobs.get(s.url).type })))
  .then((files) => {
    document.getElementById("result").textContent = JSON.stringify({ files, leftovers: document.querySelectorAll("a[download]").length })
  })

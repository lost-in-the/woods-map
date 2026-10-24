// Parses Mermaid texts with the Mermaid that GitHub renders (woods-map#76),
// for the GitHub Mermaid spec: reads [{name, text}] as JSON on stdin and writes
// {version, results: [{name, ok, detected, error}]} as JSON on stdout.
//
// argv: the vendored mermaid.min.js.gz and the vendored linkedom module. The
// browser build of Mermaid sanitizes labels with DOMPurify while it parses,
// which needs a document, so it runs in a VM context whose global is a
// linkedom window. Parsing is Mermaid's own grammar check (`mermaid.parse`);
// it draws nothing. Node is a test-time tool only; the engine never runs it.
import { readFileSync } from "node:fs"
import { gunzipSync } from "node:zlib"
import { pathToFileURL } from "node:url"
import vm from "node:vm"

const source = gunzipSync(readFileSync(process.argv[2])).toString("utf8")
const { parseHTML } = await import(pathToFileURL(process.argv[3]).href)
const { window } = parseHTML("<!doctype html><html><head></head><body></body></html>")
const context = vm.createContext(window)
for (const name of ["console", "setTimeout", "clearTimeout", "queueMicrotask", "structuredClone", "URL", "TextEncoder", "TextDecoder"]) {
  context[name] = globalThis[name]
}
context.globalThis = context
context.window = context
context.self = context
vm.runInContext(source, context)

const mermaid = context.mermaid
mermaid.initialize({ startOnLoad: false, securityLevel: "strict" })
const version = (source.match(/\{version:"(\d+\.\d+\.\d+)"\}/) || [])[1] || null
const input = JSON.parse(readFileSync(0, "utf8"))
const results = []
for (const { name, text } of input) {
  try {
    const parsed = await mermaid.parse(text)
    results.push({ name, ok: true, detected: parsed.diagramType, error: null })
  } catch (error) {
    results.push({ name, ok: false, detected: null, error: String(error?.message || error).split("\n").slice(0, 4).join(" | ") })
  }
}
process.stdout.write(JSON.stringify({ version, results }))

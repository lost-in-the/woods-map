// Renders Mermaid texts with the vendored Pele build (D-21), for the headless
// render spec: reads [{name, text}] as JSON on stdin and writes
// [{name, type, width, height, bytes, error}] as JSON on stdout.
import { readFileSync } from "node:fs"
import { pathToFileURL } from "node:url"

const pele = await import(pathToFileURL(process.argv[2]).href)
const input = JSON.parse(readFileSync(0, "utf8"))
const results = input.map(({ name, text }) => {
  try {
    const { type, width, height, svg } = pele.render(text, { links: false, images: false })
    return { name, type, width, height, bytes: svg.length, error: null }
  } catch (error) {
    return { name, type: null, width: 0, height: 0, bytes: 0, error: `${error.code || "error"}: ${error.message}` }
  }
})
process.stdout.write(JSON.stringify(results))

// Renders the Mermaid sources in this folder with Pele (woods-map#25): node pele-render.mjs seq-impact er-post
import { render } from 'pele';
import { readFileSync, writeFileSync } from 'node:fs';
const names = process.argv.slice(2);
for (const n of names) {
  const src = readFileSync(`./${n}.mmd`, 'utf8');
  const t0 = performance.now();
  try {
    const r = render(src, { fontFamily: 'Fira Code', fontFamilyMono: 'Fira Code', fontSize: 12.5, idPrefix: n, responsive: false });
    const ms = (performance.now() - t0).toFixed(2);
    writeFileSync(`out-${n}.svg`, r.svg);
    const hasNum = /autonumber|sequenceNumber|<text[^>]*>\s*1\s*<\/text>/.test(r.svg);
    console.log(`${n}: ok type=${r.type} ${r.width}x${r.height} ${ms}ms svg=${r.svg.length}B numbers=${hasNum}`);
  } catch (e) {
    console.log(`${n}: ERROR ${e.code || ''} ${e.message.split('\n')[0]}`);
  }
}

# The Mermaid GitHub renders, for the specs only

`spec/diagrams/github_mermaid_spec.rb` parses every Mermaid text the map
generates with the Mermaid build that GitHub draws a ```` ```mermaid ```` block
with (woods-map#76).

- These files are test-time tools.
- They are not under `vendor/javascript/`.
- They are not in the gem (`spec.files` leaves `spec/` out).
- The engine never loads them.

| File | What | Version | License | Source |
|---|---|---|---|---|
| `mermaid-11.16.1.min.js.gz` | `dist/mermaid.min.js` of the npm package, unmodified, gzipped (`gzip -9 -n`) | 11.16.1: npm integrity `sha512-TQsq6u22fAn3rek5VOubrhKPo1g5hwC3FXUN9hiyupTckcYiGuuKGkNQrKYwGJkXUxZdojwRG46gsSCFZMDp4g==`; SHA-256 of the uncompressed file `18327bef70d96fb505fe7287d9f6a7362ebf07ff6576ddfaffb1a06f3e1a2954`, which the spec checks | MIT (`mermaid.LICENSE.md`) | https://www.npmjs.com/package/mermaid |
| `linkedom-0.18.14.mjs` | linkedom's `parseHTML` and its runtime dependencies, bundled into one ES module with `esbuild --bundle --format=esm --platform=node --minify` | linkedom 0.18.14: npm integrity `sha512-BRUnkOm4YR5vo+qI3j0EbungB0vZPSCue5AdnTQRaxAGSbsOZiBFRO0rh4zlo8qXUhli8pxvnpEXDklMnlq2Rg==` | ISC, with MIT, BSD-2-Clause and ISC dependencies (`linkedom.LICENSES.md`) | https://www.npmjs.com/package/linkedom |

**Why a DOM.** The browser build of Mermaid sanitizes labels with DOMPurify
while it parses, and DOMPurify needs a document. The runner
(`spec/support/github_mermaid_parse.mjs`) evaluates the build in a Node VM
whose global is a linkedom window.

**Checked against jsdom.** Every generated text, and a set of broken ones,
parse the same under linkedom as under jsdom 26 with this build.

**Rendered in Chromium too.** With `WOODS_MAP_BROWSER` set, the spec also
draws every text with `mermaid.render` in headless Chromium, with
`securityLevel: 'strict'`.

## Which version GitHub renders

GitHub does not publish it. Its documentation (*Creating diagrams*, "Checking
your version of Mermaid") says to render this in a comment and read the
version it prints:

````text
```mermaid
info
```
````

The latest such check on record is GitHub Community discussion
[#70672](https://github.com/orgs/community/discussions/70672). On 20 August
2026 it read "GitHub is running Mermaid v11.16.1 (checked via the `info`
diagram)". That fits npm's release dates: 11.16.1 came out on 4 August and
11.17.0 on 19 August.

## Updating

1. Paste the `info` block into a comment on GitHub and read the version.
2. `npm pack mermaid@<version>`, then `gzip -9 -n -c package/dist/mermaid.min.js > mermaid-<version>.min.js.gz` here. Remove the old file and replace `mermaid.LICENSE.md`.
3. Set `WoodsMap::MermaidExport::GITHUB_MERMAID_VERSION` and `GithubMermaidVendor::BUILD_SHA256` (`spec/support/github_mermaid_vendor.rb`).
4. Review `NEWER_THAN_GITHUB` against the diagram types the new build registers (`mermaid.getRegisteredDiagramsMetadata()`).
5. Run the spec with `WOODS_MAP_RENDER_SPEC=1` and `WOODS_MAP_BROWSER`, and update the table in `docs/design/notes/pr-comment-share.md`.

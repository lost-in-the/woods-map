# Engine screenshots

What the engine renders, taken with Playwright (Chromium) against the
`woods-testbed` `rails-8.0` variant after `woods:extract`, so each page can be
read beside the board that designs it. Every screenshot in this folder was
taken on a page where axe-core (WCAG 2.0 A/AA, 2.1 AA, best practice) reported
no violations. Regenerate with the runner described in each pull request; the
widths are the tiers of D-19.

| Page | Board | Screenshots |
|---|---|---|
| Status page (`/woods`) | [B8-States](../boards/B8-States.html), *stale: the status page* panel | [1440](status-1440.png), [960](status-960.png), [390](status-390.png) |
| First run, no index published | [B8-States](../boards/B8-States.html), *first run* panel | [1440](first-run-1440.png) |
| Refused, non-loopback host without a token | [B8-States](../boards/B8-States.html), *non-loopback host without a token* panel | [1440](refused-1440.png), [640](refused-640.png) |
| Session form (token configured, no cookie yet) | not designed; the 403 panel's structure with a form | [1440](session-form-1440.png) |

Fonts: the scaffold screenshots predate the vendored Inter and Fira Code
(woods-map#23) and fall back to the system faces.

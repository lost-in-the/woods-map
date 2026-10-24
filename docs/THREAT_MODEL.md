# Woods Map threat model

This document covers Woods Map mounted in a host Rails application and
reachable from beyond a developer's machine, for example on a staging host.
Copy what applies into the host's own threat model. The controls are those
of milestone M8 ([woods-map#10](https://github.com/lost-in-the/woods-map/issues/10)).
Deployment steps are in [DEPLOYMENT.md](DEPLOYMENT.md).

## What the map is

The map is a read-only Rails engine over a published Woods index. Each
request reads one pinned generation through `Woods::PublishedIndex`. A
request never:

- opens the host's database;
- reflects on the running application;
- starts a git subprocess;
- reads a file outside the index.

Routes take unit types, identifiers and generation numbers. File pages admit
only exact keys of the index's `file_map`, and those keys are never resolved
on the host filesystem.

## Assets

| Asset | Where it lives | Sensitivity |
|---|---|---|
| Application source | Every unit's `source_code` in the index, concerns inlined | High: the code itself, including any secret committed to it |
| Schema | Tables, columns, indexes and foreign keys from model and table units | Medium |
| Routes, callbacks, jobs, mailers, configuration facts | Unit metadata, the dependency graph, behavioural profile | Medium: the attack surface of the host application, laid out |
| Git facts | Recent commits per unit: short SHA, message, date, author name | Medium: people and activity |
| The token | `WOODS_MAP_TOKEN` in the host environment; the browser cookie holds only its SHA-256 digest | High: it opens everything above |

**The index already contains the application source. The map exposes
nothing the index does not.** Anyone who can read `tmp/woods` (or wherever
`config.index_dir` points) can read everything the map shows. Protect the
index directory the way you protect the checkout it was extracted from.

The map holds no live data. It cannot show a database row, a session, a log
line or an environment variable, because none of them is in the index. The
same is true of the M7 guide: it will see source through the index tools,
never live data, and is disabled by default.

## Actors

1. **A network client without credentials** can reach the mount.
2. **A web page in a developer's browser** while the map runs on that
   machine. It can attempt cross-site requests, DNS rebinding and framing.
3. **An authenticated user.** Anyone holding the token, or passing the host's
   `authorize` hook with a valid cookie, can read every page. There are no
   per-page permissions.
4. **Content in the index.** Source, commit messages and identifiers are
   attacker-influenced text, for example from a malicious pull request that
   was later extracted.
5. **A client that floods the expensive endpoints**: search, the palette,
   graph JSON and impact.

## Threats and controls

| Threat | Control | Where |
|---|---|---|
| A non-loopback client reads the map with no credential | Without `WOODS_MAP_TOKEN` (or `config.token`), any request whose remote IP is not loopback gets the plain 403 panel, before the repository opens. Nothing from the index is in the response. `config.require_token = true` refuses loopback too. | `WoodsMap::Authentication`, the refusal panel |
| The token is guessed or replayed | The token is compared in constant time. The browser exchanges it once (`?token=` or the form) for a signed, `HttpOnly`, `SameSite=Strict` cookie holding its digest; the URL is redirected without it. `Secure` is set on HTTPS requests. | `SessionsController`, `store_session_cookie` |
| A page abuses a signed-in browser through a cross-site write (CSRF) | Rails forgery protection on every non-GET request. The origin guard refuses a write whose `Origin` is foreign or `null`; without `Origin`, a foreign `Referer`; without either, a `Sec-Fetch-Site` other than `same-origin` or `none`. `SameSite=Strict` keeps the cookie off cross-site requests. | `ApplicationController#check_origin!` |
| DNS rebinding: a page resolves its own name to 127.0.0.1 and reads the token-less loopback mode through the developer's browser | The token-less mode also requires the raw `Host` header to name loopback (`localhost`, `127.0.0.1`, `::1`), judged by `Woods::MCP::OriginPolicy` as `woods-mcp-http` does. `X-Forwarded-Host` is not consulted. Other names must be listed in `config.allowed_origins`. Token holders are unaffected: a rebound page has neither the token nor the cookie. | `loopback_host?` |
| Script injection through index content (XSS) | Views escape every index value. Code is highlighted into escaped spans, and links come only from published, verified reference spans. The Content-Security-Policy is a second line: `script-src` admits only the engine's digested assets route and a per-response nonce, so an injected `<script>` or event handler does not run. Pele renders diagram text with links and images off; its labels are escaped. | Views, `Highlighter`, `ContentSecurityPolicy` |
| Style injection, data exfiltration through CSS or images | `style-src` admits only the assets route, with no `'unsafe-inline'`. Views carry no `style` attributes; Pele's SVG styles are applied through the CSSOM. `img-src 'self' data:` and `connect-src 'self'` stop a request to another origin. `base-uri 'none'` and `object-src 'none'` close the remaining injection sinks. | `ContentSecurityPolicy` |
| Clickjacking | `frame-ancestors 'none'`. | `ContentSecurityPolicy` |
| Forms posting elsewhere | `form-action 'self'`. | `ContentSecurityPolicy` |
| Path traversal to host files | No route takes a filesystem path. File routes admit only exact `file_map` keys and never touch the host filesystem. Payloads are read through `PublishedIndex`, never by joining a path. Engine assets are resolved only within the gem's own roots, under the current content digest. | `FilesController`, `Repository`, `Assets` |
| Resource exhaustion on search, palette, graph JSON and impact | A per-client, per-group budget (`config.rate_limit`, default 120 per 60 seconds). Past it, a 429 with `Retry-After`, answered before the repository opens. Graph traversal and diagrams have node budgets (R-4). | `RateLimiter`, `woods_map_rate_limit` |
| Leaking index facts on a refusal | The 403 and 429 panels use the plain layout, carry no index data and are rendered before any generation is read. | Refusal views |
| The host's own pages are affected by the engine | The engine's policy and gate apply only to responses under the mount. The Railtie injects no middleware. | `ApplicationController` |

## Residual risks and limits

- **One shared secret.** The token is a single shared credential with no
  identity, scopes or audit trail. Rotation means changing the environment
  variable and restarting. Existing cookies stop working because they hold
  the old digest. Use `config.authorize` for per-user decisions and the
  host's logs for audit.
- **`config.authorize` does not replace the token.** The hook runs first and
  can refuse. A non-loopback request still needs the token, or the cookie it
  was exchanged for. With single sign-on in front, the proxy can add the
  bearer header itself, so users never handle the token (see DEPLOYMENT.md).
- **Plain HTTP exposes the token.** Terminate TLS in front of any
  non-loopback mount.
- **A reverse proxy can make every request look loopback.** If a proxy on
  the same machine forwards without `X-Forwarded-For`, Rails sees
  `127.0.0.1` for everyone. The loopback `Host` check still refuses the
  public name, but always set a token behind a proxy.
- **Rate limits count per process.** Each Puma worker or server process
  grants the full budget. The limit dampens a flood; it does not meter a
  team.
- **Everything in the index is readable to anyone admitted.** Secrets
  committed to source, internal hostnames in configuration units and
  authors' names in commit facts are all shown. If an audience must not see
  some code, do not extract it into an index that audience can reach.
- **Content Security Policy depends on the browser.** Old browsers that
  ignore CSP Level 2 nonces lose the second line of defence against injected
  script. Escaping still applies.
- **A host can weaken the policy.** `config.content_security_policy = false`
  hands the header to the host's own policy, which may be weaker.

## Checklist for the host's threat model

- [ ] The index directory is readable only by the application user.
- [ ] Any non-loopback mount has `WOODS_MAP_TOKEN` set from a secret store, served over TLS.
- [ ] `config.authorize` restricts the mount to the people who may read the source.
- [ ] A reverse proxy preserves `Host`, sets `X-Forwarded-For` and `X-Forwarded-Proto`, and is the only way to reach the app.
- [ ] `config.allowed_origins` lists only origins you serve the map from.
- [ ] The rate-limit budget suits the number of server processes.
- [ ] If the host has its own Content-Security-Policy, the interaction in DEPLOYMENT.md has been checked.

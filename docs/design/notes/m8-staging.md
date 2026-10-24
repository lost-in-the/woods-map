# Staging hardening: policy, pacing and origins

Scope: M8 ([woods-map#10](https://github.com/lost-in-the/woods-map/issues/10)), the security posture of the design study (section 2), D-4. Open choices are in [woods-map#59](https://github.com/lost-in-the/woods-map/issues/59).

## Content-Security-Policy

Every engine response carries the engine's own policy. Host pages outside the mount are untouched. The host's policy middleware leaves alone any response that already has a policy. The policy is:

`default-src 'none'; script-src <mount>/assets/<digest>/ 'nonce-…'; style-src <mount>/assets/<digest>/; font-src <mount>/assets/<digest>/; img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'`

- The layout has three inline scripts: the no-js switch, the literal import map and the module entry. Each carries a fresh nonce on every response.
- `connect-src 'self'` covers the palette, peek and graph JSON. It will also cover the M7 guide's `EventSource`.
- Views carry no `style` attribute, and a spec enforces this.
  - What was inline is now a class in `map.css`.
  - Geometry that varies uses bounded classes: tree level 0–24, step depth 0–12, and the table minimums in `ComponentsHelper::TABLE_MIN_WIDTHS`.
  - Column widths use the `width` presentational hint.
  - Specimen swatches are SVG fills.
- Pele writes its theme into `style` attributes. The diagram controller passes Pele a `sanitize` hook that parses the SVG inert and applies each style through the CSSOM. The controller refuses a text with Pele's `parse` before mounting, so Pele's attribute-styled error line is never created. Zoom controls are off, and the panel scrolls sideways at natural width (C4).
- `config.content_security_policy` takes a callable `(policy, request)` that amends the policy, for example with a `report_uri`. Setting it to `false` drops the engine header. The host's own policy and nonce generator then apply.

## Rate limits (429)

Search with the palette, the graph JSON and impact each have a per-client budget. The default is 120 requests per 60 seconds, and `config.rate_limit_key` can key the budget by user instead of IP. The budget is counted in process with a fixed window and needs nothing from Rails 7.2.

The limit runs after the gate, so a refused client is never counted. It also runs before the repository opens.

- An HTML request gets the 403 panel's plain page: eyebrow `HTTP 429`, "Woods Map is pacing requests", the group, the budget, the wait and the configuration snippet. It carries a `Retry-After` header.
- A JSON request gets `{error, retry_after, message}`. The palette shows the message in its status line.

## Origin guard and loopback Host

- **Writes:** the session create and destroy routes, and any later POST, must come from the map's own origin or from `config.allowed_origins`.
  - The `Origin` header decides when it is present. `null` never matches.
  - Without `Origin`, the `Referer`'s origin decides.
  - Without either, `Sec-Fetch-Site` must be `same-origin` or `none`.
  - A request with none of the three is a non-browser client. The token check still gates it.
- **Token-less loopback mode:** the request must also name a loopback `Host` (`Woods::MCP::OriginPolicy`), or a host listed in `config.allowed_origins`. Otherwise it gets a 403 panel that names DNS rebinding. Token holders are unaffected, because a rebound page has neither the token nor the cookie.

## Copy

The non-loopback 403 panel's last sentence on B8-States read "Or let the host gate it with `config.authorize`". The hook runs before the token check and can refuse, but it does not admit a non-loopback request without the token (D-4, the exit criterion of M8). The panel now says the hook puts the host's sign-in in front of the token and does not replace it.

## Validation

- Request specs cover the policy on every response family, the host interaction, the absence of style attributes, the budgets and the origin matrix.
- `spec/woods_map/engine_http_server_spec.rb` (`WOODS_MAP_RUN_HTTP_SERVER=1`) boots the dummy host under Puma on every interface. It drives the gate over loopback and over a non-loopback address of the machine. CI runs it.
- The Chromium diagram regression runs under a meta policy without inline styles. It asserts that the drawing is styled and that no violation is reported.

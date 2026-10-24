# Deploying Woods Map beyond loopback

This guide covers putting the map on a staging or shared host. Woods'
[MCP HTTP transport guide](https://github.com/lost-in-the/woods/blob/main/docs/MCP_HTTP_TRANSPORT.md)
covers the same ground for `woods-mcp-http`, and the two postures match on
purpose. The threats behind each setting are in
[THREAT_MODEL.md](THREAT_MODEL.md).

## 1. Mount it on purpose

The Railtie injects nothing. Mount the engine where you want it, and only in
environments that should have it:

```ruby
# config/routes.rb
mount WoodsMap::Engine => "/woods" if Rails.env.development? || ENV["WOODS_MAP"] == "1"
```

Publish the index with `bin/rails woods:extract` as part of the deploy or on
a schedule, and point the map at it:

```ruby
# config/initializers/woods_map.rb
WoodsMap.configure do |config|
  config.index_dir = Rails.root.join("tmp/woods")
  config.token = ENV["WOODS_MAP_TOKEN"]
end
```

## 2. Who may connect

| Remote address | Token configured? | Result |
|---|---|---|
| loopback (`127.0.0.1`, `::1`) and a loopback `Host` | no | Served. The engine logs one warning at boot. |
| loopback, but `Host` names something else | no | **403**: looks like DNS rebinding. List the name in `config.allowed_origins` if it is yours. |
| anything else | no | **403** plain panel. The map serves nothing until a token is set. |
| any | yes | The bearer header, or the cookie the token was exchanged for, is required on every request. |
| any, with `config.require_token = true` | no | **403** for everyone, loopback included. |

Behind a reverse proxy, the remote address is whatever Rails' `remote_ip`
resolves (section 5). A non-loopback mount therefore needs `WOODS_MAP_TOKEN`.

### Generating and using the token

```bash
export WOODS_MAP_TOKEN=$(openssl rand -hex 32)
```

- **Browsers:** open `https://staging.example.com/woods?token=…` once, or
  paste the token into the form at `/woods/session/new`. The token becomes a
  signed `HttpOnly`, `SameSite=Strict` cookie holding its SHA-256 digest; on
  HTTPS it is also `Secure`. The map redirects to the same URL without the
  token, so the token does not stay in the address bar. Sign out with
  `DELETE /woods/session`.
- **API clients** (the palette JSON, `graph/neighbourhood`): send
  `Authorization: Bearer $WOODS_MAP_TOKEN`. A missing or wrong token gets
  `401` with `WWW-Authenticate: Bearer`.
- **Rotation:** change the variable and restart. Old cookies stop matching.

## 3. `config.authorize`: who among the admitted

The hook is called with the Rack request before any token check. A falsy
result refuses the request with the 403 panel. **It adds a gate; it does not
replace the token.** A non-loopback request must pass both.

### Devise

Devise's Warden middleware sits in the host's stack, so the hook can ask
Warden for the signed-in user without redirecting:

```ruby
WoodsMap.configure do |config|
  config.token = ENV["WOODS_MAP_TOKEN"]
  config.authorize = lambda do |request|
    user = request.env["warden"]&.authenticate(scope: :user)
    user.present? && user.admin?
  end
end
```

To send people who are not signed in to the Devise sign-in page instead of
the 403, gate the mount with Devise's routing helper as well:

```ruby
# config/routes.rb
authenticate :user, ->(user) { user.admin? } do
  mount WoodsMap::Engine => "/woods"
end
```

### An SSO header from an authenticating proxy

oauth2-proxy, Pomerium, Google IAP and Cloudflare Access put the
authenticated identity in a request header. Trust such a header only when:

- the proxy removes any copy the client sent;
- the application cannot be reached except through the proxy.

```ruby
ALLOWED = %w[platform@example.com].freeze

WoodsMap.configure do |config|
  config.token = ENV["WOODS_MAP_TOKEN"]
  config.authorize = lambda do |request|
    email = request.get_header("HTTP_X_AUTH_REQUEST_EMAIL").to_s
    email.end_with?("@example.com") || ALLOWED.include?(email)
  end
  # Budget per person rather than per proxy address.
  config.rate_limit_key = ->(request) { request.get_header("HTTP_X_AUTH_REQUEST_EMAIL") || request.remote_ip }
end
```

Where the proxy can sign its assertion, verify the signature instead of
reading a plain header. For example, check Cloudflare Access's
`Cf-Access-Jwt-Assertion` against the team's keys.

**Keeping the token off people's hands.** With SSO in front, the proxy can
add the bearer header after it has authenticated the user. The token then
secures only the hop from the proxy to the app:

```nginx
location /woods/ {
  auth_request /oauth2/auth;                       # oauth2-proxy, for example
  auth_request_set $email $upstream_http_x_auth_request_email;
  proxy_set_header X-Auth-Request-Email $email;    # overwrites any client copy
  proxy_set_header Authorization "Bearer ${WOODS_MAP_TOKEN}";  # templated at deploy
  proxy_pass http://127.0.0.1:3000;
}
```

## 4. Origins

The engine compares origins against the request's own: `request.base_url`,
built from `Host` and `X-Forwarded-Proto`.

- **Writes** (the session form, sign-out) must carry that origin in
  `Origin`. Without `Origin`, the `Referer`'s origin must match; without
  either, `Sec-Fetch-Site` must be `same-origin` or `none`. Anything else
  gets the 403 panel, with a valid token too.
- **The token-less loopback mode** also requires a loopback `Host`.

`config.allowed_origins` widens both checks. Each entry is a serialized
origin, `scheme://host[:port]`, with no path. Use it when the map is served
under a second name, or locally under a development domain:

```ruby
config.allowed_origins = ["https://map.staging.example.com", "http://myapp.test"]
```

## 5. Reverse proxy

Terminate TLS at the proxy. The map speaks plain HTTP and sends the token
over it.

```nginx
server {
  listen 443 ssl http2;
  server_name staging.example.com;

  location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header Host $host;                                   # origin checks and the CSP asset source
    proxy_set_header X-Forwarded-Proto $scheme;                    # https in base_url and the Secure cookie
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;   # the real client for remote_ip
  }
}
```

- **Preserve `Host` and set `X-Forwarded-Proto`.**
  - The origin guard compares against the URL the browser used.
  - The Content-Security-Policy names the assets route by absolute URL.
  - A rewritten `Host` breaks scripts and writes.
  - If the proxy must rewrite `Host`, set `X-Forwarded-Host` to the public
    name.
- **Set `X-Forwarded-For`.** A proxy on the same machine connects from
  `127.0.0.1`. Rails' `remote_ip` trusts loopback and private-network proxies
  and reads the client from `X-Forwarded-For`. Without the header, every
  request looks loopback, and only the `Host` check and the token keep the map
  closed. Proxies on other addresses must be listed in
  `config.action_dispatch.trusted_proxies`.
- **Bind the app to loopback** (`-b 127.0.0.1`) when the proxy is the public
  surface. Keep the token set, so the hop from the proxy to the app still
  needs a credential.

## 6. Content-Security-Policy

Every response under the mount carries the engine's policy. Host pages are
untouched.

```
default-src 'none'; script-src https://host/woods/assets/<digest>/ 'nonce-…';
style-src https://host/woods/assets/<digest>/; font-src https://host/woods/assets/<digest>/;
img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'none';
form-action 'self'; frame-ancestors 'none'
```

**With a host policy.** Rails' `ActionDispatch::ContentSecurityPolicy::Middleware`
adds the host's `config.content_security_policy` only to responses that carry
no policy yet. Under the mount, the engine's header is already there, so the
engine's policy applies and the host's does not. The engine never changes
the host's own responses.

To add to the engine's policy, give a callable. It receives the
`ActionDispatch::ContentSecurityPolicy` and the request:

```ruby
config.content_security_policy = lambda do |policy, request|
  policy.report_uri "/csp-violation-reports"     # the host's collector
end
```

To have the host's policy apply under the mount instead, turn the engine's
header off:

```ruby
config.content_security_policy = false
```

The layout's inline scripts then carry the host's nonce
(`config.content_security_policy_nonce_generator`), and the host's policy
must allow:

- the engine's assets route in `script-src`, `style-src` and `font-src`;
- `connect-src 'self'`;
- `data:` images;
- inline scripts by nonce.

Views carry no `style` attributes, so the host policy needs no
`'unsafe-inline'` for styles.

Rails' `content_security_policy` controller DSL on `WoodsMap::` controllers
has no effect while the engine sends its own header. Use the callable.

## 7. Rate limits

Search with the palette, the graph JSON and the impact page each have a
budget per client:

```ruby
config.rate_limit = 120          # requests per client and group; nil or 0 turns it off
config.rate_limit_period = 60    # seconds
config.rate_limit_key = ->(request) { request.remote_ip }   # or a user identity
```

Past the budget, pages get a 429 panel and JSON clients get
`{"error":"rate_limited","retry_after":…}`, both with `Retry-After`. Counts
are kept in each server process: with `WEB_CONCURRENCY=4`, a client may make
four times the budget. Size the budget accordingly, or add a limit at the
proxy (`limit_req` in nginx) for a hard ceiling.

## 8. Streaming (the M7 guide) behind proxies

The guide panel (M7) will stream answers as server-sent events from
`ActionController::Live`. The open item in the decision log asks for proxy
settings; until M7 lands, these are the ones known to matter:

- **nginx** buffers responses by default, which holds every event until the
  answer ends. Turn buffering off for the mount (a streaming response can
  also send `X-Accel-Buffering: no`, which M7 should set):

  ```nginx
  location /woods/ {
    proxy_pass http://127.0.0.1:3000;
    proxy_http_version 1.1;
    proxy_set_header Connection "";
    proxy_buffering off;
    proxy_cache off;
    proxy_read_timeout 3600s;
  }
  ```

- **Compression:** `Rack::Deflater`, or `gzip on` at the proxy, buffers a
  stream. Exclude `text/event-stream`.
- **Puma:** each open stream holds one thread for its whole duration. Keep
  `max_threads` above the number of concurrent guide sessions you expect,
  plus the page traffic. Each worker keeps up to `config.guide_mcp_servers`
  `woods-mcp` processes (2 by default) for its answers; a worker forked from
  a parent that already started some starts its own and leaves the parent's
  alone. More concurrent answers than that wait up to
  `guide_mcp_wait_seconds`, then fail with a message.
- **CDNs and tunnels:** Cloudflare and some ingress controllers buffer or
  time out idle streams. Use a long read timeout and a heartbeat comment.
  The design falls back to polling Turbo Frames where a stream cannot open
  (design study, M7).
- **Policy:** `connect-src 'self'` already admits the guide's
  `EventSource`. No change is needed.

## Checklist

- [ ] The mount is limited to the environments that need it.
- [ ] `WOODS_MAP_TOKEN` is set from a secret store; the index directory is private to the app user.
- [ ] TLS terminates at a proxy that preserves `Host`, sets `X-Forwarded-Proto` and `X-Forwarded-For`, and strips identity headers clients send.
- [ ] `config.authorize` names who may read the source.
- [ ] `config.allowed_origins` lists only names you serve the map under.
- [ ] Opening `/woods` from outside without credentials shows the 403 panel; with the token it shows the status page.
- [ ] `curl -sI https://…/woods` shows the engine's `Content-Security-Policy`, and the browser console shows no policy violations.

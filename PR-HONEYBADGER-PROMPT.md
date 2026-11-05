# Prompt for coding agent — FAIR Station Honeybadger safeguards

Run inside the FAIRStation repo on this Mac. Do NOT merge, deploy, or push
without Patrick's say-so. Leave the work on a branch for his review.

## Context

RAMS just switched its Honeybadger config to a zero-identifiable-data mode:
the params-only `filter_keys` list was replaced with a full kill-switch on
every automatic data payload, verified against the real honeybadger 6.10.0
gem (`excluded_request_keys=[:session, :params, :cgi_data, :url]`).

FAIR Station already merged its Honeybadger implementation, but it does NOT
have those safeguards yet. Its current config is `config/honeybadger.yml`:
- `api_key` from `Rails.application.credentials.honeybadger_api_key`
  (encrypted credentials, NOT an environment variable — do not change this)
- `exceptions.enabled: false` in development and test
- `insights.enabled: false` (already off)

What is MISSING in FAIR Station: no `request.disable_*` flags and no
`breadcrumbs.enabled: false`. By default the gem ships request params,
session/cookies, Rack environment (headers, IP, user agent), and URLs, and
filters only password fields. That is the gap to close.

There are no `Honeybadger.notify` / `Honeybadger.context` calls anywhere in
the FAIR Station app (verify this with a grep before you start) — only the
yaml config references the gem.

## Task

Create `config/initializers/honeybadger.rb` that mirrors the RAMS change,
adapted to FAIR Station. The initializer block is the highest-precedence
config source, so these assignments override any `honeybadger.yml` or
environment configuration.

```ruby
Honeybadger.configure do |config|
  # Zero identifiable data: never ship request payloads, cookies/session,
  # Rack environment (headers, IP, user agent), URLs, breadcrumbs
  # (application logs and SQL), or Insights events (SQL, controller params,
  # HTTP URLs, job arguments). Only the error class, message, and backtrace
  # are reported.
  config.request.disable_params = true
  config.request.disable_session = true
  config.request.disable_environment = true
  config.request.disable_url = true
  config.breadcrumbs.enabled = false
  config.insights.enabled = false
end
```

Rules:
- Do NOT touch the API key setup. Leave `api_key` in `config/honeybadger.yml`
as it is (credentials, not env). Do not add an ENV fallback and do not
  change the credential key name.
- Do NOT change `development` / `test` `exceptions.enabled: false`.
- Do NOT add any `Honeybadger.notify` / `Honeybadger.context` calls.
- Do NOT change any other file. This is a single-concern PR.
- Branch: `fix/honeybadger-disable-request-data`
- Commit (conventional, Release Please):
  `fix(observability): disable Honeybadger request payloads`

## Verification (do this, do not skip it)

1. `ruby -c config/initializers/honeybadger.rb` must pass.
2. Load the real initializer against the real honeybadger gem version
   pinned in `Gemfile.lock` (isolated install / minimal Rails stub, the
   same approach used for the RAMS verification) and assert all six flags
   are correct, with `excluded_request_keys=[:session, :params, :cgi_data, :url]`.
3. If the full Rails app cannot be booted locally, say so explicitly and
   report that the assertions come from executing the actual initializer
   against the actual gem rather than a full app boot. Do not claim a
   full-app verification you did not run.
4. Confirm with a grep that no `Honeybadger.notify` / `Honeybadger.context`
   calls exist in the app.

## Report back

- Files changed, branch name, commit message used.
- Verification output for steps 1–4 above.
- Any field left uncertain (e.g. honeybadger gem version in the lock file,
  or anything that could not be verified locally).

Known residual caveat (do NOT try to fix it in this PR): error class,
message, and backtrace still ship, so a message itself could embed
sensitive values. That needs a full-app canary check later, not a config
change now.

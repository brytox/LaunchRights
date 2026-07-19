# LaunchRights beta signup API

A minimal [AWS SAM](https://docs.aws.amazon.com/serverless-application-model/) app
that backs the website's "register your interest" form. One Lambda sits behind an
HTTP API; it validates the submission and emails it to your beta inbox via
**Amazon SES**.

```
POST /signup   →   Lambda (validate)   →   SES SendEmail   →   beta inbox
```

## Layout

```
template.yaml      SAM template: HTTP API + Lambda + IAM + CORS
src/app.mjs        the handler (Node.js 22, AWS SDK v3 from the runtime — no deps to bundle)
```

## Prerequisites

- [AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html)
  and AWS credentials configured.
- **A verified SES identity** for the `From` address. Verifying the
  **launchrights.com** domain covers `beta@launchrights.com` (recommended):
  ```bash
  aws ses verify-domain-identity --domain launchrights.com
  # then add the returned TXT/CNAME records to DNS
  ```
  In a fresh account SES is in the *sandbox*, so you must also verify each recipient —
  verify `bob@3voltsmax.com`, or
  [request production access](https://docs.aws.amazon.com/ses/latest/dg/request-production-access.html):
  ```bash
  aws ses verify-email-identity --email-address bob@3voltsmax.com
  ```

## Deploy

```bash
cd api
sam build            # optional — packages src/ (no npm deps)
sam deploy --guided  # first time: prompts for stack name, region, and the params below
```

Guided deploy asks for three parameters:

| Parameter        | Default                        | Notes |
|------------------|--------------------------------|-------|
| `SenderEmail`    | `beta@launchrights.com`        | Must be an SES-verified identity (verify the launchrights.com domain). |
| `RecipientEmail` | `bob@3voltsmax.com`            | Where signups land. |
| `AllowOrigin`    | `https://launchrights.com`     | Production site origin. `http://localhost:5173` and `:4173` are always allowed too. |
| `ApiKey`         | *(set in template)*            | Shared secret sent as the `x-api-key` header. Must match `VITE_API_KEY`. |

All parameters have defaults, so `sam deploy` needs no overrides. To rotate the key,
deploy your own and update `VITE_API_KEY` to match:

```bash
sam deploy --parameter-overrides ApiKey=$(openssl rand -hex 24)
```

Subsequent deploys are just `sam deploy` (settings are saved to `samconfig.toml`).

On success, SAM prints the **`ApiUrl`** output, e.g.
`https://abc123.execute-api.eu-west-2.amazonaws.com/signup`.

## Wire up the website

Put that URL in the site's build env so the form POSTs to it:

```bash
cd ../website
cat > .env.local <<'EOF'
VITE_FORM_ENDPOINT=https://abc123.execute-api.eu-west-2.amazonaws.com/signup
VITE_API_KEY=<the same key you deployed with>
EOF
npm run build
```

Without `VITE_FORM_ENDPOINT`, the form falls back to a pre-filled `mailto:`.

## Test the endpoint

```bash
curl -sS -X POST "$API_URL" \
  -H 'content-type: application/json' \
  -H "x-api-key: $API_KEY" \
  -d '{"name":"Alex Okafor","organisation":"Acme","email":"alex@acme.com","useCase":"Evaluating / just exploring"}'
# → {"ok":true}       (omit or wrong x-api-key → 401 {"ok":false,"error":"Unauthorized."})
```

## Request / response

**Auth:** every request must send the `x-api-key` header matching the deployed
`ApiKey`. Because the site is static, this key ships in the client bundle — it
deters casual/bot abuse but is not a true secret. For hard protection, add a rate
limit / WAF or a server-side proxy.

**Request** (JSON): `name`, `organisation`, `email`, `useCase`. An optional
`company` field is a honeypot — if present, the request is accepted and dropped.

**Responses:** `200 {"ok":true}` · `401` bad/missing API key · `400` invalid/missing
fields (with a `fields` array) · `502` SES failed. CORS (incl. localhost dev
origins) is handled by the HTTP API, not the function.

## Teardown

```bash
sam delete
```

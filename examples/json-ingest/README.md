# Tiler JSON Ingest — Send Data From Any System

Tiler accepts JSON via a token-authenticated webhook. Any system that can `POST` HTTP works: shell scripts, cron jobs, Node services, Python pipelines, GitHub Actions, Lambda functions, IoT devices.

## 1. Create a data source with webhook enabled

Either via the Tiler UI (`/tiler/data_sources/new` → check "webhook") or directly in a console / seed file:

```ruby
source = Tiler::DataSource.create!(
  name:               "Checkout Events",
  slug:               "checkout_events",
  schema_definition:  [
    { "key" => "status",   "type" => "string" },
    { "key" => "duration", "type" => "float"  }
  ].to_json,
  ingestion_methods:  ["webhook"].to_json
)

puts "Webhook token: #{source.webhook_token}"
puts "Endpoint: POST /tiler/ingest/#{source.slug}"
```

The token is generated automatically; treat it like an API key. Rotate by regenerating from the data-source detail page.

## 2. Send one event

The endpoint accepts `Content-Type: application/json` with either a single object (one record) or an array (batch).

### curl

```bash
curl -X POST https://your-app.example.com/tiler/ingest/checkout_events \
  -H "X-Tiler-Token: $TILER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status":"ok","duration":142.3}'
```

### curl — batch

```bash
curl -X POST https://your-app.example.com/tiler/ingest/checkout_events \
  -H "X-Tiler-Token: $TILER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '[
    {"status":"ok","duration":142.3},
    {"status":"ok","duration":201.0},
    {"status":"error","duration":3500.0}
  ]'
```

### Node.js (fetch — Node 18+)

See [`node-ingest.mjs`](./node-ingest.mjs):

```javascript
const res = await fetch(`${BASE_URL}/tiler/ingest/checkout_events`, {
  method: "POST",
  headers: {
    "X-Tiler-Token": process.env.TILER_TOKEN,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({ status: "ok", duration: 142.3 }),
});
console.log(res.status, await res.text());
```

### Python (requests)

See [`python-ingest.py`](./python-ingest.py):

```python
import os, requests
res = requests.post(
    f"{BASE_URL}/tiler/ingest/checkout_events",
    headers={"X-Tiler-Token": os.environ["TILER_TOKEN"]},
    json={"status": "ok", "duration": 142.3},
)
print(res.status_code, res.text)
```

### Bash poll loop (cron-friendly)

See [`bash-poll.sh`](./bash-poll.sh):

```bash
#!/usr/bin/env bash
while true; do
  duration=$(measure_some_metric)   # your metric collector
  curl -sS -X POST "$BASE_URL/tiler/ingest/checkout_events" \
       -H "X-Tiler-Token: $TILER_TOKEN" \
       -H "Content-Type: application/json" \
       -d "{\"status\":\"ok\",\"duration\":$duration}"
  sleep 60
done
```

## 3. Optional fields

The webhook accepts these reserved keys; everything else lands in the `payload` JSON column verbatim.

| Field | Purpose |
|---|---|
| `recorded_at` | ISO-8601 timestamp; defaults to server time on receipt |
| `source_ref` | Free-text correlation id (e.g., your event id, request id) |

Example with reserved fields:

```json
{
  "recorded_at": "2026-04-23T10:00:00Z",
  "source_ref":  "evt_abc123",
  "status":      "ok",
  "duration":    142.3
}
```

## 4. Verify ingestion

Check the data source's recent records:

- UI: `/tiler/data_sources/checkout_events` shows last 50 records.
- Console: `Tiler::DataSource.find_by(slug: "checkout_events").data_records.last(5)`.

Once records are flowing, point a panel at this data source from any dashboard:

```ruby
dashboard.panels.create!(
  title:        "Checkout p95 (24h)",
  widget_type:  "metric",
  data_source:  source,
  x: 0, y: 0, width: 3, height: 2,
  config: { aggregation: "avg", value_column: "duration", time_window: "24h" }.to_json
)
```

## 5. Schema is descriptive, not enforced

`schema_definition` documents what fields you intend to send — it does NOT reject malformed payloads. Tiler stores the raw JSON; widgets aggregate via `json_extract` on whatever keys exist. A missing key for a given record produces `nil` in widget output, never an error.

This means you can:
- Add new fields to your payload without changing Tiler config
- Send heterogeneous events to the same data source (different shapes per source_ref)
- Backfill historical data without migrations

## 6. Security notes

- The webhook token is checked via constant-time comparison against the data source's `webhook_token`.
- Use HTTPS in production; the token is a bearer credential.
- Rotate tokens by regenerating from the data-source UI; the old token immediately stops working.
- Rate limiting is your host app's responsibility (e.g., `rack-attack` rules on the `/tiler/ingest/*` path).

## Files in this example

- `node-ingest.mjs` — Node 18+ fetch example
- `python-ingest.py` — Python requests example
- `bash-poll.sh` — shell polling loop for cron
- `README.md` — this file

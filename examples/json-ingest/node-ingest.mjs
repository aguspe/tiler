// Send one event to a Tiler data source via webhook.
// Run: BASE_URL=https://your-app.example.com TILER_TOKEN=xxx SOURCE_SLUG=checkout_events node node-ingest.mjs

const baseUrl = process.env.BASE_URL ?? "http://127.0.0.1:3131";
const token = process.env.TILER_TOKEN;
const slug = process.env.SOURCE_SLUG ?? "demo_requests";

if (!token) {
  console.error("Missing TILER_TOKEN env var");
  process.exit(1);
}

const payload = {
  status: "ok",
  duration: Math.round(Math.random() * 1000) / 10,
  source_ref: `evt_${Date.now()}`,
};

const res = await fetch(`${baseUrl}/tiler/ingest/${slug}`, {
  method: "POST",
  headers: {
    "X-Tiler-Token": token,
    "Content-Type": "application/json",
  },
  body: JSON.stringify(payload),
});

const body = await res.text();
console.log(`HTTP ${res.status}`);
console.log(body);

process.exit(res.ok ? 0 : 1);

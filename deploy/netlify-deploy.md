# Publishing the report: Netlify

The `report/` folder is an [Evidence](https://evidence.dev) project that builds to a fully
static site — `npm run build` bakes the query results into HTML/JS, so nothing needs to stay
running once it's deployed. First deploy is a drag-and-drop, no CLI login required.

## 1. Build the site

Postgres must be up and populated (`docker compose up -d`, full dataset loaded, `dbt run`)
before building, since Evidence queries it at build time:

```bash
cd report
npm install       # first time only
npm run sources    # runs the dbt marts queries, caches results
npm run build       # outputs static site to report/build/
```

## 2. Deploy to Netlify

1. Go to [app.netlify.com/drop](https://app.netlify.com/drop)
2. Sign up / log in (GitHub login recommended)
3. Drag the `report/build/` folder onto the page
4. Netlify assigns a public URL like `https://random-name-xxxx.netlify.app`

## 3. Rename the site (optional)

In Netlify → **Site settings → General → Site details → Change site name** — pick something
like `sebmanley-olist-report`, giving a cleaner URL:
`https://sebmanley-olist-report.netlify.app`

## 4. Update the README

Paste the deployed URL into the "Live Report" section of the main `README.md`.

## Notes

- This is a **static snapshot** — if the dbt models or seed data change, re-run steps 1
  (`npm run sources && npm run build`) and re-drag the new `report/build/` folder onto
  Netlify to update the live site. There's no automated redeploy wired up, since the
  dataset itself doesn't change.
- Free tier is sufficient — no ongoing cost, no server to maintain.

# FitForce SEO Backlink Campaign Resume Notes

Last updated: 2026-07-02

## What Is Done

- Added two AI/MCP blog posts:
  - `/blog/what-is-an-mcp-server-for-personal-trainers`
  - `/blog/ai-agents-personal-training-business`
- Added the primary linkable asset:
  - `/personal-trainer-ai-readiness-checklist`
- Added two supporting linkable template assets:
  - `/personal-trainer-client-intake-form-template`
  - `/personal-trainer-invoice-template`
- Updated blog index and sitemap with the new pages.
- Updated `deploy.sh` so root-level HTML resources are included automatically.
- Created backlink campaign docs:
  - `seo/backlink-outreach-plan.md`
  - `seo/outreach-prospects.csv`
  - `seo/outreach-batch-01.md`
  - `seo/backlink-prospects-batch-02.csv`
  - `seo/outreach-batch-02.md`
- Deployed production after adding the two template assets.
- Repositioned the invoice and client intake template pages as product-led SEO pages:
  - Keep the free copy/print template ungated.
  - Add "template to FitForce workflow" sections that map each search intent to real FitForce app features.
  - Point CTAs to `/?source=invoice_template#signup` and `/?source=intake_template#signup`.
- Added early-access source attribution plumbing so Slack can show the signup source when the website sends one.

## Validation Done

- `xmllint --noout sitemap.xml` passed.
- JSON-LD parsed for:
  - `personal-trainer-ai-readiness-checklist.html`
  - `blog/what-is-an-mcp-server-for-personal-trainers.html`
  - `blog/ai-agents-personal-training-business.html`
- Local HTTP checks passed for:
  - `/personal-trainer-client-intake-form-template.html`
  - `/personal-trainer-invoice-template.html`
  - `/blog/`
  - `/sitemap.xml`
- Production checks passed for:
  - `https://fitforce.com/personal-trainer-client-intake-form-template`
  - `https://fitforce.com/personal-trainer-invoice-template`
  - `https://fitforce.com/blog/`
  - `https://fitforce.com/sitemap.xml`

## Current Outreach State

Batch 1 has tailored copy in `seo/outreach-batch-01.md`.

Batch 2 has tailored copy in `seo/outreach-batch-02.md` and tracking in `seo/backlink-prospects-batch-02.csv`.

Send-ready:

- NASM: `nasmmedia@nasm.org`
- Fitness Mentors: `eddie@fitnessmentors.com`
- ACE Fitness: `blogs@acefitness.org`
- ISSA: `support@issaonline.com`

Gmail drafts created from `parsa@fitforce.com` on 2026-07-01:

- ACE Fitness intake template pitch: `r-3682484900655325414`
- NASM intake template pitch: `r-7736263244555354578`
- ISSA intake template pitch: `r-8175496165035414879`
- Fitness Mentors invoice template pitch: `r975953322561125879`

Earlier AI checklist Gmail drafts from `parsa@fitforce.com`:

- NASM AI checklist pitch: `r8920517414473114318`
- Fitness Mentors AI checklist pitch: `r-3740280549325795258`
- ISSA AI checklist pitch: `r6743514803855956467`
- PTDC: draft copy exists, but best route still needs contact/newsletter/social path confirmation

Needs contact lookup/form:

- Institute of Personal Trainers
- Personal Trainer Daily
- PTDC
- Exercise.com
- TeamUp
- Gymdesk

## Next Best Step

When resuming:

1. Review the four Gmail drafts before sending.
2. Send no more than one pitch per publication this week.
3. If sending Batch 2, lead with templates first and avoid also sending the older AI checklist draft to the same contact immediately.
4. Find better editorial/contact routes for PTDC, Institute of Personal Trainers, Exercise.com, TeamUp, and Gymdesk.
5. Update `seo/backlink-prospects-batch-02.csv` after each send with date/status.
6. For new template pages, follow the same pattern: free resource first, FitForce workflow bridge second, source-tagged CTA third.

## Important Note

There were pre-existing local edits in `index.html` and `style.css` before the SEO/backlink work started. Do not assume those are part of this campaign unless reviewed separately.

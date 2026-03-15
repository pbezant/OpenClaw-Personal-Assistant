---
name: job-search
description: Finds relevant job opportunities, evaluates them against a CV, and produces tailored, high-quality application materials. Use for requests like "run a job search", "find IoT jobs", or "update my applications".
---

# Skill: Job Search & Application Materials

When asked to run a job search (or on scheduled runs), follow this exact workflow:

---

### Configuration

1.  **Discord Channel ID for Job Search:** The numerical ID of the Discord channel where job search summaries should be posted. Store securely in `memory/job_search_discord_channel_id.md`.

### Phase 1 — Discover Jobs

Use `web_search` as your **primary tool** for finding jobs. Do NOT use `web_fetch` on LinkedIn, Indeed, or Glassdoor — they block bots with Cloudflare. Use `web_search` queries instead, then `web_fetch` only on direct company career page URLs once you have them.

**Target role titles (based on Preston's CV):**
- "IoT Systems Engineer"
- "IoT Solutions Architect"
- "Senior Product Designer"
- "Creative Technologist"
- "Technical Prototyper"
- "Embedded Systems Engineer"
- "Solutions Architect"
- "UX Engineer"
- "Industrial Product Designer"
- "Front-End Developer"
- "Web Applications Developer"

**Search strategy — use `web_search` as your **primary tool** for finding jobs. Do NOT use `web_fetch` on LinkedIn, Indeed, or Glassdoor — they block bots with Cloudflare. Use `web_search` queries instead, then `web_fetch` only on direct company career page URLs once you have them.**

Run a `web_search` for each of the following queries (you can batch them):
1. `("IoT Systems Engineer" OR "IoT Solutions Architect" OR "Embedded Systems Engineer") jobs Austin Texas remote 2025 2026`
2. `("Senior Product Designer" OR "UX Designer" OR "Industrial Product Designer") jobs Austin remote 2025 2026`
3. `("Creative Technologist" OR "Technical Prototyper") UX jobs Austin Texas remote 2025`
4. `("LoRaWAN engineer" OR "RTLS engineer" OR "BLE systems") jobs 2025 2026`
5. `("Solutions Architect" OR "Technical Architect") (data OR cloud OR enterprise OR "smart building") jobs Austin remote 2025`
6. `("Front End Developer" OR "Web Applications Developer") (UX OR design OR prototype) jobs Austin Texas remote 2025 2026`
7. `site:greenhouse.io ("product designer" OR "UX engineer" OR "IoT engineer" OR "front end developer" OR "web applications developer") 2025`
8. `site:lever.co ("product designer" OR "UX engineer" OR "IoT" OR "front end developer" OR "web applications developer") 2025`
9. `site:ashbyhq.com ("product designer" OR "UX engineer" OR "IoT" OR "embedded systems" OR "front end developer" OR "web applications developer") 2025`
10. `site:upwork.com ("IoT Systems Engineer" OR "Creative Technologist" OR "Technical Prototyper" OR "AI Agent Developer" OR "Product Designer" OR "UX Designer" OR "Front End Developer" OR "Web Applications Developer") freelance contract`
11. `site:fiverr.com ("IoT" OR "Embedded Systems" OR "N8N" OR "OpenClaw" OR "Product Design" OR "UX Design" OR "Front End Development" OR "Web Development") gig service`

**For each job found in search results, capture:**
- Job title
- Company name
- Location (remote/hybrid/onsite)
- Direct job posting URL (prefer company careers pages over aggregators)
- Key requirements visible in the snippet
- Salary range (if listed)

Then use `web_fetch` on the **direct company careers URL** (e.g. greenhouse.io/, lever.co/, company.com/careers/...) to get the full job description. Do NOT attempt `web_fetch` on linkedin.com, indeed.com, or glassdoor.com.

Aim to collect **at least 10–15 job listings** before moving to Phase 2.

---

### Phase 2 — Score & Rank

For each job found, score it 1–10 based on fit with Preston's CV:

**High score factors (add points):**
- Requires product/UX design experience (+7)  # Increased for strong designer lean
- Values AI/LLM integration experience (+3)  # Increased to reflect AI for development
- Direct keyword alignment with CV skills/tech (up to +3 points, based on frequency/relevance)  # Keep for ATS
- Austin or remote (+1)
- Startup or growth-stage company (+1)
- Competitive salary $120k+ (+1)
- Mentions IoT, LoRaWAN, BLE, RTLS, or embedded systems (+1) # Keep as a plus

**Low score factors (subtract points):**
- Pure software/cloud with no hardware (-1) # Slightly negative if no design/AI aspect
- Requires deep security clearance (-2)
- No mention of design or prototyping (-3) # Increased penalty for non-designer roles

**Select all matches** (score 7+) to proceed to Phase 3.

---

### Phase 3 — Create Summary Document

Create/update `~/openclaw/workspace/jobs/JOB_SEARCH_SUMMARY.md` with:

```markdown
# Job Search Summary
*Last updated: [DATE]*

---

## Job #1: [Job Title] at [Company]

**Match Score:** [X/10]
**Location:** [Location]
**Salary:** [Range or "Not listed"]

### Why You're Qualified
[2-3 sentences explaining the strongest fit — be specific, not generic]

### The Role
[1-2 sentences describing what the job is]

### Links
- 🔗 **Apply:** [Direct company careers link — prefer over aggregator]

---
[Repeat for each job]
```



---

## File Output Structure

All output goes in: `~/openclaw/workspace/jobs/`

```
jobs/
├── JOB_SEARCH_SUMMARY.md          ← START HERE — master overview
├── [Company]_[Role]/
│   └── job_description.md         ← copy of the original JD
└── ...
```

---

## Rules

1. **Always read CV.md first** before generating any application material
2. **Tailor every document** — never produce generic copy-paste materials
3. **Direct links only** — always try to find the job on the company's own careers page
4. **Be honest about fit** — if a job is a stretch, say so in the summary
5. **Research the company** — fetch their homepage/about page before writing the cover letter
6. **Update the summary** — every job search run should update JOB_SEARCH_SUMMARY.md
7. **Never fabricate credentials** — only claim skills/experience that exist in the CV

# Tech Stack Decision Matrix

Scoring framework for selecting the right technology stack during Phase 3 (Recommend). Use the app analysis from Phase 1 and discovery answers from Phase 2 to score each option.

## How to Use This Matrix

1. Read the app complexity score and feature map from Phase 1
2. Read the user's preferences and constraints from Phase 2
3. For each technology layer, score the candidates against the criteria
4. Recommend the highest-scoring option as **Primary** and second-highest as **Alternative**
5. If the user stated a preference in Phase 2, weight that heavily — user familiarity beats theoretical advantage

## Database Layer

### Candidates

| Criteria | PostgreSQL | MySQL | SQLite |
|---|---|---|---|
| **Complex queries** (joins, CTEs, window functions) | Excellent | Good | Limited |
| **JSON support** (if FM used flexible schemas) | Excellent (JSONB) | Good (JSON type) | Basic |
| **Full-text search** | Built-in (tsvector) | Built-in (FULLTEXT) | Extension (FTS5) |
| **Row-level security** | Built-in (RLS policies) | No | No |
| **Concurrent users >10** | Excellent (MVCC) | Good | Poor (file locking) |
| **Stored procedures / triggers** | Excellent | Good | Limited |
| **Hosting availability** | Universal | Universal | Embedded only |
| **Ease of setup** | Moderate | Moderate | Trivial |
| **Scaling ceiling** | Very high | High | Low |

### Selection Guide

- **PostgreSQL** — Default recommendation for most FM migrations. Handles FM's complex relationships, supports RLS for privilege set mapping, excellent for 5+ concurrent users.
- **MySQL** — Choose if the team already uses MySQL, or if the hosting environment requires it.
- **SQLite** — Only for very simple apps (<5 tables, <3 users, no concurrent writes). Good for prototyping.

## Backend Framework

### By Language

#### Python

| Framework | Best For | Complexity Sweet Spot | Learning Curve |
|---|---|---|---|
| **FastAPI** | API-first apps, modern Python | Medium–Complex | Low (if Python known) |
| **Django** | Full-featured apps with admin | Medium–Enterprise | Moderate |
| **Flask** | Simple APIs, microservices | Simple–Medium | Low |

#### JavaScript / TypeScript

| Framework | Best For | Complexity Sweet Spot | Learning Curve |
|---|---|---|---|
| **Express + Prisma** | Flexible API development | Simple–Complex | Low |
| **NestJS** | Structured enterprise apps | Medium–Enterprise | Moderate |
| **Next.js API Routes** | Full-stack with React frontend | Simple–Medium | Low (if React known) |

#### Go

| Framework | Best For | Complexity Sweet Spot | Learning Curve |
|---|---|---|---|
| **Gin** | High-performance APIs | Medium–Complex | Moderate |
| **Echo** | Clean API development | Simple–Medium | Moderate |

### Selection Guide

1. **Match team skills first** — a team that knows Python should use Python, even if Go is "faster"
2. If no team preference:
   - Simple app → **Express** (JS) or **FastAPI** (Python)
   - Medium app → **FastAPI** or **Django** (if admin panel wanted)
   - Complex/Enterprise → **Django** or **NestJS** (structure helps at scale)
3. If full-stack JS is desired → **Next.js** (combines frontend + API)

## Frontend Framework

### Candidates

| Criteria | React | Vue | Svelte | Server-Rendered (HTMX/Jinja/EJS) |
|---|---|---|---|---|
| **Complex UI** (many forms, tabs, portals) | Excellent | Excellent | Good | Limited |
| **Component ecosystem** | Largest | Large | Growing | N/A |
| **Mobile (responsive)** | With CSS framework | With CSS framework | With CSS framework | With CSS framework |
| **Mobile (native-like PWA)** | Good | Good | Good | Limited |
| **Learning curve** | Moderate | Low | Low | Very low |
| **Team size needed** | 1+ | 1+ | 1+ | 1+ |
| **Real-time updates** | Excellent | Excellent | Excellent | Good (SSE) |
| **SEO importance** | SSR needed | SSR needed | SSR needed | Built-in |
| **Offline capability** | With service workers | With service workers | With service workers | Very limited |

### Selection Guide

1. **Match team skills** — always the primary factor
2. If no preference:
   - Simple app with mostly forms/tables → **Server-rendered** (HTMX + Django templates or EJS)
   - Medium app with interactive UI → **Vue** or **React**
   - Complex app with lots of FM portals/tabs → **React** (ecosystem depth)
   - Team wants simplicity → **Vue** or **Svelte**
3. FM apps are typically internal tools — SEO is rarely important
4. If mobile is critical → ensure responsive design with a CSS framework (Tailwind, Bootstrap)

### CSS Framework

| Option | Best For | Notes |
|---|---|---|
| **Tailwind CSS** | Utility-first, custom designs | Most flexible. Good for teams that want control. |
| **Bootstrap** | Quick, conventional UI | Closest to FM's built-in themes. Familiar to most devs. |
| **Shadcn/ui** (React) | Modern component library | Pre-built components with Tailwind. Good for React projects. |
| **Vuetify** (Vue) | Material Design components | Rich component set. Good for Vue projects. |

## Authentication

| Option | Best For | Complexity |
|---|---|---|
| **Session-based (cookie)** | Server-rendered apps, simple auth | Low |
| **JWT tokens** | API-first apps, mobile clients | Low–Moderate |
| **OAuth2 / OpenID Connect** | Apps needing SSO or social login | Moderate |
| **Auth library** (Passport.js, NextAuth, Django auth) | Most apps — handles sessions, tokens, providers | Low (built-in) |
| **Auth service** (Auth0, Clerk, Supabase Auth) | Apps that want managed auth | Very Low (SaaS cost) |

### Selection Guide

- FM apps with simple accounts → **Session-based auth** or **framework built-in auth**
- FM apps using Active Directory → **OAuth2/OIDC** with the same provider
- Small team, want to move fast → **Auth service** (Auth0, Clerk)
- Budget-sensitive → **Framework built-in** (Django auth, Passport.js)

## Deployment

| Option | Best For | Cost | Ops Effort |
|---|---|---|---|
| **PaaS** (Railway, Render, Fly.io) | Small teams, fast deployment | $5–50/mo | Very Low |
| **VPS** (DigitalOcean, Linode) | Budget-conscious, full control | $5–20/mo | Moderate |
| **AWS / GCP / Azure** | Enterprise, high scale, compliance | Variable | High |
| **Docker + VPS** | Reproducible deploys, moderate scale | $10–40/mo | Moderate |
| **On-premise** | Regulatory requirements, existing infra | Hardware cost | High |
| **Vercel / Netlify** (frontend) + separate API | JAMstack architecture | Free–$20/mo | Low |

### Selection Guide

- Default recommendation: **PaaS** (Railway or Render) — easiest migration from FM Server's simplicity
- If the user runs FM Server on-premise and wants to stay on-premise → **Docker on existing server**
- If cloud cost is a concern → **VPS with Docker**
- If enterprise compliance needed → **AWS/GCP/Azure**

## Architecture Pattern

| Pattern | When to Use | FM Complexity | Team Size |
|---|---|---|---|
| **Monolith** | Simple apps, single domain, fast to build | Simple | 1–2 |
| **Modular Monolith** | Clear domain boundaries, but single deployment | Medium–Complex | 1–5 |
| **Microservices** | Independent scaling, multiple teams, polyglot | Enterprise | 5+ |

### Default Recommendation

**Modular Monolith** for most FileMaker migrations. Reasons:
- FM solutions are inherently single-application systems
- They typically have clear domain boundaries (the script groups map well to modules)
- Monolith deployment simplicity matches FM Server's operational model
- Can be split into services later if needed

Only recommend microservices if the user explicitly has multiple teams or needs independent scaling of specific features.

## Quick Decision Flowchart

```
Is the app Simple (<5 tables, <10 scripts)?
├── Yes → SQLite/PostgreSQL + Express/FastAPI + Server-rendered + Session auth + PaaS
└── No
    Is the team experienced with a specific stack?
    ├── Yes → Use their stack + PostgreSQL + PaaS/Docker
    └── No
        Is the app Medium (5-15 tables)?
        ├── Yes → PostgreSQL + FastAPI/Express + Vue/React + JWT + PaaS
        └── No (Complex/Enterprise)
            └── PostgreSQL + Django/NestJS + React + OAuth + Docker/Cloud
```

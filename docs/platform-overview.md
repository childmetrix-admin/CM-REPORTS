# ChildMetrix Reporting Platform

*Your data. Every domain. One platform.*

**March 2026**

---

## What It Is

The ChildMetrix Reporting Platform is a secure, modern data reporting service built exclusively for state child welfare agencies. You provide your data -- we deliver a continuously updated, beautifully designed platform that turns it into actionable dashboards and reports, without burdening your team.

No software to install. No internal analysts required. Just clear, ready-to-use reporting across every major area of your agency.

## Domains Covered

| Domain | Description |
|---|---|
| **Community** | Community demographics, services, resources, and contextual indicators |
| **CPS & Intake** | Reports, trends, and outcomes for investigations and screened-in reports |
| **In-Home Services** | Service delivery, FFPSA candidacy, EBPs, case outcomes, and prevention metrics |
| **Foster Care & Permanency** | Entries, exits, placement moves, use of kinship and congregate care, and permanency outcomes |
| **A Home for Every Child** (optional) | Reporting in support of ACF's Home for Every Child initiative -- available to participating states |
| **Federal Indicators (CFSR)** | CFSR outcome measures and national benchmarking |

## Investment

| | Single Domain | Full Platform |
|---|---|---|
| **Year 1** (implementation + license) | $35,000 | $95,000 |
| **Year 2+** (license + maintenance) | $25,000 / year | $85,000 / year |

Flat annual license -- no per-domain or per-user fees. Full platform pricing reflects a significant discount relative to individual domain rates.

## What You Get

**Interactive Dashboards**
Web-based visualizations covering key metrics, trends, and outcomes -- filterable by time period, geography, and population.

**Ready-to-Go PowerPoint Decks**
Presentation-ready slides with visualizations and talking points, built for leadership briefings, legislative updates, and stakeholder reports.

**Data Quality Reports**
Plain-language summaries of data quality issues -- what was flagged, how it was handled, and what it means for your results.

**State Profiles & Data Briefs**
Concise narrative summaries on select measures, ready for public reporting or internal review.

**Technical Assistance -- Included**
We work directly with your data and IT teams to define measures, assemble the right files, and troubleshoot along the way.

---

## Security & Infrastructure Overview

### Cloud Hosting

The platform is hosted on Amazon Web Services (AWS), a FedRAMP-authorized, SOC 2 Type II certified cloud infrastructure provider. All services run in isolated, access-controlled environments with no shared tenancy across state clients.

### Authentication & Access Control

User authentication is managed via Auth0, an enterprise-grade identity platform.

- Multi-factor authentication (MFA) supported
- Role-based access control (RBAC)
- State-based data isolation -- users credentialed to a given state access only that state's data
- No shared credentials across state clients

### Data Storage

State data is stored in Amazon Web Services (AWS) S3 -- dedicated, private buckets per state client. Data is never commingled across states.

- Encryption at rest: AES-256
- Encryption in transit: TLS 1.2+
- Access restricted to authorized ChildMetrix processing pipelines and designated state contacts

### Data Transfer

States submit data files via a secure upload portal within the platform. Files are transmitted over HTTPS and land directly in the state's dedicated S3 bucket. SFTP transfer is also available upon request.

- No email-based file transfer
- Upload activity logged and auditable
- State data accessible only to that state's designated contacts and ChildMetrix analysts

### Data Processing

Submitted files are processed using secure, auditable R-based analytical pipelines that produce aggregated outputs powering dashboards and reports.

- No child-level records are stored beyond what is submitted by the state
- Raw files retained for audit and reprocessing purposes only
- Processing pipelines are version-controlled and reproducible

### Data in Outputs

All dashboards, reports, and exported files display **aggregated data only**. No personally identifiable information (PII) is surfaced in the platform interface or any exported deliverable.

- No child names, case IDs, or worker identifiers in outputs
- Minimum cell-size suppression applied where applicable

### Summary

| Area | Approach |
|---|---|
| Cloud hosting | Amazon Web Services (AWS) -- FedRAMP authorized, SOC 2 Type II certified |
| Authentication | Auth0 -- MFA, role-based access control, domain-based state isolation |
| Data storage | AWS S3 -- dedicated per-state buckets, AES-256 encryption at rest |
| Data in transit | TLS 1.2+ (HTTPS upload portal and SFTP) |
| Cross-state data isolation | Enforced at both storage (separate S3 buckets) and auth (RBAC) layers |
| Data in outputs | Aggregated only -- no PII surfaced in any dashboard, report, or export |
| Audit & reproducibility | Version-controlled pipelines; raw file retention for audit purposes |

---

**ChildMetrix**
www.childmetrix.com | kurtheisler@childmetrix.com

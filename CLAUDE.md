# Bot Army Outreach Bot

Complete outreach management system for tracking contacts, scheduling follow-ups, and generating daily analytics.

## Architecture

**Phase 1: Core Infrastructure**
- Contact database with stage tracking (cold, follow_up_scheduled, replied, conversation, deal, rejected)
- NATS request/reply handlers for CRUD operations

**Phase 2: Google Sheets Integration**
- Sync contacts from Google Sheet (Name | Email | Company | Stage | Dates | Notes)
- Upsert-by-email logic for recurring imports

**Phase 3: Follow-up Scheduler**
- Checks every 30 minutes for contacts needing follow-up
- Auto-creates GTD projects with contact context

**Phase 4: SYNC_REPORT Analytics**
- Daily report: stalled contacts, missed follow-ups, new replies
- Conversion rate, response rate, reply-time averages
- Syncs to Google Drive

**Phase 5: Registry Validation**
- Validates outreach tracker names against REGISTRY.md
- Integrated with log-progress Makefile target

## NATS Subjects

- `outreach.contact.create` — Create contact
- `outreach.contact.update` — Update contact
- `outreach.contact.list` — Query contacts by stage/status
- `outreach.follow_up.schedule` — Schedule follow-up date
- `outreach.sheets.sync` — Sync contacts from Google Sheet

## Development

```bash
# Setup
mix deps.get

# Tests
mix test

# Linting
mix credo

# Build release
MIX_ENV=prod mix release
```

## Deployment

```bash
# From monorepo
make deploy-bot BOT=outreach
```

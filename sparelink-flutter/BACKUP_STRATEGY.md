# 🔒 SpareLink Backup Strategy

> **Document Version:** 1.0  
> **Last Updated:** January 17, 2026  
> **Owner:** DevOps Team

---

## 📋 Overview

This document outlines the comprehensive backup strategy for SpareLink's infrastructure, ensuring data protection, business continuity, and disaster recovery capabilities.

---

## 🗄️ Database Backups (Supabase)

### Automatic Backups (Supabase Pro Plan)

| Feature | Configuration |
|---------|--------------|
| **Frequency** | Daily automatic backups |
| **Retention** | 7 days (Pro), 30 days (Enterprise) |
| **Type** | Point-in-Time Recovery (PITR) |
| **Location** | Same region as database |

### Manual Backup Procedures

#### 1. Database Dump (Weekly)

```bash
# Export full database dump
pg_dump -h db.zcxsbfzezfjnkxwnnklf.supabase.co \
  -U postgres \
  -d postgres \
  -F c \
  -f sparelink_backup_$(date +%Y%m%d).dump

# Upload to secure storage
aws s3 cp sparelink_backup_$(date +%Y%m%d).dump \
  s3://sparelink-backups/database/
```

#### 2. Schema-Only Backup (Before Migrations)

```bash
# Export schema only
pg_dump -h db.zcxsbfzezfjnkxwnnklf.supabase.co \
  -U postgres \
  -d postgres \
  --schema-only \
  -f sparelink_schema_$(date +%Y%m%d).sql
```

#### 3. Critical Tables Backup (Daily)

Priority tables to backup daily:
- `profiles` - User account data
- `shops` - Shop configurations
- `orders` - Transaction records
- `part_requests` - Active requests
- `offers` - Quote history

```sql
-- Export critical tables via Supabase Dashboard
-- Table Editor → Export → CSV/JSON
```

### Backup Schedule

| Backup Type | Frequency | Retention | Storage Location |
|-------------|-----------|-----------|------------------|
| Full Database | Daily (auto) | 7-30 days | Supabase |
| Manual Dump | Weekly | 90 days | AWS S3 / GCS |
| Schema Backup | Before migrations | 1 year | Git Repository |
| Critical Tables | Daily | 30 days | AWS S3 / GCS |
| Audit Logs | Weekly | 1 year | Cold Storage |

---

## 📁 File Storage Backups (Supabase Storage)

### Storage Buckets

| Bucket | Content | Backup Frequency |
|--------|---------|------------------|
| `part-images` | Part request photos | Daily |
| `profile-images` | User avatars | Weekly |
| `documents` | Invoices, receipts | Daily |

### Backup Procedure

```bash
# Sync storage bucket to backup location
# Using Supabase CLI or direct S3 sync

supabase storage download part-images \
  --output ./backup/storage/part-images/

# Or using rclone for S3-compatible backup
rclone sync supabase:part-images backup:sparelink-storage/part-images
```

---

## 💻 Application Code Backups

### Source Code (Git)

| Repository | Backup Location | Frequency |
|------------|-----------------|-----------|
| Flutter App | GitHub/GitLab | Every commit |
| Shop Dashboard | GitHub/GitLab | Every commit |
| SQL Migrations | GitHub/GitLab | Every commit |

### Git Backup Strategy

```bash
# Mirror repository to backup location
git clone --mirror git@github.com:sparelink/app.git
cd app.git
git remote add backup git@backup-server:sparelink/app.git
git push --mirror backup
```

---

## 🔄 Disaster Recovery Plan

### Recovery Time Objectives (RTO)

| Service | Target RTO | Recovery Method |
|---------|------------|-----------------|
| Database | < 1 hour | PITR from Supabase |
| Storage | < 2 hours | Restore from S3 |
| Application | < 30 mins | Redeploy from Git |
| Full System | < 4 hours | Complete restoration |

### Recovery Point Objectives (RPO)

| Data Type | Target RPO | Backup Frequency |
|-----------|------------|------------------|
| Transactions | < 1 hour | Continuous (PITR) |
| User Data | < 24 hours | Daily backup |
| Media Files | < 24 hours | Daily sync |
| Logs | < 1 week | Weekly archive |

### Recovery Procedures

#### Database Recovery

```bash
# 1. Restore from Supabase PITR (via Dashboard)
# Navigate to: Project Settings → Database → Backups → Restore

# 2. Restore from manual backup
pg_restore -h db.new-instance.supabase.co \
  -U postgres \
  -d postgres \
  -F c \
  sparelink_backup_20260117.dump
```

#### Storage Recovery

```bash
# Restore storage bucket from backup
supabase storage upload part-images \
  --source ./backup/storage/part-images/
```

---

## 🔐 Backup Security

### Encryption

| Data State | Encryption |
|------------|------------|
| At Rest | AES-256 |
| In Transit | TLS 1.3 |
| Backup Files | GPG encrypted |

### Access Control

```bash
# Encrypt backup before storage
gpg --symmetric --cipher-algo AES256 \
  sparelink_backup_$(date +%Y%m%d).dump

# Only authorized personnel have decryption keys
# Keys stored in secure vault (e.g., HashiCorp Vault, AWS Secrets Manager)
```

### Backup Access Policy

- **Production backups**: Only DevOps team leads
- **Development backups**: Development team
- **Audit logs**: Security team + Management
- **All access logged**: Via audit_logs table

---

## 📊 Backup Monitoring

### Automated Checks

```bash
# Daily backup verification script
#!/bin/bash

# Check if backup exists
BACKUP_FILE="s3://sparelink-backups/database/sparelink_backup_$(date +%Y%m%d).dump"

if aws s3 ls "$BACKUP_FILE" > /dev/null 2>&1; then
    echo "✅ Backup verified: $BACKUP_FILE"
else
    echo "❌ BACKUP MISSING: $BACKUP_FILE"
    # Send alert to Slack/PagerDuty
    curl -X POST -H 'Content-type: application/json' \
      --data '{"text":"🚨 SpareLink backup missing!"}' \
      $SLACK_WEBHOOK_URL
fi
```

### Monitoring Dashboard

Track these metrics:
- [ ] Last successful backup timestamp
- [ ] Backup file sizes (detect anomalies)
- [ ] Backup duration
- [ ] Storage utilization
- [ ] Failed backup alerts

---

## 🧪 Backup Testing

### Monthly Restore Tests

1. **Full Database Restore**
   - Restore to test environment
   - Verify data integrity
   - Run application tests

2. **Partial Recovery**
   - Restore single table
   - Verify referential integrity

3. **Point-in-Time Recovery**
   - Restore to specific timestamp
   - Verify transaction consistency

### Test Documentation

```markdown
## Backup Test Log

| Date | Test Type | Duration | Result | Tester |
|------|-----------|----------|--------|--------|
| 2026-01-17 | Full Restore | 45 mins | ✅ Pass | John D. |
| 2026-01-10 | PITR Test | 20 mins | ✅ Pass | Jane S. |
```

---

## 📞 Emergency Contacts

| Role | Contact | Availability |
|------|---------|--------------|
| DevOps Lead | devops@sparelink.co.za | 24/7 |
| Database Admin | dba@sparelink.co.za | Business hours |
| Supabase Support | support@supabase.io | 24/7 (Enterprise) |
| Security Team | security@sparelink.co.za | 24/7 |

---

## 📝 Compliance

This backup strategy aligns with:
- **POPIA** (Protection of Personal Information Act)
- **ISO 27001** Information Security
- **SOC 2** Type II requirements

### Data Retention (Reference)

See `lib/shared/services/data_retention_service.dart` for programmatic retention policies.

---

## 🔄 Review Schedule

| Review Type | Frequency | Next Review |
|-------------|-----------|-------------|
| Strategy Review | Quarterly | April 2026 |
| Procedure Test | Monthly | February 2026 |
| Security Audit | Annually | January 2027 |

---

*Document maintained by SpareLink DevOps Team*

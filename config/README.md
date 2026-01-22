# Configuration Files

Configuration files for Email Agent AI services.

---

## 📁 Files

### PostgreSQL

| File | Description | Usage |
|------|-------------|-------|
| `postgresql-arm.conf` | PostgreSQL optimized for Oracle ARM (24GB, 4 cores) | Mounted in db container |

**Key optimizations:**
- `shared_buffers = 2GB` (24GB system)
- `effective_cache_size = 6GB`
- `max_worker_processes = 4` (4 ARM cores)
- `random_page_cost = 1.1` (SSD optimized)

### Nginx

| File | Description | Usage |
|------|-------------|-------|
| `nginx.conf` | Main Nginx configuration | Reverse proxy config |
| `nginx-site.conf` | Site-specific config | API routing |

---

## 🔧 Usage

### PostgreSQL Configuration (ARM)

**In `docker-compose.oracle-arm.yml`:**

```yaml
db:
  volumes:
    - ./config/postgresql-arm.conf:/etc/postgresql/postgresql.conf:ro
  command: postgres -c config_file=/etc/postgresql/postgresql.conf
```

**Or via environment variables:**

```yaml
db:
  environment:
    - POSTGRES_SHARED_BUFFERS=2GB
    - POSTGRES_EFFECTIVE_CACHE_SIZE=6GB
    # etc.
```

---

## 📊 Performance Tuning

### Memory Settings (24GB system)

```
Total RAM: 24 GB
├── PostgreSQL: 4 GB (17%)
│   ├── shared_buffers: 2 GB
│   └── effective_cache_size: 6 GB (guidance)
├── Ollama: 8 GB (33%)
├── Redis: 2 GB (8%)
├── Workers (4x): 4 GB (17%)
├── API + Others: 2 GB (8%)
└── System: 4 GB (17%)
```

### CPU Settings (4 ARM cores)

```
Total: 4 cores
├── Ollama: 2 cores
├── PostgreSQL: 2 cores
│   ├── max_worker_processes: 4
│   ├── max_parallel_workers: 4
│   └── max_parallel_workers_per_gather: 2
└── Workers (4x): 1 core each (shared)
```

---

## 🔍 Monitoring

### PostgreSQL Performance

```bash
# Connect to database
docker compose -f docker-compose.oracle-arm.yml exec db psql -U emailagent -d emailagent

# Check current settings
SHOW shared_buffers;
SHOW effective_cache_size;
SHOW max_worker_processes;

# Cache hit ratio (should be > 95%)
SELECT
  sum(heap_blks_read) as heap_read,
  sum(heap_blks_hit) as heap_hit,
  sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) as ratio
FROM pg_statio_user_tables;

# Active connections
SELECT count(*) FROM pg_stat_activity;

# Slow queries
SELECT pid, now() - query_start as duration, query
FROM pg_stat_activity
WHERE state = 'active' AND now() - query_start > interval '1 second';
```

---

## 📝 Notes

- PostgreSQL settings are optimized for Oracle ARM Free Tier (24GB, 4 cores)
- For different hardware, adjust `shared_buffers` (1/12 of RAM) and `effective_cache_size` (1/4 of RAM)
- ARM-specific CPU costs are calibrated for Ampere A1 processors

---

**See also:**
- [ORACLE_ARM_SETUP_SUMMARY.md](../ORACLE_ARM_SETUP_SUMMARY.md)
- [docs/DEPLOY_ORACLE_ARM.md](../docs/DEPLOY_ORACLE_ARM.md)

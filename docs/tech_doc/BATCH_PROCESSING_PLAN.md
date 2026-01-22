# 📋 Plan : Traitement Batch 20K+ Emails sans Blacklist

**Objectif** : Permettre le traitement de grandes boîtes mail (20K+ emails) sans risque de blacklist par les serveurs email.

---

## 🎯 Contraintes & Limites Serveurs

### Gmail API
| Limite | Valeur | Impact |
|--------|--------|--------|
| **Quota quotidien** | 1 milliard quota units/jour | ~250K emails/jour max |
| **Requêtes/sec** | 250 req/sec (burst) | Limiter à 50 req/sec (safe) |
| **Messages.list** | 5 quota units | 200M appels/jour |
| **Messages.get** | 5 quota units | Idem |
| **Batch requests** | 100 req/batch | Utiliser batching |

**Recommandations Gmail** :
- Utiliser `batch()` pour grouper requêtes
- Implémenter exponential backoff (429 errors)
- Limiter à 10-50 requêtes parallèles max

### Outlook/Microsoft Graph API
| Limite | Valeur | Impact |
|--------|--------|--------|
| **Requêtes/sec** | 10,000 req/10 min | ~16 req/sec |
| **Throttling** | HTTP 429 | Backoff obligatoire |
| **Delta sync** | Recommandé | Utiliser pour sync initiale |
| **Batch** | 20 req/batch | Moins efficace que Gmail |

**Recommandations Outlook** :
- Utiliser Delta Queries pour sync initiale
- Respecter Retry-After header (429)
- Limiter à 10 requêtes parallèles

### IMAP Générique
| Limite | Typique | Impact |
|--------|---------|--------|
| **Connexions simultanées** | 5-15 | Limite stricte |
| **Commandes/minute** | Variable (100-1000) | Rate limit agressif |
| **IDLE timeout** | 29 min | Reconnexion périodique |
| **FETCH batch** | Recommandé | 100-500 UIDs/commande |

**Recommandations IMAP** :
- Pool de connexions limité (2-5 max)
- FETCH par batch de 100-500 UIDs
- Délai entre commandes (100-500ms)
- Respecter NO/BAD responses

---

## 📐 Architecture Proposée

### Nouveaux Composants

```
shared/rate_limiting/
├── rate_limiter.py          # Rate limiter générique avec Redis
├── provider_limits.py       # Limites par fournisseur
└── backoff_strategy.py      # Exponential backoff

shared/integrations/base/
├── batch_connector.py       # Base class pour batch processing
└── connection_pool.py       # Pool de connexions IMAP

worker/tasks/
├── batch_sync.py            # Tâches Celery pour batch sync
├── progressive_sync.py      # Sync progressive par périodes
└── adaptive_scheduler.py    # Ajustement dynamique du rythme

shared/config.py
└── [Nouvelles variables BATCH_*, RATE_LIMIT_*]
```

---

## 📋 PHASE 1 : Rate Limiting & Connection Management

### 1.1 Rate Limiter avec Redis

**Fichier** : `shared/rate_limiting/rate_limiter.py`

```python
"""
Rate limiter utilisant Redis pour coordination multi-workers.
"""
import time
import logging
from typing import Optional
from redis import Redis

logger = logging.getLogger(__name__)


class RateLimiter:
    """
    Rate limiter avec sliding window.

    Exemples:
        limiter = RateLimiter(redis_client, "gmail_api", max_calls=50, window_seconds=1)

        if limiter.allow_request():
            # Faire la requête
            pass
        else:
            # Attendre
            wait_time = limiter.wait_time()
            time.sleep(wait_time)
    """

    def __init__(
        self,
        redis: Redis,
        key_prefix: str,
        max_calls: int,
        window_seconds: int
    ):
        self.redis = redis
        self.key_prefix = key_prefix
        self.max_calls = max_calls
        self.window = window_seconds

    def allow_request(self, identifier: str = "default") -> bool:
        """
        Vérifie si une requête peut être faite.

        Args:
            identifier: Identifiant unique (account_id, etc.)

        Returns:
            True si requête autorisée, False sinon
        """
        key = f"{self.key_prefix}:{identifier}"
        now = time.time()
        window_start = now - self.window

        # Cleanup old entries
        self.redis.zremrangebyscore(key, 0, window_start)

        # Count current requests
        current_count = self.redis.zcard(key)

        if current_count < self.max_calls:
            # Add new request
            self.redis.zadd(key, {str(now): now})
            self.redis.expire(key, self.window * 2)
            return True

        return False

    def wait_time(self, identifier: str = "default") -> float:
        """
        Temps d'attente avant prochaine requête.

        Returns:
            Secondes à attendre (0 si peut faire requête)
        """
        key = f"{self.key_prefix}:{identifier}"
        now = time.time()
        window_start = now - self.window

        # Get oldest request in window
        oldest = self.redis.zrangebyscore(
            key, window_start, now, start=0, num=1, withscores=True
        )

        if not oldest:
            return 0.0

        oldest_time = oldest[0][1]
        wait = (oldest_time + self.window) - now
        return max(0.0, wait)

    async def wait_if_needed(self, identifier: str = "default"):
        """Attente asynchrone si nécessaire."""
        import asyncio

        while not self.allow_request(identifier):
            wait = self.wait_time(identifier)
            logger.debug(f"Rate limit reached for {identifier}, waiting {wait:.2f}s")
            await asyncio.sleep(wait + 0.1)  # Small buffer
```

### 1.2 Limites par Fournisseur

**Fichier** : `shared/rate_limiting/provider_limits.py`

```python
"""
Configuration des limites par fournisseur email.
"""
from dataclasses import dataclass
from typing import Dict


@dataclass
class ProviderLimits:
    """Limites pour un fournisseur."""

    # Rate limiting
    requests_per_second: int
    requests_per_minute: int
    requests_per_hour: int

    # Batch
    batch_size: int
    concurrent_requests: int

    # Backoff
    initial_backoff_seconds: float
    max_backoff_seconds: float
    backoff_multiplier: float

    # Connections (IMAP only)
    max_connections: int = 1


# Configuration par défaut par provider
PROVIDER_LIMITS: Dict[str, ProviderLimits] = {
    "gmail": ProviderLimits(
        requests_per_second=50,      # Safe: 50/sec (max 250/sec)
        requests_per_minute=2000,    # Safe: 2000/min
        requests_per_hour=100000,    # Safe: 100K/hour
        batch_size=100,               # Gmail batch max
        concurrent_requests=10,       # Parallel requests
        initial_backoff_seconds=1.0,
        max_backoff_seconds=64.0,
        backoff_multiplier=2.0,
        max_connections=1             # API, not IMAP
    ),

    "outlook": ProviderLimits(
        requests_per_second=10,       # Safe: 10/sec (16/sec max)
        requests_per_minute=500,      # Conservative
        requests_per_hour=20000,      # Safe
        batch_size=20,                # MS Graph batch limit
        concurrent_requests=5,        # Lower than Gmail
        initial_backoff_seconds=2.0,
        max_backoff_seconds=128.0,
        backoff_multiplier=2.0,
        max_connections=1
    ),

    "imap": ProviderLimits(
        requests_per_second=2,        # Very conservative
        requests_per_minute=60,       # 1/sec average
        requests_per_hour=2000,       # Safe for most servers
        batch_size=200,               # FETCH batch size
        concurrent_requests=1,        # Sequential for safety
        initial_backoff_seconds=5.0,
        max_backoff_seconds=300.0,
        backoff_multiplier=2.0,
        max_connections=3             # IMAP connection pool
    ),
}


def get_limits(provider: str) -> ProviderLimits:
    """Get limits for provider."""
    return PROVIDER_LIMITS.get(provider.lower(), PROVIDER_LIMITS["imap"])
```

### 1.3 Exponential Backoff

**Fichier** : `shared/rate_limiting/backoff_strategy.py`

```python
"""
Stratégies de retry avec exponential backoff.
"""
import asyncio
import logging
import random
from typing import Optional, Callable, Any

logger = logging.getLogger(__name__)


class ExponentialBackoff:
    """
    Exponential backoff avec jitter.

    Exemples:
        backoff = ExponentialBackoff(initial=1.0, max_delay=60.0)

        for attempt in range(5):
            try:
                result = await api_call()
                break
            except RateLimitError:
                await backoff.sleep(attempt)
    """

    def __init__(
        self,
        initial: float = 1.0,
        max_delay: float = 60.0,
        multiplier: float = 2.0,
        jitter: bool = True
    ):
        self.initial = initial
        self.max_delay = max_delay
        self.multiplier = multiplier
        self.jitter = jitter

    def delay(self, attempt: int) -> float:
        """
        Calculate delay for attempt.

        Args:
            attempt: Attempt number (0-indexed)

        Returns:
            Delay in seconds
        """
        delay = min(self.initial * (self.multiplier ** attempt), self.max_delay)

        if self.jitter:
            # Add random jitter (0-25% of delay)
            jitter_amount = delay * 0.25 * random.random()
            delay += jitter_amount

        return delay

    async def sleep(self, attempt: int):
        """Sleep with exponential backoff."""
        delay = self.delay(attempt)
        logger.info(f"Backoff: sleeping {delay:.2f}s (attempt {attempt})")
        await asyncio.sleep(delay)


async def retry_with_backoff(
    func: Callable,
    max_attempts: int = 5,
    backoff: Optional[ExponentialBackoff] = None,
    retry_on: tuple = (Exception,)
) -> Any:
    """
    Retry function avec backoff.

    Args:
        func: Async function to retry
        max_attempts: Maximum retry attempts
        backoff: Backoff strategy (default: 1s initial, 60s max)
        retry_on: Exceptions to retry on

    Returns:
        Function result

    Raises:
        Last exception if all attempts fail
    """
    if backoff is None:
        backoff = ExponentialBackoff()

    last_exception = None

    for attempt in range(max_attempts):
        try:
            return await func()
        except retry_on as e:
            last_exception = e
            logger.warning(f"Attempt {attempt + 1}/{max_attempts} failed: {e}")

            if attempt < max_attempts - 1:
                await backoff.sleep(attempt)
            else:
                logger.error(f"All {max_attempts} attempts failed")
                raise last_exception

    raise last_exception
```

### 1.4 IMAP Connection Pool

**Fichier** : `shared/integrations/base/connection_pool.py`

```python
"""
Pool de connexions IMAP pour limiter connexions simultanées.
"""
import asyncio
import logging
from typing import Optional
from contextlib import asynccontextmanager
from imapclient import IMAPClient

logger = logging.getLogger(__name__)


class IMAPConnectionPool:
    """
    Pool de connexions IMAP avec limite.

    Évite de dépasser max_connections du serveur.

    Usage:
        pool = IMAPConnectionPool(host, user, password, max_connections=3)

        async with pool.acquire() as imap:
            messages = imap.search(['ALL'])
    """

    def __init__(
        self,
        host: str,
        username: str,
        password: str,
        max_connections: int = 3,
        port: int = 993,
        use_ssl: bool = True
    ):
        self.host = host
        self.username = username
        self.password = password
        self.port = port
        self.use_ssl = use_ssl
        self.max_connections = max_connections

        self._semaphore = asyncio.Semaphore(max_connections)
        self._connections: list[IMAPClient] = []

    @asynccontextmanager
    async def acquire(self):
        """
        Acquire connection from pool.

        Yields:
            IMAPClient instance
        """
        async with self._semaphore:
            conn = await self._create_connection()
            try:
                yield conn
            finally:
                await self._release_connection(conn)

    async def _create_connection(self) -> IMAPClient:
        """Create new IMAP connection."""
        logger.debug(f"Creating IMAP connection to {self.host}")

        # Run blocking IMAP operations in thread pool
        loop = asyncio.get_event_loop()

        def connect():
            client = IMAPClient(self.host, port=self.port, ssl=self.use_ssl)
            client.login(self.username, self.password)
            return client

        conn = await loop.run_in_executor(None, connect)
        return conn

    async def _release_connection(self, conn: IMAPClient):
        """Release connection back to pool or close if error."""
        try:
            # Check if connection still alive
            loop = asyncio.get_event_loop()
            await loop.run_in_executor(None, conn.noop)

            # Connection OK, could pool it for reuse
            # For now, close to avoid idle timeout issues
            await loop.run_in_executor(None, conn.logout)
        except Exception as e:
            logger.warning(f"Error releasing connection: {e}")
            try:
                await asyncio.get_event_loop().run_in_executor(None, conn.logout)
            except:
                pass
```

---

## 📋 PHASE 2 : Batch Processing Strategy

### 2.1 Base Connector avec Batch Support

**Fichier** : `shared/integrations/base/batch_connector.py`

```python
"""
Base class pour connecteurs avec support batch.
"""
from abc import ABC, abstractmethod
from typing import List, Dict, Any, Optional
import logging

logger = logging.getLogger(__name__)


class BatchConnector(ABC):
    """
    Base class pour connecteurs supportant batch processing.

    Implémente:
    - Pagination automatique
    - Rate limiting
    - Batch fetching
    - Progress tracking
    """

    def __init__(self, account_id: int, rate_limiter: Optional[Any] = None):
        self.account_id = account_id
        self.rate_limiter = rate_limiter
        self._stats = {
            'total_fetched': 0,
            'batches_processed': 0,
            'errors': 0
        }

    @abstractmethod
    async def fetch_batch(
        self,
        batch_size: int,
        offset: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Fetch batch of messages.

        Args:
            batch_size: Number of messages to fetch
            offset: Pagination token/offset

        Returns:
            {
                'messages': List[dict],
                'next_offset': Optional[str],
                'has_more': bool
            }
        """
        pass

    async def fetch_all(
        self,
        batch_size: int = 100,
        max_messages: Optional[int] = None,
        progress_callback: Optional[callable] = None
    ) -> List[Dict[str, Any]]:
        """
        Fetch all messages with pagination.

        Args:
            batch_size: Messages per batch
            max_messages: Maximum total messages (None = unlimited)
            progress_callback: Callback(fetched, total_estimated)

        Returns:
            List of all messages
        """
        all_messages = []
        offset = None

        while True:
            # Rate limiting
            if self.rate_limiter:
                await self.rate_limiter.wait_if_needed(str(self.account_id))

            # Fetch batch
            try:
                result = await self.fetch_batch(batch_size, offset)
                messages = result['messages']

                all_messages.extend(messages)
                self._stats['total_fetched'] += len(messages)
                self._stats['batches_processed'] += 1

                logger.info(
                    f"Batch {self._stats['batches_processed']}: "
                    f"fetched {len(messages)} messages "
                    f"(total: {self._stats['total_fetched']})"
                )

                # Progress callback
                if progress_callback:
                    progress_callback(self._stats['total_fetched'], None)

                # Check limits
                if max_messages and self._stats['total_fetched'] >= max_messages:
                    logger.info(f"Reached max_messages limit: {max_messages}")
                    break

                # Check if more pages
                if not result.get('has_more', False):
                    logger.info("No more messages to fetch")
                    break

                offset = result.get('next_offset')

            except Exception as e:
                logger.error(f"Error fetching batch: {e}", exc_info=True)
                self._stats['errors'] += 1
                raise

        return all_messages

    def get_stats(self) -> Dict[str, int]:
        """Get sync statistics."""
        return self._stats.copy()
```

### 2.2 Configuration Batch

**Ajout dans** : `shared/config.py`

```python
class Settings(BaseSettings):
    # ... existing settings ...

    # ==================== BATCH PROCESSING ====================

    # Sync batch sizes
    EMAIL_SYNC_BATCH_SIZE: int = Field(1000, description="Emails per sync batch")
    CLASSIFICATION_BATCH_SIZE: int = Field(100, description="Emails per classification batch")

    # Rate limiting
    ENABLE_RATE_LIMITING: bool = Field(True, description="Enable rate limiting")
    GMAIL_REQUESTS_PER_SECOND: int = Field(50, description="Gmail API rate limit")
    OUTLOOK_REQUESTS_PER_SECOND: int = Field(10, description="Outlook API rate limit")
    IMAP_REQUESTS_PER_SECOND: int = Field(2, description="IMAP rate limit")

    # Connection pooling
    IMAP_MAX_CONNECTIONS: int = Field(3, description="Max IMAP connections per account")

    # Backoff
    ENABLE_EXPONENTIAL_BACKOFF: bool = Field(True, description="Enable exponential backoff")
    BACKOFF_INITIAL_SECONDS: float = Field(1.0, description="Initial backoff delay")
    BACKOFF_MAX_SECONDS: float = Field(60.0, description="Max backoff delay")

    # Batch processing
    MAX_EMAILS_PER_SYNC: Optional[int] = Field(None, description="Max emails per sync (None = unlimited)")
    SYNC_DELAY_BETWEEN_BATCHES_MS: int = Field(500, description="Delay between batches (ms)")
```

---

## 📋 PHASE 3 : Progressive Sync

### 3.1 Progressive Sync Strategy

**Fichier** : `worker/tasks/progressive_sync.py`

```python
"""
Synchronisation progressive par périodes.

Stratégie:
1. Jour 1: Derniers 7 jours (emails récents critiques)
2. Jour 2: 8-30 jours (emails récents importants)
3. Jour 3-7: 1-6 mois (historique)
4. Semaine 2: 6-12 mois
5. Semaine 3+: > 12 mois (archive)

Permet de:
- Avoir rapidement les emails importants
- Étaler la charge sur plusieurs jours
- Ne pas saturer les quotas
"""
import logging
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from celery import shared_task
from sqlalchemy import select

from api.models import EmailAccount, Email
from api.database import get_db_context
from shared.config import settings
from shared.rate_limiting.rate_limiter import RateLimiter
from shared.rate_limiting.provider_limits import get_limits

logger = logging.getLogger(__name__)


@dataclass
class SyncPeriod:
    """Période de synchronisation."""
    name: str
    days_back_start: int
    days_back_end: int
    priority: int  # 1 = highest


# Périodes de sync progressives
SYNC_PERIODS: List[SyncPeriod] = [
    SyncPeriod("critical_recent", 0, 7, priority=1),      # Last 7 days
    SyncPeriod("recent", 8, 30, priority=2),              # 8-30 days
    SyncPeriod("last_3_months", 31, 90, priority=3),      # 1-3 months
    SyncPeriod("last_6_months", 91, 180, priority=4),     # 3-6 months
    SyncPeriod("last_year", 181, 365, priority=5),        # 6-12 months
    SyncPeriod("archive", 366, 3650, priority=6),         # 1-10 years
]


@shared_task(
    name='worker.tasks.progressive_sync.sync_account_progressive',
    bind=True,
    max_retries=3
)
def sync_account_progressive(
    self,
    account_id: int,
    period_name: str
) -> Dict[str, Any]:
    """
    Sync account pour une période spécifique.

    Args:
        account_id: ID du compte
        period_name: Nom de la période (ex: "critical_recent")

    Returns:
        Stats de sync
    """
    try:
        logger.info(f"Progressive sync account {account_id}, period: {period_name}")

        # Get period config
        period = next((p for p in SYNC_PERIODS if p.name == period_name), None)
        if not period:
            raise ValueError(f"Unknown period: {period_name}")

        # Calculate date range
        now = datetime.utcnow()
        date_from = now - timedelta(days=period.days_back_end)
        date_to = now - timedelta(days=period.days_back_start)

        logger.info(f"Syncing period {period_name}: {date_from} to {date_to}")

        # Import connector (avoid circular import)
        from shared.integrations import get_connector

        async def do_sync():
            async with get_db_context() as db:
                # Get account
                result = await db.execute(
                    select(EmailAccount).where(EmailAccount.id == account_id)
                )
                account = result.scalar_one_or_none()

                if not account:
                    raise ValueError(f"Account {account_id} not found")

                # Get connector
                connector = await get_connector(account)

                # Fetch emails for period
                emails = await connector.fetch_emails(
                    date_from=date_from,
                    date_to=date_to,
                    batch_size=settings.EMAIL_SYNC_BATCH_SIZE
                )

                logger.info(f"Fetched {len(emails)} emails for period {period_name}")

                # Save to DB (batch insert)
                await save_emails_batch(db, account_id, emails)

                # Update last_sync for this period
                account.last_sync = datetime.utcnow()
                await db.commit()

                return {
                    'account_id': account_id,
                    'period': period_name,
                    'fetched': len(emails),
                    'date_from': date_from.isoformat(),
                    'date_to': date_to.isoformat()
                }

        import asyncio
        result = asyncio.run(do_sync())

        return result

    except Exception as exc:
        logger.error(f"Progressive sync failed: {exc}", exc_info=True)
        raise self.retry(exc=exc, countdown=2 ** self.request.retries * 60)


async def save_emails_batch(
    db,
    account_id: int,
    emails: List[Dict[str, Any]],
    batch_size: int = 500
):
    """
    Save emails en batch pour performance.

    Args:
        db: Database session
        account_id: Account ID
        emails: List of email dicts
        batch_size: Batch size for inserts
    """
    from api.models import Email

    for i in range(0, len(emails), batch_size):
        batch = emails[i:i + batch_size]

        email_objects = []
        for email_data in batch:
            # Check if exists
            existing = await db.execute(
                select(Email).where(
                    Email.account_id == account_id,
                    Email.message_id == email_data['message_id']
                )
            )
            if existing.scalar_one_or_none():
                continue  # Skip duplicates

            email_obj = Email(
                account_id=account_id,
                message_id=email_data['message_id'],
                subject=email_data.get('subject', ''),
                sender=email_data.get('sender', ''),
                date_received=email_data.get('date_received'),
                body_preview=email_data.get('body_preview', ''),
                status='pending'
            )
            email_objects.append(email_obj)

        if email_objects:
            db.add_all(email_objects)
            await db.flush()

            logger.info(f"Saved batch of {len(email_objects)} emails")


@shared_task(name='worker.tasks.progressive_sync.schedule_progressive_sync')
def schedule_progressive_sync(account_id: int):
    """
    Schedule progressive sync pour un compte.

    Crée des tâches pour chaque période, dans l'ordre de priorité.
    """
    logger.info(f"Scheduling progressive sync for account {account_id}")

    # Sort by priority
    sorted_periods = sorted(SYNC_PERIODS, key=lambda p: p.priority)

    # Chain tasks
    from celery import chain

    tasks = [
        sync_account_progressive.si(account_id, period.name)
        for period in sorted_periods
    ]

    # Execute chain (sequential)
    workflow = chain(*tasks)
    workflow.apply_async()

    logger.info(f"Scheduled {len(tasks)} progressive sync tasks")
```

### 3.2 Configuration Progressive Sync

**Ajout dans** : `shared/config.py`

```python
class Settings(BaseSettings):
    # ... existing ...

    # ==================== PROGRESSIVE SYNC ====================

    ENABLE_PROGRESSIVE_SYNC: bool = Field(
        True,
        description="Enable progressive sync (recommended for >10K emails)"
    )

    PROGRESSIVE_SYNC_INITIAL_DAYS: int = Field(
        7,
        description="Initial sync: last N days (most important)"
    )

    PROGRESSIVE_SYNC_PERIODS: str = Field(
        "7,30,90,180,365,3650",
        description="Comma-separated sync periods in days"
    )
```

---

## 📋 PHASE 4 : Monitoring & Adaptive Throttling

### 4.1 Monitoring des Taux

**Fichier** : `worker/monitoring/sync_monitor.py`

```python
"""
Monitoring de la synchronisation et détection de throttling.
"""
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, Optional
from redis import Redis

logger = logging.getLogger(__name__)


class SyncMonitor:
    """
    Monitor sync rates et détecte throttling.

    Stocke dans Redis:
    - Nombre de requêtes/min, /hour
    - Erreurs 429 (rate limit)
    - Temps de réponse moyen
    - Statut throttling
    """

    def __init__(self, redis: Redis, account_id: int):
        self.redis = redis
        self.account_id = account_id
        self.key_prefix = f"sync_monitor:{account_id}"

    def record_request(self, success: bool, response_time_ms: float):
        """Enregistre une requête."""
        now = datetime.utcnow()

        # Increment counters
        minute_key = f"{self.key_prefix}:requests:minute:{now.strftime('%Y%m%d%H%M')}"
        hour_key = f"{self.key_prefix}:requests:hour:{now.strftime('%Y%m%d%H')}"

        self.redis.incr(minute_key)
        self.redis.expire(minute_key, 120)  # Keep 2 minutes

        self.redis.incr(hour_key)
        self.redis.expire(hour_key, 7200)  # Keep 2 hours

        # Record response time
        self.redis.lpush(f"{self.key_prefix}:response_times", response_time_ms)
        self.redis.ltrim(f"{self.key_prefix}:response_times", 0, 99)  # Keep last 100

        if not success:
            self.redis.incr(f"{self.key_prefix}:errors")
            self.redis.expire(f"{self.key_prefix}:errors", 3600)

    def record_rate_limit(self, retry_after: Optional[int] = None):
        """Enregistre un rate limit (429)."""
        logger.warning(f"Rate limit detected for account {self.account_id}")

        # Set throttled flag
        self.redis.setex(
            f"{self.key_prefix}:throttled",
            retry_after or 60,  # Throttled for at least 60s
            "1"
        )

        # Increment 429 counter
        self.redis.incr(f"{self.key_prefix}:rate_limits")
        self.redis.expire(f"{self.key_prefix}:rate_limits", 3600)

    def is_throttled(self) -> bool:
        """Check si account est throttlé."""
        return bool(self.redis.get(f"{self.key_prefix}:throttled"))

    def get_stats(self) -> Dict[str, Any]:
        """Récupère statistiques."""
        now = datetime.utcnow()
        minute_key = f"{self.key_prefix}:requests:minute:{now.strftime('%Y%m%d%H%M')}"
        hour_key = f"{self.key_prefix}:requests:hour:{now.strftime('%Y%m%d%H')}"

        requests_this_minute = int(self.redis.get(minute_key) or 0)
        requests_this_hour = int(self.redis.get(hour_key) or 0)

        response_times = [
            float(t) for t in self.redis.lrange(f"{self.key_prefix}:response_times", 0, -1)
        ]
        avg_response_time = sum(response_times) / len(response_times) if response_times else 0

        return {
            'account_id': self.account_id,
            'requests_per_minute': requests_this_minute,
            'requests_per_hour': requests_this_hour,
            'avg_response_time_ms': avg_response_time,
            'throttled': self.is_throttled(),
            'total_rate_limits': int(self.redis.get(f"{self.key_prefix}:rate_limits") or 0)
        }
```

### 4.2 Adaptive Throttling

**Fichier** : `worker/tasks/adaptive_scheduler.py`

```python
"""
Ajustement dynamique du rythme de sync basé sur monitoring.
"""
import logging
from typing import Dict, Any
from celery import shared_task

from worker.monitoring.sync_monitor import SyncMonitor
from shared.config import settings
from api.database import get_db_context

logger = logging.getLogger(__name__)


@shared_task(name='worker.tasks.adaptive_scheduler.adjust_sync_rate')
def adjust_sync_rate(account_id: int) -> Dict[str, Any]:
    """
    Ajuste le taux de sync basé sur monitoring.

    Si throttling détecté:
    - Ralentit sync
    - Augmente délais entre batches

    Si tout va bien:
    - Peut accélérer progressivement
    """
    from redis import Redis

    redis = Redis.from_url(settings.REDIS_URL)
    monitor = SyncMonitor(redis, account_id)

    stats = monitor.get_stats()

    logger.info(f"Account {account_id} sync stats: {stats}")

    if stats['throttled']:
        logger.warning(f"Account {account_id} is throttled, slowing down")

        # Store reduced rate in Redis
        redis.setex(
            f"sync_rate:{account_id}",
            3600,  # 1 hour
            "slow"  # slow|normal|fast
        )

        return {'account_id': account_id, 'action': 'slow_down', 'reason': 'throttled'}

    elif stats['requests_per_minute'] > 50:
        logger.info(f"Account {account_id} high rate, maintaining")
        redis.setex(f"sync_rate:{account_id}", 3600, "normal")
        return {'account_id': account_id, 'action': 'maintain', 'reason': 'high_rate'}

    else:
        logger.info(f"Account {account_id} low rate, can speed up")
        redis.setex(f"sync_rate:{account_id}", 3600, "fast")
        return {'account_id': account_id, 'action': 'speed_up', 'reason': 'low_rate'}


def get_sync_delay(account_id: int) -> float:
    """
    Get délai entre batches basé sur adaptive throttling.

    Returns:
        Délai en secondes
    """
    from redis import Redis

    redis = Redis.from_url(settings.REDIS_URL)
    rate = redis.get(f"sync_rate:{account_id}")

    if not rate:
        return settings.SYNC_DELAY_BETWEEN_BATCHES_MS / 1000.0

    rate = rate.decode('utf-8')

    delays = {
        'slow': 5.0,      # 5 secondes entre batches
        'normal': 1.0,    # 1 seconde
        'fast': 0.5       # 500ms
    }

    return delays.get(rate, 1.0)
```

---

## 📋 PHASE 5 : Error Recovery & Resilience

### 5.1 Task Retry Strategy

**Fichier** : `worker/tasks/batch_sync.py`

```python
"""
Tâches Celery pour batch sync avec retry robuste.
"""
import logging
from typing import Dict, Any, Optional
from celery import shared_task
from datetime import datetime, timedelta

from api.models import EmailAccount, Email
from api.database import get_db_context
from shared.config import settings
from worker.monitoring.sync_monitor import SyncMonitor
from worker.tasks.adaptive_scheduler import get_sync_delay

logger = logging.getLogger(__name__)


@shared_task(
    name='worker.tasks.batch_sync.sync_account_batch',
    bind=True,
    max_retries=5,
    default_retry_delay=60,  # 1 minute base delay
    autoretry_for=(Exception,),
    retry_backoff=True,
    retry_backoff_max=600,  # Max 10 minutes
    retry_jitter=True
)
def sync_account_batch(
    self,
    account_id: int,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None
) -> Dict[str, Any]:
    """
    Sync batch d'emails avec retry automatique.

    Features:
    - Exponential backoff automatique
    - Rate limit detection
    - Error recovery
    - Progress tracking

    Args:
        account_id: ID du compte
        date_from: ISO datetime (optional)
        date_to: ISO datetime (optional)

    Returns:
        Sync statistics
    """
    from redis import Redis
    from shared.integrations import get_connector
    import asyncio

    redis = Redis.from_url(settings.REDIS_URL)
    monitor = SyncMonitor(redis, account_id)

    try:
        # Check if throttled
        if monitor.is_throttled():
            logger.warning(f"Account {account_id} is throttled, retrying later")
            raise self.retry(countdown=120)  # Retry in 2 minutes

        logger.info(f"Starting batch sync for account {account_id}")

        start_time = datetime.utcnow()

        async def do_sync():
            async with get_db_context() as db:
                # Get account
                from sqlalchemy import select
                result = await db.execute(
                    select(EmailAccount).where(EmailAccount.id == account_id)
                )
                account = result.scalar_one_or_none()

                if not account:
                    raise ValueError(f"Account {account_id} not found")

                # Get connector with rate limiting
                connector = await get_connector(account, enable_rate_limiting=True)

                # Parse dates
                df = datetime.fromisoformat(date_from) if date_from else None
                dt = datetime.fromisoformat(date_to) if date_to else None

                # Fetch with progress
                emails_fetched = 0

                def progress_callback(fetched, total):
                    nonlocal emails_fetched
                    emails_fetched = fetched
                    logger.info(f"Progress: {fetched} emails fetched")

                emails = await connector.fetch_emails(
                    date_from=df,
                    date_to=dt,
                    batch_size=settings.EMAIL_SYNC_BATCH_SIZE,
                    max_emails=settings.MAX_EMAILS_PER_SYNC,
                    progress_callback=progress_callback
                )

                # Save to DB
                from worker.tasks.progressive_sync import save_emails_batch
                await save_emails_batch(db, account_id, emails)

                # Update last_sync
                account.last_sync = datetime.utcnow()
                await db.commit()

                # Record success
                duration = (datetime.utcnow() - start_time).total_seconds()
                monitor.record_request(success=True, response_time_ms=duration * 1000)

                return {
                    'account_id': account_id,
                    'fetched': len(emails),
                    'duration_seconds': duration,
                    'date_from': date_from,
                    'date_to': date_to
                }

        result = asyncio.run(do_sync())

        logger.info(f"Batch sync completed: {result}")

        return result

    except RateLimitError as exc:
        # Rate limit hit
        logger.warning(f"Rate limit hit for account {account_id}: {exc}")

        retry_after = getattr(exc, 'retry_after', 60)
        monitor.record_rate_limit(retry_after)

        # Retry with exponential backoff
        raise self.retry(exc=exc, countdown=retry_after)

    except Exception as exc:
        # Other errors
        logger.error(f"Batch sync failed for account {account_id}: {exc}", exc_info=True)

        duration = (datetime.utcnow() - start_time).total_seconds()
        monitor.record_request(success=False, response_time_ms=duration * 1000)

        # Retry with backoff
        countdown = 2 ** self.request.retries * 60  # Exponential: 1min, 2min, 4min, 8min
        raise self.retry(exc=exc, countdown=countdown)


class RateLimitError(Exception):
    """Exception pour rate limiting."""

    def __init__(self, message: str, retry_after: int = 60):
        super().__init__(message)
        self.retry_after = retry_after
```

### 5.2 Dead Letter Queue

**Fichier** : `worker/tasks/dead_letter_handler.py`

```python
"""
Gestion des tâches échouées (Dead Letter Queue).
"""
import logging
from celery import shared_task
from datetime import datetime
from typing import Dict, Any

from api.database import get_db_context
from api.models import SyncLog

logger = logging.getLogger(__name__)


@shared_task(name='worker.tasks.dead_letter_handler.handle_failed_sync')
def handle_failed_sync(
    account_id: int,
    error_message: str,
    retry_count: int
):
    """
    Handle sync définitivement échoué.

    Actions:
    1. Log dans database
    2. Notification admin
    3. Désactive auto-sync si trop d'échecs
    """
    import asyncio

    logger.error(
        f"Sync failed permanently for account {account_id} "
        f"after {retry_count} retries: {error_message}"
    )

    async def log_failure():
        async with get_db_context() as db:
            # Log in database
            log_entry = SyncLog(
                account_id=account_id,
                sync_type='batch_sync',
                status='failed',
                error_message=error_message,
                retry_count=retry_count,
                created_at=datetime.utcnow()
            )
            db.add(log_entry)

            # Check if too many failures
            from sqlalchemy import select, func
            result = await db.execute(
                select(func.count(SyncLog.id))
                .where(
                    SyncLog.account_id == account_id,
                    SyncLog.status == 'failed',
                    SyncLog.created_at >= datetime.utcnow() - timedelta(hours=24)
                )
            )
            failure_count = result.scalar()

            if failure_count >= 5:
                logger.warning(
                    f"Account {account_id} has {failure_count} failures in 24h, "
                    "consider disabling auto-sync"
                )

                # Could disable auto-sync
                from api.models import EmailAccount
                account_result = await db.execute(
                    select(EmailAccount).where(EmailAccount.id == account_id)
                )
                account = account_result.scalar_one_or_none()
                if account:
                    account.auto_sync_enabled = False
                    logger.info(f"Disabled auto-sync for account {account_id}")

            await db.commit()

    asyncio.run(log_failure())
```

---

## 📊 Configuration Finale Recommandée

### `.env` pour Oracle ARM 24GB

```bash
# ==================== BATCH PROCESSING OPTIMAL ====================

# Sync batches (optimisé pour 20K emails)
EMAIL_SYNC_BATCH_SIZE=1000          # 1000 emails/batch
CLASSIFICATION_BATCH_SIZE=100        # 100 emails/classification batch
MAX_EMAILS_PER_SYNC=20000           # Limite: 20K emails par sync complète

# Rate limiting (respectueux)
ENABLE_RATE_LIMITING=true
GMAIL_REQUESTS_PER_SECOND=50        # Conservative (max 250/sec)
OUTLOOK_REQUESTS_PER_SECOND=10      # Conservative (max 16/sec)
IMAP_REQUESTS_PER_SECOND=2          # Très conservatif

# Connection pooling
IMAP_MAX_CONNECTIONS=3              # Max 3 connexions IMAP simultanées

# Backoff
ENABLE_EXPONENTIAL_BACKOFF=true
BACKOFF_INITIAL_SECONDS=1.0
BACKOFF_MAX_SECONDS=60.0

# Progressive sync (recommandé pour >10K emails)
ENABLE_PROGRESSIVE_SYNC=true
PROGRESSIVE_SYNC_INITIAL_DAYS=7     # Commencer par 7 derniers jours
PROGRESSIVE_SYNC_PERIODS=7,30,90,180,365,3650

# Délais
SYNC_DELAY_BETWEEN_BATCHES_MS=500   # 500ms entre batches

# Workers (4 cores ARM)
CELERY_WORKERS=4
CELERY_WORKER_CONCURRENCY=1

# Timeouts ARM
OLLAMA_TIMEOUT=150
CLASSIFICATION_TIMEOUT=150
IMAP_TIMEOUT=90
```

---

## 📈 Estimation Performance 20K Emails

### Scénario: Gmail, 20K emails, Oracle ARM 24GB

| Phase | Stratégie | Emails | Temps | Détails |
|-------|-----------|--------|-------|---------|
| **Fetch IMAP** | Batch 1000 | 20K | 10-20 min | 50 req/sec, 20 batches |
| **Parse & Save** | Streaming | 20K | 5 min | Parse MIME + DB insert |
| **Classification** | Hybride | 20K | 45-90 min | 70% rules (instant), 30% AI (2-3 sec/email) |
| **Actions** | Batch | Variable | 5 min | Move/archive selon règles |
| **TOTAL** | Progressive | 20K | **1-2 heures** | Premier traitement complet |

### Mode Continu (après sync initiale)

| Métrique | Valeur | Commentaire |
|----------|--------|-------------|
| **Sync interval** | 10 min | Celery Beat schedule |
| **Nouveaux emails** | ~50-100 | Par sync typique |
| **Classification** | 2-3 sec | Par email (Ollama) |
| **Traitement batch** | 5-10 min | 100 nouveaux emails |
| **Charge CPU** | 30-40% | Moyenne |
| **Charge RAM** | 10-12 GB | 50% disponible |

---

## ✅ Checklist Implémentation

### Phase 1: Rate Limiting (Priorité HAUTE)
- [ ] `shared/rate_limiting/rate_limiter.py`
- [ ] `shared/rate_limiting/provider_limits.py`
- [ ] `shared/rate_limiting/backoff_strategy.py`
- [ ] `shared/integrations/base/connection_pool.py`
- [ ] Tests unitaires rate limiting

### Phase 2: Batch Processing (Priorité HAUTE)
- [ ] `shared/integrations/base/batch_connector.py`
- [ ] Mettre à jour `shared/config.py` (batch settings)
- [ ] Implémenter dans Gmail connector
- [ ] Implémenter dans IMAP connector
- [ ] Tests batch processing

### Phase 3: Progressive Sync (Priorité MOYENNE)
- [ ] `worker/tasks/progressive_sync.py`
- [ ] Configuration periods
- [ ] Celery Beat schedule
- [ ] Tests progressive sync

### Phase 4: Monitoring (Priorité MOYENNE)
- [ ] `worker/monitoring/sync_monitor.py`
- [ ] `worker/tasks/adaptive_scheduler.py`
- [ ] Dashboard monitoring (optionnel)
- [ ] Alertes (optionnel)

### Phase 5: Error Recovery (Priorité HAUTE)
- [ ] `worker/tasks/batch_sync.py` avec retry
- [ ] `worker/tasks/dead_letter_handler.py`
- [ ] Logging amélioré
- [ ] Tests error scenarios

### Documentation
- [ ] README batch processing
- [ ] Guide déploiement Oracle ARM (update)
- [ ] Troubleshooting guide
- [ ] API endpoints monitoring

---

## 🎯 Ordre d'Implémentation Recommandé

### Semaine 1: Fondations
1. Rate limiting (Phase 1)
2. Batch connector base (Phase 2)
3. Tests rate limiting

### Semaine 2: Sync
1. Batch sync Gmail (Phase 2)
2. Progressive sync (Phase 3)
3. Tests end-to-end

### Semaine 3: Robustesse
1. Error recovery (Phase 5)
2. Monitoring (Phase 4)
3. Documentation

### Semaine 4: Optimisation
1. Adaptive throttling (Phase 4)
2. Performance tuning
3. Production testing

---

## 🚨 Points Critiques

### Ne JAMAIS faire:
- ❌ Dépasser les limites API documentées
- ❌ Ignorer les erreurs 429 (rate limit)
- ❌ Faire des connexions IMAP sans pool
- ❌ Sync complète sans progressive (>10K emails)
- ❌ Retry sans exponential backoff

### TOUJOURS faire:
- ✅ Respecter Retry-After headers
- ✅ Logger tous les rate limits
- ✅ Monitoring des taux de requêtes
- ✅ Batch processing pour bulk operations
- ✅ Connection pooling pour IMAP
- ✅ Progressive sync pour grandes boîtes

---

**Ce plan assure un traitement robuste, respectueux des serveurs, et optimisé pour Oracle ARM Free Tier.** 🚀

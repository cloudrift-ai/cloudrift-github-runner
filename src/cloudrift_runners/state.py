from __future__ import annotations

import datetime
import logging
from dataclasses import dataclass

from google.cloud import firestore

logger = logging.getLogger(__name__)

COLLECTION = "runner_jobs"
_TTL_HOURS = 24


@dataclass
class JobRecord:
    job_id: int
    instance_id: str
    run_id: int
    repo: str
    labels: list[str]
    status: str
    created_at: datetime.datetime


class StateStore:
    def __init__(self, db: firestore.Client | None = None):
        self._db = db or firestore.Client()

    def try_create_job(
        self,
        job_id: int,
        instance_id: str,
        run_id: int,
        repo: str,
        labels: list[str],
    ) -> bool:
        doc_ref = self._db.collection(COLLECTION).document(str(job_id))

        @firestore.transactional
        def _create(txn: firestore.Transaction) -> bool:
            snap = doc_ref.get(transaction=txn)
            if snap.exists:
                logger.warning("Job %s already exists (duplicate webhook?), skipping", job_id)
                return False
            now = datetime.datetime.now(tz=datetime.UTC)
            txn.set(
                doc_ref,
                {
                    "job_id": job_id,
                    "instance_id": instance_id,
                    "run_id": run_id,
                    "repo": repo,
                    "labels": labels,
                    "status": "running",
                    "created_at": now,
                    "expire_at": now + datetime.timedelta(hours=_TTL_HOURS),
                },
            )
            return True

        txn = self._db.transaction()
        return _create(txn)

    def get_job(self, job_id: int) -> JobRecord | None:
        doc = self._db.collection(COLLECTION).document(str(job_id)).get()
        if not doc.exists:
            return None
        data = doc.to_dict()
        return JobRecord(
            job_id=data["job_id"],
            instance_id=data["instance_id"],
            run_id=data["run_id"],
            repo=data["repo"],
            labels=data.get("labels", []),
            status=data["status"],
            created_at=data["created_at"],
        )

    def mark_completed(self, job_id: int) -> None:
        self._db.collection(COLLECTION).document(str(job_id)).update({"status": "completed"})

    def mark_failed(self, job_id: int) -> None:
        self._db.collection(COLLECTION).document(str(job_id)).update({"status": "failed"})

    def find_stale_jobs(self, max_age_minutes: int) -> list[JobRecord]:
        cutoff = datetime.datetime.now(tz=datetime.UTC) - datetime.timedelta(
            minutes=max_age_minutes
        )
        query = (
            self._db.collection(COLLECTION)
            .where("status", "==", "running")
            .where("created_at", "<", cutoff)
        )
        results = []
        for doc in query.stream():
            data = doc.to_dict()
            results.append(
                JobRecord(
                    job_id=data["job_id"],
                    instance_id=data["instance_id"],
                    run_id=data["run_id"],
                    repo=data["repo"],
                    labels=data.get("labels", []),
                    status=data["status"],
                    created_at=data["created_at"],
                )
            )
        return results

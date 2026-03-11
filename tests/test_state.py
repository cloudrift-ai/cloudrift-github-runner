from __future__ import annotations

import datetime
from unittest.mock import MagicMock, patch


def _make_mock_db():
    """Create a mock Firestore client with minimal behavior."""
    db = MagicMock()
    _store: dict[str, dict] = {}

    def _get_doc(collection_name):
        col = MagicMock()

        def _document(doc_id):
            doc_ref = MagicMock()
            doc_ref.id = doc_id

            def _get(**kwargs):
                snap = MagicMock()
                snap.exists = doc_id in _store
                snap.to_dict.return_value = _store.get(doc_id)
                return snap

            def _set(data, **kwargs):
                _store[doc_id] = data

            def _update(data, **kwargs):
                if doc_id in _store:
                    _store[doc_id].update(data)

            doc_ref.get = _get
            doc_ref.set = _set
            doc_ref.update = _update
            return doc_ref

        col.document = _document
        return col

    db.collection = _get_doc
    # Make transaction() return a mock that supports the transactional decorator
    txn = MagicMock()
    txn.set = lambda ref, data: ref.set(data)
    db.transaction.return_value = txn
    return db, _store


def test_try_create_and_get():
    from cloudrift_runners.state import StateStore

    db, store = _make_mock_db()

    # Patch the transactional decorator to just call the inner function
    with patch("google.cloud.firestore.transactional", lambda f: f):
        ss = StateStore(db)
        created = ss.try_create_job(
            job_id=100,
            instance_id="inst-abc",
            run_id=200,
            repo="myorg/myrepo",
            labels=["self-hosted", "cloudrift"],
        )

    assert created is True
    assert "100" in store

    record = ss.get_job(100)
    assert record is not None
    assert record.instance_id == "inst-abc"
    assert record.status == "running"


def test_mark_completed():
    from cloudrift_runners.state import StateStore

    db, store = _make_mock_db()
    now = datetime.datetime.now(tz=datetime.UTC)
    store["100"] = {
        "job_id": 100,
        "instance_id": "inst-abc",
        "run_id": 200,
        "repo": "myorg/myrepo",
        "labels": [],
        "status": "running",
        "created_at": now,
    }

    ss = StateStore(db)
    ss.mark_completed(100)
    assert store["100"]["status"] == "completed"

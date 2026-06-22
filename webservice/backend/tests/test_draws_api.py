SSQ = {"category": "ssq", "issue": "24001", "frontNumbers": [1, 2, 3, 4, 5, 6], "backNumbers": [16]}


def test_create_requires_auth(client):
    r = client.post("/api/v1/draws", json=SSQ)
    assert r.status_code == 401


def test_create_and_get(client, auth_headers):
    r = client.post("/api/v1/draws", json=SSQ, headers=auth_headers)
    assert r.status_code == 200
    body = r.json()
    assert body["frontNumbers"] == [1, 2, 3, 4, 5, 6]

    r2 = client.get("/api/v1/draws/ssq/24001", headers=auth_headers)
    assert r2.status_code == 200
    assert r2.json()["issue"] == "24001"


def test_get_not_found(client, auth_headers):
    r = client.get("/api/v1/draws/ssq/99999", headers=auth_headers)
    assert r.status_code == 404


def test_upsert_updates(client, auth_headers):
    client.post("/api/v1/draws", json=SSQ, headers=auth_headers)
    updated = {**SSQ, "backNumbers": [10], "prizes": {"first": 5000000}}
    r = client.post("/api/v1/draws", json=updated, headers=auth_headers)
    assert r.status_code == 200
    assert r.json()["backNumbers"] == [10]
    r2 = client.get("/api/v1/draws/ssq/24001", headers=auth_headers)
    assert r2.json()["prizes"] == {"first": 5000000}


def test_create_rejects_bad_numbers(client, auth_headers):
    bad = {**SSQ, "frontNumbers": [1, 2, 3]}
    r = client.post("/api/v1/draws", json=bad, headers=auth_headers)
    assert r.status_code == 422


def test_list_and_filter(client, auth_headers):
    client.post("/api/v1/draws", json=SSQ, headers=auth_headers)
    client.post("/api/v1/draws", json={**SSQ, "issue": "24002"}, headers=auth_headers)
    client.post("/api/v1/draws", json={"category": "dlt", "issue": "24001",
                                       "frontNumbers": [1, 2, 3, 4, 5], "backNumbers": [1, 2]},
                headers=auth_headers)
    r = client.get("/api/v1/draws?category=ssq", headers=auth_headers)
    assert r.status_code == 200
    body = r.json()
    assert body["total"] == 2
    assert body["items"][0]["issue"] == "24002"  # 倒序


def test_delete(client, auth_headers):
    client.post("/api/v1/draws", json=SSQ, headers=auth_headers)
    r = client.delete("/api/v1/draws/ssq/24001", headers=auth_headers)
    assert r.status_code == 204
    assert client.get("/api/v1/draws/ssq/24001", headers=auth_headers).status_code == 404

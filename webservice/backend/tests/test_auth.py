def test_login_success(client):
    r = client.post("/api/v1/auth/login", json={"password": "test-pass"})
    assert r.status_code == 200
    assert r.json()["token"] == "test-token"


def test_login_wrong_password(client):
    r = client.post("/api/v1/auth/login", json={"password": "nope"})
    assert r.status_code == 401

import pytest
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_health_endpoint(client):
    """Test the /health endpoint returns 200 and correct JSON."""
    rv = client.get('/health')
    assert rv.status_code == 200
    assert rv.get_json() == {"status": "healthy"}

def test_root_endpoint(client):
    """Test the root endpoint returns a cowsay string."""
    rv = client.get('/')
    assert rv.status_code == 200
    assert b"cowsay" not in rv.data # checking if it crashed, or we can check for <pre> tag
    assert b"<pre>" in rv.data

def test_metrics_endpoint(client):
    """Test the /metrics endpoint returns prometheus metrics."""
    rv = client.get('/metrics')
    assert rv.status_code == 200
    assert b"wisecow_requests_total" in rv.data

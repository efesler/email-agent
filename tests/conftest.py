"""
Configuration pytest pour les tests
"""
import pytest
import asyncio
from typing import Generator


@pytest.fixture(scope="session")
def event_loop():
    """Create event loop for async tests"""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


# Les fixtures seront implémentées au fur et à mesure
# Exemples de fixtures utiles:

# @pytest.fixture
# def client() -> TestClient:
#     """FastAPI test client"""
#     from api.main import app
#     return TestClient(app)

# @pytest.fixture
# async def db_session() -> AsyncSession:
#     """Database session pour tests"""
#     async with get_db_context() as session:
#         yield session

# @pytest.fixture
# def mock_ollama():
#     """Mock Ollama pour tests rapides"""
#     with patch('worker.classifiers.ollama_classifier.classifier') as mock:
#         mock.classify_email.return_value = {
#             'category': EmailCategory.UNKNOWN,
#             'confidence': 50,
#             'reason': 'Test mock'
#         }
#         yield mock

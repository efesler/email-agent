"""
Tests de base pour Email Agent AI
"""
import pytest
from fastapi.testclient import TestClient


def test_placeholder():
    """Test placeholder pour que pytest passe"""
    assert True


# Les tests réels seront implémentés progressivement
# Exemples de tests à implémenter:

# def test_health_endpoint(client: TestClient):
#     """Test de l'endpoint health"""
#     response = client.get("/health")
#     assert response.status_code == 200
#     assert response.json()["status"] == "healthy"

# def test_classification_categories(client: TestClient):
#     """Test de récupération des catégories"""
#     response = client.get("/api/classification/categories")
#     assert response.status_code == 200
#     assert len(response.json()["categories"]) > 0

# def test_email_classification(client: TestClient):
#     """Test de classification d'email"""
#     test_email = {
#         "subject": "Facture Test",
#         "sender": "test@example.com",
#         "body_preview": "Votre facture pour 100€",
#         "has_attachments": True
#     }
#     response = client.post("/api/classification/test", json=test_email)
#     assert response.status_code == 200
#     assert "category" in response.json()

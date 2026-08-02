# backend/search/urls.py
from django.urls import path
from .views import search_furniture

urlpatterns = [
    path('', search_furniture),  # /search/?query=...
]

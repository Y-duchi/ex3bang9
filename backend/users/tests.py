import hashlib

from django.contrib.auth.hashers import make_password
from django.test import SimpleTestCase

from .views import verify_stored_password


class PasswordVerificationTests(SimpleTestCase):
    def test_accepts_django_password_hash_without_upgrade(self):
        matches, needs_upgrade = verify_stored_password(
            "portfolio",
            make_password("portfolio"),
        )

        self.assertTrue(matches)
        self.assertFalse(needs_upgrade)

    def test_accepts_legacy_sha256_hash_and_marks_it_for_upgrade(self):
        legacy_hash = hashlib.sha256(b"portfolio").hexdigest()

        matches, needs_upgrade = verify_stored_password("portfolio", legacy_hash)

        self.assertTrue(matches)
        self.assertTrue(needs_upgrade)

    def test_rejects_wrong_password(self):
        matches, needs_upgrade = verify_stored_password(
            "wrong-password",
            make_password("portfolio"),
        )

        self.assertFalse(matches)
        self.assertFalse(needs_upgrade)
